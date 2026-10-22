# 绘图固定桶诊断

旧运行 `84ff2d9da3` 因正耗时重复调用挤满 32 行而失败，结果保持 FAIL。本版只改外部观察器，使用不同的 `ensure-work-aggregate-v1` schema；旧记录不能按新规则追认通过。

重要调用仍最多 32 条：首次绘制、resident 变化、未完成、身份异常、时钟异常和元数据错误都逐条保留。第 33 条重要调用仍使记录不完整并解绑。成功、身份一致、时钟有效且 resident 前后不变的重复调用，无论正耗时或零耗时，都进入固定三个桶：目标房间、尚未绑定目标、其他房间。

每桶保留调用数、正/零耗时数、总与最大耗时、首末本机时钟和墙钟、调用序号边界、房间身份变化次数、resident 变化次数。稳定 resident 仍可能有绘图，汇总不是忽略其开销。回调中不输出日志或枚举对象；重要行外只有固定桶及三份房间引用。任何异常仍使诊断失败。

原三场景、1000 ms / 3 帧 / 95 秒等断言不变；`FirstRasterSceneProbe.as` 从冻结旧版本逐字复用。准确组合仍为 early2 D356、宿主03 29D36、Sand003、实际注入 RV7852。安装准入另立当前 RV187D 的单项变化，其他 21 项固定；旧冻结输入和报告均不改。

组件入口为 `tests/PaintTimingBufferChecks.as`，38 条断言已经由根执行，结果 38/0。helper SHA `b8684081e88fccba936ab987710e22bf735ef7daf1297357e791d91b9c8ce56e`；组件 SHA `5e7610ac7dfb98668522c60d12c5b5672d79c56749a6e575dba2bb52d2533f3e`。这是缓冲器功能检查，不是新完整场景或性能合格。

根会话在本目录共同审查后串行执行：

```text
python -B -X utf8 experimental/recovery-early-paint-aggregate/check.py
python -B -X utf8 experimental/recovery-early-paint-aggregate/freeze_sources.py
python -B -X utf8 experimental/recovery-early-paint-aggregate/runtime_check.py
python -B -X utf8 experimental/recovery-early-paint-aggregate/prepare.py --output build/m52/recovery-early-paint-aggregate-driver-01 --build
```

`prepare.py` 精确复用旧构建函数，只替换 schema 名及两处证据文件名；内存检查、登记、编译错误处理不变。`binding.verify_driver(path,meta,scenario)` 仅接受 `scene-native-input-early-paint-aggregate-driver` 与新 schema，并逐项核对源和产物。编译后运行准入单独冻结为 `runtime-inputs.json`，入口由 `freeze_runtime.py` / `run_native.py` 管理；`inputs.json` 只冻结构建源，不预授运行资格。

`audit_profile.audit_log(path)` / `audit_profiles(profiles,travels)` 严格要求每侧三段、原 TRAVEL RESULT 内嵌数据一致、重要行与固定桶总账一致、有限单调时钟、完整目标区分、所有权保留，且 faults/nativeFaults/overflow/身份错误均为零。结果始终 `diagnostic_only=true, performance_qualified=false`。此诊断只用于定位真实绘制耗时；不修改生产逻辑，也不增加 CPU 采样。
