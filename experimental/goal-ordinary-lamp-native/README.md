# 普通房灯具首绘：最薄双臂实机接线

本目录只准备运行接线，没有编译、启动游戏或部署。复用冻结的 `goal-native-loading-native-v2` 实际 RC 9C8536A7、宿主 2DB0B4EB 和驱动 877B05DA；没有另编驱动，也没有恢复暂缓的分房探针。

- baseline：原 UI 修正组合 + 正式 LAD 8ADBA691。
- candidate：同一 RC/驱动/配置 + 新 LAD 宿主 + LAD 8A127C99，仅替换两个私有副本的文件。
- 当前安装仍 A796 / RC 78C / RV 638E。真实历史 RC、UI 宿主、驱动的 BF4A 编译环境经原 v2 明确验证；新 LAD 两份构建必须属于实际当前 22 项。没有改写 `installed()`、历史清单或回执。

真实旧 UI bundle 先原样验证，再独立调用新宿主与 LAD 的 `verify`。宿主默认实际新输出 `goal-ordinary-lamp-host-02`；失败 host01 保留。候选宿主还必须有根审查产生的 `runtime-admission.json`：`kind=ordinary-lamp-host-runtime-admission`、`scope=native-test-only`、`validated=true`、`installed=false`，绑定 2DB0 基底、实际候选、build 和 method-audit、实际 Grafon AS/P-code 及单独语义审查文件的指纹。没有实际回执就是 not-ready。本入口不创建它，也不把构建器的 `validated=false` 改成 true。

只对现有 UI 普通入口展开源码增加五个接点：启用既有私有 copy2 分支、原时停分支仅在确有时停候选时替换、增加精确 LAD 单文件替换、末尾核真实模块 SHA、启动前禁止旧 LAD 日志。原共享 runner/私有 runner 不变。`adapted-ordinary.py.txt` 与 `source.diff` 可直接审阅；其余功能、原 35 项旅行检查、双方各 11 项 UI 检查、原两种 DONE、600 秒、6 GiB/512 MiB、独占、私有桌面、登记、错误、回收及前后 22 项均保留。根在首次运行前发现原时停分支会读取空候选路径并明确重开本目录；旧冻结文本/清单/差分保存在 `prior-freeze-01`，此次仅补该非空条件，不改任何实际二进制。

沿原 child_stopped 回调在副本清理前保全 `LightAndDarkness.log`；原原生日志/JSON/最终 PNG 继续由旧接口收集、校验。LAD 日志必须实际 loaded/ATTACH 且无准备、存储、附着、绘制或恢复错误。记录全部 ATTACH/BAKE 与灯数，不将其误标为图像等价。`lamp_visual_qualified=false`、`optimization_path_proven=false`、`performance_qualified=false` 始终保留。

原驱动首程和返程 seed 是 **1380142925**，不得说成未锁种子。但 Math.random 人口、原生动态状态与镜头不能仅凭种子认定跨运行每个像素相同。原 PNG 只在全部三程结束后产生，不能代表首次省灯图的完整证据。

从游戏根执行（Python 用现有解释器）：

```text
python -B mods/RConnect/experimental/goal-ordinary-lamp-native/run.py --source-check
python -B mods/RConnect/experimental/goal-ordinary-lamp-native/run.py --arm candidate --check
python -B mods/RConnect/experimental/goal-ordinary-lamp-native/run.py --arm candidate --output build/m52/goal-ordinary-lamp-native-candidate-01
```

根已安排旧 UI v2 直接运行基准 `build/m52/goal-native-loading-native-lamp-baseline-01`。无需重复跑基准；完成后可只读采用其真实 35+11、原 inputs/run/result/log/清理证据，再从原 `module-logs` 读取 LAD 日志。此模式仅打印新摘要，不改任何旧结果：

```text
python -B mods/RConnect/experimental/goal-ordinary-lamp-native/run.py --adopt-baseline build/m52/goal-native-loading-native-lamp-baseline-01
```

如根另决定重跑基准，可用 `--arm baseline --output build/m52/goal-ordinary-lamp-native-baseline-02`，仍同一个原驱动。

## 图像证据缺口与最小后续补点（仅设计，未写驱动）

现有 ModLoader `AgentDebugProbeMod` 是另一个 AppID/生命周期的末端截图与树采样，不能配置为本驱动的首次 LAD attach 回调。现有 877B 也只有最终 PNG。两者不足以直接证明首次灯图等价。

可用外部一次性观察器，在 stage ENTER_FRAME -81（LAD -80 后、WB -100 前）捕获首次随机普通房：Carrier 的 `ladAPI.runtime` 已公开 world/location/lamps/enabled；灯记录公开 bo、holder、proxy、state。资格先要求同房、灯数非零、三引用均已 strip、holder 实挂、proxy 正在 loc.units，不能以空房通过。克隆四个原生 BitmapData 及 public satsBmp 后，同一调用内只执行一次真实 `g.drawLoc(loc)`，沿真实 `LadSceneBake.surfaces` 的筛选再次取图，逐像素比较并检查 sceneRedraws 恰加一、世界/房间/玩家/灯状态和代理身份不变。colorBmp 是 internal，现有两份 SWC 没有 Grafon 声明；不猜动态 QName，不造同名类或签名桥。其 hardlight 后的 backBmp 最终输出参与比较，必须明确 color_buffer_directly_observed=false。需保留原相机缩放修复边界，最终释放全部克隆。该操作会重绘、调用 drawAllObjs 并扰动本帧，只能算图像诊断，不能进入净耗时资格。

真实 alloff/allon 另在诊断阶段走原 Location 方法及后续 LAD 回调，记录灯 frame/state、代理数量和实际画面；直接 drawLoc 不等于测了开关灯。当前接线没有这些新检查，也不声称已测。捕获到不一致时保存原始差异，不为随机图像临时改容差或清掉痕迹。
