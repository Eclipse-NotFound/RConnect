# 首次绘制前恢复：当前版本最小差异审查

2026-10-24。仅源码与既有证据审查；未编译、运行、改安装或复制 SWF。本文件是**移植差异报告，不是已接通的补丁**。

**结论：可复用 early2 的栅格票据及退出许可修正；不应重新设计原生调用栈续体，也不能直接把旧 RoomSync 覆盖 roomfix5。当前最小可行范围仍是 RC 四个既有类＋一个 Gate、宿主三类及真实 Sand003 接口。现有资料不足以把这些接口的拼接当成一个可直接套用的小补丁，因此本次停在准确差异清单。**

## 已证实的路线与未合入原因

`recovery-early-buildsrc`、`recovery-early-host-review`、`recovery-early-restore-review` 属于本会话同一路线，不是未曾验证的新想法。early1 缓存重访死锁源于 grant 提前 `TravelGuard.endTravel()`；early2 D356 将其移至 exit0、首绘和双侧准备均成立后的 `completeEarly`。真实 f95499e5a7 与无诊断 6b322acc0f 均完成三程；后者主 47/0、加 36/0。未取得发布资格的主要原因是整体加载仍慢，且对照入口/实体工作量不完全相同；不能说方案功能已被否定，也不能说已有提速资格。`recovery-early-paint-timing-v3` 只是该路线的观测宿主，不应搬进生产。

关键顺序是：`sceneOpen` 取得 waiting/unpainted 票据 → 保留原 `scenePrepare`、显示对象、相机/GUI、出生和进入副作用 → `Game.enterToCurLand` 尾部 constructed → 原 seal/ready/grant 与完整恢复 → 放开票据 → 下一次原生 `sceneTick/sceneEnsure` 才绘制最终地形。它并没有跳过第一次 `drawLoc` 调用，而是跳过其中昂贵的地块栅格化。恢复里的 `redrawLoc` 仍初始化正确的原生显示环境，但同一票据继续挡住地块绘制；无须挂起同步 AS 调用栈。

## 当前底座所需的具体差分

| 文件 | 最小变化；必须保留的当前行为 |
|---|---|
| RC `MapGeneration` | 接入准确 `Game` constructed/hold/cancel 槽及 Grafon 票据槽，复用旧 acquire/release 的真实 Sand 载体身份合同。保留当前 `seedFor/receive/adopt/sceneMode`；不导入旧非随机地图 `announce/adopt` 协议。 |
| RC `RoomSync` | 在当前 `prepareMap` 的**共同合并地图**事务中协商 earlyId/epoch，缓存早到 seal，constructed 后才发送准备状态；完整 grant 恢复期间票据保持 waiting；真实首绘、原生 exit0、下一帧成立后 ACK/activate，最终才 endTravel。保留当前 barrierRoom/barrierLand、READY 去重、crossedUnchanged、连续过门、跟随计时、stationary owner 不暂停。不得替换整个 begin/commit。 |
| RC `Session` | 仅增加双方 early 能力协商及对应字段存储；缺任一宿主/载体能力回现有路径。不引入旧 nativePrepare/nativeTravel 全套后备分支。 |
| RC `GameBridge` | 跳过“未产生像素”时无意义的 RoomTerrainView 复用预检，完整地形/对象/单位恢复不变；复用 `finishFirstRaster` 在最终真实地形出现后重放墙痕。不得删 shelf 或整表恢复。 |
| 新 `EarlyTravelGate` | 复用已核类的 World/Game/player/Land/Location/renderer 身份、票据、下一帧和 viewReady 条件；不另带 `NativeTravelPlan/SeedRasterEntry/FirstRasterGate` 的旧后备状态机。 |
| 宿主 `Grafon` | 从旧方案只取票据字段/桥、sceneOpen 取票据、sceneEnsure/sceneTick 等待与完成标记、sceneViewReady 等待判据。当前 A796 的颜色、连续场景及照明改动保留；不使用旧 2D/29D SWF。 |
| 宿主 `Game`、`World` | Game 只增加进入流程尾部 constructed 通知与版本/桥；World 复用旧 hold 下继续原生 exit/camera/GUI、阻止同帧 Land/脚本推进、exit16 控制延后及换档/死亡取消。不能仅给 `World.ativateLoc` 加 return：其调用者仍会继续设置出生、激活检查点、照明与进入触发。 |

