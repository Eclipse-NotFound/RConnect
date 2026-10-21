# 原生气体驱动 v2：只修外部夹具

基线为实际失败的 `build/m52/recovery-gas-driver-01/tests`，准确祖先摘要见 `native-plan.json`。`generate.py` 校验祖先 SHA 后生成两个 AS 文件，`driver.patch` 给出全部增量。没有修改候选13、旧驱动01、旧运行4733dbf4b4或其34条出生、4条像素及超时失败。

本目录只准备源和纯 Python 自检，**未编译、未启动 AIR、未证明原生通过**。父会话统一冻结、构建、实跑。仍为主单颗→加单颗→主双颗→加双颗，原26秒阶段时限、180秒启动时限、360秒运行总时限及冷启动首轮保持；不预热、不跳过第一轮。

## 修改

1. 第一颗通过真实 `gun.b` 新身份观测后，保持 G 松开，直至原生 `t_auto==0 && attackPos()` 才再次按 G。只读计数；不写 t_auto/t_attack/t_reload/rapid、寿命、位置或伤害。每次第二投记录只读 readiness gate，并独立校验它位于两颗实际出生之间。双颗同时在链内的原断言保留。超时附原生门控数值，正常热路径不增加日志。
2. 同一游戏帧多次 RENDER 仍合并到一条最终姿态，`at/wall` 保留该帧首次观察时间；`observedAt/observedWall` 标明最后一次真实观察，`revision/sampleId` 标明该帧第几次采样。出生时间不被替换。
3. PNG 截图对应的旧 sample 对象以不可变引用保存在该对象的 `captures` 中。后续 RENDER 换掉最终条目，也不会换掉截图身份。截图记录 visual/frame/sampleId/sampleAt/observedAt，以及 draw 前后姿态；必须关联唯一实际捕获版本，且截图期间姿态一致。每轮只捕获一朵一次，与原版相同。
4. 分析器校验捕获版本确实属于同一帧并不晚于最终观察；捕获姿态还必须来自同一唯一 wire 的有序区间。仍逐字段核对保存 JSON，独立解码 PNG 并重算差分像素。所有旧反例保留，补同帧覆盖、伪造捕获版本、截图中姿态变化、虚假捕获姿态、未松开防连发计数等反例。

**末采样遗漏仍为 FAIL。** 没有修改生产 strictEnd，没有延长动画，也没有放宽最后源姿态的检查。分析结果明确输出 `finalSourcePose: required; omission is FAIL`；精确 cursor 到 end 才移除仍为 unknown，`cursorAlignmentQualified/fullLifecycleQualified/performance_qualified` 始终 false。新夹具本身正确不代表原来的晚显示或末采样缺失已经修好。

`GasPulseNativeTestDoc` 新增“每次重复 G 等待原生 readiness”断言，每侧两次源场景各增加1条；没有删原断言。当前纯 Python 自检45项通过。它们只是生成一致性、记录格式和反例校验，不是 AS3 执行。

## 父会话入口

从 `mods/RConnect` 执行；输出必须为未存在的 `build/m52` 直接子目录。示例候选为准确13，可按后续冻结候选替换 source。调用 `--build` 才会经原框架启动编译器，本次没有调用。

```powershell
python -B -X utf8 experimental/recovery-gas-native-v2/check.py
python -B -X utf8 experimental/recovery-gas-native-v2/native_tool.py prepare --source build/m52/recovery-13/src --output build/m52/recovery-gas-v2-driver-01 --build --registry-wait 900
python -B -X utf8 experimental/recovery-gas-native-v2/native_tool.py run --drivers build/m52/recovery-gas-v2-driver-01 --output build/m52/recovery-gas-v2-native-01 --registry-wait 900
```

如需574D对照，运行命令加 `--control`，使用另一个全新输出目录；对照缺气体能力造成的失败仍保留。适配器沿用 `recovery-tests/{prepare,run}.py` 与 `run_coop_regression.py`，只登记 v2 单入口并冻结本目录输入，继承共享登记、唯一 AppID、独立桌面、延迟显示、wait-host-world、exclusive AIR、内存护栏、自有进程清理、全22项安装前后校验、准确候选/驱动哈希和双侧日志。没有自建另一套启动器。

输出 `result.json` 保留原运行器结果；`gas-verification.json` 必须同时满足原生原断言、完整四轮、唯一顺序对应、终止包与最后源姿态、24个保存证据及PNG重算，才可 passed。单看前者或计数相同不足以签收。

## 剩余边界

数据上限仍96个气体身份、每个128个逻辑帧；超过即失败。捕获额外保存每轮1个不可变 sample，不额外 draw、不写逐帧文件。draw耗时仍记录，结果只用于功能核查。粉色气雾、暂停、跨房及网络丢包恢复没有纳入本次四轮。

初始1–2.3秒显示欠账的最小插点计划见 `diagnostic-plan.md`；本次只列计划，未加任何生产或诊断插点。
