# 墙痕重复解码：独立源码候选

基线为准确 `build/m52/recovery-02/src`；只覆盖 `rconnect/game/WallImpactVisuals.as`。不修改 integrated、冻结构建、安装版、发送频率、协议、快照修复或墙面效果。本候选未编译、未运行 AIR，不能称性能已经改善。

## 证据与限制

- `Session.as:1066–1086` 每约 200 ms 在单位快照附带 `readWallPaint()`；`WallImpactVisuals.snapshot` 轮转已有 cells；无变化时 `packed(c)` 直接返回之前的 `c.wire`，故其 `d` 字符串不变。接收 `decode` 先解压，之后 `put` 才按 incoming 版本跳过旧单元。
- a9441a62e1 全轮日志（不是只取首轮）：加入侧 2,494 次 `decode-stages`，`total` 合计 4,338 ms；其中 2,493 条没有 key。主侧 43 次、90 ms，均无 key。这些数组编码没有房间 key，符合墙痕路径，但日志未记录调用栈和 `d`，不能将全部次数直接算为同 payload 缓存命中。
- a944 的 8 条 REMOTE TRACE 没有 wire 字段，仅有 end/frames/info/result/role/round；当前新增 wire 观察器也只记录武器事件与轨迹 samples，未记录墙痕 `d`。因此现有实机日志不能证明两次编码逐字相同。组件会用真实 snapshot 和 BinaryMessageCodec 往返证明无变化路径的重复，并比较旧/新实际解码次数；该组件尚未运行。
- `RoomCodec.unpack` 每次成功后调用两次 Log.d；Log.d 每次同步打开、追加、关闭 FileStream。`timing.total` 在第二次 Log.d 前取值，包含第一次日志写入，不能把累计 total 称为纯解码 CPU，也不能直接当节省量。

## 改动与安全边界

缓存键是完整的 `d` 字符串，命中还核对 `cached.data===data`；不是坐标、版本或摘要。只缓存完整验证后的纯数字 words。保留原本对数值字符串、布尔和嵌套数组的 Number 转换兼容，但这些值不缓存。存入和返回各有独立数组，调用方不能破坏后续复用值。

外层批次/坐标/重复键/编码累计长度校验每次仍执行，版本过滤仍在 put，畸形 payload 仍使整批不落图。未命中走准确原 RoomCodec，1M 编码、16MB 解压、单 cell 3200 words、64 cells/48K 字符网络上限、1200 cells 检查点上限均保留。成功命中不再次解压已经通过这些验证的相同字符串。

FIFO 最多 64 项、32,768 words、131,072 编码字符，任一达到即淘汰；reset 清空。缓存全局有界且不保存房间引用；换房的每次输入仍根据当前房间重新检查坐标。没有修改 protectedPixels 自用的解码和其他 RoomCodec 调用。

仍需实测净收益：持续变化或循环超过容量的密集单元可能频繁淘汰，未命中比旧版增加类型检查与一次数组副本，不能仅由重复路径推定总耗时下降。命中仍复制 words，以保证调用方不能修改缓存；本方案没有以共享可变数组换取更高跑分。

未另外移除日志：缓存命中自然不再重复解码和写那两条计时日志；缓存未命中、错误和房间 checkpoint 诊断保持原样。若实际命中率低，单独给墙痕解码加默认保留诊断的静默选项可再评估，不能在本候选冒充已验证收益。

## 组件与复核

运行 `prepare.py` 仅生成文本覆盖、真实类前后副本及来源清单，不启动 JVM/AIR。`check_static.py` 校验真实方法来源、所有未改方法、外层检查逐字保留和容量夹具。入口为 `components/RecoveryWallDecodeChecks.as`，正常路径预期 **120 条断言，执行数 0**；后续由主会话登记串行编译运行，读取独立 `result.json`。

WallBefore/After 是完整生产类，只改类名、开放 private decode 供检查，并给 After 暴露只读统计；真实 RoomCodec 只插入一次调用计数，真实 BinaryMessageCodec 不改。Log 使用内存替身，GameBridge 仅提供 probe，原生房间用小 BitmapData 网格。因此可验证真实解码/落图/快照语义，不包含真实 TCP、游戏绘制和磁盘日志性能。

检查包括：重复相等、同 v 不同 d、相同 d 新坐标/版本、等价数值但不同编码、畸形/超限/重复键、已热缓存仍校验外层、非数字兼容值不缓存、修改返回值不污染缓存、reset/回房、三个独立容量上限及淘汰后再解码、同版本仍不落图、新版本正确落图、整批失败不部分写入，以及真实 snapshot 经 BinaryMessageCodec 往返仍得到相同 d。不放宽原比较和限额。
