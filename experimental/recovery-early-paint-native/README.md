# 原生绘图诊断的薄运行适配

仅接纳准确 early2 D356、paint-driver-v2、Sand003 和旧 RV7852；安装仍须为 RV AB46 的指定 22 项组合。只写隔离副本，沿用原有三场景、计时和断言，支持双侧与 `--solo`。所有结果均 `performance_qualified=false`。

不复制旧运行器。在内存中读取并核对冻结的 `recovery-early-exit-native/run_native.py`，仅作三处可逆替换：本诊断允许 solo；用冻结 `audit_profile.audit_log` 验证各侧三段原生绘图区间；补明确的性能不授资格字段。进程、取消、共享测试登记、内存门槛、错误扫描和输入复验继续使用原主体及冻结 `recovery-early-revisit-frozen-rv/native_runner.py`。

宿主仅接受最终 `build/m52/recovery-early-paint-host-03`，实际产物固定为 `29d36cdd94aadc5368156f80e854808d78b74baf8347ebfcc80c644d73601ef7`。必须另有 `build/m52/recovery-early-paint-host-recheck-03/receipt.json`，其中 compiled、source_readback_passed、pcode_bindings_passed、exception_cfg_passed、validated、installation_unchanged、source_unchanged 七项均 true；以 `builder_manifest_sha256` 绑定 03 原构建记录，再核对实际 SWF、回读 AS、p-code 及全部审查输入。缺独立回执或还未冻结精确输入，一律拒绝启动 AIR。诊断 validated 不代表游玩或发布合格。旧 02 的真实拒绝回执作为负例保留，不作为任何运行授权。

现成 v2 驱动不重编、不改 metadata。`source_compat.py` 严格核对 v2 与 v3 源：除 sceneEnsure 外全部源码相同；原提前返回、开始采集段、结束采集与观察段、5 参数顺序和 21 字段表达式完全一致；变化只能是已冻结变换中的显式保存异常与重新抛出。v3 源固定为 `eb487597d89073d61e1dffc7789c46130379c45276a9fde5f180008d87e0f960`。兼容证明随新的运行 intent 保存，并与原驱动的 v2 来源分别记录。

根会话审查后执行（本子任务不运行）：

```text
python -B -X utf8 experimental/recovery-early-paint-native/check.py
python -B -X utf8 experimental/recovery-early-paint-native/freeze.py --drivers build/m52/recovery-early-paint-driver-v2-01 --expected-host-sha 29d36cdd94aadc5368156f80e854808d78b74baf8347ebfcc80c644d73601ef7 --expected-review-sha <独立回执 SHA256> --expected-driver-sha 3b234a348418ee55cc9533e719ff75544394f33aedd4d5a82762c86778872e1a
python -B -X utf8 experimental/recovery-early-paint-native/run_native.py --candidate build/m52/recovery-early-exit-compile-01 --drivers build/m52/recovery-early-paint-driver-v2-01 --game-candidate build/m52/recovery-early-paint-host-03 --output build/m52/<全新输出> --scenario scene --sand-mode bridge
```

单人只加 `--solo`。成功结果仍须原场景全部通过、无游戏错误、输入与安装不变，并且每侧 `profile_valid=true`。绘图诊断失败会保留 `paint_profiles` 错误原因，不把失败变成性能样本。

当前仅源码准备与静态检查；由根会话冻结和安排实际运行。
