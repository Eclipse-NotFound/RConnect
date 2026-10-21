# 首轮墙面粒子延迟核查（2026-10-22，只读）

## 结论与证据边界

`40814ef14c` 的两侧 14 轮功能断言全过（主 106 / 加 104，无 COOP FAIL / TypeError / ReferenceError），但首轮收到命中事件到**测试在 RENDER 遍历中首次看见 Part**相隔 2,754 ms。这个末点不是 `BallisticImpactVisuals.play()` 的调用时刻，也不是 Part 构造时刻，因此目前不能将这段时间直接命名为“播放队列等待 2.75 秒”。

已确定其后的约 935 ms 含测试夹具同步像素检查、整屏截图绘制、PNG 压缩和写盘造成的阻塞。PNG 已移至全部动作采样结束之后；实际截图仍在原成功像素取样时刻 draw。**此前的 2,754 ms 发生在加入侧第一次截图之前，不能用这个修改解释掉。**

本次只读检查没有发现当前有效数据路径混用 Unix 日期毫秒与 `getTimer()`，也没有发现“首个有效带时间戳玩家包必然先把特效交给未初始化时钟”的顺序错误。真实队列、游标和原生发射调用之间仍缺内部观测点。下面给出仅用于隔离诊断副本的最小方案；本次未实施诊断源码改动、未运行 JVM/AIR、未改冻结候选。

## 核查输入

- 证据运行：[40814ef14c](../../build/cooperation/40814ef14c/)，实际生产候选为 **recovery-02** / `a7c87358ed73c6a8b39ba40db7896d5af34d1baeb70f05e9e37f4a9de7971b5b`，不是 recovery-03。
- 当前只读候选：[recovery-03](../../build/m52/recovery-03/) / `a98c6d00e85afad965ea2358c1bf4b8571a48f8e0c71ea244c68931e47a59cf1`。
- 两版 `ImpactEventQueue`、`ProjectileVisuals`、`RemoteMotion`、`BallisticImpactVisuals` 完全相同。`ProjectileFrameStream` 只新增采集端 `afterWithRevision`，接收/播放时钟方法相同。`GameBridge` 的本次接收、ENTER_FRAME 和 RENDER 路径也相同。可以用 03 解释这些方法的行为，不能把 02 的运行结果当作 03 实测。
- 日志指纹：host `3bd0e14553f5e030f33beba718d5f37f99fcf4e0f148abd8f53462674b9f208e`；join `a5739ae1d5a8f7f0d2ae31d741812a242d91ef76806b77b8c4e2e93c282e55cf`。
- 已延后编码的外部驱动：[EnergyImpactTestDoc.as](tests/EnergyImpactTestDoc.as)，当前 SHA256 `0cd8f51cea09d497ecea1ed6ff27fd94af54d07afde27d67766a836ab493e057`。旧运行用的 driver06 未改。

当前 03 相关源码 SHA256：

| 文件（`src/rconnect/game/` 下） | SHA256 |
|---|---|
| ImpactEventQueue.as | `0996719782f7238b4e38596ec72a8e273995d4efb1241514ca9e632d98cdc658` |
| ProjectileFrameStream.as | `938b8ee0d3afa262e4b23c608c6b46d9b84b6cb71f4cb4b148ccb445de3c679c` |
| ProjectileVisuals.as | `6e584f4ee777f9dda609c0bd9b7ad17e2189bdd8ac2a7519f11187c8fa313593` |
| RemoteMotion.as | `cd58b1286bc913149ac02ad60713e82c251b8e574043444b4f3ccfd6e4a2ebc5` |
| BallisticImpactVisuals.as | `516ce98fb6d9523c5eeb7b7c8e9c4ccb320d11a75594af26f3e3c6e3b8caf6eb` |
| UnitPresentation.as | `3b8049b3de582dd9559248c0370db230669233930cf50ab651babc1fe09179ce` |
| GameBridge.as | `e1cd085795e134ca293a5eb83fe44e22a0bc7edfb172f960a2c6a1e8bdec9260` |

