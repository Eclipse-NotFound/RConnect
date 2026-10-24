# roomload2：首绘等待路径中的两类地形循环优化

以准确 `recovery-room-first-raster-product-01 / 6D4655…5392 / roomload1` 为基底，只从已构建的 `recovery-room-perf-current-01` 逐字取回 NativeTileState 与 TerrainSync；入口仅改版本为 `0.2.24-roomload2`。其余 79 类不变，包括原六类 early 逻辑、GameBridge、RoomTerrainView。未引入预采集缓存、对象索引、单位复用或新测试框架。

- NativeTileState：调用内编译坐标/字段槽位计划、行号 Vector 去重，保留完整预验证、原算式、写入顺序、回调及不支持形状回退。无跨房缓存。
- TerrainSync：本地破坏观察对真正 Tile 只比较 phis/hp；完整宿主字段、checkpoint、协议、频率、预测、ACK和动态对象路径不变。这处不直接改变 restoreCheckpoint 的工作量。

准备脚本核真实 67/154 项组件结果、完整冻结源与 Checks.swf；两控制类只还原类名后均与 6D 对应源相同，154 项已同时包含优化 NativeTileState。旧 roomperf1 普通绘制路径未见整体速度收益，仍不部署、不改旧结论。本候选用于重新测 early 路径约 534 ms 的 terrain 恢复段；组件通过不等于新组合原生或性能通过。

本目录只保存三类覆盖、相对 6D 差分、完整 82 类预期清单和薄编译绑定。旧 first-raster 构建器保持原文件；内存中唯一文本适配将“正式 RC 必须等于编译基底”改为准确正式 `78C052…F4699`，编译基底仍严格核 6D，真实 installation() 不替换。适配差分与展开源码 SHA 记入 manifest。公开 source_check/recipe_inputs 绑定本目录的完整证明；原两条 Java、384 MiB 堆、1 GiB 开始/512 MiB停止、300秒单命令、登记、自有子进程回收、安装与源前后一致检查保留。

根会话从 `mods/RConnect` 执行；本次只准备/check，不执行 build：

```text
python -B -X utf8 experimental/recovery-room-first-raster-loop-current/prepare.py --prepare
python -B -X utf8 experimental/recovery-room-first-raster-loop-current/build.py --check
python -B -X utf8 experimental/recovery-room-first-raster-loop-current/build.py --build build/m52/recovery-room-first-raster-loop-product-01 --registry-wait 900
python -B -X utf8 experimental/recovery-room-first-raster-loop-current/build.py --verify build/m52/recovery-room-first-raster-loop-product-01
```

只读 API：`build.verify(absolute_output_path)` 返回实际 prepared 记录，并核实际 compile/SWF（若已构建）。无运行器、AIR、宿主修改或部署入口；实际新产物仍须与 roomload1 用同一宿主、驱动及输入对照。
