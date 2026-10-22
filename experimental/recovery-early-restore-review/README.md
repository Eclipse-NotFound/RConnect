# 早交付握手与加入端恢复成本复核

2026-10-23。只读审查准确 `experimental/recovery-early-exit-authorization/src`（生产候选 D356483F…ACB3），未改生产源、未编译或启动 AIR。此报告由 `/root/early_overlap_review` 应根代理要求保存。

## 结论

`493c841d14` 的两端首次 `sceneEnsure` 没有重叠，不等于加入端在等待主侧绘完。两次加入端已收到完整 grant、正在同步恢复世界时，主侧开始绘图；加入端恢复耗时超过主侧绘图耗时，所以自己的绘图随后才开始。当前不应为此删掉完整恢复、出生定位或 ACK 屏障。

### 代码顺序

以下行号均指上述准确候选：

1. `rconnect/core/RoomSync.as:127` 在原生构造完成后持有控制；`:155` 主侧发 seal，加入侧收到 seal 且构造完成后 `sendReady`（`:901`）。
2. 主侧 `commit`（`:934`）采集权威房间，`:981` 发 grant。`rconnect/net/TcpLink.as:83` 同步调用 socket.flush。随后 RoomSync `:989` 才允许主侧绘图。
3. 加入侧 grant 分支 `:826` 起，完整解包/恢复，`:860` 放到已确认的主侧出生点；`:879` 立即 `early.allowPaint` 并返回。此处没有等待主侧首次绘图完成或 activate。
4. `EarlyTravelGate.as:73` 解除 raster.waiting；`:77` 的完整绘图、exit0、下一帧等要求用于最终放开操作。RoomSync `:174` 的 ACK/activate 是绘图之后的共同激活，不是加入侧首次绘图的准入条件。

### 同轮实际证据

来源：`build/cooperation/493c841d14/host.log`、`join.log`。加入日志行37–60为首进、125–143为重访；`EARLY PAINT PROFILE` 有 getTimer 与墙钟配对。墙钟跨端对齐误差约1 ms，不影响下面的千毫秒级顺序判断。

|流程|加入 grant 整段（自身getTimer）|主ensure墙钟起止|加入ensure墙钟起止|加入grant结束→ensure|
|---|---|---|---|---:|
|首进|33526→35391，1865 ms|1792677551536→1792677552585|1792677553383→1792677554306|15 ms|
|重访|45969→47740，1771 ms|1792677563978→1792677564995|1792677565733→1792677566892|16 ms|

用各自同轮日志时钟换算，加入 grant 开始比主 ensure 开始早约33/32 ms。因此798/738 ms的两ensure间隙，主要可由加入恢复处理较慢解释，不需要假设“等主侧画完才发数据”。此处不能把跨端进程调度当精确CPU分账。

## 现有恢复分项已经可用

`GameBridge.as:6231` 的 `restoreCheckpoint` 现有日志是**累计耗时**，相邻相减才是阶段时长。`join.log:54/137`：

|阶段|首进 ms|重访 ms|
|---|---:|---:|
|role准备|65|68|
|地图点、对象匹配/恢复|252|255|
|地形恢复|493|488|
|清除、匹配、新建和恢复单位|634|668|
|掉落/镜像/地雷/终端|46|39|
|重绘及末尾处理|97|62|
|restore总计|1587|1580|
|grant其它处理（含解包等，不能全称解码）|278|191|

此前准确同候选 `f95499e5a7/join.log:58/148` 的 restore 为1613/1593 ms、grant为1839/1769 ms；相减地形488/427 ms、单位725/739 ms。两轮支持优先检查地形与单位恢复，不需再为这层分账加一套探针。

单位路径 `GameBridge.as:6266` 在 foreign 情况先清掉可同步单位，`:6276` 后仍对每个记录执行 ObjectIdentity.resolve；新建对象使 loc.units 逐渐增长。当前日志把清除、构造、原生状态、武器和姿态合在一起；追加核对的旧详细 profile 已显示 resolve 不是主要成本，见末节。不得直接跳过重建：原生未同步引用、死亡、武器构造与子类型字段均有语义。

