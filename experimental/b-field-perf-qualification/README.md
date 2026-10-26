# B 四轮真实双侧性能资格工具

2026-10-25。只读评定已有测试证据，不启动AIR/JVM、不调用bench、不改产品、根tools或部署文件。根会话统一安排真实测试。

状态：24项离线正反例通过，field21独立计划已冻结；历史field9实测只作为日志/工作负载解析验证。**未据此授予候选性能资格，四轮真实结果须另行输入。**

既定field21四轮已完成并正式判为**未合格**：第二轮基线密集阶段有完整10秒窗口未实际发射，且重复轮次原始耗时约翻倍。未替换失败轮次。见[结果与最小诊断建议](FIELD21-RESULTS.md)及[field21-qualification-01.json](field21-qualification-01.json)。候选第二轮单项证据完整不代表整组通过。

## 固定对照组合

| 组别 | RConnect构建 | SWF SHA256 | native |
|---|---|---|---|
| baseline | b190-field9-build / field3 | fbaaea1b9f9da4514d0cbedff43403ed53fc694198ddd0e917980c7d922a1acd | native-hooks-019 / 1028a49a4af4d8e1b4bd215a44d38a742723438e24056e2336ea875d82efdba9 |
| candidate | b190-field21-build / field4 | f4426b1a067611c89296a38b722c8ef65c86ff2e61cf2869fa48ca046460d581 | native-hooks-021 / eced04ad8dae6b74444ee6e5f5ec5ddf2e83528a9eecfef66f58985cb0c83063 |

基线与两组native准确字节固定在脚本中；候选必须通过显式`--candidate-build`选定并冻结为新计划。`field21-plan.json`冻结构建记录、全部AS源码、SWF、native、AB007驱动及payload、field2 bench脚本和既有B playable清单的hash。源码与构建清单必须完整一致，并核验BuildInfo、重算源码指纹、比对实际SWF。评定时重新核对全部冻结内容，不能只改候选名、source或hash来替代旧计划。

field21 source：`f8a63b52187efb3a9ec5a5e7d90a6455b9862839adefb09e6fa59d848c3b5ee1`。旧`field20-plan.json`原样保留，SHA256仍为`bdf5e67ee1fbd586e5c0b59d6347e799798a9f34b6ec7c9a67fe6125da2fc644`；它只支持原field20字节，不会自动升级。field20 candidate-01是先导测试，不属于field21正式四轮。field20与21虽都显示field4，源指纹和SWF不同，不能仅凭版本标签混用。

原 `field_driver/qualify_performance.py`硬编码startup2基线且未验证native组合，不能直接拿它给本轮判定。本工具沿用其均值/P95计算口径，并补证据核验。

## 根会话运行命令

以下从游戏根目录运行，**只给根会话执行**。本子任务不会启动这些命令。每次两个60秒阶段，顺序基线→候选→基线→候选；同一workspace可重复使用，避免复制四套运行目录。结果目录必须是新的，若示例名已存在应换一组新名字，不能覆盖失败证据。第一轮基线`b-field20-perf-baseline-02`已完成并单独核验合格，下面只列剩下三轮；失败的baseline-01未启动AIR，不可纳入。

```powershell
$bPerfPython = 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
$bPerfRunner = 'mods/RConnect/tools/host_authority/field2_driver/bench.py'
$bPerfWorkspace = 'build/ab/b-field2-bench-20261025-01'

& $bPerfPython $bPerfRunner --workspace $bPerfWorkspace --seconds 60 --candidate 'build/ab/b190-field21-build' --native 'build/ab/native-hooks-021/pfe.swf' --result 'build/ab/b-field21-perf-candidate-01'
& $bPerfPython $bPerfRunner --workspace $bPerfWorkspace --seconds 60 --candidate 'build/ab/b190-field9-build' --native 'build/ab/native-hooks-019/pfe.swf' --result 'build/ab/b-field20-perf-baseline-03'
& $bPerfPython $bPerfRunner --workspace $bPerfWorkspace --seconds 60 --candidate 'build/ab/b190-field21-build' --native 'build/ab/native-hooks-021/pfe.swf' --result 'build/ab/b-field21-perf-candidate-02'
```

不加`--profile`，不接逐帧clock采样器或其他额外诊断。若需要诊断，另跑有标记的诊断轮，不混入净性能四轮。现有bench会登记测试占用、使用独立AIR ID/后台桌面并检查内存；工具没有绕过它们。

四轮完成后，只读评定：

```powershell
& $bPerfPython 'mods/RConnect/experimental/b-field-perf-qualification/qualify.py' evaluate `
  --plan 'experimental/b-field-perf-qualification/field21-plan.json' `
  --baseline 'build/ab/b-field20-perf-baseline-02' 'build/ab/b-field20-perf-baseline-03' `
  --candidate 'build/ab/b-field21-perf-candidate-01' 'build/ab/b-field21-perf-candidate-02' `
  --out 'experimental/b-field-perf-qualification/field21-qualification-01.json'
```

CLI中的相对参数都相对于`mods/RConnect`，也可给该目录内的绝对路径。只写一个新的评定JSON；输出目录必须已存在。不覆盖旧结论。返回码0表示门槛通过，1表示输入有效但性能/重复性不通过，2表示证据缺失或不匹配。

已存在的冻结计划不要重写。如确需重新冻结同一准确组合，可在运行前用新的文件名：

