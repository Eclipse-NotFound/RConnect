# A 版卡顿/性能优化考古与 B 适用性清单

日期：2026-10-29。只读调查；未修改 A 源码、B 模组本体、游戏文件，未编译、未启动游戏、未执行 git。

## 0. 一句话结论

A 普通入口（0.2.24-tcp1，`build/github-a-release/src`）真正做过、且有证据的性能工作，集中在**弹丸记录生命周期、完整轨迹复用/合并、地形栅格复用、呈现记录复用、节拍/缓冲边界**；但用户点名的“显示树子记录复用、差异编码路径栈、接收缓冲未读游标、血条紧凑描述、伤害数字静态模板、根 pose 缓存、只发加入显示房副本”**不是 A 普通入口的既有实现，而是 B 主机权威线（field6/field7）已经做过的机制**。B 当前 smooth04 源码中这些机制基本都在；真正还值得从 A 借的，是 A 在“记录退休、尸体跳过、同一姿态不重放、单帧链索引、UI 变化门控”上的几处小机制。

同时纠正一个报告归属：`dense-optimization-2026-10-14.md`、`host-algorithms-2026-10-14.md`、`ab-performance-2026-10-14.md`、`b195-qualification-2026-10-14.md` 记录的是 **B193/B195 主机权威线**的实验与候选，不是 A 普通入口源码的优化。把它们的 `VisualPose`、`TerrainScan`、`SceneSnapshot` 当作“A 已做过”会串线。

## 1. 基线与证据等级

- A：`mods/RConnect/build/github-a-release/src`，86 个 `.as`；公开版本 0.2.24-tcp1（animfix3-l10n + TCP 适配）。仓库内另有 A22 时期源码与报告，属同一 A 线的历史。
- B：`mods/RConnect/build/ab/b190-visual-motion-smooth04-source/src`，129 个 `.as`（B-MEMORY 记为 144 份完整源/5 份覆盖；本目录是给定源码快照）。当前安装身份为 B3-0.1-smooth1（`B-MEMORY.md:13`）。
- 证据等级：
  - **实测收益**：有具体运行/组件数字，且改动与测量对应。
  - **仅结构优化**：源码可见的减少分配/减少遍历/缓存复用，没有对应耗时或帧率测量。
  - **未量化**：报告只说明机制、计数或等价性，不能换算成 CPU/帧率。
  - **功能证据**：只证明画面/生命周期正确，不证明性能。

## 2. A 优化清单（12 个重点领域）

### 2.1 弹丸记录生命周期 / 无视觉辅助对象泄漏

- 问题：爆炸伤害用的辅助 `Bullet`（`vis==null`，原生只活 3 步）也被录成联机记录；旧逻辑在 `flight==null` 时既不设置 `endSentAt`，也不走出生时间清理，记录无限累积。
- A 机制：
  - 记录创建：`rconnect/game/UnitPresentation.as:139-143`（`recorded:true,frames:[],end:0,endSentAt:0`）。
  - 清理循环：`UnitPresentation.as:166-170`，结束记录 `endSentAt` 后 700ms 或未录制记录出生后 700ms 退休。
  - `endSentAt` 改成与 `flight` 无关：`UnitPresentation.as:182-191`（当前版把 `if(int(shot.end)>0 ...)` 放在 `flight!=null` 之外）。
  - 无显示对象不建画面：`rconnect/game/ProjectileVisuals.as:27-33`（`vis==null` 直接返回 null）。
  - 播放数组硬上限 160，超限丢最旧：`ProjectileVisuals.as:105`；移除时同时清 `channel.records`：`ProjectileVisuals.as:192`。
- A 证据：`state/a-stutter-investigation-2026-10-28.md:12-28`；同一真实驱动 7 次 NPC 火箭爆炸、56 个原生无显示对象，停火 5 秒后加入侧空弹道记录 **56→0**（同文件 25-26 行），运行峰值 56→8（同 27 行）。这是**记录生命周期实测**，不是 FPS 实测；报告明确“没有证据量化它占用户全部卡顿的比例”（同 18 行）。
- 证据强度：**实测收益（计数/生命周期）**；FPS 未量化。

### 2.2 完整轨迹复用与重复合并

- 问题：完整快照带整段 `frames`，快速包只带新增帧；接收端对同一弹丸的重复历史反复遍历、分配合并数组。
- A 机制：
  - 快速包只发 `motionAt` 之后的后缀：`UnitPresentation.as:210-239`（`start` 循环 221-222、`frames.slice(start)` 224、推进 `motionAt/motionEnd` 226-227）。
  - 完整轨迹采样的同戳覆盖与 64 点上限：`UnitPresentation.as:152-160`。
  - 完整历史快捷复用：`ProjectileVisuals.as:113-135`；新历史覆盖旧窗口、未丢结束时间且爆炸信息不缺失时直接返回 `fresh`，不再逐点合并（118-123）；否则按源时间合并、保留旧 `end`/`explosion`（124-134）。
- A 证据：`a-stutter-investigation-2026-10-28.md:32-34`（mergeFlight 与快速包新增轨迹；候选只在新历史覆盖旧窗口时复用）；`a-visual-feedback-repair-2026-10-28.md:32`：419,546 个真实轨迹游标比较无差异；03 两近战合计 21,006 个高频帧实例，04 为 2,082 个。报告明确“离线字数不是实际二进制网络带宽，不能冒充 CPU 收益”（同 32 行）。
- 证据强度：**结构 + 等价性实测**；CPU/带宽未量化。另 `a-stutter` 第 54 行记录了“补采终点未证明明显收益，未纳入最终候选”的失败方向。

### 2.3 显示分工（只发加入显示房副本）

