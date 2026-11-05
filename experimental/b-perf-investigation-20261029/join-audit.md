# RConnect B 加入侧（join）战斗性能只读审计

> 审计对象：当前安装版 **B3-0.1-smooth1** 的准确源码
> `mods/RConnect/build/ab/b190-visual-motion-smooth04-source/src`
> 依据：`BuildInfo`/manifest `source_id=e2be0722…`；`src` 下 129 个 `.as` 全部与 `experimental/b-smooth-20261029/source-04/source-manifest.json` 逐文件 SHA-256 一致；manifest 另含 15 个 `stubs/` 源，合计 144 份。
> 版本串见 `src/RConnectMod.as:19`。
> 方式：只读 grep/read 源码与既有报告/日志；未编译、未启动游戏、未做 git 操作、未改任何 `.as`/release。

**证据口径提醒（先读）**

1. 产品默认 `Timing.enabled=false`（`authority/Timing.as:5-8`），只有 probe 构建会打开（`EnemyVisualProbe.as:31`、`StressProbe.as:12`、`WeaponProbe.as:62`）。本报告的 6 ms/18 ms 等分项数字来自 `build/ab/b-smooth-profile-03/03-A/join/ABBench.log`（插桩构建、现有 B、80 敌人持续轻机枪 30 s），**不是 smooth04 安装字节的精确复测**；smooth04 在 `b-smooth-clean-05` 的密集平均比该基线好约 5.4%（`state/B-MEMORY.md:16`、`experimental/b-smooth-20261029/README.md:42`）。因此分项数字用作“量级/排序”参考，不能当本轮产品精确定额。
2. 插桩口径有缺口：`client.decode` 只包住 `FrameDelta.decode`（`ClientReplica.as:61-63`）；AMF3 反序列化/解压发生在 `Link.drain`→`WireCodec.decode`，未单独计时（`Link.as:105`、`WireCodec.as:21-30`）。`SharedVision` 的每帧/10 Hz 工作、HUD 10 Hz、输入编码、原生游戏渲染也都不在 join 的 present 分项里。**所以真实每帧 CPU 高于分项之和。**
3. `state/B-MEMORY.md:17`、`README.md:41-43` 已记录：静止阶段首个间隔 292 ms、密集播放等待均值 162–168 ms、1–2 px 镜头回摆仍在；本审计不把它们当作已解释，只给机制线索。

---

## 0. 结论摘要

- **加入侧最大头是“每个确认帧把所有显示实体完整重放一遍”**：80 敌场景 `replica.units` 平均 **10.4 ms/确认帧**（n=403），`client.present` 平均 **18.8 ms/屏幕帧**、最大 66 ms，`client.decode` 平均 **6.08 ms/条帧消息**（n=404；不含 AMF3）。同场主侧约每 30 s 只发 404 帧（≈13.5 帧/s，`host.publish` 均 33.2 ms、最大 79 ms），加入侧约 21 次 present/s；present+receiveBatch 已约占 30 s 墙钟的 50%。
- **单帧/单消息最值得先动的不是“再删字段”，而是“没变也重放”**：场景单位、特效、血条、玩家在未变化的确认分支上仍走完整 `NativeFields.apply`/`VisualPose.apply`/`unit.blit`/`addChild`；`FrameDelta` 返回的不可变分支身份（同一对象引用）可以直接作为短路依据（`FrameDelta.as:20-49`、`ReplicaScene.as:184-241`、`SceneEffects.as:16-56`）。
- **每帧固定全量扫描确实存在**：`prune`（全部显示层子节点）+ `pointer`（所有单位/物件/特效）每次 render 都跑；另有 `SharedVision.render` 每个 RENDER 事件遍历整张房间光照位图 × 2 个条目（`SharedVision.as:131-151`），以及 10 Hz 的 `remember()` 重建整行字符串（`:28-38`、`:40-68`）。这些量级不大但恒定，且未被 present 分项覆盖。
- **无“无限”泄漏证据，但有有界保留池**：join 侧 `endedProjectiles/endedOrder` 按 240 tick 退休（`ClientReplica.as:159-163`）、特效记录按下一次确认帧清（`SceneEffects.as:55`）、时钟队列受 delay 限制。空 `clip` 的爆炸辅助弹丸仍会进 ended 池并走一次 `applyProjectile` 早退（`:146-154`、`:267`），A 版已修同类“无显示记录不退休”（`state/a-stutter-investigation-2026-10-28.md:12-28`），B 的对应项是**有界但按发数增长**，值得实测确认量级，不是无限泄漏。
- **A 版对应线索**：A 的 `RConnectAnimationAccess.tick` 在 blit 未变时会跳过重绘（`build/github-a-release/src/fe/unit/RConnectAnimationAccess.as:86-113`），A 的 UnitPresentation 有 `rec.pose`/observe/tick 快速路径（`rconnect/game/UnitPresentation.as:241-322`、`:405-415`）；B 的 `AuthorityAnimation.apply` 每确认帧无条件 `unit.blit(...)`（`fe/unit/AuthorityAnimation.as:15-20`），这是最明确的一处“B 退化/未移植”。A 细节归另一位审计员，本报告只列对应位置。

---

## 1. 加入侧一帧到底做了什么（receive → apply → present → display）

### 1.1 每条网络消息（socket 事件 / 每消息）

| 步骤 | 代码位置 | 频率/备注 |
|---|---|---|
| socket 数据进缓冲 | `Link.onData`（`Link.as:84-90`） | 每个 `SOCKET_DATA` 事件；`buffer` 增长，超过 64 KiB 且“已消费前缀≥剩余”才 compact（`:124-135`） |
| 批量拆包 | `Link.drain`（`Link.as:91-123`） | 每次 drain 最多 8 ms（`:94`）；每包 `new ByteArray` 复制 payload（`:101`） |
| 线格式解码 | `WireCodec.decode`（`WireCodec.as:21-30`） | **每消息**；TAG/flags 检查、`readBytes` 到 body（第二次复制，`:25`）、必要时 `uncompress`（`:26`）、AMF3 `readObject`（`:27`）、尾字节检查 |
| 消息分发 | `RConnectMod.receive`（`RConnectMod.as:220-259`） | 每消息；probe/exploration/chat/leave 各早退分支 |
| 帧消息处理 | `receive` frame 分支（`RConnectMod.as:249-253`） | **每条 frame 消息**；`NativeIntents.replaying++`、`replica.apply(value)` |
| 不可见 `label` 重设 | `RConnectMod.as:252`（`label.visible=false` 见 `:96`） | **每条 frame 消息**一次 String 拼接 + `TextField.text` 赋值；label 从未显示 |
| 差异解码 | `ClientReplica.apply`→`decoder.decode`（`ClientReplica.as:60-63`；`FrameDelta.as:13-51`） | **每条 frame 消息**；`branch(prior)` 复制根（`:21`），按 change 路径逐段 clone（`:34-41`），grouped update 原地写（`:43-46`） |
| 时钟/确认 | `prediction.confirm`、`clock.push`（`ClientReplica.as:64-67`；`MovementPrediction.as:17-29`；`PlaybackClock.as:25-39`） | 每 frame 消息；`clock.push` 的 boundary 为真时才 `present(true)`（`ClientReplica.as:67`） |
| 边界立即刷新 | `ClientReplica.present(true)`（`ClientReplica.as:67`、`:69-89`） | 仅 boundary：首帧/换房/pauseEpoch/timeControl phase、cycle/玩家 epoch、roomEpoch 变化（`PlaybackClock.as:27-31`）；**一次回调内可能连续 render 多个积压确认** |

### 1.2 每个屏幕帧（`Event.ENTER_FRAME`，加入侧）

