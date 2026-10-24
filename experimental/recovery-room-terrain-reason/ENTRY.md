# 准备与运行

本入口只用于查首个不能复用地形画面的原因。诊断产品版本为 `0.2.24-roomreason1`，不可部署。当前仅静态检查；根会话统一编译和 AIR。

在 RConnect 目录使用本机 Python：

```text
experimental/recovery-room-terrain-reason/prepare.py --check
experimental/recovery-room-terrain-reason/prepare.py --output build/m52/recovery-room-terrain-reason-product-01 --build
experimental/recovery-room-terrain-reason/run.py --product build/m52/recovery-room-terrain-reason-product-01 --check
experimental/recovery-room-terrain-reason/run.py --product build/m52/recovery-room-terrain-reason-product-01 --output build/m52/recovery-room-terrain-reason-native-01
```

不加 `--build` 只冻结新目录；`--verify <已有目录>` 只复验。所有输出不可覆写。`run.py --check` 不带 product 时只核源、原驱动与当前安装，明确 `candidate_compiled=false`，不能因此启动测试。

编译复用已核 `loading-counters/prepare.py` 的 `compile_output`，只在独立模块对象中替换准确 verify/installation 两回调，不改原脚本或全局 subprocess。保持登记、编译前 1 GiB、512 MiB 运行保护、hidden Java、子进程 finally 回收。产品05编译来源 ABE2 与本次实际 A796/RV0DBE 分别登记；不以历史安装清单伪装当前。

原 `scene-driver-02` 的 AS 与 SWF 不重编、不改。薄运行入口只替换旧 native_v4 的两处候选 token 和一处版本文本，再显式绑定新产品校验、历史驱动校验、真实安装及证据回调。原三程、场景偏好、实际输入、错误扫描、双人 6 GiB 启动门槛、512 MiB 保护和收尾全部保留。没有新宿主、协议、玩法或广义测试框架。

原 `result.json` 保留功能判定；独立 `terrain-reason-result.json` 记录诊断完整性，`join-terrain-reason.json` 保留原恢复整行与 join 日志 SHA、行号。`passed` 仅表示原功能通过且取证完整，`non_reuse_observed` 另列是否真的观测到拒绝；如果实际复用成功，不伪造原因。所有性能资格固定 false；本候选新增调用有观测开销，不能用它的加载时间给生产优化授资格。
