# 准确 21 版普通墙面写色：独立 85 项组件

准确基线为 `build/m52/recovery-21` / `9ac7ede757c253bbf61e0c44334870b4a95112f976c1b40f2f390822a8b7e7ba`。本目录只有一个生产覆盖文件 `src/rconnect/game/WallImpactVisuals.as`，它来自 **21 版完整类**，仅把 `put` 和 `replay` 的最终 `setPixel32` 颜色入参各包一层 `NativeWallColor.setter`。不改逻辑像素值、线包、版本、保护、ACK 或解码段，不把 18 版旧整类覆盖进来。

`prepare.py` 薄调用既有 `recovery-wall-decode-fast/prepare_color_components.py`，输出限定到本新目录，并额外核对旧 85/0 回执与实际冻结组件源码、准确 21 产物、源码指纹。原 85 条断言和独立旧颜色对照类逐字保留；候选类以外的四个生产依赖 `WallCellCodec/RoomCodec/WallSurfaceBridge/NativeWallColor` 与 21 **逐字节相同**。所以 Base64 快解和 W1 去重都保留，且不会混入新的传输/采集行为。

原 `recovery-wall-small-color-component-01` 已实际 85/0，组件 `ff968f61…b583b`；这是前置证据，**不冒充本次 21 组合已通过**。本目录仍未编译、未 AIR，不产生新版本号或全包候选。也不把历史少量 opaque 差异登记为已消失。

根会话运行原串行组件入口：

```powershell
python -B -X utf8 experimental/recovery21-small-wall-component/prepare.py --verify
python -B -X utf8 tools/validation/run_recovery_component.py --source experimental/recovery21-small-wall-component/components --entry WallSurfaceChecks.as --expected 85 --output build/m52/recovery21-small-wall-component-01
```

合并计划只有一步：本次 85 项确实通过后，在根决定的完整候选中用该 **准确 21 加两处 setter** 的单类覆盖；其余 89 类不动（若另行定版本号，入口只改版本字符串）。当前不做这个全包合并。`two-setters.patch`、`inputs.json` 和 `static-checks.json` 提供精确差异与检查；静态通过不表示游戏/性能资格。
