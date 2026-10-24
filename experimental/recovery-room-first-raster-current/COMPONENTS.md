# 当前首次绘制移植：复用组件

本目录最初只准备组件源码，以下准备记录保留当时边界。根会话现已完成六组组件编译与 AIR 执行，251 项全部通过，独立回读见文末；这仍不是原生游戏或性能资格。执行和测试登记由根会话统一安排。没有新增原生驱动，没有改生产源或本次 `src/`。

| 源集 | 入口 | 实际被测类 | 覆盖边界 |
|---|---|---|---|
| `components/crossing` | `RoomCrossingChecks.as` | 本次 RoomSync、EarlyTravelGate；roomfix5 Codec、Protocol、RoomEntryView | 原 92 项过门/READY 回归入口原字节复用；本次未运行，不能沿用历史通过结论 |
| `components/room` | `EarlyTravelRoomChecks.as` | 同上 | 早到 seal、完整恢复期间等待、真实首绘许可、退出计数、ACK/activate、能力不足回退、取消/换档/死亡；断言原字节复用，未运行 |
| `components/guard` | `EarlyExitAuthorizationChecks.as` | 同上，加 roomfix5 原字节 TravelGuard | 新图/重访、剩余 19/10/1 帧退出许可、重复 grant、完成后失效、取消和断连；断言原字节复用，未运行 |
| `components/gate` | `EarlyTravelGateChecks.as` | 本次原字节 EarlyTravelGate | World/Game/玩家/房间身份、票据、后续帧与 renderer 就绪；断言原字节复用，未运行 |
| `components/room` | `EarlyTravelPortChecks.as` | 本次 RoomSync、EarlyTravelGate | 新增 12 项：普通 request 造成 pending=0 的旧房 hold，prepare 成功后解除旧暂停再构造；原生 start 返回 false 后取消、通知并释放双方许可 |
| `components/wall` | `WallFirstRasterChecks.as` | 本次完整 WIV、roomfix5 Codec | 新增 12 项：首次栅格等待期间不观察/改写临时位图，保留完整墙痕状态，解除票据后在实际新位图逐像素恢复 |

成功完整走完原入口时预计分别为 **92 / 36 / 79 / 20** 项，共 227 项；后三项已核历史 `component-result.json`，只是用于识别遗漏/提前退出，不是本次通过数。四个原入口仍原字节。两个新增入口各 12 项，完整预期共 **251** 项，未编译/运行。本次五源集 55 个生成 AS（15 / 16 / 16 / 2 / 6）已准备并通过 `--check`；绑定 RoomSync `DCF929FB…8CCF`、WIV `12EB9457…0A59`。源文件检查成功不是 AS 编译或断言通过。

准备入口为 `components/prepare.py`；直接运行只按固定白名单生成上述五个小源集。加 `--check` 仅核对父目录六类清单、输入与产出哈希、源码文件集和原测试入口。父目录源码有调整时，必须由父会话完成其清单更新，再显式重跑本组件准备；它会拒绝覆盖被手动改过的组件文件。精确来源及哈希在 `components/inputs.json`。

九个既有 I/O 替身来自 `recovery-room-ready-once/component`，原字节复用：RConnectMod、RCLocale、Session、MapGeneration、Log、TravelGuard、TravelPlacement、GameBridge、TcpLink。它们已含 `hostEarlyTravel`、独立许可 acquire/release、`finishFirstRaster`，当前接口无需改替身。guard 组以真实 TravelGuard 替换对应替身；只有页面点击访问使用旧 guard 组的明确替身。组件不会验证真实 MapGeneration/Sand 桥、Session 网络协商或 GameBridge 地形恢复/墙痕实现。

新失败分支使用独立文件 `DecliningTravelGameBridge.as` 的 GameBridge 子类，覆盖 `startSharedTravel` 返回 false；没有改原替身或伪造生产方法。新墙痕入口复用 `recovery-wall-working-set/WorkingSetChecks` 的 160×80 BitmapData/4×2 实墙输入形状和原生 Bullet 联系字段，以及该目录的 GameBridge.probe、Log、Bullet 三个原字节替身。没有提取或模拟 WIV 私有实现，没有带入旧测试用缓存/包装类。原生栅格完成标志为明确 fixture 输入，不能称为真实宿主已首绘。

旧 ready-once 的 Codec 带计时日志、RoomEntryView 缺少当前加载文案回退；两者不带回，改用准确 roomfix5 原字节。Protocol 也直接取 roomfix5。当前真实 TravelGuard 的 `allowTravel` 只有 `landId` 一个参数，guard 组用于防止旧兼容替身掩盖签名错误。

后续编译适配：Port01 因同文件两个 externally visible 定义编译失败，尚未运行 AIR；只将拒绝旅行的替身移到独立 AS，12 项断言不变。生成文件数因此由 55 增至 56（room 由 16 增至 17），新清单为 `73F34A49…7F305`。生成器只写实际变化字节，墙痕源及生产六类未改。先前组件输入和 Port01 失败证据仍在原构建目录保留。

