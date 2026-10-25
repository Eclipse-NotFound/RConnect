# LAD 普通房首绘：最小产品构建入口

只接线已冻结 `goal-ordinary-lamp-first-raster-candidate` 的 23 份 LAD 源码，不修改其 Runtime、版本号或宿主源码，不写 LAD live/release，不启动游戏。当前仍是构建准备；没有编译回执或性能资格。

```text
python -B -X utf8 experimental/goal-ordinary-lamp-product-build/build.py --check
python -B -X utf8 experimental/goal-ordinary-lamp-product-build/build.py build/m52/goal-ordinary-lamp-product-01
python -B -X utf8 experimental/goal-ordinary-lamp-product-build/build.py build/m52/goal-ordinary-lamp-product-01 --verify
```

`--check` 只读取准确源码、工具、四个原 stub 和当时真实 22 项安装指纹；不登记、不建输出、不运行 Java。实际构建仅接受全新 `build/m52/goal-ordinary-lamp-product-*` 目录。`verify(output)` 缺真实构建回执时抛 `NotReady`，不会把源码准备或失败产物视为可运行产品。

两条编译命令逐项沿用 LAD `build/build.ps1`：

- 固定 `D:/Program Files/Adobe Animate 2024/jre/bin/java.exe`；固定本机 `mods/Sandevistan/build/tools/flexsdk` 和 airsdk 的 airglobal。仍为 Xmx768m、两个原系统属性、+flexlib、target-player32、debug=false、optimize=true。
- 第一步 compc 编译原四个签名 Unit、Bullet、Box、Tile；第二步 mxmlc 的 host-signatures.swc 始终处于 external-library-path。保留 swf-version32、use-network=false、static-link-runtime-shared-libraries=true、includes=lad.native.LadLampTarget，入口是 LightAndDarknessDoc.as。
- 不启动 PowerShell 再间接等待。每次直接 Popen Java，交共享 Registration 登记真实 PID，沿用 runtime_memory.wait_owned；每次启动至少 1 GiB 可提交余量，运行中 512 MiB 门槛，编译最多各300秒。finally 只结束并回收自己创建的 Java。
- 编译后用已在本机使用的固定 JRE11 和 FFDec 执行只读 `-dumpAS3`（180秒），同样登记和监控。读取 stdout 中实际 `scripts\\...as` 清单，规范化后必须与准确23源类完全相等；排除 fe 和测试类，保留 LadLampTarget。FFDec 不修改 SWF。

`recipe.json` 固定原 build.ps1、四 stub、候选清单、共享工具、两个实际 JRE、编译器/FFDec依赖的指纹。没有继承旧 8ADBA 部署回执的 protected 环境；`installation_at_preparation` 是本次真实22项安装，实际构建前后再次核对。若环境变化则失败，不能静默更新旧回执。外部 Java 注入选项非空时预检拒绝，避免固定命令被未知选项改变。

真实产物目录保存两项 `commands` 编译回执，以及独立 `class_probe` 回执、每个 Java 的 PID/退出/回收证据、启动内存/运行采样、配置、原始日志、源码与工具输入、安装前后指纹。失败文件保留；异常及 SystemExit 原因进入 stop_reason。classes、SWF 和全部证据重新验哈希后，verify 才返回成功。

构建通过仍只代表编译与类范围合格：需要根会话另行完成真实宿主三方法保留构建、组件和原生加载/画面/性能验证；本入口不部署、不包含 AIR 或分房探针。

冻结后停止写入，根为唯一实际运行者。
