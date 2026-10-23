# 普通墙面 ACK 计时：隔离运行适配

本目录只负责诊断候选准入、私有配置开关、原四轮测试接续及证据复制。**不编译、不安装、不修改原驱动/断言、不授予性能资格**。主任务独占 `analyze.py`，此入口不调用或修改它。

固定组合：

- 产品：`build/m52/recovery-ordinary-wall-ack-timing-01`，由原隔离覆盖构建器从准确 C6A3 编译；覆盖源只能来自 `experimental/recovery-ordinary-wall-ack-timing/src` 的 1–6 个既有类，版本 `0.2.24-wallacktime1`，必须标 `diagnostic_only=true`。
- 宿主：已准入 `recovery-ordinary-mask-host-02`，SHA `6616b1a5d90e541980954ea8831949c5c5f72e945ef8378275567b9ade40289b`；独立准入回执 SHA `542d59fb6db55cad9891cb2beaf946921290790df7900112f1038995c7f7044d`。
- 驱动：原 `recovery-ordinary-wall-driver-01`，原四轮双向轻机枪/速射等离子、原精确 uint 像素分析器，600 秒。
- 安装：真实 22 文件仍为 EB365 正式组合，历史 C6A3/host05 审核只保留历史意义。

## 独立准入

`preflight()` 先调用冻结的 `recovery-ordinary-mask-native` 准入，因此原 C6A3 产品、旧 host05 绑定、原驱动及新 host02 的独立准入均真实复查。随后独立调用既有 `recovery-isolated-overlay/build.py.verify(PRODUCT)`，核新候选编译回执、全部源/工具/覆盖源/构建产物指纹、准确基底/版本及前后实际安装。

不修改旧 `wall.PRODUCT`、`wall.CANDIDATE`、`historical_product`、`verify_binding`，也不让它们冒充诊断产品审核。原驱动准备清单仍按原内容验证。运行前后的诊断准入、宿主、输入和安装必须相同。

## 私有配置单点

准确共享运行器 `tools/run_coop_regression.py` SHA 为 `7ECA453B…AE4D3`，没有通用 RConnect 配置透传参数。`private_runner.py` 读取并核验该源码，只在原 `run_registered` 内既有 `config.txt` 写入之前插入一行：

```text
_ack_private_config(cfg, release, output, role)
```

该函数只增加 `wallAckTiming='1'`，并先断言：输出是本次 `build/cooperation/<10位token>`，角色为 host/join，写入目录恰为该输出中的本角色 `mods/Rconnect/release`。它不写配置文件；仍由原写入语句完成，并由原运行器在启动前保存真实配置及指纹。正式配置无法通过此路径检查。

私有运行器限定准确诊断产品、host02、600 秒及原 effects/all-mods/private-desktop/defer-visible/wait-host-world/exclusive/keep-copies 参数。共享 `main()`、登记、取消、错误判定、内存监测与自有进程清理完全沿用；不新增登记层，不篡改共享文件。

原框架 `native_inputs` 只在配置预期中增加同一个 `wallAckTiming='1'`，继续把**实际完整配置**与预期精确比较，并核实际/保留配置字节指纹、全部 22 文件、驱动/宿主/候选、6 GiB 启动/512 MiB 运行保护及清理。没有删除配置字段后再审计的伪装。宿主替换仍使用原公开适配方式，安装读取永远是真实安装。

## 原框架复用边界

继续使用已冻结的五锚点 `shared.adapted_native`，显式绑定诊断产品及新宿主；唯一新增的调用路径替换是把其委托运行器指向本目录 `private_runner.py`。没有替换错误正则、DONE、轮次、超时、像素判据或清理函数。适配后的三个小函数源码会另存到测试输出，供回读核对：

- `framework-adapted-native.py`
- `framework-config-input-audit.py`
- `private-run-registered.py`

## 执行方式

从 `mods/RConnect` 目录执行，或给输出绝对路径。只有主任务运行；这里没有启动过 AIR。

```text
python -B -X utf8 experimental/recovery-ordinary-wall-ack-timing-native/run_native.py --check
python -B -X utf8 experimental/recovery-ordinary-wall-ack-timing-native/run_native.py --output build/m52/recovery-ordinary-wall-ack-timing-native-01
```

`--check` 只核验；候选未编译/指纹不符时失败。运行只能写尚不存在的 `build/m52/recovery-ordinary-wall-ack-timing-native-NN`；默认 `--registry-wait 900`。禁止 `-O`。

## 证据及结论边界

运行结束后先核实际 run 的候选/宿主身份，再从本次唯一的 `pfe-modsettings-rconnect-coop-{host|join}-<token>/Local Store` 复制证据：

- 原 `large-wall-proof` 四轮图像及 JSON → 输出 `wall-proof/{role}`，逐文件上限保持 32 MiB；原分析器输出原样保存到 `wall-surface-analysis.json`。
- 新 `wall-ack-timing/round-0.json` 至 `round-3.json`，每端四份 → 输出 `wall-ack-timing/{role}`；每份上限 8 MiB。只核 `kind=ordinary-wall-ack-timing-v1`、本次 `appId`、角色、轮号，原样保留全部内容并记录指纹、complete/termination/overflow/faultCount 等字段。

`ack-timing-result.json` 将以下维度分开：

- `functional_pass`：仅原框架成功、原像素分析器成功；原 `result.json` 不改。
- `diagnostic_evidence_complete`：八份诊断 JSON 均取得且身份/格式匹配，单凭此项不代表计时样本有效。
- `diagnostic_samples_ready`：八份均为 `complete=true`、`termination=analyze`、`bothSampled=true`，没有 overflow、dropped、faultCount/faults，且本次两侧日志没有 `WALL ACK TIMING OUTPUT FAILED`、存储中没有 `abort.json`。如有 abort，另复制保留；异常计时文件不会阻止原像素分析。这里仅核采集有效性，不计算 ACK 延迟或改变原业务判据。
- 外层 `passed`：原 `functional_pass` 与 `diagnostic_samples_ready` 成立且前后核验不漂移。完整时钟/事件关联和时延分析仍由主任务后续 `analyze.py` 处理；它不属于游戏输入闭包，也不参与原功能判定。

所有结果固定 `diagnostic_only=true`、`performance_qualified=false`、`gameplay_qualified=false`、`installed=false`。这次测量含产品内探针开销，不能直接把延迟差归因于未测的优化，也不能把既有功能通过当成流畅度通过。
