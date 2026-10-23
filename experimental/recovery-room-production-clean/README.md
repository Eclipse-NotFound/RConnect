# 生产候选：移除共享 RoomCodec 的逐次计时

只准备源码和组件。未编译、未运行 AIR、未部署，211 是计划断言数，不能当成已通过。

## 准确输入与唯一生产覆盖

来源 `build/m52/recovery-room-production-03/src/rconnect/net/RoomCodec.as`，SHA `549dbffadf05547509a0c2fe8a3637c0ef089305ebe7637322e6a196c471828c`。

新覆盖 `src/rconnect/net/RoomCodec.as`，SHA `bd98187fb1201c118f4980a3a93e3a06b0ebed28ba1cfc1be8661dcb33762570`。仅删除 getTimer/Log 导入、pack/unpack 计时对象与时钟写入、四条计时日志。没有增加诊断开关，没有改 JSON、ByteArray 压缩、base64、长度限制或紧凑地形表。compact/sparseRow/expand 部分与准确旧源逐字符相同；源文件行尾统一为 LF。`source.diff` 给出全部生产差异。

删除原因：墙面命中像素也用 RoomCodec。旧 pack/unpack 各写两条同步文件日志；这不能进入高射速墙痕的正常生产路径。此改变消除该开销，不等于已经证明整体流畅或提升了多少性能。

注意输入边界：旧日志直接访问 `o.key` / `result.key`，对 `pack(null)` 或解码得到 JSON null 会附带空引用异常。删除日志同时去掉此诊断副作用；没有为保留副作用而新增任意协议限制。生产正常 checkpoint 与墙面数组、显式非法 wire/尺寸/字段表拒绝路径保持。不要声称任意不受支持输入的全部异常行为完全一致。

## 复用组件

复用 `experimental/recovery-codec-diagnostics/components/CodecDiagnosticChecks.as` 和其 result.json 输出框架，历史原测试 199/0 的实际回执在 `build/m52/recovery-codec-diagnostics-component-01`。历史结果不替代本次。

本次入口 `components/CodecCleanChecks.as`，计划 **211 条**：34 组 × 6 条 transport 检查、1 条真实 NativeTileState 捕获检查、5 条非法输入拒绝一致、1 条旧格式读取一致。

- 旧类 `CodecBefore` 是准确 roomfix3 全类仅重命名；新类 `RoomCodec` 与新生产覆盖字节一致。两者没有算法替身。
- Log 仅替换磁盘边界以数调用；检查旧 pack+unpack 共 4 次、新类 0 次。组件不测真实磁盘性能。
- 每组检查压缩字符串逐字相同、全部还原字段相同、旧新交叉解码、输入未改；含空/稀疏/完整墙格、24 次连续墙格、4 类旧稀疏地形 schema。
- 新增准确 roomfix3 的完整 NativeTileState 与 NativeRoomState，复用已有 terrain-loop 的 fe.loc.Tile 及邻接接口夹具。真实 capture 生成 v2 table；v1 表把坐标默认值展开为显式 row 再移除 grid，测试旧格式 transport。Tile 是声明夹具，未加载原生游戏。
- `component.diff` 说明从旧检查入口的变化。删掉旧 timingEnabled 模式断言，换为交叉解码，不恢复计时开关。

根会话沿用现有受监控组件执行入口，参数为：

```text
--source experimental/recovery-room-production-clean/components
--entry CodecCleanChecks.as
--output build/m52/recovery-room-production-clean-component-01
--expected 211
```

原基础工具是 `tools/validation/run_recovery_component.py`；编译也应使用根当前的受监控包装，保留共享队列、1 GiB 启动/512 MiB 运行保护，不因此启用新的执行框架。`prepare.py` 只生成文本，运行一次即冻结源清单；根已拥有实际构建、AIR 与最终合并职责。
