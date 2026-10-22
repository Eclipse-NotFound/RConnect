# 当前玩家 RV 设置下的独立密集对照

只对齐测试输入，不改变游戏设置或优化生产代码。默认模组组合的所有旧失败继续保留；这里即使通过，也只能说明这两份设置下的表现，不能称“关闭 RV 修复了性能”。实际使用 driver03 原字节、原 80 身体 / 12 枪 / 七阶段与全部门槛、正式隔离存储/独占/内存/占用登记及原完整场景审计。

冻结配置逐字节来自：

| 侧 | 当前游玩存储 | 已冻结关键值 | SHA-256 |
|---|---|---|---|
| 主 | `pfe/Local Store/RealisticVision_config.txt` | `enabled=0`，classic，dim `0.6000000000000001` | `24a0162f565dfa9a04e42bd64ca6fb688d556d50d99a528dbfa703d680eaba0c` |
| 加 | `pfe-modsettings-rconnect-player2/Local Store/RealisticVision_config.txt` | `enabled=0`，current，dim `0.35` | `f3c7dfe712a836188d712f70b7d30fd83b8bb70435de28757196b3f926bf23f8` |

不是旧 `pfe2`，也不是发布目录 `enabled=1` 默认配置。两个原文件在复制后重新读取确认未变。`inputs.json` 保存完整来源与依赖指纹，`configs/` 只有 424 字节；不会把临时文件写入用户游玩目录。

`run_motion_comparison.py` 是正式同名 wrapper 的完整副本；[wrapper.patch](wrapper.patch) 列出全部逐行差异，[wrapper-edits.json](wrapper-edits.json) 可精确重建这 11 处增量：导入定位、新增两模板参数、模板冻结/指纹、参考轮等值校验、底层两参数透传、原始 run/input 中两份哈希的验收。原场景表、解析、性能条件、隔离与登记不变。没有全局 subprocess 替换。

独立 `run.py` 复用原 `prepare.verify` 和未改动的 corridor `audit`，准确绑定 `recovery-density-corridor-drivers-03`（manifest `5a8dbb9395c8dba8b6e980c49b112c6df3ae2e19e2f4950769d29756f8e1735c`）。它不修改冻结 driver 对旧官方 wrapper 的依赖；旧工具必须继续通过指纹核对。wrapper 将配置再冻结到本轮输出，**只有原底层 `run_coop_regression.py` 的既有模板接口**写入唯一 AppID 的测试存储。结果核对底层 `run.json` 和运行前 `input.json` 的配置哈希；这些是模板输入证据，不冒充 RV 每帧内部状态采样。

在 `mods/RConnect` 下，根会话按测试占用串行执行（本交付未执行）：

```powershell
$py = 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
& $py -B -X utf8 experimental/recovery-density-profile-settings/check.py
& $py -B -X utf8 experimental/recovery-density-profile-settings/run.py --candidate build/m52/coop-bundle-04 --output build/m52/recovery-density-player-settings-574d-01
& $py -B -X utf8 experimental/recovery-density-profile-settings/run.py --candidate build/m52/recovery-20 --output build/m52/recovery-density-player-settings-20-01 --reference build/m52/recovery-density-player-settings-574d-01
```

对照必须来自本入口同两份冻结模板。缺模板、两侧交换、任一字节变化、wrapper/driver/安装/底层工具变化均不能作为同条件比较；无原生结果仍失败，不把模板校验代替性能门槛。运行后原用户设置哈希另行核对，`result.json` 原结果不改写，`fixture-audit.json` 保留真实场景、差异与失败。
