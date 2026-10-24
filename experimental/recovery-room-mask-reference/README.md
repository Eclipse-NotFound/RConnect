# restore 首次引用扫描：条件性省略提案

准确基底为 `build/m52/recovery-room-production-04/src/rconnect/game/MirrorMasks.as`，SHA `B4283CF68870010C4D454A6C7D511F00DBC5C3540E1839F878DFE680084F5E24`。产品只有一处条件改变：首次 `maskReferences(rootRef,refs)` 增加 `attached(nativeMask,v) && v.mask!==nativeMask`。退休遮罩的 `remaining` 扫描、capture、snapshotMask、clean、所有者判断与异常处理逐字保持。

理由：`refs[nativeMask]` 只在随后的 `active && attached(nativeMask,v) && (v.mask===nativeMask || !refs[nativeMask])` 分支中读取。nativeMask 不再附着时不会用到 refs；v 已持有自己的 nativeMask 时短路也不会用到 refs。这不是减少视野更新或跳过所有权检查。这里不提前增加 `active` 条件，不重排 renderer API 调用。

`prepare.py --prepare` 只在本目录写文本源码、精确差分和指纹；`--check` 只读验证。不含编译或运行操作，不能覆盖已有冻结提案。

组件 `component/MaskReferenceComponentDoc.as` 同时调用实际旧类和实际新类。旧类只将声明名改为 `MirrorMasksReference`，所有方法原样；新类与产品提案逐字相同。二者每个案例均新建独立且实际挂到组件 Stage 的显示树。仅用公开属性读取的 GameBridge stub 和 body/vis/hpbar 身份 stub，不加载游戏或 RV。模拟的 RVExplorationAPI 只给 active 开关，不模拟 RV 生成遮罩的算法。

14 类情形覆盖 nativeMask 为 null、无初始 nativeMask 后出现 alias、native 脱离、自己持有、空闲 native 被恢复、native 已被另一个对象持有、alias 退休后被其他对象持有、后来出现新 owner、active=false、release/restore、原生 body 字段替换、无 alias 的 release、forget 和 owned copy 清理时新 owner 接管。每端核明确预期，再逐状态比较归属、可见、缓存、附着显示树和完整 ARGB 图像；独立副本另核实际源遮罩像素，确保不抢其他 owner。原始 bitmap 在清理时仍可读取；异常和清理失败均记录为失败。

组件不能证明真实 RV 执行次序、敌人数量、加载收益或原生游戏兼容；当前没有任何运行通过结论。根会话可用既有 `tools/validation/run_recovery_component.py` 以本目录 `component` 为 source、`MaskReferenceComponentDoc.as` 为 entry 在新 build 输出编译运行；根负责原登记、内存、私有桌面、错误和清理门槛。通过后仍须真实 `MirrorMaskRestoreTestDoc` 与目标加载流程回归。未改该真实驱动、正式源、安装版或其他模组。
