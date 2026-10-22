# recovery16 完整隔离源码

准确以 `build/m52/recovery-14`（SWF `225a794040c71f2a55ff433366a7969201ac3a58ffaab0a655cee1e4eefbe5f7`）全部 **88 份 AS** 为底，叠加已冻结 `recovery-wall-surfaces` 的 WallImpactVisuals、GameBridge、WallSurfaceBridge，并仅将入口版本改为 `0.2.24-recovery16`。结果 **89 份 AS**，原版中其余 **85 份文件逐字节不变**。没有引入 recovery15 的姿态算术改动；UnitPresentation 与14完全相同。

`integration.json` 使用既有完整构建清单格式，可由正式 `prepare_recovery.py --source` 读取。`ancestor-integration.json` 保存14原始清单；`wall-surfaces.patch`、`version.patch` 分开记录功能与版本差异。生成器复用旧完整源准备脚本的清单/指纹函数，没有新编译器、编译工具副本或部署入口。

**当前仅源码准备，未编译16、未运行 AIR、未取得功能或性能资格。** 提案静态检查28项通过，54项组件运行结果不在本清单中冒充通过。原提案目录保持冻结。1200个墙痕格的 checkpoint 容量限制仍存在。

**16必须配合独立编译并回读合格的新 Grafon 宿主。** 所需宿主源码及精确哈希在 `integration.json.host_dependency`，基于 FD92 增加墙面桥；FD92本身以及安装版宿主没有这项新接口。此目录不包含新宿主二进制，也不据源码声明宿主已合格；主会话取得真实宿主回执后再安排同字节原生对照。具体回读和测试边界见原提案 README。

在 RConnect 目录验证本源快照（不运行 JVM/AIR）：

```powershell
python -B -X utf8 experimental/recovery-wall-surfaces-buildsrc/prepare_sources.py --verify
```

由主会话使用已有正式入口串行编译，输出目录必须全新：

```powershell
python -B -X utf8 tools/validation/prepare_recovery.py build/m52/recovery-16 --source experimental/recovery-wall-surfaces-buildsrc --version 0.2.24-recovery16 --build
```

上条命令尚未执行。它只生成隔离RC候选，不生成宿主桥、不给部署资格。
