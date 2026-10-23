# 独立问题：普通墙面坏压缩数据未被拒绝

状态：已复核真实失败和准确源码；只有独立修正草案，未编译、未运行、未与 ACK 快发合并。

证据是 `build/m52/recovery-ordinary-wall-ack-component-01/component-result.json`：前 6 项通过，第 7 项故意给 `d:"bad"`，`ByteArray.uncompress → RoomCodec.unpack → decodeWords → ordinaryDecode → ordinaryAck` 抛出 #2058，最终 6 通过/1 异常。原回执和原测试不变。

准确 C6A3 源的旧 large `decode` 在整个解析范围内 catch 并返回 null；新增 ordinary `ordinaryDecode` 直接调用 `decodeWords`，没有同样的拒绝边界。`RoomCodec.unpack` 的解压/JSON 异常向上传播；`Session.onLinkMessage/handleMessage` 以及 `TcpLink.onData` 的事件 dispatch 外也没有 catch，因此**不能称为原设计的自动断连行为**。这是普通墙面路径已有的坏载荷健壮性缺口，不是 ACK 快发改变解码造成；只有故意坏输入的组件证据，不推断正常联机已出现损坏包。

独立补丁仅从 C6A3 复制 `WallImpactVisuals.as`，在 `ordinaryDecode` 的单次 `decodeWords` 调用周围 catch `Error` 返回 null。其余字段/全表校验、版本检查、队列退休、绘制次序和 large 逻辑不变；不捕获整个 ACK 或绘图过程。坏数据仍被拒绝，不赋予成功资格，待确认批次和 queued 不应变化。未加入 ACK Boolean 返回或 Session 快发代码，`source.diff` 明确只有这个解析边界。

原 ACK 20 项的第 7 项“坏载荷不能开启 flush 机会”保持原标准；不把预期异常记成新合格契约。根可在独立修正审查后决定组合重跑：使用新输出保留 component01，逐项确认返回拒绝、pending 仍阻塞、后续有效 ACK 才退休、queued 像素仍完整。原 153 项也须保持，不因这次修正减少覆盖。尚未创建会把 #2058 当通过的 v2 组件。
