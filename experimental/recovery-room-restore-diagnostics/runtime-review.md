# 房间恢复原生诊断 01：结果与有限优化方向

日期：2026-10-22。只读分析已完成的 `build/m52/recovery-room-restore-native-01` / `build/cooperation/2e09dd2325`。本报告没有启动测试、修改候选或安装文件。

结论：加入侧大地图的同步导入约 2.06 秒，但首轮导入后的第一帧又耗时 3.407 秒，另有收到旧快照后的集中处理；不能把全部延迟归因于敌人构造，也不能通过去掉遮罩宣称加载已经等同单人。最值得优先验证的网络方向是**在加入侧确认导入完成前，暂缓向它采集和发送可被最新状态替代的世界镜像**，保持宿主继续运行。不过简单添加 `pending==0` 尚不安全：未发送的能量火花会自动过期，新物体的首次模板建档也会被推迟，必须处理这些明确边界。

## 结果资格与输入

- 原框架 exit 0 / passed true：host 25 项、join 14 项，无 FAIL/错误，双方 DONE。三轮入口相同；大地图 240×125，基地 48×25，种子符合驱动固定输入。
- 独立诊断 `diagnostic_checks_passed=true`；双方各 3 条完整事务、每条 3 个完整 ENTER_FRAME，全部 `scopeMismatches=0`、`openScopes={}`，无解析错误。
- 22 项安装及候选/工具/驱动/宿主输入不变；前后完整输入 JSON 的 SHA 相同。运行没有内存或外来 AIR 中止，实际采样最低可提交余量约 4.834 GiB；这不是 CPU/GPU 无争用证明。
- 候选 B9447B…BCB90，scene driver12，E159…E5D30C 宿主。只有诊断完成资格，`passed/gameplay_qualified/performance_qualified` 仍全部 false，未部署。
- 原框架 `result.json` 和 `framework-result.json` 原字节 SHA 都为 `a455c7b2662f63aca84374d2de3f807b9259a6a760385c153571221c0a1670ad`。
- `diagnostic-result.json` SHA：`8884551f72b760928974480d1db66fdfd54fa4bb7aa1aa5fe658407214e8598a`；前后输入 SHA：`655d9cfcaa7e7eda2a5351523923c84fb6af5a5ea54e565c9632995d36bd51d7`。
- host.log SHA：`545b41b08b491273844e317807a92b754b87679abf42d78f197df9812aae4958`；join.log SHA：`265797fe37a97262c22cfc065b3ff07a064eba847490a2ad464c7ae7fd39182a`。

## 测量口径

`RestoreCostTrace` 从 join sendReady / host commit 开始记录，grant/commit 成功返回后，取下一次完整 ENTER_FRAME 起的前三帧，到第四帧顶部结束。`times` 包含子调用，**父项与子项不能相加**；`preGrantTimes` 也包含等待期间的调用，不是一次纯导入 CPU profile。

`frames[n].times` 的归属一直保持到下一帧顶部，所以包括该帧之后的 socket/Timer 回调，不能都归到 ENTER_FRAME 回调内部。`started→next started` 是帧间墙钟时间；Stage priority 0 范围包含原生 MainMenu 及同优先级其它回调，不是纯 World.step。priority -1 到 -8999 的范围也包含其它模组和未细分工作；当前记录不足以指认某一个模组。getTimer 为毫秒精度；本报告只在同一实例内相减，没有直接相减 host/join 两套 getTimer。

驱动 scene12 的 RoomTravelTimingTestDoc 通过真实 beginMission/gotoLand 行进，`stable()` 后在显示对象 ENTER_FRAME 检查控制标志、记录结果；没有在此路径做 PNG 编码。`TRAVEL RESULT` 是帧观察到恢复条件的时刻，不是精确原生构造结束或已实发按键的响应时刻。诊断插桩、其它模组、日志及进程调度本身仍有开销；本轮没有配对 solo，不能用于“已达到单人耗时”的判定。

## 三轮总体与导入前后

单位毫秒。R0 首次马哈顿，R1 回基地，R2 重访同一马哈顿。

| 项目 | R0 | R1 | R2 |
|---|---:|---:|---:|
| host 原驱动旅行耗时 | 9481 | 4364 | 5214 |
| join 原驱动旅行耗时 | 15633 | 2900 | 8490 |
| join ready 发完→grant 开始 | 1392 | 66 | 1068 |
| join grant 整体处理 | 2063 | 600 | 2057 |
| join grant 返回→首个完整帧顶部 | 885 | 44 | 1063 |
| join 随后三帧至第四帧顶部 | 5156 | 151 | 1896 |
| host commit 整体处理 | 928 | 64 | 821 |
| host commit 返回→收到 ACK 回调开始 | 2640 | 627 | 2665 |

