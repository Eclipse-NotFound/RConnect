# recovery09：房间恢复后快照积压的接收侧处理边界

日期：2026-10-22。只读分析，未修改生产/驱动/冻结产物，未启动 JVM、AIR 或测试。源码均取 `build/m52/recovery-09/src/`，不是正在演进的 integrated。候选 `0.2.24-recovery9`，SWF SHA-256：`1507686cd0811f6e6697a663ceed08ed7f85c8562399d50ccc79a891f8503acf`。

**结论：不能仅按 `unitsync` / `worldstate` 类型保留最后一个包。可以研究“每条信息照收，只把同批中重复的单位显示更新集中做一次”，但现有 `applyUnitsSync` 把逻辑、采样、事件和显示混在一起，必须先拆清边界。它不是在 Session 中加一个 latest 指针就安全的改动。** 首个候选应只处理加入侧、同一房间/权威任期、同一轮 socket 排空里的稳定存活单位；其它消息及对象生命周期照旧。下面列出具体保留项和实施前须证明的条件。

## 1. 已测到什么，尚未测到什么

历史证据为 `experimental/recovery-room-restore-diagnostics/runtime-review.md`，对应冻结07诊断轮 `cooperation/2e09dd2325`，不是09新实测：

- R0 导入内首次 `applyUnitsSync` 1次/24ms；grant 返回后29次/610ms，其中首个完整帧前11次/220ms，第三帧归属18次/390ms。
- R2 导入内1次/23ms；grant后15次/321ms，其中首帧前14次/299ms。
- R0 首个完整帧间隔3407ms，R2另一个1461ms长间隔没有 `applyUnitsSync`。重复全量应用是真实额外工作，但不是所有长帧的原因。
- 日志没有逐包发送时间、每次 socket 排空长度，也没有把 `applyUnitsSync` 内部划分到事件/索引/碰撞/显示。所以不能把29次都算作ACK前发送，不能承诺合并后直接省610ms，更不能据此声称达到单人耗时。

09仍保留下面的相同收发调用链。原生地形恢复、136个单位构造、原生/其它模组首帧工作不在本提案可消除范围内。

## 2. 积压产生与 ACK 的准确位置

1. `core/RoomSync.as:647,690–702`：宿主完成 commit，设好权威/term，发送 `room/grant` 后立即 `release()`；`pending` 留到ACK。`canSyncWorld`（495）不检查pending，所以本机继续运行和采集。
2. `core/Session.as:1064–1115,1204–1231`：宿主每约50ms发 `worldstate`，每约200ms发完整 `unitsync`。后者只是单位/掉落等字段完整，**不代表包内所有字段都是完整状态**。
3. `net/TcpLink.as:161–210`：一次 `onData` 读入字节，再逐帧解析，立即 `dispatchEvent(MESSAGE,msg)`。没有现成的语义消息队列。join处理grant时同一线程同步执行 `restoreCheckpoint`；它返回后，后续完整网络帧继续逐个处理，中间不一定有游戏帧。
4. `core/RoomSync.as:560–609`：join恢复checkpoint、放置角色、设置ready/term/settledRoom后，在602发送ACK，随后才清pending并release。**ACK当前表示checkpoint已导入，不表示积压清空，也不表示首个画面已绘制或按键已响应。** 不应为了合并改成“队列清空后才ACK”。
5. `core/Session.as:415–470`：旧镜像只要此时符合房间/epoch/term就按序 `progress.restore → reconcileWorld → reconcileObjs → tilePatch → wallPaint → objSpawn → loots → applyUnitsSync`。ACK之后的长帧也会再次形成积压，所以只管理ACK前没有覆盖整个问题。

接收资格仍须在原顺序判断：`RoomSync.accepts`（491）要求当前已落定房间；`acceptsReceipt`（514）只要求旧已落定房间及任期，特意允许换房边缘的最后伤害。不能先保存一批不合格包、等grant后再按新上下文重新解释。World相同而Game替换也必须失效：现有 `nativeTravel.matchesWorld` 在房间处理前检查（529）；批次还需保存并核对实际Game/World/loc身份，不能只比较房间字符串。

## 3. 逐字段分类

下表中的“保留”指交给原处理路径及原去重逻辑，不是保证把已超过原本寿命的特效强行补播。不得延长特效寿命来做性能测试过关。

