# e53cb3730a 收包批次独立复核

只读复核准确20／BEFC、原密集七阶段、实际双侧 RV enabled=0 配置。未改生产、驱动、分析器或结果，未启动 JVM／AIR。结论：**本轮没有同一 DATA 批次中的多份 unitsync；确有多份 worldstate 同批，以及单个消息的长同步处理。旧 netMax=78378 是驱动跨阶段计时污染。原5项性能失败保留，没有性能或发布资格。**

来源：

- `build/m52/recovery-socket-batch-probe-20-01/socket-batches.json`：SHA `8b10ab949a9d5beecc1ebb79828d16506a748e017dcf47e405373ce73fdb7f7f`，`collected=true`。
- 根汇总 `summary.json`：SHA `ad3f9b5f936186ea2e895a49a092497273b5d8938600cb2d638712fcbe337510`。独立直接读取上项原记录核对210个阶段数值字段，并复核类型数、full/fast packets 与直方图总数，均一致。
- 原 `result.json`：SHA `f1c5117581b836921dbcb61702a4d99fc3d23a7003b17dd036dc5af6fad68e56`。`fixture-audit.json` 保持 `input_comparable=false / attribution_allowed=false / passed=false / baseline_only=true`；本轮不是与另一候选的性能对照。
- `build/cooperation/e53cb3730a/join.log`：SHA `2a7e43c624814f914b1c4ba911a3b6a8cecf48e835f826919cb5a72712df7687`；host.log：`d3e00383caecceefac9e503a771584f2604091c6b973b0d6e1b7ac5e81c837b4`。
- 实际冻结驱动 `build/m52/recovery-socket-batch-probe-drivers-01/tests/SustainedDensityTestDoc.as`：SHA `12a39c8879962ec666b76c8b42c31f10a486da25ae2af4224c8bb6009f3112cf`；观察类 SocketBatchProbe.as：`a67ba6fd71b6a5133aeb635025b26b3c6b8da68863b6ba4f48109805a41aa155`。

## 七阶段数量

full 是实际 `unitsync`；fast 是 `worldstate`。批次按 **DATA 开始时**的阶段归类，未把一次消息拆成两批。

| 阶段 | 加入 DATA 批 | 消息 | full | fast | ≥2 full 批 | ≥2 fast 批 | 最长批 ms | 观察开销计数 ms |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | 131 | 324 | 47 | 134 | 0 | 40 | 68 | 56 |
| 1 | 116 | 224 | 33 | 86 | 0 | 15 | 117 | 29 |
| 2 | 116 | 215 | 32 | 84 | 0 | 15 | 101 | 31 |
| 3 | 114 | 217 | 31 | 85 | 0 | 13 | 86 | 27 |
| 4 | 115 | 217 | 32 | 84 | 0 | 19 | 114 | 23 |
| 5 | 115 | 223 | 32 | 88 | 0 | 18 | 102 | 31 |
| 6 | 116 | 220 | 33 | 87 | 0 | 20 | 100 | 29 |
| 合计 | 823 | 1640 | 240 | 648 | 0 | 140 | 117 | 226 |

加入 full 直方图逐阶段为 `0:84/83/84/83/83/83/83`、`1:47/33/32/31/32/32/33`，没有 ≥2 桶；各阶段直方图总数等于批数、`types.unitsync == fullStats.packets == full`。原驱动七次 `packets` 也恰为47/33/32/31/32/32/33，支持本阶段没有漏观察完整快照。

主侧七阶段批数37/29/30/31/28/36/31，消息115/108/112/111/114/114/113，合计222批、787消息；full/fast全为0，符合该侧收到玩家上报的职责，不能当“宿主没发送状态”。最长33ms。主侧7批跨阶段（各1批），加入0批跨阶段；原汇总按起始阶段累计正确。

负载阶段 full 共19200单位条目、1249次墙格出现、10,201,472个已有 d 字符；fast 共51840单位条目、661次墙格出现、5,723,452个 d 字符。每个full/fast均80单位；字符数是重复发送累计，**不是独立格数、压缩线包字节数或重复内容相同的证明**。

附着后包含outside的总数为主747批、加1322批；outside加入499批含159 full，直方图仍仅0/1，最长2827ms（不纳入负载 longest16）。本轮不能据零多full推断“从来不积压”：连续多个 DATA 回调可以在同一显示帧之间发生；本探针未保留全部回调时间序列，也不观察私有未解完半包缓存。

## 最长批的实际顺序

以下为各自进程的 getTimer 毫秒，不跨进程相减。

