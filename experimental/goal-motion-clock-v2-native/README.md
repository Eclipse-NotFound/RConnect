# v2 原生测量接线

仅复用已冻结 `goal-three-issues-native/run.py` 与已经编译的 `goal-three-issues-native-drivers-02`。唯一替换函数是旧运行器的 `product()`：只接受 `build/m52/goal-motion-clock-v2-product-01`，调用该候选的 `build.py.verify()`，核真实编译回执、版本、源清单、产物指纹及当前22项安装字节。新接线自身也进入原 `intent.json` 的输入指纹。

没有新 AS 驱动、截图、启动器或阈值。原跳跃每侧6项、抓取主43/加42项、完整 ENTER_FRAME/RENDER/焦点/收到数据/呈现时间测量都由旧运行器执行。共享6 GiB启动与512 MiB运行保护、独占AIR、登记、两端私有偏好/telemetry、清理和最终输入复验保持原样。

失败时旧 `result.json`、共享运行日志和失败判定原样保留。额外 `failure-measurements.json` 收集日志中已经发出的全部测量，包括未通过的轮次；无法要求已崩溃进程补发尚在内存中的数据，缺失会明确标记。额外提取失败只报错，不覆盖原失败结果。

先执行产品编译；之后工作目录 `mods/RConnect`：

```powershell
python -B -X utf8 experimental/goal-motion-clock-v2-native/run.py --source-check
python -B -X utf8 experimental/goal-motion-clock-v2-native/run.py --drivers build/m52/goal-three-issues-native-drivers-02 --product build/m52/goal-motion-clock-v2-product-01 --case native-jump --check
python -B -X utf8 experimental/goal-motion-clock-v2-native/run.py --drivers build/m52/goal-three-issues-native-drivers-02 --product build/m52/goal-motion-clock-v2-product-01 --case native-jump --output build/m52/goal-motion-clock-v2-native-jump-01
python -B -X utf8 experimental/goal-motion-clock-v2-native/run.py --drivers build/m52/goal-three-issues-native-drivers-02 --product build/m52/goal-motion-clock-v2-product-01 --case fast-held --check
python -B -X utf8 experimental/goal-motion-clock-v2-native/run.py --drivers build/m52/goal-three-issues-native-drivers-02 --product build/m52/goal-motion-clock-v2-product-01 --case fast-held --output build/m52/goal-motion-clock-v2-native-held-01
```

仅根会话启动实测；每条实测串行运行。基线继续用旧入口原命令，不借此改历史输入或失败证据。组件通过也不等于本机掉帧、远端流畅、有限特效或密集场景已经达标。
