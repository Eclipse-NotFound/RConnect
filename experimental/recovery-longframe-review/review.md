# recovery19 长帧：只读复核

结论：**只确认一处尚未消除的同回调重复采集；没有证据支持它能让密集场景整体达标，也没有找到第二个可安全直接消除的主要热点。建议停止零散候选，不把网络积压当作已定位原因。** 本次无生产修改、编译、AIR 或新采样框架。

依据为 [14 的实际 CPU 采样](../recovery13-density-review/profile-14-01.json)（`a6a7e27789`，主 2318 / 加 1259 个 CPU 样本）与准确 [19 源码](../../build/m52/recovery-19/src/)。[inputs.json](inputs.json) 核对原两侧日志哈希，及以下链路 15 个方法在 14→19 字节相同。采样数是包含关系，不是调用次数、耗时或可节省量；19 只替换 base64 尾段的已有整体对照没有取得资格，不能拿 14 的 pack 热点宣称 19 已改善。

## 唯一具体候选：一次网络回调内共用敌人公共采集结果

[Session:1063](../../build/m52/recovery-19/src/rconnect/core/Session.as:1063) 先完整执行 `broadcastWorldState`，随后达到 200 ms 时再执行 `readUnitsSnapshot`。前者经 [readEnemyMotion:5502](../../build/m52/recovery-19/src/rconnect/game/GameBridge.as:5502)，后者经 [readUnitsSnapshot:5534](../../build/m52/recovery-19/src/rconnect/game/GameBridge.as:5534)，重新遍历同一 `loc.units`，再次读取活敌人的姿态、炮塔显示、燃烧、身体效果、六个运动字段与 grip。两次 `beginCaptureBatch` 还各自建立一次保留武器所属者索引。**这里是动作包与完整包的公共部分重复，不是每 50 ms 发了两次完整单位快照。**

实际栈支持关注这条路径：主侧 `readEnemyMotion` 包含 128、`readUnitsSnapshot` 包含 216、`unitFields` 包含 113 个 CPU 样本；有 `probe ← unitFields ← readUnitsSnapshot ← onTick` 的 26 个样本。不能把这些相加算收益：完整包包含 HP、伤害代理属性、死亡、完整轨迹等不重复工作，样本还互相包含。80 身体夹具在每次完整快照到期时最多重复读取 80 份公共记录；现证据没有该子集的独立毫秒或分配数。

若以后有理由投入，最小方向是**只在这一次同步调用内**保留第一次读取的公共结果，第二次采集用完立即丢弃；快速包仍先发、完整包仍按原频率发送。不能预先采完整包拖慢快速包，不能做跨帧缓存。仍须保留：

- 完整包对死亡单位及特有字段的独立处理；两条路径过滤条件并不完全相同。
- `captureEffects` 的增量游标/命中/爆炸、完整 `capture` 的终态与修复历史，不能互相替代。
- `readEnemyMotion` 的直接数值读取与完整快照 `numOr/probe` 默认值差异；未知 getter 的调用语义不能凭“同一帧”省略。
- 发送错误可能同步改变连接/房间状态；复用须限同一次 World/Location/单位身份，不能从上一轮取旧值。

因此这只是一个可证实的局部消重机会，**尚不足以作为新的主要长帧修复候选**；本次不建议据这些包含样本再起实现轮次。

## 其余两条怀疑未获证实，暂不实施

**不是双重序列化。** `TcpLink.send → BinaryMessageCodec.pack → copy → writeObject` 每包只有一次 JSON 兼容整理；原生 `writeObject` 是实际编码。主侧 copy 包含 311 / 叶 220 个样本，没有字段级证据能安全跳过。50 ms 玩家全轨迹、200 ms 敌人完整修复确有重复数据，但修改内容或缓存归一化树已经过[专门核查](../recovery-binary-copy-review/review.md)，不能在此换名重做。接收者本人快照也已在编码前排除。

**没有证实积压导致本轮长帧。** [TcpLink.onData:161](../../build/m52/recovery-19/src/rconnect/net/TcpLink.as:161) 的确同步解完全部完整帧并逐包派发，重回调后可能成批处理；现采样却没有足够 `onData/applyUnitsSync` 栈、积压包龄或队列长度，无法证明它是主要成本。加入侧实际更突出的是 `onMirrorFrame → tickFrozenAnims`（278）、RV `hideEnemies`（150）与 `WallBlend.onFrame`（187）；这些不是同一网络包的重复 apply。正常动画推进只有一次，暂停后的最终校正有明确脏标记，RENDER 的最终显示采集也承担原生帧脚本之后的修订。伤害收集在 Timer 与帧回调之间仍可能产生新命中，本体/命中代理仍各负其责，不能以“重复对象”为由删掉。这里不给出丢整包、改 ACK、删代理、跳动画或通用合批方案。

当前能下的判断是：主侧仍承担采集与编码，加入侧仍承担较重显示更新；**现有证据不能把它们归结为一个可直接删除的重复主循环。** 保留准确失败与可比性边界，等待根会话已经安排的准备修正后对照结果，不再新增微优化实验。
