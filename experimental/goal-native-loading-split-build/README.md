# 分房观察驱动：单次有界编译入口

这里只准备编译接线，不运行编译、AIR 或部署。产品和宿主运行准入仍由根单独核对。

入口先原样调用相邻 `goal-native-loading-split-probe/prepare.py.verify()`。真实 `source-manifest.json`、`source.diff` 未完成授权写入时，`--check` 或 `--build` 都返回 `not-ready`，且不会创建构建目录。本目录不生成、补写或替代这两份文件；此时尚不能冻结完整源输入。

核验通过后，仅复制清单内 17 个 AS（16 个原字节不变）、准确的 598D `ProductionDeclarations.swc`、8AA `GameCombatStubs.swc`、D52 `EffectsHarness.swf`。仅一条 AIR 配置的 mxmlc，入口 `A22RoomEntryTestDoc.as`，产物为 `entry-room/EffectsDriver.swf`；没有重编 ABI 或复制整套运行器。

编译复用既有 `runtime_memory` 和共享 `Registration`：1 GiB 启动可提交余量、512 MiB 运行保护、300 秒子进程上限、384 MiB Java 堆，登记后启动隐藏 JVM，`finally` 只回收本次子进程。实际 22 项安装在准备、启动和结束核对；不拿旧编译环境冒充当前环境。

只读检查（根在真实探针清单写入之后才能得到 ready）：

```powershell
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 'experimental/goal-native-loading-split-build/build.py' --check
```

根唯一执行的编译命令（工作目录 `mods/RConnect`，必须使用新输出目录）：

```powershell
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 'experimental/goal-native-loading-split-build/build.py' --build --output build/m52/goal-native-loading-split-driver-01
```

`verify(output)` / `--verify <目录>` 必须读到真实成功的 `compile.json`，核一条实际命令、退出码、PID 回收、内存记录、完整输入、17 源、ABI、Harness、编译日志以及安装前后指纹。返回编译证据，不授游戏功能、原生显示或性能资格。失败输出保留，不覆盖历史目录。

有界编译步骤参考冻结 `goal-three-issues-native/build.py`（8B85F7E6），只取一条编译和登记/保护方式；不借用它的旧产品或 BF4A 环境资格。所有实际依赖在合法编译时记入新 `prepared.json`，完成前不提前创建源清单或成功回执。