- A 是否做过：**没有在发送端按加入方显示房过滤**。
  - 宿主 `readUnitsSnapshot` 发送宿主当前房间的全部单位与武器，不做“加入方正在显示哪个房”的筛选：`GameBridge.as:5572-5651`。
  - `Session.broadcastWorldState` 把本机与所有 peer 的完整 `snap`、宿主 `enemyMotion/lootMotion/wallPaint` 一起广播：`Session.as:1205-1233`；报告确认“原完整快照仍带全历史；主侧定时器和收到加入侧玩家包都会触发世界广播。这些旧广播和编解码路径未改，但会承担新增数据”（`a-stutter` 32 行）。
  - 接收端才按 `sameRoom`/`sameHostRoom` 丢弃不同房的状态：`Session.as:477-482`、`Session.as:513-517`。
- A 证据：这是**已确认的负担**，不是“A 做过的优化”。A 的报告没有把“只发显示房副本”列为已实现收益。
- 证据强度：**未优化/未量化**。
- B 对照：B 已在发送端实现：
  - `HostSession.as:127` 把 `frame.room` 设为加入方 `actors[1].unit.loc`；
  - `HostSession.as:156-173` 的 `projectilesForRoom` 只保留该房弹丸与结束事件；
  - 接收端 `ClientReplica.as:145-155` 再按 `p.room===frame.room && present` 过滤。
  - 结论：**B 已有等价实现，A 不适用**。

### 2.4 显示树子记录复用

- A 是否做过：**没有完整显示树快照/子记录复用**。A 的架构是把状态写到原生 Unit/Weapon 上，不序列化整棵显示树。最接近的复用是“呈现状态记录复用”：
  - 每批同步只为每个 owner 建一次历史武器索引，返回即释放：`UnitPresentation.as:34-47`；武器列表复用该索引：`UnitPresentation.as:49-71`。
  - 每帧原生子弹链只扫一次，按武器分发：`UnitPresentation.as:75-85`；`observe` 使用该索引：`UnitPresentation.as:89-105`。
  - 身体部件按路径复用记录：`PlayerBodyEffects.as:98-110`、`154-161`；隐藏部件只保留可见性，不复制样式：`PlayerBodyEffects.as:115-126`。
  - 同一选中姿态对象跳过整单位 apply：`GameBridge.as:6446-6449`。
- A 证据：`a22-motion-2026-10-15.md:185` 提到“最终视图直接复用已采样的 currentSample，消除每个玩家重复 3 次、每个敌人重复 1 次完整插值”，属结构优化；没有独立耗时。
- 证据强度：**仅结构优化**。
- B 对照：B 已有完整机制：
  - `VisualPose.as:50-51` 按显示对象缓存上一份 pose；`VisualPose.as:88-118` 子记录逐个比较，未变就复用，列表变化才复制前缀；`VisualPose.as:122-150` 整棵未变则返回同一不可变记录。
  - 结论：**B 已有且比 A 完整；A 的呈现记录复用不需要移植**。

### 2.5 差异编码路径栈

- A 是否做过：A 没有 B 那种“路径栈 + 分支克隆”的场景帧差异编码。A 的差异编码主要在房间检查点地形：
  - `RoomCodec.as:45-83`：按 tile 的键集合生成 schema 表，行只写与 schema 基准不同的槽位。
  - `RoomCodec.as:86-99`：`sparseRow` 一次遍历校验键并收集变化值。
  - 旧 JSON 全行格式仍可读：`RoomCodec.as:100-154`。
- A 证据：
  - `state/room-loading-2026-10-19.md:52-63`：24000 格组件样本旧全行打包 3068/解包 1589ms，新稀疏 1992/1193ms；字符 318648→191260。
  - 同文件 76-79 行：30000 格同进程样本旧采集+打包 1001+1052ms，新 1108+507ms；压缩字符 253356→163204，未压缩 1,862,362→782,082 字节。
  - 报告明确“只是组件样本，不是整机加载收益”。
- 证据强度：**实测收益（组件级）**；整机未量化。
- B 对照：B 已有更强的场景帧差异：
  - `FrameDelta.as:20-49`：解码时复用前缀路径、只在真正写入的父/路径克隆分支；`FrameDelta.as:58-94` 编码用一次遍历的路径栈。
  - `NativeFields.as:82-85` 与 `VisualPose.as:147-155` 提供精确前驱的 delta 提示。
  - 结论：**B 已有等价且更完整；A 的 RoomCodec 只可作房间检查点参考，不是 B 帧编码的缺口**。

### 2.6 接收缓冲游标

- A 是否做过：A 有**播放游标**和**轮询游标**，但没有 B 那种“接收字节缓冲未读游标”：
  - 播放游标：`RemoteMotion.as:29-36`（`frames/gaps/offset/cursor/sampledAt/arrivedAt`）；`RemoteMotion.as:118-149` 收包；`RemoteMotion.as:165-212` 采样、游标夹到最新点、消费已过帧。
  - 同戳重复只替换末点、不重置时钟：`RemoteMotion.as:132-135`。
  - 地形轮询游标：`TerrainSync.as:19`、`TerrainSync.as:126`（按房间格数轮转扫描）。
  - A 的 TCP 半包处理是 `TcpLink.as:172-209`：每次 `onData` 把 `_rbuf.position` 归零重新解帧，半包时回退到 `headPos`；不是跨回调保留的未读游标。
- A 证据：`state/three-performance-goals-2026-10-25.md:23-25`：50ms Timer 每回调直接发 PLAYERSTATE；主侧 267 包序号连续、源戳均 67.665ms；加入侧 534 包中 166 个同源戳、367 个正间隔均值 48.951ms（约 20.4Hz）；结论是“只支持节拍不对称事实，不证明 Flash Timer 内核实现”，且没有改 Timer。
- 证据强度：**结构 + 观测**；无收益量化。
- B 对照：B 已有：
  - `Link.as:15-16` `readOffset`，`Link.as:96-117` 完整帧才提交游标、半包保留游标、8ms 有界 drain；`Link.as:124-135` 按已消费前缀压缩。
  - `PlaybackClock.as:3-55` 单一房间播放时钟，`pending` 队列 + `current/next` 游标 + 自适应 65–250ms 缓冲。
  - 结论：**B 已有等价且更强；A 无缺口可借**。

