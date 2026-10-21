# 随机大图延后首绘：单变量对照

目的仅为证伪“延后首绘能改善共同加载”。准确13已通过功能，却比同驱动单人慢；本目录不是可部署修复，也不改当前 integrated/冻结历史。源码准备完成后由根会话串行编译/AIR。

生产差异只有 `RoomSync.openFirstRaster` 的 seed 分支最终 `return firstRaster.open(...)` 改为 `return null`，另改候选版本文字为 `0.2.24-recovery13-seed-off`。此前身份/目的地/配置校验保留；SeedRasterEntry、固定seal入口、完整状态恢复与既有无ticket ACK分支均不改；非seed首绘路径逐字不变。准确基线是 `build/m52/recovery-13` / `1177eb…fddb1`，准确宿主保持 `host-03` / `fd92fb…6734e`。

## 组件与同字节驱动

`components/on`、`components/off` 都执行真实 RoomSync/Gate/SeedRasterEntry；原生World/Game/像素是既有小替身。保留原79项非seed检查，配合同一组30项seed检查；两目录只允许真实RoomSync的一条return和显式期望常量不同。7个最终状态记录（正常、错误seed、死亡、同World替换Game、断开、配置退回、恢复失败）要求逐字段相同；ticket存在与延后ACK时机是明确有意差异。未执行前不称109项已通过。

大图只编译一次 `prepare_driver.py`，on/off两包调用**同一SWF**。它从隔离应用的 `tests/seed-gate-intent.json` 读取明确布尔期望及候选SHA，缺失/畸形直接失败。运行器分别记录intent，并独立核对原生实际日志、每轮ticket存在/不存在、初值、真实完成、candidate指纹。on缺ticket、off多ticket、桥缺失均失败，不把“没有票据”默认当成功。

公共 runner 不支持附加测试资产，因此 `native_runner.py` 是可审计的私有副本：仅调整自身路径、复制intent并登记其hash。`native-runner.patch` 可回读；去除这几处后逐字恢复公共源。登记、内存、独占、启动、日志判错、清理不变。外部 `run_native.py` 保留既有39/13标签、真实按键、时间口径、超时与22项安装门禁；功能passed仍不代表性能合格。

## 根会话执行命令

工作目录 `mods/RConnect`；以下输出均须为新目录，按登记串行运行。Python使用本机已探测的解释器。

```powershell
$rasterPython = 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'

& $rasterPython -B -X utf8 tools/validation/run_recovery_component.py --source experimental/recovery-seed-raster-control/components/on --entry NativeTravelRoomChecks.as --output build/m52/recovery-seed-gate-on-component-01 --expected 109 --registry-wait 900
& $rasterPython -B -X utf8 tools/validation/run_recovery_component.py --source experimental/recovery-seed-raster-control/components/off --entry NativeTravelRoomChecks.as --output build/m52/recovery-seed-gate-off-component-01 --expected 109 --registry-wait 900
& $rasterPython -B -X utf8 experimental/recovery-seed-raster-control/compare_components.py --on build/m52/recovery-seed-gate-on-component-01 --off build/m52/recovery-seed-gate-off-component-01

& $rasterPython -B -X utf8 experimental/recovery-seed-raster-control/prepare.py build/m52/recovery-seed-gate-off-01 --build --registry-wait 900
& $rasterPython -B -X utf8 experimental/recovery-seed-raster-control/prepare_driver.py build/m52/recovery-seed-gate-driver-01 --compile --registry-wait 900

& $rasterPython -B -X utf8 experimental/recovery-seed-raster-control/run_native.py --candidate build/m52/recovery-13 --gate-expect on --game-candidate build/m52/recovery-first-raster-host-03 --drivers build/m52/recovery-seed-gate-driver-01 --scenario scene --output build/m52/recovery-seed-gate-on-dual-01 --registry-wait 900
& $rasterPython -B -X utf8 experimental/recovery-seed-raster-control/run_native.py --candidate build/m52/recovery-seed-gate-off-01 --gate-expect off --game-candidate build/m52/recovery-first-raster-host-03 --drivers build/m52/recovery-seed-gate-driver-01 --scenario scene --output build/m52/recovery-seed-gate-off-dual-01 --registry-wait 900
```

单人对照在对应命令加 `--solo`，输出另命名 `...-on-solo-01` / `...-off-solo-01`。单人和宿主从不应生成seed ticket；外部intent仍必须明确且匹配候选，两个布尔值不能随意对调。实际首绘timing与原elapsed/真实按键响应分别列出，重复样本及入口、单位本体/命中代理负载仍需核对。

本目录 `check_sources.py` 是纯静态和解析器反例：不加载AS、不运行原生游戏。`source-checks.json`、`control-manifest.json` 记录已做范围。组件与原生结果全部由上面的新输出承载，旧大图与entry-room失败不改。
