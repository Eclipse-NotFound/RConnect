# selfecho 原生双人对照入口

仅复用 `goal-three-issues-native` 的完整 run/build/analyze 和已编译 drivers-02：跳跃 9EE16FA6、抓取 FEF72AB4。没有新 AS、编译器或共享 runner 副本。宿主保持正式 A796，Sandevistan 保持 CEC6；不加载原生 UI 候选，不读取或生成 UI runtime-admission。

原 run 展开只有三处接点：绑定历史驱动验证器与原 analyzer；明确选择 baseline78C / selfecho1；限制新输出目录。测试主体不改：跳跃双侧 6/6、抓取 43/42、四个窗口、原生拟合延迟 <=160ms、完整消息/显示/计时恢复要求全部保留。原超时准确为跳跃 300 秒、抓取 360 秒；根已确认保留，没有改成 600 秒。6 GiB/512 MiB、登记、独占、私有桌面、错误扫描与回收仍执行原共享 runner。

驱动在 BF4A 时编译；当前 RV 是 638E。只复用 `goal-native-loading-native-v2/run.py` 的纯 `verify_environment_change()`，其调用不涉及 UI 产品、宿主或准入。原 build 的完整 inputs/verify 函数只作三处显式替换，展开在 `adapted-build.py.txt`：历史编译前后必须相等；当前实际22项只允许指定RV变化；结果区分 build_environment/runtime_environment。真实 installed() 从未替换。准确旧 driver 编译指令、ABI、源码、输入、输出与进程退出/回收证明照旧核验。

正式78C自身更早的编译环境按其原回执保留，不能写成驱动的BF4A环境。新 selfecho 必须调用其实际 build.py.verify，完整产物、准确源覆盖和编译回执齐全后才可运行；其本次编译环境必须等于当前638E组合。intent 的 product 明确保存产品编译环境、驱动编译环境和运行环境。所有原始结果保留 smoothnessQualified/performanceQualified=false，PASS不自动等于性能达标。

在 `mods/RConnect` 运行，输出必须全新：

```text
python -B experimental/goal-self-echo-native/run.py --source-check
python -B experimental/goal-self-echo-native/run.py --drivers build/m52/goal-three-issues-native-drivers-02 --product build/m52/recovery-room-production-05 --case native-jump --check
python -B experimental/goal-self-echo-native/run.py --drivers build/m52/goal-three-issues-native-drivers-02 --product build/m52/goal-self-echo-product-01 --case fast-held --check
python -B experimental/goal-self-echo-native/run.py --drivers build/m52/goal-three-issues-native-drivers-02 --product build/m52/recovery-room-production-05 --case native-jump --output build/m52/goal-self-echo-native-jump-baseline-01
```

另三轮分别换为同目录候选/基线及 fast-held，并使用新的对应输出名。缺完整 selfecho 产物时 `--check` 明确 not-ready，不创建运行输出。根统一执行构建和 AIR。
