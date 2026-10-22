# 59bdfdf888：原生单人尾段优先级区间

实际结果：`build/m52/recovery-paint-enter-bands-solo-01/result.json`；原始日志：`build/cooperation/59bdfdf888/host.log`。35 项通过、0 错误，profile_valid=true，安装未改变。准确 driver 为 `e25bb481e76ef0efecbf7775d6752ac5629f0ae30734c7bc194fc1ad143545a2`，prepared 为 `2d3b7e641c64385d3a5f22e6979c364e067593ee79499e876cb4255367f1fa16`。

首进和重访的八个标记都齐全，同一 startStage、双时钟有序，faults/duplicates/overflow 均为 0。基地流程未触发目标 ensure，八项明确为 before-target-ensure，没有伪造时间。Flash CPU 样本仍为 0。

| getTimer 区间（ms） | 首进 | 重访 |
|---|---:|---:|
| sampler start → -1 | 137 | 87 |
| -1 → -7001 | 2561 | 2522 |
| -7001 → -9001（4 段） | 各 0 | 各 0 |
| -9001 → -10001 | 4 | 6 |
| -10001 → 最低优先级（3 段） | 各 0 | 各 0 |
| 最低优先级 → 首 RENDER | 1 | 2 |
| 首 → 末 RENDER | 2 | 3 |
| 末 RENDER → 下一 ENTER | 15 | 20 |
| 全尾窗 | 2720 | 2640 |

对应墙钟全尾窗同为 2720/2640ms；主要区间 -1→-7001 同为 2561/2522ms，-9001→-10001 为 5/7ms。其它差异为相邻读钟的 1ms 边界差，总和一致。

这次数据把主要单人尾段成本定位在同一 Stage 的 -1→-7001 优先级区间；不能继续把整段约 2.5 秒归给 -9001→-10001 所在的回调范围。标记只限定 dispatcher 顺序，不能单凭此结果确定某个模组或原生函数。下一份独立源码将八个标记移至 -80/-100/-200 附近及 -7000 前后，不修改生产源；本轮没有修复或性能发布资格。