### 2.7 原生血条紧凑描述

- A 是否做过：**没有同步血条描述**。A 的做法是每帧在本地重新跑原生血条布局：
  - `GameBridge.as:440-449` `presentUnitHealth`：对每个存活镜像单位调用 `visDetails()`、`setHpbarPos()`，并把 `hpbar` 挂到 `visObjs[3]`。
  - `MirrorMasks.as:21-29`、`85-89` 处理血条/身体的遮罩引用。
- A 证据：没有针对血条的收益测量；`MirrorMasks.capture` 实测 29ms 被报告为“不是 3 秒主因”，不做复杂全局索引（`state/MEMORY.md:82`）。
- 证据强度：**未量化（且 A 本身是每帧本地重算，不是优化）**。
- B 对照：B 有实现但**实测命中 0、已回退**：
  - `HealthBarPose.as:22-34` 只对已知 `hpBar` 根生成紧凑 `pose+parts`；`36-67` 白名单只接受 `hp_bar3/4` 与非嵌套三槽位。
  - `ReplicaScene.as:294-302` 应用该描述。
  - `B-MEMORY.md:13` 明确“实际 hpBar 存在嵌套动画，撤销未命中的血条缓存，保留原完整同步回退”；`experimental/b-smooth-20261029/README.md` 记录 smooth03 的 compact 实测 0 次命中、smooth04 完全撤销该改动。
  - 结论：**B 部分有/实测无效**；A 没有可借的实现。

### 2.8 伤害数字静态模板

- A 是否做过：A 有伤害数字功能，但**没有“静态模板复用”**：
  - 发送端只发文本/位置/颜色/缩放/寿命，按签名去重：`NativeTextVisuals.as:142-149`、`156-177`；签名包含 `txt:frame:color:sx:sy`（168 行）。
  - 接收端按 kind 取原生 `Emitter.arr`，新建 Part 后写回 TextField：`NativeTextVisuals.as:178-220`；没有复用“原生 visualNumb 的静态显示配方”。
  - 空状态提前返回，不遍历历史：`NativeTextVisuals.as:224-231`。
  - 累计数字优先复用已有 Part（500ms 内）：`HitFeedback.as:23-45`。
- A 证据：`a-visual-feedback-repair-2026-10-28.md:15-16`、29 行：话语/数字双侧真实 Part 文本/颜色/提前取消/重复包不双份；数字 67、累计 65→127 的文本/颜色/frame 均相同。属功能证据。
- 证据强度：**功能实测；性能未量化**。
- B 对照：B 已有专门模板：
  - `DecorativeEffects.as:9-52` 只接受已知 `visualNumb` 的静态配方，缓存 `recipe`（帧+子 TextField），后续只 `captureRoot` 根姿态；`92-107` 用 recipe 安装文本、其余走 `VisualPose.apply/motion`。
  - `SceneEffects.as:34-44` 在特效层应用。
  - 结论：**B 已有等价实现；A 的 native Emitter 方案不是性能模板，不建议移植**。

### 2.9 根 pose 缓存

- A 是否做过：A 有“同一姿态对象不重复 apply”和“同一帧不重复 blit”的局部缓存：
  - `GameBridge.as:6446-6449` `_lastUnitVisual[u] !== selected` 才 `_presentation.apply`；暂停模式切换时清空（`GameBridge.as:89`）。
  - `RConnectAnimationAccess.as:90-93` `painted[unit]` 按 `id/frame/visData` 跳过重复 `u.blit()`。
  - `SatsTargetVisuals.as:13-37` 用签名去重 SATS 复制。
- A 证据：`a22-motion-2026-10-15.md:185`（复用 currentSample）属结构；`three-performance-goals` 没有单独测该缓存。
- 证据强度：**仅结构优化**。
- B 对照：B 已有：
  - `VisualPose.as:40-44` `captureRoot` 与独立 `capturedRoots` 缓存；`50-51` 根记录复用；`122-150` 整棵未变返回同一记录；`147-149` 生成 `capturedDeltas` 供 FrameDelta 复用。
  - `PoseTween.as:12-33` 未变姿态直接返回 `a`；`PoseTween.as:99-158` 确认帧到插值帧只复制变化部分。
  - 结论：**B 已有且更完整；A 的 `_lastUnitVisual` 仍可作为“接收端整单位跳过”的补充思路，但不是根 pose 缓存缺口**。

### 2.10 地形 / 首绘复用

- 问题：换房恢复/重访时完整 `Grafon.drawLoc` 重绘可达数百毫秒；首绘等待与重复栅格化是加载卡顿主项。
- A 机制（真正实现）：
  - `RoomTerrainView.as:8-61` 在恢复前保存本机绘制输入：房间/渲染器、尺寸、样式、`backobjs`、每格 `tileInputs`、轮廓。
  - `RoomTerrainView.as:62-82` `unchanged(loc)` 比较同一 loc/渲染器、尺寸、未 rebuild/recalc、样式/背景/每格输入全部相同。
  - `RoomTerrainView.as:85-98` 命中时只更新原生轮廓、光图、`drawAllObjs`、相机和 HUD，**跳过 drawLoc 栅格重建**。
  - `GameBridge.as:6272-6277` 只有非 retained、地形未 dirty、无墙痕时才构造 `terrainView`；`GameBridge.as:6344-6347` `unchanged` 时 `refresh`、清 dirty、记 `terrainReused`；否则走完整 `tileRedrawIfDirty`。
  - 地形检查点本身也做了紧凑编码：`RoomCodec.as`（见 2.5）、`TerrainSync.as`。