```powershell
& $bPerfPython 'mods/RConnect/experimental/b-field-perf-qualification/qualify.py' freeze `
  --candidate-build 'build/ab/b190-field21-build' `
  --out 'experimental/b-field-perf-qualification/field21-plan-02.json'
```

## 每轮输入目录结构

```text
<run>/
  result.json       field2 bench完整回执，含准确candidate/native、两侧files、两阶段results
  runner.py         bench当时复制的执行脚本
  machine.json      本机时间、CPU与可用内存采样
  host/
    ABBench.log     installed / ready / measure-begin / sample / result / done
    RConnect-B.log  实际boot源指纹、角色、session与错误
  join/
    ABBench.log
    RConnect-B.log
```

截图和其他日志由bench照常保留，但不是本脚本算均值/P95的输入。输入目录、AIR身份都必须互不重复；machine时间核对四轮顺序与不重叠。工具将结果文件、runner、machine及两侧原始日志的hash登记进评定JSON。

## 不放宽的门槛及证据核验

- **准确运行字节**：计划中的所有输入仍须匹配；每轮和两侧files都必须同时匹配该组RC/native；实际boot源指纹、版本、角色和隔离session一致。AB007构建、实际payload、原始installed配置、runner及基础playable清单相同。
- **配置一致**：RConnect config按冻结manual配置加角色/session/实际监听端口重建并核hash；ab-bench.json固定B/60秒/不profile/相同AB007 source；AIR描述符固定入口pfe.swf与窗口设置。不能把“配置是可变文件”当成任意忽略配置。
- **共同运行组合**：两侧及四轮其他文件的hash清单完全一致。唯一特殊处理是启动器自动生成的`work/manifest-backups/loader-manifest-时间戳.txt`：仅去掉文件名中的运行时间差，内容hash及数量仍以多重集比较；实际`mods/loader-manifest.txt`不豁免。该备份路径的用途已核对ModLoader启动器说明。
- **工作负载真实**：每阶段至少45个实际样本；每个样本、开始及结束的敌人数与附着显示数均是8或80。不要求visible等于敌人数，保留原视野/遮挡；但visible值必须有效。两侧都有真实角色、武器、弹药与发射计数。
- **持续开火**：主侧相邻样本中，两人的每次耗弹差必须非负且严格等于实际弹丸生成计数差；六个10秒窗口都要有至少8秒样本跨度，且两人在每个窗口均有实际开火。两人全阶段都须耗弹。
- **真实时序**：阶段至少60000ms，intervals数量=frames、排序正确、和=elapsed；样本时间有序且覆盖到55秒以后。原ABBench.log的独立sample列表、measure-begin弹药与result嵌入内容，必须与回执逐项相等。
- **性能**：每侧分别比较8敌人和80敌人两阶段，两轮均值取中位数（两值即平均），P95沿用`intervals[int(frames*0.95)]`再取两轮中位数。候选mean及P95都必须≤基线的1.05倍。
- **重复性**：基线和候选各自两轮mean的最大/最小≤1.2；同时要求P95重复比≤1.2。不能以两轮平均掩盖一次异常波动。
- **完成和错误**：每轮complete/passed/done为真，原日志没有fatal/error；runtime_changes为空、两阶段齐全、无profile timings。可用内存没有跌穿既定0.5GiB运行保护。

相比旧工具，新增了两项更严格的真实性约束：采样不足的10秒窗口会判无资格而非跳过；P95重复比也纳入≤1.2。没有降低45样本、5%或1.2门槛；如果这些条件无法满足，应重测或解释失败，不能自动跳过条件。

## 已完成的工具验证

```powershell
& $bPerfPython 'mods/RConnect/experimental/b-field-perf-qualification/test_qualify.py'
```

24项离线检查通过：原16项覆盖完整工作负载，44样本拒绝，敌人/附着缺失拒绝，耗弹或shots不匹配，停止开火，即便耗弹/shots同时不变也拒绝，采样窗口缺口，intervals损坏，profile，非有限数/重复时间，5%边界，mean/P95重复比，模糊路径及原始日志与摘要不一致。新增8项覆盖显式候选参数、新旧计划兼容且旧文件不变、基线/native不可换、源指纹/版本/manifest/SWF不可改标签、冻结清单遗漏、候选路径边界、实际SWF不符、构建源码指纹与清单不符。另只读`b-field-clean-fixed9-01`核对真实历史格式；它不是本轮对照输入。

第一轮真实基线`b-field20-perf-baseline-02`独立通过准确文件/配置/原日志/持续开火核验：主侧8敌人59样本、80敌人58样本；加入侧分别60/59样本。它只证明该轮输入有效，单轮均值不证明候选性能通过。bench当前回执没有记录RC候选构建目录，因此运行证据以实际SWF及源指纹匹配计划；native实际路径也逐项检查。计划本身完整验证候选构建的准确路径及内容，不臆造运行日志未记载的RC来源路径。

已核对Windows common.save换行序列与旧真实ab-bench.json hash相同，并复验冻结计划仍匹配准确文件。没有生成伪造的四轮“通过”报告，也没有运行新游戏测试。

评定只覆盖**Stage事件帧间隔**。它不能证明GPU最终输出、端到端动作延迟、墙体/导弹事件完整性或所有玩法回归；这些仍由功能与时钟实测独立判断。`qualified=true`也不是部署命令。