| 步骤 | 代码位置 | 频率/备注 |
|---|---|---|
| ENTER_FRAME 入口 | `RConnectMod.as:97-98`（监听）、`:104-175`（`before`） | 每屏幕帧 |
| HUD 刷新 | `RConnectMod.as:113-115` | 每 100 ms 一次；`ui.refresh()`+`hud.refresh()`；HUD 折叠/隐藏时仍 layout（`NetHud.as:289`、`:401-419`、`:387-396`） |
| join 暂停本地世界 | `RConnectMod.as:147` | 每帧写一次 |
| 投掷物预选择 | `RConnectMod.as:148-150`→`ClientReplica.projectileSelection`（`ClientReplica.as:38-50`） | 每帧调用但先判 `!ctr.keyTele` 早退；**按 Q 时**建 targets 数组并跑一次全场景 `scene.selection`（`:41-42`） |
| 显示推进 | `RConnectMod.as:151-155`→`ClientReplica.present`（`ClientReplica.as:69-89`） | 每屏幕帧；见 1.3 |
| 存档确认 | `RConnectMod.as:154`→`PersonalSaves.confirm`（`PersonalSaves.as:24-38`） | 每屏幕帧调用；有请求时同步 `world.saveGame(slot)`（`:34`），可能是一次长帧 |
| 偏好应用 | `RConnectMod.as:157`→`applyPreferences`（`:271-286`） | **每屏幕帧**构造 5 元数组 + `join(":")`（`:277`）；join 分支实际用不到 host 那段 |
| 输入打包/发送 | `RConnectMod.as:158-170`→`InputSource.frame`（`InputSource.as:12-33`）+`Link.send`（`Link.as:30-38`）+`WireCodec.encode`（`WireCodec.as:11-20`） | 每屏幕帧：43 个键读取、`flight.concat`+`slice` 两次数组分配（`InputSource.as:27-29`）、AMF3 编码、socket flush |
| 探索 | `RConnectMod.as:172`→`SharedVision.step`（`SharedVision.as:28-38`）；另有 ENTER_FRAME `requestRender`（`:19`）与 RENDER `render`（`:20`、`:131-136`） | `step` 内部 100 ms 节流；`requestRender` **每帧** `stage.invalidate()`，RENDER 每帧 `apply`（`:137-151`） |

### 1.3 每个屏幕帧的 present 内部（`ClientReplica.present`，`ClientReplica.as:69-89`）

| 步骤 | 位置 | 频率/数量 |
|---|---|---|
| 取播放队列 | `clock.take`（`PlaybackClock.as:40-51`） | 每帧；`pending.shift()` 排队元素（`:46`） |
| 逐确认 render | `for each(state in ready) render(state)`（`ClientReplica.as:74`） | 每个“已到播放时间”的确认 1 次；边界 flush 时 N 个 |
| 插值 pose 构建 | `PoseTween.frame(current,next,fraction)`（`ClientReplica.as:76-77`；`PoseTween.as:99-158`） | 每屏幕帧（`fraction>0` 时）；遍历 2 玩家 + 全部 scene.units/objects/effects + projectiles |
| 插值 render | `render(tween,true)`（`ClientReplica.as:78`） | 每屏幕帧（同上），见 1.5 |
| 本地预测 | `predict()`（`ClientReplica.as:81`、`:91-98`；`MovementPrediction.as:33-71`） | 每帧；通常 <0.01 ms（profile） |
| 光照 | `scene.light(displayFrame.paused)`（`ClientReplica.as:83`；`ReplicaScene.as:159-165`） | 每帧；仅黑房 |
| 指针扫描 | 建 `targets` 数组（`ClientReplica.as:85`）+`scene.pointer(targets)`（`:86`；`ReplicaScene.as:27-32`→`:35-53`） | **每帧**遍历所有 units/objects/effects/extra；每个对象 4–5 次 `NativeAccess.get`（try/catch）+ `isFinite`，并对每个命中对象写 `onCursor`（`:51`） |

### 1.4 每个“确认帧”的 render（`ClientReplica.render`，`ClientReplica.as:99-189`）

| 步骤 | 位置 | 频率 |
|---|---|---|
| `view.prepare`（RV 桥） | `:101` | 每 render |
| Map 状态 | `:103`→`MapState.apply`（`MapState.as:20-47`） | 仅确认帧（非插值）；完整 land 字段 + 已访问房间循环（`:41-45`） |
| 时控呈现 | `:104` | 仅确认帧 |
| 场景应用/插值 | `:105`（`scene.interpolate`）/`:106`（`scene.apply`） | 插值帧/确认帧各一次 |
| 房间可见性 | `:113` `frame.room===access.roomKey()` | 每 render 重建 room key 字符串（`NativeAccess.as:98-101`） |
| 角色/原生 UI | `:114-132`：`CharacterState.apply`、`grafon.warShadow`、GUI modal、菜单、Stand、消息 | 仅确认帧；`CharacterState.apply` 遍历背包/护甲/物品/效果（`CharacterState.as:35-69`） |
| 两名玩家 | `:134-142`→`applyPlayer`（`:190-265`） | 每 render（确认帧和插值帧都会！） |
| 投掷物 | `:144-167` | 每 render；见 1.6 |
| 显示树清理 | `:169-173`→`scene.prune`（`ReplicaScene.as:57-73`） | **每 render**；建 keep Dictionary、枚举 6 层所有子节点并移除不在 keep 的 |
| 原生 HUD 4 件套 | `:174` `gui.setHp/setMana/setWeapon/setPet` | 仅确认帧；`GUI.setHp` 内部会写 `hp.text`（反编译 `game-reference/decompiled/1.02/src102/scripts/fe/inter/GUI.as:938-948`） |
| 桥呈现 | `:175-177` weapons/addons/injury | 仅确认帧 |
| 声音 | `:178`→`SessionSound.apply`（`SessionSound.as:67-70`） | 仅确认帧 |
| SATS 重建 | `:179-186` | 仅 SATS 暂停且 epoch 变化（罕见但贵） |

### 1.5 每个“插值帧”的 render（`render(tween,true)`）

- `scene.interpolate`（`ReplicaScene.as:168-183`）：对**每个 scene.units** 做 `NativeFields.motion`（10 个字段循环，`NativeFields.as:119-121`）+ `VisualPose.motion`（整棵显示树）；对每个 unit 再 `healthBar(...,true)`（`:173-174`）；对每个 object 做 motion（`:177-181`）；`effects.interpolate`（`:182`；`SceneEffects.as:57-66`）对每个 effect 做 `SpeechScale.localPose`+`VisualPose.motion`。
- `applyPlayer(interpolated=true)`（`ClientReplica.as:135-142`、`:190-265`）：仍执行 `setPos/setVisPos/scale/hp` 等（`:231-234`），并且 **`:235`、`:260` 仍调用 `VisualPose.apply` 而非 `VisualPose.motion`**；`:253` 才是有条件的 `NativeFields.apply`。
- `VisualPose.motion` 每节点都要 `parent.getChildByName(child.n)` + `getQualifiedClassName`（`VisualPose.as:194-199`）；这是全树逐节点线性查名。

### 1.6 每单位/记录/显示对象的成本点（确认帧）