- 加入 **#636，阶段1/frame3，86733→86850，117ms**：worldstate tick1292 在86737→86740（3ms，80单位、0墙格），player-mines与coop-pause各0ms，worldstate tick1293在86743→86745（2ms、0墙格），worldstate tick1294在86750→86850（**100ms、0墙格**）。源sampleTime依次125262/125351/125432，确是不同采样的3个fast，0 full。同步MESSAGE总105ms；本批不能归因为多份full或大墙痕包。
- 加入 **#1042，阶段4/frame47，115267→115381，114ms**：unitsync tick1590 在115276→115364（88ms，80单位、6墙格、47844字符）；player-mines1ms；worldstate tick1591在115368→115370（2ms、0墙格），tick1592在115374→115381（7ms、1格8928字符）；末尾friendly-fire/player-mines各0ms。全批只有1 full，另2 fast。
- 加入 **#1176，阶段5/frame60，124751→124853，102ms**：unitsync tick1692 在124758→124852（94ms，80单位、5格41600字符），其后friendly-fire/player-mines各0ms、coop-pause1ms。1 full、0 fast。阶段2的 #773 同样1 full（94ms、5格41600字符），全批101ms。
- 主侧 **#531，阶段0/frame53，118344→118377，33ms**：coop-pause0ms → terrain20ms → playerstate1ms → exploration11ms。不能把这批归给敌人快照处理。

两侧各16份保留批的消息数、rows数、逐消息dispatchMs求和均与批摘要相等；无 rowsDropped。所有保留批起止阶段／帧相同。这里只观察同步回调耗时，不是 CPU 采样；100ms可包含原生分配／GC或回调等待，无法从本记录进一步命名函数。

## 78秒旧计时的原因

实际驱动 `SustainedDensityTestDoc.as:36` 初始化 `netAt=0`；`:192` 的高优先级监听只有 `phase=="load"` 才赋 `netAt=getTimer()`，`:193` 的低优先级监听却重新检查当时phase，只要已是load就记 `getTimer()-netAt`。首次 `density-commit` 到来时phase是density-prepare（`:365`），高监听不赋值；默认测试监听通过 `logArena();beginDensity()`（`:371`）在同一次MESSAGE中调用 `setPhase("load")`（`:444`），随后低监听以初始0为起点。`netAt` 在此前准备／尸鬼／炮塔阶段均未赋新值。由此第一次伪时长等于结束时进程计时值，而非回调耗时。

运行证据相互吻合：

- join.log:168 首段即记录 `netMs=80124/netMax=78378`；此后七段netMax原值不变。
- 将各段累计netMs扣除这一个污染值78378，得到 **1746/3381/4834/6320/7859/9332/10915ms**；新观察器各段累计真实MESSAGE夹取为 **1747/3384/4838/6324/7864/9339/10922ms**，仅差1/3/4/4/5/7/7ms，符合监听边界与getTimer量化差别。
- 新观察器完整附着后最长DATA仅outside2827ms、load117ms；所有未闭合／嵌套／孤立MESSAGE／异常计数均0，没有78秒批。

因此 **netMax=78378不能作为生产78秒收包或网络积压证据**。旧netMs也带同一个初始污染，且netMs/netMax从不按七阶段清零。本报告不改旧驱动或旧结果；原五次帧数／p95 FAIL来自独立的frames/p95断言，不受这条netMax错误“赦免”。

## 开销与判定限制

主侧负载累计DATA671ms／MESSAGE469ms，观察计数19ms（pre2+metadata7+post10）；加入DATA15667ms／MESSAGE10922ms，观察计数226ms（pre4+metadata192+post30）。这些是嵌套范围，不能相加；post包含低MESSAGE内与DATA-stop之后两种边界，也不能把226直接全从15667扣除。毫秒量化、观察导致的分配／GC和调度扰动没有完整排除，0ms不等于零开销。

两侧 `open/orphanMessages/missingEnd/nestedData/nestedMessage/faults/attachFailures/metadataTruncated` 均0，Socket身份保持，全部七阶段有批次，故完整观察资格成立。唯一低MESSAGE监听在Session/default监听之后，但准确20 `Session.as:417` 的full仍可被`rooms.accepts`拒绝；`:502` 的worldstate先处理玩家，敌人／掉落／墙痕另经`sameHostRoom`权限检查。**分派完成不证明全部字段实际应用，更不能证明重复应用。**

tick/source sampleTime不是线包发送时刻，未校准双侧时钟；不能据二者与接收getTimer的差值报网络延迟。Socket bytesAvailable也不包含所有前批留下的半包字节。

原加入阶段0/1/2/3/6共5项“80 enemies keep stage frames progressing”失败原样存在；无真实运行异常。安装22项、独占、驱动／模板／真实用户配置起止核对仍不变，但这只能保证本次诊断来源，不产生性能达标或发布资格。当前证据收窄了“单批多个full”为主要长帧原因的假设；不能据此擅自删快照、合并fast或降低发送频率。