- A 证据：
  - `state/room-loading-2026-10-19.md:15-17`：组件 17 为 126/0；真实大场景 39/0；加入侧基地与大场景重访**明确命中 `terrainReused`**，首入因真实差异完整重画；报告明确“不能用不同运行负载样本计算改进百分比”。
  - `state/nativeui2-loading-review-2026-10-25.md:56-76`：78C 基线加入侧 restore 48ms 且 `terrainReused`；nativeui2 候选 385ms/重绘 383ms，说明复用失败时确实回到完整重画；但“399ms 是比较及重画区段合计，不宣称全部为 drawLoc 独占耗时”。
  - 更早的 A22 分段：`state/a22-followup-2026-10-15.md:92-94`：恢复共 311–665ms，其中整幅房间重绘 251–617ms；采集地形 28–42ms；编码主要是 JSON 文本转换；诊断日志本身有开销，不能当正式改善证明。同文件 132 行：已省冗余编码/采集，但当时“尚无安全条件允许跳过重绘”。
  - `state/journal.md:159`：同一加载轮基线“恢复 48ms 且 terrainReused”，候选“restore385/重绘383”，是 A 侧最强的一次复用对比，但仍是单轮/单场景，不能外推整场。
- 证据强度：**实测收益（房间恢复/重访，场景级）**；首入不获益，整场未证明。
- B 对照：
  - B 有发送端瓦片差分：`SceneSnapshot.as:66-84` 只发变化字段；`ReplicaScene.as:101-144` 只有几何/背景/ink 变化才 `drawLoc`，耐久度 `hp/thre/indestruct` 变化不触发整房重绘（112-128）；`SceneBackdrops.as:17-30` 按栅格 epoch 缓存背景描述。
  - 但 B 在房间变化时 `ReplicaScene.apply` 会 `dispose()` 并新建 `Location`（`ReplicaScene.as:78-93`），没有 A 的“同房恢复前保存栅格、命中 `unchanged` 直接保留”路径；B 的首个房间必然完整绘制。
  - 结论：**B 部分有（发送端差分 + 几何门），A 的“同房栅格保留”在 B 架构下缺失，需要重新设计**。

### 2.11 同步节拍 / 播放时钟

- A 的机制与证据：
  - 50ms Timer：`Session.as:172`（默认 `tickMs:50`，`Config.as:19`）；每个回调发 `PLAYERSTATE`：`Session.as:1022-1026`。
  - 200ms 单位完整快照：`Session.as:1068-1112`；注释明确“AIR 在负载下会合并延迟 Timer，数四个回调会把 200ms 拉到 500ms；用实际经过时间，不做补发突发”（1069-1072）。
  - `broadcastWorldState` 还会在收到客户端包时触发：`Session.as:590`、`606`、`688`、`1065`；报告确认“主侧定时器和收到加入侧玩家包都会触发世界广播”（`a-stutter` 32 行）。
  - 播放缓冲：`RemoteMotion` 普通/敌人/持物分别 100ms 上限（`RemoteMotion.as:47-53`、`151-163`）；`GameBridge.presentationTime` 统一采样时（`GameBridge.as:394`）。
  - 失败/边界证据：`three-performance-goals-2026-10-25.md:23-25`：50ms Timer 没有 `last=now` 节流；主 267 包 seq 连续、源戳 67.665ms；加入 534 包中 166 同源戳，正间隔均值 48.951ms，不能称有效 30Hz；`Session` 独立 Timer 与 ENTER 没有固定先后契约。`a-stutter` 68 行：下一步应采真实慢帧的发送/接收/显示用时，“而不是继续叠未经测量的播放时钟改动”。`a-visual-feedback` 38 行同样说“不应继续给弹丸加独立时钟”。
- 证据强度：**观测边界**；没有证明改节拍能提速，反而有“不要盲改”的否定性证据。
- B 对照：B 已有统一播放时钟：
  - `PlaybackClock.as:3-24` 每房间一条时间线，固定 65ms 起、按观测帧间隔和到达抖动自适应到 250ms；`40-50` `take` 不倒退；`HostSession.as:117-166` 宿主在原生步/`EXIT_FRAME` 发布；`ClientReplica.as:60-89` 解码→clock→render。
  - B-MEMORY/README：smooth04 明确不改同步节拍、战斗、预测/镜头/默认环境（`B-MEMORY.md:13`）；密集播放等待仍约 162–168ms（`B-MEMORY.md:17`）。
  - 结论：**B 已有；A 的 Timer 模型不适用，A 的价值是“先测再改”的边界**。

### 2.12 空转 / GC / 字符串处理

- A 做过的具体点：
  - 离线/无网络时跳过画面采集：`GameBridge.as:58-66` `skipOfflinePresentation`；`GameBridge.as:262-266`、`354-358` 调用；`Session.as:27-30` 仅在从未尝试网络时允许跳过；A 报告说明该捷径在“联机后再 Leave”的同一 Session 不恢复（`a-stutter` 78 行）。
  - 空状态不分配/不遍历：`NativeTextVisuals.as:224-231`。
  - 字号只在变化时重算并缓存：`RCLocale.as:74-93`（签名 `text+width/height`）；报告 `state/github-a-locales-2026-10-29.md:16`、`22`。
  - AMF3 编码避免每个数值走字符串：`BinaryMessageCodec.as:17-61`，32 位整数直接返回、避免 JSON 十进制字符串分配（32-42）。
  - 颜色/滤镜比较避免临时数组：`PlayerBodyEffects.as:46-58`、`66-92`；只在变化时重建滤镜（76-91）。
  - 热路径成员探测的静态字段白名单，避免 `in`/异常：`GameBridge.as:608-641`。
  - 日志降噪：大量 `Log.d` 只在首次/变化时写（如 `GameBridge.as:396-401`、`UnitPresentation.as:463-468`）。
