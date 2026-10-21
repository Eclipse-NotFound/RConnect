# 首次非随机整图旅行桥隔离候选

版本 `0.2.24-recovery-travel1`。基于冻结 `build/m52/recovery-01` 的准确源码；该基线产物为 `79041b072829c60eb415280c5c02bbf465aac91a9bb632b6476ba41f2b5a8447`。

**本目录最新修正未编译、未运行 AIR、未部署。没有首次非随机地图实际缩时数据。** 旧冻结组件已由主会话运行，准确结果和计数错误见文末；原生宿主候选仅完成独立构建与静态回读。只读导出当前准确宿主后，写了原生 Game 的一个类补丁、7 个 RConnect 源码覆盖、测试与配方。完整来源哈希见 integration.json。

## 当前宿主与补丁范围

实际入口 application.xml 指向根 pfe.swf；本次开始、结束均为 `BEFCF0509E11FAC9FEF7AFB834708B8B93752A14AE3D5CD72B42AA6D42F9B82A`。

- `native-export/scripts/fe/loc/Game.as`、`Land.as`、`fe/World.as` 是从该准确宿主只读导出，不是公共旧反编译替身。
- `native-import/fe/loc/Game.as` 是唯一拟导入的原生类；差异在 `native-game.patch`。无需修改其它宿主类或其它模组。
- 准确 Game 中已有 CS 的 `sceneResetGeneration` 与 `sceneNativeCall("prepare", ...)`，均保留各一次。加入侧替换已有缓存生成时需要执行原有 reset API；没有改 CS 实现。
- FFDec 导出因其 Roaming 日志目录无写权限发出日志初始化警告，但三个类均 Export finished / OK；没有为此申请权限或修改配置。

## 实现行为

1. Game 添加默认 null 的 `rconnectTravelBridge`。宿主依旧先运行原生 Encounter 与原始等级/首次进入计算，在真正 `new Land` 前 announce。加入侧只有已接受、已实际开始、绑定同一 World 的一次性计划才能 adopt；它采用宿主已解析目标、firstVisit、原始 constructorLevel、entryCoord。离线及没有计划时保留原生 Encounter 和构造分支。
2. 同一新增地图可真正从两个进程同时进入原生加载。复用 room/prepare，新增计划 ID（会话 nonce + 单调序号）及源 epoch；不把尚未建完的地图伪装为普通 worldReady。计划只用于首次非随机/真实重建，随机种子路径和普通缓存快路保留。
3. HELLO 协商 nativeTravel 能力。宿主仅在所有当前 peer 声明能力、无旧 barrier 时广播新计划；不支持时保留原串行流程。欢迎消息本身附带未完成计划，先处理计划再处理世界信息，避免晚连接者先走旧流程又重载一次。随后重发 prepare 是幂等的。
4. 计划最多启动一次，重复/已退休消息不重新进入；同地图 ID 新建使用新 ID，不受 seed=0/同 ID 短路。构造等级作为本次原生局部参数传入，不修改玩家等级/全局任务触发器。
5. 接收计划时不先删除目标旧 Land；原生构造完整返回后才赋新引用。首次进入的引导暂停若仍存在，在真正开始原生退出后释放自有 hold，不能让 onPause 卡住 exitStep；旧 room barrier、共享暂停、新游戏 ng_wait 期间暂缓启动。
6. 宿主在 seal 时保存一次不可变入口锚点，ready/grant/ack 联合校验 plan ID 和原有 barrier/epoch/term。加入侧恢复完整 checkpoint 后才按该锚点放置并放行；普通 worldstate 里宿主随后移动不能替换入口。
7. World 替换/死亡取消本地计划并退休旧 ID；旧 prepare/seal/grant/带旧 ID 的 worldInfo 不能再次启动。异常保留当前失败/45 秒保护。**目前未新增跨端取消握手：若一端在进入中死亡或 World 替换，对端可能按现有 45 秒超时进入明确失败，需要实际测试判定是否补快速取消。不能称无缝恢复。**

## 文件与方法重叠

`src/` 是相对 recovery-01 的稀疏覆盖：

- `RConnectMod.as`：仅版本。
- `rconnect/core/NativeTravelPlan.as`：纯计划状态机、去重、一次消费、锚点与退休 ID。
- `MapGeneration.as`：原生桥注册与分发，现有 seedFor 不变。
- `RoomSync.as`：prepare/欢迎/启动、seal-ready-grant-ack 的计划身份与锚点；旧房间完整恢复保留。
- `Session.as`：HELLO 能力、欢迎附带计划、补发。
- `TravelGuard.as`：旅行许可绑定计划，计划未完成时阻止再次点地图旅行。
- `GameBridge.as`：worldInfo 增添 activeTravelId，原生旅行采用 entryCoord；原生计划不提前清空目标缓存。

并行合并时以上均以 recovery-01 为祖先，勿覆盖父会话后续对这些文件的新修改。尤其 RoomSync/Session/GameBridge 应逐方法合并。

## 验证与执行配方