## 已发生的时序

同一实例内用 `getTimer` 相减；跨实例只用日志中的 `wall`。不能拿宿主的 85,127 直接减加入侧的 47,393。

| 事件 | 文件行号 | 本机 getTimer | wall（Unix ms） | 能证明什么 |
|---|---:|---:|---:|---|
| 主侧真实 Bullet 接触墙，周围已有 5 个原生火星 | host.log:39 | 85,142 | 1792598885967 | 真命中及真实素材存在 |
| 主侧第一次看见 Part | host.log:42 | 85,154 | 1792598885979 | 主侧 RENDER 观测 |
| 主侧第二个 Part | host.log:43 | 85,173 | 1792598885998 | 首个像素尝试未必成功，可能继续尝试 |
| 主侧第三个 Part | host.log:44 | 86,070 | 1792598886895 | 与上一个日志相隔 897 ms，夹具同步采样污染 |
| 加入侧收到首个命中包，Session 保留同一 snap | join.log:38–39 | 47,392–47,393 | 1792598886102–6103 | source=85,127，impact.at=85,127，stream=15/seq=1，5 火星 |
| 再次收到同一命中的后续完整状态 | join.log:42 | 48,311 | 1792598887021 | gun.sampleTime=86,164，3 个轨迹点；不是第二次命中 |
| 新包中的事件窗口已清空 | join.log:48 | 49,031 | 1792598887740 | snap.sampleTime=86,895；此前已收到的命中由独立队列保留 |
| 加入侧首次在 RENDER 看见 Part | join.log:60 | 50,147 | 1792598888857 | 比首个 wire 迟 2,754 ms；此时粒子 liv==mliv |
| 加入侧第二个 Part | join.log:61 | 51,082 | 1792598889791 | 同一粒子遍历被同步像素/截图处理阻塞约 935 ms |
| 加入侧剩余三个 Part | join.log:62–64 | 51,084–51,085 | 1792598889793–9794 | 都仍 liv==mliv，位置一致 |

首个命中包距主侧真实接触日志仅约 136 ms（跨实例 wall）；网络收到之前不是这次 2.75 秒缺口的主要部分。包上的 `active=true / roomHold=false / paused=false / ghostSameLoc=true`，房间、epoch 均相同。日志没有记录队列入队、`sourceTime`、play 开始或结束；`sessionStored=true` 只证明 Session 保留了 snap，不能代替这些内部证据。

原生 Emitter 同步创建一组 Part；旧 `render()` 对第一个 Part 执行 `record → pixels()` 后才遍历下一个。单凭旧日志不能把 935 ms 全部分给 PNG 编码，也不能把第三个粒子的日志时间当作第三次原生发射。现驱动会记录 `renderFrame` 和各阶段耗时。

## 实际接收、时钟与渲染顺序

### 接收

1. `Session.handleMessage(MSG_WORLDSTATE) → applyWorldState → GameBridge.updateRemote`。
2. `updateRemote` 先校验房间/epoch，创建或取得 ghost 和 `RemoteMotion`。
3. 同一方法内先 `motion.push(snap, getTimer())`，再 `motion.sample(presentationTime())`，最后 `_projectiles.receive(..., motion)`（GameBridge:810–812）。
4. `ProjectileVisuals.receive` 先把命中交给 `ImpactEventQueue.receive`（ProjectileVisuals:75），随后才处理弹体序号/轨迹。已经移除的弹体、晚到的独立命中不因弹体序号丢弃。
5. 队列先 `ProjectileFrameStream.receiveClock`，然后把命中入 `pending`。`received` 是接收端 getTimer，`s.at` 是发送端帧时间（ImpactEventQueue:13–28）。

### 时钟