## 地形状态的最小可行优化

准确源没有名为 `hostTiles` 的状态字段；若这个称呼指主侧发送的地形，则为 checkpoint中的 `tiles`，由 NativeTileState表或旧数组表示。

- `TerrainSync.as:49` 的 `enter` 为当前房间每格建立13字段快照，同时赋给 `base[x][y]` 和 `observed[key]`。
- `base` 保留接管前的原生状态。`:120` `hostPatch` 每次相对它检查，持续向新/旧对端补发非默认格；不能在恢复后改成权威新值，否则可能丢掉既有破坏。
- `observed` 是最近确认的本地状态。`:136` `capture` 用它计算此后真正发生的伤害；`:203` `apply` 或完整恢复后更新它，避免把导入造成的HP差当成玩家新攻击。两个容器可暂时共享同一不可变快照，后续代码都是替换条目，没有原地改旧快照。
- `restoreCheckpoint:36` 先 reset→enter 全图建立旧值，再 `NativeTileState.restore:93`；后者全表验证（`:128`）后才开始写（`:141`），每格保持 setZForm→最终opac→after（`:148`）。after又为observed建立一份新13字段对象。大图240×125=30000格。

**推荐首先只准备一个局部候选：恢复回调复用值未变的 observed 快照。** 算一次格键，若现有 `matchesTile(t, observed[k])` 为真，保留原对象；否则才执行 `state(t,x,y)` 替换。只触及 NativeTileState分支的after回调，保留全字段写入、每格一次回调、完整表预校验、setZForm、opacity、dirty=true、reset/epoch和旧数组回退。未知标量字段仍由NativeTileState原代码照常恢复，只是不进入这13字段的伤害观察快照。

这可避免大量未变化格的第二份快照分配，但额外比较也有成本，**没有收益结论**。需完整 TerrainSync.restoreCheckpoint 旧新交错测量，不可只测NativeTileState而遗漏回调。若收益不稳定，应停止，不合入。

不推荐本轮直接把enter快照融合到NativeTileState验证或写入遍历：坏表在末行才被拒绝时，旧代码已经完成整个base/observed初始化而未写Tile；融合会留下局部基线或改变初始化/异常顺序。若再加失败补全和新回调来恢复语义，复杂度已大于这个局部候选。也不推荐逐标量“相等才写”，它为约百万次写入增加读取/比较，未证明收益。

### 必须保持的反例与验证

复用 `tests/room-entry/NativeTileStateChecks.as`（v1/v2、完整字段、形状副作用、对象引用、末行坏表原子拒绝、未知对象字段拒绝）、`TerrainSnapshotChecks.as`（13字段和非原生回退）、`tests/NativeTileFieldsRegression.as`（真正游戏Tile槽），并以准确旧/新完整 TerrainSync 比较：

1. 完全相同的30000格、每个13字段分别变化及混合变化；表外可选标量变化仍被恢复。
2. restore之后 `report` 不制造导入伤害；随后真实减HP只报新增部分；hostPatch仍相对恢复前base持续报告变化，恢复原值后安静。
3. setZForm引起的phY1变化和最终opac；door/trap引用；旧数组/缺字段对象回退不变。
4. 末行非法、重复槽位、缺Tile、错误类型仍在任何Tile写入前失败；失败后再调用hostPatch/report，与旧完整类一致。
5. 真实全图读取/写入和比较放在被测时间外；至少旧新/新旧交错，完整结果比较，不以“必须变快”作通过断言。局部胜出仍需原生双人旅行验证，不能提前声明加载已达单人时长。

旧 `recovery-terrain-loop` 已做元数据查表和seen-vector优化；准确当前NativeTileState已经包含这些，不重复把旧改动当新方案。握手、绘图和激活顺序均保持。

## 追加：接收侧原生单位复用的边界

**结论：重复构造确实是更大的已测成本；但当前元数据不能证明“刚生成且从未模拟”，不宜把 `if(foreign)` 改为 `if(foreign && authority)`。可研究带明确出生记录、类级重置契约和逐单位回退的复用；尚无一个已验证可直接放行的通用条件。** 本节仍只有源码/日志审查，没有实现或运行新候选。

