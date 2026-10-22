# 普通房墙面颜色：隔离的两处最终写入修正

沿准确 recovery18 的完整组件，只修改 `WallImpactVisuals.put/replay` 的两次最终 `setPixel32` 入参，使用已实测的 `NativeWallColor.setter`。不改颜色数据、协议、预测保护、ACK、版本、采集、分块或调用频率。该原生颜色转换问题同时适用于小房的 `frontBmp`，不能仅修大图。

原69项组件全部保留；追加16项，含完整旧类复现五个半透明读回损失、六色接收、逻辑检查点、重复包、六色重建回放、邻接背景。只准备源文件不表示测试通过，实际回执另存 `build/m52/recovery-wall-small-color-component-01`。本目录没有独立游戏构建、宿主改动或部署。

运行 `prepare.py` 后，使用现有 `run_recovery_component.py --source experimental/recovery-wall-small-color/components --entry WallSurfaceChecks.as --expected 85 --output build/m52/recovery-wall-small-color-component-01`。组件不代表真实游戏性能或最终发布资格。
