# 首绘之后的 CPU 尾段诊断（仅隔离入口）

只在原聚合观察器已记下“目标房间、原生 ensure 成功、resident 从 0 变为正数”后开始采样，下一次 **stage ENTER +1000000** 先暂停再整理。每段至多一次、共三段；helper 是实际组件03通过 **31/0** 的冻结 v3（1d35215b…81c61）。这段可能覆盖绘图方法之后的约两秒空档，也可能不覆盖；以真实起止时间和栈为准。

`observer.patch` 是全部 AS 接入差异。原三段场景、实际按键、1000ms 静止门槛、3帧恢复断言、95秒超时和聚合审计均保留。宿主仍 host03/29D3，RConnect early2/D356，Sand003/3E22，运行时 RV7852。安装基线只接受根已读回的 RV6593，其他21项不变；旧准备记录中的 RV187D 仅作为明确的来源差异。编译继续 `debug=false / optimize=true`，栈文件/行号缺失原样保留。

记录分为 `EARLY PAINT TAIL`、`EARLY PAINT TAIL OUTPUT` 和最终 `SUMMARY`。`collectMs` 已包含 `cleanupMs`，两者不能相加；编码与日志写入成本单列，最后的小型计时标记无法自测自己的输出成本。采样整理同步发生在下一 ENTER，会推迟后续原生逻辑；本轮的原生耗时、FPS及窗口总长都不能直接与无采样轮作性能比较。截断、异常、替换、未触发或没有CPU样本不获得完整 CPU 证据，更不授予性能/发布资格。

唯一采样入口的依据：实际通过组件的 helper/adapter 精确复制；其余实际加载的23个 SWF 解压检查不含任何采样API名称。准确 host03 有 `flash.sampler` 命名空间常量但没有这些API名称，只对该固定指纹允许此无调用常量；其他文件不豁免。此检查针对已知冻结代码，不声称排除外部附加分析器或人为混淆的动态名称。沿用独占AIR、唯一存储、原测试登记及全部原错误审计；不启动外部分析器。

新入口还在取得共享登记后、任何私有副本或AIR之前，比对外层本轮预定22项安装清单、当前安装与预先接受的准确基线；任何变化直接拒绝并写 `installation-gate.json`、`error.json`、`result.json`。外层异常也保留失败回执；旧成功/失败日志不改写。排队后不动态追认新的部署。

根审查后的顺序（本目录准备者不编译/不启动AIR）：

1. `check.py`：只读源、准确组件31/0、薄包装及安装变化反例；不冻结。
2. `freeze_sources.py`：扫描准确加载输入，保存源码与采样独占依据；拒绝覆盖已有冻结。
3. `prepare.py --output build/m52/recovery-early-paint-tail-driver-01 --build --registry-wait 900`：复用原构建，原三份断言源码逐字复制。
4. `freeze_runtime.py --drivers build/m52/recovery-early-paint-tail-driver-01 --expected-host-sha 29d36cdd94aadc5368156f80e854808d78b74baf8347ebfcc80c644d73601ef7 --expected-review-sha <host03实际独立回执SHA> --expected-driver-sha <刚构建的EffectsDriver.swf实际SHA>`。
5. `run_native.py --candidate build/m52/recovery-early-exit-compile-01 --drivers build/m52/recovery-early-paint-tail-driver-01 --game-candidate build/m52/recovery-early-paint-host-03 --output build/m52/recovery-early-paint-tail-solo-01 --scenario scene --solo --sand-mode bridge --registry-wait 900`。

先做一次单人实际尾段。双人仍受原6GiB启动门槛约束，未另设放行；本轮没有编译或原生运行结果时不得据源码宣称有效采样。