本轮已做：AS 括号/重复方法/合并标记检查，Python 配方 AST 检查；确认原生 Encounter、new Land 及两处 CS 调用各保留一次；冻结 recovery-01 全部源码哈希未变；安装宿主哈希未变。静态检查不能证明 AS 编译通过。

`tests/NativeTravelPlanChecks.as` 现含 **33 条独立状态机断言，执行数为 0**。原 31 条覆盖精确构造输入、首次进入/坐标、未启动不能消费、重复启动、重复包、同 ID 新建、源 epoch、World 替换、目的地变化、完成/取消后的旧包、入口锚点不随移动/外部对象修改、无效等级/序号；审阅追加同一 World 更换 Game 的两条。该测试需真实 `NativeTravelPlan.as`，其它生产类不需要，因此原 31 条不能证明 RoomSync 的暂停、seal、旧 pending 配合正确。

`tests/NativeTravelProbe.as` 是可选外部观察器，调用 `install(main, rconnectModInstance, role)`。包装生产回调并原样调用一次，记录 wallMs/getTimer、原生进入/构造前、后续帧观察到 Land 变化、确认可控制状态。它不发起旅行、不改变计划。Land 变化时间是帧观察上界，**不是精确构造结束时间**；精确区间需父会话在独立计时驱动里给原生 new Land 前后加观测，不能据此夸大重叠。观察器用完 dispose，仅恢复自己仍持有的包装。

父会话先按共享测试登记串行安排。以下准备器只复制 AS/Python 文本，不编译、不运行，不处理二进制：

```powershell
python -B -X utf8 experimental/recovery-native-travel/prepare_sources.py build/m52/recovery-travel-01
```

准备器核对准确 recovery-01 源码与本目录清单，输出完整 src、tools/stubs、native-import、tests 和 prepared.json。目标必须是不存在的新 build/m52 目录。**父会话在任何原生编译前另行核对安装宿主仍为 BEFC。** 若宿主变更，应重新只读导出并重做单类补丁，不能直接导入旧类覆盖他人更新。

原生构建：用已验证 FFDec 26.2.1，只导入输出目录的 native-import（仅 Game），生成该隔离目录内的候选宿主；不得写安装版。定向导入后反编译回读 Game，并核对 MainFE/其它类及非代码资源未变。RConnect 构建用输出目录 tools/build_mod.py、显式 amxmlc/java 和该隔离目录的输出路径；不能调用源根默认 release 输出。组件用 AIR 编译配置、SWF 38，仅编译 NativeTravelPlanChecks 和实际 NativeTravelPlan。

已有 RoomEntry/NativeLoading 组件框架复用时，除了新增真实 NativeTravelPlan，还需要给**外部测试替身**的 MapGeneration 添加 nativeTravelSupported=false、TravelGuard.allowTravel 增加可选 travelId 参数。不要为了适配旧替身改生产接口；fixture 的 GameBridge 是 dynamic，但测试涉及新计划时应给 world.game/lands/坐标补真实语义字段。

## 原生验收与仍待审查边界

完整矩阵见上一级 `recovery-loading/nonrandom-plan.md`。至少执行：冷缓存固定图、autoLevel 双角色不同等级、visited/currentCP 不同、显式 curCoord、4 条 Encounter 重定向、同 ID 新建、缓存/随机回归、加载期间新连接、重复/迟到包、拒绝 gotoLand、旧 hold/shared pause、死亡/读档/超时、原生剧情点击、保留已杀敌/破墙/唯一掉落。

还需特别检查两个边界：

- 旧缓存快路可能在 Encounter 最终重定向前已发过一个旧式 prepare；新桥不会把错的最终状态交给加入侧，但可能造成一次额外的预加载。此候选没有复制 Encounter 规则来提前猜重定向，也没有删缓存快路，应在“原请求目标有缓存但最终遭遇目标首次进入”案例测是否需要取消旧预加载。
- 宿主在 commit 后可恢复行动、plan 在 ACK 后清除。已阻止菜单旅行重入，但其它直接触发跨图的路径需原生驱动验证；纯状态机拒绝新计划抢占，不能当作所有原生入口都已阻止的证明。

最终时间比较必须包括离线同组合单人流程、574D、recovery-01、此候选，观察真实构造区间及双方确认可控制的总时长。截图/详细观察器轮次不用于性能百分比。也需检查同机并行生成的 CPU/内存峰值与 checkpoint 尾段；不能只凭显示同一加载图案称达到单人耗时。

准备脚本初稿（混合主机文件读取和文本复制配方）被本地护栏归为 binary-swf-use-release-pipeline 拒绝，没有写入；随后缩小为仅处理源码文本的 prepare_sources.py，正常保存。没有维护授权表、绕过护栏或执行二进制构建。

## 独立审阅追加：提前 seal 与旧交接隔离

