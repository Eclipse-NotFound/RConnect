# early2 单位恢复阶段：只读分析

2026-10-22。只读核查，未改生产源码、冻结诊断源或测试门槛，未启动 JVM/AIR。这里所称“房间恢复”实际入口是 `GameBridge.restoreCheckpoint()`，不是独立 `RoomState.restore()` 类。目的只是为真实计时后选择最小改动，**尚未证实下列任一候选能缩短加载**。

## 准确输入与计时边界

- RC：`build/m52/recovery-early-exit-compile-01`，SWF SHA256 `d356483f927c608b5973982558127ce4feb0873a36676909ed3b3d6ac8b7acb3`。阅读源为 `experimental/recovery-early-exit-authorization/src`；GameBridge、NativeRoomState、ObjectIdentity、RoomSync、RConnectUnitAccess 已逐文件核对与该构建的 `src` 字节相同。
- 原生 `Location` 依据准确 2D 宿主 `build/m52/recovery-early-host-01/after/scripts/fe/loc/Location.as`，文件 SHA256 `9c7e679a4b5b8423355cb3ce07e496caa13415beb1ffdd630f0f2ed7b38c9cab`。本次未声称逐个敌人原生构造函数已与 2D 字节码核对。
- `GameBridge` SHA256 `3fe9bb83a16a57300e733806cddbe74ce55bcaf323bec15554814f4714eba967`；`NativeRoomState` `1e91028348b29dc1bd00dc55cf4d5df5d5ee40469ef9ea0f7e9626d30a601938`；`ObjectIdentity` `0bc4cc3429f78f0e43164dea4af4481e4230fdf335bd0eed6e7090baf0937774`。
- `timing.units - timing.terrain` 对应 GameBridge **6262–6298**：权威侧 boxTrackReset、可选旧单位清理、单位匹配/构造/完整恢复、清掉未出现的旧单位。角色清理在此前 `role` 段；后续 `applyUnitsSync`、命中代理、掉落物、玩家地雷在 `effects` 段，不能都算进 units。
- 旧 early1 实测 units 区间 **719 ms** 来自累计值 1536−817；其 GameBridge 实现与当前相同，但这不是当前 early2 新测量。出处：`experimental/recovery-early-first-load-review/README.md`。也不能把它称为纯敌人动画或纯构造耗时。

## 已由源码确认的调用链

1. 加入侧 `RoomSync` 的 grant 分支（819–858）先去重，再 `RoomCodec.unpack → game.restoreCheckpoint(state, owner, foreign[, retained])`；同一正在等待首绘的 grant 不重复恢复。精确 fresh-owner、unchanged、retained 各有单独校验路径。
2. 同房新地图通常由主侧先建立 `records[myKey]`，再取 `records[theirKey]`（948–983）；`theirKey == myKey` 时返回 `owner=false, fresh=false`。加入侧通常因此进入 foreign 重建；这不是简单把所有新图标 fresh 就能省掉的路径。
3. `restoreCheckpoint` 先验证尺寸、执行 `roomRole`、对象和地形恢复。`roomRole` 会解除旧冻结、清理显示/命中代理/伤害基线，并建立新角色；它先直接 reset，再强制 `_lastLocRef=null → resetBaselinesIfWorldChanged`，确有一部分第二次清空，但这属于 role 段。
4. **foreign=true**：复制 `loc.units` 数组遍历，保留本机玩家、场景命中类及非安保的 fraction≥100 对象，其他逐个 `loc.remObj → indexOf/splice`，删除 puppet 标记，清空本房单位身份表。
5. 每个快照单位：排除场景命中类 → `_units.resolve` → 未匹配才 `getDefinition(cls) → new XML → 构造敌人 → putLoc → loc.addObj → loc.units.push → bind`。随后无论新旧都 `NativeRoomState.restoreUnit → RConnectAnimationAccess.receive → TurretDisplay.receive`。
6. `restoreUnit`：恢复公开标量/数组 → 包内桥恢复 AI/计时器等内部字段 → 每单位查询 Weapon 类 → 按槽检查枪械 id/variant，失配才移除旧武器显示并 `Weapon.create` → 恢复枪械字段和 currentWeapon → setVisPos。sost≥4 再移除链和显示。没有调用原生 `die` 代替恢复。
7. 再复制 `loc.units` 清理快照中未使用的合格单位。此后 effects 段才清理/恢复掉落物；非权威侧再次完整遍历快照 `applyUnitsSync`：设置移动/防御/视野/姿态、冻结 AI、建立运动缓冲和血量基线，必要时创建 **MirrorHitUnit**，最后恢复玩家地雷与安保状态。

