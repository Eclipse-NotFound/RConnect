# Opaque 色差与分块边缘：只读核查

基于实际 `f80b01a647`、准确 16 / ACC 回读与 driver04 证据。未改生产、未运行游戏。结论：**有具体采集优先级风险，但现有证据不足以证明该像素确由 gutter 差异造成。**

## 真实几何与时间

round 2 区域 `(576,4396,128,128)` 的 index 6737，世界坐标为 `(657,4448)`。实际 source host 的 baseline 和 final 记录中，四个 surface 均覆盖此点；记录顺序如下：

| 记录顺序 | surface 原点 | 像素在块内 | 属于 core 吗 |
|---|---|---|---|
| 0 | (600,4440) | (57,8) | 否，顶部 gutter |
| 1 | (600,4120) | (57,328) | 是，唯一 core |
| 2 | (280,4120) | (377,328) | 否，右侧 gutter |
| 3 | (280,4440) | (377,8) | 否，右上 gutter |

side=320、gutter=40、bitmap=400×400；core 为 `[x+40,x+360) × [y+40,y+360)`。四块均 staged，revision 全增加 8；当前证明文件只拼接各块 core，**未保存这四块重叠像素的分别读值**。

两端 baseline 都是 `ff75756c`。前五次可见颜色更新相同；随后源 host 在墙钟 1792627917747 观察 `ff4e4e46`，join 在 1792627917971 观察 `ff4d4d46`；最后 host 1792627918503 为 `ff43433c`，join 1792627919050 为 `ff42423c`。两端各自 display 与自己的 core 同值。准确序列在 `gutter-review.json`。

## 代码支持什么

- ACC 回读 `Grafon.sceneSurfaces`（403 行）和 `sceneApply`（约 1219 行）都 `for each` 遍历 `sceneChunks`。前者产生证明中的顺序，后者逐块绘制。证明没有在命中指令上记录实际枚举顺序，不能把前后列表当成逐条执行追踪。
- 16 `WallSurfaceBridge.onNative("before")`（约 83–95 行）用已有 `entry.covered` 从所有 affected 区域中扣除；`"after"`（约 98–113 行）把每个 `piece.world` 整片记入 covered。覆盖的选择不区分 core/gutter。
- 因此若第一个绘制块恰是记录中的 `(600,4440)`，这一个世界像素的初次值会来自其顶部 gutter；后面 `(600,4120)` 的 core 该点将被 covered 排除。**这条路径在源码中确实存在。**
- 宿主逐块以不同 bitmap 局部坐标渲染 decal；源码并没有保证各重叠副本位级恒等。因此不能因为 world 坐标相同，就把 first-covered 自动当成 canonical core。

## 证据缺口与最小补证

既有 `wire` 只保存 cell 的 x/y/v，不保存 words；proof 只存 core 拼图。所以现在无法确认第一次采到的 gutter 颜色是否为 `ff42423c`，也无法排除采集之后、接收写入之前的另一条路径。本轮 opaque setter 小实验已排除“单次 BitmapData setter 直接造成它”这一具体解释，但不排除其他操作。

如需继续，最小外部观察是只对 `(657,4448)`：在真实命中帧之后读取四个已存在 `nativeBuffers[0].getPixel32(localX,localY)` 并保存 surface 顺序、revision 与时间；同轮收到的 cell `(16,111)` 中只读解码 index 337 的真实 wire uint，另读对侧四个实际 buffer。不上生产 hook，不手写像素，不改变 source 源时间或抓取顺序。若首 gutter、wire、对侧同为 `ff42423c` 且 core 为 `ff43433c`，方能闭合本假设；否则保留失败并定位实际分歧。这里只提出观测点，未修改 driver04 或实施新测试。