- A 证据：
  - A22 CPU 诊断：`a22-motion-2026-10-15.md:218`：宿主 2142 样本，`BinaryMessageCodec` 372、`Session` 1000、RV 453、WB 255；加入 1702 样本，RV 661（hideEnemies313、applyMask235）、镜像动画272、最终视图96、WB288、`MirrorHitUnit.syncMotion`38；含子调用，不能相加，不能当 FPS 收益。
  - 同文件 122 行：宿主 3431 样本中 JSON stringify 1087、Session 1997；加入 RV463、镜像330、WB248、最终视图181；隐藏 HUD/探索已不在前列。
  - 同文件 152 行：AMF3 微基准 `copy` 465–542ms/30 轮，原 JSON 607–700ms；原始 AMF 183–249ms，不能把原始 AMF 当生产收益。
  - `a22-motion` 155 行：`fix33` 帧间重绘 54/26/33/26ms、游戏帧增量 0；说明“显示/重绘”可以独立于逻辑帧推进。
- 证据强度：**部分实测（CPU 采样/微基准）**；采样是 0.2.22 时代、非孤立归因，不能直接换算当前 B。
- B 对照：
  - B 用 AMF3 + 压缩：`WireCodec.as:11-29`（≥4096 才压缩，1MB/8MB 上限）；`FrameDelta` 只发变化；`NativeFields.as:18-78` 用 `Vector.<String>/Vector.<int>` schema、不可变记录、delta 提示；`VisualPose` 复用不可变数组/记录；`Timing` 只在 probe 时启用。
  - B 的接收有界批处理/压缩：`Link.as:91-135`（8ms 一批、按已消费前缀压缩）；`PlaybackClock` 队列。
  - B 没有 A 的离线捷径，但 B 的 replica/host 仅在 welcomed/active 时创建，空闲路径本身不同；A 的 `skipOfflinePresentation` **不适用**。
  - B 的 UI 仍是每 100ms 全量写文本：`authority/ui/NetHud.as:265-371`；A 有 `RCLocale.fit` 字号缓存，B 没有等价 `fit`。这是一处**低风险小优化**（见 Top 5）。
  - 结论：**B 大部分已有且更强；A 的离线跳过不适用；UI 文本/字号门控是 B 可借的小项**。

## 3. B 源码现状核对（用户点名 12 项的 B 位置）

| 领域 | B 实现位置 | 判定 |
|---|---|---|
| 场景目标索引（补充项） | `SceneSnapshot.as:21,29-38,173-192`（id→Unit target；每 tick 清理时按目标所在房建临时索引）；`ReplicaScene.as:35-53` 目标选择 | B 已有 |
| 弹丸记录 FIFO | `RoomRuntime.as:194-228`（按原生对象链重新构造，不保留跨帧弹丸记录）；`ClientReplica.as:20-21,146-163`（`endedProjectiles/endedOrder/endedHead`，240 tick 退休） | B 已有，未找到 A 式无限累积分支 |
| 显示树子记录复用 | `VisualPose.as:50-51,88-118,122-150` | B 已有 |
| 差异编码路径栈 | `FrameDelta.as:20-49,58-94`；`NativeFields.as:82-85`；`VisualPose.as:147-155` | B 已有 |
| 接收缓冲未读游标 | `Link.as:15-16,96-117,124-135`；`PlaybackClock.as:3-55` | B 已有 |
| 原生血条紧凑描述 | `HealthBarPose.as:22-96`；`ReplicaScene.as:294-302` | B 有代码但实际命中 0/已回退（`B-MEMORY.md:13`） |
| 伤害数字静态模板 | `DecorativeEffects.as:9-111`；`SceneEffects.as:34-44` | B 已有 |
| 根 pose 缓存 | `VisualPose.as:40-44,50-51,122-150`；`PoseTween.as:12-33` | B 已有 |
| 只发加入显示房副本 | `HostSession.as:127,156-173`；`ClientReplica.as:145-155` | B 已有 |
| 地形/首绘复用 | `SceneSnapshot.as:66-84`；`ReplicaScene.as:101-144`；`SceneBackdrops.as:17-30` | B 部分：发送端差分/几何门有；A 的“同房栅格保留”缺失 |
| 同步节拍/播放时钟 | `PlaybackClock.as`；`HostSession.as:117-166`；`RoomRuntime.as:173-193`；`ClientReplica.as:60-89` | B 已有；A 的 Timer 模型不适用 |
| 空转/GC/字符串 | `WireCodec.as:11-29`；`FrameDelta.as`；`NativeFields.as`；`Link.as:91-135`；`NetHud.as:265-371` | B 多数已有且更强；UI 文本门控/离线跳过是差异 |

补充 B 的宿主发布链：`HostSession.capturePresentation` 在原生 `EXIT_FRAME` 后采集整帧（`RoomRuntime.as:50,173-193`），`FrameDelta.encode` 发差量（`HostSession.as:159-165`）。这与 A 的“50ms playerstate + 200ms unitsync + 收包触发 worldstate”是不同架构；不要把 A 的 Timer 结论直接套到 B。

## 4. Top 5：B 可直接借鉴且低风险

> 排序按“证据/收益可能性 × 改动局部性”。前 3 条是显示/采集门控，不改变同步频率、伤害、预测、默认模组环境；第 4 条需要保留最终态，风险中等；第 5 条是 UI 微优化。

1. **无显示弹丸不进入每 tick 状态/差量（A F14A 的直接教训）**
   - A：`UnitPresentation.as:166-191` + `ProjectileVisuals.as:27-33`；无显示辅助对象不再反复扫描/打包。
   - B：`RoomRuntime.projectile` 只按对象链重建状态（`RoomRuntime.as:211-228`），`state.clip` 可为空串（220 行）；`HostSession.projectilesForRoom` 只按房间过滤（`HostSession.as:167-173`），不检查 `clip==""`。加入端 `applyProjectile` 虽在 `clip==""` 时直接返回（`ClientReplica.as:266-267`），但宿主仍每 tick 为这类对象构造 `VisualPose.capture`/状态并发送。
   - 改法：采集时对 `clip==null` 且没有爆炸/抓取/结束事件的普通弹丸直接跳过；结束态仍保留一次。低风险，收益取决于爆炸辅助对象数量；A 只证明了记录数 56→0，不证明 FPS。