版本号文件另计。`Land`、`NativeTileState`、`TerrainSync`、普通分房/背景门协议不需要用旧版本替换。旧原生入口 `continuousSceneBeforeRaster` 是同步广播且仅覆盖大场景，没有等待返回值；独立监听该事件不能暂停后续栅格化。

## 本次没有伪装成已闭合的接线

1. 当前 prepare 只有 `target:seed:constructing` 去重，不是旧 Gate 的唯一 earlyId/epoch 事务；当前 `observeHost` 还会清 preparing，普通 seal 可以在原生完成前到达。需在当前类中精确适配持票、早到 seal、重复包与取消，不能省去或拿旧 NativeTravelPlan 假定已存在。
2. 当前 grant 立即 ACK/release；旧 early2 延后到首绘，并保留退出许可。必须仅在准确共同大图事务分支延后，普通 crossedUnchanged/未换房玩家保持现有语义。旧整类覆盖会丢失已部署的这些修正。
3. 正式 Sand CEC6 没有 hold 载体；仅 World.onPause 不能阻止它直接步进。Sand003 已有真实 41 项生命周期、43 项非零冷却和旧 early2 三程证据，但未覆盖敌方补步开启、活动/回放中整旅回退，也没有 A796/当前模组组合资格。本目录不改 Sand，不把缺载体视作 idle。

以上接线需要在当前源码中成组实现并复核，不是增加一个回调就能成立。建议根若继续，限定共同 CS 大图的这一条路径，复用旧 Gate/取消/退出许可用例和现有三程驱动，再保留当前普通房及隐藏门回归；不重做旧 90 类整包，不承诺消除完整恢复本身的约 1.8 秒。

## 准确来源

- 当前 RC：`build/m52/recovery-room-production-05` / SWF `78C052AEA963F1689B705AE1E14D274916AE1A1F7E81933390CAF8D1A88F4699`。RoomSync `1C5AC8D9C761C40D0908A2C048062A7B09F604C6B9FA34272CAE27E27C52A848`；MapGeneration `BA5EA9BF85933329759575CE19E8D5260F9218C1E0AACCCD1FA956D1E045A3A6`；Session `14AAC9A684133740B95A4BBE3CBCEC9F03095965496C292B2D9FFEB54D9F453D`；GameBridge `F7016BFD096CA3C88EA1214733117758B1998B579EC6F3CA9FC9332B605011A9`。
- 当前宿主：A796827173AF7D6FAB9885FB66ECC62182AB5335918A30C7CCE4C44914A238B7；`mods/ContinuousScene/build/generated/scene-compat-20261024/tint/product/pfe.xml` 为 `1D2642C7D55D1F97121738E6AE84996A140EBFEFF686E6706C88CEF82A7338DA`，无旧旅行桥/栅格票据。其 World/Game/Land 语义来源为 `recovery-native-travel-host-01/before/scripts` 的 BEFC，不能拿该目录 after 的隔离 E159 当正式来源。
- 可复用旧修正：`experimental/recovery-early-exit-authorization/src/rconnect/core/RoomSync.as` `B2B6A3785CD60F9CB08FB48D52E3CCE3A757D474DDE35D4F0903D47FE7BAC51E`；`recovery-early-buildsrc/src/rconnect/core/EarlyTravelGate.as` `544D61B428CA0E3B3DAF603EB0A8C8546FC01A64D22834C73F7D90D323F6A814`。
- 原生结果：`experimental/recovery-early-exit-native/RESULTS.md`；实际恢复与首绘顺序：`experimental/recovery-early-restore-review/README.md`；外部许可剩余边界：`experimental/recovery-sandy-hold-native-cooldown/RESULTS.md`。这些是历史证据，不重标为当前组合通过。

## 后续实施状态

上述文字保留最初只读停点。根随后明确要求实际移植，本目录现已准备当前四类增量、原 Gate 及 WIV 单条件，共六类源码；具体状态、构建入口与未验证范围以 `README.md` 为准。追加 WIV 的原因是准确 A796 `scenePrepare` 在票据阻止首绘时仍保留非空 `frontBmp`，不能把它提前当成已绘制墙面。仍未编译、运行或部署，不把本报告改写成已取得提速资格。