| 对象 | 每确认帧工作 | 位置 |
|---|---|---|
| 每个 scene unit | 构造/换 clip（新单位）→ `NativeFields.apply(u.fields)`→`NativeFields.apply(u.inter)`→attach+`setVisPos`→`AuthorityAnimation.apply`（`unit.blit` copyPixels）→血条判定（附着的 hpbar **无条件** `addChild` 到第 3 层）→`VisualPose.apply(u.vis)`→`healthBar`→逐武器 apply | `ReplicaScene.as:184-241`；`:209`、`:212`、`:214-224`、`:225-226`、`:227-236`；`AuthorityAnimation.as:15-20`；反编译 `Unit.as:2863-2868` |
| 每个 hpbar | `HealthBarPose.apply`→`VisualPose.apply/motion` 整棵血条树；实测 compact 资格不命中（见 §3） | `ReplicaScene.as:294-302`；`HealthBarPose.as:101-105`、`:107-129` |
| 每个 object | `NativeFields.apply(o.fields)`、Interact、shadow 重建/apply、attach、`VisualPose.apply` | `ReplicaScene.as:242-269` |
| 每个 effect | `SceneEffects.apply`：必要时建 clip/BitmapData，**每个 effect 每个确认帧 `addChild`**，`SpeechScale.localPose`，随后 `decorations.apply` 或 `VisualPose.apply`；结束时清缺失记录 | `SceneEffects.as:16-56`；`:34-43`；`:55` |
| 每个 projectile | `applyProjectile`：空 `clip` 早退；新建显示；parent 不符才 addChild；坐标/旋转/缩放；`VisualPose.apply`/gotoAndStop；grip 指针对象；另加 `projectiles` 清理循环 | `ClientReplica.as:144-167`、`:266-296`；`:267`、`:281-282`、`:283-294` |
| 每个玩家 | `applyPlayer`：两玩家均整树 apply（确认/插值都）；held/action 对象；武器创建与 apply | `ClientReplica.as:190-265` |
| 每条 frame 消息 | 上述 decode/apply/label | 1.1 |

### 1.7 测量数字（profile-03 03-A join；80 敌 / 30 s，插桩构建）

| 分项 | n | 均值 ms | p95 | 最大 | 说明 |
|---|---:|---:|---:|---:|---|
| `client.present` | 630 | **18.80** | 33 | 66 | 每屏幕帧 present（≈21 fps） |
| `client.render`（每次 render 调用，混合确认/插值） | 1025 | 8.60 | 21 | 45 | 合计 8.8 s/30 s |
| `client.tween`（PoseTween.frame） | 622 | **4.54** | 9 | 48 | 每屏幕帧构建插值快照 |
| `client.sceneAndMap`（含 scene.apply/scene.interpolate/map） | 1025 | 5.43 | 13 | 43 | 离散帧被插值帧摊薄 |
| `replica.units`（仅 scene.apply 的 unit 段） | 403 | **10.41** | 14 | 19 | 每确认帧；最大单项 |
| `client.players` | 1025 | 2.24 | 6 | 16 | 两名玩家；确认+插值 |
| `replica.objectsAndEffects` | 403 | 0.66 | 2 | 3 | 本次是 LMG 场景；爆炸/文字场景会增长 |
| `client.character` | 403 | 0.58 | 1 | 3 | 背包/护甲/效果循环 |
| `client.prune` | 1025 | 0.27 | 1 | 7 | 每 render |
| `client.pointer` | 630 | 0.29 | 1 | 2 | 每屏幕帧；按 Q 时另有一次 selection |
| `client.decode`（仅 FrameDelta） | 404 | **6.08** | 15 | 62 | 每条 frame 消息 |
| `network.receiveBatch` | 433 | 7.14 | 17 | **63** | 含 AMF3/解压/apply 等，未再细分 |
| `wire.serialize`（join 自己的输入） | 707 | 0.08 | 1 | 2 | 每屏幕帧发送 |

对照 8 敌：`client.present` 8.84（n=864，≈28.8 fps）、`client.decode` 1.48、`replica.units` 1.09、`client.tween` 1.56、`receiveBatch` 2.25。  
对照 80 敌主侧（同一 profile-03 03-A）：30 s 只 publish 404 次（≈13.5 次/s），`host.publish` 均 33.2 ms、p95 54、最大 79 ms；这解释了为什么“主侧卡→确认变稀→加入侧插值时间变长”。

---

## 2. 战斗场景的增长点（按预估影响排序）

> 排序综合：分项测量（80 敌 LMG）× 代码里随弹丸/敌人/特效/数字/血条/文字增长的线性项 × 真实战斗会放大但未测的项。**“未验证”= 本轮无直接测量。**

### P1. 每个确认帧把所有单位完整重放（最大，线性于敌人数）

- 机制：`scene.apply` 对 `s.units` 全量 `applyUnit`（`ReplicaScene.as:147`、`:184-241`）：字段 apply（`:209`）、`unit.blit` 像素拷贝（`:212`）、血条整树（`:214-224`）、身体整树 `VisualPose.apply`（`:225`）、逐武器（`:227-236`）。**不区分该 unit 的确认状态是否与上一帧相同**。
- 增长维度：每敌人每确认帧；与敌人数量线性，与“状态变化比例”无关（未变化也重放）。
- 实测：`replica.units` 10.4 ms/确认帧（n=403，80 敌），是 join 最大单项；单位部分约占每次屏幕帧 render 的 1/2（4196 ms/30 s vs present 11844 ms/30 s）。
- 备注：`blit` 是 `BitmapData.copyPixels`（反编译 `Unit.as:2863-2868`）；A 的 tick 已在帧未变时跳过（见 §3）。

### P2. 每屏幕帧的插值构建 + 插值显示（线性于场景实体数，每帧都跑）

- 机制：`PoseTween.frame` 每秒 21 次遍历 2 玩家 + U 单位 + O 物件 + E 特效（`PoseTween.as:99-158`），对移动实体 `copy` 根/矩阵/子记录；随后 `render(tween,true)`→`scene.interpolate` 对同样实体跑 `NativeFields.motion`+`VisualPose.motion`（`ReplicaScene.as:168-183`）。
- 实测：`client.tween` 4.54 ms/屏幕帧；插值 render 还计入 `client.render`/`sceneAndMap`；合计约 6–9 ms/屏幕帧（80 敌，推算）。
- 放大点：`applyPlayer` 在插值帧仍 `VisualPose.apply`（`ClientReplica.as:235`、`:260`），相当于每帧对 2 名玩家做完整树 apply 而不是 motion；`VisualPose.motion` 每节点 `getChildByName`（`VisualPose.as:195`）。

### P3. 每条 frame 消息的解码（随“变化分支数”增长）

- 机制：AMF3 `readObject`（`WireCodec.as:27`，未计分项）→ `FrameDelta.decode` 的 clone-on-write：根/场景/单位数组/每个变化单位的 `fields`/`pose`/`healthBar`/`weapons` 分支复制（`FrameDelta.as:20-49`），以及 `changes` 路径数组的逐条解释。
- 增长维度：每条消息；变化单位数、动画分支数、每单位变化子记录数。密集战斗动画/弹丸多时 op 数增长 → clone 数增长。
- 实测：`client.decode` 6.08 ms/条（n=404，80 敌）；`network.receiveBatch` 7.14 ms、最大 63 ms；8 敌时 1.48/2.25 ms。**AMF3 解压/反序列化包含在 receiveBatch 但不在 decode 分项**，所以真正“收包解码”比 6.08 更高。
- 备注：没有发现同一 payload 被重复 decode；但存在“AMF3 反序列化 + delta 解释”两段，以及 payload 在 `Link`/`WireCodec` 被复制两次（`Link.as:101`、`WireCodec.as:25-27`）。

### P4. 特效/受击/伤害数字/粒子（真实战斗比 LMG 场景更大）

