# 共同换图提前交付：安全边界复核

2026-10-22；只读源码审阅，没有运行 AIR/JVM，没有修改原生或模组源码。父会话负责实现、测试及部署。输入为正文列出的准确13、FD92/ACC原生导出及CEC6冻结源码。

结论：原生流程存在可收窄的停点，但不是把当前 grant 提前发送就能安全实现。最早停点是 `Game.enterToCurLand` 完整返回，且必须在同一次 `World.step` 内阻止其后的模拟。原生加载倒计时、相机、GUI和首绘需要继续。当前 CEC6 时停模组存在独立推进路径且没有公开状态接口，因此仅新增 World 分支不能承诺全模组冻结；该组合须先有明确接口，不能猜配置关闭后放行。

## 1. 停点与必须保留的流程

准确原生 `World.exitStep:1134` 先递减 `t_exit`。20只显示加载画面；19才调用 Game。`Land.enterLand:1199` 的实际顺序是 `ativateLoc → setGGToSpawnPoint`，存档点分支也会选择并激活入口。`World.ativateLoc:1071` 已调用 Grafon.drawLoc，但最终出生尚未设定。Game 尾部还会执行地图触发、visited/mReturn/任务阶段处理。因此只能在 Game 的末尾发 `constructed`，并现场核对 World、Game、Land、Location及本次旅行身份，随后刷新 `GameBridge.refreshWorld:478` 的缓存引用。

`World.step:1256` 的外层 `!onPause` 在调用 exitStep 前已经判过。若 constructed 中才设置 onPause，本帧仍会执行 Land.step；只有 `t_exit==17` 被旧代码跳过。`Land.step:1633` 即使 catPause 为真也继续脚本，`Location.step:3549` 会推进玩家、对象、空间索引、波次/警报及地形。所以必须在 exitStep 返回后再次检查精确加载票据，不能仅依赖下一帧 RoomSync.before。

与此同时，旧 onPause 会连 exitStep 一起停住。新的受限分支只能允许持票的原生倒计时继续，不能简单把外层改成 `!onPause || loading` 后照跑整个分支。World 后半 `allStat>=1` 的相机/GUI在 onPause 外；Camera 原生计算会继续调用 sceneTick，无需人为提前调用 Camera.calc。18/17的原生点击等待必须保留，不能把计时器直接设零。

exit16 原生会 `controlOn`、清 `pip.noAct`；加载票据必须延后这两个操作到正常激活。菜单/SATS判断也在 onPause 外，单独 controlOff 并不能禁止所有菜单。等待中若菜单使 allStat 变2、而新加载分支仍只接受1，会产生等待互锁。应保留原生点击/画面流程，明确拦住本次共同旅行期间的游玩输入，不能强写 allStat 绕开真实菜单。

这是明确的玩法时序改变：加载尾部原本会发生的世界 tick 被延后到共同激活后。它不是逐字节等价优化，也不能一边允许这些 tick 发生、一边激活旧 checkpoint。

## 2. 当前 RC 接口不能直接复用的两处

1. `FirstRasterGate.beginRestore:21` 立即令 `ticket.waiting=false`。而 RoomSync grant 处理在完整 `restoreCheckpoint` 和入口定位之前调用它；restore 自身也可能调用 `tileRedrawIfDirty:6314`。早交付需分开“准许导入”与“准许 chunks”，完成导入和 anchor 后再放行首绘。宿主也须持首绘票据，采集并固定 grant 后才绘图。
2. `FirstRasterGate.ready:32` 只检查下一个 frame、unpainted 与 sceneViewReady；旧路径本来在 t_exit==0 后进入，所以没有原生过渡检查。新 ACK 必须额外证明原生退出过渡、无 comLoad/死亡且身份未变。宿主还要自己 native-ready/view-ready 和对侧同票据 ACK 全齐，才发 activate。旧 `RoomSync.commit:744` 的立即 release 不能用于此分支。

普通分房、离线、未知桥、对侧未协商支持仍保留原路径。不应全局放开 `isTransitioning`。随机种子旅行没有非随机 NativeTravelPlan 的 token，不能仅凭空 travelId 延用旧 seal；earlyId 必须绑定本次 World/Game/目标/代际及 epoch/barrier。旧 pending 不能被新消息抢占。

`GameBridge.checkpoint:6162` 不是纯 getter：它会绑定单位/对象键、建立观察基线并清理交接状态。应在原事务结算旧报告后采集一次，立即 pack 固定字节；不能缓存包含活引用的对象，在首绘或其它回调后才编码。Session 在 busy 期间仍有玩家状态包，只有敌人/地形等主要路径被 canSyncWorld 挡住；“冻结”不等于没有回调或网络工作。

## 3. 绘制修改哪些状态

FD92 的 `Grafon.sceneDrawSteps:2743` 和普通 drawLoc 都调用 `Location.tileKontur:2399`。后者只写 `kont1..4/pont1..4` 八个派生轮廓值；原生 fe 源码中其使用者是 Grafon。轮廓取决于邻格 phis/door/back/shelf 和当前 backwall，包含 sky 分支。NativeTileState 捕获 public 标量，因此这些八字段会进入旧全量快照。

