# 原生加载观察：宿主验证器 v2 薄绑定

只在本目录新增接线，旧 `goal-native-loading-native`、其 recipe/private_runner、冻结观察器与 UI 产品都不改。

对准确旧 run.py（6600386F）只有两处精确文本替换，展开源码与差分在本目录：

1. 宿主验证器改为 `goal-native-loading-host-build-v2/build_host.py`，固定 F9A46DA8 完整 SHA。其补丁仅增加 `0xb0` 二元比较的来源跟踪；仍由该构建器独立核实际六步及最终宿主。
2. 默认宿主目录改为 `build/m52/goal-native-loading-host-03`。

另包一层原 bundle，将新 wrapper/manifest/展开源码与 v2 构建器的准确输入加入既有 pins；不替换原 bundle 的任何判断。产品仍走原 `build_product.verify()`，并限实际 product01 的 9C8536A7；观察器仍走实际 driver01 的 877B05DA。宿主 `validated=false` 结构回执与根实际独立语义准入必须分别通过；准入 schema、文件约束及 native-test-only 范围不变。

原 35 项 + 11 项、600 秒、原 DONE 与新增 DONE 同时等待、JSON/PNG 清理前保全、全部错误扫描、6 GiB/512 MiB、私有桌面、登记和回收原样继承。Sandevistan 仍为 CEC6；没有首绘桥资格，也没有给旧失败宿主补通过结果。

```text
python -B experimental/goal-native-loading-native-v2/run.py --source-check
python -B experimental/goal-native-loading-native-v2/run.py --check
python -B experimental/goal-native-loading-native-v2/run.py --output build/m52/goal-native-loading-native-01
```

`--source-check` 只核小文本与展开源码，绝不加载/解析大型 XML 或验证产物；这是当前代理仅执行的检查。正常 `--check` 沿原门禁，缺 host03/根实际语义准入时仍 ready=false，不生成运行目录、不启动游戏。实际完整检查与 AIR 由根在其它测试结束后串行执行。
