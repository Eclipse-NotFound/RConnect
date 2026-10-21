# recovery-09 地形循环局部候选

只有一个生产覆盖：`src/rconnect/game/NativeTileState.as`。准确基线为 `build/m52/recovery-09`，SWF SHA `1507686cd0811f6e6697a663ceed08ed7f85c8562399d50ccc79a891f8503acf`；源文件 SHA `dab683e9d14e18e8b7e35a917da8a7e237391b602f43d315661fd0d11ce8cae5`。没有改安装版、整合源或冻结候选。

已有诊断给出的优化范围是大地图 nativeRestore 526/594ms、nativeCapture 298/283ms；这是整个方法的时间，**不是本补丁保证能节省的时间**。本候选没有运行 JVM/AIR，没有收益结论。

本次只改变循环内重复元数据工作：

- restore 的每行 `seen={}` 改成此调用内一个固定长度 `Vector.<int>`，用非零行号标记已见槽位；下一次调用和重入调用各自拥有独立存储。
- 经过原有表头验证后，以槽位保存字段类型和 required 标记，避免在每个变化值上重复从字段名查表。
- capture / restore 的坐标默认值提前编为槽位、X/Y轴、步长；逐格仍执行原来 `base + coordinate * step` 的运算顺序，不改偏移、数值或协议内容。

全部数据行仍先验证后写入；字段/坐标/行/类型/重复槽位错误仍走原错误字符串。写入顺序、`setZForm` 及 opacity 恢复、每格一次 callback、对象引用、不支持形状的 null 回退保持。元数据只在一次调用内存在，没有跨地图缓存。生产调用来自 TerrainSync 的同步恢复，callback 只记录地形观察状态；本方案不新增对“callback 在恢复中篡改传入协议表头或原生 Tile 类声明”的支持。

## 实际旧新完整类组件

`components/` 同时编译两个真实完整 NativeTileState：旧类仅把类名改为 `ControlNativeTileState`，新类与生产覆盖逐字节相同；NativeRoomState 与 RoomCodec 是准确09源字节。相邻 fe.loc.Tile 是既有 room-entry 的明确替身（声明字段与 setZForm），不是运行中的游戏本体；fe.unit、GameBridge、TurretDisplay 也只作邻接替身。

计划67个实际AS断言；01 曾编译并启动 AIR，但没有完整结果，当前分步夹具尚未执行：

- 3项采集/真实RoomCodec/传输等价；9项有效恢复（v1/v2、坐标覆盖/负坐标/槽位重排、空覆盖行、callback写入/抛错/重入），比较完整标量、错误内容、回调次序与对象身份；
- 40种非法表头/网格/末行/类型/非整数与重复槽位，旧新均须同样拒绝、在任何原生写入或callback之前失败；
- 10种不支持采集形状回退，以及2种末尾原生Tile缺失/非原生对象的恢复拒绝；
- 3轮真实旧新完整类的30000格采集与恢复，交替先后次序，保留每轮原始耗时。每轮比较全表输出、全部恢复标量及30000次callback。没有“必须更快”的断言，组件也不给整机性能资格。

离线核对（无进程启动）：

```powershell
python -B -X utf8 experimental/recovery-terrain-loop/prepare.py
python -B -X utf8 experimental/recovery-terrain-loop/check_sources.py
```

父会话后续串行调用既有通用组件执行器；它负责冻结新目录、共享game登记、编译和独立AIR、22项安装检查及子进程清理。本次未调用：

```powershell
python -B -X utf8 tools/validation/run_recovery_component.py --source experimental/recovery-terrain-loop/components --entry TerrainLoopChecks.as --expected 67 --output build/m52/recovery-terrain-loop-component-03 --registry-wait 900
```

组件只用于等价性和小循环定向计时；通过后仍应在同种子原生旅行流程比较 nativeCapture/nativeRestore、总导入及恢复后三帧。保留失败、冷轮和反向顺序，不用组件计时替代用户“单人相应流程耗时”的门槛。

## 组件 01 未完成与夹具修正

