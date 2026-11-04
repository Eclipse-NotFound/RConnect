# B 加入侧卡顿与延迟：本轮实测结论与可恢复源码（2026-11-04）

只处理 **B（主机权威线）**。A 源码、A 正式体、宿主 SWF、存档与配置均未改。

## 0. 结论先说

本轮**先证伪了一个看起来合理的优化**，再交付一个更小的安全改动。

| 尝试 | 实测结果 | 处理 |
|---|---|---|
| 播放头「停顿后按 +25% 速率平滑追赶」（不再 `position=max(position,target)`） | 加入侧 `maxLag`（最新确认时间 − 播放头）从历史 **90–218 ms** 恶化到 **456–597 ms**，`clock.delay` 长期顶到 **250 ms 上限** | **撤销**。播放头减速等于直接加延迟，方向与目标相反 |
| 每帧确认消费预算（真正积压时才限量） | 与上一条同批被撤销；`maxQueued` 反而升到 8–11 | 撤销 |
| 预测冻结阈值 150 → 200 ms | 双侧各 **13 项** `prediction hold` 契约检查失败 | **撤销**。150 ms 是已发布契约，不是可调参数 |
| 预测窗口 100 ms/3 步 → 150 ms/5 步（阈值不动） | 契约检查全通过 | 保留 |
| 删除 `SceneSnapshot` 每帧每子节点一次无用 `getQualifiedClassName`（结果从未使用） | 无行为影响 | 保留 |
| HUD 固定标签每条 frame 消息重设文本 → 仅 role 变化时赋值 | 无行为影响 | 保留 |

## 1. 关键测量：为什么「平滑追赶」是错的

`BStartupDriverMod.samplePlayback()` 每 100 ms 记录
`lag = replica.lastFrame.time - replica.clock.position`（最新已收确认时间减播放头）。

同一场景（textmotion）、同一驱动、同一宿主，历史与本次对比（join 侧 `PLAYBACK` 行）：

| 构建 | maxDelay | maxLag | maxQueued | underflows | samples |
|---|---:|---:|---:|---:|---:|
| entry1 `3b58198e` | 201 | 177 | 4 | 28 | 192 |
| smooth1/J11/J12/P0/P13 等 16 次历史 | 105–250 | **90–218** | 3–6 | 12–27 | 143–192 |
| fast1-01（含平滑追赶，budget=1） | 250 | **543** | 11 | 13 | 213 |
| fast1-02（平滑追赶，budget 条件） | 250 | **456–597** | 4–10 | 14–68 | 30–45 |

`lag ≈ delay` 是旧实现的恒等式：旧的 `position=max(position,target)` 让播放头**始终贴在墙钟目标上**，
所以「落后最新确认」的量正好是一个缓冲值。把播放头改成限速追赶后，`lag` 变成
`delay + 未追回的差额`，而主侧一帧本就 60–90 ms，差额会持续累积。

**结论（本轮最有价值的一条）**：加入侧的"延迟"在数值上就是 `delay`；
任何降低播放头推进速度的改动都会等量增加延迟，不能用它换取平滑。
真正能同时降低延迟与卡顿的只有一件事：**减少主侧发布间隔**（`host.publish`），
让 65 ms 基准缓冲重新够用。

## 2. 保留的改动（b-fast1-03）

源：`source-01/`（145 份完整副本），清单 `source-manifest.json`。
候选 `build/ab/b-fast1-03/RConnectMod.swf`，`9f60d9e6df1a053c5dea72127dc9eee87f815d2a043845cb3c9e5952449bad89`，
source `7b682a0145a115ceb20c69467605614888e25597df87f6819b20c6bc3e3432b2`，版本串 `B3-0.1-fast1`。

改动的 3 个文件：

1. `src/authority/MovementPrediction.as`
   - `Math.min(100, stepMS*3, now-base)` → `Math.min(150, stepMS*5, now-base)`。
   - 冻结阈值仍是 **150 ms**（契约）；只放宽窗口内允许重放的步数。
   - `GroundMotion.capture` 的 24 px 走廊、安全按钮判定、身份/地形/暂停校验、主机权威全部未改。
2. `src/authority/SceneSnapshot.as`
   - 层扫描循环里 `var kind:String=getQualifiedClassName(drawn);` 的结果从未被使用，
     而该循环每次捕获都遍历全部已绘制子节点 → 删除。
3. `src/RConnectMod.as`
   - `VERSION` → `B3-0.1-fast1`；
   - `label.text="RConnect B · 开发测试 · "+role` 每条 frame 消息都重设（原生文本排版 + 新字符串分配）
     → 仅在 `role` 变化时赋值。

## 3. 环境与证据边界

- 本窗口机器被其它会话持续占用（编译一次耗时 >30 分钟，游戏启动 70–100 s，历史为 15–20 s）。
  因此 **fast1-02 的 6 次 textmotion 全部未能进入行走阶段**，其唯一失败项是
  `text motion: diagnostic phase completes: stationary`（阶段预算耗尽），不是断言失败；
  这些回执保留，不作通过依据，也不作"卡顿已修/已坏"的依据。
- fast1-01（一次完整跑完 109/122 项）的 13 项失败全部来自被随后撤销的 200 ms 阈值改动，
  其余全部通过——这为 `PlaybackClock/SceneSnapshot/labelRole` 的当时形态提供了完整的
  阶段覆盖，但那不是 fast1-03 的字节证据。
- **fast1-03 尚未取得同字节功能回执。** 未部署。

## 4. 下一步（按收益排序，均有本轮证据支撑）

1. **主侧发布耗时**（唯一能同时降延迟与卡顿）：80 敌人 `host.publish` 32–34 ms，
   其中 `capture.units` 18 ms（282 个原生字段/单位 + 整棵姿态树）、`capture.tiles` 3.4 ms（全房 39 字段扫描）。
   下一步应先加计数再分级采集，不做无证据的降频。
2. **`FrameDelta.decode` 单消息尖峰**（41–49 ms，6–13 KB 包）：J11 已把均值降 51%，
   剩余尖峰来自大包多单位的路径克隆，属协议层，改动面大。
3. 本轮证伪的两条不要再试：**不要给播放头限速**；**不要改 150 ms 冻结阈值的契约断言**。

## 5. 复现

```powershell
python mods\RConnect\tools\host_authority\build.py --output build/ab/b-fast1-04 `
  --source-root build/ab/b-fast1-source-01 --optimized
python mods\RConnect\tools\host_authority\field2_driver\run.py `
  --workspace build/ab/b-field2-runtime-01 --scenario textmotion `
  --candidate build/ab/b-fast1-04/RConnectMod.swf `
  --result build/ab/b-fast1-test-textmotion-09 --preparation prepared-entry-01.json
```

（路径均相对 `mods/RConnect`；`build.py` 每次必须新的输出目录。）

离线契约复核（不运行游戏）：`python simulate_clock.py` —— 用逐行等价的 Python 模型
复算 `ContractChecks.playbackCadence` 的三条断言（连续播放/无倒退/不越界、暂停边界原子、delay 回落到 65）。
