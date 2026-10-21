# recovery13 墙痕编码热点：独立候选，尚无收益结论

准确基线 `build/m52/recovery-13`，SWF `1177eb1a…ddb1`。只写本目录。生产覆盖为 **WallImpactVisuals.as + 新增 WallCellCodec.as**；不修改 RoomCodec、Session、GameBridge、伤害或其他模组。没有运行 JVM/AIR，没有安装或发布资格。

## 已核实的热点

原生 profile `3b8269a9a7` 主侧 2,689 个 CPU 样本，`packed` 包含 797 个，其中 `updates` 713、`snapshot` 84；JSON、压缩、临时数组及相关回收是实测路径，不把这些包含关系直接相加。[profile-review.json](profile-review.json)保存实际栈、原日志指纹和自然载荷尺寸。

`c.wire` 已有缓存。`captureCell` 先比较真实 BitmapData，不变则返回；变化后更新像素并清空 wire。`put` 仅实际像素值变化时清空 wire。`updates` 只选未发送的新版本，`sentUpdates` 在交给有接收者的 TCP 后推进；原快路/200ms轮转恢复不能拿掉。未看到可安全延长缓存的证据。`queued` 没有 v，原代码故意不缓存，不能把它套成长期缓存；排队越限的首个尚未选中 cell 可多编码一次，但不足以解释开火中的主要热点。

候选保留这套失效及运输逻辑，改掉中间的通用数字数组/JSON/UTF8 转换。还保留原有排序，避免本轮同时引入每格额外索引缓存或 1,600 槽全扫描。未更改解码缓存容量。

## 有限格式与兼容

新 d 字符串以 `!W1:` 开头（不会与旧 base64 冲突）。内容是 zlib + base64 的定长二进制：2 字节像素数，随后每点 2 字节位置、4 字节 ARGB，按位置升序。最多 1,600 点，解压有效数据最多 9,602 字节；压缩输入限 10,000 字节/文本 13,340 字符。空格、全透明、最大 uint 均有组件用例。

收到旧 d 仍调用原 RoomCodec；新 d 只在墙痕类读取。外层 x/y/v、全部位置/版本检查、整批先验证后写入、ACK、预测保护、毁墙、复访、轮转、64 cell 和 48,000 字符限额都沿用原实现。预测中的 pending 也改为调用统一的已验证像素读取，不能仍拿新 d 送进旧 RoomCodec。

每包能装多少格可能改变，这是允许的：组件要证明每批合法、剩余格最终送完、ACK 幂等、发送游标不提前消费，不要求新旧批次字节相同。老载荷可读不意味着旧模组能读取新格式；本候选双侧须用同版。

AIR 的 `ByteArray.uncompress` 无流式输出上限参数。这里先限制压缩输入，解压后在任何像素和 ACK 修改前拒绝超过 9,602 字节的结果；不能把这个事后界限说成原生 inflater 从不临时分配更多内存。没有扩大原房间解码入口。

## 证据与待测

- 历史 `5314f8125d` 的 **82 份真实自然墙痕/1,276 次已记录解码 miss 顺序**作为语义回放输入，来源和字节不变。它不是本轮走廊的载荷分布，也不是实际每秒编码次数。Python zlib 尺寸试算总文本 298,328 → 247,892 字符，只说明这个旧样本的尺寸，不说明 AIR 速度。
- 组件保留两份**完整实际生产类**，只改类名并增加私有方法访问包装；prepare.verify 会把包装剥离后核对精确原文。RoomCodec 是准确13原字节，不用替身计时。
- **49 项 AS 组件待执行**：自然字值/类型/次序与像素逐点一致、旧载荷/异常拒绝、独立数组、缓存与真实像素失效、预测/ACK/旧版本、整批原子拒绝、毁墙、复访、70格轮转、64格和48k拆分。接触场景使用真实 BitmapData 和 Bullet 名称的最小接触标记，不是已加载游戏的原生开火。
- 微基准按 **ABBA×2** 交替旧/新，每块 82 份×3次强制未缓存编码，并分别冷解码完整相同像素。实际 class 的排序/压缩/编码和读取都在计时内；输入构造、文件和缓存重置在计时外。输出每块 ms/字符数/校验和，不预设“新一定更快”；净收益须同时看编码与解码及包大小。
- 当前只有 [offline-result.json](offline-result.json) 的静态核对；没有 AS 结果，没有当前走廊真实采样。若微基准退化或新分批成本抵消编码收益，应搁置，不能为过门槛改变视觉/频率/限额。

主会话运行（新目录必须不存在；沿原登记、1GiB组件内存门槛、60s超时及22输入审计）：

```powershell
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/recovery-wall-encode/run_component.py --source experimental/recovery-wall-encode/components --entry WallEncodeChecks.as --expected 49 --output build/m52/recovery-wall-encode-component-01
```

`run_component.py` 仅让原通用框架把那份 JSON 也冻结/复制/核对，其余验证与执行不变。完整 AS 返回结果在 `component-result.json`，即使断言都过也保持 performance/net_gain_qualified=false，须人工审阅 ABBA 后再决定是否值得完整原生测试。

## profile 正则的误判

已确认主侧 RConnect.log 第86行、加入侧第249行都是 `PROJECTILE PROFILE` 的 JSON；匹配到的是 `allocations` 内 `ReferenceError` 类名及其分配计数，不是抛出异常的日志行。当前诊断审计的广泛正则会把两整行列为 module_errors。这里仅登记，不修改原运行结果、正则或失败计数；这也不能消除七阶段的真实帧数/耗时失败。
