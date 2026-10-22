# 大场景持久墙痕：隔离提案

2026-10-22。仅源码/组件准备；未编译、未运行 AIR、未部署。当前静态核对 28 项通过，组件计划 54 项，不能把计划数当运行通过数。

**准确输入**：RConnect `build/m52/recovery-14`（SWF `225a7940…be5f7`）；宿主使用 `recovery-first-raster-host-03/import/fe/graph/Grafon.as`（源 `976526e7…850d`），对应 FD92 宿主。完整来源与输出哈希见 `inputs.json`，不以短哈希作为构建准入。

交给主会话合并的最小差异：

- `WallImpactVisuals`：大图不用 `frontBmp` scratch/整块 shadow；原格式解码只取消固定 1920×1000 坐标上限，保留实际房间、版本、长度、重复键及词值校验；已接受像素写真实 `nativeBuffers[0]` 并更新 `revision`；普通房仍走原代码。
- 新 `WallSurfaceBridge`：只在原生局部实际绘制前后读取该区域；短期向量随此次回调释放，没有整图或整 chunk 备份。重建分块时只重放已保存的稀疏像素，不重新生成随机 decal。
- `GameBridge` **仅** `presentationNetworkActive` setter 增加 `_wall.networkActive=value`。不要用该整类覆盖较新的整合源。Session 的现有真实 peer 判断与频率不改。
- 宿主只改 `Grafon`：实际前景像素绘制的 before/after、原生 mark 出生和 raster 完成回调；区域样式传入真正参与合成的 clips；异步 warm 保存/恢复同一 clips 字段。公共 `sceneSurfaces()` 形状不变。`proposal.patch` 为方法差异。

顺序和生命周期：

- 同一原生 mark 用弱键标识；已观察的世界矩形不会因 gutter 或重建重复成为命中。原生 mark 没有驻留块时只登记，等原生真正画出后才取真实像素。
- 原生出生与“经过原版本/预测过滤的每个接收像素”具有本机次序。较旧、延迟首绘的 mark 不能覆盖较新的接收像素，**即便新接收颜色等于已有颜色**。这个次序只帮助本机迟绘合并，不上网，也不取代 wire 版本、待确认保护、ACK。
- 次序映射随原有稀疏 cell 删除/恢复；房间恢复换 lifetime，完整 reset 清除弱表、计数与旧 token。断开清除自身回调；旧 owner 不会清除后来 owner 的回调。重新启用以既有 sceneMarks 为基线，只观察随后出生的 mark。
- pending 首绘时接收只存逻辑像素，不写旧驻留块；真正 raster 回调仍能将像素画入当前原生输出。接收修改将 `dirty` 交还原有 SATS 更新入口。离线不注册回调，不新增绘制采样。

在 RConnect 目录执行源码准备/核对（不启动 JVM/AIR）：

```powershell
python -B -X utf8 experimental/recovery-wall-surfaces/prepare_components.py
python -B -X utf8 experimental/recovery-wall-surfaces/static_checks.py
```

由主会话串行登记后运行组件：

```powershell
python -B -X utf8 tools/validation/run_recovery_component.py --source experimental/recovery-wall-surfaces/components --entry WallSurfaceChecks.as --output build/m52/recovery-wall-surfaces-component-01 --expected 54
```

组件用真实完整旧/新 `WallImpactVisuals`、新 bridge、两个 codec，以及逐字提取的 5 个宿主方法（见 `component-inputs.json`）。替身边界明确为原生素材绘图、分块调度、Location、`GameBridge.probe`；使用实际 `BitmapData` 做像素对照，不包含 TCP、完整 CS 栅格、帧率或内存资格。检查覆盖双轴超普通边界、gutter、版本与畸形原子拒绝、未来块、局部纹理不覆盖、预测/ACK、迟绘新旧及等色顺序、区域 clips、破墙、reset/checkpoint、pending、原生异常传播、离线/监听拥有权，以及普通房旧新输出逐字段一致。

宿主构建/回读由主会话现有登记入口执行。输入为准确 FD92 二进制与 `native/fe/graph/Grafon.as`，只导入 `fe.graph.Grafon`；不写 CS 模组。保持既有 22 项安装输入前后相同、输入工具指纹、before/after 导出、非代码 tag/header/class list 与代表类不变检查。额外回读：

```powershell
python -B -X utf8 experimental/recovery-wall-surfaces/verify_readback.py build/m52/<new-host-output>/after/scripts/fe/graph/Grafon.as
```

此脚本只验本补丁锚点，并含删除 before/after、漏 origin 恢复、多余随机调用、丢 clips 的静态负例；不能单独充当宿主完整资格。没有生成可伪装为已编译宿主的 `prepared.json`。

必须真实验证：同字节外部驱动以旧14/安装宿主作反例，再用候选/新宿主；双向 lmg/plamg 在 `sceneLarge=true`、世界 x>1920 或 y>1000 墙面比较实际稀疏像素及首显时间；跨 chunk/gutter、混合区域样式、无驻留块的 mark、相机移出/返回、SATS、普通房、离线与密集开火。独立 native driver 由 `wall_impact_fix` 准备。离屏延迟取样和异步 warm 的真正显示时机，不能用本组件冒充实测。

保留的限制：每包最多 64 cells/48000 字符，checkpoint 最多 1200 cells；大地图长期打到超过 1200 个不同格后，完整 checkpoint 仍会被拒绝。此容量问题未解决，后续应单独处理分块与总量保护；本轮不扩大协议。每次真实 raster 会遍历该房间已保存稀疏 cells，实际开销及局部向量峰值必须在密集/大图实测，未作性能改善承诺。
