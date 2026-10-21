# recovery14 BinaryMessageCodec 只读审查

结论：**没有发现同一包先做 JSON 往返、再重复 normalization 的路径，也没有本轮可安全省去的完整遍历。建议停止这条局部优化方向。** 确有跨消息重复整理同一批轨迹历史，但安全省去它需要另建不可变数据/失效规则或调整发送内容；这不是当前许可范围内的小改。本次没有实现、编译、运行或新夹具。

准确输入为 [recovery14](../../build/m52/recovery-14/)（SWF `225a794040c71f2a55ff433366a7969201ac3a58ffaab0a655cee1e4eefbe5f7`）。[profile-14-01.json](../recovery13-density-review/profile-14-01.json) 的 a6a7e27789 主侧 2318 个 CPU 样本中，copy 包含 311、叶 220，已独立读回核对。它证明该方法值得关注，**不说明 220 个样本都在数字转换、不提供具体字段/消息的访问次数，也不等于可节省的 CPU 或 FPS**。源码及证据 SHA-256 见 [inputs.json](inputs.json)；14 的 codec 与 13 字节相同。

## 实际发送链

- [Session:1203](../../build/m52/recovery-14/src/rconnect/core/Session.as:1203) 每网络 tick 采集玩家状态并广播 worldstate；[GameBridge:655](../../build/m52/recovery-14/src/rconnect/game/GameBridge.as:655) 生成普通字段对象，调用完整 `capture(gg,true)`。`Protocol.make` 与 `RoomSync.stamp` 只补字段；没有预先 normalization。
- [TcpLink:65](../../build/m52/recovery-14/src/rconnect/net/TcpLink.as:65) 协商成功后直接 `BinaryMessageCodec.pack`；[codec:17](../../build/m52/recovery-14/src/rconnect/net/BinaryMessageCodec.as:17) 只有一次递归 `copy`，随后原生 `writeObject`。后者是 AMF 序列化，不是第二次 JSON 数字整理。仅 pack 返回 null 时才走 JSON 回退；现有采样没有证明大量回退。
- [HostServer:100](../../build/m52/recovery-14/src/rconnect/net/HostServer.as:100) 已在发送前把接收者自己的 snap 置空，保留名单。双人场景不会把加入者刚解码的整份玩家轨迹再编码回本人。`hasObserverOtherThan` 也已避免单加入者上传触发额外即时广播。这两项不能再次作为“新优化”。

## 真正重复的部分与边界

[UnitPresentation:189](../../build/m52/recovery-14/src/rconnect/game/UnitPresentation.as:189) 的完整 capture 每次把 `shot.frames` 引用放入新 envelope；copy 每次再走全历史。单条保留上限 64 点，每点 10 个数值字段；在 50 ms tick 且达到上限的理论情况下，仅这一条的 frames 就有约 12,800 次标量访问/秒，**这是源码上限推算，不是实测本轮负载**。敌人的 200 ms unitsync 同样是完整修复；50 ms enemyMotion 已用增量。后者与完整修复重叠的点是有意重复，并非先编码后丢弃。

不能仅按对象身份、时间戳或“上包验证过”跳过：`observeWeapon` 的 [167 行](../../build/m52/recovery-14/src/rconnect/game/UnitPresentation.as:167) 会替换同 stamp 最后点，数组还会 push/shift；`captureEffects` 明确支持该修订。相同源对象也可以出现在两个字段内，当前 copy 会展开成两个独立子树；直接复用 normalized 子树再 `writeObject` 会生成对象引用，接收端 [codec:107–115](../../build/m52/recovery-14/src/rconnect/net/BinaryMessageCodec.as:107) 明确拒绝这种 wire。clone 缓存树仍要完整遍历/分配，收益没有证据。

## 快路径判断与反例要求

现有 copy 已先处理 null、数值、字符串与布尔，标量不进入 Dictionary；int32/uint32 已直接返回，只有其他有限数值做 `Number(String(value))`。不能把它改成原值直传：历史已实测 `110.39999999999999` 在原 JSON 接收为 `110.4`，严格相等比较确会改变；见 [原始开发记录](../../state/a22-motion-2026-10-15.md:124)。不能凭数学上的“整数可精确表示”把快路径扩到所有双精度整数，AIR 格式化等价须另证。

若未来重新开启 codec 修改，至少保留以下精确反例，而非 epsilon 比较：

| 候选简化 | 必须不变的反例 |
|---|---|
| 数字直通/更宽整数范围 | `-0` 的倒数符号、int/uint 边界及邻接小数、上述 110.399…、NaN/±Infinity、超 32 位整数与极小/极大有限数 |
| 复用旧树/省掉重复引用处理 | `{a:child,b:child}` 必须得到独立子树；`child.self=child` 必须拒绝；同身份数组内容/末点同 stamp 修订必须发送新值 |
| 跳过对象或叶节点检查 | 深度 64/65（即使最后是标量）、typed object/ByteArray/Date、空键；数组中的 undefined/Function→null，普通对象的相同值须被省略 |
| 改为直接 AMF 写入 | 接收端仍拒绝引用/typed/externalizable，保留 UTF-8/Unicode边界、1 MiB 限制和完整结构校验；不能只比较普通玩家包 |

旧 A39 已做过两条相近实验：[记录](../../state/a22-motion-2026-10-15.md:238) 中直接写 AMF 在 Unicode 等价上失败且无收益；Dictionary 改祖先数组虽通过局部功能，也无收益。这是旧证据，不冒充 14 的新实测，但足以避免原样重做。当前也没有分配归因能证明去掉两个 `Number(...)` 强转或展开标量递归值得增加实现分支。**保留当前 codec，下一步应依根会话已有加载 CPU 结果处理实际长帧，不再为本方向增加候选。**
