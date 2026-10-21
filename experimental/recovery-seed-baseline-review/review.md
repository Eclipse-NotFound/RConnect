# Seed gate ON/OFF：无输入基线超时只读复核

2026-10-22。只读取冻结结果、驱动和准确 13 源码；没有改阈值、失败结果或生产代码，没有运行 AIR/JVM。

结论：两轮失败是**原生加载标志解除后，无法在原 1000 ms 内取得三帧静止样本**。不是角色漂移或按键未释放，也尚未进行 KEY_DOWN。ON/OFF 都失败，不能据此认定延后首绘有效或无效。已有记录不能确定这些长帧中最慢的实际回调。

## 输入与原结果

| 项目 | ON | OFF | 原成功 ON 对照 |
|---|---|---|---|
| 输出目录 `build/m52/` | `recovery-seed-gate-on-dual-01` | `recovery-seed-gate-off-dual-01` | `recovery-first-raster-scene-dual-01` |
| `build/cooperation/` | `c0df7677dd` | `7242e75f15` | `96b09cd943` |
| RC SHA 前缀 | `1177eb1ae9b2`（准确 13） | `49006ca98872`（仅 seed gate 关闭对照） | `1177eb1ae9b2` |
| 宿主 | 三者均 `fd92fbd5ae92…734e` | 同左 | 同左 |
| 驱动 SWF | `20e7deec18d7…91aa` | 与 ON **同字节** | `413bcfdc041f…b2c` |
| 原结果 | failed；host 14 PASS、join 9 PASS | failed；host 14 PASS、join 9 PASS | passed；host 47 PASS、join 36 PASS |

两个新结果都保留 join 的 baseline 超时、host 的 `timeout phase=wait round=0`，以及外部“三次结果不全”错误。host 已完成第一轮真实输入检查，等待的是 join 结果；不能把其 wait 超时当作第二条独立加载性能证据。三个 intent 的 22 项安装输入指纹逐项相同，Harness 也相同。这里只核对保存的输入与结果，未重新检查安装文件或启动测试。

## 超时发生在哪一帧

下列 `t` 是加入侧自己的 `getTimer()`，不能直接与主侧 `t` 相减。`baselineAt` 赋值本身没有打印；表中起点是紧随其后的 `baseline-start` 样本，所得跨度是实际等待的下界。旧成功轮的 `baselineElapsed` 与样本差有 1–5 ms 差异，不能把样本时间冒充精确赋值时间。

| 加入侧 round 0 | ON | OFF |
|---|---:|---:|
| 旅行开始 | 28137 | 27189 |
| `grant` 处理区间 | 37197–39137（1940 ms） | 36150–38081（1931 ms） |
| frame 探针首次观察 busy=false、ready=true、pause/cover=false | 42013 | 38839 |
| baseline-start `t` | 42332 | 41294 |
| 后续 baseline-frame `t` | 42474、44465 | 41553、41724、43281 |
| 相邻基线样本间隔 | 142、1991 ms | 259、171、1557 ms |
| 首样本到失败帧 | ≥2133 ms | ≥1987 ms |
| 实际取得的更新后静止帧 | 2 | 3，但第三帧已超时 |
| KEY_DOWN / KEY_UP 样本 | 0 / 0 | 0 / 0 |

所有失败前样本：同一 actor、同一 Ctr，`x=161.8, y=4320, dx=dy=walk=0`，左右键都为 false；`ctr.active=false` 是只读记录，旧成功样本同样为 false，不是本轮新增失败依据。

驱动 `baselineInput()` 顺序没有变化：先验证样本/累计连续静止帧，再检查 `getTimer()-baselineAt>1000`，最后才检查是否已有三帧。因此 OFF 第三帧仍必须失败，不能以“已经拿到三帧”为由改绿。ON 在第二帧即超时。

独立 frame 探针也看到了长间隔：ON `42423→44373=1950 ms`；OFF `41630→43151=1521 ms`。这些区间均处于 ready、非 busy、非暂停、非遮罩状态。OFF 另有更早的 `38839→41385=2546 ms`；baseline-start 在 41294，不能把整段 2546 ms 都算进基线窗口。

原日志定位：ON `join.log:52–77`，输入原始数组在第 75 行；OFF `join.log:59–79`，输入数组在第 77 行。失败后的 disconnected 日志不属于这段联机测量。

## 新 intent 是否改变等待条件

直接比较两份**冻结驱动源**：`build/m52/recovery-first-raster-scene-driver-01/tests` 与 `recovery-seed-gate-driver-01/tests`。

