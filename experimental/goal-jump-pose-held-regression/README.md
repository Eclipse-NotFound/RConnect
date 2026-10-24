# 跳跃姿态候选的既有抓取回归

仅接入已编译52D4723C jumppose1或正式78C052基线，复用完整 goal-self-echo-native 历史驱动/环境验证和 goal-three-issues-native 原 fast-held 四轮。没有新AS、SWF、编译或测试框架。运行主体只把新输出前缀改为 `goal-jump-pose-held-`，产品通过独立回调选择，原 selfecho 文件/产物/结果不改。

使用准确 drivers-02 的 fast-held `FEF72AB4…317CB` 和原 Harness；动作、主43/加42项、四个窗口、160ms原判据、测量归属/恢复、原360秒、完整错误检查保持。原生业务数据与原 analyzer 不变。私有CS `nativeEnabled=false`、当前telemetry忠实复制、14模组实际加载、6GiB启动/512MiB运行门槛、共享登记、独占、桌面和自有副本/进程回收全部复用原流程。

准确驱动编译BF4A与当前638E环境沿原独立核对，不伪造历史安装。52D须调用 goal-jump-pose-product/build.py.verify，核实际源、两条编译成功、SWF及编译前后22项与当前一致；缺实际产物则not-ready，不建输出。基线也复用原真实来源验证。所有新源、原完整依赖与实际产品证据进入原intent/input验证。

在RConnect目录执行（prepare只冻结本目录文本，后续不重跑）：

```text
python -B -X utf8 experimental/goal-jump-pose-held-regression/run.py --source-check
python -B -X utf8 experimental/goal-jump-pose-held-regression/run.py --drivers build/m52/goal-three-issues-native-drivers-02 --product build/m52/goal-jump-pose-product-01 --case fast-held --check
python -B -X utf8 experimental/goal-jump-pose-held-regression/run.py --drivers build/m52/goal-three-issues-native-drivers-02 --product build/m52/goal-jump-pose-product-01 --case fast-held --output build/m52/goal-jump-pose-held-candidate-01
```

基线把product换为 `build/m52/recovery-room-production-05` 并使用新输出名。root统一实际运行，本入口准备不运行。PASS仅说明共享RemoteMotion改动未破坏既有念力四轮断言，不证明抓取110–120ms延迟降低，也不把跳跃补帧当总体FPS收益。结果保持performanceQualified/smoothnessQualified=false。