ready→grant 同时包含宿主工作、传输、排队及两进程调度，不能称为纯网络延迟。host 在 ACK 前已恢复运行，故 host 的旅行耗时会早于 join；回基地的两个计时起点也分别由本机收到 depart / 开始原生流程决定，不能由表中差值推断某一侧的固定优势。

证据位置：host.log 45/58、133/140、159/172 行分别是 ready/ACK；join.log 55、86、112 行为 grant；双方三个 RestoreCost 行位于 host 56/138/170、join 70/92/128。

### 加入侧导入内部

下表展示包含关系，不是可相加总表。

| 计时项 | R0 | R1 | R2 |
|---|---:|---:|---:|
| `room.grant` | 2063 | 600 | 2057 |
| 其中 `codec.unpack` | 186 | 17 | 186 |
| 其中 `restore.total` | 1861 | 583 | 1853 |
| restore 内 `terrain.restore` | 616 | 67 | 691 |
| terrain 内 `terrain.nativeRestore` | 526 | 21 | 594 |
| restore 内单位构造累计 | 505 / 136 次 | 20 / 9 次 | 435 / 136 次 |
| restore 内 `restore.reconcileObjects` | 208 | 7 | 204 |
| restore 内 `unit.restoreCall` | 136 | 4 | 139 |
| restore 内 `restore.roomRole` | 26 | 454 | 35 |
| restore 内首次 `mirror.applyUnits` | 24 | 2 | 23 |
| 首次镜像的 hit 构造累计 | 6 / 131 次 | 0 / 9 次 | 5 / 131 次 |

两次大地图都是删除 136 个原生单位，再创建 136 个单位，创建 131 个碰撞代理；访问 91 把枪，其中新建 28 把。耗时最大的一组为完整地形恢复与真实单位构造；并非碰撞代理构造或 maskPrepare 自身。R1 最大的是 `roomRole` 的 454ms，它包含 presentation/projectiles/masks/旧代理等多项清理，本插桩没有把这 454ms 分到具体子调用，不能断言就是 mask 清理。

宿主两次大图的 `checkpoint.total` 为 505/455ms，包含 `terrain.capture` 386/386ms（内含 nativeCapture 298/283ms），另有 `codec.pack` 393/342ms。这些是 join ready→grant 等待中的确定宿主工作，不应重复加到 join 的导入段。

### 恢复后前三帧

| 角色/轮次 | 帧间隔 1 / 2 / 3 | Stage priority 0 范围 1 / 2 / 3 |
|---|---|---|
| host R0 | 231 / 131 / 195 | 101 / 77 / 83 |
| host R1 | 61 / 52 / 57 | 8 / 6 / 8 |
| host R2 | 215 / 220 / 105 | 86 / 91 / 42 |
| join R0 | 3407 / 215 / 1534 | 1378 / 120 / 95 |
| join R1 | 67 / 43 / 41 | 6 / 5 / 6 |
| join R2 | 298 / 1461 / 137 | 39 / 37 / 29 |

- join R0 首帧：Stage ENTER_FRAME 整段 3259ms，其中 priority 0 范围 1378ms，priority -1 之后至 RConnect mask 回调之前 1719ms；RC mirror 为 153ms，RC render-view 为 39ms。presentation.apply 仅 8ms（嵌套在 mirror 内）。因此 3407ms 不能被称为“敌人动画播放耗时”。
- join R0 第三帧：Stage 整段只有 113ms，render.bottom→下一帧顶部有 1413ms。这个帧归属下出现 18 次 applyUnitsSync、390ms；可证明期间有突发处理，但剩余时间未被本插桩细分，不能全部说成同步或 JSON 解码。
- join R2 第二帧：Stage 70ms、render.bottom→下一帧顶部 1354ms；该帧没有 applyUnitsSync 计时。这直接反驳“所有长帧都是单位全量同步”的过度归因。
- join R1 三帧已明显较短；不能把大地图结果平均后隐藏这一区别。

## commit 后的快照积压：证据与门控边界

冻结07源码的确定链条：

1. `RoomSync.as:690–702` 在发 grant 后 `release()`，让宿主原生世界继续运行，但仍保留 `pending` 等 ACK。`canSyncWorld`（495–496）只检查 ready / !busy / 当前已落定房间，不检查 pending。
2. `Session.as:1066–1115` 因而继续每约200ms采集完整 units/objects/tiles/loot；`1219–1231` 继续每约50ms采集 enemyMotion/lootMotion/wallPaint 并广播。
3. `TcpLink.as:onData` 在一次 socket 回调内循环解完已到齐的帧，立即 dispatch；join 的 grant 同步调用结束后，随后完整快照已符合 `rooms.accepts`。`Session.as:415–470` 会逐包 reconcile 对象、地形、掉落并 applyUnitsSync，没有合并旧快照。

