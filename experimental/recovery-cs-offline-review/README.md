# CS 离线采集候选独立源码审核

2026-10-23。仅核对冻结源码及文件，未编译、未启动 AIR、未修改 CS 或 RC 生产源、未部署。计时审查另见同目录 `TIMING-REVIEW.md`。

## 准确对象

- 基线：`build/m52/coop-bundle-04`，正式 RC `574D2B51490AE8B25A1396555600F56A301F8A20AE50104C0E35CF2796441AFE`。
- CS 实验：`mods/ContinuousScene/build/generated/rc-offline-probe-20261023-r1`。
- 候选：`88CC639E8293FD38DFE4B4855ED2359F2DACF58A8DF18B3F7766B20AE1D0E968`。
- 来源证明：`0BE07E23517B619520D841B83913EDE88C28142604C6189F8E199C60FC5EC81C`。
- prepared：`4D0743B2FDD61586B22193C431E5D5FBA534D77CA33E0BC5483B2F286AE112B1`，与历史部署回执的 candidate/prepared 对应；历史回执中的其它模组组合不代表当前测试组合。
- 独立重算两套各 78 源 + 71 输入，共 298 个文件，无哈希失配。before 与准确 prepared 的 source/inputs 全部一致。仅 `RConnectMod.as`、`Session.as`、`GameBridge.as` 三源不同；另外 75 源及 71 构建输入不变。编译记录中的候选哈希与实际 SWF 相同。未重跑 CS builder。

## 产品行为与生命周期

限定试验在源码层面可继续验证，尚无运行或合入资格。

1. `Session.as:27–31` 默认 `offlineProbeEnabled=false`，只有开关开启、从未尝试联网且 `mode===OFFLINE` 才跳过。`startHost:195`、`startJoin:220` 在 `stop()` 前先令 `_networkAttempted=true`；该字段只有一次初始 false 和这两处 true，没有 leave、失败、断线、重试重置。现有标准启动路径均经过这两函数；无队友的 HOSTING 也保持原采集。
2. `RConnectMod.as:89–92` 在创建 Session 后、`autoStart()` 前绑定资格函数。载体只在测试 appID 前缀 `pfe-modsettings-continuous-motion-` 下安装。注意这是前缀限制，不是单个精确 appID 限制；本轮实际隔离还须由启动器的唯一 appID 和存储证据保证。普通安装默认不开启，仍有诊断判定开销，因此候选内部 A 不能自动代替未经改动的正式574D性能。
3. `GameBridge.as:62–73` 未绑定、返回非 true 或抛错均继续原采集。只包住 mirror 的 `presentation.observe/observePlayer/bodyEffects.observe` 与最终 RENDER 的相应三调用。`_wall.observe`、`_ports.observe`、`stage.invalidate`、整个 `onPerceptionFrame`、实际 apply/tick、SATS、`presentHeldVisuals` 均保留。
4. 正常 `Session.stop:275–301` 会调用 `GameBridge.endSession:207`；后者清 `_presentation` 与 `_bodyEffects`，同时清远端、弹道、念力等已有状态。`UnitPresentation.reset:406` 清 `hostShots`、弹链索引、frameTime，以及静态身体/近战观察表；`PlayerBodyEffects.reset` 清 observed/applied。首次联网的观察历史由此重新开始，与原版本原有启动清表流程相同。这里是成功执行 stop 的源码推论，不代替异常或连接实测。

## 被跳过的观察是否直接驱动本地画面

已顺着准确574D对应消费者核对，没有发现这些观察调用直接控制本地玩家/敌人的原生动画、AI、开火或护盾。

| 观察链 | 写入及消费者 | 本轮结论 |
|---|---|---|
| `UnitPresentation.observe` → `RConnectAnimationAccess.observe` | 静态 observed 字典，记录 MovieClip 帧/标签；由 capture 判定远端连续播放 | 只记录，不调用本地 goto/play/stop 或原生 animate |
| `observeWeapon` → `MeleeVisuals.observe` | 近战显示姿态历史；capture 后由接收端 apply 使用 | 读取矩阵/帧等，不改本地武器或斩击显示 |
| `observeWeapon` → `EnergyImpactVisuals.observeWeapon` | sources/claimed 和命中特效历史；capture→receive/tick | 本地 native Part 仅被读取，实际粒子显示不由此链推进 |
| `observeWeapon` → `ProjectileVisuals.beamFrame` / `ProjectileExplosionVisuals.capture` | 读取飞行/爆炸结果，保存发送记录 | 不调用爆炸、伤害、原生攻击或接收端播放 |
| `PlayerBodyEffects.observe` | 本地 shield 等8条路径的帧历史；capture 的 play 判定 | 读取 clip，不调用本地 apply；apply 本身也拒绝 `player===true` |

本地念力特别核对：`GameBridge.presentHeldVisuals:886` 仍在 mirror 和 RENDER 执行，调用独立 `_telekinesis.tick(loc, gg.teleObj, ...)`；它不依赖 `_presentation` 的观察历史。远端武器光晕等由接收快照产生，而资格在任何标准联网尝试前永久撤销。保留调用是源码事实，实际图像等价仍待验证。

## 不可越过的证据边界

- 测试载体的 `setEnabled` 只切布尔，**不会清表**。A→B→A 会保留 A 的 `hostShots`、弹药计数与未结束事件。恢复观察时可能一次性看到计数差、补做历史清理。普通计时窗与切换成本必须分账；不能称ABBA两状态完全无历史。
- `observeWeapon` 先由 loc.units 采到的普通 assr/autor 事件一般 `recorded=false`，700ms 淘汰。特殊弹 `recorded=true` 的结束事件要求 `endSentAt>0` 后700ms淘汰，而 `endSentAt` 在 capture 中写入；纯离线不发快照的路径可能保留这类记录。源码条件成立，未测残留数量或耗时，不认定普通枪卡顿根因。
- 首次联网后的 `stop/endSession` 清表足以说明标准代码没有继承离线观察历史；但仍须原生操作验证 host无队友、join失败、leave、重新连接后计数不再跳过，及连接瞬间正在飞行的特殊弹、护盾、近战、念力视觉正确。不要把源审当作这些测试已完成。
- 先验证离线原生画面/功能及完整计时，再做准确候选的联网生命周期。任何离线收益不自动解决双人密集卡顿，也不赋予 early2 或其它整合候选资格。

本审核没有发现足以阻止这一限定隔离试验的源码回归；也没有宣称已优化、已修复或可部署。
