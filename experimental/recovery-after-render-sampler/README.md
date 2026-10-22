# 原 RENDER 采样窗之后的 CPU 诊断

只诊断，不作 FPS 或发布资格。沿用准确 driver03：10 份 AS 原字节不变，`SustainedDensityTestDoc` 仅改 5 处明确的诊断代码，新增 `AfterRenderProfileTestDoc` 入口。准备、武器 ready 条件、80 身体 / 12 枪 / 七阶段刺激与全部门槛不变；[diagnostic.patch](diagnostic.patch) 给出完整差异。按声明反向去除诊断差异后，原文件文本逐字恢复。

遵照限定，保留旧 `diagEnd` 的 **stage RENDER -1000000** 和旧 `diagBegin` 的 **stage ENTER +1000000**：在旧窗结束处启动，下一次原 ENTER 钩子先暂停，再整理。没有改到最高优先级 RENDER，因此不重新包含旧窗已覆盖的显示回调。“最先”仅指这套 stage 监听器；不宣称早于 AIR 对其他 DisplayObject 的全部广播。

每阶段仍用原第 1、6、11、16、21、26 帧选择，phase 0/1/5/6 各最多 6 窗，其余不采。跨 phase、退出 load、finish 均先停止并标未完成；重复 RENDER 不重启，缺少 RENDER 不借下一帧。保留原帧时刻，同时分列：

- `at / after / renderAt`：原 ENTER 开始、ENTER 尾部、原 RENDER 尾钩子入口。
- `startCallAt / start`：调用 startSampling 前、调用返回后立即读时钟。
- `stop / pauseReturned`：下一 ENTER 入口（取消则是取消点）、pauseSampling 返回时刻。边界调用本身的少量指令可以据此界定，不能假称零开销。
- `collectStart / collectEnd / collectMs`：采样已暂停后的枚举、构造栈字符串与留存耗时，排除在目标采样窗口之外。

窗口仅保留 CPU 栈，跳过 NewObjectSample/DeleteObjectSample，不保留被采样对象或分配汇总。时间行上限 4096、每窗不同栈上限 1024、栈深度 64；超限明确计数。没有 CPU 样本的墙钟时间仍是未知，不能直接称休眠、等待或 GPU 时间。

复用原登记构建、同一 profile-settings wrapper 与两份冻结 RV 设置。1 GiB 编译、6 GiB 双开启动、512 MiB 运行保护及真实用户设置起止哈希校验不变。原失败保留；`cpu-profile.json` 单列新窗口时刻和 CPU 栈，`actual_runtime_errors` 区分合法 PROFILE 数据中的错误名称与真实 COOP FAIL/异常。

在 `mods/RConnect` 下由根会话串行执行；本交付未编译/AIR：

```powershell
$py = 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
& $py -B -X utf8 experimental/recovery-after-render-sampler/check.py
& $py -B -X utf8 experimental/recovery-after-render-sampler/sampler.py --output build/m52/recovery-after-render-sampler-drivers-01 --build --registry-wait 900
& $py -B -X utf8 experimental/recovery-after-render-sampler/run.py --candidate build/m52/recovery-20 --drivers build/m52/recovery-after-render-sampler-drivers-01 --output build/m52/recovery-after-render-sampler-20-01 --registry-wait 900
```

静态及 Python 生命周期模型 **61/0**；不冒充 AS 执行或 AIR 事件顺序验证。检查涵盖预算、取消/结束、整理排除、原文恢复及冻结依赖。原采样结果 `043b72eaec` 不改动、不改绿。
