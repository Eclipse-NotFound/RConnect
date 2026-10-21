# 首次非随机整图并行加载：只读核查与最小实现方案

2026-10-21。针对已冻结并编译的 `build/m52/recovery-01`，产物 SHA256 `79041b072829c60eb415280c5c02bbf465aac91a9bb632b6476ba41f2b5a8447`。本次仅核查及规划，未改生产/冻结源码、未编译、未运行 AIR。以下性能与失败恢复均为待验证设计，不是通过结论。

## 结论

**首次非随机整图确实缺少“宿主还在建图时，就让加入侧开始建图”的消息。** 原生加载图案替换不能补上这个时间缺口。应复用现有 `type:"room" / op:"prepare"` 和最终 `seal → ready → grant → ack`，在原版已决定目的地、首次进入标志、构造等级之后、调用 `new Land` 之前发送一次完整的进入计划。加入侧照这个计划走原版 `gotoLand → exitStep`，两个进程的建图才有机会重叠；最终房间状态及出生位置仍由宿主确认。

不建议直接把正在退出时的 `curLandId` 当成已确定地图发出去。原版会在 `enterToCurLand` 内运行 `Encounter()`，可能把目的地改为剧情遭遇；双方角色触发器也可能不同。照两边各自的规则预建，既可能浪费一整次生成，也会再次出现不同出生点。

## 已查明的等待链

当前候选源码为事实依据：

- `RoomSync.prepareCachedMap` 只在 `t_exit>20 && !game.crea` 且目标 `act.land!=null` 时提前发 prepare。第一次进入 `act.land==null` 的地图没有通知；`crea=true` 的重建也被排除。
- `MapGeneration.seedFor` 是另一路提前通知，挂在 `Land.rconnectSeedSource`。现有原生种子补丁仅在随机分支调用；非随机 `buildSpecifLand` 没有该回调。不是“非随机种子为 0，因此可以随便提前发”。
- `GameBridge.readWorldInfo` 的 `worldReady` 必须同时满足 `world.land.act.id == game.curLandId` 及 `!isTransitioning()`。退出期间用旧 Land 的信息不能冒充目标信息，这个限制是必要的。
- 加入侧 `RoomSync.observeHost` 对 `worldReady===false` 直接返回。缺少 prepare 时，只能等宿主完成 native exit，再从 worldInfo 或 seal 得到可用目标，之后才 `startSharedTravel`。
- 原生 `World.exitStep`：20 显示加载，19 同步调用 `Game.enterToCurLand`，18/17 可等待剧情点击，16 恢复画面和控制；`RoomSync.check` 在整个 `isTransitioning()` 期间不发 seal。因此当前首次非随机图近似为“宿主生成和退出 + 加入侧生成和退出 + 房间确认”。
- `TcpLink.send` 已直接 `socket.flush()`；`RoomSync.send` 走 Session 已有连接。无需改传输协议或等待下一个 50ms worldstate 定时器才能发送 prepare。但 OS/Flash 是否在宿主长同步构造中及时传出，仍须跨进程实测。

## 同时发现的出生/重入边界

1. `startSharedTravel(info)` 当前调用 `g.gotoLand(target, null, true)`，没有采用宿主退出前的 `curCoord`。
2. `adoptHostLandParams` 明确只处理随机地图，非随机直接 return；不能认为已有 `hostVisited` 会同步首次进入行为。
3. 原生 `Game.enterToCurLand` 在建图前计算 `firstVisit = !act.rnd && !act.visited`。`Land.enterLand(firstVisit, curCoord)` 优先使用显式坐标；没有坐标时，非首次进入可能选择角色自己的 `currentCP`，首次进入则选地图入口。事后 worldInfo 的 `visited` 已变为 true，不能还原刚才使用的 firstVisit。
4. 构造输入等级不等于 `Land.landDifLevel`。`Game` 从 firstroom/角色等级得到原始整数参数；`Land` 再依 rnd、dif、autoLevel 决定难度，同时还用原始参数计算 lootLimit。仅发最终 layoutLevel、或临时改 act.dif，不能精确替代完整构造输入。
5. 当前 `startPreparedMap` 对“相同地图 ID 且 differs 为 false”直接返回。非随机 seed=0 无法识别同 ID 的一次新建/重建；`preparedToken = id:seed:constructing` 也不能充当完整旅行身份。
6. 当前初次 grant 后已有 `TravelPlacement.place` 对齐宿主位置，可以保留。新的提前计划不应直接 setPos；本地布局、权限和完整 checkpoint 尚未确认时仍不得显示可操作场景。