排除 `NativeTravelRoomChecks` 和 `NativeTravelPlan / FirstRasterGate / SeedRasterEntry`。前者依赖旧后备协议，不能作为当前精简移植的资格。旧断言保留不代表新实现已通过；更不能用组件替身宣称原生首绘、并行加载或大图耗时已达标。

既有 room 入口直接走 `prepareMap → prepare → openFirstRaster → nativeConstructed`，无需旧后备协议；guard 入口包含 `visited=true / constructing=false` 的缓存重访。其原生替身每轮新建 Land，不覆盖真实缓存 Land 的引用寿命，也不覆盖同一 Session 连续第二次同地图/种子的 `preparedToken` 重置，以及新增 45 秒超时的真实计时。上述边界须单独验证，不能默认为旧断言已覆盖。

## 2026-10-24 实际组件结果与独立回读

已逐组核对 `intent.json` 的入口、预期数量与全部 `src/` 实际字节，`Checks.swf` 与回执产物指纹，以及 `component-result.json` 每条断言。六组均为编译 exit 0、AIR exit 0、逐条通过、失败数组为空；回执均记录构建期间安装与源未变。下表目录统一在 `build/m52/`，指纹为各自 `receipt.json` 的完整 SHA-256。

| 实际目录 | 检查结果 | 回执 SHA-256 |
|---|---:|---|
| `recovery-room-first-raster-gate-current-01` | 20 / 0 | `31409bb8ac093e43f6d93b645ab4c798f1861d18b94af84cbba94be17b70f386` |
| `recovery-room-first-raster-room-current-01` | 36 / 0 | `519f33a76750a3903ef81fa44d87352fa2c82393eab39472f9c530b9691335e1` |
| `recovery-room-first-raster-guard-current-01` | 79 / 0 | `ca66d6834f60296ef4177bdbb91a4da15a9314cb2f59b6aedfe921884eb58966` |
| `recovery-room-first-raster-crossing-current-01` | 92 / 0 | `ed5cc1acf426611694693f9a528a247d38dce18fe872fa7333c21b82a144bf29` |
| `recovery-room-first-raster-wall-current-01` | 12 / 0 | `0e1a91d5aa3e47a9b153c375d5fdd64ed5b8873d8a11f37594f3e33780a3e191` |
| `recovery-room-first-raster-port-current-02` | 12 / 0 | `14b431b73f7c43e00222a9a1216c19530eae4f7ceeaca94bb116c2f3e56092d7` |

合计 **251 / 0**。被测生产字节与实际编译产品 `6d4655f30bc252e798304bbf99a21458d53eeec1538c6d49eeb04c1a0b655392` 的冻结源码一致：RoomSync `dcf929fb066dc1d807c18176cb4a27485604a1582fc6580c8459d27d697c8ccf`，Gate `544d61b428ca0e3b3daf603eb0a8c8546fc01a64d22834c73f7d90d323f6a814`，WIV `12eb9457f753373ea67516702d464aa4ac1266f651d2bc20bb7b50d2b4c80a59`。这里核对的是实际受测类，不把测试替身称为真实 MapGeneration、GameBridge 或 Session。

准确输入差异：room-current-01 的源码清单还包含旧、未被本次 `EarlyTravelRoomChecks.as` 入口引用的 `EarlyTravelPortChecks.as`（`e0497523a041e9a9d98679ed0fc99147a41fe916512e70aecd63ec6989ed24cb`），没有单独的 DecliningTravelGameBridge 文件。当前 room 源集以及 port-current-02 改为拆分后的入口 `0bc028e9125f756afc0f920a9e01ae466d4de4aee9a28374ec5a9d4ad4d70e72`，并新增替身文件 `c031c3bf467a6da3f7b920e48c90b43911a038507d51b0b504caf155df0c07c7`。其余 room 输入全部相同；guard/crossing 原本使用各自源集，不包含这个 Port 入口，实际全部输入与当前对应组一致。Gate、Wall 与 Port02 的输入也逐项相同。不能以当前总清单冒充此前 room36 的原清单。

Port01 的真实编译失败仍保留，回执 `d94b22a002fbe0ab753cbcaa8cb83e6c7c9ee48a21de7d42759e1eb4617f4e97`，compile exit 1、未启动 AIR；没有覆盖或将失败改判为通过。拆分前后 Port 的 12 项断言正文相同，仅移动测试替身类定义。

组件证明当前真实 RoomSync/Gate 的受测状态转换及 WIV 小位图路径通过既定检查。它们未加载游戏，因此不覆盖当前 A796 宿主首绘、真实 Sand003、双侧网络时序、完整 CS 大图墙痕/视野或单人耗时目标；六份回执的 `native_game_test=false`、`performance_qualified=false` 保持原样。上述未覆盖边界没有因 251 项通过而关闭。