- 源玩家帧：`GameBridge.onPerceptionFrame`（ENTER_FRAME 优先级 90000）设置 `_sampleAt=getTimer()`。
- `readSnapshot.sampleTime` 使用 `_sampleAt`；`UnitPresentation.observePlayer` 使用同一 stamp；命中 `impact.at` 和 gun.sampleTime 都由这个帧时间产生。
- `RemoteMotion.pushTimed` 首个有效包同步设置 `cursor=stamp-delay()`、`sampledAt=now` 并加入 frames。玩家初始 delay=100 ms；常规自适应 delay 上限 250 ms。`sourceTime` 此时已有限，不等待另一个包才建立。
- 队列 `tick` 使用已有的真实 `motion.sourceTime`；只有没有有效 motion cursor 才退回 `now-offset-delay`。getter 只读，不主动推进时间。
- 队列只在 `sourceTime >= impact.at` 时调用 play；15 秒是过期保护，不是预设播放延迟。

对日志的**条件性推断**：后续 wire 的 gun.sampleTime 从 85,127 到 86,164，差 1,037 ms。若它同正常生产链一样带着对应的 snap.sampleTime 处理，则 `pushTimed` 的源时间间隔 >1,000 ms 分支会重建 cursor 到至少 86,064，已经越过 85,127 的命中。这样，48,311 到 50,147 这约 1,836 ms 不能继续简单解释为“正常 100–250 ms 插值缓冲”。旧 wire 日志第二条只输出 gun.sampleTime，没有输出当时的实际 cursor 和完整 snap.sampleTime，故这里只列出下一次诊断应验证的条件，**不认定已证明队列何时放行**。

### 实际回调顺序

相关 ENTER_FRAME 优先级由高到低：驱动 before=100000；GameBridge 帧戳=90000；原生/其它模组工作；驱动 after=-6000；GameBridge.onMirrorFrame=-10000。

`onMirrorFrame` 先采集源展示，再对远端玩家 `motion.sample(presentationTime())`，随后 `_projectiles.tick`。对敌人而言，`tickFrozenAnims` 位于这个 tick 之后；RENDER 再次 tick 时才能使用该帧刷新后的敌人游标。该次 case0 是玩家 LMG，不是 NPC。

相关 RENDER 优先级：GameBridge.onVisForceFrame=-10000；玩家光晕/地雷等；驱动 render=-30000；RoomSync 的最终加载 UI=-2000000000。

`onVisForceFrame` 在其展示采集/外观工作之后再次 `_projectiles.tick`，使用同一帧 `presentationTime()`，不再次推进玩家 motion。之后才到驱动观察 Part。两个生产回调均可能因 roomHold 提前返回；RENDER 另有 `_forcingVisibility/_animatingMirrors/_applyingUnits` 防重入。旧包日志只采了收包瞬间的 roomHold，不能证明后续每个回调均执行。

因此旧观测总间隔至少混合了：Session 接收处理、等待下一次展示回调、真实 cursor 等待、play/Emitter 本身耗时、生成后到测试 RENDER 的其它回调耗时。需要分别测量，不能用模拟游标替代实物游标。

## 最小观测方案（尚未实现）

### 严格保持候选二进制不变时的限制

实际 `GameBridge._remotes`、`ProjectileVisuals.impactEvents`、`ImpactEventQueue.pending` 都是 private。现有外部接口只有 `projectileVisualCount` 等数量，不暴露命中队列或其实际 motion 对象。现有 `presentationTiming` 只有聚合 view/motion 开销。仅在外部多加 ENTER_FRAME/RENDER 监听器，或另建一个 RemoteMotion 重放收到的包，都**无法满足“观察真实 cursor/queue”**。

不能为了日志调用 `readSnapshot`、`capture`、`sample`、`settle`、`push`、`tick`、`observe`；这些会消费记录或推进游戏/展示状态。也不应依靠普通 `probe` 去读取 AS3 private 字段。

### 推荐：一个诊断副本类插点，外部驱动负责收集