`build/m52/recovery-terrain-loop-component-01/receipt.json`：编译成功，AIR exit 124，`Component wrote no result`，安装及输入未变。旧冻结源、Checks.swf、空 stdout 和失败回执全部保留。通用执行器的 AIR 等待实际上是 `wait_owned(...,60,...)`；本轮不修改它，也不延长任何时限。

旧夹具构造函数一次执行 64 项小检查及 3 轮大表测试；每轮 `canon(a)==canon(b)` 一次递归构造两份完整大字符串，然后同步比较 30000 对 NativeRoomState 标量。此路径没有一次事件循环让出或中间记录，是明确的脚本长栈风险。没有 ScriptTimeoutError 或停点日志，不能声称已实证 01 正好在某条 canon/describeType 内超时；NativeRoomState 本身已按类缓存 schema，并非每格重新 describeType。

修正仅限测试调度：构造函数只排任务；ENTER_FRAME 以 8ms 调度预算推进小检查及大表准备/比较，达到预算后留下一帧继续。每次真实 capture/restore 仍是一整个同步调用，单独紧贴调用记录 getTimer；分帧建房、日志和等价比较不计入被测耗时。完整表比较改成同一 canon 规则比较全部非 rows 表头与按原序全部 30000 行；完整恢复标量仍逐格用原 canon 规则比较，无抽样。3 轮顺序仍旧/新、新/旧、旧/新，保存所有原始样本。

每个步骤开始/结束及最后完成都写 `File.applicationStorageDirectory/progress.json`，并发 `TERRAIN_PROGRESS` trace。根据运行目录 process.json 的 appid，可在 `%APPDATA%/<appid>/Local Store/progress.json` 查看最近阶段、游标、已完成断言和已采样耗时；进度不等于通过，只有完整 result.json 的 67 项与现有 runner 一致检查才能通过。每轮结果另外保存 tableRowsChecked/cellsChecked/callbacksOld/callbacksNew，均必须为 30000。未修改任何旧/新生产类或相邻替身，未调整 frameRate，未运行编译器或 AIR。

## 组件 02 未完成与验证器修正

02 已编译/AIR，最终仍 exit124 / 无 result，冻结输入与安装不变。原日志保留：前64项failed=0，round0全部真实调用已完成（captureOld549/captureNew590/restoreOld494/restoreNew371ms），30000行表比较已完成；最后一条完整进度为 elapsed55799ms / frame1133 / phase8 / cellsChecked15341。不能把4个局部耗时作为整轮通过或收益结论。进度明确显示夹具逐格 scalars+canon 和每批双日志/帧间调度仍太贵，本次不再用无结果推断生产函数卡死。

03 继续仅改验证器：先由实际 `describeType(Tile)` 和完整生产 `NativeRoomState.scalars(first)` 核对字段清单。必须是准确 `fe.loc::Tile`、sealed、无 getter；声明中的所有原始类型字段均检查，生产 scalars 的每个输出字段必须被包含，唯一额外的非有限字段必须为 optional=NaN；仅有的对象字段必须为 door/trap。每格检查旧/新实际构造类、全部原始类型字段（严格相等，NaN双方为NaN才相等）、Tile/door/trap各自在恢复前后的身份。sealed且每格为同一构造类保证实例不能增删字段；没有依靠首格值去猜其余格的字段集合。此检查比原 scalars/canon 对非有限值和对象引用的覆盖更强。

完整表的全部非rows表头仍用原canon比较；每一行的长度、每一元素按原序严格比较，不再为每行生成字符串。3轮仍各检查30000行、30000格、每格全部字段及各30000次回调；结果额外列出 scalarFields/scalarValuesCompared/referenceCellsChecked，检查数量必须完整。64项小用例仍走原 scalars/canon，保持原异常、回调顺序及非法表覆盖。没有改旧/新生产类、待测调用或时限。

进度现仅在阶段变化、距上次至少1秒，或异常/最终完成时写盘/trace；不再每帧两次。03 尚未编译或启动，本代理只做离线完整性检查。
