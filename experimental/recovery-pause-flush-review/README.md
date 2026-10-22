# recovery23 暂停补发只读审查

审查对象：`recovery-pause-flush/inputs.json` 的完整 90 类，对照准确 `build/m52/recovery-22/src`；指纹和独立核对见 `evidence.json`。本审查未编译、运行 AIR 或改动被审源。

## Standards

未见这次增量违反工作区边界或引入不必要长期状态。只有 `CoopPause.refresh`、`Session.flushPausedWorldState` 与版本号变化，其余 87 类逐字一致；现有 `broadcastWorldState` 原样复用。新增状态只有调用栈中的 `wasPaused`，没有重试队列、永久标记或额外计时器。

## Spec

正常连接下的顺序符合“先确认暂停，再立即补停止姿态”：`CoopPause.as:190–204` 先把 `_paused` 和 `GameBridge.coopPaused` 设为真，再按原策略发送 `coop-pause/state`，最后仅在 false→true 边沿调用补发。旧 summary 早退改为包住原发送段的等价条件。TCP 保持消息顺序；没有为每次 refresh 额外发包。这里补的是原 **快速 worldstate**（玩家、敌人运动、活动掉落物和墙痕增量），不是 200ms 全房 unitsync。

`Session.as:1205–1212` 在采集前检查 HOSTING、双方暂停状态、可同步的当前房间、authority、非转换、服务器已绑定及至少一连接。真实 `RoomSync.canSyncWorld` 还要求 `game.loc === settledRoom`、`world.loc === settledRoom`、当前 land 身份相同（`RoomSync.as:94–98,565–566`）。没有新增“等待 peer ACK 才暂停”的全局阻塞。若边沿当时不满足 guard，这次补发不排队；后续沿用原 50ms 广播，不承诺无效房间恢复后还会补同一边沿。

相同 tick/sampleTime 可以进入当前接收链：`Session.as:502–506` 不按 tick 丢弃 worldstate；`RemoteMotion.as:133–150` 对同时间戳替换末样本，旧时间戳才丢弃；暂停时 `queueUnitMotion` 使用 settle。真实 `_sampleAt` 在 **onPerceptionFrame，priority 90000** 更新（`GameBridge.as:134,370–374`），不是在 onMirrorFrame 更新。`CoopPause.before` priority 99500 早于它，此入口可能沿用上一物理帧的采样时间；after priority -7000 晚于原生模拟、早于 -10000 的特效 observe，因此补发能包含当前对象姿态，却只能包含截至当时已被观察的特效。没有据此证明时间倒退或丢动画，也不能把 fixture 固定 sampleTime 当真实帧时序验证。

## 有证据的验证缺口

1. **真实失败重入未被 50 项外壳覆盖。** `TcpLink.send:65–93` 自己吞发送异常并同步 dispatch FAILED；`HostServer.removeClient` 再 dispatch CLIENT_REMOVED；`Session.onClientRemoved:310–315` 会直接再次调用原 `broadcastWorldState`。组件 FakeServer.throwOnce 则直接抛异常，hook 删除 clients 也不派发这些事件。因此组件“捕获一次／不重复 wall commit”不能推广到真实断线。两人模式最后客户端移除会让外层 wall-commit 条件失效，链也有 closed-notified 防重复；未发现新增无限递归，但确实可能有一次额外原生采集。这是复用的旧广播副作用，不足以据此要求新增锁或长期重试状态。
2. **采集不是纯读取。** `readSnapshot → UnitPresentation.capture`、`readEnemyMotion → captureEffects:253–285` 会推进已观察特效的发送游标、结束保留时间；wall updates 在广播后才标记 sent。新边沿复用相同路径，没有事务回滚，也没有改变 TCP 失败处理。50 项使用固定返回值的 FakeGameBridge，没有验证真实游标、同帧弹体结束、原生动画与显示像素。
3. **当前实际组件证据仍是失败。** 审查时 `recovery-pause-flush-component-01/receipt.json` 为 compiled=false / AIR 未启动；compile.log 指向 ControlCoopPause 错改 `game.setControlCoopPaused`。本次只核对了 50 个断言的源码和两个 Session 方法逐字嵌入，不能写成“50 项已通过”。后续修正/新回执须另核对，不覆盖这个失败。

原生必要验证限于既有 SATS 入口、晚到快照和暂停重绘夹具：确认 state 确实先到，补发后最终姿态与主侧一致，同 stamp 不回跳、恢复不瞬移；跨房/断线应按既有清理退出。还应记录这次额外采集是否增加暂停首帧耗时，不能只比较发包更早。完整 Session、真实 socket、像素与性能资格目前均未由组件给出。

结论：规范方面无新增问题；目标方面未见可证的正常路径阻断，保留上述 3 项验证边界，其中组件实际未运行是当前明确未完成项。没有建议扩大协议或新增持久状态。