### 成本证据及 foreign 实义

旧详细诊断 `build/cooperation/2e09dd2325/join.log:70/128` 的首进/重访各删除、构造136个单位；`unit.constructor` 为505/435 ms（各136次），`unit.putLoc` 27/25 ms，`unit.addObj`37/35 ms，`unit.resolve`10/2 ms。另有武器补建28个，`gun.constructor`80/76 ms；它已包含在 `unit.restoreCall`136/139 ms中，不能重复相加。这是**旧诊断组合**的成本来源证据，不是D356候选收益预测。两次单位组成均含25个Monstrik、20个Slaver、20个Merc、16个Turret、14个Vortex、12个Alicorn、11个Mine及其它类；尚无按类构造耗时或安全复用命中率。

准确D356 `RoomSync.as:857` 的 foreign 为 `msg.fresh!==true && (!authority || settledRoom!==game.loc || !ready)`。这里 `authority` 是此前本机角色，`Boolean(msg.owner)` 才是即将恢复的角色；foreign不仅表示镜像转权威，也包括接收侧重新进入房间、尚未ready等。`:851` retained分支另有语义。故 authority=false不足以区分新生单位、旧镜像或缓存重访。

### “未模拟”在现有原生流程中不成立

- 原版 `game-reference/decompiled/1.02/src102/scripts/fe/loc/Location.as:1253` 在createUnit末尾主动执行一次单位step。已回读的本模组宿主 `build/m52/recovery-early-host-01/after/scripts/fe/loc/Location.as:1264` 也保留该调用。不是只有普通World帧才会推进单位。
- 原版 `Land.as:665/670/741/763` 还调用preStep；`Location.as:2204` 每次推进30次stepInvis，`:3316` 对链中每个对象调用step。已回读宿主Land对应调用仍在`:703/708/779/801`。本审查未给当前连续场景每个单位计算实际调用次数，不能声称所有单位都恰好31次；足以否定仅凭new-Land和constructed推断零步。
- `Unit.as:1766` step只因disabled/trigDis等条件提前返回，正常会执行inter.step、forces、control、run、actions、animate及childObjs.step（`:1798–1852`），没有通用“房间未active则不模拟”守卫。UnitMonstrik.control也会修改AI并可能寻找目标（`:199–229`）。
- `RoomSync.nativeConstructed:127` 到`:137`才hold；`EarlyTravelGate.finishConstruction:48`记录房间级身份，不记录每个单位出生代次或模拟次数。`roomRole:6192`清理RC状态、设置freezeAI，但没有立即disabled所有原生单位；真正冻结在`applyUnitsSync:5714–5722`，完整恢复末尾`:6306`才调用。同步恢复调用栈本身通常不会被普通帧插入，但不能因此抹去构造期step或外部回调。

### 当前恢复没有覆盖的状态与明确反例