- 机制：每个 effect 每个确认帧：`SceneEffects.apply` 无条件 `grafon.visObjs[layer].addChild(rec.clip)`（`SceneEffects.as:40`；即使已是同一父节点的子对象，`addChild` 会移除再追加并触发显示列表事件），然后 `SpeechScale.localPose` + `DecorativeEffects.apply`/`VisualPose.apply`（`:41-43`）；每个插值帧 `VisualPose.motion`（`:57-66`）。伤害数字走 compact 模板时 `DecorativeEffects.motion` 通常会再进 `VisualPose.apply`（`DecorativeEffects.as:103-107`），其中 TextField 分支每次都比较 `htmlText`/`text`、写 `textColor`/`multiline`/`scroll`（`VisualPose.as:256-281`）。
- 增长维度：房间里同时存活的 Part/伤害数字/粒子/普通道具视觉数（E）；受击越密集、爆炸/火焰越多，E 越大；文本越多，TextField 分支越多。
- 实测：本次 80 敌 LMG 场景 `replica.objectsAndEffects` 仅 0.66 ms/确认帧（n=403），**不能代表真实火箭/喷火/群体受击场景**；预计真实战斗放大 2–5 倍以上（未验证）。
- 相关主侧增长：`SceneSnapshot.capture` 每帧扫 6 层全部子节点、对象链到 10000（`SceneSnapshot.as:127-172`），把所有未渲染的松散显示物做成 effect 状态；这既是主侧慢因，也决定 join 的 E 增长。

### P5. 血条（每个敌人每确认帧 + 每插值帧整树）

- 机制：`HealthBarPose.capture` 的 compact 资格 `known()` 要求 hpBar 根为 1 帧、armor/bar 为 `hp_bar4_243`/`hp_bar3_245` 且**子节点全部是 Shape**、无 filters/mask/scrollRect/scale9Grid（`HealthBarPose.as:36-67`；关键 `:50-52`）。实际 hpBar 的 armor/bar 内还有嵌套 MovieClip（`state/B-MEMORY.md:13`、`README.md:33` 记录），因此 `known()` 实测返回 null，走 `{kind:"full",pose:VisualPose.capture(...)}`（`HealthBarPose.as:23-25`）；join 的 `HealthBarPose.apply` 对 full 直接 `VisualPose.apply/motion`（`:101-105`），没有 compact 三部件路径可省。
- 增长维度：每个非玩家、可见、未死的敌人每确认帧 1 次血条整树 apply（`ReplicaScene.as:294-302`）+ 每插值帧 1 次整树 motion（`:173-174`）。
- 实测：包含在 `replica.units` 10.4 ms 内，未单独拆分（未验证占比；按 hpBar 树的嵌套 MovieClip 数量估计不可忽略）。
- 备注：smooth04 文档说“撤销血条缓存”指的是撤销 smooth03 对 HealthBarPose 的额外缓存实验；compact 校验代码本身属于基线（manifest 中 HealthBarPose 哈希 `4dadc097…`，source-04 不含该文件覆盖），不能把它当成 smooth04 新增收益；**实测命中 0 是 README 的资格记录**。

### P6. 每帧固定全量扫描（不随敌人数线性，但每帧恒在）

| 扫描 | 位置 | 频率 | 量级 |
|---|---|---|---|
| `prune`：keep Dictionary + 6 层全部子节点 | `ClientReplica.as:169-173`、`ReplicaScene.as:57-73` | 每 render（确认+插值） | 0.27 ms/次（80 敌） |
| `pointer`/`selection`：所有 units/objects/effects/extra，每个对象 4–5 次 try/catch 属性读 | `ClientReplica.as:85-86`、`ReplicaScene.as:27-53` | 每屏幕帧 | 0.29 ms/帧（80 敌） |
| 按 Q 时第二次 selection | `RConnectMod.as:150`+`ClientReplica.as:41-42` 与 `:85-86` | 按 Q 的每帧 | 重复一次全场景扫描（未单独测） |
| `projectiles` 清理：每个 projectiles 键 + `frame.projectileEvents` | `ClientReplica.as:144-167` | 每 render（含插值帧） | 0.10 ms/次（本次弹丸少） |
| `endedOrder` 退休 while | `ClientReplica.as:159-163` | 每 render | 与活跃 ended 数有关 |
| `SceneEffects` 缺失清理：枚举 records | `SceneEffects.as:55` | 每确认帧 | 与 effects 记录数有关 |
| `scene.apply` 的 units/objects 缺失清理 | `ReplicaScene.as:148`、`:152` | 每确认帧 | O(U+O) |
| `SharedVision.render`：整张房间 lightBmp 像素循环 ×2 条目 | `SharedVision.as:131-151` | **每 RENDER 事件**（`requestRender` 每 ENTER_FRAME invalidate，`:19`） | 约 `(spaceX-1)*(spaceY-1)*2` 次 `getPixel32`/可能 `setPixel32`；未插桩（未验证；30×20 房间约 1.2k 次/帧） |
| `SharedVision.step`→`remember`：整行字符串重建 + 逐行 merge | `SharedVision.as:28-38`、`:40-68` | 100 ms 节流（10 Hz） | 行数 ≈ spaceY；无 RV API 时每格一次 `Number/round/charAt/join`（未验证量级） |
| HUD 隐藏/折叠仍 `layout`+`nativeObstacles` | `NetHud.as:265-289`、`:387-396`、`:401-419` | 10 Hz | 9 个 GUI 子对象 getBounds + graphics 重绘 |

**结论**：`prune`/`pointer` 单独不大（合计 ≈0.56 ms/帧），但它们是“纯每帧浪费”，且 `SharedVision` 的两处全房间工作完全不在 join 分项口径内；先加计数器再决定是否值得改。

### P7. 每帧/每消息的固定杂项（单项小，叠加后不可忽略）

- `applyPreferences`：每屏幕帧 5 元数组+join（`RConnectMod.as:157`、`:277`）。
- `label.text`：每条 frame 消息 1 次 String + TextField 赋值，且 label 永远不可见（`:252`+`:96`）。
- `GUI.setHp/setMana/setWeapon/setPet`：每确认帧 4 次（`ClientReplica.as:174`）；`setHp` 直接写 `hp.text`（反编译 `GUI.as:938-948`）。
- `MapState.apply`：每确认帧完整 land 字段 + 已访问房间循环（`MapState.as:20-47`），无 state 身份短路。
- `CharacterState.apply`：每确认帧遍历背包 weapons/armors/items/effects（`CharacterState.as:35-69`）；物品越多越慢，但通常 <1 ms。
- `grafon.warShadow()`：每确认帧设置 colorTransform/blendMode（反编译 `Grafon.as:357-369`）。
- `sound.apply`：每确认帧遍历事件并启停声道（`SessionSound.as:67-70`）。
- 输入编码+flush：每屏幕帧一次 AMF3 编码 + socket 写（`Link.as:30-38`；`wire.serialize` 0.08 ms/次，80 敌）。
- `PlaybackClock.pace`：每条消息在样本≥4 后做两次 `concat().sort()`（≤32 元素）（`PlaybackClock.as:13-20`）。
- HUD 10 Hz：`HudModel.refresh` 建 peer 对象/数组（`HudModel.as:28-45`），`NetHud.refresh` 即使折叠也 layout（见 P6）。

### P8. 突发/长帧（可能解释 292 ms 首间隔与战斗尖峰；部分为假设）

