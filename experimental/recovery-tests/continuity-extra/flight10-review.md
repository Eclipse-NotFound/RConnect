# recovery10 普通高速飞行复核

2026-10-22。只读复核既有运行 `build/m52/recovery-flight-native-09` / `build/cooperation/9898f0da34`；未启动测试、未改断言、驱动、生产或冻结记录。候选为 recovery10，驱动为 recovery-flight-drivers-15。

## 结论

原结果仍为 **FAIL**：主侧 64 PASS / 0 FAIL，加入侧 75 PASS / 2 FAIL，两侧均完成全部八轮。两项失败都在 case 7。八轮接触尾段的原生位置、动画帧、时长、实际合成像素及结束清理检查全部通过；没有丢失/重复场景。仅为普通单发功能轨迹证据，不授予密集场景或整体性能资格。

| case | 方向 / 武器 | 对侧首显相对源首显 ms | 对侧最大显示间隔 / 原上限 ms | 接触尾段源 / 对侧 ms | 对侧尾段游戏帧 |
|---:|---|---:|---:|---:|---:|
| 0 | 主→加 / lmg | 199 | 45 / 85 | 77 / 54 | 2 |
| 1 | 加→主 / lmg | 125 | 38 / 96 | 98 / 100 | 3 |
| 2 | 主→加 / quick | 141 | 42 / 85 | 109 / 101 | 4 |
| 3 | 加→主 / quick | 129 | 60 / 85 | 127 / 89 | 3 |
| 4 | 主→加 / plamg | 175 | 39 / 85 | 88 / 76 | 3 |
| 5 | 加→主 / plamg | 122 | 44 / 85 | 68 / 75 | 3 |
| 6 | 主→加 / alilight 向右 | 108 | 53 / 85 | 71 / 71 | 3 |
| 7 | 主→加 / alilight 向左 | 129 | **104 / 85，FAIL** | 85 / 66 | 2 |

case 7 另一个失败是动画帧停留：源飞行段 35 次变帧、最长 23ms；对侧 25 次变帧、最长 131ms，超过原公式 `23 * 1.5 + 85 = 119.5ms`。其位置停留仅 26ms，不能把“动画循环帧相同”误说成位置冻结。

## case 7 的准确时间链

以下 `at` 为加入侧 getTimer；`frame` 为真实 ENTER_FRAME 计数，RENDER 可在同一游戏帧出现两次。

| at | frame / render | 观测 |
|---:|---|---|
| 73482 | 39 / — | 第一份有效轨迹包含源 `113119:f1`、`113187:f2` |
| 73520 | 41 / 81 | 首次显示 `x=1603.4,y=443.65,f=1` |
| 73546 | 41 / 82 | 同一位置、同一 f1；首次像素读取已完成 |
| 73611 | 41 / — | worldstate 观测到源 `113216:f3`、`113233:f4`、`113255:f1` |
| 73620 | 41 / — | unitsync 观测到源 `113119..113255` 五份历史点 |
| 73621 | 41 / — | worldstate 观测到源 `113308:f2` |
| 73650 | 42 / 83 | 下一次显示 `x=1432.9,y=434.1,f=1`；距上次 RENDER **104ms** |
| 73651 | 42 / 84 | 同一位置、同一 f1；从首次 f1 起累计 **131ms** |
| 73707 | 43 / 85 | 显示下一循环的 f2 |

源端真实动画经过 `1→2→3→4→1`。长帧跨过中间动画后，再显示同一循环帧，解释了这两项失败为何相关。保留失败，不因已知解释而改绿。

该 104ms 空档内，已有记录显示 **10ms 内三条相关弹体观测**（worldstate、unitsync、worldstate），且三条都在恢复绘制前到达，分别提前约 39 / 30 / 29ms。恢复绘制时已有中间点，不能说仍在等待第一份轨迹。但 73546 前仅持有到源 113187 的点，不能据此断言整个空档期间始终不缺后续样本。

