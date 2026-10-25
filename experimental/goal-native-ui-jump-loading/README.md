# nativeui2 的最小加载接线

仅连接已冻结的 `goal-rconnect-only-loading` 执行入口与新整合产品；不复制旅行、登记、进程、内存或清理框架。宿主使用已有真实 2DB0，新的 RConnect 产品须由 `goal-native-ui-jump-product/build.py.verify()` 核验。旧 9C / 2DB0 的 `ui_bundle()` 仍实际执行，作为历史宿主构建及准入证明，绝不替代新产品的编译回执。历史安装与当前 22 项通过原环境桥分别核对。

新驱动从实际 908D 的三份 AS 派生，只把 NativeLoadingProbe 的准确预期版本 `nativeui1` 改为 `nativeui2`；另两份 AS 字节完全不变。双人原主 23 / 加 12 项旅行检查、每端 11 项 UI 检查不变；单人保留原 11 项旅行和 8 项通用观察，明确不授双人 UI 合同资格。运行仍实际只启用 RConnect，保留 600 秒、原单 / 双内存门槛、共享独占登记、私有 AppData / 桌面、错误处理、输入和正式 22 项前后校验及 finally 回收。

`run.py` 提供无参数 `candidate_bundle()`：返回真实新产品 `meta/compile/pins/installation/environment`、新 `driver_proof` 和经原入口核验的准确宿主 `bridge`。新产品或新驱动缺真实成功编译回执时必须 not-ready；文本检查不会创建编译输出或伪造 `compiled`。本目录的源码准备不启动 Java / AIR，不部署。

在 RConnect 目录执行（实际编译 / 运行仅根会话）：

```text
python -B experimental/goal-native-ui-jump-loading/prepare.py --prepare
python -B experimental/goal-native-ui-jump-loading/run.py --prepare-source
python -B experimental/goal-native-ui-jump-loading/build.py --check
python -B experimental/goal-native-ui-jump-loading/build.py --build --output build/m52/goal-native-ui-jump-loading-driver-01
python -B experimental/goal-native-ui-jump-loading/run.py --check --mode dual
python -B experimental/goal-native-ui-jump-loading/run.py --mode dual --output build/m52/goal-native-ui-jump-loading-dual-01
```

固定产品输出为 `build/m52/goal-native-ui-jump-product-01`，由其独立构建入口生成；本目录不负责产品编译。`--mode solo` 可复用同三程操作作对照。适配器只接受整合版 UI 分支，基线继续使用原冻结入口。统计仍区分总旅行时间、原生退出流程、实际 RENDER 遮挡和恢复耗时；固定布局种子不保证原生人口或出生点相同，不能据不同入口 / 视口宣称达到了原单人耗时。
