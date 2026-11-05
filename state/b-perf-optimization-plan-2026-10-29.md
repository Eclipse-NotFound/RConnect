# RConnect B 战斗卡顿调查与优化方案

- 日期：2026-10-29（Asia/Shanghai）
- 范围：只调查 **B 版（主机权威线，当前安装 B3-0.1-smooth1）**；只读参考 A；**未改 A 源码、未改 B 正式模组本体（release/可玩包 SWF/产品源）、未部署任何新构建**。测试脚本按其常规流程替换了隔离 benchmark 副本中的候选 SWF/配置，未触及正式包。
- 基线：`build/ab/b190-visual-motion-smooth04-source`（source `e2be0722…1cf15`，与安装 SWF `c3118075…ff44fa` 对应）；B 可玩包本体在 `build/ab/b3-playable-190/game/mods/RConnect/release/RConnectMod.swf`，本轮未改。
- 配套审计（同目录，均由只读审计得到）：
  - `experimental/b-perf-investigation-20261029/join-audit.md`（加入侧每帧链路，402 行）
  - `experimental/b-perf-investigation-20261029/host-audit.md`（主侧每帧链路，483 行）
  - `experimental/b-perf-investigation-20261029/a-inventory.md`（A 版考古与归属纠偏，334 行）
  - `experimental/b-perf-investigation-20261029/evidence-table.md`（既有量化证据，337 行）

---

## 0. 结论摘要（先给判断）

1. **“战斗时两侧都卡”有直接证据；“加入侧 Stage 帧率显著差于主侧”在本轮受控 AB 数据中不成立。** 80 敌人持续射击（60 s 四轮）：主侧平均帧间隔 **63.70–75.52 ms**、加入侧 **41.48–47.63 ms**；>100 ms 长帧主侧 **11–50 次/60 s**、加入侧 **1–13 次**。但 8→80 敌人时主侧变慢 **+58.7%～+90.9%**、加入侧 **+24.0%～+38.7%**，两侧都显著退化，加入侧自身确实在变卡。
2. **主侧瓶颈是发布（publish）中的逐单位全量采集，不是网络。** 80 敌人：`host.publish` **32.2–34.2 ms/帧**，其中采集 **21.0–23.0**（单位 **16.8–18.5**：字段 **8.5–9.3**、身体姿态 **9.9–12.1**、原生动画帧约 **1.0–1.1**；瓦片固定 **3.3–3.5**），`host.delta` 约 **2.8**、`send` 约 **2.5**。主侧一帧还跑原生 `simulate` **16.1–16.9 ms**。
3. **加入侧瓶颈是“每个确认帧把全部显示实体完整重放”，而不是“再删字段”。** 80 敌人：`client.present` **17.4–18.8 ms/屏幕帧**（`render` 约 **12.5–14.0**、`tween` **4.3–4.6**）、`receiveBatch` **4.1–4.9**（含 `decode` 每消息 **5.7–6.1**，摊到屏幕帧 **3.3–3.9**）；`replica` 应用 **6.2–7.1 ms/帧**，其中单位 **5.9–6.7**。未变化的单位、特效、血条、武器仍走完整 `NativeFields.apply`/`VisualPose.apply`/`unit.blit`/`addChild`。
4. **帧率与同步节拍强耦合，会把主侧卡顿放大成加入侧等待。** 主侧一帧 = 一个原生世界 tick = 一次发布（标称 30Hz）；单帧超过 33.3 ms 就少一个 tick、少一次发布，加入侧 `PlaybackClock` 会把播放缓冲从 65 ms 抬到上限 250 ms。既有实测：密集播放等待均值 **162–168 ms**、欠帧计数 **22/60 s**，加入侧起始静止首间隔 **292 ms**、左右步行 **1–2 px 镜头回摆** 10/8 次——这些仍未解释，不能把平均帧改善当成“卡顿解决”。
5. **优化分三层：先拿“没变也重放/重复扫描/无显示记录”的低风险收益；再动“采集分级/字段裁剪/脏路径应用/突发预算”；最后才讨论渲染与同步解耦、离屏显式降频等需要产品决策的架构。** 本轮给出分阶段方案、预期量级、风险与验收，不部署。
6. **本轮新的运行测试被环境阻塞（需要下一轮补）：** 已编译带逐帧归因的诊断构建，但 AIR 私有桌面启动失败（`0xC0000142` DLL init；默认桌面探针可启动但会显示窗口且探针 app id 不符合 B 前缀），因此没有新的运行时数据；本报告数字全部来自既有插桩/AB 产物，已标口径。

---

## 1. 证据基础与口径

### 1.1 构建身份

| 标签 | 版本/身份 | 用途 |
|---|---|---|
| baseline | B3-0.1-clientenv1，SWF `c953c068…fc5a0`，source `5854ef39…41dd` | clean-05 的 A 轮、profile-03 的 A 轮 |
| smooth01 | SWF `7e347ddc…432d`，source `ce68d48a…bef` | profile-03 的 B 轮（插桩分项） |
| smooth04/安装 | B3-0.1-smooth1，SWF `c3118075…ff44fa`，source `e2be0722…1cf15` | clean-05 的 B 轮；textmotion/ui/rockets 功能证据；当前安装 |
| dense 诊断 | SWF `1a38b74b…23c8`，原生 SWF `eced04…3063` | 仅作旧构建拆分参考，**不与 smooth 系列混算** |

### 1.2 数据来源

- **clean-05**：同环境 11 模组、8/80 敌人各 60 s、持续轻机枪、ABAB 四轮；Stage 帧间隔与长帧统计（非插桩）。
- **profile-03**：同环境 30 s、8/80 敌人、持续轻机枪、ABAB 四轮；`Timing` 分项（含插桩开销）。
- **b-dense-profile01**：旧 field22 构建、45 s、80 敌人；提供“字段/姿态/血条/动画”内部拆分，只作量级参考。
- **textmotion-02**：smooth04 功能场景，含静止/步行/开火各阶段的长帧与镜头记录。
- **真实窗口 frame-recorder（旁证）**：`pfe-modsettings-rconnect-b-player-{1,2}\Local Store\frame-recorder\frames-v1.jsonl`，10-29 11:05–11:11 的真实双窗口记录；含暂停/加载/切角色，**不能归因战斗**，只用于“真实会话存在超长窗口/焦点切换”的旁证（见 evidence-table §5 D12–D13）。

### 1.3 口径限制（必须与结论一起读）

- 插桩数值含 `Timing` 自身开销；嵌套计时（如 `present ⊃ render`）不能相加。
- 分项数字来自 smooth01 插桩构建，安装字节 smooth04 的密集加入平均值约快 5.4%；因此分项是“量级/排序”，不是安装版精确定额。
- clean-05 的 Stage 间隔包含原生渲染/GPU/系统调度；不是 RConnect 独占 CPU，也不是输入到显示的端到端延迟。
- 292 ms 首间隔发生在 textmotion 静止阶段首个间隔，后续最大约 59 ms；不能当作稳态战斗卡顿，也不能当作噪声。
- 现有 AB 场景是“80 个静止无敌原生尸鬼 + 持续轻机枪”，不含真实 AI 移动、爆炸、死亡、掉落、破墙；真实战斗的特效/弹丸/尸体负载**没有**本轮实测。

---

## 2. 量化现状

### 2.1 Stage 帧间隔（clean-05，60 s；括号为 >100 ms 次数）

| 场景 | 主侧 average / P95 / max（>100ms） | 加入侧 average / P95 / max（>100ms） |
|---|---|---|
| 8 敌人（四轮范围） | 40.10–41.26 / 47–63 / 101–119（0–1） | 33.39–33.44 / 46–47 / 94–99（0） |
| 80 敌人（四轮范围） | 63.70–75.52 / 93–107 / 120–146（11–55） | 41.48–47.63 / 67–78 / 106–131（1–13） |

结论：**平均帧看主侧更慢；加入侧的相对“卡”更可能来自等待/尖峰/可感知平滑度，而不是稳态平均帧。** 这一点必须在下一轮用逐帧归因与端到端延迟测量确认，见 §5.2。

### 2.2 分项（profile-03 04-B，80 敌人，单位 ms/帧；n 为 30 s 内调用数）