精确原生 Location 证实：`addObj` 会维护 firstObj/lastObj 链，active 时调用 `addVisual`（2282–2303）；`remObj` 会维护链并调用 `remVisual`（2306–2330）。它们不维护 `loc.units` 数组，所以现有 splice/push 不能直接删除。

## 明显重复工作与尚待计时的假设

| 源码已证实的工作 | 可以说什么 | 尚不能说什么 |
|---|---|---|
| foreign 路径拆除原有普通敌人，再按快照构造 | 双侧本地地图已造出的同类敌人可能紧接着重建；不是直接复用原生实例 | 未量化各敌人构造/武器/显示耗时；不能认定它独占 719 ms |
| 每次匹配的 key 命中仍 `list.indexOf`；未命中则遍历整个数组 | ObjectIdentity.resolve 为线性查找。foreign 重建时数组不断增长，已 bind 的前序单位仍会被后续循环访问后跳过；最多形成二次增长的检查量 | 未证明检查次数或其耗时占比足够大；不能据复杂度直接宣称主因 |
| 清理循环逐单位 indexOf/splice；首尾各 concat 一次 | 存在线性搜索、数组移动及临时数组；链表移除还会移除显示 | 不能把有副作用的 remObj 改成一次过滤数组，也不能擅改移除顺序 |
| restoreUnit 已写字段/位置，随后 applyUnitsSync 再遍历并写部分重叠字段 | 确实是两次遍历和部分重复赋值，但计时位于 units 与 effects 两段 | 第二轮还建立仅镜像需要的命中/伤害/动画状态；不能整体跳过 |
| 每单位 getDefinition(Weapon)，失配枪械可能重新创建；每数组字段 JSON stringify/parse | 存在可局部归并的查询与克隆成本；原生构造后枪械失配有第二次创建路径 | 没有实际“失配次数/数组量/耗时”；先缓存类或换克隆不保证总体收益 |
| roomRole 内部分 reset 重复；新 MirrorHitUnit 构造先 sync，随后调用方再 sync，prepare 也重复一次 | 可以精确定位重入式小重复；前者在 role，后者在 effects，不在 units | 不应靠这些微项解释或承诺消掉大图加载差距 |

## 不可省略的身份与结算约束

- 单位身份不是 `id` 一对一：ObjectIdentity 先按网络 key 找同一对象，再在未使用、未绑定对象中按 id/类/150 像素范围找最近者。换成单纯 id 字典会把同类敌人的伤害、抓取或死亡写给另一个实例。任何局部索引必须保留 key、数组成员资格、used、顺序和相等距离时的原选择。
- foreign 重建是为了从显示替身恢复到原生可运行实体；公开标量和内部桥没有传输目标、对象引用或链关系。复用旧 mirror 不能仅以 hp/坐标相同判等，须证明 AI、武器所有者、难度和原生对象关系完整。
- `sost≥4` 目前也可能先建对象再移除显示，并保留其数组身份。不能直接删去死单位快照；这会涉及重访、死亡/复活及炮塔地雷去重。更不能为提速调用 die：会引入掉落、经验或任务再次结算。
- MirrorHitUnit **只在 loc.units，不在 firstObj 步进链**，自身 xp=0、die 空实现；它借用本体的 vis/hpbar 供 SATS。dispose 还将 sost=4 并清借用引用以废弃旧 SATS 排队目标。把本体直接改回可攻击、留旧代理或把代理加入链，都改变结算或导致双显示。
- 原生 linked-list 字段及 visible/alpha 等本机显示字段被 NativeRoomState 特意排除。优化 restore/clone 不能把引用直连或把这些字段补回。

## 后续最小选择建议（未实施）

先用根的真实计时确认 units 相对原生绘制和其他恢复段仍占显著时间，再在**一次恢复中**区分移除、resolve、构造/putLoc/addObj、标量/武器/动画恢复四类成本，按实际发生数量解释；这些是缺少的证据，不是本次新增驱动需求。若主要是 resolve，优先考虑只作用于此次恢复的成员索引、保留原有匹配规则和失败顺序；若主要是构造，下一步需要单独证明允许复用的实体边界，不能以删第二遍或跳过死亡恢复替代。当前没有足以选定生产优化或发布的测量结果。