1. **边界 flush**：`Clock.push` 返回 boundary 时 `apply()` 立即 `present(true)`（`ClientReplica.as:67`），`take(flush=true)` 把 `pending` 里所有 `time<=last.time` 的确认一次取完（`PlaybackClock.as:40-47`），`present` 对每个 ready 连续 `render`（`ClientReplica.as:74`）。换房/暂停/时控/epoch/首帧都可能触发；若积压 N 帧，就是**一次回调内 N 次完整离散 render**（每次约 14–20 ms 量级）→ 100–300 ms 长帧的现成机制。profile 的 `client.present` 最大 66 ms、`client.render` 最大 45 ms；292 ms 未在该场景复现，不能直接归因，但这是最像的机制之一（**未验证**）。
2. **单条消息超预算**：`Link.drain` 的 8 ms deadline 只在 `message()` 之后检查（`Link.as:94`、`:110`）；一条 frame 消息自身就可能 20–60 ms（`client.decode` 最大 62 ms、`receiveBatch` 最大 63 ms 的实测），deadline 无法切分单条消息 → 收包事件本身造成长帧。
3. **房间 full 帧**：`SceneSnapshot.capture` 在 `full` 时整房间 tiles/units/objects/effects + map + character（`SceneSnapshot.as:40-197`）；`FrameDelta.encode` 发 `packet.full`（`FrameDelta.as:9`），join `FrameDelta.decode` 直接 `prior=packet.full`（`:15`）后全量 apply；换房/首次进入是已知贵路径。
4. **地形破坏触发 `drawLoc`**：`scene.apply` 在 tile 非 `hp/thre/indestruct` 字段变化且 ink 不能覆盖时设 `geometry=true`（`ReplicaScene.as:102-127`），随后 `w.grafon.drawLoc(room);w.cam.setLoc(room);` 并重挂所有单位/物件（`:136-143`）；源码注释明确“sustained fire 下完整 drawLoc 可能数百毫秒”（`:114-119`）。战斗破墙/火箭是 burst 来源。
5. **`saveGame` 同步**：`PersonalSaves.confirm` 在 `before()` 里同步调用 `world.saveGame(slot)`（`PersonalSaves.as:29-36`，调用点 `RConnectMod.as:154`）；加入侧确认到存档请求时可能单帧卡顿（未验证量级）。

### P9. 逐记录 new/Dictionary/数组拷贝（GC 压力，与 P1–P4 叠加）

- `FrameDelta.decode`：每消息根/场景/数组/单位记录/pose 分支 clone（`FrameDelta.as:20-49`、`:52-56`），`writable` Dictionary、`prefix/parents` 数组。
- `PoseTween`：每屏幕帧 `copy(a)`、`m.concat()`、`children.slice`、`keyed()` 索引对象（`PoseTween.as:12-64`、`:80-89`、`:99-158`）；`HealthBarPose.tween` 每单位 `copy(a)`（`HealthBarPose.as:131-149`）。
- `SceneEffects.apply`：`live` Object、每个新 effect 的 clip/BitmapData/atlas 拷贝（`SceneEffects.as:17-38`）。
- `VisualPose.apply`：对存在 managed 子节点的父，每次 `new Dictionary(true)` 做 live 集（`VisualPose.as:298-299`）；子记录数组 `slice/push`（`:107-117`）。
- `CharacterState.apply`：`old={}`、`effects=[]`（`CharacterState.as:62`）。
- `RConnectMod.applyPreferences`：数组+join 字符串（每帧）。
- `PlaybackClock.pace`：两次 concat+sort（每消息）；`SharedVision.remember`：每格/每行字符串（10 Hz）。
- `SceneSnapshot.capture`（主侧）：`rendered` Dictionary、每单位/物件/effect 记录对象、changed tile 值数组（`SceneSnapshot.as:48`、`:78-83`、`:89-101`、`:105-126`）——这既是主侧成本，也是 GC 导致“两侧都卡”的共同候选。

### P10. 未退休记录/保留池现状（结论：未发现无限泄漏；有界池仍会变大）

- join `endedProjectiles`/`endedOrder`：结束弹丸投影事件每条进入一次；按 `frame.tick - tick > 240` 退休（`ClientReplica.as:146-163`），数组到 256 且半空时 slice（`:162-163`）。**空 `clip` 的爆炸辅助弹丸也会进池**（ended 记录在 `:149-154` 建立，`applyProjectile` 在 `:267` 早退），A 版同类“无显示爆炸记录不退休”已修（`state/a-stutter-investigation-2026-10-28.md:12-28`）；B 是有界但按发数增长，火箭/爆炸密集时值得计数确认。
- `SceneEffects.records`：强键 `id`，每次确认帧 `apply` 的 `live` 对比删除（`SceneEffects.as:55`）；只要持续有确认帧就会清；停帧期间保留（正常）。
- `PlaybackClock.pending`：受 `delay`（65–250 ms）限制；`take` 每帧 shift（`PlaybackClock.as:40-51`）。
- `NativeFields`/`VisualPose`/`DecorativeEffects`/`PeerFlights`/`TerrainInk` 等缓存：均为 `Dictionary(true)` 弱键（`NativeFields.as:8-11`、`VisualPose.as:22-29`、`DecorativeEffects.as:11-13`、`TerrainInk.as:12`），未发现 join 侧强引用越积越多。
- `ReplicaScene.units/objects/effects`：按 key 删除；room change 走 `dispose()`（`ReplicaScene.as:78-93`、`:314-322`）。
- 待查（未验证）：`endedOrder` 中空 `clip` 记录峰值、`SceneEffects` 记录峰值、房间 full 帧后旧 room 的 weak 缓存滞留。

### P11. JSON/字符串开销（结论：JSON 不在 join 热路径；热字符串另有其处）

- **JSON 不是每帧/每消息成本**：join 侧 `JSON.parse(JSON.stringify(...))` 只在连接时 `NativeAccess.profile()`（`NativeAccess.as:47-55`）与手动 addon action（`RConnectMod.as:345-348`）；`VisualPose.recipeKey` 的 `JSON.stringify` 只在 capture 侧（主机）用于不可变 filters/color 元组缓存（`VisualPose.as:32-36`），join 的 apply/motion 不复用该路径。
- 真正的热字符串：`label.text`（每 frame 消息，`RConnectMod.as:252`）；`getQualifiedClassName`（`VisualPose.motion/apply` 每显示节点，`:196-197`、`:301-303`）；TextField 的 `htmlText`/`text` 比较与 `textColor/scroll` 写（每 effect/文本每确认帧，`:256-281`）；`applyPreferences` 的 `join(":")`（每屏幕帧，`:277`）；`NativeAccess.keyFor/roomKey` 字符串拼（每 render，`:113`；`NativeAccess.as:98-101`）；`PlaybackClock` 无数值字符串但每消息排序；`SharedVision` 10 Hz 行字符串重建。
- 未发现 join 侧把 AMF3 payload 转 JSON 或 base64 的路径（`PixelSurface` 用二进制 ByteArray，`PixelSurface.as:9-14`）；A 旧的 base64 诊断路径不属于 B 产品。

---

## 3. 与 A 版已知优化点的对应（只做线索，A 细节由另一位负责）