这些是筛选后的弹体事件观测，**不是完整 TCP 包计数或处理耗时**。`observeWire/observeGuns` 只记录本轮武器的 flight，缺少消息唯一号、完整包大小、Session 入口/退出、socket 到达和源发送时刻。现有普通消息日志只有无时间戳的 `injected alicorn1`、`removed local extra`、`unitsync matched 3/3`，不能将它们定位到这个窗口。由这些数据只能证明相关数据集中被观察到，**不足以定位为接收处理负载，更不能量化其占了 104ms 中多少时间**。

首次合成像素读取耗时 23ms，位于 73520 那次 RENDER，完成后才有 73546 的记录；104ms 空档从 73546 开始。接触像素读取发生在 74659 以后。不能直接把 104ms 算作任一次像素读取时间，也不能仅据此排除先前测试工作对后续调度的影响。源端自身的最大 97ms 空档发生在更晚的 `113839→113936`（墙钟 `1792609847329→1792609847426`），不是对侧本次空档所在时间。

case 6、7 都是原生 UnitAlicorn 所有的闪电，采用 `RemoteMotion.enemy()`；recovery10 的新增累计校准只用于 `!immediateStart && bufferLimit==0`，未改变敌人这一分支。当前记录没有帧内分段证据，停止于“不能定位”；不为追逐偶发长帧扩大诊断。

## 与旧 recovery08 普通运行的边界

对照为 `recovery-flight-native-08` / `105bfac8ad`，候选08 / driver14。

- driver15 与 driver14 的 15 份 tests 文件及 2 份 analysis 文件逐字节相同，断言与公式没有变化。SWF 和 harness 因重新构建而不同，不能称二进制相同。
- 两轮游戏和资源相同；除外部 RConnect harness 外，运行的其他模组相同；22 项安装输入相同，各轮安装前后均未改动。双方完整 22 项运行输入审计均通过。
- case 0 首显差距 **354→199ms**，首个有效轨迹观测到显示 **308→143ms**，原生发射到显示 **458→240ms**。这是实际观察改善，没有把状态机预测当实测。
- 旧08 source prepare/armed 等阶段不同，源端发射到首显也由约 104ms 变为约 40ms；弹道初始状态/速度存在差异。不能将全部改善归因于时钟算法或作整体百分比。
- 旧08仅 case6有106ms间隔失败，本轮case6为53ms，但case7出现104ms及动画131ms失败。一次失败位置变化不代表整体性能已达标。

## 关键 SHA-256

| 输入 / 结果 | SHA-256 |
|---|---|
| recovery10/RConnectMod.swf | `184eea3d6405ee57cb0bc3f6cfa78668f5ca9334888b0ca2af04095bc17c4608` |
| recovery-flight-drivers-15/prepared.json | `deb7bc2a296dbdcfb97fe813f65386a09d864b12ae6d48eb06bc71a1283b87fa` |
| driver15 EffectsDriver.swf | `033f09110e0a2635c18e700621475ee03548473f1a17d1dd25853ad4a14a11b1` |
| driver14/15 NativeFlightContinuityTestDoc.as | `3fd803a59bfa84fd9aa5e82c3d6df83934d5041ac399b0b335ef57468f0da23a` |
| driver14/15 analysis/native_flight.py | `790e7c0b7f00daa8e9a11e3f45cf216706e01b23a27a2430c01efecea4bef381` |
| recovery-flight-native-09/result.json | `916c35ca86b2766b8a3cd5a46cd9fa66b97b40236bc715a9082dc073edb14235` |
| recovery-flight-native-09/flight-summary.json | `92fc605bb1477c2d1c12ae9f34124ec4d4dceef94e1b780d8b16e9be205112cd` |
| 9898f0da34/input.json | `c16e20cfd2a8762f5860841266945d12895df6cba1232ae611ad5bf9fb3558ff` |
| 9898f0da34/run.json | `4f184a9910a44a3b1e6d6c21b6a48f735c37e0d63abfcf2f27b04d4cba80a9a9` |
| 9898f0da34/host.log | `1ab72fb8c22034f426b66b5867ff8b68a6682d6d0c1f9ffe3dcf56a4497f47c6` |
| 9898f0da34/join.log | `6b81eac82245c2620cb5e9cd6f7fa8f9a303d85656da2baf72181682f310b047` |