2. **死亡/尸体姿态未变且无新弹道时跳过重复采集**
   - A：`GameBridge.as:5525,5533-5539` `_fastDeaths`，按 `sost:animState` 缓存，死亡单位无 pending flight 时不再采集；A 报告把“大量敌人/尸体”列为未完成场景，这是已有的一层防护。
   - B：`SceneSnapshot.capture` 对 `room.units` 中所有非 player 单位每 tick 采集完整 `NativeFields`/`VisualPose`/`HealthBarPose`/`AuthorityAnimation`/weapons（`SceneSnapshot.as:86-102`），没有死亡键跳过。`FrameDelta` 之后会去掉未变差量，但宿主端采集已经发生。
   - 改法：每单位缓存 `sost:animState`；`sost>=3` 且死亡键未变、无新 `projectileEvents` 时只保留首次死亡态，跳过后续完整采集。低风险；必须保留 `ended`/爆炸/武器事件。
3. **确认帧整单位未变时跳过重放**
   - A：`GameBridge.as:6446-6449` 同一个 `selected` 对象不重复 `_presentation.apply`；`a22-motion-2026-10-15.md:185` 的 currentSample 复用也是同一思路。
   - B：`ReplicaScene.applyUnit` 每次确认都 `NativeFields.apply`、`VisualPose.apply`、`AuthorityAnimation.apply`、healthBar（`ReplicaScene.as:184-241`）；`interpolate` 每渲染帧还对所有单位调 `NativeFields.motion`/`VisualPose.motion`（`168-183`）。`FrameDelta`/`VisualPose` 产生不可变记录，未变时 `fields/pose` 常是同一对象。
   - 改法：每单位记录 `lastFields/lastPose/lastHealthBar` 对象身份；相同则跳过字段/姿态重写，但仍处理 attach/层、pet、死亡、SATS、遮罩。低风险；需用真实敌人/血条/暂停/时停回归确认。
4. **单 tick 原生对象链只扫一次并复用（中等风险）**
   - A：`UnitPresentation.as:34-47` 每批建一次历史武器索引、用完释放；`75-85` 每帧子弹链只扫一次、按武器分发。
   - B：`RoomRuntime.capture` 每次宿主步会走 `firstObj`（`RoomRuntime.as:194-210`），同一 step 内 `stepPlayers` 与 `stepLand` 都可能触发（`RoomRuntime.as:117,154`）；`SceneSnapshot.capture` 又走一遍对象链找 loose effects 并标记 projectile（`SceneSnapshot.as:127-149`）。
   - 改法：以 `tick` 为键缓存本 tick 的弹丸/对象身份表，第二趟复用；但必须保留房间 step 后的最终弹丸态和 ended 事件，不能吞掉 `finalState`。**不是纯低风险**，需保留对象链语义回归；收益可能可观（宿主 publish ≈ 62ms / simulate ≈ 36ms 是 B 自己测量的量级，见 `experimental/b-smooth-20261029/README.md`）。
5. **HUD/日志变化门控与字号缓存**
   - A：`NativeTextVisuals.as:156-177` 只在签名变化时发送文本；`RCLocale.as:74-93` 只在文本/尺寸变化时重算字号；A 报告 `github-a-locales-2026-10-29.md:16,22` 明确“只在变化时计算字号并缓存”。
   - B：`NetHud.refresh` 每 100ms 无条件写大量 `.text`（`authority/ui/NetHud.as:265-371`），包括固定标签、状态行、按钮和帮助文本；没有等价的字号缓存。
   - 改法：只在实际值变化时赋值；固定文案预先算一次布局；日志仍按事件。低风险、收益小（10Hz UI），但可减少 UI 文本排版/GC 抖动；不能当帧率主项。

## 5. B 架构下需要重新设计，不宜直接搬 A

1. **A 的同房栅格保留（RoomTerrainView）**
   - A 依赖“同一 `Location` 上恢复检查点，保留已绘制的栅格”，只跳过 `drawLoc`，仍恢复所有玩法字段/轮廓/光图/对象层。
   - B 的房间切换走 `ReplicaScene.apply` 的 `dispose()` + 新 `Location`（`ReplicaScene.as:78-93`），首次/每次换房都重建显示树；直接移植会与 B 的对象重建、`SceneBackdrops`、`TerrainInk`、SATS/暂停栅格冲突。
   - 若要做，应设计为“B 的同一房间检查点恢复”专用路径：不重建 Location，只更新字段/对象，再决定是否 `drawLoc`；并以 A 的 `unchanged` 字段集合 + B 的 `TerrainPatch`/ink 条件为门槛。高复杂度，但 A 的 `terrainReused` 证据（48ms vs 383ms 的单轮对比）说明值得立项验证，不能直接改。
2. **A 的弹丸历史/mergeFlight 模型**
   - A 有“完整快照带全历史 + 快速包带后缀 + 接收合并”，因为 A 的弹丸播放需要逐帧 `frames`（闪电/火焰/激光/缩放）。
   - B 的模型是“每 tick 采当前显示状态 + FrameDelta 差量 + PlaybackClock 插值”，没有每弹丸历史数组；把 mergeFlight 搬进 B 会引入重复历史和额外分配，收益方向相反。
   - 如果 B 的快速弹丸/特殊弹丸观感确实不足，应在 **host 采集侧**增加短窗口轨迹（只在需要的 `clip` 上），而不是在接收侧合并历史。
