# 首次加载 CPU 诊断驱动：单次编译入口

仅准备/核对编译，不启动 AIR，不修改安装版。源码是已冻结的 `../goal-loading-cpu-probe`：prepare E10112B0、manifest C323BBC0；入口真实调用其 `verify()`，不代写或生成缺失清单。五份 AS 原字节复制至新的 build 目录，入口 `tests/RoomTravelTimingTestDoc.as`。三份原驱动、两份旧采样器来源、基底 prepared/compile/877B05DA driver 和差分均纳入输入核对。

复用 `../goal-native-loading-split-build/build.py` 的单 mxmlc 编译、共享 game 登记、至少 1 GiB 启动余量、512 MiB 运行保护、300 秒超时和仅回收自己 PID 的流程。AIR 配置、外部库 598D3985 / 8AA240ED、原 D52EF430 harness 保持。产物仅 `timing/EffectsDriver.swf` 与 `timing/EffectsHarness.swf`；诊断产物没有运行或性能资格。

从 RConnect 目录执行（由根会话独占启动）：

```powershell
$py = 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
& $py -B -X utf8 experimental/goal-loading-cpu-native/build.py --check
& $py -B -X utf8 experimental/goal-loading-cpu-native/build.py --build --output build/m52/goal-loading-cpu-driver-01
& $py -B -X utf8 experimental/goal-loading-cpu-native/build.py --verify build/m52/goal-loading-cpu-driver-01
```

输出目录必须是 `build/m52/goal-loading-cpu-driver-*` 下不存在的直接子目录。全部源码、工具、来源凭证及当前 22 项安装记录在建目录前核对。缺清单或缺真实 compile 回执返回 `not-ready` / exit 2，不生成替代证据；其它指纹或合同不符直接失败。当前安装快照独立记录，不把历史基底编译环境重标为当前环境。

`verify(output)` 只接受真实单 mxmlc 成功：prepared 输入、完整源码副本、精确命令、正 PID、exit 0、已回收、内存回执/日志及实际两份产物指纹均相符，当前 22 项安装前后不变。失败编译仍保留 `compile.json`、已有日志和内存证据，不能视为成功。返回 `verified/artifacts/inputs/prepared_sha256/compile_sha256/build_environment`，并明确 `runtime_tested=false`、`performance_qualified=false`。

本次冻结范围只有 `build.py` 与本文件；不冻结或修改同目录由根会话维护的 `run.py`。编译入口的输入指纹不包含 `run.py`；真实运行准入、单采样器互斥和诊断扰动解释由运行入口负责。