| 侧 | 分项 | 均值/帧 | p95/max | 备注 |
|---|---|---:|---|---|
| 主 | `host.publish` | **33.73** | 53/86 | 发布总耗时 |
| 主 | `host.sceneAndPlayers` | 27.00 | 42/81 | ⊂ publish，含场景采集 |
| 主 | `capture.unitsAndTiles` | 21.86 | 35/76 | ⊂ sceneAndPlayers |
| 主 | ├ `capture.units` | **18.34** | 31/72 | 80 单位/帧 |
| 主 | ├ `capture.tiles` | 3.39 | 5/8 | 与敌人数无关、与房间面积成正比 |
| 主 | 字段 `capture.nativeFields` | 9.27 | — | 72,802 次/30 s |
| 主 | 姿态 `capture.pose` | 11.18 | 1/52 | 81,331 次/30 s |
| 主 | `host.delta` | 2.76 | 5/9 | 差异编码 |
| 主 | `host.send` | 2.45 | 4/9 | AMF3+压缩+flush |
| 主 | `host.simulate` | 16.65 | 24/35 | 原生世界步进外框（含 `simulate.room` 14.27、`players` 6.14） |
| 加 | `client.present` | **18.69** | 32/73 | 每屏幕帧 |
| 加 | ├ `client.render` 合计 | 13.99 | — | 每帧约 2 次（确认+插值） |
| 加 | ├ `client.tween` | 4.40 | 9/55 | `PoseTween.frame` 构建插值快照 |
| 加 | ├ `client.sceneAndMap` | 8.73 | 21/26 | ⊂ render，含 scene.apply/interpolate/map |
| 加 | └ `client.players` | 3.65 | — | 两名玩家，确认+插值 |
| 加 | `replica` 应用合计 | 7.11 | — | ⊂ sceneAndMap |
| 加 | ├ `replica.units` | **6.73** | 13/26 | 80 单位/确认帧 |
| 加 | ├ `replica.objectsAndEffects` | 0.36 | 1/3 | LMG 场景；爆炸/文字会增长 |
| 加 | └ `replica.terrain` | 0.02 | — | 本场景无破坏；整房 `drawLoc` 另计 |
| 加 | `client.decode` | 5.77/消息（3.68/帧） | 15/53 | 仅 `FrameDelta.decode`，不含 AMF3 |
| 加 | `network.receiveBatch` | 4.50/帧 | 16/54 | 含 AMF3/解压/apply 等外框 |

旧 dense 构建的内部拆分（仅量级）：主侧每 80 单位 `capture.units` 24.40 = 字段 11.56 + 身体 8.42 + 血条 1.87 + 动画帧 1.65；加入侧对应应用 12.97 = 字段 5.56 + 身体 3.07 + 血条 1.49 + 动画 1.99。与 smooth 系列方向一致，但原生 SWF 不同，不能当精确值。

### 2.3 尖峰/长帧

- profile-03 80 敌人：`client.present` max 73–76 ms、`client.render` max 45–59、`client.tween` max 48–55、`client.decode` max 53–62、`receiveBatch` max 54–63；主侧 `publish` max 79–86、`simulate` max 35–64。
- 长帧不是单一分项造成：一次屏幕帧可能同时包含“收包/解码（最多 60+ ms）+ 多个确认 render + tween + prune/pointer”，叠加超过 100 ms。
- `client.prune`/`client.pointer` 每 render 全扫显示树/单位/物件/特效；`SharedVision.render` 每 RENDER 扫整房光照行，`label.text` 每条 frame 消息重设（label 永远不可见），`applyPreferences` 每帧构造数组+`join(":")`。

### 2.3b 本轮逐帧诊断（Stage 0 首批，`b-perfdiag-run-06`，30 s 双实例，探针构建）

逐屏幕帧记录 `dt + Timing 增量`，按敌人数分组（探针开销存在，作归因不作产品定额）：

| 侧/场景 | n | dt mean / p95 / max | >67 ms | >100 ms | 主要分项（每帧合计） |
|---|---:|---|---:|---:|---|
| 主 8 敌 | 718 | 41.8 / 66 / 128 | 35 | 2 | publish 13.6、simulate 10.4、采集 5.3 |
| 主 80 敌 | 324 | 65.8 / 96 / 176 | 100 | 8 | publish 30.3、采集 19.7、simulate 14.7、delta 2.6、send 2.3 |
| 加 8 敌 | 892 | 33.6 / 46 / 135 | 16 | 2 | present 8.8、render 7.7、players 4.2、receive 1.7、tween 1.1 |
| 加 80 敌 | 698 | 40.6 / 70 / 136 | 42 | 6 | present 17.1（render 12.9、sceneAndMap 8.2、units 6.3、tween 4.0）、receive 3.8、decode 3.0 |

**可归因的长帧（而非平均帧）**：

- 加入侧 80 敌最差帧 **130/111 ms**：`receiveBatch` **48/44 ms**、`decode` **46/42 ms**、`present` 39/43 ms，且 `ready=2`（同一屏幕帧消费了两个确认）。这是**收包/解码突发 + 多确认 render 叠加**，不是单位 apply 单项。
- 另一 102 ms 帧：`present` 59、`tween` 41，`ready=1`；是 **插值快照构造尖峰**。
- 加入侧 8 敌 86 ms 帧：`receiveBatch` 51、`decode` 49，同样是 decode 突发；96 ms 帧是 `present` 68 / `players` 61 的玩家姿态尖峰。
- 主侧 80 敌 176 ms 帧：`publish` 45、采集 27、`simulate` 20；`publish`/采集仍是主侧尖峰主因。
- `ready` 分布（加 80 敌）：0×271、1×421、2×6；**多确认帧虽少，但正好对应 130/111 ms 两个最大尖峰**。GC/堆下降与部分长帧重合（heapDrop=1），但样本不足，不能单独归因 GC。

### 2.3c 解码包级诊断（`b-perfdiag-run-07`，60 s，带 wire/包统计）

在逐帧记录上增加：`wire.decode`（AMF3/解压）、每帧收包数/字节/是否 full、最近发送字节。80 敌加入侧 n=1454：

- 平均 `client.decode`（FrameDelta）3.09 ms/帧、`wire.decode` 0.65 ms/帧；但**长帧中的 decode 达 41–49 ms**，对应包 6.3–13.3 KB、`full=0`、每帧 1–2 个 frame 消息。
- 8 个最长加入帧（91–103 ms）中 4 个由 `receiveBatch`/`client.decode` 主导（43–51 ms），其中 AMF3/wire 只占 1–3 ms → **绝大多数解码时间是 `FrameDelta.decode` 的分支克隆/更新，不是 AMF3、压缩或网络**。
- 其余长帧：`present 73 + tween 50`（102 ms）、`present 34/units 18`（103 ms，`ready=2`）、以及 `heapDrop=1` 普遍出现；GC 与 decode 可能互相放大，但未能分离。
- 主侧：长帧 `publish` 83/73/72 与 `capture.unitsAndTiles` 17/65/62，另 `simulate` 63 ms；`wire.decode` 仅 0.16 ms/帧，可忽略。

**新的优先级判断**：`FrameDelta.decode` 的分支克隆成本（与单位 `fields` 记录 282 字段、整棵 pose 子树的克隆规模直接相关）比“多确认 render”更优先；**H5 字段按消费者裁剪**与 **J11 decode/clone** 应作为下一轮第一组，J8 多确认/收包预算第二组。仅做 UI/标签级微优化不会改变这些尖峰。

结论：**下一阶段优先级应为“收包/解码/多确认突发控制”（J8/M3），其次才是单位未变重放（J1）与插值构造（tween）**；平均帧优化不足以消除用户感知的瞬时卡顿。

### 2.4 播放/延迟/回摆

- 密集播放等待均值 **162–168 ms**（clean-05），`PlaybackClock.delay` 137–177 ms；欠帧计数 **22/60 s**。这是“加入侧画面落后主侧”的直接来源之一，不是 Stage 平均帧。
- textmotion：加入侧静止首间隔 **292 ms**，左右步行镜头反转 10/8 次、最大 1/2 px；两段开火移动无反转。未解释，保留。
- 输入→主侧执行→确认→播放的端到端延迟**没有**直接测量；`delay` 不是端到端延迟。

---

## 3. 根因排序（按对帧预算/体感的预期影响）

### R1 主侧 publish 的逐单位全量采集（最大吞吐瓶颈）

- 80 单位每帧：`NativeFields.capture` 全字段（`NativeFields.as:18-78`）、`VisualPose.capture` 整树（`VisualPose.as:37-152`）、`AuthorityAnimation.capture`（每单位 blit）、`HealthBarPose.capture`、武器/交互采集（`SceneSnapshot.as:85-103`）。
- `capture.tiles` 每帧全房 `spaceX*spaceY` 扫描（`SceneSnapshot.as:66-84`），与敌人数无关；80 敌人时 3.3–3.8 ms/帧。
- 直接后果：publish 32–44 ms → 一帧超 33 ms → tick/发布率下降 → 加入侧 buffer 抬升；形成“主侧越慢，加入侧等待越长”的放大链（`PlaybackClock.as:16-23`）。

### R2 加入侧确认帧“全量重放”而非“差异应用”

