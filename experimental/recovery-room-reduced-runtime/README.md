# 关闭三个视觉／场景模组的隔离运行入口

只用于本轮普通房对照，正式安装不变。`launcher.py` 接受原 `run_coop_regression.py` 参数；必须保留 `--all-mods --effects --effects-driver ... --seconds 600 --private-desktop --require-exclusive-air`。加 `--solo` 可做单人对照。使用另行准备的 `recovery-room-reduced-driver-01/timing`，不能复用依赖 CS 的旧 timing 或 240×125 scene 驱动。候选和外部驱动的准确绑定仍由外层验证入口提供。

执行前可只读运行 `launcher.py --check`；不会调用启动器、编译或启动 AIR。

原共享运行器字节固定为 `7eca453b…5ae4d3`，不修改该文件。只对执行副本做两个精确替换，并逐次保存展开源和差分：

1. 原冻结副本完成后、角色复制和 `inputs` 采集之前，且在原清理 `try/finally` 内，调用官方 `RemainsModLauncher.exe --root <frozen> --version 1.02 --only <原启用集合去掉三项> --no-ui --report ...`。三项为 LightAndDarknessMod、RealisticVisionMod、ContinuousSceneMod。只补入冻结副本所需 `supported-mods.txt`。不传 `--launch`；指定版本后此选择操作不依赖描述符读取。
2. `inputs.modules` 仅记录真正启用的模块；原全部 SWF 保留，另外记录完整物理库存。未改原错误扫描、CS 启用时注册判据、功能断言、频率、600 秒上限、6/3 GiB 启动及 512 MiB 运行保护、共享登记、独占判断和清理。

启动器本身在原登记内同步执行、隐藏窗口并回收；随后原 AIR 启动仍调用原 `before_launch`。每端启动前核描述符、独有 AppID、名单、全部物理 SWF 和旧 loader 状态不存在。原运行器结束并回收进程后，复制与解码该端真实 `ModLoader.sol`：要求新 session 位于本次启动时间内，boot/每个 requested/ok 都属于该 session，实际 requested 和 ok 集合准确等于启用集合且无任何 err。拒绝仅凭“没有模组日志”宣称禁用成功。

证据在原合作运行输出中：`selection/` 保存官方报告、名单、全部库存、真实 SOL 和解码状态；`reduced-selection-result.json` 将原功能结果和选择证据合并。`reduced-installation-after.json` 核全部 22 项正式输入未变。原 input/run/result 日志不重写。配置报告只是选择证据，真实加载证明来自本轮 SOL。

关闭 CS 不会撤销宿主 SWF 内已经部署的代码钩子；这些钩子仍由准确现行宿主提供，运行时 CS 模块不加载。此次结果只代表这组三项关闭后的普通房场景，不授予 RV/LAD/CS 全开或连续大图的性能资格。准备阶段未执行启动器、编译、AIR 或部署。