- `A22RoomMetrics`、`FirstRasterSceneProbe`、`RoomTravelSceneTestDoc` 三个文件完全相同。
- Timing 驱动仅新增 `seedGateIntent` 字段、配置阶段一次 `SeedGateNativeIntent.read()`/日志、用其布尔值替换旧常量、结果附带该对象。旧常量为 true；新 ON 意图也为 true。
- 文件打开/读取/JSON 解析只在 `!configured` 中执行一次，发生在 boot；不是 `travel`、`startInputCheck()` 或 `baselineInput()` 的每帧工作。基线前 `rasterProbe.finish()` 已把 active 设为 false，随后 `sample()` 立即返回。
- `stable()` 条件、baselineAt 的赋值位置、三帧规则、1000 ms 门槛、键盘与释放检查均未改动。没有源码依据认为 intent 读取把“加载等待”偷计入了这次 1000 ms。

不能从静态比较推断整个进程事件相位完全相同；一次启动读取和新编译字节可能影响最初时序，但没有相应计时或相同世界逐帧回放证据，不能把本次秒级停顿归因于它。

## 最慢回调：已知与缺失

本轮记录的最慢 **TCP MESSAGE 分发处理** 是上述 grant：ON 1940 ms、OFF 1931 ms，均早于 baseline-start 约 3.2 s。旧成功 ON 的首轮 grant 也耗时 1913 ms。`RConnectRoomTiming restore` 中 terrain/units/effects 等数字是累计检查点，不能求和当作各阶段成本。

基线窗口内没有 `A22 NETWORK RECEIVE`（单次非 room MESSAGE 分发 ≥100 ms 才打印）。这只排除了“已被探针覆盖且单次分发达到100 ms并正常返回”的日志事件，**没有排除**：

1. 多个不足100 ms的已排队单位/世界状态连续处理；
2. `TcpLink.onData()` 中发生在 MESSAGE 分发之前的 ByteArray/二进制解码，以及同一次 while 的累计成本；
3. 原生 World/绘图、RC 每帧/Timer、其他模组回调、GC 或调度等待。

ON 长间隔前有 `unitsync matched 130/130`，OFF 有 `142/142`；这些行没有独立时间/持续时间，不能据此把 1950/1521 ms 都算给 applyUnits。WallBlend 的10秒心跳只有累计/场景计数，没有这段逐回调耗时；CS/RV日志也没有可配对的边界。**不能报出已证实的最慢帧回调名称**。

若后续需要归因，缺的是同一时间轴上的首个 ready 前后少量帧：原生帧开始/结束、RC tick/Timer、socket整批 decode+分发（含包数/类型）、首屏/后台 scene 绘制边界，以及 GC/停顿证据。仅新增“窗口末尾FPS”无法补齐。此报告未增加插桩或修改驱动。

## 与旧成功轮的可比性

旧 `96b09cd943` 的三轮 join 基线实际记录 `563/149/682 ms`，按键响应 `256/52/213 ms`，因此原 1000 ms 检查确实曾在同 RC13+FD92、同22项安装组合下通过。本次主侧也通过首轮：ON baseline 712 ms、按键213 ms；OFF baseline545 ms、按键196 ms。

但同 seed 不代表完整运行负载逐项相等：旧首轮入口为 `(1161.8,4800)`，新两轮为 `(161.8,4320)`；主侧 units 分别为旧185、ON179、OFF191；grant state 字符串长度分别202876、197568、208472。三者均240×125、seed1380142925。不能把旧成功与新失败当作“只变了 intent 的严格同场景因果实验”，也不能仅靠三次不同负载的瞬时帧说明 gate 优劣。

两次新运行的内存守卫均未终止，也未检测到其他 AIR 重叠；失败窗口附近 commit 余量约 ON 5.80–5.97 GiB、OFF 6.16–6.21 GiB，物理可用约2.83–3.05 GiB。全程最低更低但部分发生在失败后；没有 GC/分页时序证据，不能把内存当作已证实原因，也不能以守卫未终止声称资源无影响。

## 冻结证据指纹

- ON join.log：`95244b1ddb919a7e0ed33415f663a069885790ba6e076f653354e9aa1e2d8a00`
- OFF join.log：`ae9258ee2e4144e2d2512545526d1bcb16233a13d5765db5ec103b78535a5331`
- 旧 join.log：`d38a5850ad0dc50b5f98db2e01fdad70f26e32611b7d45d205539731144d1136`
- ON result.json：`efb49dc16a509d747887ceea9743da6f0b9785136012381d5b83b5d934d947b5`
- OFF result.json：`a4f0ae0bf3a938dfdbcdd5b7b32f6bceaf99e722e50e1021cd0da48f45f10bb8`

原失败完整保留。该对照目前只证明两种配置都出现恢复后长帧，未完成三轮操作恢复资格，也未证明达到对应单人耗时。