- `ReplicaScene.applyUnit` 对每个单位无条件执行 `NativeFields.apply`（全字段迭代）、`NativeFields.apply(inter)`、`unit.blit`、`VisualPose.apply`、血条整树、逐武器 apply（`ReplicaScene.as:184-241`）；未利用 `FrameDelta` 未变化时返回同一不可变分支的身份（`FrameDelta.as:20-49`）。
- `SceneEffects.apply` 对每个特效每个确认帧 `addChild` + `VisualPose.apply`（`SceneEffects.as:16-56`）；`AuthorityAnimation.apply` 无条件 `unit.blit`（`fe/unit/AuthorityAnimation.as:15-20`）。
- 实测 `replica` 应用 6.2–7.1 ms/帧（80 单位），是加入侧最大单块；未变化比例未知（下一轮必须先计数）。

### R3 每屏幕帧的插值/渲染/扫描

- `client.present` 17.4–18.8 ms/帧；`PoseTween.frame` 遍历 2 玩家+全部单位/物件/特效/弹丸并复制数组（`PoseTween.as:99-158`）；`render(tween,true)` 对每个单位 `NativeFields.motion` + 整树 `VisualPose.motion` + 血条 motion + 武器 motion（`ReplicaScene.as:168-183`），每节点 `getChildByName` + `getQualifiedClassName`（`VisualPose.as:194-199`）。
- `prune` 每 render 建 keep Dictionary 并枚举 6 层所有子节点（`ReplicaScene.as:57-73`）；`pointer` 每帧遍历所有单位/物件/特效（`ReplicaScene.as:27-53`）。
- `SharedVision` 每 RENDER 全房瓦片 `getPixel32`/`setPixel32`（`SharedVision.as:131-151`），10 Hz 重建整行字符串（`:28-68`）；不在 present 分项内，真实加入侧 CPU 高于分项之和。

### R4 未变化/无显示记录仍被采集、发送、重放

- 尸体/死亡单位：无变化仍每 tick 全量采集（`SceneSnapshot.as:86-102`；A 线 `_fastDeaths` 经验）。
- 空 `clip` 爆炸辅助弹丸：仍进记录/差量/接收侧 ended 池并走一次 `applyProjectile` 早退（`ClientReplica.as:146-154,266-267`）；A 已修同类“无显示记录不退休”，B 是有界保留但按发数增长。
- 未变化单位/特效/血条契约上仍是“每确认帧完整 apply”，缺少整体短路。
- 血条 compact 在真实 1.02 `hpBar` 命中 0（嵌套 MovieClip），smooth04 已回退；每个敌人血条走 full 姿态重放（`HealthBarPose.as:36-67`）。

### R5 同 tick 重复遍历 / 分配

- 同一原生对象链每 tick 最多 6 次完整遍历：`RoomRuntime.capture` 3 次（`RoomRuntime.as:117,154,185`，第 3 次未计时）+ `SceneSnapshot` 特效链 1 次（`SceneSnapshot.as:129`）+ `PlayerPointer` 每玩家 1 次；另 `projectilesForRoom` 两次、`TimeBridge.snapshot` 两次、`NativeFields.capture(room)` full 帧两次（`SceneSnapshot.as:45,63`）。
- 每帧/每单位新建 Object、Dictionary、数组（`SceneSnapshot` 的 `rendered`/`seen`、`ClientReplica.render` 的 `managed`、`present` 的 `targets`、`SceneEffects.apply` 的 `live`、`PoseTween` 的复制）；增加 GC 压力与尖峰风险（未直接测 GC）。

### R6 收包/解码/边界 flush 的突发

- `Link.drain` 每 socket 事件最多 8 ms，但预算检查在单条消息处理之后（`Link.as:91-123`）；单条 frame 消息可含大量变化并触发 `present(true)` 同步 flush 所有积压确认（`ClientReplica.as:67-74`）。
- AMF3 反序列化/解压未单独计时（`WireCodec.as:21-30`）；payload 复制两次（`Link.as:101`、`WireCodec.as:25`）。`receiveBatch` max 54–63 ms 与长帧同量级。

### R7 战斗破坏触发整房 `drawLoc` 的风险

- `ReplicaScene.apply` 在 tile 几何字段变化时调用 `w.grafon.drawLoc(room)`（`ReplicaScene.as:105-143`）；代码注释与历史记录称整房重绘可达数百 ms；当前 `TerrainPatch.isFrontDestruction` 只覆盖“普通前墙破坏”且逐 tile 批内任一派生字段变化仍回退。真实战斗（门/窗/水/斜坡/混合破坏）触发频率与耗时**本轮未测**，但它是“瞬时卡一下”的强候选。
- 发送端 `capture.tiles` 3.3–3.8 ms 固定成本；接收端地形应用本身 0.02 ms（本场景），但 `drawLoc` 不在该计时内。

### R8 “加入侧更严重”为什么平均帧看不出来（待测假设）

- **缓冲/等待**：加入侧画面落后 162–168 ms，且欠帧 22/60 s；主侧一次 40–80 ms 的 publish 会直接抬高 buffer 上限。
- **窗口焦点/遮挡**：真实 recorder 记录到 focus 在 host/join 间切换，焦点变化伴随 fps 下降（P2 旁证；含暂停/加载，不能当纯战斗归因）。两窗口相互遮挡或最小化时，AIR/DWM 可能降低后台窗口刷新。
- **尖峰而非平均**：`present`/`decode`/`receiveBatch` 的 max 53–76 ms，在真实爆炸/多弹丸/破墙时可能更高；平均 41 ms 掩盖了 100–200 ms 的瞬时停顿。
- **端到端延迟**：操作手感由“输入→主侧→确认→播放”决定，可能显著大于 Stage 帧间隔；需要外部事件时间戳测量。
- **竞态**：合成场景是静止尸鬼，真实 AI 移动/死亡/特效密度未纳入。

---

## 4. A 版对照（已纠偏，避免把 B193/B195 线当成 A）

A 普通入口（0.2.24-tcp1）真正有证据的优化集中在：

| A 机制 | A 证据/位置 | B 现状 |
|---|---|---|
| 无显示爆炸辅助弹丸记录退休（`endSentAt` 与 flight 解耦） | 56→0、峰值 56→8（`state/a-stutter-investigation-2026-10-28.md:12-28`） | B 空 clip 仍进记录/ended 池，有界但按发数增长；值得移植“不建/不重放” |
| 完整轨迹复用/`mergeFlight` 快捷分支 | 419,546 游标离线等价（`a-visual-feedback-repair-2026-10-28.md:32`） | B 已有弹丸 FIFO/完整状态，但可借鉴“新历史覆盖旧窗口直接复用” |
| `RoomTerrainView` 地形栅格复用 | 单轮 48 ms vs 383 ms（`state/MEMORY.md`/recovery 报告） | B 新 Location 架构无等价；只能借鉴“同房保留底图”原则，不能直接搬 |
| `RoomCodec` 稀疏地形表 | 组件级 3068→1992 ms 等（`state/room-loading-2026-10-19.md`） | B 发送端已差分；接收端地形整房重绘仍是风险 |
| `RemoteMotion` 游标/100 ms 缓冲 | 观测边界（`state/three-performance-goals-2026-10-25.md`） | B 的 `PlaybackClock` 已有单时钟游标；B 的 delay 65–250 ms 比 A 的 100 ms 更保守 |

**归属纠偏（重要）**：“显示树子记录复用、差异编码路径栈、接收缓冲游标、血条 compact、伤害数字静态模板、根 pose 缓存、只发加入显示房副本”**不是 A 普通入口的实现**，而是 B 主机权威线 field6/field7 已做的机制（`a-inventory.md:5-9,199-217`）。B 目前这些机制基本都在；真正还值得从 A 借的是：

1. 无显示/不可见辅助记录不进入每 tick 状态/差量（A F14A 核心教训）。
2. 尸体/死亡单位在死亡键未变且无新弹道时跳过重复采集。
3. 已确认姿态/帧未变时跳过整单位重放（A `RConnectAnimationAccess.tick` 的“帧未变不重绘”语义）。
4. 单 tick 原生对象链只遍历一次并复用索引（保留最终弹丸态/ended）。
5. HUD/字号/文本变化门控（小收益但纯局部）。

A 的 onlyRC 约 30 fps、全 14 模组约 18 fps、关 LAD/RV/CS 后约 28 fps；B 默认已关闭 CS/RV/LAD。**不能把 A 的记录泄漏/轨迹复用当成“FPS 已解决”的证据；A 报告本身也明确未证明整体性能。**

---

## 5. 优化方案

### 5.1 目标与验收指标

目标（相对当前 smooth1，同环境 ABAB，8/80 敌人 60 s）：

