# 普通房关闭 LAD／RV／CS 的最小接线

复用 `goal-ordinary-loading/run.py` 的当前 78C／A796 准入、三程结果、私有配置复制、原共享运行器与收尾。既有入口、AS、二进制及正式配置均不修改，不重新编译。

仅两个接线文件：

1. `run.py` 薄载入准确普通入口（SHA `5613e8bc…96b3502`）。两处窄替换：配置复制钩子跳过官方选组程序的 `before_launch` 通知；真正 AIR 启动前允许且仅允许一条已退出的选组进程历史，PID 必须等于本轮 `selection/launcher-process.json`、`air_launch=false`、退出码 0、`test_registry.gone(child)=true`，并且登记不处于 launching。登记历史不清除，其他原检查和配置复制保留。固定复用已编译 reduced 驱动 `build/m52/recovery-room-reduced-driver-01/timing`（SHA `80e56d6e…b8ad7f9`），逐项核历史 35 个输入、9 个产物；历史安装只记录来源，当前 22 项另行真实冻结与前后核验。
2. `runner.py` 薄载入准确旧 `recovery-room-reduced-runtime/launcher.py`（SHA `a5d3a120…ab72601`），只把其登记回调交给普通入口包裹。旧官方启动器选组、实际 SOL 审核和原共享运行流程原样执行，不复制新的运行框架。调用链是普通入口钩子 → 旧 selector 钩子 → 原共享 runner。

官方 `RemainsModLauncher.exe --root <自有冻结副本> --version 1.02 --only <其余原启用集合> --no-ui --report ...` 仅选择副本模块，不传 `--launch`。LAD、RV、CS 的 SWF 留在物理副本，但不加载；其余原启用模块保持。旧 selector 在原登记内运行并回收子进程。最终同时核真实 `ModLoader.sol` 的本轮 session、requested/ok/err、日志中的 CS 未加载断言、原三程的实际非合并房间和所有原错误检查。

原 `result.json` 保留，不重写。新增 `reduced-result.json` 必须也为 `passed:true`；它将原功能通过、准确选组和真实加载证据合并。单人 3 GiB／双人 6 GiB、运行 512 MiB 压力底线、独占 AIR、源与安装不变、清理断言全部沿用。结果仍为 `performance_qualified:false`，关闭三项的结果不代表全开组合。

## 使用

在游戏根目录，只读准入检查（已实际通过，无 JVM／AIR）：

```powershell
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 'mods/RConnect/experimental/goal-ordinary-reduced/run.py' --product 'build/m52/recovery-room-production-05' --check
```

实际运行由主会话安排，必须使用未存在的输出目录：

```powershell
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 'mods/RConnect/experimental/goal-ordinary-reduced/run.py' --product 'build/m52/recovery-room-production-05' --mode solo --output 'build/m52/goal-ordinary-reduced-solo-01'
```

本入口仍忠实复制当前 telemetry 配置，但不启用 CS。私有 CS 偏好保留 false，驱动另核 CS 类没有加载，不能仅凭偏好文件宣称关闭。

首次 `170de91308` 在 AIR 前因原外壳把已退出的选组 PID 历史当成活动进程而拒绝。旧结果不变，两份旧入口已保存至 `build/m52/goal-ordinary-reduced-solo-01/recipe-run.py` 和 `recipe-runner.py`；上述进程历史判断是此次唯一运行修正。
