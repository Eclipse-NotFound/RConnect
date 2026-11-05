# RConnect B 版性能证据表（只读挖掘）

- 时间：2026-10-29（Asia/Shanghai）
- 范围：本轮之前已存在的性能测试产物；**未运行游戏、未构建、未修改任何被分析文件**。
- 唯一写入：本文件 `mods/RConnect/experimental/b-perf-investigation-20261029/evidence-table.md`。
- 目的：为“加入侧相对主侧严重卡顿、战斗两侧都卡”的根因判断提供可核对数字；**不把不同构建、不同条件、不同仪器的数据混算**。
- 口径总则：表 A 的“帧均”= 该阶段每 Stage 帧均摊毫秒（`meanMs × n / frames`）；表 B 的均值/P95 来自 `intervals` 数组或资格文件；所有“插桩”数值都含仪器自身开销（见 §5）。

## 0. 结论速览（先给硬结论）

1. **“加入侧相对主侧严重卡顿”在 Stage 帧间隔上不成立。** 同一轮 ABAB 中，80 敌人时主侧均值 63.70–75.52 ms，加入侧 41.48–47.63 ms；主侧 >100 ms 长帧 11–50 次/60 s（或 19–45 次/30 s），加入侧仅 1–13 次（或 3–9 次）。四个 run、两个构建系列方向一致。
2. **“战斗两侧都卡”成立。** 8→80 敌人：主侧均值 +58.7%～+90.9%，加入侧 +24.0%～+38.7%；两侧 P95 与 >100 ms 长帧都上升。加入侧自身确实退化，只是没有主侧那么严重。
3. **分项归因（单轮插桩，80 敌人）：** 主侧 `publish` 32.21–34.24 ms/帧（其中采集 21.00–22.98，字段 8.53–9.27，身体姿态 9.88–12.06，动画约 1.01–1.14，瓦片 3.31–3.51）；`simulate` 16.05–16.91。加入侧 `present` 17.44–18.80、`decode` 5.68–6.08 ms/条（3.33–3.90/帧）、replica 应用 5.85–6.73/帧。血条在 smooth 构建未单独插桩。
4. **干净 60 s ABAB（smooth04 对 baseline）：** 密集加入 44.321→41.921 ms（−5.4%）、P95 71→67.5；密集主侧 66.580→65.579 ms（−1.5%，两轮区间重叠，**不可分离**）；轻负载主侧 40.103→40.701 ms（慢 1.5%，仍在 5% 门槛内）、加入 33.503→33.417 ms。
5. **不能证明：** 加入侧稳态帧率差于主侧；292/389 ms 级长帧属于战斗稳态；输入到显示延迟；任何“严重卡顿已修复”的结论。现有证据只能支持“减少已测 Stage 开销约 5%”，见 §6。

## 1. 证据索引与构建身份

### 1.1 来源标签（后文表格统一引用）

| 标签 | 文件/目录 | 条件与说明 |
|---|---|---|
| A1 | `mods/RConnect/build/ab/b-smooth-profile-03/01-A/result.json` | A=baseline `c953c0…`，30 s，8/80 敌人，`profile=true` |
| B1 | `mods/RConnect/build/ab/b-smooth-profile-03/02-B/result.json` | B=smooth01 `7e347d…`，30 s，8/80，`profile=true` |
| A2 | `mods/RConnect/build/ab/b-smooth-profile-03/03-A/result.json` | 同 A1（第二个 A 轮） |
| B2 | `mods/RConnect/build/ab/b-smooth-profile-03/04-B/result.json` | 同 B1（第二个 B 轮） |
| C1–C4 | `mods/RConnect/build/ab/b-smooth-clean-05/{01-A,02-B,03-A,04-B}/result.json` | A=baseline `c953c0…`；B=smooth04 `c31180…`；60 s，8/80，`profile=false` |
| Q | `mods/RConnect/build/ab/b-smooth-clean-05/qualification-01.json` | clean-05 的 2×ABAB 汇总、重复门槛、播放缓冲 |
| S03 | `mods/RConnect/build/ab/b-smooth-profile-03/series.json` | profile-03 构建/工具/顺序/环境哈希 |
| S05 | `mods/RConnect/build/ab/b-smooth-clean-05/series.json` | clean-05 构建/顺序/环境哈希 |
| D0 | `mods/RConnect/build/ab/b-dense-profile01/result.json` | **旧构建** `1a38b7…`（b190-field22 基线），45 s，诊断插桩，原生 SWF `eced04…` |
| D1 | `mods/RConnect/experimental/b-field-dense-profile/profile01-analysis.json` | 对 D0 的分项汇总（每帧合计，非每单位） |
| T-h / T-j | `mods/RConnect/build/ab/b-smooth-textmotion-02/host-text-motion-final.json` / `join-text-motion-final.json` | smooth04，textmotion 功能场景，分阶段窗口 |
| T-s | `mods/RConnect/build/ab/b-smooth-textmotion-02/join-text-motion-stationary.json` | 加入侧静止阶段单次采样 |
| R | `mods/RConnect/build/ab/b-smooth-rockets-02/join-clock-trace.json` | smooth04，rockets 功能场景，35.25 s，逐帧到达/屏幕/确认 |
| M1–M4 | `b-smooth-profile-03/{01-A,02-B,03-A,04-B}/machine.json` | 机器负载（free/commit），1 s 采样 |
| M5–M8 | `b-smooth-clean-05/{01-A,02-B,03-A,04-B}/machine.json` | 同上 |
| W | `mods/RConnect/experimental/b-smooth-20261029/README.md` | 本轮设计/失败/部署说明（二手汇总，尽量回引原始文件） |
| P1/P2 | `C:\Users\hello\AppData\Roaming\pfe-modsettings-rconnect-b-player-{1,2}\Local Store\{RConnect-B.log, frame-recorder\frames-v1.jsonl}` | **旁证**：同一 session `684cab38a22444cbbf0685884b6862f6` 的真实窗口记录；不是受控 AB |