- 主侧 `host.publish` 33.7 → **≤28 ms**（先拿低风险），进一步 → **≤22 ms**（分级采集）。
- 加入侧 `client.present` 18.7 → **≤16 ms**（低风险），进一步 → **≤13 ms**（脏路径/插值预算）。
- 战斗 80 敌人 >100 ms 长帧次数：两侧各 **减少 ≥30%**（相对同轮 baseline）；播放等待均值不高于 168 ms，欠帧不增加。
- 功能断言不减少：textmotion 111/124、ui 134/91、rockets 57/57、enemies 原生断言、terrainlive、security、loading 全部保留。
- 不改变：同步频率、线上字段语义、伤害/碰撞/AI/动画帧选择、暂停/时停/回放、默认模组组合。

### 5.2 Stage 0：先补测量（只做 probe 构建，不发布）

| 编号 | 测量 | 目的 |
|---|---|---|
| M1 | 逐屏幕帧：`present`、`render`（确认/插值分开）、`tween`、`receiveBatch`、`WireCodec.decode`（AMF3 vs FrameDelta vs clone）、`prune`、`pointer`、`SharedVision.render` | 把 max 53–76 ms 拆到具体段，定位长帧 |
| M2 | 每确认帧：未变化单位比例、仅变换变化比例、特效重放/跳过、血条 compact/full 命中、空 clip ended 数、`drawLoc` 次数/耗时、每帧 apply 记录数 | 决定 R2/R4/R7 的真实收益上限 |
| M3 | 收包分布：每包 bytes/压缩后、每 socket event 消息数、每屏幕帧 ready 数、`Link.drain` 实际批时长、多确认 flush 次数 | 验证 R6 突发假设 |
| M4 | 外部事件时间戳：输入→主侧执行→加入侧屏幕出现的端到端延迟；远程玩家运动连续性/镜头反转计数 | 解释“加入侧更卡”的体感 |
| M5 | 真实战斗场景：`random_mane` 真实 AI 敌人 + 双方真实武器/爆炸/死亡/破墙，至少 60 s；与 80 尸鬼合成场景分开报告 | 补足当前 AB 不覆盖的真实负载 |

要求：M1–M3 用现有 `--profile` 路线（probe 构建，产品不加计时）；M4 需要外部驱动或带时间戳的事件日志；M5 需要真实地图/真实战斗驱动（现有 `random_mane` 驱动可扩展）。**先加计数、后改代码**，避免再次出现“血条缓存命中 0 被当收益”的情况。

> 测量进展：`b-perfdiag-run-06` 已完成一次 30 s 双实例逐帧记录（结果见 §2.3b）；已覆盖 M1 的帧级分项与 M3 的 ready/突发分布。仍缺 M2（未变化单位/特效比例、血条命中、drawLoc 计数）、M4（端到端延迟）、M5（真实战斗）。早期 AIR 私有桌面失败与测试槽排队记录保留，不作为数据。

### 5.3 Stage 1：低风险先行（不改同步语义/伤害/动画结果）

| 编号 | 侧 | 改动 | 机制/位置 | 预期（未实测） | 风险/验证 |
|---|---|---|---|---|---|
| H1 | 主 | 同一 tick 只采集一次对象链；去重 `RoomRuntime.capture` 3→1、full 帧 `NativeFields.capture(room)` 2→1、`projectilesForRoom` 2→1、`TimeBridge.snapshot` 2→1 | `RoomRuntime.as:117,154,185`、`SceneSnapshot.as:45,63`、`HostSession.as:134,160-161` | 1–3 ms/帧，弹幕越密越高 | 事件时点/顺序；rockets/enemies 事件序列对比 |
| H2 | 主 | 缓存静态元数据：每单位 class/clip、mount、武器 id/variant、hpbar 有无、`petOwner`；复用 `rendered/seen/targets` Dictionary 与数组 | `SceneSnapshot.as:86-102,161-192` | 1–3 ms/帧 | 弱键失效/换房清理；enemies/terrain 断言 |
| H3 | 主 | `access.time.phase=="replay"` 提出单位循环；`keyFor(room)` 缓存；`applyPreferences` 版本门控；`InputSource.frame` 去两次数组复制 | `SceneSnapshot.as:88`、`RoomRuntime.as:218`、`RConnectMod.as:157,271-286`、`InputSource.as:28-29` | 0.3–1 ms/帧 | 偏好即时生效、动作顺序断言 |
| J1 | 加 | 确认帧按“未变分支身份”短路：单位 fields/pose/blit/hpbar/武器；特效同 state 跳过 `addChild`/`VisualPose.apply`；周期性 full refresh（换房/首帧/UI/暂停/时控/每 N 帧） | `ReplicaScene.as:184-241`、`SceneEffects.as:16-56`、`FrameDelta.as:20-49`、`AuthorityAnimation.as:15-20` | 2–4 ms/帧（上限接近 6.7 ms 的单位项） | 本地原生/其他模组改动恢复；enemies/textmotion/rockets 像素/层级 |
| J2 | 加 | ~~玩家插值帧用 `VisualPose.motion` 而非 `apply`~~ **已实测失败，撤销** | `ClientReplica.as:235,260` | 原估 0.8–1.5 ms；实测抛 `Interpolated pose has no confirmed native child` | 原因：玩家/武器插值姿态含未 apply 的子节点，`motion` 不能替代 `apply`；保留原 apply。记录见 §5.7 |
| J3 | 加 | `prune`/`pointer` 只在显示集合/选择变化时执行；`projectileSelection` 只在按 Q 时建 targets；`SharedVision` dirty 化；`label`/`applyPreferences` 去每帧/每消息写 | `ReplicaScene.as:57-73`、`ClientReplica.as:38-50,85-86`、`SharedVision.as:19-20,28-68,131-151`、`RConnectMod.as:96,252` | 0.5–2 ms/帧，减少恒定抖动 | 选择/探索/暗房像素；visualfield/exploration |
| J4 | 加 | 空 `clip` 爆炸辅助弹丸不建记录/不进 ended 池/不 apply（只保留宿主伤害语义） | `ClientReplica.as:146-154,266-267`、`SceneSnapshot.as:129-148` | 小项，但随爆炸发数增长 | 弹道事件与爆炸视觉；rockets/explosions 断言 |
| J5 | 加 | `PlaybackClock.pace` 去掉每消息 `concat().sort()`（≤32 元素），保持 `wanted` 公式与 65–250 边界 | `PlaybackClock.as:8-24` | <0.1 ms/消息，减分配 | 逐帧 delay 对比；162–168 ms 不退化 |
| J6 | 加 | `SceneEffects`/`DecorativeEffects` 的 `addChild`/完整 pose 重放条件化（与 J1 合并） | `SceneEffects.as:34-43`、`DecorativeEffects.as:92-107` | 0.2–1 ms/帧（爆炸场景更高） | 层级/顺序/伤害数字；rockets/textmotion |

**Stage 1 合计预期（保守）**：主侧 publish −3～6 ms、加入侧 present −3～6 ms；80 敌人主侧平均帧 65→58–61 ms、加入侧 42→36–39 ms；长帧次数下降但**不承诺**消除 292 ms/162–168 ms。

> 基于 §2.3b 的逐帧数据，**J8（收包/解码/多确认突发控制）应从 Stage 2 提前为下一轮第一优先项**：它直接对应加入侧 130/111 ms 最大尖峰；J1（未变状态短路）次之；tween 尖峰另需 PoseTween 分配/遍历优化。

### 5.4 Stage 2：需要实测的结构性优化

| 编号 | 侧 | 改动 | 预期/风险 |
|---|---|---|---|
| H4 | 主 | **采集分级/范围化**：hot 字段每 publish；cold 字段按变化/低频；离屏/远处/静止单位降频；进视野/受击/换武器/换房时立即全量 | 最大潜力：`capture.units` 18.3 → 10–12 ms；风险=显示滞后/漏事件；需 M2/M5 数据 + 像素对照 |
| H5 | 主 | 字段按消费者裁剪（保留 SATS/血条/武器/模组接口所需），不删字段值本身 | 字段 9.3 → 6–7 ms；需消费者清单 + 逐字段对照 |
| H6 | 主 | 单 tick 对象链索引复用：`capture`/弹丸/`PlayerPointer`/`Security` 共用一次扫描（保留 ended/最终态/顺序） | 1–3 ms；需 hostile AI/感知/弹丸逐值对照 |
| H7 | 主 | `capture.tiles` 事件/脏区驱动，full/换房/回放仍全量；每 N 帧/0.5 s 强制兜底 | 3.4 → 0.5–1 ms；风险=地形不同步（穿墙/看不见破坏）；必须先枚举 TILE 写入者 |
| H8 | 主 | `MapState.capture` visited 增量；`CharacterState`/`map`/`audio` 事件化（保留 HUD 时序） | 1–2.5 ms；风险=HUD 滞后；需 ui/textmotion/security |
| J7 | 加 | **脏路径应用**：利用解码 change ops 只写变化字段/子树；保留首帧/换房/UI 事件 full apply 与周期校验 | `replica.units` 6.7 → 4–5 ms；中等复杂度/不可变历史 |
| J8 | 加 | 突发预算：每屏幕帧最多消费 K 个 ready（保序不丢）、drain 按单消息估算预算、边界 flush 限批；首房/tick0 保持原子 | 压 100–300 ms 尖峰；不改善平均；风险=显示晚 1 帧/首帧时序 |
| J9 | 加 | 血条 compact 放宽（保留 full 回退），或对 hp/armor/alpha 未变的血条跳过整树 apply | 0.5–2 ms；风险=嵌套动画/护盾/boss；必须保留 full 回退与命中计数 |
| J10 | 加 | `VisualPose` 子节点 `name→DisplayObject` 缓存（父节点/numChildren 失效），保持“名字+class→索引”顺序 | 0.5–2 ms；风险=重名/动态子节点 |
| J11 | 加 | decode 拆项后：去掉一次 payload 复制、减少 `branch` clone、评估 AMF3/压缩阈值（本机回环） | 1–3 ms/消息空间；风险=不可变帧共享 |