本轮可量化部分：R0 的 applyUnitsSync 共30次/634ms，包含导入内1次/24ms；grant 之后29次/610ms，其中**首个完整帧前11次/220ms**，第三帧归属18次/390ms。R2 共16次/344ms，导入1次/23ms；grant 后15次/321ms，其中**首帧前14次/299ms**，首帧归属1次/22ms。结合 host commit→ACK 的2.64/2.665秒，足以确认在加入侧处理旧镜像的额外工作；没有实际发包逐条时间，因此不把所有29/15次都标成“ACK前发送”。

ACK 是 join grant 内、下一完整帧之前发送的。只暂停至 ACK 能削掉导入期间的积压，**不会**抹去 R0 自身3.407秒首帧，也不能防止 ACK 后因这些长帧再次积压。保持这个收益界限，不能承诺一个门控就达成单人耗时。

### 最小优化方向：仅出站世界镜像的导入背压

建议以“只保留当前持久状态和真实有限事件，不反复发送加载期间的旧完整状态”为一个隔离候选，不改变原生恢复流程、恢复字段、主侧模拟或 grant/ACK 的权威规则：

- 新增独立的出站许可，条件可依赖宿主 pending/已提交状态；**不要修改通用 `canSyncWorld`**，它还被接收、伤害/物体回报及分房逻辑使用。不要延后宿主 release，不重开双方暂停界面。
- 许可应在 readUnitsSnapshot/readObjsSnapshot/readTilePatch/readLootSync 和 worldstate 的 enemyMotion 等采集**之前**检查，不能采集后丢包。否则 `captureEffects` 的 fastAt/fastEnd/endSentAt、墙痕 sentUpdates 等会提前消费发送状态。
- 保留玩家小包、房间控制、伤害回执、地图进度与断开处理。整包 worldstate 不应停发，它还承载玩家及旅行身份信息。ACK 后让下一轮发送真实最新完整镜像，不重放积压的全量快照。

但仅这几条布尔判断还不能合并，至少有两条明确反例需要先处理：

1. **短暂特效不是持久状态。** `EnergyImpactVisuals.as:RETAIN_MS/MAX_EVENTS/observeWeapon` 会在 end+1000ms 或超过96条后删记录，独立于发送；`UnitPresentation.capture/captureEffects` 会标记已发送，而普通弹未发送终点最长保留15秒。停采2.6秒并不等于“全部未发效果都还在”。加载期间真实开火、命中后死亡的射手、移除/换房也必须考虑；`readEnemyMotion` 还跳过死亡单位。候选需提供不受重镜像门控的有限事件小通道，或明确可验证的未发送保留与释放机制，不能依赖最终 hp/地形包冒充火花历史。保留当前50ms通道但只挡200ms也不能自动证明死亡射手末次特效不丢。
2. **newObjs 有首次模板边界。** `GameBridge.as:3522–3562` 的 readNewObjs 首次调用把当时 loc.objs 和原生 Area/Trap 当模板并直接返回 null；目前只有200ms分支调用它。若推迟到ACK，期间新生成的 Area/Trap 可能被误归为原始模板而永久漏报。应把“原始模板建档”从“发送增量读取”分离，在准确原生房间快照边界、主侧恢复模拟前建立同一基线；已有基线不能清空或重新吸收新对象，也不要调用 readNewObjs 后丢返回值。

这是一个有明确源证据和可测收益的方向，**不是已证明安全的补丁**。若要先做只改一处且不触及这些事件生命周期的低风险工作，可暂缓这条网络候选；不能用减包为理由接受上述退化。此处未实现任何门控。

验收应直接复用本场景驱动及相同插桩对照，记录 commit→ACK 期间 heavy packet 的实际采集/发送次数应为0、join 首帧前 applyUnitsSync 及字节量下降、grant/首三帧原判据不变；同时验证 ACK前后真实开火火花/爆炸、射手死亡后末次命中、破墙、容器与新Trap/Area、唯一掉落、分房旧房保持活动、重复/错误ACK和断线超时。不能通过清空接收队列或放宽时限取得“通过”。

当前报告仅定位成本和限制，没有新的性能合格结论。完整原始结果、失败判据和输入指纹保留在原运行目录。
