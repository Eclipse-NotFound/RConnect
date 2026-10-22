# 墙痕改传原生绘制指令：有限可行，不能直接替换像素包

2026-10-22，只读可行性核查；未实现、编译或运行。准确 native 输入是 `build/m52/recovery-early-host-01/after/scripts/fe/graph/Grafon.as`，SHA `e6b4142462c1187388c4bb9c8151dd6c2605ce4e4b9fedd421cf4749c54bd7a0`，与 ACC 回读全文件相同。RC 接口读取 early2 的 `WallSurfaceBridge.as`（SHA `527e045129068f2c1153e9d843add5bddde07554dfef33a450937512bfa21b99`）。下述 22 点失败属于准确 RC22+ACC，数据量属于 RC20 的既有实测，不冒称同一候选的新测试。

**判断：已知原生弹孔有条件改传短指令，能避开逐像素读取、编码、传输和解码；但要保留现有效果，必须先解决共同绘制顺序、基底和结构生命周期。现有接口不够，尚不能给提速比例或进入实现。** `recovery-socket-batch-review/independent-review.md` 实际有 5 格/41600 字符的完整包；同轮还有不带墙痕的 100ms 快速同步，因此即使省掉墙痕，也不等于解决全部卡顿。

**已有基础。** 准确 Grafon `sceneApply:1173–1264` 已为大图建立 `[kind,args,stamp,affected]` 历史：decal 的 args 含两个图案 Class、世界位置、缩放、旋转和混合模式，stamp 固定两个随机选帧值；`sceneSave:1496–1505` 甚至已有 Class 名称序列化。`decal:4687–4758` 真正创建图案、选帧并绘制，适合观察已解析的绘制参数。一次命中若只需几十个标量和少量分区矩形，数据量会明显小于数千像素；这是结构上的潜力，尚无实际节省测量。不能重放 `dyrka`：它还随机选图案/比例/角度并发射粒子；也不能重放 `tileDie`，否则会重复碎屑等副作用。这里讨论持久墙痕，不取代火星粒子同步。

| 必须补足的窄接口 | 原因与准确位置 |
|---|---|
| 普通房与大图共用的“已解析绘制操作”通知 | 现 `rconnectWallBridge` 是静态 Function 槽，只有 mark/before/after/raster；RC `onNative:71` 明确只收大图。普通房缺通知。需在实际选帧后记录资产身份、帧、world Matrix 六值、ColorTransform 八值或 null、blend、smoothing 与实际裁剪；同一个原生操作只出生一次，不能把分块/预热/重画计成新命中。 |
| 纯绘制回放入口，允许传确定帧/参数且抑制回报 | sceneApply/sceneStamp/sceneRestoreMarks 都是 private；外部直接调 public decal 会重新抽帧，大图又会新增随机 stamp。需由 Grafon 内部执行相同绘制算法，不调用伤害/掉落/粒子入口。Matrix 与 MovieClip.rotation 的现有单位用法不同，不能“顺便纠正”数值。 |
| CS 最终分区裁剪/颜色语义 | `sceneApplyRegionAction:1723–1816` 会保存基底、切换区域 cTransform、多次画、按 clips 复制后合成。只抓某次 draw 的 null clip 或当前 cTransform 不够；需保留真正生效的世界裁剪及每个分区颜色，避免 core/gutter/废弃预热副本成为重复命令。 |
| 结构代际与有序持久回放 | 需要明确普通弹孔、tileDie 结构擦除、gwall 新增、同 BitmapData 的 drawLoc 重建，以及房间/权威交接。接收命令去重、原地预测、ACK 和重访历史必须共享同一顺序与基底；旧存量墙痕也要保留，不能清历史换轻包。 |

**主要不等价不是随机数。** 原生 decal 不是单纯盖贴图：先 erase，再保存**当前前景** alpha，按 normal/hardlight 等模式 draw，最后恢复 alpha；大图路径同样如此（1099–1122、4716–4758）。因此相同图案/帧/Matrix/ColorTransform，遇到不同旧颜色、alpha 或不同到达顺序仍可能产生不同结果。Class+帧也尚未证明足以重建所有嵌套时间轴/滤镜状态，资产与运行时需匹配，不能以地图种子代替这些条件。

**旧反例直接限制方案边界。** RC22 的原生普通房 `215270505b` 在相邻 phis=0 格有 22 个真实墙沿变化丢失（`recovery-ordinary-wall-review`）：完整原生绘制区域理论上能覆盖它们，不应再按碰撞格硬裁。可是 `recovery-ordinary-wall-edge-component-02/component-result.json` 实际 136 项中第134失败：先把同像素擦空，再接受晚到非零墨迹，逻辑 ACK 接受但画面不收敛。当前协议按**后到的绝对颜色**接纳，纯指令在空 alpha 上重画却会保留空 alpha；这是不同语义。必须从共同基底按确认顺序重建/校正双方预测，不能把操作包直接塞进旧 put/ACK。`recovery-wall-core-ownership/interface-risk.md` 的 core/gutter 与同色 ACK 屏障也仍适用；其额外组件当时仅静态预测，不冒称已实跑否决指令方案。

**停点。** 没有发现“完整原生指令同步已被实测证伪”的证据；被否定的是随机重放、当前 alpha 猜支持和忽略权威次序等捷径。完整方案会把当前绝对像素状态同步改为有序操作历史，历史随高射速增长，重访/重建回放也有成本；若要压缩历史，仍需一致基底或检查点，不能无限累积也不能删除持久痕迹。建议先把以上四个缺口视为实施前契约，不在现有失败候选上零散接线。未证明普通房、CS 分区、透明重叠、毁墙后迟到包与重访都等价之前，保留现像素路径及失败证据，不宣称可替换。
