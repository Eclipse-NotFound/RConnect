# 独立原生运行适配器

`run_native.py`只供已编译的`build/m52/recovery-room-restore-diag-01`（B9447B…BCB90）使用，固定原scene12驱动与E159宿主。没有编译、部署或修改候选的入口。

从`mods/RConnect`执行（本次未执行）：

```powershell
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/recovery-room-restore-diagnostics/run_native.py --output build/m52/recovery-room-restore-native-01 --registry-wait 900
```

输出必须是全新的build/m52直接子目录。适配器在本进程中只替换原`run_room_travel_timing.py`的候选audit函数，使用本目录prepare.verify验证该诊断kind、全部源/工具/诊断输入，并额外固定候选二进制SHA。原main照常校验驱动和宿主、执行scene双人流程及600秒限制、共享登记、6GiB启动/512MiB运行保护、独占AIR、22项安装和原错误/三轮旅行结果。未传solo，未改原脚本、驱动、宿主或已编译候选。

运行前后保存`diagnostic-inputs-before.json`和`diagnostic-inputs-after.json`，包含候选源码/工具/二进制、完整scene12冻结文件、E159宿主与冻结源码、运行工具及22项安装指纹。后验采集即便发现改变也保留观察到的哈希；结果列出改变的输入组。缺件等读取失败明确记录，不按不变处理。

原main产生的`result.json`保持原字节，同时复制成`framework-result.json`并记录SHA；其中passed仅是原框架判据的结果。原控制台原样保存在`framework-console.log`。另输出`diagnostic-result.json`，其`passed`、`gameplay_qualified`、`performance_qualified`始终false，`diagnostic_only`始终true。不要把原framework passed误用为生产或性能资格。

独立结果逐角色保存日志中真实的`RConnectRestoreCost`对象、日志SHA和JSON解析错误。只有原框架成功、所有输入不变、两侧各3条完整事务且各有3帧、无未闭合计时范围/计时失配，才记`diagnostic_checks_passed=true`并退出0。原失败、短缺/不完整事务、格式错误或输入变化均保留证据并退出非0；不补造样本、不修改原失败。新增完整性判据只决定这次诊断数据是否齐全，不替代原main的旅行判据。

离线校验入口：

```powershell
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/recovery-room-restore-diagnostics/check_run_native.py
```

本次11项离线检查通过：准确编译候选/scene12/E159与22项安装只读核验，错误候选拒绝，假运行器成功与失败、缺行、格式错误、指纹变化、异常后原结果保留、audit/argv恢复和资格不误绿。测试禁止创建子进程，只使用自有临时目录并自动回收。结果在`native-runner-offline-checks.json`。没有启动JVM/AIR，不能据此称原生诊断已经运行。