3. **A 的 50ms Timer + 200ms 完整快照节拍**
   - A 的 Timer 模型已被证明源戳/到达不对称（`three-performance-goals` 23-25），且 AIR 会合并延迟 Timer；A 自己结论是不要盲改。
   - B 已改为宿主原生步发布 + PlaybackClock；不要为了对齐 A 把 B 改回固定 Timer。
4. **A 的离线跳过（skipOfflinePresentation）**
   - A 的普通入口有“离线也注册采集器”的负债，所以需要 `offlinePresentationEligibility`。
   - B 的 `ClientReplica` 只在 welcome 后创建、`HostSession` 只在 accept 后创建（`RConnectMod.as:176-205,245-253`），没有同一路径的离线空转；A 的捷径不适用。
5. **A 的显式显示树/血条/伤害数字模板**
   - A 的架构不序列化显示树，血条是本地每帧 `visDetails`，伤害数字是 native Emitter 重建；B 的 `VisualPose`/`HealthBarPose`/`DecorativeEffects` 已经是另一套更强的方案。
   - 其中 `HealthBarPose` 因实际 hpBar 嵌套动画命中 0 已回退（smooth04）；若要继续，应针对真实嵌套结构重新设计 compact 白名单/回退，而不是恢复 smooth03 的旧缓存。

## 6. 战斗两侧卡顿与加入侧严重卡顿的对应关系

### 6.1 A 侧证据能说明什么

- **轻负载/冻结 AI 的 onlyRC 窗没有卡顿**：18 秒原生跳跃 baseline 主 30.00/加 29.99 fps，RENDER 最大 97/99ms，无 >100ms（`only-rconnect-jump-2026-10-25.md:34-41`）。因此“加入侧一联机就必卡”不是普遍事实，卡顿依赖负载/场景。
- **关掉其他模组能明显恢复**：全 14 模组跳跃基线主 20.20/加 18.37 fps（`three-performance-goals:189-194`）；仅 RConnect 为 30 fps；关闭 LAD/RV/CS 的原生 reduced 轮主 28.83/加 27.56 fps（`three-performance-goals:226`）。这说明 A 的加入侧严重卡顿有相当部分来自**其他模组 + 本机帧推进**，不是纯 RConnect 协议。
- **A 的加入侧 CPU 样本**：RV 661（hideEnemies313、applyMask235）、镜像动画272、最终视图96、WB288、MirrorHitUnit38（`a22-motion:218`）；宿主样本 Session1000、BinaryMessageCodec372、JSON stringify1087/3431（同文件 122）。这些是 A22 时代、含子调用、非孤立归因，不能直接作为 B 的预算，但说明“接收/显示/其他模组”都可能是加入侧主项。
- **A 的爆炸记录泄漏只证明记录数增长**：56 条空记录/7 次真实火箭，停火后不退休（`a-stutter:12-28`）；它可解释“累计爆炸越多、工作量越大”，但报告明确没有量化占全部卡顿比例。
- **A 的普通枪弹仍有整帧停顿**：`a-visual-feedback-repair:38` 明确“普通枪弹仍随整帧偶发变慢；本轮没有证明普通弹或全侧 FPS 提升”；因此 A 的 animfix2/3 不能作为“战斗卡顿已解决”的证据。

### 6.2 B 侧对应

- B 的宿主更慢、加入侧相对快：smooth04 密集 80 敌人加入平均 **44.321→41.921ms**，主侧 **66.580→65.579ms**（`B-MEMORY.md:16`）；这与 A 的“A 宿主 14.42/加入 13.62fps、B 宿主 10.4/加入 16.4fps”方向一致（`ab-performance:22-29`，属 B193 对照，不是 A 优化）。
- B 的加入侧仍有播放等待/欠帧：smooth04 密集等待均值约 **162–168ms**、轻负载欠帧候选 6/10、有 1 个空缓冲样本（`B-MEMORY.md:17`）；smooth04 报告还保留静止首个间隔 292ms、左右步行 1–2px 镜头回摆。说明 B 的加入侧剩余卡顿主要在**时钟/解码/应用**，而不是 A 的记录泄漏。
- B 默认环境已关闭 CS/RV/LAD（`B-MEMORY.md:21,24`），所以 A 的“其他模组占加入侧 CPU”在 B 默认组合中不成立；B 若仍严重卡顿，应优先分解：
  1. host `publish`（`SceneSnapshot.capture` + `FrameDelta.encode` + `Link.send`）；
  2. 加入 `Link.drain`/`WireCodec.decode`/`FrameDelta.decode`；
  3. `PlaybackClock` 欠帧；
  4. `ReplicaScene.applyUnit` + `VisualPose.apply`；
  5. `applyProjectile` + `SceneEffects`。
- B 当前仍每 tick 发送无显示弹丸、每 tick 采集尸体完整姿态、每确认重放整单位；这三项与 A 已修的记录泄漏/尸体采集问题同构，是最可能的“战斗越久越重”方向；但 A 的证据只给机制，不给 B 的帧率数字，必须按 B 自己的 `Timing` 分段测量后再改。

### 6.3 两侧卡顿的共同点

- 都是**主线程单线程工作**：宿主采集/编码/发送、加入解码/应用/渲染，任一侧的每帧工作量都会拉长 ENTER/RENDER 间隔。A 的 B193/B195 报告显示宿主“整理、比较并发布”在 80 敌人约 58ms，模拟约 38ms（`host-algorithms:10-18`，这是 B 线历史，不是 A），与 B 当前宿主 publish≈62ms/ simulate≈36ms 同量级，说明 B 的主侧负担首先是**每确认快照成本**，不是网络带宽。
- 都是**长帧而非平均帧**：A 的 `a-visual-feedback` 保留主侧 210ms、加入 364ms 长帧；B 的 smooth04 保留 292ms 静止长帧（`B-MEMORY.md:17`），更早 field8 还记录过 575ms 静止/387ms 主侧长帧（`B-MEMORY.md:87`）。因此优化目标应是“减少每帧最坏路径/分配”，而不是降同步频率或删敌人。