### 1.2 构建身份（防止把不同构建当成同一“B 版”）

| 构建 | 版本 | SWF SHA-256 | 源 ID | 出现于 |
|---|---|---|---|---|
| baseline | B3-0.1-clientenv1 | `c953c0684ca716b2641c88f13e514275d5f2cc8e3387d9ade50d7ab8bd1fc5a0` | `5854ef397c1e96cf24d8b637f32cdc24589502d91fe86cce892a3189b75041dd` | profile-03 A1/A2；clean-05 C1/C3 |
| smooth01 | B3-0.1-clientenv1（boot 记录；系列内称 smooth01） | `7e347ddc237746cc3c9833952386b54aeca6b9914b940a98e760f58a7bc7432d` | `ce68d48a6153df26de1ba7aef10238e590c445b26921eb5af31dfd5a74b7bef` | profile-03 B1/B2 |
| smooth03 | B3-0.1-smooth1 | `bb18ef1b187a38a3b84dbce3f3ac16f67d18ff5a07f8ea278c142bc978b6e9a3` | `a8efbb697f611d07e9578ebc92961dc69d4a5b18dbc0c79ca3b51916ebc096ec` | clean-04（**未用于本表**） |
| smooth04 | B3-0.1-smooth1 | `c3118075c414887aea770d7df36b349e52fe330a441571218fa969c25bff44fa` | `e2be0722726c5d489f76419a194ea86274b61362c0836707a2ab7d1570a1cf15` | clean-05 B1/B2；textmotion/ui/rockets；部署版 |
| dense 诊断 | 非 smooth | `1a38b74b81c23a634daf3e5ee15cce59c92f2ed920eeaf47db886852356523c8` | 未登记为候选 | D0/D1 |

> 构建来源：S03、S05、Q 的 `choices/baseline/candidate`；部署版见 `b-smooth-deploy-20261029-01/deployment.json` 的 `build`（status=verified，4 个目标替换）。
> **原生命令宿主也不同：** profile-03/clean-05/textmotion/rockets 的 `native_sha256` 均为 `3b1b77d3f6de08e5b31bb03883da6900b3656e497a4749305133019d0377ed83`；D0 的 `native_sha256` 为 `eced04ad8dae6b74444ee6e5f5ec5ddf2e83528a9eecfef66f58985cb0c83063`。D0/D1 不能与 smooth 系列混算。

### 1.3 统一环境（AB 系列）

- 默认组合：启用 11 个模组（ModLoader、Sandevistan、MSW、TDFC、RandomRooms、LootEditor、PermanentInjury、AddictionSystem、FirearmAttachments、WallBlend、ABBench）；关闭 ContinuousScene、LightAndDarkness、RealisticVision。见 A1–A2/B1–B2/C1–C4 的 `enabled`/`disabled`。
- 场景：`loc0_0`，`land=rbl`，舞台 984×611，世界 1920×1000，`rate=30`（A1/B1 的 `host/ABBench.log` `kind=ready`）。
- 两实例同机、私有桌面；同房间内 **2 名玩家共存**（各 run 的 `samples[].players` 长度=2）。
- 敌人数量：phase 0 = 8，phase 1 = 80（`expectedEnemies`；`enemies.attached/visible/count` 一致）。
- 环境哈希：`environment_sha256=301cf50a…`；`preparation_sha256=bff12e70…`（S03/S05/Q）。

## 2. 表 A：分项耗时

### 2.1 主侧（A1/B1/A2/B2；30 s；插桩；单位 ms）

格式：**8 敌人 = 帧均**；**80 敌人 = 帧均 [单帧 P95/单帧 max]**。顺序统一为 A1 / B1 / A2 / B2。
`n/帧` 表示该计时器每 Stage 帧平均记录次数；`p95=0` 的 per-call 计时器是 1 ms 整数粒度导致，不代表零成本。

| 指标（字段） | 8 敌人 | 80 敌人 | 包含/重叠关系与口径 | 来源 |
|---|---|---|---|---|
| publish（`host.publish`） | 11.83 / 14.94 / 13.74 / 14.03 | 32.21 [52/84] / 34.24 [54/83] / 33.18 [54/79] / 33.73 [53/86] | ⊃ sceneAndPlayers + character + delta + send；也 ⊃ 采集（下） | A1/B1/A2/B2 `roles.host.results[].timings` |
| simulate（`host.simulate`） | 9.03 / 11.85 / 10.35 / 11.04 | 16.05 [23/64] / 16.79 [24/62] / 16.91 [25/41] / 16.65 [24/35] | 与 publish 并列；其分段 players/room 合计可大于外层，勿相加 | 同上 |
| simulate.players | 5.94 / 6.66 / 6.78 / 6.77 | 6.11 / 6.06 / 6.35 / 6.14 | `host.simulate` 内分段 | 同上 |
| simulate.room | 8.09 / 10.85 / 9.39 / 10.03 | 13.57 / 14.22 / 14.36 / 14.27 | `host.simulate` 内分段 | 同上 |
| sceneAndPlayers（`host.sceneAndPlayers`） | 8.63 / 10.95 / 9.94 / 10.45 | 24.68 / 27.16 / 25.26 / 27.00 | ⊃ `scene.capture`（即下项） | 同上 |
| **采集合计**（unitsAndTiles+objects+untracked） | **5.47 / 7.21 / 6.38 / 6.71** | **21.00 / 22.98 / 21.72 / 22.79** | ⊂ sceneAndPlayers；三项相加 | 同上，三项 `meanMs×n/frames` |
| 其中 units（`capture.units`） | 1.75 / 2.02 / 1.93 / 1.95 | 16.78 / 18.47 / 17.25 / 18.34 | ⊂ unitsAndTiles | 同上 |
| 其中 tiles（`capture.tiles`） | 3.12 / 3.41 / 3.48 / 3.45 | 3.31 / 3.51 / 3.45 / 3.39 | ⊂ unitsAndTiles | 同上 |
| 字段（`capture.nativeFields`） | 1.22 / 1.39 / 1.34 / 1.27 | 8.61 / 8.62 / 8.53 / 9.27 | 每帧合计；34 次/帧（8）/ 178 次/帧（80） | 同上 |
| 身体姿态（`capture.pose`，VisualPose.capture） | 3.82 / 5.70 / 4.52 / 5.23 | 9.88 / 12.06 / 10.37 / 11.18 | 每帧合计；61–90 次/帧（8）/ 199–201 次/帧（80） | 同上 |
| 动画（`capture.blitFrame`，AuthorityAnimation.capture） | 0.10 / 0.10 / 0.10 / 0.10 | 1.01 / 1.14 / 1.03 / 1.03 | 每帧合计；8 次/帧（8）/ 80 次/帧（80，每敌 1 次） | 同上 |
| **血条** | **未插桩（缺口）** | **未插桩（缺口）** | smooth 构建没有 `capture.unit.bar`；不能用旧 D1 的数字代替 | — |
| send（`host.send`） | 0.94 / 1.54 / 1.24 / 1.25 | 2.94 / 2.91 / 3.03 / 2.45 | ⊂ publish | A1/B1/A2/B2 |
| wire.serialize | 0.50 / 0.91 / 0.72 / 0.64 | 1.57 / 1.61 / 1.66 / 1.24 | 编码分段；非 publish 外的独立成本 | 同上 |
| wire.compress | 0.32 / 0.50 / 0.36 / 0.45 | 1.19 / 1.10 / 1.21 / 0.98 | 同上 | 同上 |
| native.scope（重叠计量） | 17.28 / 22.10 / 19.87 / 20.84 | 29.12 / 30.73 / 30.87 / 30.33 | **跨 simulate/capture 的重叠外框**，绝不能与上面相加 | 同上 |