从准确 recovery-03 冻结复制到**全新诊断目录**，只给 `ImpactEventQueue.as` 加一个默认 null 的静态诊断接收函数；生产和现有 frozen 完全不改。外部驱动绑定到实际加载的那个类，并使用它的声明库，禁止另嵌一份同名队列类。这个副本只做归因，不作最终性能合格证据。

插点只读既有局部变量、不改变分支/调用次数/时钟：

1. **enqueue**：`pending.push` 后，记录 seq、s.at、s.groups 总数、pending 对象身份、clock/motion 身份、received、接收端 now；外部给对象分配只读观察编号。
2. **tick-check**：使用现成局部变量 `time`（即真实 `ProjectileFrameStream.sourceTime(a.clock,now)` 的结果），记录传入 now、实际 getTimer、pauseAt、received、impact.at、真实 `motion.sourceTime/latestSampleTime`、offset/delay、clockReady、loc 是否相同、pending 长度。不要额外计算或推进一次 sample。
3. **decision**：明确 wait / wrong-room / timeout / play / stale-impact 各分支的实际决定。即使超时删队列也留下终点。
4. **play-before / play-after**：包住原来的单次 `BallisticImpactVisuals.play(...)` 调用，只计时并读 loc.lastObj 身份；不得再次调用 Emitter。另以只读链观察确认调用确实创建了 Part，不能把调用返回当作生成成功。

诊断函数的外部实现只把标量写入有界内存缓冲；不在热路径 JSON.stringify、写盘、截屏或扫全房。仅启用 case0、最多 4,096 条，溢出明确标失败而非丢数据后称完整。对象身份表只为这一轮保留，结束清理。函数异常必须记为诊断失败，同时不可改变原队列分支；不得通过异常中断真实 play。

外部 Stage 监听器与收包监听器配套：

- TcpLink.MESSAGE 在 Session 之前/之后各一个优先级点，记录相同 msg 身份、source snap/gun/impact 时间、事件循环序号和 getTimer。现有 wire 是 Session 之后的点，不能当原始 socket 字节到达时刻。
- ENTER_FRAME 在 90000 前后各记录一个轻量边界；在 -10000 前/后各记录一次，区分原生/模组帧工作与镜像执行。
- RENDER 在 -10000 前/后、驱动 -30000 前各记录一次。仅改变诊断缓冲中的 phase 名称，不调用 stage.invalidate/updateAfterEvent，也不提前扫描素材。
- Part 首次链出现与首次最终 RENDER 出现分别记录。利用 play-before/after 的 lastObj 边界只读枚举该调用新加入的 Part，避免每次扫全房；若还需前序链观察，只在上述既定观察点执行，保存独立耗时。不要为了识别 atlas 提前调用 getSpriteList/getDefinition 去预热尚未使用的资源；用对象身份、Part 类和坐标先关联，素材/像素仍由原位置的断言核对。已有像素断言保留；PNG 在全部动作采样结束后编码。
- 外部回调运行耗时也计入统计；结束后再导出整个有界缓冲。保留 14 轮、冷首发、原有等待期限、功能/像素断言，不预热、不跳首轮。

诊断一轮应能拆成这些可核对区间：

| 区间 | 观测差值 | 判断 |
|---|---|---|
| Session 处理 | message-before → enqueue → message-after | 接收/ghost 构造/采集等成本 |
| 没有展示机会 | enqueue → 首次 tick-check | 帧调度或前序回调阻塞 |
| 真正等时钟 | 连续 tick-check 为 wait，直到 time>=impact.at | 必须同时给实际 cursor/最新源帧，不以估算替代 |
| 发射本身 | play-before → play-after | 原生 Emitter/素材初始化/构造成本 |
| 发射到观测 | play-after → 首次链出现 → 首次 RENDER Part | 展示回调、绘制或外部采样成本 |
| 外部截图成本 | 已有 IMPACT PIXEL TIMING / PNG EXPORT | 绘制与结束后的编码、写盘分开 |

