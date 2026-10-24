# 原生加载观察：宿主验证器 v2 薄绑定

本目录由根明确重开，前一冻结形态保留于 git `4dc936f`。旧 `goal-native-loading-native`、其 recipe/private_runner、冻结观察器、产品与宿主构建器都不改。

对准确旧 run.py（6600386F）有四处精确文本替换，展开源码与差分在本目录：

1. 宿主验证器改为 `goal-native-loading-host-build-v2/build_host.py`，固定 F9A46DA8 完整 SHA。其补丁仅增加 `0xb0` 二元比较的来源跟踪；仍由该构建器独立核实际六步及最终宿主。
2. 默认宿主目录改为 `build/m52/goal-native-loading-host-03`。
3. 探针资格改走显式历史环境适配，保留原完整验证函数和全部文件/命令/返回码/回收检查。
4. 将三份历史构建环境互相相等与当前运行环境校验分开；当前仅准许 RV 的一次准确变化。

产品仍原样执行 `build_product.verify()`，固定 product01 的 9C8536A7；宿主仍原样执行 F9A46DA8 验证器，固定 host03 路径。实际 driver01 固定 877B05DA：`adapted-probe.py.txt` 展示三个完整函数，探针自身的 inputs 函数字节不变；基础 inputs 的一个安装相等判断、verify 的历史/当前相等判断和返回环境字段各精确替换一次。私有函数命名空间保留真实 installed()，没有伪造其返回值或修改原模块/回执。该适配结果不声称原冻结探针 verify 原样通过。

`runtime-environment.json` 保存实际回读的 22 项。三份编译前后清单仍必须等于 BF4A 历史清单；当前清单恰好只允许 `mods/RealisticVision/release/RealisticVisionMod.swf` 从 BF4AC9CD…AFEF 变为 638E2D40…3710，其余 21 项全部相同。RV 真实部署回执固定 BB713983…D379F，17 项保护指纹另外核对，不能代替完整 22 项检查。探针返回、bundle 和运行 intent 内的 bridge 都明确携带 build_environment/runtime_environment；新接线、历史环境及部署回执全部加入运行 pins。实际 installed() 的运行前后比较继续执行。

宿主 `validated=false` 结构回执与根实际独立语义准入必须分别通过；准入 schema、文件约束及 native-test-only 范围不变。未提供实际 runtime-admission.json 时仍立即 not-ready，不创建、伪造或跳过准入。新 RV 的实际画面效果需重新实测，旧环境的结论不能作为新运行组合的性能资格。

原 35 项 + 11 项、600 秒、原 DONE 与新增 DONE 同时等待、JSON/PNG 清理前保全、全部错误扫描、6 GiB/512 MiB、私有桌面、登记和回收原样继承。Sandevistan 仍为 CEC6；没有首绘桥资格，也没有给旧失败宿主补通过结果。

```text
python -B experimental/goal-native-loading-native-v2/run.py --source-check
python -B experimental/goal-native-loading-native-v2/run.py --check
python -B experimental/goal-native-loading-native-v2/run.py --output build/m52/goal-native-loading-native-01
```

`--source-check` 只核小文本与展开源码，不加载/解析大型 XML。正常 `--check` 沿原门禁，缺 host03/根实际语义准入时仍 ready=false，不生成运行目录、不启动游戏。允许单独只读验证三份实际产物，但这不授予运行准入；AIR 由根统一执行。