`sceneDrawRegionChunk:1697` 暂改九项 Location 环境字段并在 finally 恢复；轮廓字段没有同时还原。区域/视口绘制顺序会改变最终留下的派生值。故“预绘前后所有 public 标量必须逐字相同”不是合理不变式，但也不能删去整组地形比较。实质碰撞、血量、对象/门箱/掉落仍应严格冻结，八个轮廓值按同一原生重算规则单独核对。

尤其 `CheckPoint` 构造函数的 shelf 写入发生在对象构造期（公共原生参考 82–83行），不是 addVisual 的显示派生；Location 构造也有 shelf 写入。shelf 会影响碰撞及轮廓，必须保留。drawAllObjs 在 sceneOpen 初始化阶段就发生，不能把它延后或删掉以求表面上“全无变化”。

13 的 WallImpactVisuals 在 first-raster pending 时不采 front 空图；16 的真实分块墙面桥也会在 pending 时拒绝采样。早期宿主票据必须保留此含义，checkpoint 使用已有墙面状态，不能把空 scratch/尚未画的 chunks 当成新墙面覆盖历史。

## 4. 模组调度与准确 CEC6 边界

RoomSync.before 优先级100000，GameBridge感知90000；after为-9000。原版 MainMenu 的 World.step 在普通 ENTER_FRAME 默认优先级；CS/WB等也有独立回调。不能依赖“下一次 after 再冻结”。准确 RV7852 对应源码在 onPause 时仍计算本机视野/光照与可见性，这些显示派生不等于允许战斗模拟。

时停版本已绑定：`Sandevistan/build/out/keybind-20261015-006/build-input.json` 指向冻结源码 AD931F4F…84492D；冻结产物与当前正式产物都实算为 CEC6A306…CCCF942。发布记录明确该件不含 SandyAuthority。此前读取的当前 root 源含未发布 B 接口，不能作为此组合接口依据。

准确冻结 `SandevistanMod.as`：

- `onFrameInner:706–716` 只有 sandyActive/replaying 时手动推进玩家/世界，普通玩家 idle 只减少冷却；`stepSandy:4232/4309` 和 `stepReplay:5694` 直接调用 gg/loc。
- `inGameplay:790` 不查 onPause、t_exit、ggControl。`startSandy:3892` 仅用这个条件；`onKey:6818–6831` 可在加载 hold 期间新激活。只在旅行开始时检查 onPause，挡不住中途热键。
- idle 支路 `754→stepEnemySandy→5003` 可对敌人补步。默认/release的 esandyenabled=0 不是完整运行时证据：应用存储会覆盖配置，设置项 setter 也可改变它。
- 旧 config 中 projhits=1 不代表该逻辑运行；准确版本 cfgProjHits 恒false，旧键已迁往 MSW，不能拿这条死路径扩大风险。
- 活动/回放为 private。该入口公开的只有构造函数与 init，没有稳定 active/replay/query；HUD可关闭，且不是状态契约。B 的 SandyAuthority不能借用到 CEC6。

因此当前可证的必要条件是“无既存外部模拟、票据期间禁止新模拟、退出恢复原状态”，不是可用 `onPause===false` 单独表达的充分准入条件。禁止从磁盘默认配置猜安全。准确 CEC6 需要独立的受限 loading hold 接口，或不在这个不支持的组合启用优化。接口提案留 RConnect 内供父会话审阅；新增 A 接口尚未获准修改对方。

## 5. 取消与所有权

- 票据绑定 World 与 Game；同 World 读档换 Game 也失效。原生 comLoad 在暂停外处理，不能等通常暂停分支后才清。
- grant未固定/未导入时可撤票回旧晚交付；已部分导入后的失败不能普通 release 到半世界，应保持不可操作并走原失败处理。两者不能共用一段“恢复游玩”。
- 正常 activate 才补执行延后的控制恢复；只接受同 earlyId/epoch/barrier，重复 ACK/grant 不再 restore，旧 activate 不解锁新旅行。
- 撤回桥只在当前函数仍是本票据安装的函数时恢复；不能覆盖后装 owner。Game换掉时不能把旧 savedOnPause、ggControl、pip.noAct写入新Game。暂停布尔值相等不证明独占所有权。
- 首绘取消只撤本 ticket；保持 unpainted 由真实渲染清除。不要因为取消就把空画面认作已完成。

最小可验证实现仍是 Game 完成回调、World 受限加载推进、现有 Grafon ticket 的宿主接入及 RC 单一旅行事务；另须解决准确时停独立推进契约。它不需要全房间缓存或新调度框架，但少掉上述任何一项都无法由当前代码证明安全。

验收仍是同输入真实三段旅行：grant必须早于宿主首chunk；两侧绘图确实重叠；冻结期间真实对象不前进而t_exit走完；完整恢复/入口/首屏/实际按键恢复后才激活；重访、取消、读档、点击等待及旧客户端分支保留。没有执行这些测试，本报告不授予功能或性能通过。

附加指纹清单没有生成：一次“只读输入、在本目录写 inputs.json”的 Python 命令被本地保护规则以 read-only-reference 拒绝，未执行，未换方式重试。CEC6冻结源/候选/正式SWF此前已用只读 Get-FileHash 独立实算并与build-input核对；本报告没有冒称完成全部输入指纹清单。
