# 原版加载界面接续（RConnect (2)，未部署）

## 请求与边界

用户要求去掉独立“地图交接中”界面，只显示原版“加载中”，并检查加入侧是否等宿主加载结束才开始。统一集成/部署仍归主会话 `01a086bb-378c-7f60-b8e1-50d90ffa0996`。本会话仅维护独立覆盖树，不改其房间或运动活动源码，不混入 motion1。

## 改动

- `experimental/native-loading-ui/src/rconnect/ui/RoomEntryView.as`：移除独立提示文字和绿色底色。使用当前游戏 `vwait` 所属的原版 `visualWait` 资源，接续原生加载结束至房间确认完成之间的等待；同步原版的本地化文字、图案帧、剧情/点击继续提示、位置和颜色。
- 不调用 `World.setLoadScreen`，不抢走/修改原生 `vwait`，不改变原生暂停、淡入淡出或点击状态。原版方法还会隐藏 HUD/场景、重设剧情和点击状态，不能为延长画面而每帧调用它。展示副本使用同一原生类而非截图，自有黑底阻挡尚未确认的地图；菜单、报错和模组控件保持原层级。SATS 的独立场景层使用同样的原版资源。
- 交接的状态确认和布局保护不删除。普通分房时未换房的一方仍由 RoomSync 判断保持可见。
- 本次基于**准确 room19**，继承其提前发送地图准备信息、加入侧提前开始原生旅行的机制。`MapGeneration` 在建图种子确定时调用 `prepareMap`；缓存地图在退出阶段提前发送；`TcpLink` 立即 flush；加入侧接收 `prepare` 调用 `startPreparedMap`。这是代码证据，本轮实际重叠时序仍需实测。当前安装 bundle2 没有这些提前加载优化。

## 冻结与验证

- 安装仍 `0.2.23-coop-bundle2`，SHA `574d2b51490ae8b25a1396555600f56a301f8a20ae50104c0e35cf2796441afe`。
- 房间基线 `build/m52/room-entry-fast-19`，SHA `051240012891ab8e6e41d30d8fb13ab16d120f41c5d9578a84a9146906257fea`。
- 本次冻结 `build/m52/native-loading-01`，版本 `0.2.24-native-loading1`，SHA `f95d830b126fd35672aea7c54b339e80597c321e1906e21de5661b508162c5af`。全部来源与构建输入见 prepared.json；没有覆盖生产 SWF。
- `build/m52/native-loading-component-02`：**147项、0失败、exit 0**，冻结源与安装未变。包含原有131项房间检查和16项原版显示组件检查：原生资源类、文字、淡出层、菜单/错误、SATS、变换坐标、剧情、世界替换与清理。夹具图案是人工组件素材，不等于原版像素或完整游戏通过。
- component-01 编译成功、后台桌面创建 WinError5，未进入 CreateProcessW。默认沙箱恢复时无法读取退出身份；自动审批首次拒绝释放，补充提升只读核对后才通过。准确PID44552/创建标识134370357251116620不存在，匹配描述符 AIR 为0，stdout空且无 process.json；见 `startup-failure-check.json`。共享登记 ab09e305bfff444f9206d5391cf89308 已按正式流程核对释放，未绕过。
- `build/m52/native-loading-map-01`、`native-loading-map-02` 在启动检查被外部 AIR PID86656拦下，**未启动本轮游戏、不算原生通过**。主会话用户随后选择暂不退出、保留候选；不重复询问、不关闭用户游戏。
- 为显示正确性准备 `run_native_loading_game.py`，仅允许 entry-map/entry-room，明确 `functional_only=true / performance_qualified=false`，允许用户游戏保留；共享登记、6GiB启动及512MiB运行保护、安装指纹和隔离方式不变。`native-loading-map-functional-01` 排队后因可提交余量 **4,819,263,488 bytes（4.49GiB）** 未启动AIR；准确登记 `37212bf918154ffb848d712d3cd16374`，证据 `build/cooperation/4368d3f310/memory-before.json`。之后只读采样为3.53GiB。完整原生检查仍未运行，没有加载耗时/并行时序结论。
- 本轮不存在自有运行中AIR或排队。共享登记曾出现的泛“RConnect”功能回归是另一光晕会话，不是统一集成主会话；此处不以会话归属推测作为测试授权或性能依据。

## 后续验证入口

- 本次新外部观察器 `tests/native-loading/NativeLoadingProbe.as` 用于验证实际游戏资源类、图案、文字、层级所有权及等待尾段，记录原生加载显隐时刻并保存 `native-loading-wait.png`。已编译为 `build/m52/native-loading-driver-01`，尚未运行；它不链接到生产候选。
- `prepare_native_loading_driver.py` 在冻结 room-travel-driver-12 上叠加观察器，单独构建 entry-room/entry-map；不动公共驱动源码。注意通用运行器只自动收集 `presentation-*.png`，需从本轮唯一 AIR 存储把 `native-loading-wait.png` 复制至本轮证据目录。
- 同字节功能入口：`run_native_loading_game.py --candidate build/m52/native-loading-01 --drivers build/m52/native-loading-driver-01 --output <新目录> --scenario entry-map --registry-wait 300`；普通分房换 `entry-room`。使用共享登记、独立桌面和存储、原有内存门槛。运行前核对当前安装组合。全退出后的独占检查可用 `run_room_travel_timing.py` 代替。
- 加载耗时与并行开始用未加入截图采样的原驱动12 `scene`/`timing`，不能把显示替换声称成耗时已经缩短。需对照双方 `TRAVEL RESULT exitStart/exitEnd` 和 `RConnectTravel: prepare`，同时确认房间、入口和控制恢复。
- 待原生结果补入本记录并由主会话合并/发布门禁；room19 的原生验证不足不能由组件检查代替。
