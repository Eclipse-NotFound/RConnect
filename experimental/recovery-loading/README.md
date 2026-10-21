# 回退后：加载问题独立接续

2026-10-21。此目录只有待集成源码和独立外部观察器，未编译、未启动 AIR、未部署。统一集成会话负责接下来的串行构建、实机验证及是否部署；不据此改共享 MEMORY 或其它候选。

## 准确依赖

1. 正式回退基线：`build/m52/coop-bundle-04`，`0.2.23-coop-bundle2`，SWF `574d2b51490ae8b25a1396555600f56a301f8a20ae50104c0e35cf2796441afe`。
2. 必需房间依赖：冻结 `build/m52/room-entry-fast-19`，SWF `051240012891ab8e6e41d30d8fb13ab16d120f41c5d9578a84a9146906257fea`；prepared.json `d11d8f9f04127989e62b669538c088e24200fc7286b9ae15527f1cc3550cd844`。不是活动 experimental/room-entry-fast 目录，避免其它会话后续改动混入。
3. 本目录 `src/` 覆盖以上冻结源，构建时另改版本为 `0.2.24-recovery-loading1`。没有继承 motion2。

room19 相对 574D 的源码差异是：RConnectMod（版本）、RConnectModDomains、MapGeneration、RoomSync、GameBridge、NativeRoomState、NativeTileState、RoomTerrainView、TerrainSync、RoomCodec。准备脚本把各文件前后 SHA 写入新 prepared.json 的 `room19_changes`；后续若和其它功能合并，GameBridge 属于必须逐段核对的重叠文件。

## 查明的问题与本次改动

- 下午安装的 motion2 不含 room19 或 native-loading1；所以原版加载界面和并行旅行候选虽有记录，实际上未进入用户运行版本。这不是成功部署了第1项后又出现复发。
- 原版 World.exitStep 在 20 显示加载、19同步生成、16恢复画面和控制；网络房间尚未确认时，不能直接删除全部遮挡并放行生成副本。room19 保留完整状态确认，区分本机换房与未换房一侧，提前发送 prepare 并在首次共同进入后校准入口；原地主侧提交完自身房间即恢复，不再等加入侧画完。
- `src/rconnect/ui/RoomEntryView.as` 使用原生 `visualWait` 同一个资源类及本地化文字，不含自绘“交接中”文字、字体或绿色底。World 自己的 vwait、剧情、点击状态和层级不被写入；只用同资源副本覆盖尚未确认的场景。断开/确认仍清除自有层。与 native-loading1 相比，SATS 不显示时不创建、更新第二份加载资源。
- `src/rconnect/core/RoomSync.as` 在 room19 上仅去掉加载期间 HUD 的“房间交接中…”状态。失败/超时的可操作错误仍保留，未删暂停、确认、房间身份或消息隔离。
- **原生观察器存在一个应先修的假失败**：旧 RoomEntryProbe 仅收到 ACK 才认为主侧提交完成；room19 已在发送 grant 后恢复，ACK 前一帧可能被旧观察器错误判断为泄露场景。新准备器只改外部观察器：主侧收到 ready、Session 已完成 commit、ready=true/busy=false 且 barrier==term 时，也记录确认。没有降低生产放行条件。
- 旧 NativeLoadingProbe 强制 `tail>0` 才成功，等于要求必须看得到额外等待；新观察器允许没有尾段，但实际加载资源存在且全部显示断言必须通过。截图文件改为通用 runner 能自动收集的 `presentation-*.png`。
- 新观察器记录 ENTER_FRAME 前/后及 RENDER，保留跨双实例可比较的 `wallMs`，避免用两个进程不同起点的 getTimer 直接相减。截图检查与纯性能计时仍分开。

## 已验证与尚未验证

本轮只完成只读来源/SHA核对、源码差异检查和 Python AST 解析。没有把旧147组件检查算作本源码通过，也没有本轮构建或实机结果。

历史证据：room17 有普通分房、状态保留及有限像素比较；room19 新改了 ACK 前恢复和轮廓保留，仅131组件过；native-loading1 仅147组件过，完整原生驱动因占用/内存未启动。**此前两项都不能称原生合格。** 当前宿主5432的 Grafon 与当时像素验证宿主不同，应使用当前准确输入重验。

并行准备还有边界：新随机地图由 Land 构造的种子回调通知，发生在主侧 exit=19、实际生成前；缓存图可在 exit>20 通知。首次进入非随机地图没有随机种子回调，room19 可能仍等宿主完成再通知。这一分支本次没有凭空复制 Game.Encounter / 等级规则来提前生成；要用当前实际地图测出时序后再决定是否新增两阶段旅行协议。不能声称所有地图已同时开始，也不能声称达到单人耗时。

## 主会话执行入口

工作目录 `mods/RConnect`；以下 python 为已定位的 Codex Python。构建器自动申请共享登记，不启动游戏。每个输出必须新建；不要覆盖之前失败证据。

```powershell
python -B -X utf8 experimental/recovery-loading/tools/prepare.py candidate build/m52/recovery-loading-01 --build --registry-wait 900
python -B -X utf8 experimental/recovery-loading/tools/prepare.py drivers build/m52/recovery-loading-driver-01 --build --registry-wait 900
python -B -X utf8 tools/validation/run_native_loading_checks.py build/m52/recovery-loading-component-01 --source build/m52/recovery-loading-01/src --run --registry-wait 900
python -B -X utf8 tools/validation/run_room_travel_timing.py --candidate build/m52/recovery-loading-01 --drivers build/m52/recovery-loading-driver-01 --output build/m52/recovery-loading-map-01 --scenario entry-map --registry-wait 900
python -B -X utf8 tools/validation/run_room_travel_timing.py --candidate build/m52/recovery-loading-01 --drivers build/m52/recovery-loading-driver-01 --output build/m52/recovery-loading-room-01 --scenario entry-room --registry-wait 900
```

纯计时仍用无新增截图/逐阶段日志的 `build/m52/room-travel-driver-12` 的 `scene`/`timing`；对574D、新候选、离线同组合各跑，固定种子仅约束地图布局，仍须核对单位数量/资源负载和实际恢复控制。不要把带观察器这一轮用于性能百分比。

必验场景：首次共同进随机图、缓存重访、普通分房双向各一次、双方分房时其中一方再次换房、双方先后进入同一房、基地/新非随机图、隐藏背景房、剧情点击继续、断开/恢复失败。检查无额外交接字样；未换房者不中断；两侧真实生成时间重叠；入口坐标一致；原生 HUD/菜单/SATS/错误层正常；已杀敌、炮塔/地雷、破墙、门箱、唯一掉落和迟到命中未回滚；完整房间确认前无错误场景可操作帧。

本目录新增文件仅：README.md、tools/prepare.py、tests/NativeLoadingProbe.as、src/rconnect/ui/RoomEntryView.as、src/rconnect/core/RoomSync.as。