### 5.5 Stage 3：需要产品/体验决策，暂不实施

- **仿真/发布与渲染解耦**：固定时间步累积器，让主侧 tick 不随渲染帧率下降（会改变 tick 时序/回放/SATS 语义，风险最高）。
- **离屏/远端视觉保真度分级**：远处粒子/伤害数字/次要特效降级或合并；需用户确认“可见缺失”的接受边界。
- **主/加双窗口运行规范**：避免两个窗口互相遮挡/最小化导致后台刷新下降；这属于运行环境建议，不是代码优化，不能代替代码修复。
- **长期协议**：从 AMF3 对象树改为紧凑二进制操作流；收益上限大，但工作量和兼容风险最高，不作为近期项。

### 5.6 不做的改动（与用户约束冲突）

- 降低同步频率/发包频率、减少线上字段值、删除伤害/动画/碰撞字段。
- 降低播放缓冲默认值来“看起来更快”（会以更多欠帧/回摆换延迟）。
- 按距离剔除敌人/特效（可能造成可见缺失）。
- 无证据的播放时钟加速、盲加补帧（历史已失败）。
- 改 A 版或把 A 的记录泄漏结论直接当 B 的 FPS 结论。

### 5.7 本轮 Stage 1 实施记录（候选，未部署）

**v1 `796ec224…c070`（含 J2）已实测失败，保留失败：** textmotion 测试加入侧 FATAL `Interpolated pose has no confirmed native child`（`VisualPose.motion` 被用于玩家/武器插值姿态）。原因是玩家插值姿态可能包含尚未通过 `apply` 建立/挂接的子节点，`motion` 不能替代完整 apply。**J2 从方案中撤销，不进入后续候选。**

**v2 `77d4f837…f9a1`（当前候选，未部署）** 只保留已审查的低风险项：

- `authority/ClassNames.as`（新增）：`DisplayObject` 类名弱缓存，替换 `SceneSnapshot`/`ReplicaScene`/`RoomRuntime` 的重复 `getQualifiedClassName` 调用（类名对同一对象不变）。
- `SceneSnapshot.as`：删除 full 帧重复的 `NativeFields.capture(room)`（原 `:45` 与 `:63` 采两次）；把 `access.time.phase=="replay"` 提出单位循环；类名缓存。
- `ClientReplica.as`：空 `clip` 的爆炸辅助弹丸结束事件不再进入 ended 池/重放；保留玩家/武器插值完整 `apply`。
- `RConnectMod.as`：去掉每条 frame 消息对不可见 `label.text` 的重复赋值（notice/fail 仍更新）。
- `RoomRuntime.as`：弹丸/对象类名缓存。

**功能证据（v2，同字节）**：

| 场景 | 主侧 | 加入侧 | 结果 |
|---|---:|---:|---|
| textmotion | 111 | 124 | passed，0 failed，runtime unchanged |
| ui | 134 | 91 | passed，0 failed，runtime unchanged |
| rockets | 57 | 57 | passed，0 failed，runtime unchanged |

**性能 ABAB（`build/ab/b-stage1-clean-01`，30 s × 2 阶段 × A/B/A/B；A=candidate，B=baseline smooth04）**：

| 阶段 | candidate A 两次 | baseline B 两次 | 判断 |
|---|---|---|---|
| 8 敌主侧 | 41.39 / 36.52 ms | 36.01 / 38.87 ms | candidate 平均约 +4%（在 5% 门槛内，但方向不利） |
| 80 敌主侧 | 69.27 / 61.55 ms | 59.00 / 69.70 ms | 平均约 +1.7%，方向/幅度均被波动淹没 |
| 8 敌加入 | 33.57 / 33.34 ms | 33.36 / 33.33 ms | 基本持平 |
| 80 敌加入 | 40.79 / 38.07 ms | 37.61 / 43.13 ms | 平均约 −2.3%，但 baseline 自身波动 14.7%，不能分离 |

结论：**本轮 Stage 1 v2 只有功能资格，没有可分离的稳定性能收益；不晋升、不部署。** 不能把 join 80 敌的约 2% 当作收益；主侧方向不一致。ABAB 执行与重复门槛通过，但性能门槛的“收益”不成立。

**尚未完成**：enemies/terrainlive/security/loading 功能回归；真实战斗/端到端延迟；Stage 0 逐帧计数。由于 v2 无可分离收益，不继续扩大部署范围。

### 5.8 J11 稀疏字段候选（**已部署 2026-10-31**）

针对 §2.3c 的 `FrameDelta.decode` 克隆尖峰，按“保留不可变全量 base + 累积变化键”的方式实现：

- `FrameDelta.decode`：对 `scene.units/objects/.../fields` 的 grouped update 不再克隆整份 200+ 字段记录；保留原 `fields` base，生成不可变 `fieldsDelta`（仅变化键，含删除键过滤）；全量帧仍保留完整 fields。
- `FrameDelta.refreshMotion`：每帧为 scene units 生成 10 个 `NativeFields.MOTION` 快照，插值走 `motion`，不再依赖完整 fields 克隆。
- `ReplicaScene.applyUnit/applyObject`：应用 `fields` base 后再应用 `fieldsDelta`；新单位/物件构造读取有效字段（`id/tr/X/Y/sloy`），修复新 UnitAlicorn 在新单位+delta 情况下拿到旧/缺字段的问题。
- `PoseTween`：scene unit 插值使用 `motion` 快照，但输出仍保留参考兼容的 `fields`（tween 上删除 motion，避免接口差异）。
- Probe/SceneChecks 读取有效字段（`NativeFields.get/has`），保持测试断言对稀疏记录正确。

**功能证据（候选 `build/ab/b-j11-03`，`6d540c20…f842`，源 `b-j11-source-01`）**：

| 场景 | 主侧 | 加入侧 | 结果 |
|---|---:|---:|---|
| textmotion（v3 同字节） | 111 | 124 | passed |
| rockets（v3 同字节） | 57 | 57 | passed |
| terrainlive（v3 同字节） | 185 | 130 | passed |
| enemies（v3，含 UnitAlicorn 新单位） | 57 | 57 | passed；baseline 对照同为 57/57 |
| loading（v3） | 75 | 69 | passed |
| security（v3） | 88 | 63 | host 1 失败，与 baseline 对照同失败（88/1，原生安全阶段未完成，保留失败） |
| ui（v3，修正外部探针后） | 127 | 84 | passed；baseline 同驱动 127/84 通过 |

> UI 首轮失败已定位为**外部测试探针**直接读 `scene.objects[i].fields.nazv`，在稀疏字段下读到 base 而漏掉 `fieldsDelta`；不是产品功能失败。已在 `tools/host_authority/field2_driver/BUiCases.as` 改为读取有效字段并重建 `prepared-smooth-07.json`；同驱动下 candidate 与 baseline 均为 127/84 通过。其余产品侧 probe 已用 `NativeFields.get/has` 读取有效字段。

**逐帧诊断对比（60 s，join 80 敌，探针构建；baseline=`b-perfdiag-run-08`）**：

| 指标 | baseline | J11 诊断 | 变化 |
|---|---:|---:|---:|
| dt mean / p95 / max | 46.22 / 78 / 129 | **36.56 / 59 / 99** | mean −21%，max −23% |
| >100 ms 帧 | 15 | **0** | 本轮样本消失 |
| `client.decode` mean / max | 3.47 / 54 | **1.69 / 41** | mean −51% |
| decode >40 ms 帧 | 8 | **1** | 大幅减少 |