若必须完全不重编任何生产类，则只能先做外部帧边界和粒子链时刻，报告“仍缺真实队列和 cursor”，不能宣称已满足这次诊断目标。以上是一类只读插点的建议，并非本次已经采取的修改。

## 独立静态边界检查

以下分开当前有效包路径与异常/迁移路径，不把静态边界冒充本轮根因。

1. **当前有效包没有绝对/相对时间混用。** `_sampleAt`、impact.at、flight.frames[].at、motion.cursor 均为源实例 getTimer；received/pauseAt/传入 tick 的 now 是接收实例 getTimer，通过 offset 或共享 motion 比较。`new Date().time` 在此处仅作测试 wall 和 Session 收包时间记录。roomEpoch 是房间代号，只作身份比对，不参与毫秒运算。AMF/JSON 编解码对这些字段没有专门变换。
2. **首包初始化先于特效接收。** 正常 `updateRemote` 给有有效 sampleTime 的 snap 执行 push/sample 后才 receive；`receiveClock` 又先完成 state.motion/offset/delay 赋值再入队。因首包必须等第二包才有 cursor 的解释与这条路径不符。若根本创建不了 ghost，该方法不会进入接收，而非把命中挂到未就绪 cursor。
3. **帧戳可暂时停住，但不是跨时区错算。** `presentationTime()` 平时返回本帧 `_sampleAt`，不是每次调用的当前 getTimer。网络回调在两个 ENTER_FRAME 之间执行时，sample 的 now 可比收包 now 旧；`sampleTimed` 把负 elapsed 钳为 0。这可让游标等下个展示帧，须记录帧间隔；不能凭正常 100 ms delay 承诺任何负载下都有 100 ms 端到端延迟。
4. **远端玩家离房时，已排队命中可能保留停止的旧 motion（确定的静态边界，未证明本轮发生）。** `updateRemote` 房间不匹配会 `despawnGhost → _projectiles.forget(ghost)` 并清除 rec.motion；`ProjectileVisuals.forget` 只移除 active projectile/seen owner，没有解绑 ImpactEventQueue 的 pending clock。若命中已经排队但 cursor 尚未到 impact.at，而玩家先离房、观察者留原房，pending.loc 仍是本地当前房间，旧 motion 却再也不被 sample；队列会一直 wait，直到 15 秒丢弃。NPC 死亡通过下一次 receive(null) 转 fallback 的既有修复不能覆盖这条“没有下一次 receive”的路径。case0 始终同房，不能据此解释 2.75 秒。后续应增加“射击后马上离房、观察者留原房”的实际队列用例。
5. **缺失/空时间字段的 fallback 不等同于当前生成的数据。** `Number(gun.sampleTime)` 对 null 得到 0；undefined 得到 NaN 后回退本机 now。若配合无 motion 的旧/畸形包，却保留来自另一进程的 impact.at，会使用不相配的 offset。`ImpactEventQueue` 的 `isFinite(Number(s.at))` 也允许 null→0。当前 UnitPresentation 明确发送有效 stamp，case0 实际值也完整；不以兼容畸形输入解释已记录的有效事件。
6. **断流后旧包的 reset 分支早于“旧 stamp 拒收”（确定静态边界）。** `RemoteMotion.pushTimed` 若到包间隔 >1,000 ms，会先重建 frames/cursor；仅 else 分支才拒绝 stamp<last.at。若旧帧在断流后重发，可回退到旧源时间。当前 TCP case0 记录的 stamp 递增，无证据触发这个旧帧条件；可作为独立组件回归，不能先拿补偿跳时钟覆盖它。

下一步应先用延后 PNG 的未改时钟驱动确认缺口是否还存在，再按上述队列插点把剩余时间归到准确区间。现有日志支持排除一些解释，尚不足以选择任何“补偿 2.75 秒”或加速播放的改法。
