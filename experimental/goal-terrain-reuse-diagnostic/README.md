# DIAGNOSTIC_ONLY：地形画面复用的第一个拒绝原因

准确 5325/nativeui2 的完整编译源码为底，仅覆盖 RoomTerrainView 与 GameBridge。其余 80 类和 RConnectMod 的公开版本逐字节保留，使现成 1640 加载驱动可复用；本产物是独立诊断 SHA，不能用 nativeui2 名称冒称原 5325，更不能部署或授予性能收益。

复用原已审核 5A81 首拒因插点，取消旧“仅首次合并大图”筛选。只在隔离 `pfe-modsettings-rconnect-coop-` AppID 启用，每次正常完成的 restore 最多新增一条 `RConnectTerrainReuse DIAGNOSTIC_ONLY` JSON。原 RConnectRoomTiming 日志及全部恢复、复用判断、完整重画都不变。

记录 captureRetained/captureDirty、四个 admission operand 实际求值结果（值代表允许复用，后续短路未求值的字段缺席）、viewCreated、constructorValid、原复用 if 紧前 reuseGuardDirty、unchangedCalled、reused、首个拒因及 faultCount。constructor 与 unchanged 的首个身份/尺寸/flags 拒因按原字段顺序解释；style/backdrop/tile 比较沿原 same 循环直接取得第一个不同项，不重新运行 unchanged 或额外调用墙痕 checkpoint。tile 包含 x/y、字段名，以及比较两端标量的值与类型；超长字符串只保留 96 字前缀和原长度，明确表示截断。

诊断 helper 的异常均在其内部隔离；日志序列化/写入异常不传播到游戏。缺行、faultCount 非零、complete 非 true 均是诊断证据不完整，不能视为成功。原方法异常、返回值、字段访问与实际判定顺序保留；原 guard 拒绝后仅为解释再读相同原生数据字段，不调用游戏方法。只记录第一个拒因，不能据它声称剩余所有字段相同；若 reuseGuardDirty=false、未调用 unchanged 且 first=null，则含义是无需重画。

`prepare.py` 逐块正反还原旧诊断插点和本轮窄适配，剥离后精确回到 5325 两类原字节。额外硬核墙痕 checkpoint、unchanged、tileRedrawIfDirty 和原 timing 日志调用数不变。没有世界写入、像素采样、新协议、驱动或缓存。记录开销使本轮只能作机制取证。

构建薄绑定复用 v5 原编译器，仅三处文本适配：源码基底 5325 与正式安装 78C 分开；prepared/compile 各标 diagnostic_only 和 performance_qualified=false。原两条编译命令、登记、1GiB 编译启动门槛、512MiB 运行保护、隐藏进程、PID 收尾、22 项前后核验保留。真正产物须 `build.verify(output)` 检验编译回执及独立 SWF SHA。

在 RConnect 目录执行的文本检查：

```text
python -B -X utf8 experimental/goal-terrain-reuse-diagnostic/prepare.py --prepare
python -B -X utf8 experimental/goal-terrain-reuse-diagnostic/prepare.py --check
python -B -X utf8 experimental/goal-terrain-reuse-diagnostic/build.py --check
```

仅根在审查后执行编译（此轮准备不执行）：

```text
python -B -X utf8 experimental/goal-terrain-reuse-diagnostic/build.py build/m52/goal-terrain-reuse-diagnostic-product-01 --registry-wait 900
```

现成原三程、全部业务判据和实际 host 2DB0 另由根接线；本目录不新增运行器。
