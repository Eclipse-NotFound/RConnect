# 共同整图旅行：早期交付的最小设计边界

2026-10-22，接[关键路径复核](review.md)。只读设计，没有改源码或运行测试。它只针对已证实的“宿主首绘完成→交付→加入侧首绘”串行；并不声称解决全部恢复后长帧或保证达到单人7.93/4.03秒。

## 1. 准确的原生完成点

不要把 `t_exit==20` 当作新地图已完成。准确E159/FD92的 `World.exitStep` **先递减**：

| 时刻 | 已完成 | 尚未完成/不能假设 |
|---|---|---|
| 递减到20 | 原生加载画面、关闭声音 | 还没有调用目标Game.enterToCurLand |
| 19：new Land及sceneNativeCall(prepare)后 | 新地图生成；或选择缓存Land | 目标Location的reactivate、最终玩家出生、GUI和地图触发状态未完 |
| 19：Land.ativateLoc内，Grafon.sceneOpen时 | 玩家inLoc、Location.reactivate；通用显示初始化将执行 | setGGToSpawnPoint还在后面；不能锁定最终入口 |
| **19：Game.enterToCurLand全部返回** | 地形/原生箱体/敌人已有；Location激活；spawn/存档点选择、lightAll、GUI、地图触发状态及返回标志已走完 | 首屏是否已画取决于ticket；原生倒计时/淡出仍未完；之后本帧仍可能马上Land.step |
| 18/17/16→0 | 点击等待、原生画面关闭和淡出/控制恢复 | 不能用固定毫秒代替；必须按真实原生流程完成 |

`Land.enterLand` 的 ativateLoc→setGGToSpawnPoint 顺序明确；`World.step` 在exitStep后直接执行Land.step，Land还会步进脚本，Location会推进gg、firstObj、波次/警报/地形重建等。因此**提前发送一次完整checkpoint，随后让宿主继续原样运行，最后再激活那份旧副本，不安全**。只要期间发生死亡、开箱掉落或破墙，就已不是同一世界截面。

## 2. 建议的窄实现：提前走原事务，暂缓激活

适用范围仅“双方已协商支持、宿主发起的同一整图旅行”，绑定已有World/Game/旧Land/目标id+seed+sceneMerged/新Land/Location身份和本次epoch/barrier。普通分房、仅一侧支持、离线及未知原生路径全部仍走现有流程。随机seed路径仍不能借用仅支持非随机的nativeTravel token；在既有SeedRasterEntry上绑定本次代际，不能仅凭空travelId接受。

1. **原生逻辑完成通知。** 在Game.enterToCurLand所有原生动作结束后，通过现有Game travel bridge增加一个本机 `constructed` 通知。父调用World/本次Game/目标Land/Location必须现场核对，不能由Timer猜测t_exit==19。此处不广播普通worldReady，不改通用isTransitioning。
2. **在同一帧进入“加载中冻结”。** `RoomSync`保存原暂停/控制状态，旧房间末尾报告照原序结算。本次新世界不执行战斗、脚本、掉落或玩家输入；仍保留onPause供现有模组识别。准确World.step需要一处特殊分支：只有匹配这张有效加载票据时，允许exitStep继续、相机/GUI照原生推进，但不执行其后世界模拟；还要覆盖“本帧进入外层if时尚未暂停，exitStep中才冻结”的情况。不能只在下一帧检测pause。
3. **初始化照做，双方首屏都等最终状态。** 复用Grafon现有ticket，宿主此条路径也暂缓chunks，sceneOpen的显示绑定、光照准备、drawAllObjs等不删。宿主逻辑完成并冻结之后走原seal/ready/commit；加入侧的ready只对这个精确constructed票据提前，不对任意t_exit>0放开。宿主完整checkpoint仅采集一次并固定字节，作为原grant发出；这仍不是授权双方模拟。不得把checkpoint()叫成纯getter：它会绑定对象键、建立基线/观察游标，必须仍在原事务的单次采集位置。
4. **恢复与绘图可重叠。** 宿主采集后放行自己的绘图，加入侧完整恢复该grant、定位到seal冻结入口后放行绘图。双方世界模拟继续冻结；原生倒计时、相机及真实可见首屏继续推进。不要在宿主绘图完成后才发grant，也不要在加入侧beginRestore前偷偷用本地未确认图。
5. **最后只发小型激活确认。** 加入侧的原ACK仍要求完整restore、入口就位、真实viewReady和原生过渡结束，不能在收包时发。共同整图分支下宿主收到ACK且自身同样native-ready后，发送带同一epoch/barrier的 `activate`，再恢复双方保存的暂停/控制状态。grant处理不提前release；普通分房的“宿主commit后不等对侧绘图”行为不改。必须协商新能力，否则旧客户端不识别activate会被锁住。