| 消息/字段 | 09语义与具体入口 | 能否仅留最新 |
|---|---|---|
| `unitsync.units[]` 身份 `k/id/cls/tr/fraction`、存在集合、`sost/death` | `GameBridge.reconcileWorld:5966` 按完整集合创建/删除单位；`applyUnitsSync:5611` 同步生死、强制显示集及命中代理 | **不能整数组替换**。出生→开火→死亡→缺席不可变成从未存在；实例键不可按id归并。结构变化、阵营/安保角色变化及死活变化先结束合并窗口，按原顺序处理 |
| `units[].hp/defense/motion/grip/targeting/view/aura/security` | `applyUnitsSync:5648` 先采本地命中损失，再覆写宿主值；`enemyGrip.preserveLocal` 保留已接受输入；`setPos`影响碰撞；代理sync使用这些字段 | 只在证明窗口中无读取/回调/本地输入时，最终纯赋值才可能合并。首版保留逐包逻辑赋值与血量/护甲/护盾基线，不能仅保留最终hp再倒算伤害 |
| `units[].x/y/sampleTime/pose/anim/body/bodyEffects/burning/weapons` | `queueUnitMotion:5886` 同时push动作历史、sample/settle及setPos；`tickFrozenAnims:6380` 按历史样本显示；死亡立即apply并删除motion | **历史逐条摄入**，只研究将重复显示提交延到本批安全点。不能只留最新坐标、角度或动画状态 |
| `units[].weapons[]`、`worldstate.enemyMotion[].effects[]` | `UnitPresentation:186,243` 包含弹体frames、真实impact、无vis explosion、酸液ground、终末end；`ProjectileVisuals.receive:63` 先处理impact再过滤弹序号 | 全部按原顺序摄入原事件队列；可去重的是已有通道自己确认的同一事件。不能按最大seq丢较小seq后到的impact/终末，不能只保存最后一把枪 |
| `worldstate.enemyMotion[]` | `GameBridge.applyEnemyMotion:5512` 在单位不存在、已死、不在_hostAlive、坐标非法、时间戳较旧时**连effects也跳过** | 不能先应用最后一个全量再重放旧快包：这样会丢中间击中或爆炸。接收先后保持；若拆事件摄入必须保持原实例/房间归属与拒绝条件，不能无条件绕过校验 |
| `worldstate.players[]`、每人的`snap` | `Session.applyWorldState:1234` 维护成员集合和跟随；`GameBridge.updateRemote:724` 包含武器、heldMotion、port、抓取策略、死亡与跨房间消隐 | 首版完全照旧。它不是位置小包；缺席即removeRemote，跨房间会discard传送序号。不能用包外roomstamp否决全部players，当前players本就独立于sameHostRoom处理 |
| `unitsync.objs[]` | `reconcileObjs:2989` 先捕获本地意图；`applyIst:3222` 的open/lock/loot/mine/expl会调用原生setAct；`applySceneState:3121`可die/setDoor | 保留逐包。开→关、mine/expl变化、本地解锁/搜刮回显不只是最终布尔值；不可拿最终doorOpen抵销过程 |
| `unitsync.objSpawn[]` | `readNewObjs:3522` 排除首次模板，之后只报当前仍存在的新对象；`applyObjSpawn:4967` 按id/类/位置幂等生成，Box另走scene通道 | 保留每份列表及顺序。已消失的短命Trap/对象不保证在后包仍存在，不能将末包当全集；不能为合并延后发送侧首次模板建档 |
| `unitsync.loots[]` / `worldstate.lootMotion[]` | `applyLootSync:3806` 两者均可认领/生成实体；motionOnly并非只改坐标。完整数组中缺席意味着移除（3903）；空数组有效。存在拾取请求/吸取/本地推动保护 | 首版照旧。不能跳过出生→落下→拾取/清除；不能把最后motionOnly当完整集合或把空数组当无更新 |
| `unitsync.tilePatch[]` | `TerrainSync.hostPatch:120` 最多128瓦片、轮转非默认状态；`apply:203` 先capture本地破坏意图，再保护未确认的预测 | 不是全量，末包必会漏前批瓦片。不同瓦片可在独立证明后聚合，但同瓦片部分字段、破坏动画、water重建和ACK保护顺序不能改。首版照旧 |
| `unitsync/worldstate.wallPaint[]` | `WallImpactVisuals.snapshot:453` 轮转累计cell，最多64cells/48000字符；updates也是分批；receive:385先observe本地实际像素，再按version及预测保护put | 不是整墙全量。不能取最后列表，也不能单凭同v跳过校验。同cell旧版若受pending保护，ACK后仍需同版修复；`put:350` 特意不推进该cell incoming游标。首版保留原receive及缓存 |
| `unitsync.points` | `WorldProgress.restore:25` 可创建/替换原生奖励对象、保存点、播放拿取状态并prepare；不只有计数 | 首版照旧。即便保留最终地点状态，也不能代替下面独立奖励事件 |
| `map-progress.events[]` | `WorldProgress.receive:129` 按key/epoch去重，调用`pers.expa`给奖励；请求与确认有不同语义 | 原序保留；不能“有最终points，所以删奖励包” |
| `playerdmg.hits[]`、`friendly-fire`、`loot-ack`、`terrain-ack`、`room/*`、`coop-pause`、各grip、`player-mines`、`security-terminals` | Session及独立TcpLink监听器处理，有seq/token/revision/term和一次性结算；最后伤害可能合法属于换房前任期 | 都是合并边界：先提交先前待显示状态，再按原分发处理。不得合并、延后或跳过 |
| exploration/chat/未知类型 | 原独立协议；不属于本次单位重复恢复 | 保留，作为边界；未知字段或混合旧协议回退原路径 |