| B 现状（file:line） | A 的对应/已知做法（只读线索） | 判断 |
|---|---|---|
| 每确认帧无条件 `AuthorityAnimation.apply`→`unit.blit` copyPixels（`fe/unit/AuthorityAnimation.as:15-20`；反编译 `Unit.as:2863-2868`） | A `RConnectAnimationAccess.tick` 用 `painted[unit]` 记录上次 blit，帧未变不重绘（`build/github-a-release/src/fe/unit/RConnectAnimationAccess.as:86-113`）；A UnitPresentation 有 `rec.pose`/`observe`/`tick` 快速路径（`rconnect/game/UnitPresentation.as:241-322`、`:405-415`） | **B 明确缺“未变帧跳过”**；A 已实测“身体不变帧”下降（`state/MEMORY.md:60` 的记录 194/347→49/349） |
| join `endedProjectiles` 240 tick 退休 + 空 clip 记录（`ClientReplica.as:146-163`、`:267`） | A 发现并修“无显示爆炸辅助弹丸记录不退休”（`state/a-stutter-investigation-2026-10-28.md:12-28`；`ProjectileVisuals` 的 `endSentAt`/700 ms 清理与 `recorded` 分支，`:114-134` 的 `mergeFlight`） | B 不是无限泄漏，但**同类对象仍保留 240 tick**；A 的结束事件/清理策略可作对照，需计数验证 |
| hpbar 每确认帧 full 树 apply（`ReplicaScene.as:294-302`；`HealthBarPose.as:36-67` 的 compact 不命中） | A 用 `MirrorHitUnit`/`MirrorMasks` 维护原生镜像对象；A 记录 `MirrorMasks.capture` 实测 29 ms（`state/MEMORY.md:82`），并按原生对象复用（`rconnect/game/MirrorMasks.as:94` 起） | A 是“镜像对象 + 一次性/差异维护”，B 是“每帧完整 pose 重放”；**架构差异，不能直接搬**，但可借鉴其“只在原生变化时刷新”的口径 |
| 每屏帧 `PoseTween.frame` 全场景遍历 + 每节点 `getChildByName`（`PoseTween.as:99-158`；`VisualPose.as:194-199`） | A `RemoteMotion` 按单位 push/sample 时间窗插值，按 slot/id 直接定位；`UnitPresentation.apply` 用记录的 `rec`/`slot` 而非泛型按名查找（`rconnect/game/RemoteMotion.as:55-113`、`:237-256`；`UnitPresentation.as:284-322`） | B 是通用显示树 diff/插值；A 是类型化记录。线索：B 的按名查找/整树 copy 是可优先替换的通用层 |
| `WireCodec` AMF3 + `FrameDelta` 路径 op（`WireCodec.as:21-30`、`FrameDelta.as:13-51`），decode ≈6 ms/消息 | A `rconnect/net/BinaryMessageCodec.as`（126 行）为自有二进制协议；A 文档还提到“加入侧自己的完整快照被主侧回传，直到接收应用才跳过”的旧机制（`state/MEMORY.md:38`） | 未量化对比；**不能先验认定 A 更快**。建议 A 审计员对比 codec 布局/字段裁剪；B 的 6 ms 值得按“AMF3 vs FrameDelta vs branch clone”拆开 |
| `SharedVision` 每帧 invalidate + 整房间像素循环（`SharedVision.as:19-20`、`:131-151`），10 Hz 全行重建（`:28-38`、`:40-68`） | A `ExplorationSync`/`RoomSync` 的探索同步；本次未审 A 细节 | 线索：B 的探索显示更新频率/范围可参照 A 的批处理；属显示层，不动同步结果 |

> 边界：本节只列“可能缺失/退化”的对应点；A 的准确收益、门槛、失败记录由 A 审计员负责，不能用本表替代 A 结论。

---

## 4. 优化候选（不改变同步语义/伤害/动画结果）

> 约定：所有候选只改“显示侧/工作调度”，不改 `FrameDelta` 线上字段语义、不改 `PlaybackClock.delay` 默认值、不改预测/伤害/动画帧选择、不降发包频率。收益量级用 profile-03 分项与代码线性关系估计；**除特别注明外均为未实测**。验证统一复用既有场景与门槛，并补计数器。

### 可先做（低风险，不需要先做大规模实测）

#### C1. 去掉每帧/每消息的确定性浪费（label + applyPreferences）

- 机制：`label` 永远 `visible=false`（`RConnectMod.as:96`），但每条 frame 消息仍 `label.text=...`（`:252`）；改为只在首次/notice/fail 时设置。`applyPreferences` 在 `RConnectMod.as:157` 每帧调用，`:277` 每帧建数组+join；改为“role==host 且偏好/策略变化时”才构建（join 分支根本不用 policy 串）。
- 预期收益：极小（<0.1 ms/帧量级），但零语义风险；顺带消除每消息的不可见 TextField 布局。
- 风险：notice/fail/role 文案路径必须仍更新。
- 验证方式：`notice`/`leave`/`FATAL` 日志与 HUD 文案断言；与性能无关的功能冒烟。
- 涉及：`RConnectMod.as:96`、`:157`、`:252`、`:271-286`。

#### C2. `SharedVision` 按需刷新，而非每 RENDER 全房间扫描

- 机制：`requestRender` 每 ENTER_FRAME `stage.invalidate()`（`SharedVision.as:19`），`render` 每 RENDER 对 `own[key]` 与 `memories[key]` 各跑一遍 `(spaceX-1)*(spaceY-1)` 的 `getPixel32/setPixel32`（`:131-151`）。改为：仅在 `own[key]`/`memories[key]` 版本变化、房间切换、`retDark`/native relight（`room.relight_t` 或 `grafon` 重绘）时标记 dirty 再 apply；`step` 的 `remember` 10 Hz 也只在 `room.space/visi` 变化或节流更低频时重建行缓存。
- 预期收益：估计 0.2–1 ms/帧（随房间格子数/条目数线性；未实测），并去掉每帧强制 `invalidate()` 对 AIR 帧调度的扰动。
- 风险：探索遮罩/黑暗显示可能晚 1 帧或漏一次 native 重绘后的重应用；**不改任何同步/战斗结果**，但属视觉显示。
- 验证方式：暗房/探索/RV 开关的像素对照（已有 visualfield/exploration 场景）；`own/memories` 行合并的既有断言；`SharedVision.receive` 前后不动。
- 涉及：`SharedVision.as:19-20`、`:28-38`、`:40-68`、`:109-130`、`:131-151`。

#### C3. 玩家插值帧改用 `VisualPose.motion`

- 机制：`applyPlayer` 在 `interpolated=true` 时仍 `VisualPose.apply(g.vis,state.visual)`（`ClientReplica.as:235`）和武器 `VisualPose.apply(v,w.visual)`（`:260`）；与 `scene.interpolate` 的契约一致，插值帧应只做 `motion`（变换），离散属性留到确认帧 apply。
- 预期收益：`client.players` 2.24 ms/渲染（n=1025）中插值帧部分可省，估计 0.8–1.5 ms/屏幕帧（未实测）。
- 风险：本地原生/其他模组在两次确认之间对玩家 vis 的修改（滤镜/文字/子节点）不会在插值帧被恢复；确认帧仍会 apply。需回归 body/weapon 视觉与 RV 开/关。
- 验证方式：`textmotion`、`visualfield`、`ui` 既有断言 + 玩家身体/武器像素与滤镜对照；插值帧内不发确认帧的静止/移动两种状态。
- 涉及：`ClientReplica.as:222`、`:235`、`:253`、`:260`。

#### C4. `PlaybackClock.pace` 去掉每消息排序（小项，可随 C1 一起）

- 机制：每 push 在 `intervals.length>=4` 时 `intervals.concat().sort(...)`+`jitter.concat().sort(...)`（`PlaybackClock.as:13-20`），元素 ≤32；改为维护有序副本/仅在新样本时更新，或按固定窗口用插入。保持 `wanted=Math.max(65,Math.min(250,p90+late+15))` 不变（`:20`）。
- 预期收益：<0.1 ms/消息；主要是减少分配。
- 风险：低；必须保持 delay 数值与 65–250 边界完全一致。
- 验证方式：同输入帧序列的 `delay` 逐帧日志对比；密集播放等待分布（162–168 ms 基线）不退化。
- 涉及：`PlaybackClock.as:8-24`。

### 需要实测确认（收益更大，但需先计数/拆项）

#### C5. `SceneEffects.apply`：只在需要时 addChild/重放完整 pose