**边界**：探针构建、单轮样本；clone 计数仍有 632/288 等尖峰（可能来自 pose 或其他路径），不能宣称全部解码尖峰消除。clean ABAB（60 s×2×ABAB）与功能回归已完成，结果见下表；**已部署（2026-10-31），安装体与测试字节完全一致**。

**clean ABAB 第一轮（`b-j11-clean-01`，60 s×2 阶段，A=J11-03，B=smooth04；两轮/侧）**：

| 阶段 | J11-03 A 两轮 mean / p95 | baseline B 两轮 mean / p95 | 判断 |
|---|---|---|---|
| 80 敌加入侧 | **37.02/35.40 ms，61/56** | 40.24/39.70 ms，66/66 | mean 约 **−9.4%**、p95 约 **−9%**；A 两轮都低于 B |
| 80 敌主侧 | 58.78/60.69 ms，85/89 | 59.25/60.76 ms，86/90 | 基本持平（−0.4%，在噪声内） |
| 8 敌加入侧 | 33.39/33.38 ms，45/44 | 33.50/33.36 ms，44/46 | 持平 |
| 8 敌主侧 | 36.65/36.66 ms，55/56 | 37.01/38.27 ms，56/59 | 约 −2.6%，方向有利但幅度小 |

**clean ABAB 第二轮（`b-j11-clean-02`，同一门槛）**：

| 阶段 | J11-03 A 两轮 mean / p95 | baseline B 两轮 mean / p95 | 判断 |
|---|---|---|---|
| 80 敌加入侧 | **37.01/35.72 ms，60/59** | 44.65/40.26 ms，77/66 | J11 两轮均明显低于 baseline |
| 80 敌主侧 | 59.19/62.09 ms，87/91 | 69.24/61.36 ms，101/90 | 平均约 −7%；一轮 baseline 离群 |
| 8 敌加入侧 | 33.34/33.82 ms，45/45 | 34.94/33.33 ms，56/44 | 基本持平 |
| 8 敌主侧 | 36.02/37.17 ms，55/57 | 44.43/36.66 ms，75/56 | 平均约 −10%，一轮 baseline 离群 |

> 合并两轮：80 敌加入 mean **约 36.3 ms vs 基线 41.2 ms（−12%）**，P95 **约 59 vs 69（−14%）**；主侧密集平均约 −4%，未变差；轻负载加入持平、主侧略好。两轮 A 自重复 1.046/1.036，B 1.014/1.109，均在 1.2 内；同字节功能回归通过（security host 单失败与 baseline 相同）。**达到部署门槛，2026-10-31 部署 J11-03 字节。**

### 5.9 S1 字段裁剪（在 J11 之上，探索中的新切口）

按 `field-consumers.md` 的 S1 清单，对**非玩家 scene unit** 的 40 个“宿主 AI/物理/音效/脚本”字段在 `NativeFields.capture(...,crop=true)` 的 schema 中排除；玩家、对象、武器、房间字段保持完整。源 `build/ab/b-j11s1-source-01`，候选 `build/ab/b-j11s1-01`（`33ac70ea…ca8`）。

**功能（同字节，`prepared-smooth-07`）**：textmotion 104/117（0 failed）、enemies 50/50（0 failed）、rockets 50/50（0 failed）；terrainlive host 124/2（失败为 native 玩家 `work=die` 启动/生命周期超时，join 123/0，非字段裁剪直接断言）、loading/ui 未跑。计数与旧驱动不同，因 `prepared-smooth-07` 是新驱动/环境，不能与旧 111/124 等直接比数量。

**性能 ABAB（`b-j11s1-clean-01`，60 s×2，A=S1，B=J11；两轮/侧）**：

| 阶段 | S1 A | J11 B | 观察 |
|---|---|---|---|
| 80 敌主侧 | 64.82 / 65.67 ms，p95 95/97 | 75.41 / 71.63 ms，p95 112/105 | S1 平均约 **−11%**（两轮都低于 B，但 B 自身波动大） |
| 80 敌加入侧 | 38.41 / 38.65 ms，p95 63/64 | 47.09 / 39.26 ms，p95 84/66 | S1 更稳定；B 有一轮 47 ms 离群 |
| 8 敌主侧 | 39.29 / 45.48 ms | 42.84 / 44.92 ms | 混合，S1 略好 |
| 8 敌加入侧 | 33.39 / 36.19 ms | 33.67 / 34.44 ms | 混合，S1 一轮偏高 |

**判断**：S1 对**主侧密集采集**的收益方向在第一次 ABAB 中最明显（少 40 字段/单位，约 −18–20% 字段键数），但**第二次确认 `b-j11s1-confirm-02` 方向相反**：80 敌主侧 S1 **67.96/65.02 ms** vs J11 **61.70/60.52 ms**，加入 S1 39.56/37.50 vs J11 36.93/37.68；即 S1 并未稳定优于 J11。terrainlive host 的启动死亡失败仍需复跑排除夹具波动；S1 尚未完成 loading/ui 回归。**未达到稳定部署标准，不部署、不与 J11 合并晋升。**

**S1 vs 当前安装基线（`b-j11s1-total-01`，60 s×2，A=S1，B=smooth04）**：80 敌加入 S1 44.96/40.49 ms vs baseline 43.42/51.20（baseline 一轮 51.2、max 365，不可靠）；80 敌主侧 75.48/70.27 vs 65.23/81.16（平均基本持平）；8 敌两侧接近。**该轮环境波动大于候选差异，不能确认 S1 相对基线的独立收益。** 因此 S1 仅保留为探索切口，不作为晋升依据。

> 下一步值得试的第二组：S2 的“音效 + 名字/脚本 + 武器技能坐标”约 18 字段（`field-consumers.md` §5.2），以及 host 侧 `capture.tiles` 事件化；两者都需先加计数，避免盲裁。更可靠的做法是先在低负载时段重复 S1 ABAB（至少再两组），再决定是否保留裁剪。

---

### 5.10 J12 未变字段基础跳过（**已部署 2026-10-31**）

在 J11 稀疏 fields 之上，加入侧记录每个单位/物件/武器的 `appliedBase/appliedDelta`：若不可变 base 与上次相同则不再整份 `NativeFields.apply`，只应用新的 `fieldsDelta`；武器/对象/新视觉创建时重置。源 `build/ab/b-j12-source-01`，候选 `build/ab/b-j12-01`（`7c2cc412…47a`）。

**功能（同字节，`prepared-smooth-07`）**：textmotion 104/117、rockets 50/50、terrainlive 178/123、enemies 50/50、loading 68/62、ui 127/84，均 0 failed。

**性能**：

| 对照 | 轮次（join 80 mean） | 判断 |
|---|---|---|
| J12 vs J11（`b-j12-clean-01`） | 36.77/36.13 vs 42.49/39.58 | J12 两轮都低，约 −11% |
| J12 vs J11（`b-j12-clean-02`） | 40.29/34.86 vs 38.62/38.98 | 一轮高、一轮低；合并约 −3% |
| 两轮合并 | **37.0 vs 39.9** | 约 **−7% mean**；P95 60 vs 67（约 −11%） |
| J12 vs smooth04（`b-j12-total-01`） | **34.13/33.84 vs 39.79/39.18** | 约 **−14% mean、−18% P95**；主侧 63.2 vs 60.7（+4%，宿主代码未改，噪声内） |

**部署**：`build/ab/b-j12-deploy-20261031-01`；安装体 `7c2cc412…`，旧 J11 体 `6d540c20…` 在 `before/`；manual `a3a0c301…c7b0`、README `96ab5a7c…ad8e`、validation `477d379a…c1c5`；A 体/root/DLC witness 未变。

### 5.11 已评估但未晋升的切口

| 切口 | 试验 | 结果 | 处理 |
|---|---|---|---|
| S1 40 字段裁剪 | `b-j11s1-01`，功能 + 两组 ABAB | 两次 ABAB 方向相反；无稳定收益 | 不部署 |
| S2 18 字段组（音效/名字/武器技能坐标） | `b-s2-01`，textmotion；ABAB vs J12 | join 80 36.05/36.35 vs 35.70/35.41（约 +2%），无收益 | 不部署 |
| J13 姿态/血条记录跳过 | `b-j13-01`，textmotion；ABAB vs J12 | join 80 约 −2.5%，低于 5% 门槛且方向不稳 | 不晋升 |
| J14 隔帧瓦片扫描 | `b-j14-01`，terrainlive | `BTerrainBoundsChecks` 失败（隔帧跳过后该帧无 tile delta），join 同行停止 | 撤销 |
| J15 尸体采集缓存 | `b-j15-01`，enemies | join 13 项历史敌人视觉断言失败（冻结过早/记录复用） | 撤销 |
| J16 多确认限流 | `b-j16-01`，textmotion；ABAB vs J12 | join 80 约 +2.9%，长帧未改善 | 撤销 |
| J17 插值记录跳过 | `b-j17-01`，textmotion；ABAB vs J12 | join 80 35.99/36.05 vs 35.84/35.81，约 +0.5% | 撤销 |
| J18 动画帧缓存 | `b-j18-01`，enemies | join 1 项历史视觉断言失败（缓存 `blank`/帧状态不完整） | 撤销 |
| J19 多确认帧跳过插值 | `b-j19-01`，textmotion；enemies；ABAB vs J12 | join 80 mean 37.58/38.12 vs 38.29/37.89（约持平），>100ms 帧 1/3 vs 11/9 有尾部改善；但 enemies host 123/1 历史敌人断言失败 | 撤销，不部署 |
| 宿主死亡/瓦片优化 | 审计/实现尝试 | 无安全且可重复的宿主收益；`capture.tiles` 仍为固定成本 | 保留为后续设计 |