## 4. 必须保留的事件、模板和时间语义

**事件键与顺序。** `ProjectileVisuals`的通道是实际owner身份＋`gun.id:variant:stream`，不是slot或武器名。内部flight以seq认领；`ImpactEventQueue`区分hit/explosion，同seq真实hit可以后到，energy impacts另有id、frames和end。`UnitPresentation.weaponList:51`还保留已换下武器的未完事件。正确办法是继续调用这些既有接收组件，不在通用合并器另造一个“最大seq”规则。`ProjectileFrameStream.merge:70` 对同stamp最后点修订、旧点、64点上限有既有规则；不能排序后随意去重。反复gas脉冲和酸液地面Part也不等价于一个最终explosion布尔值。

**死亡与缺席。** 已进入队列的特效在 `ProjectileVisuals.forget:204` 可分离时钟后继续，射手死亡不会立刻消掉子弹；但“先删owner，之后再从旧包提取特效”不能靠forget补救，因为那些事件尚未进入队列。第一版遇到身份集合、sost死活或武器stream切换应先结束窗口，不凭最终尸体快照推测中间行为。`ObjectIdentity.resolve:70` 键不存在时还会按类/id/距离认领；不能在过时坐标上只认领一次后永久复用，也不能把一只同名新怪认成旧怪。

**本地命中。** `captureUnitDamage:5823` 比较_baseHp/_baseDefense与实际单位，生成_pendingHits，再由原报告路径结算。若旧全量未写入hp，但把_baseHp更新到旧全量值，下次capture会把人为差异当本地命中；反过来删capture会吞真命中。因此首版不合并这一层。必须保证“捕获本地变化→宿主逻辑值→基线更新”的原子顺序，不能只在最终绘制时补capture。

**源模板。** `readNewObjs`第一次调用把当前loc.objs与Area/Trap链记入_objTpl/_objNativeTpl，并返回null。它不是可无副作用停掉的getter。发送侧 `captureEffects`也会推进fastAt/fastPoint、终态标志和endSentAt，energy.captureDelta推进增量游标。先采集再丢包会消费事件；停采集到ACK则可能把运行时新生对象误收进模板，且已有特效留存有限。此次建议保持采集、发送、200ms修复及各自限额不变，接收侧处理已到齐的数据；不采用前一诊断报告的简单ACK门控方向。

**动作时钟。** `RemoteMotion.pushTimed:121` 用源sampleTime与实际接收now校准偏移，维护最近间隔、最多32样本；同stamp替换、乱序拒绝、>1000ms断档、>600px跳跃及port分段均有含义。只留下最新pose会改变延迟估计和轨迹；给合并包重写sampleTime也会改变武器与身体相对时刻。每条样本保持原顺序摄入；每条接收时刻由实际分发时记录，不能统一伪装成grant时刻或批尾时刻。因为减少处理耗时本身就会改变后续getTimer，测试应使用注入的同一接收时间表核对算法，而非要求真实优化后墙钟逐毫秒等同旧版。

**暂停。** `queueUnitMotion`在coopPaused时会settle并请求SATS重绘，projectile/energy/impact各有暂停时钟平移。跨`coop-pause`批处理会重现“身体与SATS分裂/恢复瞬移”。暂停包、当前暂停状态改变、房间hold变化均结束窗口；初版可直接在暂停/恢复期间禁用合并。

## 5. 建议的最小实施路径与退路（仅方案）

### 第一阶段：只建立有界窗口，不丢任何信息

