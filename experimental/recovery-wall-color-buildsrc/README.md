# recovery18：仅原生墙面最终写色校正

准确已编译 recovery16 `A1519B39…5A31C` 为底；90 个 AS 文件，原 89 个中 87 个逐字节保留。唯独 `WallSurfaceBridge.paint/replay` 两处 `setPixel32` 最终入参调用 `NativeWallColor.setter(color)`；新增助手采用已实际测试的 LUT 原字节 `0F716045…FA842`；入口版本改为 `0.2.24-recovery18`。逻辑状态、线包颜色、covered/gutter 选择、Grafon 与原生 driver04 均不改。

采用主会话实际执行的 `recovery-wall-color-component-02`（10 / 0）：65,536 个原生可观测 ARGB，新助手零差异，直接写入有 5,886 个回读变化。公式版 component01 的 6 / 10 失败保留，未引用失败公式。LUT 按实际 AIR 生成每个用到 alpha 的 256 项反查表，最多 256 张小表，不缓存房间或图片。此处并不声称解决 opaque 色差，必须以同 driver04 严格重测。

## 组件范围

原 `recovery-wall-surfaces-component-01` 冻结的完整 54 项组件逐字保留，含真正完整 WallImpactVisuals、WallSurfaceBridge、两种编码类，及原已说明的五个 Grafon 方法抽取/绘图夹具边界。只覆盖 bridge 两处和新增助手；所有其它组件源逐字节不变。

末尾追加 15 项，合计 **69 项**：

- 六个实际失败颜色，分别核验两个重叠 buffer 的精确 uint（6 项）。
- 同六个颜色在非驻留块重建/replay 后逐 uint 相等（6 项）。
- 线包与 checkpoint 仍保留原 ARGB（1 项）。
- 重复同版本接收不重复写入、不增 revision（1 项）。
- 相邻未命中背景像素保持（1 项）。

不把组件通过当作实机流畅或完整游戏资格。本目录没有新执行器，继续使用共享串行登记入口。助手和完整集成组件是两次不同证据，不能相互冒用。

## 顺序与命令

首先只准备文本，尚不生成正式 `integration.json`：

```powershell
& $py -B -X utf8 experimental/recovery-wall-color-buildsrc/prepare_sources.py
```

由主会话运行实际组件，本代理不运行 JVM/AIR：

```powershell
& $py -B -X utf8 tools/validation/run_recovery_component.py --source experimental/recovery-wall-color-buildsrc/components --entry WallSurfaceChecks.as --expected 69 --output build/m52/recovery-wall-color-integration-component-01
```

通过后绑定实际 receipt、原 54 项顺序/结果、全部组件源码及 Checks.swf 指纹，才生成正式集成入口：

```powershell
& $py -B -X utf8 experimental/recovery-wall-color-buildsrc/prepare_sources.py --finalize build/m52/recovery-wall-color-integration-component-01
& $py -B -X utf8 tools/validation/prepare_recovery.py build/m52/recovery-18 --source experimental/recovery-wall-color-buildsrc --version 0.2.24-recovery18 --build --registry-wait 900
```

准备/绑定脚本均不启动编译器、不启动游戏、不部署；拒绝覆盖已有源码或已有正式 integration。`--verify` 只核对冻结输入、差分边界和组件副本。所有生成物仅在本实验目录；正式编译仍由原入口负责。`source-plan.json` 中的未执行状态是准备时快照，实际通过后以新 `integration.json` 的组件绑定为准。
