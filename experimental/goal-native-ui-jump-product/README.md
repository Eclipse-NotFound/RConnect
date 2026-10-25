# nativeui2 隔离产品配方

准确正式78C为底，仅合并9C原生加载界面的RoomEntryView，以及52D跳跃补帧的GameBridge、RemoteMotion、NativeJumpPose；RConnectMod只将版本改为`0.2.24-nativeui2`。五份覆盖中，77个原类逐字不变、4个原类变化（含版本）、新增1类，最终82类。发送调度、RoomSync、普通分房和物理源码不加改动。

五份源码直接取准确已编译来源，重新核对各自实际SWF、固定prepared/compile回执、完整src/tools与冻结源清单。历史78C、9C、52D的22项环境分别保存，绝不冒充本次环境。准备不复制SWF或完整工具目录；真实构建才复制78C完整src/tools进入全新build目录。

工作目录为RConnect，准备和只读检查：

```text
python -B -X utf8 experimental/goal-native-ui-jump-product/prepare.py --prepare
python -B -X utf8 experimental/goal-native-ui-jump-product/prepare.py --check
python -B -X utf8 experimental/goal-native-ui-jump-product/build.py --check
```

根确认onlyRC的52D跳跃/念力回归通过后，才可显式构建：

```text
python -B -X utf8 experimental/goal-native-ui-jump-product/build.py build/m52/goal-native-ui-jump-product-01 --registry-wait 900
```

薄绑定沿用goal-jump-pose-product和原v5有界编译器：共享登记、每条Java启动1 GiB余量、384 MiB堆、300秒上限、512 MiB运行保护、隐藏编译器、实际PID等待/清理、原两条compc/mxmlc命令及22项安装前后检查不变。只读`build.verify(absolute_output)`必须见实际成功compile、两条命令、完整src/tools与真实SWF；只有准备文件不能通过。

运行必须配准确2DB0宿主及其既有独立准入；本目录不重编宿主、不生成运行入口、不启动AIR或部署。新产品构建环境与旧宿主/驱动的历史环境须分别核验。现有908D NativeLoadingProbe预期nativeui1，后续只允许另作明确版本适配，不能直接借旧通过结果当nativeui2通过。本配方不给组合原生/性能资格，也不重标原失败或旧回执。
