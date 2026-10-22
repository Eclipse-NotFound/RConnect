# 准确 22：运动游标与长空档成本交叉核查

结论：**没有找到可归因于这两次空档、可安全直接消除的全姿态重复计算或无界追帧循环。** 不提出新的生产候选。唯一建议的下一步是一次外部显示时间线诊断，区分“没有游戏帧/显示回调”和“回调持续发生但已收到的位置没有呈现”；不改插值策略、发送频率或原门槛。

本次只读准确 `build/m52/recovery-22/src`。GameBridge、UnitPresentation、RemoteMotion、WeaponDisplay 与准确 21 均逐字相同；具体 SHA 和原 CPU 筛选计数见 [evidence.json](evidence.json)。没有编译、AIR、源码/配置/旧结果修改。

## 三条实际链

| 对象 | 收包 | 显示取样 | 是否重复求全姿态 |
|---|---|---|---|
| 念力箱子 | `updateRemote:765 → receiveHeldMotion:907 → trackBoxPos:4641`；给 held motion 的数据只有 x/y/sampleTime | `onVisForceFrame:284 → tickBoxTweens:4731`，每次最终 RENDER 都可能取样 | **否。** 没有 weapons/visual，跳过武器插值，bodyPose 立即返回 null。收包 pushTimed 本身不 sample |
| 念力掉落物 | `receiveHeldMotion:918–922` 仅推 x/y/sampleTime；结束由 release 路径交回原生重力 | `onVisForceFrame:285 → tickLootMotion:3657` | **否。** 同上。持有超时、所有权、拾取、房间身份检查仍有必要 |
| 普通掉落 | `applyLootSync:3817–3896` 推 x/y/stay/sampleTime；fast 轨迹 500ms 内不被慢 full 重置 | 同一 `tickLootMotion`，暂停时 settle | **否。** 已知键复用对象；首次认领/构造另有成本，不能归给每次插值 |
| 远端玩家 | `updateRemote:810–817` push 后立即 sample/settle、driveGhost、接收弹体和传送 | `onMirrorFrame:355` 再 sample/driveGhost；RENDER `:269` 只读 currentSample | **可重复武器姿态求值。** 玩家的身体用 poseFrame/bodyFrame，通常没有敌人的 visual.pose.blit。此链不是念力物品自己的运动缓冲，也不能把全部 driveGhost 当成无效重播 |

`UnitPresentation.tick:407` 和 `animateBody:461` 只是读取 currentSample，不暗中再次推进 RemoteMotion。其敌人接收期 queue/sample 冗余已经被独立审查和别名反例限制；本次不换名称重做延后姿态，也不提出屏外裁剪。

## 游标、重复调用与循环上限

- `GameBridge.presentationTime:384` 使用本帧 `_sampleAt`（高优先级 ENTER `:374` 更新），暂停使用 `_coopPauseAt`。同帧额外 RENDER 会重复调用箱子/掉落取样，但正常 `sampleTimed` 的 elapsed 为 0，不会因调用次数多而额外追时间。仍会重算位置、执行对象放置；若期间收到新点/同戳修订，结果可能合理变化，不能仅凭时间相同跳过。
- `RemoteMotion.pushTimed:170` 把 frames 限制为 **32**，gap 为 **8**；`sampleTimed:228` 的 shift 循环最多移走 30 条以保留至少两点，`curve:304` 最多计算 4 个字段。没有按照 249ms 或 160ms 分拆成若干“补跑游戏帧”的循环。held 延迟上限 100ms；普通即时掉落允许缓冲上限 500ms，但这是**显示时钟策略，不是花 500ms 执行代码**。
- `settle` 将游标落在最后收到端点，再取样，不运行原生 AI/伤害/物理。旧协议无时间戳 push 确实前后各 sample 一次，但上述现代路径有 sampleTime；不能用兼容支路解释这次空档。
- 不把整个 RemoteMotion 宣称为严格常数成本：武器插值按 first/last 列表匹配，最坏 O(W²)；兼容 rot 的 while 规范化迭代次数依输入角度。显示路径 r 来自 atan2，普通原生武器列表较小，但本次未记录这些空档的全部武器长度/角度，既不能证明异常大输入，也不能擅自加截断或改角度语义。位置专用箱子/掉落不进入这段。
- `TcpLink.onData:161–209` 一次读当前字节，再同步派发缓冲内全部完整帧，没有按显示帧分摊的包数预算；每个包有 1MiB 限制，批次本身依已收字节量。**这是可批量工作的边界，不是已证明的死循环或此次长空档根因。** 不据此丢包、通用合批或改 ACK。