补充：publish 的单帧 max 在 80 敌人为 79–86 ms，与主侧 max 帧间隔 120–146 ms 同量级；simulate max 35–64 ms。

### 2.2 加入侧（A1/B1/A2/B2；30 s；插桩；单位 ms）

格式同上。`decode` 是**每条网络帧**的均值/P95/max，另给每 Stage 帧合计；其余为每 Stage 帧合计。

| 指标（字段） | 8 敌人 | 80 敌人 | 包含/重叠关系与口径 | 来源 |
|---|---|---|---|---|
| display（`client.present`） | 7.71 / 8.14 / 8.84 / 8.56 | 18.01 [31/65] / 17.44 [32/76] / 18.80 [33/66] / 18.69 [32/73] | 每 Stage 帧一次；⊃ render | A1/B1/A2/B2 `roles.join.results[].timings` |
| render 合计（`client.render`） | 6.59 / 6.77 / 7.23 / 7.00 | 13.39 / 12.52 / 14.00 / 13.99 | 每帧约 2 次（状态 + 补间） | 同上 |
| sceneAndMap | 1.51 / 1.99 / 1.90 / 1.91 | 8.60 / 7.79 / 8.83 / 8.73 | ⊂ render；⊃ replica 应用 | 同上 |
| players | 3.68 / 3.28 / 3.92 / 3.68 | 3.39 / 3.31 / 3.64 / 3.65 | ⊂ render | 同上 |
| tween | 1.06 / 1.29 / 1.53 / 1.48 | 4.31 / 4.63 / 4.48 / 4.40 | 补间 render 分段 | 同上 |
| **apply 合计**（replica.units+objects+terrain） | **1.28 / 1.64 / 1.57 / 1.54** | **6.91 / 6.20 / 7.10 / 7.11** | ⊂ sceneAndMap；三项相加 | 同上 |
| 其中 replica.units（单位应用） | 0.90 / 0.73 / 0.86 / 0.78 | 6.54 [13/48] / 5.85 [13/18] / 6.66 [14/19] / 6.73 [13/26] | 每帧合计（80 敌人=80 单位/帧） | 同上 |
| objectsAndEffects | 0.34 / 0.82 / 0.66 / 0.68 | 0.36 / 0.33 / 0.42 / 0.36 | 同上 | 同上 |
| terrain | 0.03 / 0.09 / 0.05 / 0.08 | 0.01 / 0.02 / 0.02 / 0.02 | 同上 | 同上 |
| decode（`client.decode`，每条） | 1.08 [2/42] / 1.30 [3/57] / 1.48 [3/47] / 1.13 [2/15] | 5.95 [15/61] / 5.68 [15/55] / 6.08 [15/62] / 5.77 [15/53] | 按网络帧；每 Stage 帧 0.74–0.90 条（8）/ 0.59–0.64 条（80） | 同上 |
| decode（每 Stage 帧合计） | 0.97 / 0.96 / 1.18 / 0.86 | 3.77 / 3.33 / 3.90 / 3.68 | `meanMs×n/frames` | 同上 |
| net.receiveBatch | 1.57 / 1.59 / 1.84 / 1.52 | 4.69 / 4.13 / 4.91 / 4.50 | 网络收包外框 | 同上 |
| applyCached（向量缓存命中路径） | 0.06 / 0.08 / 0.07 / 0.07 | 0.13 / 0.10 / 0.12 / 0.12 | 几乎全为 0，说明向量重绘未走大量命令路径 | 同上 |
| **字段（NativeFields.apply）** | **未插桩（缺口）** | **未插桩（缺口）** | smooth 构建无 `replica.unit.fields`；D1 的 5.56 ms/帧只能作旧构建参考 | — |

补充：present 单帧 max 在 80 敌人为 66–76 ms，decode max 53–62 ms，replica.units max 18–26 ms；加入侧 max 帧间隔 113–138 ms，量级与“decode+present 单次尖峰”一致，但**没有逐帧对应关系**，不能据此断言组合关系。