原版规则核查位置：`game-reference/decompiled/1.02/src102/scripts/fe/World.as:1134`；`fe/loc/Game.as:331`（enterToCurLand）、`:405`（Encounter）、`:425`（gotoLand）；`fe/loc/Land.as:102`（构造）、`:1143`（enterLand）。这是只读机制参考，**实施前必须从当时准确游戏宿主导出 Game/World/Land 并核对差异**；不能把历史 `build/analysis/pfe_current` 名称当成现安装指纹。

## 推荐最小改动：保留现有房间确认，加一个原生旅行桥

完整正确覆盖首次非随机图，需要读取原生“刚算出的进入决定”。推荐只在原生 `fe.loc.Game.enterToCurLand` 加一个默认 null 的静态桥接回调，例如 `rconnectTravelBridge`，分两处调用。RConnect 未注册、离线或无有效计划时，原版分支保持完全相同。不是重新写 Encounter、等级或出生规则。

### A. 原生 Game 的两处窄接点

**adopt 接点，原生 Encounter 前：** 加入侧取当前 World / 本次原生退出绑定的一次性已确认计划。只有 host 发来的有效、未消费计划才返回数据；使用其中已解析目的地，避免加入侧再按自身触发器重定向。宿主与离线返回 null，仍运行原生 Encounter，一次且仅一次。

**announce 接点，原生已经计算首次进入及构造参数、但 new Land 之前：** 宿主把刚算出的结果通知 RConnect。首版仅在最终 `curLand.rnd==false` 且确实需要创建/重建时启用；缓存图与原有随机种子快路先保留。加入侧在这个位置采用计划中的构造参数、进入标志和坐标，再继续原版 new Land / activate / enterLand。只替换本次局部输入，不永久修改角色等级或全局任务触发器。

原生桥的伪代码位置（不是可直接部署的完整补丁）：

```text
saveOldObjects()                    // 原有调用，顺序不移动
plan = bridge("adopt", this)        // null 表示按原版；有效数据只来自已授权加入侧旅行
if plan == null: Encounter()        // 宿主仍由原版决定是否进入遭遇
else: use plan.resolvedLandId       // 不在加入侧再掷一次剧情选择
resolve curLand                    // 原有土地查询及异常回退
compute firstVisit/create/level     // 原有计算不另抄一份到模组
if plan != null: use exact plan local inputs
if creating:
    bridge("announce", this, native computed inputs)
    new Land(player, curLand, level)
activate land; enterLand(firstVisit, entryCoord)  // 原有顺序
```

`adopt` 应先完成绑定及字段验证；计划被认定有效后若出现错误应进入明确失败状态，不能偷偷退回本地 Encounter 生成另一张图。`announce` 发送失败不应抛错破坏宿主原生旅行；保留现有完成后 seal 的安全回退。

比起直接在 Land 非随机分支补发一个 seed 回调，这多读取了一次 Game 的真实进入上下文，但避免漏掉 Encounter、firstVisit、原始 level、curCoord 四个决定。**这是本方案必要的原生改动；只改 RConnect 层可给特定普通地图做提前尝试，但不能据此承诺全部首次非随机图正确并行。**

### B. 复用 prepare 的数据与生命周期

建议扩展现有消息，不新增持续同步通道：

```text
room/prepare {
  travelId: session nonce + monotonic sequence,
  fromEpoch,
  planVersion: 1,
  info: {
    curLandId: 原生 Encounter 后的最终 id,
    nativeCreate: true,
    firstVisit: 本次 enterLand 使用的 Boolean,
    constructorLevel: 原生 new Land 的第三个整数参数,
    entryCoord: 原生 enterLand 将使用的 nullable String,
    landStage, hostVisitedBefore, sceneMerged,
    layoutSeed: 0                       // 非随机，不把 0 伪装为有效随机种子
  }
}
```

- `travelId` 是进入尝试身份，不是地图随机种子，也不代替房间 epoch/term。它负责重复 prepare 幂等、相同 ID 重建、迟到消息淘汰；最终 seal/grant 带同一个 travelId，现有 barrier/epoch/term 校验继续保留。
- 计划是“可开始原生加载”，不是“世界已完成”。不要把它塞进普通 worldInfo 并撤掉 worldReady 的防护；让 prepare 的独立接收分支显式读取计划。兼容旧 prepare 时走旧逻辑。
- `RoomSync` 保存一个当前 pending plan 和最后消费 ID 即可，不建立无限计划队列。发起一次原生退出后只更新状态，不再次 gotoLand；若另一个旅行已经进行，等待它完成/取消并核对 token，不能重置 t_exit 插队。
- `MapGeneration` 注册/注销原生桥、收取计划并提供一次性 adopt；原有随机 seedFor 保持。CS 模式依计划在生成前暂时采用现有 sceneMode 机制；会话结束按原有 savedSceneMode 恢复。
- `GameBridge.startSharedTravel` 验证本机桥能力、计划目标与字段，再 `gotoLand(target, entryCoord, true)`；不能通过直接 enterToCurLand 跳过原生退出链。`gotoLand` 若被角色负重/权限拒绝，必须返回“未开始”，不要提前标记 plan consumed。
- 首次非随机 nativeCreate 的同 ID 重建不能再被“同 ID + seed 不变”短路。若加入侧已有该目标缓存，是否重建由本次创建计划决定；失效的旧缓存引用在事务内暂存，不能先丢唯一副本。普通缓存重访仍沿旧缓存路径。
- `TravelGuard` 的一次原生退出许可继续使用，补充将许可和当前 travelId 绑定；重复/迟到 prepare 不能给另一轮退出续权。grant/reset/世界替换都撤销。
- `Session` 不需要新的高频定时器。HELLO/WELCOME 后若宿主仍有未完成计划，应补发该计划；新加入者错过最初广播不能永久等一个不会重发的 prepare。已有连接只由宿主发送，加入侧不能令主侧启动任意地图。

