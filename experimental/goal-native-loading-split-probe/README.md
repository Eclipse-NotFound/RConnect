# 普通分房的原生等待界面观察源码

只准备源码；尚未编译、启动游戏或取得运行资格。正式版、旧驱动及旧回执未改。

来源是 `build/m52/recovery-entry-observer-driver-01/tests` 的 17 份 AS 源码。仅 `RoomEntryProbe.as` 改动，其余 16 份逐字相同，包括房间动作、确认状态机、标量逐项比较与损伤/物品/控制断言。旧产物 BF6 仅为来源证据，不能代替新观察器的实机验证。

入口仍是 `tests/A22RoomEntryTestDoc.as`，继承原 `RoomCooperationTestDoc("random_mane", false)`。原流程覆盖普通分房、主侧加入对方房间、权威移交、死亡后空房重访、旧房消息拒绝和双方物品/墙面状态。未增加地图下一层或背景门动作。

观察器在原最终 `RENDER` 优先级 -2147483648 只读真实 World：

- 实际 `vwait` 对象和原父容器身份不变，`rconnectLoadingUiFaults` 存在且为零；旧三个命名的定制覆盖/复制对象不存在。
- `entryPending` 为真、且原生没有故事/死亡/菜单等显示所有权时，真实等待界面必须可见，场景、背景及 HUD 隐藏。不会把 `busy` 当成本机等待条件。
- 本机确认完成且 `t_exit==0` 的正常状态必须恢复场景、背景及 HUD，不能遗留等待界面。允许原生 exit 18..17 仍持有等待对象。
- 只读既有 `room-test/prepared` 消息后，主侧原动作保证至少 2500 ms 不移动。取前 2000 ms 的最终 RENDER 核同房、无 `entryPending/roomHold`、无等待、场景继续显示；该窗没有实际观察帧即失败。原业务的 stationary 断言不变。
- 不调用 `rconnectLoadingView`，不改 visible/alpha、相机、黑幕、游戏状态或网络消息。未知观察异常明确记失败。

原生黑幕和淡出语义保留，未要求 `vblack` 永远透明。沿用原来的至多两张截图：等待/恢复各一张，黑幕非零时暂缓，结束才编码 PNG；这是显示正确性轮，不授性能资格。仅实际生成的 waiting PNG 才有等待画面像素证据；对象链通过不能冒称截图或 GPU 验证。每帧只检查既有覆盖对象的已知父层，结束时做一次有上限的完整树查重。

构建继续使用原已冻结外部 ABI，不新增游戏声明：

- `build/m52/room-travel-driver-12/ProductionDeclarations.swc`（598D3985…82A7）
- `build/m52/coop-bundle-04/build/GameCombatStubs.swc`（8AA240ED…A61A）
- `build/m52/room-travel-driver-12/entry-room/EffectsHarness.swf`（D52EF430…1086）

新原生桥字段通过 `Object` 动态读取。产品、宿主和当前安装准入由根现有运行器另核，不能把旧 prepared 内的历史安装表当当前环境。这里不复制 SWF/SWC、不引入运行器。

`prepare.py --check` 或 `verify()` 只读核对完整来源清单、唯一变更类、八个原观察方法、关键协议/标量断言和 ABI 指纹。`source.diff` 是唯一观察器与冻结基底的精确文本差分。根后续使用原受监控编译入口构建，再按原房间回归执行；本目录不执行 JVM/AIR。
