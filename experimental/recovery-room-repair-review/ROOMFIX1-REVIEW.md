# roomfix1 独立源码审查

2026-10-23。范围：准确 aura1 + room19 增量 + 原生加载素材；本审查没有编译、启动 AIR、部署或修改根候选。以下是静态证据及待根执行的组件，不能当作实机通过。

## 输入与三方合并

- 正式与基底 `release/RConnectMod.swf`、`build/m52/recovery-aura-offline-01/RConnectMod.swf` 均实际读回 `df0fa0e2ca952e77e5132e75d71e73558dc919c7b8cdeba5da05fc9e94dc01e7`。
- 供体 `build/m52/room-entry-fast-19` / `05124001…57fea`，旧基底 `build/m52/coop-bundle-04` / `574d2b51…41afe`。
- 根候选 `experimental/recovery-room-production/{prepare.py,source-manifest.json,source.diff,src}`；原始 RoomSync 为 `b26b9bac5cecc6e72eefd7767d0da64bf1bff9aa87649c67c3ac95224b370d69`。
- 三个旧/新源码目录数量分别 78、81、78；候选覆盖 11 类，合成 81 类。供体实际改变 10 类，另加新的 RoomEntryView；没有漏入其它实验源。
- `Session`、`PeerGrip`、`TelekinesisVisuals`、`PlayerBodyEffects` 不在 overlay，仍为 aura1 准确文件。`GameBridge` 的实际 overlay diff 与 OLD→ROOM 的 hunk 正文逐行相同，仅行号偏移；因此离线早退、四类光晕改动没有被覆盖。
- `RConnectMod` 仅变版本。`MapGeneration/RoomSync/GameBridge` 是生命周期增量；`NativeRoomState/NativeTileState/TerrainSync/RoomCodec` 是地形保存编码增量；`RoomTerrainView` 复用像素；`RConnectModDomains` 是 CS 公共类查找入口；`RoomEntryView` 换为原生素材。

准备器只锁供体 SWF，没有同时验证供体 source inventory。当前此次实际差异已独立核对；后续重做准备时宜将 room19/prepared.json 的 source 清单也绑定，不能由 SWF SHA 推断旁边源码未变。

## 必须修正的交错

### 加入侧在 unchanged 确认到达前跨门

`RoomSync:462–464` 的 keepOwner 让独占 B 房的加入侧继续活动，并省略 own/fresh。宿主另进 A 后发 seal，加入侧发 ready(B)，接着 B→D；普通门不受 TravelGuard 的 busy 限制。`check()` 记录 D 并发送 request，但旧 readySent 仍为真。旧 grant(B, unchanged) 到达时，`:419–421` 要求 currentSettledRoom，必定抛错。主侧原 `:394` 还会在 pending>0 时丢掉后续请求的调度意图。

不能只放宽该条件：公共尾部 `:444` 会把旧 B 的 term 错授给当前 D。需要按旧 settled 身份确认 B，ACK 后同回调继续 hold D，再接下一轮。若 check 已经发送 D request，不重复发送；同一 TCP 的先后顺序确保它在 ACK 前到主侧。

### 宿主跨门后，旧 ready 不能改成新房交接

`begin()` 可让未换房的宿主继续运行；`commit()` 却按收到 ready 时的当前 loc 取 myKey。旧 seal(A) 的 ready(B, own=null) 不能在宿主已 A→B 时拿旧 records[B] 接管 B，否则会用旧记录回滚原 owner 的进度。

这不是必须伪造私有状态才能到达：双方同 X，加入侧去 B 时宿主仍可走；宿主在 ready 前去 A 会设置 requested，原 commit 把 A 确立后，ACK 又发一次 A 的 seal，双方 owner 可继续走。此轮再汇合会出现上述错误。新的组件分别覆盖该自然前置及已经排队的 B request。

根指定的修正提案将 seal 绑定 `barrierRoom/barrierLand`，仅当旧房确实是 ready、authority 的 settled 房时，允许 `game.inRoom(barrierRoom, commitHeld)` 完成旧事务。不同 Land 或原本已冻结的新目的地突然改房直接拒绝。完成作用域后立即 hold/check 真正新房，ACK 再启动新轮，向原 owner 获取最新 checkpoint。