预计修改范围：原生 `fe.loc.Game` 的桥接插点；RConnect 的 `MapGeneration`、`RoomSync`、`GameBridge`、`TravelGuard`，以及 Session 的欢迎后重发（小段）。不改武器、伤害、对象状态、checkpoint 内容或地图生成算法本体；不再新增第二套等待 UI。当前 recovery-01 不修改，另建后续候选并保留准确宿主来源。

### C. 最终出生一致与首帧放行

- 计划只负责双方同时启动，不能事先猜最终 x/y。
- 宿主原生进入完成、第一次冻结入口时记录一次 `entryAnchor = {travelId, roomKey, landX/Y/Z, x, y}`，放进该次 seal（或单独同 token 字段），不得被之后普通 worldstate 里宿主移动的位置替换。
- 加入侧完成原生加载后，已有 `sendReady` 可按宿主 roomKey 跟到同一房间；grant 恢复检查点后，再用同 token anchor 执行已有 TravelPlacement，并校验 world.loc / gg.loc / roomKey。
- 只有完整 grant 成功才撤销自有原生加载资源/释放控制；宿主仍按 room19 在 commit 后恢复，不额外等加入侧画完再 ACK。
- 这可避免“本地存档点先露一帧，再跳到宿主”及“宿主加载完已移动，加入侧追着新位置出生”。与玩法中自由分房和跟随队友的普通房间切换分开；不把每次门内移动都强制同生点。

## 失败、回滚和重入必须怎么处理

| 时点/故障 | 最小安全行为 | 不能做的事 |
|---|---|---|
| 发出前/消息无效 | 拒绝计划，保持当前房间；记录具体字段错误 | 用旧 Land 的种子/坐标补空值后直接进入 |
| prepare 重复或晚到 | 同 ID 幂等；已完成/已撤销 ID 不再执行 | 每个重复包重置 t_exit，或同 ID 重建被完全忽略 |
| 目标不存在、能力不支持 | 本轮保持旧安全完成后跟随路径，或明确阻塞；双方行为一致可诊断 | 进入原生 rbl 回退后假称目的地成功 |
| gotoLand 被负重/权限拒绝 | 不消费 native plan、不宣布开始；保留有界等待及可操作错误 | 反复强制关界面、无限重试或绕过角色检查 |
| 构造前取消/断线 | 清理自有 pending/许可/模式覆盖；仅在原生尚未激活新 Land 时恢复暂存缓存引用 | 在新房间已激活后直接把旧引用塞回 world |
| 构造/恢复中异常 | 保持未确认场景不可操作，走现有明确失败及 45s 保护；保留日志与旧 checkpoint | 解除遮挡继续在半恢复世界战斗，或递归重新 enterToCurLand |
| 宿主目标已变化/重进同图 | 新 travelId 取代未开始旧计划；已开始的先完成/取消再采用新计划 | 把新的 hostInfo 直接覆盖到旧 plan 并合用旧 barrier |
| 旧 seal/grant/worldstate 迟到 | travelId 与 barrier/epoch/term 联合校验；只允许当前事务完成 | 让旧消息清空新 preparing 或把 player 放到旧入口 |
| 游戏世界重建、死亡、读档 | 取消旧 World 绑定、旧原生许可及计划；随后按正常当前宿主世界重新握手 | 将死亡/读档当成旧 travel 的继续，复用旧一次性授权 |

“回滚”需分开：候选发布失败可恢复备份的模组及宿主组合；进程内若已经执行了脚本/生成，不声称只换回几个引用就能逆转全部副作用。此时应按已有安全退出/重连流程恢复。原生桥无订阅或离线时必须与原版等价；卸载后不能残留 sceneMerged、构造等级、firstVisit 或许可覆盖。