## 7. 证据边界（哪些 A 收益不能外推）

1. **记录数 56→0**：来自 `stutter-blast-driver-01` 的人造火箭/8 目标驱动，真实 NPC 火箭、8 个辅助对象；不代表自然碰撞、完整战斗或整体 FPS（`a-stutter:28`）。A 自己也说“没有证据量化占全部卡顿比例”（18 行）。
2. **mergeFlight 等价性**：419,546 游标比较是离线逐点等价；高频帧 21,006→2,082 是**离线帧实例数**，不是二进制网络带宽或 CPU（`a-visual-feedback:32`）。
3. **地形复用 48ms vs 383ms**：一对加载轮/特定房间（`journal:159`、`nativeui2-loading-review:56-76`）；首入没有命中，重访/基地才可能命中；不能写成“换房快 300ms”，也不能外推到所有房型。
4. **RoomCodec 稀疏表**：24000/30000 格组件样本，不是整机；30000 格采集反而从 1001 变 1108ms，收益主要在打包/字符数（`room-loading:52-63,76-79`）。
5. **A22 CPU 采样**：0.2.22 时代，37/39 等候选混合，含子调用和 RV/WB 其他模组；不能相加，不能当当前 A/B 的稳定排名（`a22-motion:122,152,218`）。
6. **同步节拍统计**：18 秒单窗，534 包/166 同戳，只证明源戳/到达不对称，不证明 Timer 内核或端到端延迟（`three-performance-goals:23-25`）；A 报告明确下一步是测真实慢帧，不盲改时钟（`a-stutter:68`）。
7. **B smooth04 自身**：同环境 ABAB 单轮、8/80 敌人各 60 秒、原 5% 平均/P95 与重复 1.2 门槛；密集加入 5.4% 改善不能覆盖 292ms 静止长帧、1–2px 镜头回摆和 162–168ms 播放等待（`B-MEMORY.md:13,16,17`）。`HealthBarPose` 的 compact 实测 0 命中，smooth04 已撤回，不能把 field7 的“已有血条紧凑描述”当成当前有效收益。
8. **报告归属**：`dense-optimization`、`host-algorithms`、`ab-performance`、`b195-qualification` 是 B193/B195 线（`host-algorithms:1` 明确“B 主侧算法”；`b195-qualification:1` 明确 B195）。其中 `VisualPose`、`TerrainScan`、`SceneSnapshot` 均不在 A 普通入口源码；引用时应标为 B 线历史，不标为 A 已做。
9. **A 的“离线捷径”边界**：`canSkipOfflinePresentation` 只在“本次 Session 从未尝试网络”时有效；联机后再 Leave 不恢复（`Session.as:27-30`、`a-stutter:78`）。因此不能把 A 的离线表现当联机表现，也不能把该捷径移植给 B。

## 8. 建议的下一步（给 Lead 的接续）

- 先测后改：用 B 现有 `Timing` 分类记录 host.publish / host.delta / client.decode / client.sceneAndMap / client.units / client.projectiles / client.present；在 8/80 敌人、持续轻机枪、含死亡/爆炸的场景下取慢帧，而不是只看平均。
- 先做 Top 5 的 1–3（无显示弹丸、尸体跳过、整单位未变跳过），每项单独 ABAB；不要和同步节拍、预测、默认环境一起改。
- 地形/首绘复用单独立项，先验证 B 是否能在“同一 Location 的检查点恢复”而不重建显示树；若不能，保持现状，仅做发送端差分优化。
- 血条：不要恢复 smooth03 的 compact 缓存；如果要做，先采样真实 hpBar 的嵌套结构，设计新的白名单/回退，再以命中率为准。
- 所有“A 的报告收益”引用时标注证据等级；不要把 A 的记录数、组件毫秒、单轮加载对比写成整场 FPS。

---

### 附：本清单引用的 A 源码位置（按文件）

- `rconnect/game/UnitPresentation.as:34-47,49-85,120-172,182-191,210-239`
- `rconnect/game/ProjectileVisuals.as:27-33,105,113-135,144-170,192`
- `rconnect/game/RemoteMotion.as:29-36,47-53,118-149,151-163,165-212`
- `rconnect/game/RoomTerrainView.as:8-98`
- `rconnect/game/TerrainSync.as:14-22,19,126`
- `rconnect/game/GameBridge.as:58-66,262-266,354-358,394,440-449,5525-5548,5572-5651,5657-5839,5932-5942,6183-6228,6266-6354,6423-6465,6446-6449`
- `rconnect/game/ObjectIdentity.as:8-98`
- `rconnect/game/SatsTargetVisuals.as:13-37`
- `rconnect/game/PlayerBodyEffects.as:46-58,66-92,98-110,115-126,154-161`
- `rconnect/game/NativeTextVisuals.as:142-149,156-177,178-220,224-231`
- `rconnect/game/HitFeedback.as:23-45`
- `rconnect/game/MirrorMasks.as:21-29,78-90,94-132`
- `fe/unit/RConnectAnimationAccess.as:54-93`
- `rconnect/core/Session.as:27-30,172,477-482,513-517,1022-1026,1068-1112,1205-1233,1235-1265`
- `rconnect/core/RoomSync.as`（检查点/恢复；`GameBridge.restoreCheckpoint` 调用）
- `rconnect/net/RoomCodec.as:26-40,41-83,86-99,100-154`
- `rconnect/net/BinaryMessageCodec.as:17-25,26-61,62-75`
- `rconnect/net/TcpLink.as:161-210`
- `rconnect/core/Log.as:17-53`
- `modlocales/connect/RCLocale.as:74-93`
- `rconnect/ui/NetHud.as`（UI 文本刷新，非核心性能）
