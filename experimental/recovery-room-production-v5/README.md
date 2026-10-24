# roomfix5 隔离文本配方

准确前版是 `build/m52/recovery-room-production-04`，SWF `34A17DE66E9A89165B4BDE75D22EC1DD3D4295BB496B903124687AF80422B703`。本轮只改两类：`MirrorMasks.as` 首次引用扫描增加 `attached(nativeMask,v) && v.mask!==nativeMask`；`RConnectMod.as` 版本变为 `0.2.24-roomfix5`。没有加入诊断计数、网络缓存或新的接口。

`prepare.py --prepare` 只生成本目录文本源码、差分、原样复用的 v4 `build.py` 与指纹；`--check` 回读所有冻结来源、前版实际完整源码及工具、编译回执和最终两类增量。不编译、不启动 AIR。前版 overlay 必须与 aura1 完整基底重建出准确 roomfix4，候选完整源码清单必须只比该实际 roomfix4 差两类。遮罩源码还必须逐字等于独立组件提案，且与前版只有一处可逆替换。

为保持原编译脚本接口，`BASE` 仍指向准确 aura1 `DF0F…01E7`，`src/` 保存完整累积 overlay；这不表示本轮重新实现旧改动。`incremental.diff` 和 `incremental_changes` 明确本轮仅两类，`source.diff` 则是相对 aura1 的完整差异。v4 `build.py` 原始字节不改，仍保留登记、两次 Java、内存门槛、自有进程回收、编译源检查和安装前后 22 项检查。实际运行环境按新构建时的回执记录，不能把 roomfix4 历史环境当作现在的安装环境。

当前仅源码准备；组件与真实恢复、房间流程的运行结论由根会话另行核验。没有编译通过、性能通过或部署资格。本目录不改原候选、正式源、安装版、其他模组或既有测试驱动。