## 证据能连接到哪里

新原生复核的两个关键样本：

- `f8bc3462f4` 念力 round3：源加入侧相邻最终显示采样间隔 **219ms**，主侧观察 **249ms**；两侧都在持有中段，排除了释放/整段 JSON 输出时点。源自身也缺样本，无法仅用接收端的姿态计算解释全部现象。
- `60ccbb7140` 掉落 round0：加入侧显示采样 **31553→31713（160ms）**，对应后一位置已于 **31569** 收到。由此可排除“整个空档只是等待位置包”这一解释；但两套驱动均按游戏帧去重 RENDER，仍不能证明中间完全没有额外显示。

既有 CPU（不同运行，不拼成同一次因果链）：

| 加入侧 | CPU 样本 | sampleTimed 包含栈 | driveGhost | tickLootMotion / tickBoxTweens / receiveHeldMotion / applyLootSync |
|---|---:|---:|---:|---:|
| 043b72eaec，ENTER→最终 RENDER | 958 | 64 | 13 | 全 0 |
| b3d7b8558b，最终 RENDER→下一 ENTER | 1614 | 75 | 8 | 全 0 |

样本包含关系重叠，0 不是零耗时。这些密集诊断主要出现敌人链，不是上述念力/掉落场景。旧 after-render 已证明有长时间落在原采样窗外；新 Socket 诊断也证明某次 worldstate 同步派发占 100ms，且该批含三个不同 sampleTime 的 fast、零 full。但它没有同次内部 CPU 栈，也不对应 160/249ms 这两段。不能把 100ms 全归给 sampleTimed，更不能将 78秒 netMax 旧夹具污染值恢复成性能证据。

## 唯一有依据的下一试验（尚未实现）

在既有 continuity 的**同一掉落 round0** 做一个外部诊断变体；保留原驱动全部操作、去重后的原轨迹/断言、频率和超时。在原 `PresentationContinuityTestDoc.render:295` 去重 return **之前**，仅额外记录当前 frame、getTimer、drop 的逻辑 x/y 与 vis.x/y；同时记录原高优先级 ENTER 到达及已有 lootMotion 到达的 sampleTime/位置。限制为掉落初显后 2 秒、最多 256 条，溢出明确记为不完整，结束后再写一次；不截图、不 stringify 整个消息、不取私有游标、不包裹生产方法、不新增 CPU 采样。

其可证伪的判断仅为：

1. 若同类空档中 ENTER 和所有最终 RENDER 都缺席，则不是“这些回调持续执行却由单物品插值保持旧值”；继续定位事件循环/原生渲染才有依据。
2. 若 RENDER 持续发生但没有新 ENTER，则可核验同帧显示时间固定的实际作用；记录真实像素对象位置，不能把按帧去重漏记当不更新。
3. 若新 ENTER 和最终 RENDER 持续发生，位置数据也已收到，而 vis 仍长时间落后，才有理由进一步记录该条轨迹的游标/放置顺序。现有记录尚未达到这一步。

这只是有界归因诊断，不给性能资格，无法凭一次未复现宣布修复。若根不继续这个诊断，本轮应停在“没有足够证据支持新的生产优化”，不再追加零散算法候选。
