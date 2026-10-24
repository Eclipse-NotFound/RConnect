# 原生加载显示宿主：0xB0 证明修正

仅修正宿主 02 的真实静态证明拒绝，不改变 AS、协议、原生操作或产品。旧 `goal-native-loading-build`、UI 源、产品及失败回执保持原字节；产品继续使用原 `build_product.verify`。

准确失败输入是 `build/m52/goal-native-loading-host-02/donor.xml`（SHA-256 `12a69e4dd7198b24fd8f512d1f7ddaafbeca1674bce7e6d98fb7cbfd9eadfceb`）。方法 `fe.World::rconnectUiBlocked`，方法索引 3274，偏移 107 的 `0xB0` 对应 `comLoad >= 0`。Adobe AVMPlus 的[操作码表](https://github.com/adobe/avmplus/blob/master/core/opcodes.tbl)将它定义为 `greaterequals`：无立即操作数、栈净变化 -1。此处只给既有证明器的二元运算分支加入 `0xb0`，弹出两个操作数并推入一个未知结果；不将比较结果当作 activation/catch 身份。下溢、未知操作码、未知 slot 来源与异常控制流检查原样保留。

`build_host.py` 私有加载准确旧构建器，分别绑定 retainer 直接调用及 `body_names` 所用的 provenance 模块。`exact_sources()` 硬核旧 7 文件及新证明器仅此一处字节变化。新 prepared 的 inputs 同时包含旧完整来源与本目录源；prepare/build/verify 都使用该新 pins，不能拿旧 host02 的失败或旧产品资格充当 host03 成功。

新宿主仍运行原六步 FFDec、原共享登记、1 GiB 启动及 512 MiB 运行门槛、隐藏子进程与 finally 回收。九个原方法只前置字节码，exitStep 才使用供体；原构造器、静态初始化、未改方法及资源审计不变。默认新输出为 `build/m52/goal-native-loading-host-03`，已有输出不可覆盖。此目录不自动执行任何 JVM/AIR。

根执行入口（从 RConnect 目录，使用既有 Python）：

```text
python -B experimental/goal-native-loading-host-build-v2/build_host.py --check
python -B experimental/goal-native-loading-host-build-v2/build_host.py --prepare --output build/m52/goal-native-loading-host-03
python -B experimental/goal-native-loading-host-build-v2/build_host.py --build --output build/m52/goal-native-loading-host-03
python -B experimental/goal-native-loading-host-build-v2/build_host.py --verify --output build/m52/goal-native-loading-host-03
```

只读 API 为 `verify(Path)`，返回原结构构建回执；`validated` 仍为 false，真实最终语义复核与原生验收另行完成。准确 donor02 的离线 retain 证据只写独立 `build/m52/goal-native-loading-host-v2-offline-01`，不代替 host03 六步构建、不授游玩或性能资格。