### 2.3 旧构建逐单位拆分（D0/D1；**不可与 2.1/2.2 混算**）

条件：`b-dense-profile01`，45 s，8/80 敌人，诊断补丁 `diagnostic.patch`；基础为 b190-field22（非 smooth），原生 SWF `eced04…`，构建 `1a38b7…`。单位：**每帧毫秒（该帧全部单位合计，不是每单位）**；`outer` 为 `capture.units` / `replica.units` 外层。

| 角色 | 敌人 | stage 均值 | outer | metadata | fields | body | blit/动画 | bar/血条 | weapons | residual |
|---|---|---|---|---|---|---|---|---|---|---|
| 主侧 | 8 | 62.69 | 2.47 | 0.0362 | 1.1031 | 0.8663 | 0.1866 | 0.1880 | 0.0139 | 0.0808 |
| 主侧 | 80 | 123.05 | 24.40 | 0.2568 | 11.5601 | 8.4180 | 1.6475 | 1.8661 | 0.1557 | 0.4918 |
| 加入侧 | 8 | 44.60 | 1.24 | — | 0.6123 | 0.2413 | 0.2008 | barNative 0.0516 / barPose 0.0391 | 0.0126 | 0.0628（construct 0.0237） |
| 加入侧 | 80 | 88.07 | 12.97 | — | 5.5601 | 3.0683 | 1.9945 | barNative 0.8525 / barPose 0.6421 | 0.0956 | 0.6393（construct 0.1175） |

读法：`stage` 是该阶段 `elapsed/frames`（平均帧间隔），不是分项之和；`outer`/parts 单位为“每帧全部单位合计”。D1 的字段名 `*_ms_per_capture` 容易误读为“每单位”，实际分母是 `capture.units` 调用数（每帧 1 次）＝**每帧合计**。该构建 stage 已达 62.69/123.05 ms，且诊断插桩在单位循环内增加 6 对 `Timing.start/end`/单位，绝对数不可用于 smooth 构建。

## 3. 表 B：帧间隔、长帧、播放等待、消息节拍

### 3.1 干净 60 s ABAB（C1–C4；主证据；`profile=false`）

格式：**均值 ms / P95 ms / max ms / >100 ms 次数**。均值与 P95 取自 Q 的重复值（最近秩）；max 与 >100 次数由 Cx 的 `intervals` 数组复算。

| 角色/负载 | C1（A） | C2（B1） | C3（A2） | C4（B2） |
|---|---|---|---|---|
| 主侧 8 敌人 | 40.12 / 62 / 101 / 1 | 41.26 / 65 / 106 / 1 | 40.09 / 65 / 134 / 2 | 40.14 / 63 / 119 / 1 |
| 主侧 80 敌人 | 69.45 / 102 / 127 / 50 | 67.44 / 96 / 145 / 28 | 63.70 / 91 / 126 / 11 | 63.72 / 93 / 120 / 26 |
| 加入侧 8 敌人 | 33.34 / 46 / 99 / 0 | 33.39 / 47 / 95 / 0 | 33.67 / 47 / 102 / 1 | 33.44 / 47 / 94 / 0 |
| 加入侧 80 敌人 | 45.79 / 75 / 131 / 13 | 42.37 / 68 / 113 / 2 | 42.85 / 67 / 110 / 3 | 41.48 / 67 / 106 / 1 |

来源：C1–C4 `roles.<role>.results[].intervals`（n=1496/865/1800/1311 等），Q `comparisons[].baseline/candidate.{mean_ms,p95_ms,mean_repeats_ms,p95_repeats_ms}`。
注意：C1/C3 是 baseline，C2/C4 是 smooth04；**密集主侧两轮 baseline 自身 69.45 vs 63.70（9.0% 差）**，所以 −1.5% 的“改善”不可分离；密集加入候选两轮 42.37/41.48 均低于 baseline 两轮 45.79/42.85，−5.4% 在重复内可分离。

### 3.2 插桩 30 s ABAB（A1/B1/A2/B2；仅同轮相对比较）

格式：均值 / P95 / max / >100 次数，全部由 `intervals` 复算（线性插值 P95）。

| 角色/负载 | A1 | B1 | A2 | B2 |
|---|---|---|---|---|
| 主侧 8 敌人 | 36.94 / 56.4 / 83 / 0 | 45.90 / 70.0 / 104 / 2 | 43.75 / 69.0 / 103 / 2 | 44.36 / 69.0 / 117 / 4 |
| 主侧 80 敌人 | 70.50 / 99.2 / 146 / 19 | 75.52 / 110.0 / 145 / 45 | 74.32 / 106.8 / 120 / 29 | 73.47 / 106.6 / 138 / 32 |
| 加入侧 8 敌人 | 33.34 / 43.0 / 93 / 0 | 33.90 / 48.0 / 104 / 1 | 34.74 / 55.8 / 104 / 2 | 33.90 / 52.0 / 97 / 0 |
| 加入侧 80 敌人 | 44.73 / 71.0 / 113 / 3 | 44.25 / 70.0 / 138 / 6 | 47.63 / 76.0 / 118 / 8 | 47.03 / 77.0 / 123 / 9 |

**环境漂移证据（M1–M4）：** free GiB 均值/最小 = A1 9.43/8.51 → B1 8.61/8.12 → A2 7.94/7.52 → B2 7.61/7.27。同一 A 构建、同一环境哈希，轻负载主侧 A1 36.94 ms vs A2 43.75 ms（+18.4%）；因此 30 s 插桩轮的 A/B 差异不能当构建优劣。clean-05 的 M5–M8 free GiB 均值 8.52–8.99，环境稳定得多。

### 3.3 播放缓冲等待与欠帧（Q；clean-05；单位 ms）

