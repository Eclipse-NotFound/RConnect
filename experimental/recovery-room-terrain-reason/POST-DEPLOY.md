# roomfix5 部署后的诊断入口适配

**12:39后状态：此入口已不适用于当前安装。** 正式ModLoader随后从BD71更新为2050E023；本入口会正确拒绝额外环境变化，不再续加适配或运行它。此前的静态审查和 `--check` 是当时环境的结果。新的单实例机制取证使用实际当前输入独立冻结，旧产品和回执不改写。

现已实现独立 `post_deploy.py`，并只运行 `--check` 通过；未编译、未启动 AIR。原诊断源码、构建产物、驱动与运行脚本保持冻结。

## 可复用的准确产物

- 诊断产品 `build/m52/recovery-room-terrain-reason-product-01/RConnectMod.swf`：`9a128737ce470127db16ff903fe0bcbdd8280daead0f714c983515c52a14b1ef`。
- prepared：`9650b504612a8a279d477f06a6ceceb5ebfc9896d58cdf168f0c2268aeadfb21`；compile：`2402bbca756801456adf4431661a60cdb80bca6e812055d2f3260cf9676a856c`。
- 不变的三程场景驱动：`build/m52/recovery-room-scene-driver-02`，沿用原 Harness 和全部断言，不重编。
- 原诊断运行入口 `run.py`：`d15e9722bfbddb2b41c65b0a097a9d7685046f013309ba3d2ada755407f69d0e`。

## 最小实现

独立 `post_deploy.py` 绑定真实回执 `build/m52/recovery-room-user-deploy-01/deployment.json`，SHA `16ef10ba4f2a5393fd41efe0648ea55a051dd9d5dd7c9efeab722ee66d4eabe4`；仅引用实际执行的 `deploy-executed.py`（639166DB），不引用其后来未执行的加固源。

1. 历史诊断产物验证：复用原 `source_check()`（本函数不宣称当前安装通过），核原 prepared/compile 的完整源码、tools、inputs、files、artifacts、两条成功且已回收的编译命令。原三份 installation 表必须仍等于真实编译时 A796/RV0DBE/DF0F 的22项；不把历史改写为78C052。
2. 历史驱动验证：复用 `current_rv_verifier.artifacts()` 与原来源 pins，保留原80CF/6DBA构建环境；不调用要求旧正式RC的 installation 分支。另核 scene 两个不变 AS、timing SWF 和精确 scene 适配来源。
3. 当前安装验证：核真实部署回执、回执引用的备份/候选/验证证据，再实扫22项。只有正式 `mods/Rconnect/release/RConnectMod.swf` 可从 DF0F 变为78C052；其余21项逐项完全相同。回执尚未知、未成功、回滚或实际字节不符均拒绝；具体成功字段以真实回执 schema 为准，不能凭路径存在认定部署成功。
4. 将上述独立函数放入一个明确的 `prepared` 代理对象，交给独立加载的原 `run.py` 模块。代理的 `verify()` 明确验证“历史编译产物 + 当前实际部署”，`installation()` 始终返回实际安装。原 prepare 模块和其 installation 函数均不修改；不伪装它通过了新安装。
5. 原 run 的三处候选文本适配、三程原框架、偏好文件、内存门槛、共享登记、实际运行输入、错误扫描、收尾和首拒因分析全部复用。新入口只追加其自身、部署回执及引用文件的指纹，不创建新刺激或缩减任何断言。

运行环境证据分别列原驱动编译、诊断产品编译、实际部署后三个对象。原 `result.json` 仍为功能判断，原因取证仍写独立结果，所有性能资格保持 false。

准入边界：部署事实证明当前正式文件变化，不证明9A诊断已跑过，也不证明加载达到单人时间。部署回执中的 smoke pending 与性能未合格作为历史事实保留，不能冒充已完成安装后复验。

在 RConnect 目录用本机 Python 执行：

```text
experimental/recovery-room-terrain-reason/post_deploy.py --check
experimental/recovery-room-terrain-reason/post_deploy.py --output build/m52/recovery-room-terrain-reason-native-01
```

默认且唯一产品是上述9A诊断；若显式传 `--product` 也须为同一准确目录。运行仍只由根会话执行。入口没有编译或部署功能。
