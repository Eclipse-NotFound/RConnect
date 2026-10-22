# 574D 离线采集优化：独立生产候选构建

仅准备构建入口；此处未编译、未运行 AIR、未提交或部署。候选完整来源是 CS 的 `rc-offline-production-proposal-20261023-r1/src`：78 份源码中 75 份与正式 574D 相同，只有 RConnectMod、Session、GameBridge 三类含提案改动。冻结时仅再将 RConnectMod 的 VERSION 改为 `0.2.24-offline1`。

脚本严格核对提案 proof `EC95927A…DD045`、patch `D17C2E92…06F23`，以及 `build/m52/coop-bundle-04` 的真实 574D 二进制、78 个来源指纹和 71 个工具输入。按 proof 逐项重做精确替换并比较补丁；工具逐字节复制 574D 的 71 个输入，不借用 room19、当前活动 src 或其它恢复候选。

从 RConnect 目录运行，默认只冻结新目录：

```
python -B -X utf8 experimental/recovery-offline-production/prepare.py
python -B -X utf8 experimental/recovery-offline-production/prepare.py --output build/m52/recovery-offline-production-01 --verify
python -B -X utf8 experimental/recovery-offline-production/prepare.py --output build/m52/recovery-offline-production-01 --build
```

`--build` 可在新目录准备后编译，也可编译已经准备但从未尝试构建的目录。`verify(folder)` 为只读入口。默认输出 `build/m52/recovery-offline-production-01`；重试须使用同前缀的新编号目录。已存在目录不能默认重新准备；有 compile-start、产物或构建痕迹后不能再次编译。

`prepared.json` 一次写入后不再改写，故其 `compiled=false` 永远表示准备时状态；实际结果在另一个一次写入的 `compile.json`，含产物指纹、命令、真实 Java PID、回收和安装前后证据。`verify()` 在编译回执存在时必须同时验证成功状态与产物，失败回执不能取得资格。

编译入口仍为冻结的原 `build_mod.py`，debug=false/optimize=true 的原参数规则不改，并强制明确隔离输出。原入口会在候选目录创建一个空 release 目录，不接触安装 release。只替换加载模块自身的 subprocess.run 调用对象，使原 compc/mxmlc 两条 Java 命令由外层监督：隐藏窗口、共享 game 登记、每次启动至少 1 GiB 可提交内存、原内存监控、真实子 PID 登记、finally 终止并回收自有编译进程。全局 subprocess 与原工具文件均不修改。

准备前后及排队取得登记后核对完整 22 项安装，构建结束再次核对；已准备后安装发生变化则拒绝。失败保留独立回执和所有已有文件，不覆盖候选、不自动部署。编译通过只证明构建完成，离线实机、首次联机与失败/离开/重连生命周期、显示机制及性能仍需单独验证。
