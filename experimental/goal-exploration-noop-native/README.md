# ExplorationSync 单独优化的原生对照入口

只把冻结 `goal-three-issues-native/run.py` 的产品解析接到 `goal-exploration-noop/build.py.verify`；实际版本必须为 `0.2.24-explorationnoop1`，准确 recipe manifest 为 `941904ac31a3225d8543f089398840c7adfb46f75f367f89751be97abe65c163`。产品固定 `build/m52/goal-exploration-noop-product-01`，测量驱动固定已编译的 `goal-three-issues-native-drivers-02`。

基底仍为安装78C和宿主A796。核对完整源码清单，只有 ExplorationSync 和入口版本改变，RemoteMotion 与其它79类保持78C；没有合入 motion-v2、加载界面或其他候选。

原跳跃6+6、快抓取43+42、四程原160ms拟合门槛、全部测量/私有偏好/当前telemetry、实际22项安装核验、共享登记、6GiB启动/512MiB运行内存保护、独占AIR和finally回收均由原冻结入口执行。本目录不新增驱动或进程启动器，不改变通过门槛。

缺少真实 `compile.json` 时，`--check` 输出 `ready:false, reason:"not-ready"` 并以2退出；不创建运行目录，也不启动编译/AIR。回执存在后必须通过真实 builder.verify 的完整源码、命令、安装及产物检查；失败回执不能当作已就绪。`--source-check` 仅验证接线源码及指纹，明确不表示产品已编译。

以下工作目录为 RConnect，仅根执行实际运行：

```text
python -B -X utf8 experimental/goal-exploration-noop-native/run.py --source-check
python -B -X utf8 experimental/goal-exploration-noop-native/run.py --drivers build/m52/goal-three-issues-native-drivers-02 --product build/m52/goal-exploration-noop-product-01 --case fast-held --check
python -B -X utf8 experimental/goal-exploration-noop-native/run.py --drivers build/m52/goal-three-issues-native-drivers-02 --product build/m52/goal-exploration-noop-product-01 --case native-jump --check
python -B -X utf8 experimental/goal-exploration-noop-native/run.py --drivers build/m52/goal-three-issues-native-drivers-02 --product build/m52/goal-exploration-noop-product-01 --case fast-held --output build/m52/goal-exploration-noop-native-held-01
python -B -X utf8 experimental/goal-exploration-noop-native/run.py --drivers build/m52/goal-three-issues-native-drivers-02 --product build/m52/goal-exploration-noop-product-01 --case native-jump --output build/m52/goal-exploration-noop-native-jump-01
```

78C回测继续使用原 `goal-three-issues-native/run.py`、产品 `build/m52/recovery-room-production-05`，其余参数相同。本入口拒绝将78C或motion-v2冒充新优化产品。

保留 motion-v2-native 已使用的失败取证：原结果不变、逐条收集日志实际输出的测量到 `failure-measurements.json`，缺失/坏行显式记录；不把失败改成成功。进程未输出的内存中测量无法补造。输出路径必须是全新 `build/m52` 子目录。

交根冻结后只报告审查意见；此处未编译、未启动AIR、未部署，亦不赋予性能或全运动流畅资格。
