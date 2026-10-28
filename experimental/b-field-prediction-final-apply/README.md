# 加入侧本机预测末次绘制候选

状态：仅源码候选与观察辅助，未编译、未运行、未合入。**尚无实际命中率或性能收益证据，不能作为已完成优化。**

准确基线：`build/ab/b190-visual-motion-clientenv-source/src/authority/ClientReplica.as`，SHA256 `EEF7A6B86198E53FF0377FE2857E8F0CAEE071E3BCDCBDF125598DFDEA0432DE`。本目录保留修改副本和完整 diff；不修改 root 工作源。

## 改动与决策顺序

原流程：全部离散确认逐一 render/confirmed → 插值 scene → 本机及对侧 applyPlayer → 弹丸和 prune → prediction.sample → 本机预测 applyPlayer（或撤销预测）→ light → pointer。

候选流程：全部离散确认保持原样；只有满足资格时，将插值里的本机 applyPlayer 延后。其它角色、场景、弹丸和 prune 保持原顺序。**到原来的 prediction.sample 位置仍只采样一次**：

- 预测非空：只应用最终预测，本次省掉中间的本机 applyPlayer。
- 预测为空：先补原本机插值，再照原来的 predicted/room 条件撤销预测。
- submitted() 的即时预测路径保持原样。

这里保持采样的决策位置、参数来源和分支语义；不是保证优化前后 getTimer 的实际毫秒数相同。最初“提前 sample 再决定是否跳过”被放弃，因为它会主动提前 150 ms 断流与 100 ms 预测长度的决策位置。

## 必须保留的回退边界

- 任何离散确认；paused、SATS、菜单暂停、Sandevistan 回放；没有安全地面运动描述。
- 本机身体/武器未建立、引用或武器 epoch 不同、所在显示层不对、根遮罩存在、宠物引用需要调整。
- 正在抓取、交互，或本机还保留抓取/交互引用。这些分支还会更新供 GUI 使用的缓存对象，未作为可删除写入。
- 旧中间位置有某个 motion 字段，而最终预测没有；原写入可能残留。
- 后一个 visual 不能完整覆盖前一个 visual 的写入。

最后一条由 `PredictionPoseCover` 证明：比较**clock.current 与 lastFrame 的原始 immutable pose**，按两者对象身份作双层弱缓存。检查旧 pixels/vector/frame/颜色/文本/滚动等条件写入是否会被新值覆盖；对子节点要求相同名字、索引、类与数量，并递归核对。隐藏后缺 children、丢失向量/像素、增删或更名部件一律回退。不是按每屏幕帧新建的补间对象做缓存。

确切旧方案失败边界：VisualPose.apply 不是替换整棵树。后一个隐藏节点没有 children 时，旧 children 会保留；后一个没有 vector/pixels/text 时，旧内容可能保留。因此不能仅依据“最后总会预测”直接删掉旧树应用，之后 SATS 显影或显示恢复时可能露出差异。当前候选没有忽略这些子树。

## 中间状态依赖核对

- `ReplicaScene.light` 读取 gg.X/Y，`pointer` 用 gg.X/Y 计算距离；两者原本就在最终 predict 之后，候选仍如此。
- `applyProjectile` 读取各弹丸的确认字段、当前 loc 和图层，不读取本机临时位置。弹丸创建、结束事件、去重和删除不改。
- `ReplicaScene.prune` 只读取保留的显示根、根遮罩及其父级，未读取本机坐标。前置资格要求身体和同一武器已在正确层、没有根遮罩及无需更换宠物，避免将 native addVisual 或重挂层移到 prune 之后。
- 原生 Unit.setPos 重写自身坐标、边界、瞄准几何；setVisPos 重写自身显示位置。最终预测会覆盖这些字段；任何缺失 motion 字段回退。
- SATS 截图路径不延后；离散 GUI、伤害消息、破墙、add-on 状态、声音等都仍逐一处理。

## 必须实际观察，不能用合成例子代替

候选增加 4 个只读计数：`localInterpolationCandidates`（通过实体护栏）、`localPoseCoverageRejected`、`deferredLocalInterpolations`、`skippedLocalInterpolations`（真正被非空预测替代）。PredictionPoseCover 另有 proof checks/hits/failures。

`tests/BPredictionCoverChecks.as`：

1. `run(domain,check)` 验证正负覆盖、缓存、旧 recipe 不变，以及隐藏树/向量/像素/文本/滚动/原生部件残留必须拒绝。
2. `nativeCurrent(mod,domain,check)` 读取**实际加入侧**当前与最新玩家 pose。资格通过时，用真正的身体/武器类创建两个临时显示对象，对照 `apply(old);apply(new)` 与 `apply(new)`，逐层比较包括隐藏部件的 root 数据、实际像素、节点数/类型及遮罩有无。该检查不能在性能计时段运行。

实际通过门槛：普通静止、左右平地移动各自出现 `skippedLocalInterpolations` 增量，且实际 body/weapon 覆盖与所有隐藏子节点对照通过；若平地移动无法命中，保留为诊断，不合入。当前历史 profile 与 motion18 文件只保存耗时/汇总，没有原始 pose，不能据此填造成功次数。

事件顺序复核：相同输入回放的 confirmed tick/serial 顺序、scene 应用数、破墙次数、伤害数字消息、projectileApplications、短命弹丸次数、SATS 截图 epoch 一致；停预测/按 Q/开火/开菜单后，本机最终姿态、位置、武器指向、hover/光照应一致。playerApplications[1] 允许仅减少真正 skipped 数，其他角色不能减少。分别测等待最新确认、超过 150 ms、换房/复活、武器切换、遮罩/挂层恢复、宠物、隐藏/显形和回放。最终再比 frame/present/players 成本，覆盖检查开销必须算入。
