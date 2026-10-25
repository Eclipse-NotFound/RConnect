# 仅 RConnect：正常跳跃身体显示对照

2026-10-25；对已完成实测的只读回算。未修改原驱动、结果、安装或冻结候选；不追加测试。

## 结果与范围

准确 78C 基准 `75ac7b113b` 对准确 52D 候选 `13b3f522be`，均使用原 `goal-three-issues-native-drivers-02`、18 秒原生按键刺激。双方原 6 项检查通过；实际 ModLoader SOL 两轮两端均为 `requested == ok == [RConnectMod]`、`err == []`。其他模组物理文件仍在私有副本中，但未启用。

本组合中，52D 的双向正常跳跃身体帧推进明显更连续；结论来自最终 RENDER 的同姿态帧序列，非不同动画标签的 distinct 总数。不能扩展为位移、念力或全部动画问题已解决，也不把约 30fps 单独当成修复证据。

## 筛选与阶段

从各端唯一一份 `native-jump` 测量的相邻 `render` 行取 `(a,b)`；两行 `peer` 都存在、`pose == "jump"`、`stay == false`、`levit == 0` 才计入。身体步长为 `abs(b.peer.body - a.peer.body)`；0 为身体帧未变，至少 2 为跨帧。此筛选不重建插值时间，也不等于产品全部资格谓词。

阶段按 `b.at - startedAt` 分组：0–8 秒原地跳；8–15 秒跑跳；15 秒以后停止输入至原 18 秒窗口结束。停止输入后尚未落地的尾段仍按原记录计入。下表为“身体帧未变次数 / 合格相邻对数”。

| 观察端 | 阶段 | 78C | 52D |
|---|---|---:|---:|
| 主侧看加入侧 | 原地跳 | 97 / 174 | 28 / 174 |
| 主侧看加入侧 | 跑跳 | 92 / 163 | 20 / 164 |
| 主侧看加入侧 | 停止输入尾段 | 5 / 10 | 1 / 11 |
| 加入侧看主侧 | 原地跳 | 73 / 177 | 23 / 173 |
| 加入侧看主侧 | 跑跳 | 64 / 165 | 22 / 166 |
| 加入侧看主侧 | 停止输入尾段 | 4 / 8 | 1 / 7 |

合计主侧 `194/347 (55.9%) → 49/349 (14.0%)`，加入侧 `141/350 (40.3%) → 46/346 (13.3%)`。跨至少 2 身体帧的次数分别 `145 → 8`、`95 → 9`。相同筛选作用于本机角色时，两臂两端都为 `36/348 (10.3%)`，本机原生跳跃帧推进没有相应改变。未变帧也包含正常姿态停留，不一概认定为故障。

## 帧间隔与位置边界

全部有效相邻 ENTER / RENDER 以同进程毫秒差计算；分位数使用排序后向上取整的最近秩。两轮各端 `dropped == 0`。

| 指标，78C → 52D | 主侧 | 加入侧 |
|---|---:|---:|
| ENTER 平均间隔 | 33.330 → 33.328 ms | 33.335 → 33.328 ms |
| ENTER p95 | 37 → 37 ms | 38 → 37 ms |
| RENDER 平均间隔 | 33.335 → 33.337 ms | 33.342 → 33.320 ms |
| RENDER p95 | 44 → 44 ms | 42 → 41 ms |
| RENDER 最大间隔 | 97 → 82 ms | 99 → 106 ms |
| RENDER 超过 100 ms | 0 → 0 | 0 → 1 |

三阶段各端 ENTER / RENDER 平均间隔均约 33.3 ms，没有此次候选全程低帧率的证据。孤例为候选加入侧第 22→23 帧：ENTER 相对起点 727→833 ms，RENDER 735→841 ms，均为同一次 106 ms 间隔，不能重复计为两次独立卡顿；仍须保留，不能声称零长帧。仅两次独立运行，不授统计显著性或普遍性能保证。

仅对 15 秒内相邻两行均离地的角色，计算显示坐标 `(vx,vy)` 步长：远端位置 p95 主侧 `17.79→15.97 px`、加入侧 `16.66→16.84 px`；最大值 `39.21→35.23 px`、`33.72→32.90 px`。方向并不一致，且步长不是误差/延迟，不据此宣称位置更平滑。

## 普通驱动没有的证据

本轮 incoming 仅保存 `sampleTime/seq/x/y/dx/dy/stay`；最终显示保存 `body/pose/位置/速度/stay/levit` 等。未保存专用观察器要求的 `nativeJumpRun`、端点 `poseFrame/bodyFrame/bodyPlaying`、房间 epoch、统一观察顺序等，也没有私有 cursor。因此不能对这两轮补写“同一跳跃段两个合格端点产生真实中间帧”的严格资格，不能把以前全模组专用观察结果冒充为此次 onlyRC 结果。

既有 52D 专用观察与组件证据保留；本记录补充当前 onlyRC 的实际身体显示改善及帧间隔对照。根已确认此证据足够，不追加重复专用测试。原 `result.json` 的 `performanceQualified=false`、`smoothnessQualified=false` 均未改写。

## 精确来源

以下路径均相对 `mods/RConnect/`，SHA-256 为本次只读回读实值。

- 基准：`build/m52/goal-rconnect-only-motion-jump-baseline-01`；产品 `78c052aea963f1689b705ae1e14d274916ae1a1f7e81933390caf8d1a88f4699`。
- 候选：`build/m52/goal-rconnect-only-motion-jump-pose-01`；产品 `52d4723c1cf43e9ed2949c2e20debf7beda0b6068767c0bbaf83e83eb6a56e88`。
- 驱动源 `build/m52/goal-three-issues-native-drivers-02/tests/NativeJumpNetworkTestDoc.as`：`69c45eb85e1f7a77c4ca16dabbfd1cc82aee0cc60823ffc02722eb9bdabc3349`。
- 观察源同目录 `NativeMotionProbe.as`：`4ca25c80d0ebeda696f02ef842b56ea691fdf6dd8c78736e5c18e65b2712a394`。
- 驱动 `native-jump/EffectsDriver.swf`：`9ee16fa6ea2db8e0441a49e53f7ac55a4d5980c113706881e5cadd2d6f4c1e84`；其 `prepared.json`：`f80d5e5520eea127e12ae70744028d254978938d6127d7622a9ade5a5db9acc3`；`compile.json`：`9d4f654559cf767d626ef3e9089c9790ce41072ff71472b727a586fc63b81f0c`。

| 输出文件 | 基准 SHA-256 | 候选 SHA-256 |
|---|---|---|
| result.json | `3c787d000e3a58eccfc1499871733c295ff4dbdc446d4fe36ff7edba425383c3` | `e398756a7cce6a5e95af8c70371d8186fbade058d45f3e0587e01cea35f1cf47` |
| host-measurements.json | `525b8656a12c68de4c26411f2bfcb7b4c62c87e889522619b5461e409aeac7e3` | `9a86471e4584e1dcf084b112b85bc1bbad56ef9735966443786639bb55430c70` |
| join-measurements.json | `6fd7754dc0613b4cf3cfc56a68ffbe1565683a4fafbf7a0a44b9521bb03ea901` | `b2d4453080b42c3908d03ab885a9d5f0ce8b5c9c048d9ad5b0947fb8f39bd939` |
| only-rc-result.json | `251d49ec6f59581d4381f381345a2d43219410fa631495ac1928ec1cd8dfefb6` | `54f8159fa7ec89ae6bc183411e3cf8ebe9b7443abd91d19537188abe5f51d518` |
