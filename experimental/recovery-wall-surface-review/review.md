# 大地图持久弹痕：recovery14 只读审查

**确认存在实质同步缺口，不能用普通枪火星测试通过关闭。** 下述是准确源码与既有原生记录的交叉核查，尚未运行大图双侧弹痕像素反例；未改生产、宿主、其它模组或旧结果，未运行 AIR/JVM。候选为 recovery14 / `225a7940…be5f7`；宿主为隔离 FD92，检查的 5 个相关方法与其 E159 before 源字节相同，不是首绘等待补丁引入的新机制。

## 确定的错误链

1. [Grafon.drawLoc:3598](../../build/m52/recovery-first-raster-host-03/import/fe/graph/Grafon.as:3598) 对超出普通房尺寸的 Location 使用 sceneOpen。分块真实前景是 `sceneSurfaces()` 返回条目的 `nativeBuffers[0]`；条目保存世界原点 x/y、side、gutter、revision。`sceneRender` 将 scratch **clone** 为独立显示画布，二者不是同一 BitmapData。
2. [sceneApply:1087](../../build/m52/recovery-first-raster-host-03/import/fe/graph/Grafon.as:1087) 将 frontBmp 临时切换至各条目画布，并设置 sceneX/Y；实际 decal 在该坐标环境中绘制。finally 将 frontBmp 恢复为 sceneScratch。原点可能为负 gutter，不能把世界像素直接当成局部坐标。
3. [WallImpactVisuals.front:98](../../build/m52/recovery-14/src/rconnect/game/WallImpactVisuals.as:98) 只返回 frontBmp。before/observe 比较的是 scratch；region 又按 scratch 宽高裁切。远处命中区域通常根本不进入比较；近处也不是实际显示的弹痕。scratch 被新块绘制复用时还可能被误认成同一前景内容变化，存在误采样风险，尚无运行级触发证据。
4. [decode:277](../../build/m52/recovery-14/src/rconnect/game/WallImpactVisuals.as:277) 额外拒绝 `x*40>=1920 || y*40>=1000`，所以合法大图 x≥48 或 y≥25 的格子会令整批拒绝。put/replay/redraw 同样只写 scratch；即使取消坐标限制，也不会正确更新显示块。
5. 大图原生通过 sceneMarks 在新块绘制时恢复本机痕迹，而收到的稀疏像素没有进入该历史。只改当前驻留块一次，后续淘汰/重建仍会丢失远端弹痕。`sceneDrop` 会 dispose 原画布，不能长期持有它。另有 checkpoint 1200 格上限，必须继续明确处理，不能借支持大图移除防护。

**瞬时火星是另一条链。** `BallisticImpactVisuals.play` 调用真实 Emitter；能量/爆炸走各自 Part/显示对象采样，均不是上述 frontBmp 像素通道。持久弹孔、擦除/焦痕由 WallImpactVisuals 负责。因此“火星正常但弹痕不一致”完全可能；这次代码审查也不授予所有大图粒子运行资格。

## 已有测试实际覆盖

| 证据 | 实际覆盖 | 不能证明 |
|---|---|---|
| recovery05 普通枪 `4c2df11055`，主106/0、加104/0 | 原生 Part 火星/血粒子 14 轮。主 WallBlend.log 15 次、加 11 次心跳全部 `display.largeScene=false,sceneChunks=0`；虽 autoTravelLand=random_mane 且 CS 已加载，实际不是合并大图 | 持久弹痕、大图块、坐标偏移、重建 |
| driver10 的四个墙击入口 | EnergyImpactTestDoc 观察 Part/显示对象和像素；没有 `sceneLarge===true` 准入、没有 nativeBuffers 持久像素比对 | 编译/已有小图通过不能扩为大图通过 |
| 历史持久弹痕 `1a257a900d`，主59/0、加59/0 | 旧 final-presentation-29；普通 random_mane 房 `0,4,0→0,0,0→0,4,0`。驱动直接读取 frontBmp，检查真命中、像素、重复包及重访 | 不是本轮14/FD92；没有大图表面取证，不能为分块路径背书 |
| wall-encode 组件 | 普通 BitmapData 替身、48×25 坐标边界及旧新编解码等价 | 没有 sceneSurfaces、scratch/显示块分离或 gutter；组件通过不包含大图支持 |

直接证据位于 [主侧 WallBlend.log](../../build/cooperation/4c2df11055/module-logs/host/WallBlend.log:4)、[加入侧日志](../../build/cooperation/4c2df11055/module-logs/join/WallBlend.log:4)；精简计数与输入 SHA 见 [evidence.json](evidence.json)。注册“192×75 native land”的 CS 启动日志只表示测试地图注册，不能据此认定当前 random_mane 已合并。

## 推荐最窄方向

**推荐隔离宿主提供局部实际绘制的前后回调，RC 继续只发送变化像素。** 纯 RC 每块 clone 基线虽然可借公开 sceneSurfaces 获取真实画布，却要增加驻留块基线内存和初载复制；还要处理块刚出现同帧即被击中、淘汰及重建，容易再次拖慢加载，不建议整块 clone 方案。

- 宿主仅在 `sceneApply` 每个实际受影响 entry 的绘制前后提供 Location 身份、实际 BitmapData、世界原点与 affected 交集；回调应包住 compact decal 的实际绘制，结束时 frontBmp 已恢复为该 entry。RC 保存局部小片，比较后沿现有 40×40 稀疏 cells/预测保护/ACK/版本链发送。**不传整个背景矩形，不用随机重放 decal 代替像素。** 两侧回调异常必须隔离，不得破坏原生 try/finally 或引入额外伤害。
- 接收侧经公开 sceneSurfaces 将世界像素映射到所有相交 `nativeBuffers[0]`（含 gutter 重叠），每个真实修改块提升 revision，并使 SATS 缓存失效。已查 WallBlend 的 SceneBlendCache 用 revision 决定重算；不能只改像素而不通知。该消费者仅按必要现源只读核对，未另行导出安装版。
- 保留房间级稀疏 cells；新块/替换块出现后、首次 RENDER 前重放既有像素。身份必须包含 Location 和具体表面对象，不能只以坐标当生命周期。普通房继续原路径；pending 首绘、破墙、失去房权、离房/复访与断开沿既有保护。
- **额外必查边界：命中处没有驻留块时，sceneApply 只记录 sceneMarks，没有实际像素可供该回调采集。** 后续 `sceneRestoreMarks` 首次真实画出它时，也须有局部前后观察出口或等价安全设计；只加 sceneApply 两个回调还不能宣称覆盖屏外命中。恢复旧本机痕迹与重放远端稀疏像素也须避免互相当作新命中。

这是局部表面适配，仍属中等工作量，不是去掉两个坐标限制的小补丁。所有宿主提案只放 RConnect 隔离目录，不写 CS 源或安装；先做最小反例，再决定实现。

最低真实用例必须明确断言 sceneLarge 和不同的 scratch/nativeBuffers：双向普通枪/速射等离子命中 x>1920、y>1000 的墙；跨 chunk/gutter 边界；两侧同时不同像素；屏外无驻留块命中后进入；移远淘汰再回、离房重访、墙被打穿；首绘 pending→完成及 SATS。逐例冻结原生真实 nativeBuffers 命中前后差异，对照远端**同世界坐标**及首次显示，不只数 Part。保留相同单人/双人初载与持续开火性能门槛，不能以功能补齐换明显回退。
