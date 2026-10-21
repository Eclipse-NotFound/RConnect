# 墙面解码缓存工作集候选

基线是已冻结 `build/m52/recovery-07`，SWF SHA256 `c9f6492117124dea23a6991396cf9957d7b73a9730b747b4c8b1cad9533ca3bc`。生产覆盖只有 `src/rconnect/game/WallImpactVisuals.as`，与该基线相比只改三个数字：

| 有界容量 | 原值 | 候选 |
|---|---:|---:|
| 项数 | 64 | 128 |
| 数值槽 words | 32,768 | 131,072 |
| UTF-16 字符 | 131,072 | 524,288 |

不改解码格式、返回数组隔离、合法性检查、版本比较、pending/ACK 保护、房间状态、驱逐算法、reset、发送频率或测试阈值。继续使用 07 的默认无逐格日志 RoomCodec；生产不覆盖 RoomCodec。

## 为什么扩大这三项

原始证据：`build/cooperation/5314f8125d/join.log`，详见相邻 `recovery-flight-diagnostics/flight-diagnostic-01-review.md`。实际有 82 份数值 payload，总计 99,060 words / 298,328 字符，触发 1,276 次缓存未命中、1,246 次驱逐，全部驱逐均由 words 限制触发。没有缓存 reset，所有 payload 均满足现有数值缓存条件。128 项 / 131,072 words / 524,288 字符能覆盖本轮完整内容，不代表任何地图都能永久装下。

这是明确的内存换计算：仅按数值槽 8 字节、字符 2 字节估算，主要内容容量约从 512 KiB 增至 2 MiB，即多约 1.5 MiB。AS3 数组/对象/Dictionary 开销另计；不能把此估算称作实测私有内存增量。保留固定上限、FIFO 和 reset，避免无界常驻。未采用更复杂的按版本跳过解码方案。

## 实际生产组件

`prepare.py` 只生成/校验本目录文件，不含 JVM/AIR 启动。默认运行生成覆盖、完整旧/新测试类、真实数据、补丁与输入清单；`--verify` 只读核验。它强制固定 07 的 SWF/源文件指纹和本轮日志指纹。

- `components/rconnect/game/WallBefore.as`、`WallAfter.as` 是完整旧/新生产类；只改类名/构造器名，并加调用 private 方法的测试入口、只读缓存统计、释放测试 BitmapData 的入口。没有重写缓存/版本/像素算法。生成脚本去掉这些访问包装后逐字恢复相应生产源码。
- `components/rconnect/net/RoomCodec.as` 是冻结 07 的完整真实类，只在 unpack 函数入口加计数。两个实现共用该类；每次调用前后读取计数，记录真实解码次数，不用静态常量推算结果。`timingEnabled` 保持默认 false。
- GameBridge.probe、原生 Bullet 输入是最小环境夹具；BitmapData、ByteArray 压缩/解压与 JSON 均由 AIR 真正执行。没有游戏/TCP/动画性能验收。
- AIR 文档类 `WorkingSetChecks`，嵌入 `../data/flight-payloads.json`，输出到独立 AppID 的 `File.applicationStorageDirectory/result.json`。由主会话在新隔离构建目录编译和登记运行；本目录尚未编译/运行。

## 原顺序回放的准确范围

数据包含本轮 82 个**原始压缩字符串**和全部 1,276 个实际缓存未命中的原顺序（payload id、case、本机时刻）。第一条记录时缓存确为空；没有重置；每个 payload 都在序列中出现。测试依此顺序执行真实旧/新 `decodeWords`，逐一比较完整值、类型、顺序以及独立数组身份；另检查原始输入不变。

诊断为了不放大热路径，只为 1,147 个命中保留累计数，未保存其每次出现的顺序。因此**不声称回放了全部 2,423 次缓存查询**。旧、新代码的缓存命中仅返回 concat，不调整 FIFO 顺序或容量；省略这些只读命中不会改变所记录 miss 序列的驱逐决策。原始 122 次 protectedPixels 直接解码不属于该缓存路径，没有被塞进缓存命中率。报告记录这两个范围，保留原功能失败。

组件会实际断言旧实现 unpack=1,276、新实现=82，并按 8 个 case 输出各自次数。它还对每个真实 payload 检查：调用方修改返回数组后，再次命中返回值完全正确且独立。这里次数是**尚待 AIR 运行的预期断言**，当前未当作通过结果。

准备阶段已用 Python 检查记录顺序与 FIFO 容量的一致性：旧规则得到 1,276 次 miss / 1,246 次驱逐，逐 case 次数与原始诊断完全一致；候选容量的离线模型得到 82 次 miss / 0 次驱逐，均在 case 0。此项只是输入/容量一致性核对，不能代替组件对真实 RoomCodec 调用的测量。组件正常完成预计执行 **73 个断言**；必须检查实际结果逐项通过，不准把 expected 数改成运行结果来过门。

## 其它必要边界

- 分别构造项数、words、字符三个上限的独立驱逐；必须观测到实际旧/新类驱逐、三个容量不超限、最旧项再次触发真实 unpack。不是只比较常量。
- malformed/null、非数组、奇数 words、重复/倒序/越界/小数索引、越界/小数颜色、超过 3,200 words：原生拒绝/异常类型一致，重复输入不缓存。
- 原算法接受的字符串数值、嵌套单元素数组、null 强制转换继续保留原返回类型，不缓存；改变第一次返回的嵌套数组不能污染后续结果。
- public receive 实际像素、旧/同版本拒绝、坏批次不部分落地、重复/越界格坐标、不同房间的独立版本、reset 后重新接收。
- 实际 before/observe/report 生成待 ACK 接触；接收他方格时保留本地痕迹，ACK 后同一权威版本仍能落地。
- 本轮严格数据相等不需要数值容差；像素逐格完全一致。结果明确 `native_game=false`、`tcp_socket=false`、`performance_qualified=false`。

交付只完成源码和输入准备；编译器可接受性、AIR 组件结果、实际内存和原八轮流畅度均由后续运行判定。既有首发/尾段/帧间隔断言不改，不能因预计少解码便提前宣称问题修复。