1. **构造输入并非cls/id/tr/XML四项就够。** 原生Location`:1145–1187`可能把本机game.objs中的loadObj传给构造器；现重建`GameBridge:6283–6286`固定最后参数null。Unit构造`:582/669–675`据此构造Interact和死亡状态；`NativeRoomState`没有恢复unit.inter。带`code`的存档单位、被拆除/已掉落单位、两端本地保存不同均须排除或有明确转换契约。现`ObjectIdentity.resolve:70–97`只校验key或cls/id和150px内最近距离，没有XML、loadObj、构造难度、唯一生成槽等检查，不能直接拿其匹配作为复用资格。
2. **restore是覆写已有值，不是完整重置。** `NativeRoomState:13–36/54–59`只传公共有限标量/简单数组，跳过null、NaN、XML、对象引用及未公开对象图；缺少的字段不会清空。`RConnectUnitAccess:5`采集mapxml文本，`:57`后的restore并不回写mapxml。celUnit、priorUnit、bind、stayOsn、burn、effects里的对象、脚本和Interact等可能残留。权威镜像的AI虽冻结，动画、命中代理、交互及后续接管仍可能消费这些内容。
3. **子对象不一定等价。** `NativeRoomState:79–92`只修传入枪槽，不删除未传入的多余childObjs，也不重绑Merc.thWeapon、Raider.dropWeapon、Alicorn.psyWeapon等内部别名。UnitMerc`:29–34`构造独立arm与投掷武器；UnitAlicorn`:191–228`构造护盾clip、spd对象、滤镜和Spell。同类不同亚型/武器/构造期状态必须按对象图核对，不能只恢复顶层动画帧。
4. **地形恢复前后的派生引用不同。** 原生单位在旧本机地形上putLoc；现重建是在`_terrain.restoreCheckpoint`之后。Unit.putLoc`:1519`已有loc则直接返回，且首次执行含碰撞定位及脚本绑定（`:1529/1563`）。Turret.putLoc`:179`生成mxml交互/aRot；Turret.setPos`:334–339`在非active房间绑定osnova。aRot、mxml、osnova均不在RConnectUnitAccess传输字段中。主侧改变墙、方向、位置或炮塔类型时，保留旧对象不能假设这些依赖自动刷新；重新调用putLoc也不是通用修复。
5. **原对象身份自带生命周期。** Location.createUnit`:1242/1247`会登记saves/land.uidObjs；remObj`:2295–2319`只拆链、移视觉，不清理这些索引或第三方引用。旧重建与保留身份因而不是纯分配差异；本审查没有把旧路径潜在索引问题说成已修好。必须检查重复key、uid、脚本owner、武器owner、碰撞代理和外部缓存是否仍指向唯一活对象。空/死亡checkpoint仍须删除未匹配单位，不能让复用变成复活地雷/炮塔。
6. **第三方状态仍未获“不附着”证明。** 493轮run.json确实包含TDFC7ACD、FA B330、MSW526A、RV7852等；其加入侧TDFC日志`:3–8`记录多次room reset。但这些日志不证明每单位没有外挂状态，也不证明保留对象与换新对象行为一致。本子任务边界不含其它模组源码，因此未擅自声称其Dictionary/回调已核清。Sand许可仅覆盖其直接推进，不能当所有模组的单位生命周期证明。

### 最小可验证下一步

先做**不改变复用/重建行为的资格统计**：在准确同轮`constructed`与grant进入foreign清理前各保留一次有界观察，按具体对象记录新Land/Location/事务身份、出生槽和已知构造描述、当前内部对象图是否满足候选类契约；记录没有证据的原因，而非一律视为“新”。保持旧构造路线，输出最多每类汇总及少量拒绝样例，核对真实136个单位有多少具备可证明的候选资格。不要再给resolve加优化，旧实测不足以支持。

若仍有显著覆盖，下一隔离切片只允许 **非权威、非retained、精确early事务、新Land原生对象**，并同时具备以下证据才复用：

- 出生来源和构造输入一一匹配，拒绝最近距离猜配、重复/歧义、loadObj、脚本/uid绑定及未知亚型；旧镜像、缓存对象、死亡复活和真正权威接管继续原重建。
- 对该具体类已列清构造期step/preStep改变的非传输状态，并能等价恢复/清除；不能再使用“从未模拟”作为未经验证的前提。
- 单位、武器、显示子对象、交互和第三方附着有类级重置/重新绑定契约；任何未知引用、额外child、状态不符立即逐单位回退重建。地形/姿态恢复顺序不动。
- Host key只绑定到唯一对象；旧身份表与命中代理按原roomRole清理，未用单位仍原样剪除。之后非权威→权威仍执行原foreign重建。

验证需使用真实Unit类，比较旧重建与候选复用完成后的完整可观察状态及后续帧，而非只比较snapshot回读。至少覆盖同模板多单位换位、不同tr/武器、空/死亡snapshot、已拆地雷/炮塔、两端不同本地保存、破墙后/位置变化、脚本与uid、Merc/Alicorn子对象、复访与转权威；真实全模组两端还须观察多余枪/护盾、目标残留、命中、掉落和外部模块重附着。测量完整restore及grant到ensure，不只计构造次数。**当前没有这些证据，因而不能批准通用复用或承诺节省505/435 ms。**
