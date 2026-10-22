# 当前玩家 RV 设置：原 CPU 采样器入口

仅诊断，不能用采样期间的帧率取得性能或发布资格。准确 driver03 的 **11 份 AS 源码全部不变**，只将编译入口从 `ProjectileLoadTestDoc` 改为既有 `ProjectileProfileTestDoc`（`super(true,true)`）。保留原 80 身体 / 12 枪 / 七阶段、准备与完整武器 ready 校验、刺激、门槛、采样量及 ENTER_FRAME→RENDER 采样窗。窗外时间仍不归入函数 CPU 成本，不扩大采样范围。

`sampler.py` 直接复用原 readyfix `freeze` 和已登记的原 `build`；冻结到新 driver 目录后再核对 11 类与准确 driver03 逐字节相同。原 `diagnostic=True` 默认选轨迹汇总入口，本适配仅将 metadata 的 entry 明确改为 CPU 采样类。没有新的编译器、SWF 搬运框架或采样实现。编译继续使用 game 占用与 1 GiB 门槛；双开沿用原登记、6 GiB 启动及 512 MiB 运行保护。

运行入口复用冻结的 `recovery-density-profile-settings/run_motion_comparison.py` **原字节**、同两份 RV 配置及原严格 corridor audit。新 [run.patch](run.patch) 逐行列出 13 处适配：允许新采样 driver（仍必须全源等于 driver03）、引用原 profile wrapper/配置、标为诊断并保存 CPU 报告。启动前玩家设置必须仍等于捕获 SHA，结束后再次核对；测试工具不改玩家存储。wrapper 的完整输出另存，避免把巨型 PROFILE 错误数组打印到终端。

在 `mods/RConnect` 下由根会话串行执行；本交付没有编译/运行：

```powershell
$py = 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
& $py -B -X utf8 experimental/recovery-current-profile-sampler/check.py
& $py -B -X utf8 experimental/recovery-current-profile-sampler/sampler.py --output build/m52/recovery-current-profile-sampler-drivers-01 --build --registry-wait 900
& $py -B -X utf8 experimental/recovery-current-profile-sampler/run.py --candidate build/m52/recovery-20 --drivers build/m52/recovery-current-profile-sampler-drivers-01 --output build/m52/recovery-current-profile-sampler-20-01 --registry-wait 900
```

`result.json` 和 `fixture-audit.json` 保留原失败，不改绿；原帧数门槛仍会执行，采样导致其失败也不得放宽。`cpu-profile.json` 复用既有 `recovery13-density-review/analyze.py`，提供 `at/after/end` 分账、CPU 包含/叶栈与原日志指纹；实际样本总数不能当调用次数或可节省时间。采样数据仍包含原实现已有的分配汇总，但分析 CPU 必须使用 CPU 栈，不能混入分配计数。

原 wrapper 可能把 PROFILE 中函数名包含 `TypeError/Error #...` 的整条 JSON 误收进 errors；新报告只将结构及 role 验证通过的 `PROJECTILE PROFILE` 行视为数据，另列 `actual_runtime_errors`。外部 `COOP FAIL`、真实运行异常、畸形/错误侧 PROFILE 不会被忽略。即使 CPU 数据齐全，也只记 `collected`，永远 `performance_qualified=false`。不得与非采样 driver 的 FPS 计算改善比例；这里的用途是核对当前 RV 关闭配置下的 CPU 主要开销与采样窗外长间隔。
