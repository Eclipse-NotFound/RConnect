# 原生灯具图像诊断：真实驱动接线

此入口固定为一次独立诊断：RC 9C8536A7、LAD 8A127C99、已实际编译并获独立语义准入的宿主 **host03 / 7B3CAE6F**，以及真实新驱动 **diagnostic-driver-01 / 370F9D58**。不是旧 877B 驱动。调用父目录已经修正并重新冻结的入口，真实核历史 UI 组合，再独立调用 `diagnostic-build.verify()` 检查当前四源码编译回执、原两份外置声明和 Harness。旧 BF4A 编译与当前 RV 638E 环境仍分别核验；不替换 `installed()` 或伪造历史通过。

复用原单一私有运行器和三程刺激、35 项旅行检查、双侧各 11 项 UI 检查、600 秒、6 GiB 起步/512 MiB 运行保护、共享登记、独占、后台桌面、真实 22 项安装前后核验和只回收自有实例/副本。普通入口展开源码仅多一个精确接点：新 AppID 的 `ordinary-lamp` 目录必须尚不存在。父目录五处 LAD 替换、实际模块指纹检查和所有错误规则不变。

原私有运行器已支持额外 `--done` 前缀；这里传入 `LAMP RASTER PROBE DONE `，仍要求原 COOP DONE。最终核验还要求原 `NATIVE LOADING PROBE DONE`，三个标记双侧都必须各一次且顺序正确。失败诊断也可能写 DONE，故完成标记绝不等于通过。缺终态按原超时失败，不延长或跳过。

所有自有子进程停止后、原清理前，分别保全原 UI JSON/PNG、LAD 日志，以及每端 `ordinary-lamp/result.json` 和 12 张 PNG。新核验逐项回读固定八个标签、无错误、首程 `t_exit=19`、5 张实际原生表面像素比较结果、世界/房间/玩家/灯/代理/物理记录不变、单次 drawLoc、相机恢复及真实 alloff/allon；检查 12 个唯一文件的签名、尺寸、长度和指纹，绝不以旧 11 项代替。

本入口始终 `diagnosticOnly=true`、`performance_qualified=false`、`optimization_path_proven=false`。AS 的 BitmapData.compare 结果为同事件原生缓冲比较；Python 核对真实 PNG 文件及源证据，没有独立重算像素。内部 colorBmp 未直接读取，只有 hardlight 最终背景参与。最终旧驱动已让加入侧离线，故 alloff/allon 只验证各端本地原生行为，不能称网络切灯同步。图像仍须根查看，`lamp_visual_qualified=false` 保留；不授回滚链或全部灯型资格。

在游戏根执行（只有根负责实际启动）：

```text
python -B mods/RConnect/experimental/goal-ordinary-lamp-native/diagnostic-native/run.py --source-check
python -B mods/RConnect/experimental/goal-ordinary-lamp-native/diagnostic-native/run.py --check
python -B mods/RConnect/experimental/goal-ordinary-lamp-native/diagnostic-native/run.py --output build/m52/goal-ordinary-lamp-diagnostic-native-01
```

源码准备 `--prepare-source` 只生成本目录展开文本/差分/指纹清单，禁止覆盖已存在清单。没有新增产品、宿主、驱动编译，不改任何被冻结的上层文件、正式选择或安装文件。
