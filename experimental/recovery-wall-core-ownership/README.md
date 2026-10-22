# 核心像素归属：停点与完整类反例

本目录只保存反例源码和接口风险说明。**没有生产覆盖、宿主补丁、编译或游戏执行；停止继续扩展发布协议。** 阻碍是改动的设计成本和安全责任，不是权限。

基线准确 `build/m52/recovery-18/src`（RC18 / `11b795d0…e4d3`），宿主准确 ACC / `acc336b5…535dfd`。组件沿用已经实际通过的 69 项完整类检查，五个相关生产类与准确18逐字节一致；Grafon 仍是既有组件的原生调用顺序替身，绘制本身由 fillRect/tint 表示。新增四种序列共 8 个检查，不替换原断言，不假装执行原生枪击。

使用实际完整 crop 运行 `386a671a97` 第 7 击的坐标 `(664,4463)`、400×400 缓冲、左边缘原点 `(280,4120)`、核心原点 `(600,4120)` 和实测色 `FF676861 / FF666861`，固定“有差异的 gutter 先处理、core 后处理”。原生该轮的第一个副本恰与 core 相同，**本组件有意交换了枚举先后，用于确定反例，不能反推旧失败的确切调用顺序**。

新增序列：

1. 先采到错误 gutter，原生 core 有正确色；检查 `raster` 前正确原生色与 `raster` 后结果。
2. 原生 core 本次没有变化；检查临时 gutter 是否被撤回，不能仅比较新的差分。
3. ACK 后收到较新的不同色队友像素；旧 native 重建仍必须尊重它。
4. ACK 后收到较新的同色队友像素；即使颜色恰等于旧 gutter，权威屏障也必须保留。

准确18预计 77 项中只有前两条“desired”失败；另外 75 条包括原 69 条保持通过。**这是静态预测，尚未执行；运行结果必须原样保存，出现其它失败不能归入预期。** `ownershipObservations` 保存原生重放前、重放后、最终 BitmapData、逻辑状态的准确 uint。这里特意不增加完整宿主路径、另一套模型或额外诊断框架。

父会话如需要执行，复用现有串行组件入口，在 `mods/RConnect` 下：

```powershell
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/recovery-wall-core-ownership/prepare_checks.py
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 tools/validation/run_recovery_component.py --source experimental/recovery-wall-core-ownership/components --entry WallSurfaceChecks.as --expected 77 --output build/m52/recovery-wall-core-counterexample-01
```

原 69 项实测：`build/m52/recovery-wall-color-integration-component-01/component-result.json`。本目录不重复执行，也不改旧结果。先前18两次精确失败仍成立；386a671a97本次四轮最终 uint 全部一致也原样保留。剩余极少数单通道一级差异没有被关闭，更不能与用户的主要缺失及长帧问题混作已经解决。无整体性能或发布资格。

具体可达链与停止原因见 [interface-risk.md](interface-risk.md)。