- 机制：每个 effect 每个确认帧都 `addChild`（`:40`）并 `VisualPose.apply`（`:43`）；改为：
  1) 仅当 `rec.clip.parent !== target` 或层/顺序变化时 addChild；
  2) 记录 `rec.appliedState`，当 `rec.appliedState===s`（FrameDelta 不可变分支）且 `decor.recipe` 未变时，仅确保在树上，跳过 `VisualPose.apply`；插值帧仍走 motion。
- 预期收益：与 E 线性；本次 0.66 ms/确认帧，真实爆炸/文字场景预计更大；可省该段 20–50%（未实测）。
- 风险：显示层恢复语义（本地/其他模组对 clip 的修改不再每帧恢复）、z 序（顺序变化时必须重新 addChild）；需保留“新 effect/顺序变化/层变化”路径。
- 验证方式：`rockets`/`enemies`/`textmotion` 的原生断言 + 伤害数字/粒子层级截图；计数器统计 `addChild` 次数与跳过次数；比较 display list 顺序。
- 涉及：`SceneEffects.as:16-56`、`:57-66`；`DecorativeEffects.as:92-107`。

#### C6. 单位确认帧按状态身份短路（以及“只有变换变化时走 motion”）

- 机制：`ReplicaScene.applyUnit` 对每个 unit 无条件重放 `NativeFields.apply`/`unit.blit`/`VisualPose.apply`/hpbar/武器（`:184-241`）。利用 `FrameDelta` 未变化时返回同一对象身份（`FrameDelta.as:20-49`）：
  1) `rec.lastState===s` 且 attach/层/hpbar 外层未变 → 只做必要的位置/可见性校验，跳过字段/pose/blit；
  2) 若 `s` 与上次的差异仅在 `pose` 矩阵/alpha/xy（`NativeFields.delta`/`VisualPose.delta` 可提示），则对 unit 用 `VisualPose.motion` 而非 full apply。
  必须保留 `unit.blit` 的 blank/animState 语义（`AuthorityAnimation.as:15-20`）。
- 预期收益：上限接近 `replica.units` 的 10.4 ms/确认帧；实际取决于“未变化/仅变换变化”的单位比例（**未测**，建议先加计数器）。密集移动敌人时收益低，静止/半静止与 LR 战斗收益高。
- 风险：本地原生对 unit/visibility 的修改不会恢复；blit 跳过的 GPU 纹理上传收益需实机确认（copyPixels 后可能有隐式上传）；需保持 A 的“帧未变不重绘”等价语义（见 §3）。
- 验证方式：先只加计数器（unchanged ratio、motion-only ratio、每单位子项耗时）在 probe 构建；再做功能/像素对照（enemies、textmotion、rockets、UI）；AB 门槛沿用 `b-smooth-clean` 的 5%/P95/1.2 重复规则。
- 涉及：`ReplicaScene.as:184-241`、`:147`；`AuthorityAnimation.as:15-20`；`FrameDelta.as:20-49`。

#### C7. 放宽 hpbar compact 资格（并保留 full 回退）

- 机制：`known()` 因 armor/bar 内嵌套 MovieClip 而返回 null（`HealthBarPose.as:36-67`，关键 `:50-52`），导致每个敌人血条走 full `VisualPose.apply/motion`。可定义“稳定三层”compact：只捕获/插值 armor/bar/goldstar 的矩阵/alpha/currentFrame/可见性，保留 root 子项顺序；任何未知/嵌套动画、filters/mask/scrollRect、boss/特殊护盾仍走原 full 回退。
- 预期收益：血条部分在 `replica.units` 内的占比（未拆项；估计 1–3 ms/屏幕帧，需实测）可大幅下降；随敌人数线性。
- 风险：嵌套动画/护盾/隐身 alpha/特殊血条（boss）会走错路径；必须沿用现有 full 回退条件并扩展像素对照。
- 验证方式：README 记录的 20 个真实损伤帧/Boss/隐身帧检查；`textmotion02`/`ui02`/`enemies` 的原生血条断言；compact/full 命中计数必须显式记录（防止再次“缓存未命中被当收益”）。
- 涉及：`HealthBarPose.as:22-34`、`:36-67`、`:101-129`；`ReplicaScene.as:294-302`。

#### C8. `VisualPose` 子节点查找缓存

- 机制：`motion`/`apply` 对每个子记录用 `parent.getChildByName(child.n)`（线性扫描）+`getQualifiedClassName`，失败再按索引兜底（`VisualPose.as:194-199`、`:301-304`）。为每个父节点维护 `name→DisplayObject` 缓存，`numChildren` 变化或 apply 增删子节点时失效；语义保持“名字优先（含 class 校验）→ 索引兜底”。
- 预期收益：每显示节点每 apply/motion 省一次线性查找；80 敌 × 每单位数十节点的确认帧 + 插值帧，估计 0.5–2 ms/屏幕帧（未实测）。
- 风险：重名子节点、动态子节点、managed 清理后的缓存失效；必须保持当前“名字命中但 class 不符时再按索引”的选择顺序。
- 验证方式：所有 pose 断言 + 逐节点 target 选择日志对比；RV mask/自定义子节点场景。
- 涉及：`VisualPose.as:188-201`、`:294-323`。

#### C9. 边界 flush 与收包预算的突发控制

- 机制：`ClientReplica.apply` 在 boundary 时 `present(true)` 同步 flush 所有积压确认（`ClientReplica.as:67`；`PlaybackClock.as:40-47`），`present` 对每个 ready 连续完整 render（`ClientReplica.as:74`）；`Link.drain` 的 8 ms deadline 在 `message()` 之后才检查，单条消息不可切（`Link.as:91-118`）。候选：
  1) 每次屏幕帧最多消费/渲染 K 个已到期确认（其余保序留到下帧；不丢弃、不改时间戳）；
  2) drain 的预算把“单条消息估算”纳入，或用更小的批上限（如 1 条）后 `setTimeout` 让出；
  3) 对 room/first full 帧仍保留一次完整 apply（不得拆散离散结果），只限制后续 flush 批次。
- 预期收益：不改善平均，主要压低 100–300 ms 级尖峰（292 ms 首间隔的机制假设，未直接证明）；profile `client.present` max 66 ms、`client.render` max 45 ms、`receiveBatch` max 63 ms 说明尖峰存在。
- 风险：确认显示延迟 +1 帧；首帧/换房时序需保证“tick 0 先完成再开战”（`HostSession.as:62-64`、`RoomRuntime.awaitingFirstView` 语义不能破）；不改变任何伤害/动画结果。
- 验证方式：长帧直方图（首间隔、P95/max、>100 ms 计数）与“确认不丢/不乱序”断言（ContractChecks 的 FrameDelta/PlaybackClock 场景）；播放等待 162–168 ms 不退化；实际双人换房/暂停/时控。
- 涉及：`ClientReplica.as:67`、`:69-89`；`PlaybackClock.as:40-51`；`Link.as:91-123`。

#### C10. 先拆 decode，再决定是否减少 clone/AMF3

- 机制：当前 `client.decode` 只含 `FrameDelta.decode`（`ClientReplica.as:61-63`），AMF3/解压未计时（`WireCodec.as:21-30`），payload 两次复制（`Link.as:101`、`WireCodec.as:25-27`）。第一步在 `Link.drain` 给 `WireCodec.decode` 加一个 `Timing` 分项（仅 probe 构建；产品 `Timing.enabled=false` 不变）。若 AMF3 占比高，再评估：
  1) 去掉一次 payload 复制（从 `buffer` 带偏移解码/复用 ByteArray）；
  2) `FrameDelta.decode` 的 clone 只在“旧帧仍被时钟/display 引用”时复制，或对 `prev` 不可达的字段原地更新（需要引用/所有权检查）；
  3) 重新评估 `changes` 路径 op 的解释成本，是否改为“按单位按字段的紧凑更新”（不改变值/顺序）。