- 入口仍是 `TcpLink.onData`，只增加一轮排空的显式begin/end通知；每个完整帧继续独立验证、原序MESSAGE分发。AMF的1MiB/深度/类型限制、JSON兼容、半包、握手和失败处理不变。**不要先把整个socket内容反序列化成无界大数组。** 结束/异常/关闭都必须清理窗口。
- 合并决策留在Session/GameBridge语义层。`CoopPause/FriendlyFire/EnemyGrip/PeerGrip/ProjectileGrip/PlayerMines/SecurityTerminals`均直接监听MESSAGE；不能改成只给Session发一个合成包，也不能让这些监听器读取尚未提交的旧逻辑状态。每遇非候选消息，必须在该消息向任何监听器分发前结束前一窗口，而非等Session已处理完才flush。
- 窗口限一条link、一轮onData、同epoch/term/roomKey、同Game/World/Land/loc和冻结镜像角色；不跨Timer/ENTER_FRAME，不额外等50ms或等“多凑几包”。grant/断线/原生旅行/任期变更必须清空。达到数量/字节/耗时上限就**提交并按原路径继续**，不能丢最旧包。上限数值需从实际每次drain分布决定，此次没有证据定数。
- `rooms.observeHost`、`rooms.observeTeammate`、每包accepts、掉落/场景/奖励/永久修改等保持原顺序。涉及原生setAct/die/setDoor、可能读取角色位置或同步触发回调时，先提交单位待显示状态。不能只因两份objs payload一样就假定本地pending状态也没变。

### 第二阶段：只减少重复的单位“提交”，不减少摄入

现有 `applyUnitsSync`应先分出：

1. **有序摄入**：对象身份/存在性、生死、captureUnitDamage及逻辑基线、动作历史、武器/impact/energy/port事件、抓取保护、权限等；保留原行为。
2. **待提交显示**：对仍为同一存活实例记录最新显示目标。可审计的重复候选是最终setVisPos、外观applyUnitAppearance、已存在MirrorHitUnit的重复prepare/sync/register，以及重复全表索引/显示集清理。碰撞setPos与native回调不能先验当作纯绘制；须证明或仍逐包执行。
3. **安全提交**：在该批尾、生命周期/控制/场景/未知边界前提交一次。先提交历史里已摄入的最终样本，而不是把所有旧快包扔到最后全量之后。期间若对象变化、校验失败、旧协议缺少键/时间戳、暂停或可重入native回调，立即退回旧逐包路径。

这会让“只重画最后状态”成立，而不是“只接受最后状态”。第一版可以完全不优化players/loots/tiles/wall/objects，甚至不优化enemyMotion；先确认 `applyUnitsSync` 中可延迟部分占多少。若只剩很小的显示开销，就不值得为了它引入复杂batch控制。另一种较窄尝试是在单次应用内部复用已验证单位索引、消除重复prepare；这不要求合并网络历史，但也需另测净收益，不能凭总610ms预算断言有同量收益。

不建议第一版加入所有包字段的通用reducer：这会新造第二套生命周期/ACK/时钟状态机，容易再次增加多轮修复的复杂度。按消息类型删旧包也无法省发送侧采集/编码及客户端逐包解析；该方案只指向接收后的重复应用成本。

## 6. 实现前的最低验证矩阵

以下为待做，不是本轮通过项：

- 用真实09类驱动旧/新相同已解码包及可控接收时间，逐步比较逻辑状态、_pendingHits、基线、对象身份、事件队列和原生回调序列；显示比较在同一安全提交点进行，不以“最终hp一样”代替完整事件证明。
- `grant → WS → US → WS → US → ACK/控制`、分段TCP/半包/坏帧、两个onData、同stamp修订/乱序/缺时间戳；确保不跨drain、不跳解析、不延迟其它监听器。老term最后伤害按原接受，旧Game grant/World未换Game已换必须拒绝。
- 短命单位出生→开火→死亡→缺席、同id不同k、射手已死而弹未结束、换枪/卸枪后impact、低seq晚到hit、无vis爆炸、重复gas脉冲、酸液dry/water地面记录；事件既不丢也不重造。
- 本地轻机枪损伤/护甲/护盾值、抓取/松手/抛掷ACK穿插、友伤与playerdmg、SATS开关边界；校验无幻影伤害、无丢真实命中、源时间/生命周期不变。
- 超128不同tile的轮转；超64cells/48000字符的墙痕轮转；预测墙痕→同版被保护→ACK→同版修复；门开关、容器开后掉落、地雷布设/引爆、经验奖励/存档点、物品出生→拾取且末包空数组；不把缺席和缺字段混为一谈。
- 同一scene驱动、同一输入做solo/双侧恢复对照，分别报告grant本体、排空次数/包数、一次性事件数、单位摄入与提交次数/耗时、ACK后首三帧、恢复实际操作时间。保持原高速运动85ms/relative gap/tail等门槛及完整模组日志门禁。无性能回退且用户对应单人流程差距真实缩小，才能判断是否值得合入；功能pass不等于耗时达标。

本报告的确定结论是字段/调用顺序与旧诊断中的积压现象；合并收益及安全提交点的可实现性仍需上述拆分审计和真实组件/实机证明。