这是一个有界的加载事务扩展：只保留一份本次grant及其固定身份，没有通用网络积压合批、全房间快照缓存或新的任务调度框架。迟到/重复grant和ACK只认同一票据，重复不得再次restore；任何代际变化先撤销本次票据，绝不让旧activate解锁新Game。

必要修改面只有：**Game的完成通知、World的受限加载推进、Grafon既有ticket的宿主接入、RC的MapGeneration/RoomSync及既有加载票据，外加能力协商**。其中World分支是安全性必需，不应为了少改一类而让旧快照继续过期。可先用完全相同旧协议走至grant、仅本机保留激活，但若没有双方共同完成确认，就不能声称“双方同时恢复且不会复制过期世界”。

## 3. 仍须证实的风险，不能当作已解决

- **原生加载期间的世界步进改变。** 当前原版在加载尾部也会step；新分支更早冻结，会改变这些预先发生的AI/物理tick。这是明确的行为差异，不是逐字节等价优化。新设计应保证“加载中不额外发生战斗/奖励，激活后从同一状态继续”；若要求保留这些旧tick又不补传完整变化，则此最小方案不成立。
- **预绘前状态不全等于当前grant。** NativeTileState捕获所有可传public标量，含轮廓等派生字段；Grafon首次绘制/背景区域处理可能再改它们。已知shelf差异也不能忽略。必须核对“预绘采集→双方最终绘图”后完整必要状态一致，并明确哪些变化由同一原生重算产生。若出现未归档的实质地形/对象变化，应废弃暂存grant、回退旧晚交付，不能复用旧副本或排除比较项求通过。
- **外部模组是否尊重冻结未知。** 本次仅核对必要原生类，不扩大读取其他模组。onPause会保留现有约定，但不能据此断言所有外部ENTER_FRAME都停止写世界；需要最终原生组合证明。
- **无效/取消路径。** 死亡、同World替换Game、换档、断开、超时、种子/目标/配置变化、宿主桥丢失时撤销本次绘图票据和activate资格；清除自己持有的回调/控制状态，不覆盖后装监听或用户原暂停。部分restore失败保持不可游玩并走现有失败提示，不能直接release到半恢复世界；未开始restore的资格失效可退回旧完整交接。普通房继续原records/所有权交接，无人房死亡/破墙/门箱/掉落照原来保留。

## 4. 一条真正可证伪的原生测试

仍用现有scene三段同字节驱动、准确同22项和固定生成输入，不改三帧/1000ms及实际KEY_DOWN/KEY_UP门槛。在**同一轮双人首进→基地→重访**，于源端逻辑完成后、最终激活前安排足以跨若干原生帧的加入侧等待；观察而不直接调用receive/restore造结果：

1. 源端checkpoint确实在自己的首次chunk之前发出；join完整restore期间host已能生成首屏，证明减少的是串行工作而非仅遮罩时间。
2. 冻结窗口内源端真实对象不能前进/掉血/产出新掉落；World/Game/Land/Location保持一致，原生t_exit却能从19走到0。若任何条件不成立，该设计立即被证伪。
3. 激活时双方出生与源端冻结anchor一致；完整状态/墙体/已死敌/容器/掉落在重访仍一致，状态没有因旧grant回滚。原生按键检测与原时限照旧。
4. 记录两侧首次chunk、grant、restore完成、native-ready、activate和真实响应顺序；与同候选solo流程比较。若只是移早grant而两个首屏仍串行，或总恢复/首三帧仍慢，则功能即使通过也不能签收性能目标。

这是后续实施的验收设计，**本次没有新增测试驱动、放宽断言或执行该轮**。现有ON/OFF失败和局部采样继续保留，不被这个方案覆盖成绿色。