> 结论：**J11+J12 已部署并完成功能/ABAB 评估；其余推荐切口均已有回执和否定/边界结论。** 仍未完成真实 `random_mane` AI/爆炸/死亡/破墙与输入→显示端到端延迟；宿主密集帧仍以 publish/capture 为主，未找到可安全落地的第二刀。

### 5.12 本轮最终评估摘要

- **已部署**：J11（稀疏 fields）→ J12（未变 base 跳过）。安装体 `7c2cc412…47a`，A 体/witness 未变；同字节功能 6 场景 0 failed。
- **总收益**（J12 vs smooth04，60 s ABAB）：80 敌加入 **34.13/33.84 vs 39.79/39.18 ms（约 −14% mean）**，P95 **54 vs 65.5（约 −18%）**；主侧 63.2 vs 60.7（+4%，宿主代码未改，噪声内）；8 敌/轻负载持平。
- **加入侧增量**（J12 vs J11，两轮）：合并约 −7% mean、−11% P95；两轮方向一致（一轮较弱）。
- **已否定**：S1 字段裁剪、J13 姿态/血条跳过、J14 隔帧瓦片、J15 尸体缓存、J16 多确认限流、J17 插值跳过、J18 动画帧缓存。失败/低收益回执均保留，不纳入正式包。
- **未闭合**：真实战斗（random_mane AI/爆炸/死亡/破墙）与输入→显示端到端延迟仍无完整夹具；已做两类近似验证：
  - **真实敌人场景**：`enemies`（原生敌人 AI/武器/伤害/视觉断言）J12 同字节 50/50 通过。J12 vs J11 同驱动分项均值（非 ABAB，单轮）：host publish 13.41 vs 13.49、host.sceneAndPlayers 9.83 vs 9.88；join present 9.48 vs 9.86、render 4.00 vs 4.27、replica.units 1.34 vs 1.47、decode 0.74 vs 0.69。方向总体有利但不作性能结论。
  - **控制→可见状态墙钟延迟**：外部 `BUiCases` 增加 `wallAt`/`wallLatencyMs`，J12 两轮 lock/hack 为 372/371 与 160/167 ms；J11 对照 290/322 与 190/165 ms。混合方向、不同随机地图，**不能用于宣称 J12 降低或提高端到端延迟**；仅证明链路可观测、未出现异常停顿。
  - **输入→join 可见弹丸**：外部 `BGrabCases` 在 host 注入 `keyGrenad` 时记录墙钟，join 首次在确认帧看到该弹丸时记录；J12 `360/450/323 ms`（3 个阶段样本），J11 `348/295 ms`（2 个）。这是更接近端到端的代理，但样本少、地图不同，方向不足以判定 J12 改善；只能说明链路完整且没有异常停顿。
  - 完整输入按下→屏幕变化仍需专门夹具；这是“卡顿已解决”不能成立的主要证据缺口。宿主端 publish/capture（尤其 tile 全房扫描与 fields/pose 采集）仍是下一阶段设计目标。

### 5.13 P1/P3 + P0 渲染地形缓存（**当前安装，2026-11-01**）

- **P1/P3 小幅优化**：组合候选 `b-p13-01` `014a7ad8…328`（J12 + 稳定尸体跳过 + 未变姿态/血条/动画跳过）同字节通过 textmotion 104/117、rockets 50/50、terrainlive 178/123、enemies 50/50、loading 68/62、ui 127/84；ABAB vs J12 join80 41.34/41.81 vs 42.43/40.90，噪声内不可分离，按用户指示部署。
- **P0 渲染地形缓存**：当前安装体 `b-p0-06` `a382e94f…8386`（source `ec5945be…58d7`）。`TerrainBitmapCache` 最多保留 2 个房间的 `visFront/visBack/visBack2/visVoda/visSats` 渲染面、轮廓和边框变换；背景用 `VisualPose.recipeEqual` 结构比较；换房先恢复缓存，未命中才 `drawLoc`；只有换房写缓存，同房地形重绘不承担克隆。
- **P0 功能**：textmotion 104/117、rockets 50/50、terrainlive 178/123、enemies 50/50、loading 68/62、ui 127/84、boundary 61/52 全部 0 failed。
- **P0 收益**：重复房间恢复 **8–13ms**，未命中 `drawLoc` **143–538ms**，首次克隆 **6–141ms**；同房重绘不写缓存。两轮 P0 vs P13 60s ABAB 合并 join80 mean **42.59 vs 43.04ms（约−2.9%）**、P95 **70.25 vs 74.5ms（约−5.7%）**；主侧与轻负载在噪声内。P0 的定位是房间重访峰值优化，不是密集战斗平均帧率的大幅提升。
- **P0 内存**：loading 配对采样 join 稳定私有内存 **1341MB vs P13 1306MB（约+35MB）**，峰值 1447 vs1482MB；两房间渲染面理论上限约76MB。
- **部署**：事务 `b-p0-deploy-20261101-01`；旧 P13 体备份，A 体/root/DLC witness 未变。security host 原生阶段失败仍与 baseline 相同；版本串仍 `B3-0.1-smooth1`，两实例需重启加载。

### 6. 验证计划（每阶段同一套门槛）

1. **功能回归**（每项改动都要，不以“无异常”代替）：
   - textmotion-02（主 111/加 124）、ui-02（134/91）、rockets-02（57/57，2030 显示样本）、enemies（原生断言）、terrainlive（主 130/加 75）、security-01、loading-01。
   - 显示树/血条/特效改动额外：层级顺序、像素对照、compact/full 命中计数、`addChild`/跳过次数。
2. **性能 ABAB**：沿用 b-smooth-clean-05 的 8/80 敌人 ×60 s、持续 LMG、同环境 11 模组；原 5% 平均/P95 与重复 1.2 门槛不降；新增长帧直方图（>50/100/200 ms 次数）、播放等待/欠帧、`present`/`publish` 分项。
3. **真实战斗**：`random_mane` 真实 AI/爆炸/死亡/破墙，至少 60 s；单独报告，不与合成场景混算。
4. **端到端延迟**：外部事件时间戳（输入按下→主侧执行→加入侧屏幕变化），至少覆盖移动/开火/换弹/跳跃。
5. **同字节部署门禁**：只有与测试完全相同的 SWF 字节才部署；部署前备份、回读、回滚指纹。**本轮 J11-03 与 J12-01 已按此部署；S1/J13/J14/J15/J16 未达标准，未部署。**
6. **回退**：每阶段独立提交/构建；保留旧构建与回执；性能或功能任一门禁失败即回退，不把“局部改善”写成全局结论。

**建议执行顺序**：Stage 0（M1–M3 先做，1–2 天）→ Stage 1（H1–H3、J1–J3，2–4 天）→ 复测与决策 → Stage 2（按 M2 数据选 2–3 项，不一次全上）→ Stage 3 讨论。

---

## 7. 不要宣称 / 未验证

- **不能宣称**“加入侧 Stage 帧率显著差于主侧”：现有四轮 ABAB 方向相反（主侧更慢）。
- **不能宣称**“卡顿已解决”或“所有场景流畅”：smooth04 仅密集加入 −5.4%、主侧不可分离；292 ms、162–168 ms、1–2 px 回摆仍在。
- **未测**：真实战斗（AI 移动/爆炸/死亡/破墙）的逐帧归因；端到端输入→显示延迟；GC/堆停顿；不同机器/分机；后台窗口焦点对 AIR 的量化影响；本机公网/多人。
- **环境说明**：早期 AIR 私有桌面启动失败（`0xC0000142`）已恢复；本轮 Stage 0/功能/ABAB 均取得实际运行数据。仍需注意测试槽位排队与探针开销，不能把不同构建/窗口环境的单轮数字混算。
- **旧 dense 数据**来自不同原生 SWF/构建，只能作量级参考。

---

## 8. 产物与复现