| 轮/角色/负载 | underflow 净增 | 播放目标等待均值 | P95 | max | 最大帧间隔 | 空缓冲采样 |
|---|---|---|---|---|---|---|
| C1 A / 8 | +5 | 95.47 | 115 | 120 | 99 | 0 |
| C1 A / 80 | 0 | 176.79 | 205 | 207 | 131 | 0 |
| C2 B / 8 | +6 | 98.01 | 117 | 117 | 95 | 0 |
| C2 B / 80 | +1 | 168.36 | 186 | 192 | 113 | 0 |
| C3 A / 8 | +5 | 96.78 | 118 | 122 | 102 | 0 |
| C3 A / 80 | 0 | 162.53 | 183 | 189 | 110 | 0 |
| C4 B / 8 | **+10** | 94.76 | 115 | 130 | 94 | **1** |
| C4 B / 80 | 0 | 161.85 | 175 | 177 | 106 | 0 |

来源：Q `inputs[].playback`（字段名：`underflow_increase`、`mean_target_delay_ms`、`p95_target_delay_ms`、`max_target_delay_ms`、`max_frame_interval_ms`、`empty_buffer_samples`）。
读法：这些是**播放时钟的目标延迟/等待**，不是输入到显示延迟；密集阶段等待约为轻负载的 1.7 倍，但欠帧净增反而不在密集阶段发生（主要发生在轻负载，C4 有 1 次空缓冲）。

### 3.4 消息节拍与同戳重复（R；smooth04；rockets；35.25 s 窗口）

| 项目 | 数值 | 来源字段 |
|---|---|---|
| 到达消息数 / 速率 | 737 条 / 20.91 条·s⁻¹ | R `rows[kind=arrival]`，`returnAt` 跨度 35 249 ms |
| tick 唯一性 | tick 1…737，**重复 0 条** | R `rows[kind=arrival].frame.tick` |
| 屏幕帧数 / 速率 | 968 屏 / 27.44 屏·s⁻¹ | R `rows[kind=screen]`，`at` 跨度 35 269 ms |
| 屏幕间隔 | 均值 36.47 / P95 50 / max 581 ms；>100 ms 12 次 | R `screen.at` 相邻差 |
| 每屏消息数 | 0 条 298 屏（30.8%）；1 条 642 屏（66.3%）；≥2 条 27 屏（max 9 条） | R `screen.framesAfter` 差分 |
| 屏后队列深度 | 均值 2.51 / max 6 / 队列=0 共 26 屏（2.7%） | R `screen.clockAfter.queued` |
| 欠帧演进 | 2 → 28（净 +26；footer 末值 29） | R `screen.clockAfter.underflows` / `footer.finalClock` |
| 播放目标延迟 | 65 → 250 ms（自适应上调） | R `screen.clockAfter.delay` 取值集合 |
| 单屏渲染耗时（`endAt-at`） | 均值 10.65 / P95 23 / max 389 ms；>16 ms 147 屏，>33 ms 18 屏 | R `screen.endAt - screen.at` |

**关键限制：** 12 次 >100 ms 屏幕间隔与 389/581/292 ms 尖峰集中在两个时间段：`t+16.4–18.4 s` 与 `t+26.1–27.9 s`，对应 4 个 rockets 阶段切换（功能驱动换阶段/截图），不是稳态战斗。剔除这些簇后，稳态屏幕间隔约 30–40 ms。R 的 footer 自己声明 `qualifiesNetworkArrivalTimes=false`、`observerMs=57`，到达时刻不是精确挂接。

AB 轮的消息速率另证：clean-05 主侧帧率（=发布速率，join `samples[].hostTick` 增速与主侧帧率一致）为 24.9 条/s（8 敌人）与 14.4 条/s（80 敌人）；加入侧渲染 30.0 帧/s（8）与 21.8 帧/s（80）。profile-03 A1 对应为 27.0/14.2 与 30.0/22.4（B1/B2 轻负载主侧仅 21.7–22.5 条/s，见 §3.2 环境漂移）。join 的 `hostTick` 在 750 ms 采样内**重复 0 次**，但 750 ms 采样无法发现同戳重复，唯一逐帧证据是 R。

### 3.5 textmotion 帧间隔（T-h/T-j；smooth04；功能场景）

| 阶段 | 主侧 均值/P95/max/>100 | 加入侧 均值/P95/max/>100 | 备注 |
|---|---|---|---|
| stationary | 33.4 / 41.0 / 134 / 1 | 36.2 / 41.7 / **292** / 2 | 加入侧 292 位于该阶段**第 1 个间隔**；另一次 142 在位置 80 |
| walk-left | 37.7 / 50.2 / 101 / 1 | 34.2 / 45.0 / 93 / 0 | 加入侧镜头反转 8 次，最大 2 px |
| walk-right | 40.6 / 48.6 / 150 / 1 | 39.0 / 61.1 / 104 / 1 | 加入侧镜头反转 10 次，最大 1 px |
| walk-left-attack | 42.1 / 78.2 / 109 / 1 | 35.6 / 49.2 / 103 / 2 | — |
| walk-right-attack | 41.5 / 70.8 / 108 / 1 | 34.8 / 51.6 / 92 / 0 | — |

来源：T-h/T-j `phases.*.renderIntervalsMs`、`renderIntervalSumMS`、`renderIntervalMaxMS`、`underflow`、`cameraReversals`；T-s 为同阶段另一采样（81 样本，max 292，underflow 8）。
**不要把 292 ms 当持续卡顿：** 去掉第 1 个间隔后，加入侧 stationary 最大 59 ms；README（W）也明确写“移动 292 ms 长帧位于静止阶段第一个间隔，后续步行最大 93/104 ms”。加入侧 underflow：stationary 10，walk-left 0，walk-right 3，两段攻击 3/0；主侧各阶段 0。

## 4. 表 C：密集/战斗 vs 轻负载

### 4.1 直接对比（clean-05；同构建同条件）