## 必须执行的验证

### 功能/重入矩阵

1. 冷缓存非随机普通图：两边 act.land 都 null；普通目标、autoLevel 目标各一次；双方等级/firstroom 不同，核对 host constructorLevel 生效且本地角色等级未改。
2. 非随机首次进入不一致：主未访问/加入已访问，以及反向；加入侧另有 currentCP；显式 curCoord 与无 curCoord 各一次。确认最终入口一致、原生首次剧情只按既定宿主规则执行、未出现未确认可操作帧。
3. 原生 Encounter：random_canter→way、random_encl→post、stable_pi→stable_pi_atk / stable_pi_surf；再测主侧 storm 不重定向但加入侧本来会重定向。确保建图目标只由宿主解析一次。
4. 同一非随机 ID 的 nativeCreate 重建；普通缓存重访；随机新探索/随机缓存均回归，种子不被锁死、缓存不被无故刷新。
5. 两侧分房时宿主共同换图；加入侧正在过普通门时收到计划；隐藏背景房出来后换图；剧情点击等待（18/17）不绕过点击。
6. prepare 重复、prepare 晚于 seal、旧事务消息到新事务、WELCOME 后补发、网络延迟与一次断开：每个 travelId 最多一次原生启动，确认消息顺序不串。
7. 宿主建图前取消、建图异常、加入侧被负重/权限拒绝、加入侧恢复 checkpoint 抛错、45 秒超时；无误放行、无无限重启、旧地图进度可恢复。
8. 任一侧死亡/读档/World 替换期间来包，暂停中来包，模组重置；旧计划和许可失效，返回单人时原生逻辑不受影响。
9. 已杀敌人/炮塔/蜘蛛地雷、破墙、门箱、唯一掉落、迟到伤害报告不回滚、不重复。最终玩家身份/位置和 room authority 一致。

### 证明真的缩短时间，而不是只换遮罩

使用准确同一宿主与同一模组组合，比较：离线单人相应原生流程、574D、recovery-01、后续并行候选。固定输入只用于对齐地图/单位负载，不改变生产随机政策。

功能观察器记录共同 wall clock（Date.time）与本进程 getTimer：原生退出开始、prepare 发/收、enterToCurLand 开始、new Land 开始/结束、activate/enter 完成、seal/ready/grant/ack、首次满足可控制且画面已确认。不能直接相减两个进程各自 getTimer。

验收看两条独立事实：

- **并行事实**：加入侧 new Land 开始早于宿主建图/原生加载结束，实际构造区间重叠；不要仅用“加入侧出现加载图片”当重叠证据。很小地图构造可能比网络+两帧准备还短，此时记录无重叠，但总额外等待应仍小。
- **用户等待**：从宿主操作到两侧确认可控制的总时长；主侧原地等待、加入侧加载尾段分别记录，低开销重复测量中位数及长尾。目标从两份原生耗时相加变为接近较慢一侧原生耗时，加有限消息/确认成本。原生剧情点击等待单独列出，不能归为网络回退，也不能为了成绩跳过。

带截图/逐阶段日志的功能轮次不用于性能百分比；纯计时轮次少量标记即可。还需测共同进房时的短期 CPU/内存峰值：同机双实例并行会争用 CPU，不能假设并行后一定恰好等于单人耗时。若 checkpoint 恢复/序列化仍占尾段，再基于分段耗时处理，不能删确认步骤伪造达标。

本次没有测试数据，不能承诺已达到单人加载时间。

## 本次只读来源指纹

- recovery-01 RoomSync: `14d651cb6f369bb06cd3ae224ccbc2135e4935b5a96be47bc2166994bb5fd298`
- recovery-01 MapGeneration: `ba5ea9bf85933329759575ce19e8d5260f9218c1e0aacccd1fa956d1e045a3a6`
- recovery-01 GameBridge: `16330c074a9b2eeb13a5681408b747a5c585f164f7d489b696f4c413803fb2d2`
- recovery-01 TravelGuard: `76fb5ff44149e8f2d8ae677d16ec0799f4cb75b4a743f235b93176805259a31d`
- recovery-01 Session: `1cc4b2ddba1e1dc71c4ed7f39c5a5cff3e62b84b549c97c79aae7197f73fb0c5`
- 公共 1.02 参考 World: `271fd1768f2ffe064c17743345edd2284295134cd13677bee3b9936bc018e4e7`
- 公共 1.02 参考 Game: `d1ea2ace0f504b18b03eb57ae91cfb7b6b5c0a1fb41121acee600daabcff2a2c`
- 公共 1.02 参考 Land: `b3392523dcfbbcfd10d999172fdddf9fb5813b86ae369098988535660efec061`
