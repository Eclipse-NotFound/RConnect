# 原生绘制有界诊断：v2 宿主绑定

这层只解决 v1 宿主反编译源码不能导入的准入绑定问题。原 v1 驱动源、32 行缓冲、25 条组件断言、43 项静态/纯数据核验、原场景断言均保持冻结。这里不复制 AS、不新增运行器、不启动游戏；v1 宿主编译失败也不提供任何运行资格。

宿主 v2 对 `sceneDrawSteps` 的两处反编译伪指令按准确前序编译输入还原为 `j++` / `i++`；计时槽、字段、`sceneEnsure` 观察逻辑不变。宿主实际产物及 finally 异常路径仍由根会话独立验收，本层只钉住源码。

## 根会话接口

- `binding.KIND = scene-native-input-early-paint-driver-v2`
- `prepared.diagnostic_kind = ensure-work`
- `binding.verify_tools()`：v1 全部源、原 22 项安装准入、v2 精确源及契约哈希。
- `binding.verify_driver(path, meta, scenario)`：仅接受 scene、bridge、准确新 kind，且编译成功；同时核对原断言文件、原 7852 RV 注入约束、Sand003 来源、v2 宿主源码绑定。
- `audit_profile.audit_log(path)` / `audit_profiles(profiles, travels)`：复用 v1 精确检查器。必须每侧三段，faults / nativeFaults / bindingConflicts / incompleteCalls 全为 0，未溢出、订阅所有权保留、两端 renderer / room 身份正确、与 TRAVEL RESULT 的嵌入数据一致。返回永远含 `diagnostic_only=true, performance_qualified=false`。
- 不提供 AIR 入口；根的单一薄运行适配须继续复用冻结 native_runner，并以新宿主独立产物回执准入，不能放行旧失败宿主。

准备命令（默认只写新的隔离构建目录；只有根明确决定后才加 `--build`）：

```text
python -B -X utf8 experimental/recovery-early-paint-driver-v2/check.py
python -B -X utf8 experimental/recovery-early-paint-driver-v2/prepare.py --output build/m52/recovery-early-paint-driver-v2-01
```

内部复用 v1 准备函数，仅显式替换 kind 和 `verify_tools`；所有 AS 仍从 v1 原位读取。输出的 `paint-inputs.json` / `paint-prepare.py` 保留 v1 冻结配方，新的完整准入及 v2 宿主 source/contract 哈希进入 `prepared.json.source_inputs`。重建必须从本目录入口调用。`paint_host_source_sha256` 与 `paint_contract_sha256` 明确来自 v2。

真正绘图区间从 Grafon 两个原提前返回之后起算，结束时钟先于元数据分配与回调。每次有效回调都聚合计数和时间；零毫秒、resident 不变、非 initial 且无异常及身份变化的调用只计数，不能解释成完全没有像素工作。最多保存 32 条其余区间，第 33 条使诊断无效并解绑。结束后统一输出，不在回调中序列化日志。

当前仅源码准备和纯检查，未编译、未 AIR、无性能或部署资格。