| 指标 | 轻负载 8 | 密集 80 | 变化 | 判定 |
|---|---|---|---|---|
| 主侧均值 C1（A） | 40.12 | 69.45 | +73.1% | 两侧都变差（支持） |
| 主侧均值 C3（A） | 40.09 | 63.70 | +58.9% | 同上 |
| 主侧均值 C2（B） | 41.26 | 67.44 | +63.5% | 同上 |
| 主侧均值 C4（B） | 40.14 | 63.72 | +58.7% | 同上 |
| 加入侧均值 C1（A） | 33.34 | 45.79 | +37.3% | 加入侧自身退化（支持） |
| 加入侧均值 C3（A） | 33.67 | 42.85 | +27.3% | 同上 |
| 加入侧均值 C2（B） | 33.39 | 42.37 | +26.9% | 同上 |
| 加入侧均值 C4（B） | 33.44 | 41.48 | +24.0% | 同上 |
| 主侧 P95 C1/C3 | 62 / 65 | 102 / 91 | +50%～+65% | 支持 |
| 加入侧 P95 C1/C3 | 46 / 47 | 75 / 67 | +43%～+63% | 支持 |
| 主侧 >100 ms C1/C3 | 1 / 2 | 50 / 11 | 大幅增加 | 支持 |
| 加入侧 >100 ms C1/C3 | 0 / 1 | 13 / 3 | 增加 | 支持 |
| **主 vs 加 均值差** | 6.4–7.9 ms | **20.9–25.1 ms** | 差距随负载扩大 | **“加入侧明显差于主侧”不支持** |

### 4.2 逐项判定

| 待判命题 | 现有证据 | 结论 |
|---|---|---|
| 战斗时两侧都卡 | 主/加均值、P95、>100 ms 均随 8→80 上升（C1–C4；A1–B2 同向） | **支持** |
| 加入侧自身在战斗退化 | 加入侧 +24.0%～+38.7%（均值），P95 46–47→67–77 | **支持** |
| 加入侧相对主侧严重卡顿 | 同轮加入侧均值始终低 6.4–25.1 ms，>100 ms 次数更少 | **现有证据不能支持** |
| 加入侧播放等待在战斗变差 | 目标等待 94.8–98.0→161.9–168.4 ms（候选），基线 95.5–96.8→162.5–176.8 ms | **支持“缓冲等待变长”**，但不是端到端延迟 |
| smooth04 明显改善 | 密集加入 −5.4% 均值 / −4.9% P95；主侧 −1.5%（区间重叠）；轻负载主侧 +1.5%；292 ms 长帧仍在 | **只能支持“已测 Stage 开销小幅下降”**；W 也写明“仍保留慢帧、播放等待”，不能宣称严重卡顿解决 |

## 5. 表 D：可能被误读的数字与逐条限制

| # | 看起来像 | 为什么不能这样读 | 正确用法 |
|---|---|---|---|
| D1 | “publish 32 ms / present 18 ms 就是纯逻辑成本” | profile-03 全阶段 `Timing.enabled=true`；每个 `Timing.end` 一次 `getTimer` 差值（1 ms 粒度）。主侧 298–1129 条记录/帧、加入侧 103–182 条/帧；80 敌人主侧仅单位循环就有 6 对/单位×80 | 只作同轮 A/B 相对比较；绝对值与 clean-05 的 `profile=false` 数值不可相减 |
| D2 | “把 publish + simulate + 采集 + present 相加得当帧预算” | 计时器大量嵌套：publish ⊃ sceneAndPlayers ⊃ 采集 ⊃ units；present ⊃ render ⊃ sceneAndMap ⊃ replica 应用；native.scope 17–31 ms/帧横跨 simulate/capture；simulate.players+room 可大于 host.simulate | 只读外层或明确标注“包含”；本表已给出层级，禁止列间求和 |
| D3 | “A1 36.94 ms 比 A2 43.75 ms 说明某构建更好” | 同一 A 构建、同一环境哈希，两个 A 轮差 18.4%；M1–M4 free RAM 9.43→7.61 GiB 单调下降，与 ABAB 顺序同步 | 30 s 插桩轮只能看同轮成对方向；结论以 clean-05 的 60 s 稳定环境为准 |
| D4 | “profile-03 的 B 和 clean-05 的 B 是同一候选” | profile-03 B=`7e347d…`（smooth01）；clean-05 B=`c31180…`（smooth04）；clean-04 B=`bb18ef…`（smooth03） | 每个数字必须带构建 SHA；本表 1.2 已列全 |
| D5 | “dense 诊断的分项可拿来补 smooth 的血条/字段” | D0 基础是 b190-field22（非 smooth），原生 SWF `eced04…` ≠ smooth 的 `3b1b77…`；45 s、诊断补丁、7 对计时/单位 | 只作“旧构建曾这么贵”的机制参考，不并入 2.1/2.2 |
| D6 | “D1 的 parts 是每单位成本” | `parts = totalMs / n(capture.units)`，而 `capture.units` 每帧只调 1 次；它是**每帧全部单位合计**，不是每单位 | 若要每单位，需再除以该帧单位数（8 或 80），本表未做 |
| D7 | “292 ms / 389 ms 长帧就是战斗卡顿” | 292 ms 是 textmotion 静止阶段第 1 个间隔；R 的 389/581/292 ms 簇在阶段切换（t+16.4–18.4 s、t+26.1–27.9 s）；去掉后稳态最大 59 ms / 屏间隔 30–40 ms | 作为“阶段边界/加载类尖峰”单列；不能用它证明稳态加入侧卡顿 |
| D8 | “播放等待 168 ms 就是输入到显示延迟” | Q 的 `scope` 原文：`Stage frame intervals in the same default environment. Not GPU output or input-to-display latency.`；播放目标延迟是时钟缓冲参数 | 只能说“缓冲目标/等待变长”，不能说端到端 168 ms |
| D9 | “主侧密集 −1.5% 证明 smooth04 优化了主侧” | C1/C3 两轮 baseline 自身 69.45 vs 63.70（9.0%）；候选 67.44/63.72 与 baseline 两轮完全重叠 | 需要更多重复或更长窗口；当前只能写“未观察到超过噪声的改善” |
| D10 | “>100 ms 长帧次数可直接跨轮比较” | profile-03 是 30 s、clean-05 是 60 s；textmotion/R 是功能场景短窗；机器负载不同 | 只比较同系列同窗口；本表已按系列分栏 |
| D11 | “duplicateRenders 606 说明产品重复渲染” | `tools/.../BTextMotionCases.as` 注释与实现：同一次 ENTER_FRAME 内多余 RENDER 回调被丢弃并计数，不是产品渲染重复 | 只能当观察器事件统计；不能当渲染 bug 或卡顿证据 |
| D12 | “frame-recorder 的 4706/5251 ms 是战斗卡顿” | P1/P2 窗口记录含暂停/加载/重连/角色切换（P2 300 窗中 298 窗 paused；dtMs 3883 的 stall 标 `paused=true`）；且 P1/P2 角色会切换 | 只作“真实会话存在超长窗口”的旁证；不可归因到加入侧战斗 |
| D13 | “Local Store\RConnect.log 能对上本轮” | 本轮实际日志文件名为 `RConnect-B.log`；result.json 记录的 per-run storage（`pfe-modsettings-rconnect-b-ab-host-…` 等）在 AppData 下**不存在**；只剩 10-24 起使用的 player-1/2 目录（本轮 11:05–11:11 更新） | 逐 run 原始日志以 run 目录内 `host/ABBench.log`、`join/ABBench.log` 为准；AppData 只作旁证 |
| D14 | “两个实例同机测得的主/加差异=网络差异” | 主/加同机、私有桌面，共享 CPU/磁盘；主侧 simulate+capture 与加入侧 display 争同一 CPU | 跨机复测前，只能描述“同机联机时的 Stage 表现” |
| D15 | “样本里有 2 名玩家，可当单人基准” | 每个 run 的 `players` 长度=2，主侧采集包含 peer 玩家，加入侧包含本地+peer | 所有数字都是**2 人共存**条件；不能外推单人 |