原候选存在确定的执行顺序错误：加入侧收到 prepare 时若仍处于共享暂停，`startPreparedMap` 会暂缓；主侧 seal 随后却直接写入 `pending` 并尝试在旧 Land 发送 ready。解除暂停后，启动函数又被这个 `pending` 阻止，无法加载目标地图。原生造图未完成时收到 seal，也不能仅凭退出计数归零宣布生成成功。

本轮修正在原覆盖内完成，仍未编译／运行：

- 提前的 native seal 单独保存，只有同一 World、同一 Game 的计划已被原生入口消费，目标 Land 实际替换，退出流程完成后才应用。新 seal 不提前推进 epoch，也不占用旧房间的 `pending`。
- 接受计划时记录旧 barrier；旧 grant 仍按原 barrier/epoch 与空 travelId 确认，不会错误结束新计划。新加载必须等旧 barrier 完成；没有绕过旧 hold。重复已应用 seal 不重复 ready。
- welcome 补发与 `replayNativePrepare` 本身均检查接收者 nativeTravel 能力。缺原生桥的对侧不会收到补发计划；这不是混合版本完整兼容通过的结论。
- 计划同时绑定 World 和 Game。实际 `World.loadGame` 会保留 World、替换 Game/Pers/gg；下一帧、原生 adopt 或 room 消息入口发现 Game 已换即取消旧计划并作废旧 pending。这里只验证身份规则，没有宣称原生“加载途中读档”入口已复现，跨端取消握手仍未增加。
- 原生加载已开始、ready/busy 同为 false 时若连接意外断开，也会在离线帧清理计划。否则旧计划会一直留住 `nativeTravelPending`，令 TravelGuard 在单人模式仍拦地图菜单。清理不改正在执行的原生退出计数。

新增 `tests/native-room-component/NativeTravelRoomChecks.as`，原正常路径实际为 **45 条组件断言**，此前文档误记为 46 条。它直接驱动未改写的生产 RoomSync 的 `handle` 与 ENTER_FRAME，替身仅提供原生 World/生成边界、网络收发和场景 I/O。覆盖暂停 prepare→提前 seal→解除暂停→只启动一次→真实采用计划并替换 Land→正确 ready/grant/anchor；旧 barrier 不被抢占、旧 ready 尚未发送时继续原交接、旧 grant 正常 ACK；未消费计划、只消费但保留旧 Land 均不能 ready；同 World 换 Game；加载中断线；双方能力门槛与补发。所有场景同时检查不能靠吞掉 RoomSync 异常“通过”。这不是原生造图／TCP／性能测试。

主会话实际运行 [recovery-native-room-component-01](../../build/m52/recovery-native-room-component-01/receipt.json)：编译、AIR exit=0，45/45 检查通过；外层 runner 要求 46，故整轮仍为 `passed=false / Unexpected assertion count`，保留原回执。逐项核对是计数错误：42 个 run 内直接检查加 3 次 complete helper；catch 的失败检查不应计入正常路径。

10-22 只读审阅进一步确认：若已有旧 barrier、又接受了新计划，同一个 World 换掉 Game 后，旧 grant 的 socket 回调可能早于下一帧/adopt。原 `acceptsJoinGrant` 的旧 barrier 分支没有检查绑定身份，会把旧 checkpoint 写进替换后的 Game。现先补 5 条直接驱动 RoomSync 的反例，再最小修复：消息入口先核对 World/Game；身份变化时同时作废旧 pending，避免只清计划后空 travelId 又被接受。原 `before/adopt` 身份取消也作废该 pending。精确差异见 `review-stale-grant.patch`；当前组件为 **50 条，新增反例及修正尚未编译／运行**。没有增加跨端取消握手，替换后可能仍需等待既有失败/重连流程。

纯状态机的原 33 条检查已保持原语义和顺序，外部测试入口现改为 ADDED_TO_STAGE 执行、输出独立存储 `result.json`、退出 AIR；不是新增生产逻辑。

仅准备组件源码（不会启动编译器、AIR 或游戏）：

```powershell
python -B -X utf8 experimental/recovery-native-travel/prepare_component.py build/m52/recovery-travel-component-01
```

输出 `src/NativeTravelRoomChecks.as` 与 `inputs.json`。五个生产类为 RoomSync、NativeTravelPlan、RoomEntryView、RoomCodec、Protocol，逐字节复制并记录来源哈希；前两者取本覆盖，后三者取准确 recovery-01。父会话按共享登记与既有 HiddenProcess/唯一 AppID/内存门槛流程编译及运行，读取 `File.applicationStorageDirectory/result.json` 与完整日志；组件结果只用于功能判据。`prepare_sources.py` 也会携带本组件的源码目录，不能把该目录加进生产 source-path。

要验证新增反例确实能暴露旧源码，可在新的 build/m52 目录准备组件时追加 `--room-source-root build/m52/recovery-native-room-component-01/src`，只替换 RoomSync/NativeTravelPlan 的取源；新 50 条 fixture 不变。旧源码预期失败的是新增旧 grant 场景，不应通过减少断言数或放宽比较改判。该配方本轮未执行，旧冻结结果不改。
