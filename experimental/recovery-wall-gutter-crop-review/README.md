# 386a671a97：当前完整crop通过，原生副本同色假设不成立

准确18+ACC，原框架与完整crop诊断通过，根会话独立四轮uint复核全部精确。原PNG表示误拒以及以前实际失败均保留；本次不提供性能或最终发布资格。

完整读取round2的9组源快照，每组16384个core像素、43264个含重叠副本像素。baseline及前6击完全一致；第7击世界`(664,4463)`的core是`FF666861`，两个左侧gutter是`FF676861`；第8击分别是`FF656761`与`FF676761`。本轮可确证原生分块副本会产生不同uint，不能再假定任取一块都等于实际显示的core。

该点首个观察到的副本是`(600,4440)`的上侧gutter，顺序25，恰好与core `(600,4120)`顺序33同色；错误色来自较后的`(280,4440)`/`(280,4120)`，顺序55/58。真实wire v19/v22携带core正确色，对侧同事件处理后所有4块也正确。整个crop的43消息、127cell、22个版本均可匹配源core快照，接收写后216832次像素比较零差异。

`review.json`保存全crop差异、原消息版本匹配、写后检查以及该点完整时间线，并绑定准确输入哈希。没有改任何原结果。观察顺序不是原生回调内部断点，故此前错误像素尚未完整归因；本轮也没有传错或写错的首次时刻。

## 确切风险与最小方向

`WallSurfaceBridge.onNative("before")`先从当前bitmap取色并扣除`entry.covered`；`"after"`将整个采样矩形加入covered。ACC的`Grafon.sceneApply`按`sceneChunks`枚举逐块画并触发这些回调。因此先遇到边缘时会封住后面的core。此次先到边缘恰巧正确，没有触发产品失败；但已有实际不同颜色可建立确定的完整类反例，检验结果是否受枚举顺序影响，无需继续扩充原生夹具。

不能把所有bitmap都简单内缩40，也不能在每次命中时新增全场景扫描：

| 原生路径 | 真正有效输出范围 |
|---|---|
| `sceneApply` 实时修改 | 当前resident entry的可见core；仅有边缘而core未加载时须保留临时信息 |
| `sceneRender → sceneDrawRegionChunk` | 尚未发布的单块core，draw结束后clone到entry |
| `scenePreloadAll` | 3×3 scratch中实际将复制到新entry的多个core，不能当成一块320方格 |
| `scenePreloadRegions` / 区域局部预载 | style的实际复制clip与目标entry core交集；scratch尺寸/原点不固定 |
| `sceneAdvanceWarm → sceneDrawSteps` | job目标core与最终保留的group clip交集；第一group可暂画全bounds，后续组会覆盖，不能把中间scratch当最终core |

建议的有限修正是由宿主回调额外给出上述有效区域元数据，不改变绘制；RConnect把“正式core已取到”和“临时gutter已取到”分开。缺core时仍保留临时信息，不强制draw；真正core之后到来必须能够修正临时像素，包括`fresh==old`但此前gutter曾多报的像素。现有born/paintOrder继续保护更新的本地/对侧痕迹。异步warm的有效clip须扣除后组覆盖范围，场景保存/恢复也必须保留该上下文。只改变颜色的来源优先级，不更改wire、ACK、像素写色或伤害。

先做有意义的完整类反例：实际第7/8击颜色按gutter→core与core→gutter两种顺序；core不变而gutter变化；core未加载后正常补绘；同一mark跨core；批量scratch多core与分区覆盖；旧mark的core迟到不能覆盖更新peer ink。反例通过且原组件保持后再决定新隔离覆盖，不直接改18/ACC。目前没有生产修正。