### 8.1 本轮新增（J11/J12 已部署；其余为调查/诊断/未部署候选）

- 主报告：本文件。
- 只读审计：`experimental/b-perf-investigation-20261029/{join-audit.md,host-audit.md,a-inventory.md,evidence-table.md}`。
- 证据提取脚本：`experimental/b-perf-investigation-20261029/extract_{timings,intervals,stress}.py`（只读既有 result/日志）。
- 逐帧归因诊断构建（诊断用、**不可部署**）：
  - 源：`build/ab/b-perfdiag-source-01`（smooth04 源 + `FrameStats.as`、`Timing.samples` 公开、`ClientReplica.lastReady`、`RConnectMod` 逐帧调用；仅诊断）。
  - 构建：`build/ab/b-perfdiag-01`（SWF `24c6f5c2…ba75`，`build-input.json` 绑定源）。
  - 运行脚本：`experimental/b-perf-investigation-20261029/bench_frame_env.py`（`bench-environment` 的诊断副本，`probe=false, frameProfile=true`）。
  - 失败回执：`build/ab/b-perfdiag-run-02`（AIR 未启动/超时）、`build/ab/b-perfdiag-run-03`（私有桌面 `0xC0000142`）、`build/ab/b-perfdiag-airprobe-01`/`-default-01`（启动探针）、`build/ab/b-perfdiag-run-05`（排队未启动）。
  - 成功逐帧数据：`build/ab/b-perfdiag-run-06`（30 s）与 `build/ab/b-perfdiag-run-07`（60 s，包/AMF3/FrameDelta 统计）；分析脚本 `analyze_frame_profile_v2.py`。
- J11 稀疏字段候选（**已部署**）：
  - 源 `build/ab/b-j11-source-01`；安装体 `build/ab/b-j11-03/RConnectMod.swf`（`6d540c20…f842`）。
  - **部署事务：`build/ab/b-j11-deploy-20261031-01/{deployment.json,before/,release-executed.py}`；安装目标 `build/ab/b3-playable-190/game/mods/RConnect/release/RConnectMod.swf`，回读一致；旧体 `c3118075…` 在 `before/`，A 体未动。安装后 manual `2bdf07f9…cd667`、README `a55ff531…9f312`、validation `d99fcd1c…a547`；README/validation 已标注 J11。**
  - 诊断构建 `build/ab/b-j11-diag-01` 与数据 `build/ab/b-j11-diag-run-01`（对照 `b-perfdiag-run-08`）。
  - clean ABAB `build/ab/b-j11-clean-01`、`b-j11-clean-02`（60 s×2×ABAB，两轮合并约 −12% 加入 mean）。
  - 同字节功能回执：`b-j11-test-{textmotion-03,rockets-02,terrainlive-02,enemies-02,loading-01,ui-04}`、`b-j11-control-{enemies-01,security-01,ui-03}`；security 同 baseline 失败保留。
  - 外部驱动修正：`tools/host_authority/field2_driver/BUiCases.as` 读取稀疏有效字段，重建 `prepared-smooth-07.json`。
- J12 未变字段跳过（**已部署 2026-10-31，覆盖 J11 安装体**）：
  - 源 `build/ab/b-j12-source-01`；安装体 `build/ab/b-j12-01/RConnectMod.swf`（`7c2cc412…47a`）。
  - 部署事务 `build/ab/b-j12-deploy-20261031-01/{deployment.json,before/,release-executed.py,update-docs.py}`；旧 J11 体在 `before/`；安装后 manual `a3a0c301…c7b0`、README `96ab5a7c…ad8e`、validation `477d379a…c1c5`。
  - ABAB `b-j12-clean-01`、`b-j12-clean-02`（vs J11）、`b-j12-total-01`（vs smooth04）。
  - 同字节功能回执：`b-j12-test-{textmotion-01,rockets-01,terrainlive-01,enemies-01,loading-01,ui-01}`。
- 已评估未晋升：J13 `b-j13-01`（约−2.5%，不晋升）、J14 `b-j14-01`（terrain 组件失败）、J15 `b-j15-01`（enemies join 13 失败）、J16 `b-j16-01`（join80 +2.9%）、J17 `b-j17-01`（join80 +0.5%）、J18 `b-j18-01`（enemies join 1 视觉失败）、J19 `b-j19-01`（尾部较好但 enemies host 123/1 失败）、S2 `b-s2-01`（18 字段组 join80 +2%）；`b-s2-test-textmotion-01`、`b-s2-clean-01`。
- 真实敌人/延迟近似：`b-j11-enemies-perf-01`、`b-j12-enemies-perf-01`（enemy-timings）；`b-j11-latency-ui-01/02`、`b-j12-latency-ui-01/02`（`prepared-smooth-08` 驱动 `wallLatencyMs`）；`b-j11-e2e-controls-01`、`b-j12-e2e-controls-01`（`prepared-smooth-09` 驱动 host 输入→join 可见弹丸墙钟）。
- S1 字段裁剪探索（J11 之上，**未部署**）：源 `build/ab/b-j11s1-source-01`，候选 `build/ab/b-j11s1-01`（`33ac70ea…ca8`）；ABAB `build/ab/b-j11s1-clean-01`（S1 方向偏好）、`b-j11s1-confirm-02`（J11 方向偏好）、`b-j11s1-total-01`（vs baseline，噪声大）。功能回执 `b-j11s1-test-{textmotion-01,enemies-01,rockets-01,terrainlive-01}`。**两次确认方向相反，未达稳定部署标准。**
- Stage 1 候选（**未部署**）：
  - v1 `build/ab/b-stage1-01`（`796ec224…c070`，含已失败的 J2）与回执 `build/ab/b-stage1-test-textmotion-01`（join FATAL，保留失败）。
  - v2 `build/ab/b-stage1-02`（`77d4f837…f9a1`，当前可复验候选）与源 `build/ab/b-stage1-source-01`。
  - 功能回执：`build/ab/b-stage1-test-textmotion-02`（111/124）、`b-stage1-test-ui-01`（134/91）、`b-stage1-test-rockets-01`（57/57），均 runtime unchanged。
  - 性能：`build/ab/b-stage1-clean-01`（30 s ×2 × ABAB）；无可分离稳定收益，不晋升。
- 既有证据：`build/ab/b-smooth-profile-03/*`、`b-smooth-clean-05/*`、`b-dense-profile01`、`experimental/b-field-dense-profile/profile01-analysis.json`、`b-smooth-textmotion-02`、`b-smooth-rockets-02`。

### 8.2 复现命令（下一轮可直接用）

```powershell
# 1) 逐帧归因（需要 AIR 可启动的会话；私有桌面默认）
python experimental/b-perf-investigation-20261029/bench_frame_env.py --check `
  --preparation prepared-environment-002.json --candidate build/ab/b-perfdiag-01 `
  --result build/ab/b-perfdiag-run-04 --profile --diagnostic
python experimental/b-perf-investigation-20261029/bench_frame_env.py --run `
  --preparation prepared-environment-002.json --candidate build/ab/b-perfdiag-01 `
  --result build/ab/b-perfdiag-run-04 --profile --diagnostic

# 2) 分析 RConnect-B.log 的 frame-profile 片段（字段顺序见 FrameStats.as）
# 3) 对每个候选仍用 b-smooth-clean-05 的 ABAB 门槛，不新造门槛。
```

> 注：诊断早期的 AIR 启动失败已恢复，相关失败回执保留用于环境记录；后续诊断/ABAB 均已取得实际运行数据，不能把旧环境失败当成当前构建结论。

---

## 9. 建议用户拍板的点

1. **J11+J12 已部署（2026-10-31）**：J12 相对 J11 的加入 80 敌两轮合并约 **−7% mean、−11% P95**；相对 smooth04 基线约 **−14% mean、−18% P95**；主侧在噪声内、轻负载持平。同字节功能回归通过。版本串仍是 `B3-0.1-smooth1`（未 bump），安装字节 `7c2cc412…` 与测试字节一致。后续 bump 版本需重新编译并重跑功能冒烟 + ABAB 同字节证据。
2. **其余切口已有结论**：S1/J13 未达到稳定收益；J14/J15 有功能失败；J16 反而变慢。下一步若继续，优先真实战斗验证，而不是再叠加微优化。
3. **Stage 2 的取舍**：离屏/远处单位采集降频、特效保真度分级涉及“远端看到什么”的体验边界，需要你确认可接受的显示延迟/降级范围；代码侧在此之前只做不影响语义的低风险项。
4. **真实战斗/端到端延迟**：本轮仍以合成 80 敌与功能场景为主，`random_mane` 真实 AI/爆炸/死亡/破墙与输入→显示延迟尚未完成；这是当前最大证据缺口，不能宣称“卡顿已解决”。
