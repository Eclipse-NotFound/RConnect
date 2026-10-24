# 当前环境的三程加载对照

沿用已编译的 `recovery-room-scene-driver-02` 原始驱动、原始断言及共享运行器，不新增游戏内诊断。测量基地到新探索、返回基地、重访地图三程；计时包含原生切换、同步、出生放置、黑幕消失和控制恢复。完整当前22项环境独立冻结，历史驱动和产品的编译环境只作来源，不冒充本次运行环境。

每次只运行一个产品的单人或双人组。通过共享运行器的唯一AppID和私有桌面运行；首个AIR启动之前为所有端写私有CS启用偏好，并忠实复制当前 `telemetry.json`。补充输入与退出后回读另写回执，不改原运行器清单。内存门槛、独占检查、错误扫描、退出及副本清理全部沿用原运行器。不会改正式设置或存档。

从 `mods/RConnect` 执行，例如：

```text
python -B -X utf8 experimental/recovery-room-current-comparison/run.py --product build/m52/recovery-room-production-05 --mode dual --output build/m52/recovery-room-current-baseline-dual-01
python -B -X utf8 experimental/recovery-room-current-comparison/run.py --product build/m52/recovery-room-perf-current-01 --mode dual --output build/m52/recovery-room-current-candidate-dual-01
```

`--check` 只核对来源，不创建输出或运行AIR。输出目录不得重复。结果始终保留 `performance_qualified=false`：原三程通过仅是功能通过；版本间比较还须核对实际模组、场景、出生位置、单位工作量和时序。原生仍用自身出生选择，不将不同入口的两个耗时直接当净加速比例。此入口不宣称三程覆盖所有战斗或遮罩问题。
