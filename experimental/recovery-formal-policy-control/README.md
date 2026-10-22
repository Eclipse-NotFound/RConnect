# 正式启动进程策略的独立对照入口

用途仅为对齐正式双开运行条件。**不是产品优化，不证明原来实际被节流，也不证明进程策略造成任何性能差异。** 尚未编译、未运行AIR；安装和用户进程不改。根会话自行决定是否在其它诊断后串行使用，不自动追加测试。

基于已冻结 `recovery-density-profile-settings`，启动行为仅为向既有 `run_coop_regression.py` 多传一个 `--responsive`。底层runner本来就支持此选项：只对刚创建并经唯一描述符核验的两个测试PID，调用正式 `RConnect.Process.ps1/KeepResponsive`，将 EXECUTION_SPEED 控制位置1、状态位清0，再读回。其它掩码位保留，不改变系统电源计划、进程优先级或亲和性。

保留原driver03字节、80本体/39原生武器显示/12把射击武器、七阶段8秒与原全部门槛；两份实际玩家RV模板逐字相同。私有桌面、延后显示、等主侧世界、全模组、独占检测、原内存阈值、登记和只清自有进程均由原runner执行。完整场景/显示审计仍调用原 `recovery-density-corridor-readyfix/audit.py`。不新增采样器、构建器或游戏启动框架。

`wrapper-edits.json` 可从原profile wrapper精确重建8处文本差异；其中只有一处改变启动参数，其余是保留两份小helper源码、调用当前及同策略参考轮的只读回执验证、记录结果与失败条件。`entry-edits.json` 仅给原入口增加最终策略证据的审计门槛。全部差异另存两份patch。`inputs.json` 固定原入口/依赖/driver03 manifest、两份模板与两份正式策略helper；`handoff.json` 固定本目录源码与文档。

结果必须同时验证：

- 两侧 `*.process-policy.json` 的PID分别对应原run的两个唯一PID，掩码为合法整数，`control & 1 != 0` 且 `state & 1 == 0`。
- 两侧 `run.json`、运行前 `input.json` 里**runner实际计算的游戏副本helper哈希**，与启动前保留在外层 `process-policy-source/` 的两份小源码及已冻结输入相同。
- 两侧描述符哈希和含角色/唯一run id的AppID一致；已有 `runner-source/run_coop_regression.py` 指纹仍为经审阅的原runner，实际执行helper的保留源码仍有PID/描述符身份保护及Set后Read。

已核对原runner：256–258行在clone角色目录后，对实际 `role/tools` 两个文件分别计算SHA；348–353行随后执行该角色目录的helper并保存读回，且写入失败/掩码不符会报错；416–426行结束后正常删除host/join/frozen。**本入口不再要求结束后读取这些已删除的副本**，不加 `--keep-copies`、不改变runner。仅保留两份几KB源码与已有JSON证据，清理与D盘占用规则照旧。结果字段明确 `actual_game_copy_hash_source` 和 `postrun_game_copies_reread=false`，不把runner当时记录的哈希冒称结束后重新读取。

缺文件、默认0/0、读回失败、角色或PID混淆、helper或输入改变，都使 `result.json` 和 `fixture-audit.json` 保持失败；`attribution_allowed=false`。仅通过策略回执不能覆盖原功能/性能失败。该回执证明**启动时**实际读回，不是全程策略采样。

`--reference` 保留原来“同wrapper字节”的严格要求，并在启动前复核参考轮原始回执和保留证据，不能使用同wrapper但策略证明失败的参考轮。不能把普通策略的旧轮次作为本入口reference；普通/正式策略的单变量比较只能由独立事后报告核对同20、driver03、模板及其它全部输入，并明确唯一策略差异。若以后在正式策略下对比574D/20，可使用本入口正常reference，不放宽场景差异审计。

根会话在 `mods/RConnect` 下按占用决定执行；以下只是可调用入口：

```powershell
$py = 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
& $py -B -X utf8 experimental/recovery-formal-policy-control/check.py
& $py -B -X utf8 experimental/recovery-formal-policy-control/run.py --candidate build/m52/recovery-20 --output build/m52/recovery20-formal-policy-density-01
```

不需要也不允许在当前用户游戏或既有测试PID上补设置。运行前实际玩家RV配置若已改变，原入口会拒绝，需另行冻结正确输入；本目录不写用户配置。静态检查仅向stdout输出，不改已冻结源码或既有结果。

准备期第一次43项纯检查没有覆盖正常清理后的路径，已由独立审阅指出；该版未运行AIR，`handoff-01.json`/`static-check-01.json` 留作被替代记录，不作当前可运行证明。当前检查增加了“游戏副本全部不存在，仅保留正式证据”的实际审计函数反例，以及该状态下缺回执/错误掩码仍失败的反例。

当前纯检查实际 **50/0**，见 `static-check.json`；这是源码、输入指纹和反例验证，不是原生运行或性能合格证明。