## 6. 结论：能证明 / 不能证明 / 还缺什么

### 6.1 现有证据只能证明

1. **主侧是 Stage 帧间隔的瓶颈侧。** 80 敌人四轮：主侧 63.70–75.52 ms（≈13.2–15.7 fps），加入侧 41.48–47.63 ms（≈21.0–24.1 fps）；主侧 >100 ms 11–50 次，加入侧 1–13 次。方向在 baseline 与 smooth01/smooth04 上都成立。
2. **密集战斗使两侧同时退化。** 8→80 敌人：主侧 +58.7%～+90.9%，加入侧 +24.0%～+38.7%；两侧 P95 与长帧都上升。支持“战斗两侧都卡”。
3. **主侧成本结构（80 敌人、单轮插桩）：** publish 32.21–34.24 ms/帧（内含采集 21.00–22.98；其中字段 8.53–9.27、身体姿态 9.88–12.06、动画 1.01–1.14、瓦片 3.31–3.51）；simulate 16.05–16.91；native.scope 29.12–30.87（重叠外框）。加入侧：present 17.44–18.80、decode 5.68–6.08/条（3.33–3.90/帧）、replica 应用 5.85–6.73/帧、sceneAndMap 7.79–8.83。
4. **smooth04 的已测收益有限且集中在密集加入侧：** clean-05 密集加入 44.321→41.921 ms（−5.4%），P95 71→67.5；且候选两轮均低于基线两轮，重复内可分离。轻负载主侧慢 1.5%（门槛内），加入侧基本不变；密集主侧 −1.5% 与噪声重叠。
5. **播放等待随密度上升，欠帧主要出现在轻负载；消息在本轮 trace 中无同戳重复：** 目标等待 95–98→162–168 ms（候选）；C4 轻负载欠帧 +10 且有 1 次空缓冲；R 中 737 条消息 tick 唯一、重复 0，屏幕间隔稳态 30–40 ms（阶段切换处 389/581 ms）。
6. **加入侧确有孤立长帧：** textmotion 静止 292 ms（阶段首间隔）与 142 ms（中段），主侧 134–150 ms；量级接近，不能据此说加入侧系统性更差。

### 6.2 现有证据不能证明

- 不能证明“加入侧相对主侧严重卡顿”是稳态帧率问题；相反，Stage 间隔显示加入侧更快。
- 不能证明任何具体子系统（decode/apply/display/字段）是加入侧 >100 ms 长帧的根因；只有单次 max 与总均值，没有逐帧归因。
- 不能证明 292/389/581 ms 尖峰属于战斗稳态；它们位于阶段切换/首间隔。
- 不能给出输入到显示延迟、GPU 出帧时间、网络 RTT 对卡顿的贡献。
- 不能证明 smooth04 已解决用户感知的“严重卡顿”；W 自身也写“仍保留慢帧、播放等待和镜头回摆”。
- 不能把 dense 诊断的血条/字段拆分外推到 smooth 构建（构建与原生 SWF 都不同）。

### 6.3 还缺的测量（按优先级）