- 预期收益：6.08 ms/消息中未知比例；估计 1–3 ms/消息的可见空间（未实测）。80 敌 13.5 消息/s 下相当于 0.3–1.5 ms/屏幕帧。
- 风险：不可变分支被 PlaybackClock/PoseTween 缓存共享，原地更新会污染插值；必须证明旧帧不再被引用。第二、三步属协议内部布局，**不改变同步语义**，但需要严格历史不可变测试。
- 验证方式：probe 构建的 decode 分项（AMF3 vs FrameDelta vs clone 数）；ContractChecks 的 FrameDelta history/旧缓冲不可变断言（`ContractChecks.as:361-430` 区域）；ABAB 性能门槛。
- 涉及：`ClientReplica.as:60-63`；`FrameDelta.as:13-51`；`WireCodec.as:21-30`；`Link.as:91-123`。

> 不建议在本轮动的项：输入发送频率（会改同步节拍）、`PlaybackClock.delay` 默认 65–250 ms（会改播放缓冲语义）、降低 host publish 频率（同步语义）、按距离剔除敌人（可能造成可见缺失）、删除 `NativeFields` 字段（会破坏 SATS/血条/武器/模组接口）。这些与用户“不改同步语义/伤害/动画结果”的约束冲突。
>
> 配合项（主侧，需与 A/主侧负责人协调，不计入 join 候选）：`SceneSnapshot.capture` 的 full 帧重复 `NativeFields.capture(room)`（`SceneSnapshot.as:45` 与 `:63`）是无谓的重复采集；`SceneSnapshot` 每帧扫 6 层全部子节点制造 effects 列表（`:161-172`），直接决定 join 的 P4 负载。

---

## 5. 建议的最小验证/插桩顺序（不改产品语义）

1. **只加计数器（probe 构建）**：每帧 `unchanged unit ratio`、`motion-only unit ratio`、`effect reapply/skip`、`hpbar compact/full`、`ended empty-clip count`、`flush renders per present`、`WireCodec.decode vs FrameDelta.decode vs branch clone count`、`SharedVision apply pixels/frame`。用这些数决定 C5–C10 的优先级；产品构建不加计时。
2. **AB 基准**：沿用 `b-smooth-clean-05` 的 8/80 敌人 × 60 s、持续 LMG、原 5% 平均/P95 与重复 1.2 门槛（`README.md:42`）；同时保留帧间隔直方图/长帧计数与播放等待分布（162–168 ms 边界）。
3. **功能回归**：`textmotion02`（主111/加124）、`rockets02`（57/57，2030 显示样本）、`ui02`（134/91）、`enemies`（原生断言）；任何显示树/血条/特效改动都要加层级/像素对照，而不仅是“无异常”。
4. **边界场景**：首帧/换房/暂停/时控/死亡复活/Epoch 变化时的 flush 次数与最大帧；Q 按住时 selection 双扫的对照；爆炸辅助弹丸峰值计数；破墙 `drawLoc` 的那一帧。
5. **不把单轮插桩或平均改善解释成用户所有战斗场景已流畅**；292 ms/162–168 ms 仍需真实慢帧拆项验证（本审计未复现）。

---

## 6. 未验证/限制

- 本审计没有运行游戏，没有复现 292 ms 首间隔、162–168 ms 播放等待或 1–2 px 回摆；相关“机制假设”已标 **未验证**。
- `replica.units` 10.4 ms 的**内部拆分**（fields / blit / VisualPose / hpbar / weapons）在 smooth04 源码上未单独插桩；数字只有总项。
- `SharedVision.render` / `HUD 10 Hz` / 输入编码 / AMF3 的每帧成本没有分项计时；本报告只给出代码路径与频率，量级标“估计/未实测”。
- 血条 compact 不命中依据 `state/B-MEMORY.md:13`、`experimental/b-smooth-20261029/README.md:33` 的实测记录；本轮只读源码核对了 `known()` 的严格条件（`HealthBarPose.as:36-67`），未重新跑游戏验证。
- 真实用户战斗中的特效/伤害数字/弹丸密度未知；P4 的放大倍数、P10 的 ended 池峰值都需要实际计数。
- A 侧只做了少量只读对照（`UnitPresentation`/`RConnectAnimationAccess`/`MirrorMasks`/`ProjectileVisuals` 的位置），**A 的收益、失败与边界由 A 审计员负责**；本报告不将其作为 A 结论。
- profile-03 03-A 是 smooth01 之前的现有 B 插桩构建；smooth04 约快 5.4%（密集平均），因此分项数字应理解为“偏保守/偏大的量级参考”，不是安装字节的精确值。

---

## 附录 A：本次核验的源码身份

- `build/ab/b190-visual-motion-smooth04-source/src`：129 个 `.as`；`stubs/`：15 个 `.as`；总计 144，与 `experimental/b-smooth-20261029/source-04/source-manifest.json` 的 `sources` 144 项逐项哈希一致（`src/RConnectMod.as` `bfc1d2b5…`、`authority/HealthBarPose.as` `4dadc097…` 等）。
- 版本串 `B3-0.1-smooth1`（`RConnectMod.as:19`）。
- 未使用陈旧顶层 `src/`。

## 附录 B：关键 file:line 速查

| 主题 | 位置 |
|---|---|
| ENTER_FRAME 入口/主循环 | `RConnectMod.as:97-98`、`:104-175` |
| 收包/帧分发 | `RConnectMod.as:220-259`、`:249-253` |
| 发送输入 | `RConnectMod.as:158-170`、`InputSource.as:12-33`、`Link.as:30-38` |
| 播放时钟 | `PlaybackClock.as:8-55` |
| 确认应用/解码 | `ClientReplica.as:60-68`、`FrameDelta.as:13-51` |
| 每屏帧 present | `ClientReplica.as:69-89` |
| 确认/插值 render | `ClientReplica.as:99-189`、`ReplicaScene.as:168-183` |
| 玩家显示 | `ClientReplica.as:190-265` |
| 投掷物 | `ClientReplica.as:144-167`、`:266-296` |
| 场景单位/血条/物件/特效 | `ReplicaScene.as:75-157`、`:184-241`、`:294-302`、`SceneEffects.as:16-66` |
| 显示树 copy/motion | `VisualPose.as:188-201`、`:202-324` |
| 字段 apply/motion | `NativeFields.as:86-121` |
| 子节点/滤镜/文字 | `VisualPose.as:232-281`、`:294-323` |
| 全帧扫描 | `ClientReplica.as:169-173`、`ReplicaScene.as:27-53`、`:57-73`；`SharedVision.as:131-151` |
| 10 Hz HUD | `RConnectMod.as:113-115`、`HudModel.as:28-45`、`NetHud.as:265-289`、`:387-419` |
| 边界 flush/burst | `ClientReplica.as:67`、`:74`；`PlaybackClock.as:40-51`；`Link.as:91-123` |
| 地形重绘/ink | `ReplicaScene.as:102-144`、`TerrainInk.as:84-102` |
| 存档单帧 | `RConnectMod.as:154`、`PersonalSaves.as:24-38` |
| A 对照 | `build/github-a-release/src/fe/unit/RConnectAnimationAccess.as:86-113`；`rconnect/game/UnitPresentation.as:241-322`、`:405-415`；`rconnect/game/ProjectileVisuals.as:114-134`；`rconnect/game/MirrorMasks.as:94+`；`state/a-stutter-investigation-2026-10-28.md:12-38` |