`inRoom` 只还原 loc/world.loc/land.loc，**不会还原 `_units`、`_loot` 等扫描缓存**。这是既有旧房 checkpoint 路径的同类副作用，不能说它完全纯读。提案限缩条件避免进入旧房 roomRole/restore，gg 的 loc 始终不动；重返新房后的完整交接仍须实际验证缓存、掉落、XP及命中。此点由另一审查者继续独立核查。

## 已准备、尚未运行的源码和组件

- 最终提案：`anchored-crossing-follow-proposal.patch`，SHA `294656bb574094979b45b3c917f5679a7b2418b18d88c1d0b306f080110d6ee8`。
- 产品 RoomSync 提案位于 `components/crossing/rconnect/core/RoomSync.as`，SHA `0dde136cdba947fe671a59e19310a06ac9ced1417ba9e25f649853584bdcfc2e`。还修复跟随 3 秒计时在 busy、pending、加载、暂停等不可行动期间继续流逝的问题；扣除等待区间，新数据在等待中刷新时间不会获得双倍未来时间。
- `components/crossing/RoomCrossingChecks.as`：预计正常 56 条。真实 RoomSync + RoomCodec，显示/原生世界/传输为显式替身。join/host 各两种跨门顺序、自然双跨门前置、Land 身份替换拒绝。没有模拟另一套 RoomSync。
- `components/follow-wait/FollowWaitChecks.as`：预计正常 5 条。真实等待 3300ms，断言加载中不跟随、加载后仍尝试；不改真实计时器或过期阈值。
- `components/crossing-baseline`、`components/follow-wait-baseline` 与上述夹具相同，仅换回准确 roomfix1 RoomSync `b26b9b…69`，应产生旧实现反例。旧 crossing 可能第一组后就因缺后续 seal 终止，不能宣称其余 case 都执行。
- 目录分别作为 source-path，入口分别为 RoomCrossingChecks.as / FollowWaitChecks.as。根复用现有受控组件编译/运行；本审查没有写新测试框架。
- 先前 `unchanged-crossing-proposal.patch` 与 `anchored-crossing-proposal.patch` 是中间提案，保留为过程，**不要把它们当最终完整补丁**。

## 其他 11 类审查结论与边界

- unchanged 仅可用于真正不变的 owner；retained 要求本端仍持有准确冻结房、相同 wire、相同 key，并且仍重建单位/掉落授权。没有发现它绕过敌人、掉落、地雷或权限恢复。fresh 同样要求本端捕获的同一 loc + 相同 wire。
- NativeTileState 对非 Tile、未知 scalar/array、尺寸和 schema 不符合条件时回退原通道；restore 在写入前遍历验证所有行。坐标推导仅用于整数基准，行覆盖仍原样传输；null 保留原 optional scalar 不写入语义。没有发现确定的数据丢弃，但完整原生字段等价仍应以已有组件复验。
- RoomTerrainView 只在无 pending terrain、双方无墙痕且视觉输入逐项一致时复用；保留原生光照、物件与相机副作用。它不是无条件跳过 redraw。普通房及 CS 大图分别需要像素等价，不能由字段比较推导整机通过。
- sceneMerged 对已完成/缓存 Land 读取 CS 实际 state，对正在构造的 Land 读取 nativeEnabled。CS 的 NativeSceneAdapter 还会因基地、专用 continuous_scene、非 48×25 房、单房而不合并，所以构造前布尔值是意图而非结果；完成后的 worldInfo 会再带实际结果。候选应覆盖 host/join 开关相反、新造/缓存/背景房，特别避免把构造前意图当最终几何证明。
- 初始同地图同房也执行 `TravelPlacement.place`，从 hostInfo 的坐标纠正独立随机出生。普通分房后 initial=false，不会把每次进房都传到队友。该信息是最新 hostInfo，尚未冻结为唯一入口锚点；若宿主恢复后在加入侧 grant 前走动，加入侧可能采用新位置。这符合当前“靠近宿主”而非“严格固定出生点”的实现，需实际初始坐标证据。
- 加载素材使用原生 vwait 的独立实例，不调用有输入/剧情副作用的 setLoadScreen。失败状态仍由 NetHud rooms.status 显示，RoomEntryView 本身不画 status。未发现它改变世界加载进度。
- retained/fresh 的冻结假设仍需验证 Sandevistan 正式组合：当前 MEMORY 的 A Sand003 为隔离资格，正式 Sandy 独立手动推进不读 roomHold。普通三程耗时不能代替时停/回放中的完整交接检查。