1. **加入侧逐子系统 long-frame 归因：** 在 `present/render` 内对 decode、replica 应用（units/fields/objects）、players、tween、prune、present 各段做逐帧记录，输出“每个 >100 ms 帧的分解”，而不是阶段均值。
2. **消息突发长度分布 × 屏幕：** 在持续密集战斗（非 35 s 功能场景）记录每屏到达条数、队列深度、欠帧时刻，输出 0/1/2/3+ 分布与长帧的对应关系；本轮 R 只覆盖 rockets 功能段。
3. **每帧 apply 记录数分布：** 每帧应用的单位/字段/对象数（不是均值），以及它们与帧间隔的分位对应；当前只有“80 单位/帧”的标称值。
4. **端到端测量：** 输入事件→本地显示/远端显示的时戳链，至少区分“逻辑帧间隔”和“呈现延迟”；GPU/Stage 出帧时间另采。
5. **跨机复测：** 主/加分机运行，排除同机 CPU 争用；同时保留每轮 free/commit 与 CPU 占用。
6. **smooth 构建的血条/动画 per-unit 拆分：** 复用 dense 诊断的计时点，但必须在新构建上重编、重测，不能沿用 D1。
7. **更多重复：** 密集场景至少 3–4 轮/构建（当前 2 轮 baseline 自身差 9%，1.5% 级结论不可靠）；轻负载主侧需确认 +1.5% 是噪声还是回归。

## 7. 附录：核心 CSV（便于机器复核）

```csv
section,role,enemies,run,mean_ms,p95_ms,max_ms,gt100,n,frames,source
interval,host,8,A1,36.94,56.4,83,0,813,813,profile-03/01-A/result.json
interval,host,8,B1,45.90,70.0,104,2,654,654,profile-03/02-B/result.json
interval,host,8,A2,43.75,69.0,103,2,686,686,profile-03/03-A/result.json
interval,host,8,B2,44.36,69.0,117,4,677,677,profile-03/04-B/result.json
interval,host,80,A1,70.50,99.2,146,19,426,426,profile-03/01-A/result.json
interval,host,80,B1,75.52,110.0,145,45,398,398,profile-03/02-B/result.json
interval,host,80,A2,74.32,106.8,120,29,404,404,profile-03/03-A/result.json
interval,host,80,B2,73.47,106.6,138,32,409,409,profile-03/04-B/result.json
interval,join,8,A1,33.34,43.0,93,0,900,900,profile-03/01-A/result.json
interval,join,8,B1,33.90,48.0,104,1,885,885,profile-03/02-B/result.json
interval,join,8,A2,34.74,55.8,104,2,864,864,profile-03/03-A/result.json
interval,join,8,B2,33.90,52.0,97,0,885,885,profile-03/04-B/result.json
interval,join,80,A1,44.73,71.0,113,3,671,671,profile-03/01-A/result.json
interval,join,80,B1,44.25,70.0,138,6,678,678,profile-03/02-B/result.json
interval,join,80,A2,47.63,76.0,118,8,630,630,profile-03/03-A/result.json
interval,join,80,B2,47.03,77.0,123,9,640,640,profile-03/04-B/result.json
interval,host,8,C1,40.12,62,101,1,1496,1496,clean-05/01-A/result.json
interval,host,8,C2,41.26,65,106,1,1455,1455,clean-05/02-B/result.json
interval,host,8,C3,40.09,65,134,2,1497,1497,clean-05/03-A/result.json
interval,host,8,C4,40.14,63,119,1,1495,1495,clean-05/04-B/result.json
interval,host,80,C1,69.45,102,127,50,865,865,clean-05/01-A/result.json
interval,host,80,C2,67.44,96,145,28,890,890,clean-05/02-B/result.json
interval,host,80,C3,63.70,91,126,11,942,942,clean-05/03-A/result.json
interval,host,80,C4,63.72,93,120,26,942,942,clean-05/04-B/result.json
interval,join,8,C1,33.34,46,99,0,1800,1800,clean-05/01-A/result.json
interval,join,8,C2,33.39,47,95,0,1797,1797,clean-05/02-B/result.json
interval,join,8,C3,33.67,47,102,1,1782,1782,clean-05/03-A/result.json
interval,join,8,C4,33.44,47,94,0,1795,1795,clean-05/04-B/result.json
interval,join,80,C1,45.79,75,131,13,1311,1311,clean-05/01-A/result.json
interval,join,80,C2,42.37,68,113,2,1417,1417,clean-05/02-B/result.json
interval,join,80,C3,42.85,67,110,3,1401,1401,clean-05/03-A/result.json
interval,join,80,C4,41.48,67,106,1,1448,1448,clean-05/04-B/result.json
```

```csv
# 分项/播放：v1 = 每 Stage 帧均（decode 为每条消息均），v2/v3 = 单次 P95/max（fields/pose/anim 的 P95=0 是 1 ms 整数粒度），n = 调用数/消息数
section,role,enemies,run,metric,v1_ms,v2_ms,v3_ms,n,source
timing,host,80,A1,publish_per_frame,32.21,52,84,426,profile-03/01-A/result.json
timing,host,80,A1,simulate_per_frame,16.05,23,64,426,profile-03/01-A/result.json
timing,host,80,A1,capture_total_per_frame,21.00,,,426,profile-03/01-A/result.json
timing,host,80,A1,fields_per_frame,8.61,0,49,75828,profile-03/01-A/result.json
timing,host,80,A1,pose_per_frame,9.88,0,43,84541,profile-03/01-A/result.json
timing,host,80,A1,anim_per_frame,1.01,0,2,34080,profile-03/01-A/result.json
timing,join,80,A1,present_per_frame,18.01,31,65,671,profile-03/01-A/result.json
timing,join,80,A1,decode_per_message,5.95,15,61,426,profile-03/01-A/result.json
timing,join,80,A1,apply_total_per_frame,6.91,,,671,profile-03/01-A/result.json
playback,join,8,C4,target_delay,94.76,115,130,79,clean-05/04-B/result.json
playback,join,80,C4,target_delay,161.85,175,177,78,clean-05/04-B/result.json
```

> 复核公式：表 A 帧均 = `timings[field].meanMs * timings[field].n / frames`；表 B = 对 `intervals`/`renderIntervalsMs` 直接统计（均值、线性插值 P95、max、>100 计数）。
> 第一段 CSV 的 `p95_ms`/`max_ms` 是 Stage 帧间隔；第二段的 `v2_ms`/`v3_ms` 是分项计时器的单次 P95/max，两者不可横向比较。
