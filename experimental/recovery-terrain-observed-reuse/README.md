# 恢复后复用未变化的地形观察快照

唯一生产覆盖为 `src/rconnect/game/TerrainSync.as`，准确旧版是 early2 / D356483F…ACB3。NativeTileState 恢复 after 回调只计算一次格键；13 字段与旧 observed 相同就保留原对象，否则仍调用原 state。没有原地改快照，不改 base、全表验证、字段写入、setZForm、最终 opacity、dirty、reset/epoch、旧数组路径或其它生产文件。额外标量继续由原 NativeTileState 恢复，不能因13字段相同而略过。

`components` 同时编译完整旧、新 TerrainSync；旧类仅改类名为 ControlTerrainSync。NativeTileState、NativeRoomState 是准确 D356 原文件。闭包只有 Tile、Unit、RConnectUnitAccess、GameBridge、TurretDisplay 五个既有邻接替身；测试仅调用地形分支。Tile 是 sealed 字段及原 setZForm 的夹具，不是实际运行游戏的 Tile，不能授予原生游玩资格。

固定 50 个断言：20 个未变化/13字段/混合/额外标量/v1/可选空值/旧数组案例，4 个恢复后真实扣HP与报告、回执、销毁、保护和epoch流程，20 个非法输入与初始化失败后基线恢复，6 轮30000格完整 restoreCheckpoint 对照。前4轮相同数据，后2轮混合13字段改变；顺序旧新/新旧交替。整图验证覆盖全部声明标量（包括可选NaN）、Tile/door/trap身份、全部表行不变、恢复后无虚构伤害及权威差异保留。

计时只包围完整真实 restoreCheckpoint（包括reset/enter）；建图、采集、全量比较与日志在计时外，按8ms预算分帧。原生产调用仍同步。所有轮次原始计时均保留；没有“必须更快”的断言或性能合格结论。不稳定或无收益就停止，不继续合入。通用组件仍为原60秒时限、1GiB启动门槛，采用原编译模式（debug=true）；局部收益还需原生旅行验证。

准备/只读核验：

```powershell
python -B -X utf8 experimental/recovery-terrain-observed-reuse/prepare.py --materialize
python -B -X utf8 experimental/recovery-terrain-observed-reuse/prepare.py
```

仅根代理后续串行编译运行，当前尚未调用：

```powershell
python -B -X utf8 tools/validation/run_recovery_component.py --source experimental/recovery-terrain-observed-reuse/components --entry TerrainObservedReuseChecks.as --expected 50 --output build/m52/recovery-terrain-observed-reuse-component-01 --registry-wait 900
```

通用runner原样负责共享登记、冻结、编译、独立AIR、内存、安装22项校核和清理。此目录没有新增runner、游戏或部署入口。`prepare.py` 检查原manifest与三个完整生产源的准确绑定、候选仅一个回调差异、旧类仅改名、相邻闭包原字节及所有输出指纹。
