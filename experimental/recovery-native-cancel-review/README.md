# 跨端取消握手：只读核查（2026-10-22）

**结论：这一缺口不构成正常加载链路的独立发布阻塞，也不能解释每次正常进入都偏慢。它属于“加载尚未确认时，一端中断旅行，另一端不能立即同步中止”的异常恢复缺口；不能据此宣称死亡／读档期间的联机恢复已经完整。** 本结论不代替 recovery11 的原生功能、性能和发布门槛。

核对对象是 `build/m52/recovery-11`（SWF `cd721f0e…64ebb5`）和 `recovery-native-travel-host-01` 的 E159 宿主（`e159fe0f…e5d30c`），不是安装版 BEFC。E159 回读 `Game.as:356–415` 只有 `adopt`／`announce`：真实目标、首次访问与构造等级确定后、`new Land` 前发送准备；成功路径仍是 prepare→原生生成→seal→ready→grant→ack。没有等待取消确认的正常步骤。

具体触发必须同时满足：**已有未完成 native plan、连接尚存，且某端死亡或更换 World／Game（例如加载存档）**。recovery11 的 `RoomSync.before:154–159` 在本端作取消；`handle:531–533` 与 `adoptNativeTravel:298` 还堵住“新 Game 在下一帧前先收到旧授权／进入构造”的窗口。`cancelNativeEntry:384–392` 只撤销本地计划、退役 travelId、清理入口许可；World／Game 替换还丢弃旧 barrier。`NativeTravelPlan.cancel()` 不发消息，RoomSync 也没有 cancel／cancel-ack 分支。因此另一端可能继续等旧 ready／ack，直到自 prepare 或 hold 起计算的 45 秒保护触发，明确暂停并提示断开重连（`RoomSync:160–161,176–180,734–737`）。这是“可能等到原截止点”，不是取消后另加45秒；没有实机证据可把所有中断都归为同一种收尾。断开连接是另一分支：本地 reset 解除模组等待、保留已开始的原生单人退出计数，不能当作跨端取消握手已实现。

已有实际组件覆盖：

- [`recovery-native-plan-component-01/receipt.json`](../../build/m52/recovery-native-plan-component-01/receipt.json)：33／0。覆盖单次采用、身份／epoch、固定出生锚点、退役计划不重启、World／Game 替换与局部 cancel。
- [`recovery-native-room-component-02/receipt.json`](../../build/m52/recovery-native-room-component-02/receipt.json)：50／0。覆盖暂停后早到 seal、旧交接排队、未真正构造不报 ready、出生锚点、换 Game 后旧 grant 不恢复／不 ACK、断开后原生退出继续、能力与重放。其 **RoomSync 与 NativeTravelPlan 两类源码逐字节等于 recovery11**（SHA 分别 `efafed73…639961`、`e40903e8…9309d1`）。红对照50项中恰有5项旧 grant 保护失败；早期 room01 是45／0但外层误期待46而失败，原失败仍保留。

这些是替身 World／Game 与消息驱动的组件，**没有双进程真实死亡／读档／单端构造异常后的取消握手、45秒后恢复或重连实测**；既有正常冷图／重访通过也不能补出这些证据。建议保留为明确异常恢复遗留项，不为正常加载优化扩建取消协议。若后续承诺“中途死亡／换档无需重连”，再以同一 planId 的幂等 cancel／ack 和两端退休屏障处理，并验证旧 grant、重复取消及新旅行重入；本次没有改代码、编译或运行游戏。