## 常驻 present / refreshWorld / invalidate

当前 RoomSync 保留与正式 aura1 相同的 ENTER_FRAME before/after、末尾 RENDER 三个入口。联机每帧 before 和 after 各 refreshWorld，RENDER 再 refreshWorld；后者每次查询 applicationDomain 的 fe.World，读 gg/loc。它没有重建房间或扫全地图，不能仅凭调用多就认定主性能首因。

最小安全候选是 `present(e)` 首先判断 disconnected，清理本 overlay 后直接返回，免掉离线 RENDER 的世界反射查询。这个判断不改变联机最终显示顺序。可进一步只在连接状态切换、房间边界、已有 cover 活跃时维护显示，但当前模型**没有覆盖全部原生房切换的唯一事件**，不能直接删最终 RENDER 核验。

RoomSync 的每帧 invalidate 不是唯一触发者：GameBridge.onMirrorFrame 和 ExplorationSync.requestRender 也触发。删 RoomSync 一处不会证明消除了最终 RENDER 开销；roomHold 时 GameBridge 会早退，更不能盲删加载阶段的 invalidate。before/after/present 的重复 show 会在交接期构造点、矩阵、矩形，但仍须定位实际耗时后再减少，不应在功能修正中顺带更换绘制时序。

结论：三方合并保留 offline+aura；发现两条交接身份竞态并准备最小提案与可执行反例。未对本提案做通过宣称，未把旧 room19 或根候选1的测试转记为新提案资格。

## v2 补充：消费已被 READY 覆盖的 request

另一审查者指出，单纯在 pending 期间设置 requested=true，会把随后已经覆盖这个 request 的 READY 又排一次。v2 在接纳 matching barrier/epoch 的 READY 时，只有当前宿主 loc 仍是 barrierRoom，且 peerInfo 与 READY 的 roomKey/curLandId/curCoord/landStage 都一致，才清 requested。本地跨门仍排队；目的地不同的更新请求仍排队。

锚定旧房还新增两层条件：外层 records 必须有 owner=0 且 state.key 与旧房一致；内层 scoped commit 遇到 nativeFresh、不同 settled、未 ready 或 owner 非零即拒绝，不能在 inRoom 中走 roomRole/restore。

- 最终后继：`anchored-crossing-follow-v2-proposal.patch`，SHA `0b4037bca983afa42721a209d7a9376ebd894b8363094a1985f313325a4fcd06`。
- `components/crossing-v2/rconnect/core/RoomSync.as`，SHA `0874c604817bdf9e1c8e48fce6e9717effa245e523bb4cd4916f276dafe09cc5`。
- `components/crossing-v2/RoomCrossingChecks.as` 正常预计 68 条：原 56 + 同目的地 request→READY 不多 barrier 6 条 + 不同目标更新请求不丢 6 条。后一项明示是组件调度健壮性检查，不声称 TCP 会倒序派发。
- `components/follow-wait-v2/FollowWaitChecks.as` 同样 5 条，只有产品 RoomSync 替换为 v2。
- `components/crossing-v2-before-consume` 用相同 68 条夹具和准确 v1 提案 `0dde136…fc2e`，给“多余 barrier”单独反例；前述 roomfix1 baseline 仍保留。
- v1 已被冻结的两个目录完全未改。本审查对子目录的准备无编译、AIR、部署动作；实际运行资格由根对应回执决定。
