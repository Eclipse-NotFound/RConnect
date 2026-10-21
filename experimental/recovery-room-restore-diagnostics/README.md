# 房间恢复耗时：独立诊断覆盖

基线：冻结`build/m52/recovery-07`，版本保持`0.2.24-recovery7`。这是增加计时的候选，**没有实现加载优化**；未编译，未运行JVM/AIR。07与后续08的墙痕缓存差异不在这里混合。覆盖文件和准确SHA见`inputs.json`。

`src`有9个既有类的稀疏覆盖，以及新增`RestoreCostTrace`。所有改动均在`RCRESTORE`标记块内；`generate.py`逐文件证明删除这些块后与冻结07逐字节相同。新增块只调用诊断函数、读已有局部快照值；`RoomSync`开始诊断时额外调用一次RC的纯读取`roomKey()`，没有重复构造、恢复、抓取快照、取地形或任何原生动作。值返回方法的try/finally末尾加了ASC所需的不可达返回，原返回路径不变。插入try/finally的真实编译行为尚待编译验证。

## 运行范围与输出

- 只在AIR ID以`pfe-modsettings-rconnect-coop-`开头时启用（已核对实际生成的descriptor）。先等`random_mane/`目的房间的有效ready/commit/grant，再记录该次和随后两次事务；不消耗初始rbl联机握手额度。与原scene12的马哈顿→rbl→马哈顿三轮对应，仍需实际核对日志。
- ready/commit/grant沿用同一epoch/barrier关联，记录已有key、角色、本机getTimer时间。`postGrant`在原grant/commit分支成功完成时记录。若事务被接替或原RoomSync错误处理触发，输出明确的不完整原因；原错误继续原路径处理。
- grant后从**下一个完整ENTER_FRAME**开始收集前三帧。每帧记录Stage优先级边界、真实RC回调时长、至多16轮RENDER边界；第四个ENTER_FRAME顶部才输出前三帧，日志开销不计进这三帧。grant所在半帧不冒充完整帧。
- 每个事务只写一行`RConnectRestoreCost {…}`聚合数据；原有checkpoint/restore/错误日志全部保留。单位仅在内存累加，类名计数最多64种；完成3条后移除诊断Stage监听器。若游戏在等待grant期间完全不再派发事件，不会伪造完成记录。
- `times`为各方法**包含子调用的累计时间**，不能直接相加；`preGrantTimes`/`postGrantTimes`按调用开始时间划分（getTimer只有毫秒精度，同毫秒归前段），每个`frames[n].times`另给该完整帧内的累计。`openScopes`或`scopeMismatches`非空/非零表示记录需审查。

## 拆出的成本

| 范围 | 字段及含义 |
|---|---|
| 房间事务 | `room.ready/commit/grant/present`；`codec.pack/unpack`保留完整协议，后3帧的codec也可能包含墙痕包，不能一律叫房间解码。 |
| 完整采集 | `checkpoint.total/unitSnapshot/objectSnapshot/unitRuntime`；原units、对象、掉落、矿、终端、地图点均保留。 |
| 单位清理/匹配/新建 | `restore.removeForeignUnits/pruneUnits`，`unit.resolve/classLookup/constructorXML/constructor/putLoc/addObj`；`unit.missing/resolved/created/removedForeign/pruned`与按类计数。 |
| 单位恢复 | `unit.restoreCall/restoreRuntime/restoreScalars/restoreInternal/pose/body`；`gun.constructor/restoreScalars`与`gun.visited/created`（完成时visited-created才可推算复用，异常窗口不能这么算）。 |
| 镜像首次显示 | `mirror.applyUnits/hitConstructor/maskPrepare/maskRegister`、`mirror.hitCreated`；`presentation.apply/gunConstructor`、`presentation.newState/gunCreated`。保留原来两个mask.prepare，未做消重。 |
| 地形 | `terrain.capture/nativeCapture/restore/nativeRestore/enter`；`terrain.viewCapture/viewCompare/viewRefresh`分别是保留原画面的预采样、等价检查和原生非栅格刷新。每格不插桩、不写日志。 |
| 掉落 | `restore.loot`包含原移除、ID重建与完整applyLootSync；无跳过/推迟恢复。 |
| 完整帧 | `frame.rcPerception/rcMask/rcMirror/rcView`直接包围RC方法，早退和异常也结束计时；Stage边界覆盖90000、0、-9000、-10000附近。 |

优先级边界只覆盖**同一个Stage的事件派发**。已只读确认原1.02的`MainMenu.mainStep`挂Stage默认优先级0；夹在+1/-1之间的其它同优先级回调也包含在内，不能称为纯World时间。显示树其它对象上的ENTER_FRAME、Timer/socket回调、GC、GPU显示、Windows调度及两个Stage事件之间的空档均不能直接归因。三帧是RC和Stage时间证据，不是像素呈现时刻或真实按键响应测试。

单个敌人会产生多次计时调用，getTimer及内存累计本身也有开销，记录是定位证据；不得拿此候选与无诊断solo作正式性能门槛对照。所有既有死亡/破墙/容器/唯一掉落/重访/分房路径保留，但“去插桩相等”不替代实际游戏回归。

## 构建与核查

只生成／复核本目录覆盖：

```powershell
python -B -X utf8 experimental/recovery-room-restore-diagnostics/generate.py
python -B -X utf8 experimental/recovery-room-restore-diagnostics/check_sources.py
```

根会话之后可调用（本轮尚未调用）：

```powershell
python -B -X utf8 experimental/recovery-room-restore-diagnostics/prepare.py --output build/m52/recovery-room-restore-diag-01 --build
```

默认去掉`--build`仅冻结新目录；原输出只允许随后首次编译，编译失败必须新目录。构建在登记表排队，使用07冻结tools，产物只在新build目录。`prepare.py`核对07全部源与工具指纹、10个覆盖以及原scene12全部冻结输入；后者只读不复制修改。没有游戏运行入口，不改测试门槛、加载耗时计算或安装版。独立诊断候选应交原scene12运行器，由根会话安排，并保留原22输入资格。

`check_sources.py`只核对原字符逐字节恢复、插桩新增调用白名单、Helper的无原生行为边界、关键计时覆盖和工具/驱动原输入；它不执行AS、编译器、注册表或游戏。
