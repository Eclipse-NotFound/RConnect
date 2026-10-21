# 气体首轮时钟：准确 13 的隔离诊断源码

状态：仅静态准备；63 项纯 Python 自检通过（AS 仅做结构核对，不等同编译）。未编译、未运行 AIR、未改安装版，不能视作原生或性能通过。所有文件仅在本目录。根会话决定是否及何时运行。

基线固定为 `build/m52/recovery-13`，产物 SHA256 `1177eb1ae9b227bcf3c0eb39dedad92b63ac16dcb7ffb0b421ea0a2024bfddb1`；prepared SHA256 `e7109bec3f02ef8c7b5cf1070293022bc1ebf941942b91486910a742fc139fc4`。87 个源文件哈希均复核；本目录不是 recovery08 的旧算法覆盖。复用旧诊断的标记剥离、括号定位及有界数字表方法，依赖哈希在 `inputs.json`。

## 修改范围

- `src/rconnect/game/GameBridge.as`：仅在真实 `rec.motion.push` 前绑定玩家时钟，早于第一次 push。记录 World/房间/epoch/玩家及门控变化。已有 timed 或 legacy 状态才绑定，均将本次诊断标为不完整。
- `src/rconnect/game/RemoteMotion.as`：只读 push 前后、初始化重置、legacy 清空、sample 实际分支前后、settle 前后。记录真实 cursor/offset/wanted/debt/rate；不再调用 sample、delay、push、rateHeld，不遍历 rateOwners。Object 返回函数的 try/finally 后保留编译器所需不可达 `return null`，原分支原样存在。
- `src/rconnect/game/EnergyImpactVisuals.as`：首个被绑定玩家气体的接收、首显、strictEnd 分支和移除，各记一次。strictEnd 直接传原分支的 `time`，并记录最后收到、最后显示姿态时间，不重新推算结束规则。
- `src/rconnect/diagnostics/FlightDiagnostics.as`：默认 `sink=null`；没有外部驱动便不启用。最多两个实际玩家时钟、16 个 World/房间身份；溢出或回调异常使记录不完整。
- `tests/GasPulseNativeTestDoc.as`：以已交付 v2 为原件，只加记录器生命周期。原四轮 G 操作、26 秒动作/180 秒启动/360 秒外层时限、冷启动、原断言及图像采样均不变。剥除插桩后逐字节等于 v2。
- `tests/GasClockRecorder.as`：6 MiB 固定数字表，首轮完成即停止，不进入第二轮；仅绑定后记录帧首/末 ENTER 与 RENDER。结束时按每块最多 128 行一次导出，无逐帧文件日志。

前三类与驱动中的 `FLIGHT_DIAGNOSTIC_BEGIN/END` 标记剥离后，与各自准确原件逐字节一致。`make_overlay.py` 会验证再生成；`test_static.py` 只检查，不启动外部进程。新 helper 与 recorder 也由输入清单绑定。

## 已有正式流水线的最小接入参数

不新增构建或启动框架。本目录的 `prepare.py` 适配器已取消，`run.py` 也不创建。由根会话使用现有正式源冻结构建器，建立一个全新的隔离目录：

1. 输入准确 13 的全部源和已有工具/存根；仅覆盖上述三个同名生产类，增加 `rconnect/diagnostics/FlightDiagnostics.as`。版本仍是 `0.2.24-recovery13`，诊断必须按候选字节哈希绑定，不能仅按版本名混用。
2. 外部驱动入口 `GasPulseNativeTestDoc`；额外源为本目录 `tests/GasClockRecorder.as`，以及未改动 `experimental/recovery-gas-native-v2/native/GasPulseProbe.as`（哈希见 inputs）。原 v2 驱动要替换成本目录可剥离诊断驱动，不能同时编译两个入口定义。声明库必须来自该诊断候选，包含新增 helper；普通准确 13 的声明库缺此类。
3. 复用 `recovery-tests/prepare.py` 的正式外部声明和 registry 构建路径：只注册此入口，`scenarios=4`、`seconds=360`、`land=random_mane`；组件集合为空。输入清单加入本目录 AS、inputs、两个分析器及正式适配源码。新输出只能为 `build/m52` 的直接子目录，不覆盖 v2 或准确 13。
4. 原生 suite 为 `gas-pulse-native`；既有 `run_coop_regression` 仍须全模组、独立桌面、defer-visible、wait-host-world、require-exclusive-air，保留现行登记、内存门槛和仅清自有实例规则。安装前后 22 项核验、两侧版本/DONE/四轮/COOP FAIL、全部模组日志检查照旧。
5. 原 v2 `verify_results.py` 和其 24 个 PNG/JSON 核验必须单独保留；严格末姿态/顺序失败不能被诊断通过覆盖。追加本目录 `analyze.py --host-log <host.log> --join-log <join.log> --output <新诊断结果.json>`。该命令只读日志、写指定新结果，不启动游戏。

准确 v2 支持文件 SHA256：`GasPulseProbe.as` 为 `f92507b2a8da89f8d2653c90a617f5ab1eaf008726e74129033065a332a61a72`；原严格分析器为 `929201d6a5e4720b98c3ce073b89486cf2db35e4ca49ade181eac091af93716c`。新驱动原件 SHA256 为 `ce59b035fddb83dc1c37be145523884aef1ea621784321ff742bfb8ae25373ea`。

## 分析含义与边界

`analyze.py` 分别验证连续块序号、6 MiB/两个时钟限制、初次绑定早于 push、push/settle/sample 成对、回调错误/溢出、首轮截止及真实气体事件身份。首气体用事件 id 与首个源时间戳，唯一对应 v2 第一轮 wire 记录；不能只按“存在一朵气体”认定对应。外部 wire 监听与生产回调先后可能不同，二者毫秒差作为实测输出，不设任意 50ms 门槛。

记录完整不要求重现秒级延迟。`4733dbf4b4` 的 1–2.3 秒旧证据保持；同一生产 13 的 v2 `b15c17f816` 四轮功能与 24 PNG/JSON 通过，严格轨迹仍失败，首轮本次 82–158ms 不能归功于夹具修正。诊断首气体若没有较大延迟，直接记实测值；若其最后显示姿态早于最后收到姿态，实际 strictEnd 的 `time/end/lastShown/lastReceived` 可区分该次帧跨越，不声称已经覆盖其它云团的末帧。

`hookCostMs/hookMaxMs` 是 helper 调用内部与数字行写入的毫秒分辨率开销；`frameCostMs/frameMaxMs` 是边界回调，`exportMs` 是退出时导出。默认 null 检查、调用前简单参数读取、6 MiB 初次分配与底层日志框架成本不完全包含，0ms 不代表免费。诊断版不得用于性能验收。没有每 tile/payload、额外像素、CPU 采样器或生产日志开关。

## 已取消的被拒操作

准备一个 `prepare.py` 的纯 Python 写源命令，被本机 `PreToolUse` 判为 `Protected target (binary-swf-use-release-pipeline)`。具体操作是 PowerShell here-string 交给已知 Python，读取 timing08 的构建函数作为模板，最后仅执行 `(Path('experimental/recovery-gas-clock-diagnostic')/'prepare.py').write_text(prefix+build+main, encoding='utf-8')`；命令正文含未来复制二进制的配方字符串，因此被拦截。完整拒绝命令和错误保留在本任务工具记录中，未执行、未产生 prepare.py。

根会话随后明确取消新增适配器，要求沿正式流水线接入。本目录没有重试该写入、没有换工具绕过、没有维护授权表。此次交付是已成功写入的诊断源码、外部驱动、分析器和最小接入参数。
