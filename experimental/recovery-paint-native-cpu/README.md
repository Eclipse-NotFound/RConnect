# 原生进程 CPU 只读观察

目的：复用准确 E6B3 尾段驱动，给原 `ensure → 下一次 ENTER_FRAME` 的约 2 秒空档补充 Windows 全进程累计 CPU 证据。零 Flash 样本本身不能证明在等待或 GPU 忙碌。

只增加四处运行器语句，见 `runner.patch`：准备观察器、已登记的 `HiddenProcess` 创建后启动、原 finally 最先停止、原 kill/wait/close 完成后保存。每 50ms 读取一次，延迟后不补发密集采样，每 PID 最多 20000 行。线程只积累内存，退出关闭自己复制的句柄；保存失败不阻止原清理。句柄来自现有对象，复制时只授予 0x1000 查询权限，不枚举或按 PID 打开其它进程；每次核对创建时间。

`process-cpu.json` 位于实际 `build/cooperation/<run>` 目录。记录累计 user/kernel（100ns）、创建身份、UTC 墙钟、单调时钟、读取时长、调度延迟、截断/错误/清理状态。原 `result.json` 的场景通过不代表此 CPU 证据完整，须另检查 `process-cpu.json.complete`。用尾段日志的 start/stop 墙钟找两端相邻样本；同时保留两端误差与采样空档，不声称恰好测到了区间边界。CPU 来自全进程所有线程，可能超过墙钟，不能当作主线程或 GPU 时间；加入外部采样后不授予性能资格。

旧 tail-native 输入、实际 E6B3 SWF、安装 22 项预期及排队后重新核验全部保留；安装 RV6593、隔离运行 RV7852。没有新 SWF、编译选项或游戏源码。源准备与 fake-query 检查通过只证明边界，真实 Win32 读取待根运行。

根从 RConnect 目录运行（不构建 SWF）：

```text
python -B -X utf8 experimental/recovery-paint-native-cpu/check.py
python -B -X utf8 experimental/recovery-paint-native-cpu/run.py --candidate build/m52/recovery-early-exit-compile-01 --drivers build/m52/recovery-early-paint-tail-driver-01 --game-candidate build/m52/recovery-early-paint-host-03 --output build/m52/recovery-paint-native-cpu-solo-01 --scenario scene --solo --sand-mode bridge --registry-wait 900
```

保留原登记、单人 3GiB 启动/512MiB 运行保护、三段、1000ms/3帧/95秒原断言。实际运行及原生 API 校验由根完成，本目录不启动测试。
