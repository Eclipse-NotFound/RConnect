# seed 开关对照组件的依赖修正

原 `recovery-seed-gate-on-component-01` 因缺 `fe.inter.RConnectTravelAccess` 编译失败，未启动 AIR；原回执、43项静态结果和冻结 control 目录保持不动。这是夹具依赖误扩展，不能把原静态通过解释成编译资格。

逐文件比较实际109/0的 `recovery-seed-first-raster-room-01/src` 后，确认旧 control 生成器的 `actual` 集合误把两个替身换成完整生产类：

| 类 | 已通过夹具 | 误换生产类 | 本目录处理 |
|---|---:|---:|---|
| TravelGuard | 895字节 | 9385字节 | 恢复原替身；follow继续核对目标Land与roomKey |
| TravelPlacement | 151字节 | 1643字节 | 恢复原替身；显式写X/Y，供出生坐标断言读取 |

其余原17个文件中，仅 `NativeTravelRoomChecks.as` 是有意改为共用 on/off 的检查文档；本修正保持该文档逐字不变，不改变109项语义或7个最终状态比较。真实 RoomSync、FirstRasterGate、SeedRasterEntry、NativeTravelPlan、RoomEntryView 等保留准确13实现。World/Game、GUI入口限制和原生落点副作用仍属替身边界，须原生测试覆盖。

新目录每侧18个AS，和旧 control **仅以上两个文件不同**。全部差异见 `component-fix.patch`；原17项逐文件来源核对、旧成功/失败指纹见 `integration.json`。无生产或原生驱动修改，无编译/AIR执行。

根会话从 `mods/RConnect` 串行执行，Python替换本机已确认解释器；输出必须是新目录：

```powershell
python -B -X utf8 tools/validation/run_recovery_component.py --source experimental/recovery-seed-raster-control-fix/components/on --entry NativeTravelRoomChecks.as --output build/m52/recovery-seed-gate-on-component-02 --expected 109 --registry-wait 900
python -B -X utf8 tools/validation/run_recovery_component.py --source experimental/recovery-seed-raster-control-fix/components/off --entry NativeTravelRoomChecks.as --output build/m52/recovery-seed-gate-off-component-02 --expected 109 --registry-wait 900
python -B -X utf8 experimental/recovery-seed-raster-control-fix/compare_components.py --on build/m52/recovery-seed-gate-on-component-02 --off build/m52/recovery-seed-gate-off-component-02
```

比较入口要求两份真实回执通过、源与SWF指纹一致、各109条标签一致、7个最终状态逐字段相同。之后才继续旧 control 中已有的候选编译与同字节原生驱动；本目录不重新生成或覆盖旧 control 的生产候选、驱动或runner。
