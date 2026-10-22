# early2 单位恢复阶段：只读分析

2026-10-22。只读核查，未改生产源码、冻结诊断源或测试门槛，未启动 JVM/AIR。这里所称“房间恢复”实际入口是 `GameBridge.restoreCheckpoint()`，不是独立 `RoomState.restore()` 类。目的只是为真实计时后选择最小改动，**尚未证实下列任一候选能缩短加载**。

## 准确输入与计时边界

- RC：`build/m52/recovery-early-exit-compile-01`，SWF SHA256 `d356483f927c608b5973982558127ce4feb0873a36676909ed3b3d6ac8b7acb3`。阅读源为 `experimental/recovery-early-exit-authorization/src`；GameBridge、NativeRoomState、ObjectIdentity、RoomSync、RConnectUnitAccess 已逐文件核对与该构建的 `src` 字节相同。
- 原生 `Location` 依据准确 2D 宿主 `build/m52/recovery-early-host-01/after/scripts/fe/loc/Location.as`，文件 SHA256 `9c7e679a4b5b8423355cb3ce07e496caa13415beb1ffdd630f0f2ed7b38c9cab`。本次未声称逐个敌人原生构造函数已与 2D 字节码核对。
- `GameBridge` SHA256 `3fe9bb83a16a57300e733806cddbe74ce55bcaf323bec15554814f4714eba967`；`NativeRoomState` `1e91028348b29dc1bd00dc55cf4d5df5d5ee40469ef9ea0f7e9626d30a601938`；`ObjectIdentity` `0bc4cc3429f78f0e43164dea4af4481e4230fdf335bd0eed6e7090baf0937774`。
- `timing.units - timing.terrain` 对应 GameBridge **6262–6298**：权威侧 boxTrackReset、可选旧单位清理、单位匹配/构造/完整恢复、清掉未出现的旧单位。角色清理在此前 `role` 段；后续 `applyUnitsSync`、命中代理、掉落物、玩家地雷在 `effects` 段，不能都算进 units。
- 旧 early1 实测 units 区间 **719 ms** 来自累计值 1536−817；其 GameBridge 实现与当前相同，但这不是当前 early2 新测量。出处：`experimental/recovery-early-first-load-review/README.md`。也不能把它称为纯敌人动画或纯构造耗时。
- 准确 early2 无诊断双人 `build/cooperation/6b322acc0f/join.log` 已直接回读：首进第54行 total1676，role65 / objects305 / terrain784 / units1582 / effects1629 / redraw1676，**units 段798 ms**；重访第131行 total1469，role64 / objects279 / terrain706 / units1357 / effects1403 / redraw1469，**units 段651 ms**。两条均 foreign=true、authority=false。它们证明当前版本此段持续有较大开销，仍未拆分到匹配、构造或恢复子调用。

## 已由源码确认的调用链

1. 加入侧 `RoomSync` 的 grant 分支（819–858）先去重，再 `RoomCodec.unpack → game.restoreCheckpoint(state, owner, foreign[, retained])`；同一正在等待首绘的 grant 不重复恢复。精确 fresh-owner、unchanged、retained 各有单独校验路径。
2. 同房新地图通常由主侧先建立 `records[myKey]`，再取 `records[theirKey]`（948–983）；`theirKey == myKey` 时返回 `owner=false, fresh=false`。加入侧通常因此进入 foreign 重建；这不是简单把所有新图标 fresh 就能省掉的路径。
3. `restoreCheckpoint` 先验证尺寸、执行 `roomRole`、对象和地形恢复。`roomRole` 会解除旧冻结、清理显示/命中代理/伤害基线，并建立新角色；它先直接 reset，再强制 `_lastLocRef=null → resetBaselinesIfWorldChanged`，确有一部分第二次清空，但这属于 role 段。
4. **foreign=true**：复制 `loc.units` 数组遍历，保留本机玩家、场景命中类及非安保的 fraction≥100 对象，其他逐个 `loc.remObj → indexOf/splice`，删除 puppet 标记，清空本房单位身份表。
5. 每个快照单位：排除场景命中类 → `_units.resolve` → 未匹配才 `getDefinition(cls) → new XML → 构造敌人 → putLoc → loc.addObj → loc.units.push → bind`。随后无论新旧都 `NativeRoomState.restoreUnit → RConnectAnimationAccess.receive → TurretDisplay.receive`。
6. `restoreUnit`：恢复公开标量/数组 → 包内桥恢复 AI/计时器等内部字段 → 每单位查询 Weapon 类 → 按槽检查枪械 id/variant，失配才移除旧武器显示并 `Weapon.create` → 恢复枪械字段和 currentWeapon → setVisPos。sost≥4 再移除链和显示。没有调用原生 `die` 代替恢复。
7. 再复制 `loc.units` 清理快照中未使用的合格单位。此后 effects 段才清理/恢复掉落物；非权威侧再次完整遍历快照 `applyUnitsSync`：设置移动/防御/视野/姿态、冻结 AI、建立运动缓冲和血量基线，必要时创建 **MirrorHitUnit**，最后恢复玩家地雷与安保状态。

精确原生 Location 证实：`addObj` 会维护 firstObj/lastObj 链，active 时调用 `addVisual`（2282–2303）；`remObj` 会维护链并调用 `remVisual`（2306–2330）。它们不维护 `loc.units` 数组，所以现有 splice/push 不能直接删除。

## 明显重复工作与尚待计时的假设

| 源码已证实的工作 | 可以说什么 | 尚不能说什么 |
|---|---|---|
| foreign 路径拆除原有普通敌人，再按快照构造 | 双侧本地地图已造出的同类敌人可能紧接着重建；不是直接复用原生实例 | 未量化各敌人构造/武器/显示耗时；不能认定它独占 719 ms |
| 每次匹配的 key 命中仍 `list.indexOf`；未命中则遍历整个数组 | ObjectIdentity.resolve 为线性查找。foreign 重建时数组不断增长，已 bind 的前序单位仍会被后续循环访问后跳过；最多形成二次增长的检查量 | 未证明检查次数或其耗时占比足够大；不能据复杂度直接宣称主因 |
| 清理循环逐单位 indexOf/splice；首尾各 concat 一次 | 存在线性搜索、数组移动及临时数组；链表移除还会移除显示 | 不能把有副作用的 remObj 改成一次过滤数组，也不能擅改移除顺序 |
| restoreUnit 已写字段/位置，随后 applyUnitsSync 再遍历并写部分重叠字段 | 确实是两次遍历和部分重复赋值，但计时位于 units 与 effects 两段 | 第二轮还建立仅镜像需要的命中/伤害/动画状态；不能整体跳过 |
| 每单位 getDefinition(Weapon)，失配枪械可能重新创建；每数组字段 JSON stringify/parse | 存在可局部归并的查询与克隆成本；原生构造后枪械失配有第二次创建路径 | 没有实际“失配次数/数组量/耗时”；先缓存类或换克隆不保证总体收益 |
| roomRole 内部分 reset 重复；新 MirrorHitUnit 构造先 sync，随后调用方再 sync，prepare 也重复一次 | 可以精确定位重入式小重复；前者在 role，后者在 effects，不在 units | 不应靠这些微项解释或承诺消掉大图加载差距 |

## 不可省略的身份与结算约束

- 单位身份不是 `id` 一对一：ObjectIdentity 先按网络 key 找同一对象，再在未使用、未绑定对象中按 id/类/150 像素范围找最近者。换成单纯 id 字典会把同类敌人的伤害、抓取或死亡写给另一个实例。任何局部索引必须保留 key、数组成员资格、used、顺序和相等距离时的原选择。
- foreign 重建是为了从显示替身恢复到原生可运行实体；公开标量和内部桥没有传输目标、对象引用或链关系。复用旧 mirror 不能仅以 hp/坐标相同判等，须证明 AI、武器所有者、难度和原生对象关系完整。
- `sost≥4` 目前也可能先建对象再移除显示，并保留其数组身份。不能直接删去死单位快照；这会涉及重访、死亡/复活及炮塔地雷去重。更不能为提速调用 die：会引入掉落、经验或任务再次结算。
- MirrorHitUnit **只在 loc.units，不在 firstObj 步进链**，自身 xp=0、die 空实现；它借用本体的 vis/hpbar 供 SATS。dispose 还将 sost=4 并清借用引用以废弃旧 SATS 排队目标。把本体直接改回可攻击、留旧代理或把代理加入链，都改变结算或导致双显示。
- 原生 linked-list 字段及 visible/alpha 等本机显示字段被 NativeRoomState 特意排除。优化 restore/clone 不能把引用直连或把这些字段补回。

## 后续最小选择建议（未实施）

先用根的真实计时确认 units 相对原生绘制和其他恢复段仍占显著时间，再在**一次恢复中**区分移除、resolve、构造/putLoc/addObj、标量/武器/动画恢复四类成本，按实际发生数量解释；这些是缺少的证据，不是本次新增驱动需求。若主要是 resolve，优先考虑只作用于此次恢复的成员索引、保留原有匹配规则和失败顺序；若主要是构造，下一步需要单独证明允许复用的实体边界，不能以删第二遍或跳过死亡恢复替代。当前没有足以选定生产优化或发布的测量结果。

## 84ff2d9da3 激活后长帧与物件报告（只读补充）

**结论：宿主失败是按键前的无漂移基线超时，尚未测到按键失效。重复物件报告与同步文件日志是可测的成本路径，目前不能认定它们造成约300 ms长帧。** 输入仍为上列 early2 RC；本轮原生宿主是诊断03 `29d36cdd94aadc5368156f80e854808d78b74baf8347ebfcc80c644d73601ef7`，不可当作无诊断2D性能结果。

已核对 `build/cooperation/84ff2d9da3/{host,join}.log` 与 `module-logs/host/RConnect.log`：

- host 第50行激活 t=76391；第128–130行帧间隔300/326/286 ms，前后均 ready=true、busy=false、cover=false、nativePause=false、authority=true。第131行无输入基线由 t=76493 至77652，用时1159 ms：初值 dx=1，下一帧0.8，再下一帧才归零，之后仅两帧；pressed/released 均空，第132行以原1000 ms门槛失败。不是 KEY_DOWN 已发而玩家不响应，也不能放宽窗口使其通过。
- host 共136条 `ist report applied`，第60–127行68条、第135–202行68条，全部 `o=undefined l=0 t=undefined`；文本为同一34项序列重复4遍。模块独立日志亦为136条，排除了 trace与文件拼接造成计数翻倍。日志没有网络key、批号、时刻，**34不是已证明的唯一对象数，4不是已证明的报文数**；后68条在 `COOP EFFECTS DONE` 后，不能全部归入失败窗口。
- 无诊断、同RC的通过运行 `6b322acc0f` 也有100条 l=0（50项文本重复2遍）。它只能证明该现象并非本次独有，不能作为同布局/同诊断的成本对照。84ff join实际通过按键，基线605 ms、输入响应346 ms，也出现342 ms帧间隔。
- host绘制诊断已32条溢出，已保留区间均在激活前，不能据此排除激活后的原生绘制开销。

已证实源码路径及可证伪假设（均指准确 early2 源）：

| 假设 | 实际路径与最小判别 |
|---|---|
| 本地恢复/初始化被误当作玩家解锁，重复等待回声 | `captureInteractionIntent`(3193)比较实时open/lock/loot与 `_istExpectO`，pending每约200 ms继续发至匹配回声才清。`restoreCheckpoint`(6250)先 `reconcileObjs→applyIst→istExpectSet`，再恢复公开交互字段/内部状态；期望值与最终实时值有产生差异的顺序窗口，`istExpectSet`(3304)还以0补齐未见字段。但当前日志未证明是哪一条改变了lock。只采样最先4个新pending：房间/epoch/term/key、此前期望、实时lock、快照ist.lock及inter.lock、是否有真实交互、产生与回声清除时刻。若出现前值不同且无交互，才支持误报；若初始已相等，则否定这条归因。 |
| 重复报告主要消耗在查找和日志，而非物件动画 | `applyObjReports`(4866)逐项resolve；key命中仍 `list.indexOf`，缺失则扫描数组；实际lock相同时不调用setAct，却仍逐项 `Log.d`(4940)。`Log.d`每次trace并创建FileStream、同步open(APPEND)/write/close。136条对应136次该调用路径，但不能当作136次实际解锁或136次成功磁盘写入。量每批resolve总时长/命中数、真正setAct数与时长、Log.d总时长；若前两项低而log高，才支持IO归因；若全部低，则本假设不能解释长帧。 |
| 报告与恢复后常规快照/原生帧竞争，而非同一包被执行两次 | `Session.onHostMessage`(568)命中 `rooms.report`即return，未见还落入MSG_OBJS的双重应用；`RoomSync.report`(999)验证ready/authority/room/epoch/term后只调用一次。join场景报告和host世界快照均按实际时间约200 ms调度，无补发计数循环；慢帧下可能接连到达旧pending并与整房快照、AI/显示重启同窗。按批记录接收起止与host快照起止；报告内部成本若只占很小部分，下一步才查余下帧阶段，不把整个300 ms算给它。 |

最小观察建议（未实现）：只在本轮激活后的2秒窗口内、最多8批报告/8次快照存内存摘要，结束统一输出；超限显式记overflow。每批保留单调时钟和墙钟起止、真实room/epoch/term及对象引用身份是否一致、三数组长度、resolve次数及key命中/回退数、实际setAct次数与累计耗时、原有Log.d次数与累计耗时、批总耗时。只存最先4个期望差异key，不逐对象追加新日志、不额外枚举世界、不序列化整房、不删除原日志作为“优化”。微调用0 ms仅表示低于时钟分辨率，不能解释为零成本；用批累计及批外时间判断。原异常和原调用次数必须不变，观察异常不能改变结算。该方案需在独立RC诊断副本中加入窄观测口（这些类非dynamic，不能假装外部替换私有方法），不需再增原生宿主补丁。先取得这组拆分，再决定是否改同步基线或日志，当前不支持任何生产修改。

## 首次实际绘制之后的外部CPU采样方案（后备，未实现）

可复用 `recovery-after-render-sampler` 的“先暂停、后整理、分别计时”和CPU栈上限，**不能复制其密集场景入口、阶段刺激或采样频率**。准确场景入口仍为 `build/m52/recovery-early-sandy-scene-driver-01/tests/RoomTravelTimingTestDoc.as`，3段往返及全部断言不变；原生宿主继续03。当前无采样聚合诊断优先，只有后续确需解释空档时使用。

1. **触发与事件顺序。** host03 `Grafon.sceneEnsure` 在原生 preload/upcoming成功返回后先取finished时钟，再调用现有观察槽；此时尚在原调用栈内，并不等于屏幕像素已提交。外部 `PaintTimingBuffer` 保留独占槽与全部聚合逻辑，仅在自身验证后通知新helper：本段首次 `completed=true、residentBefore=0、residentAfter>0`，且world/game/renderer、当前world.loc与真实raster桥绑定的目标loc均相同，才开窗。不能要求 `initial=true`，cull进入的首次实绘通常为false。每段最多一次、全程最多3次；中间rbl无此调用或重访已resident时明确记 `not-triggered`，不借旧房或补触发。后续ensure只计次数、不重启采样。
2. **停止位置的真实含义。** helper在begin时登记 stage `ENTER_FRAME +1000000`，其入口先读stop单调时钟/墙钟，再立即 `pauseSampling()`。这早于同stage的 A22RoomMetrics +100006、RoomSync +100000及已读RC监听；场景驱动tick却登记在自己的Sprite，MainFE亦在自身监听，优先级不保证跨DisplayObject全局先后。因此窗口名称必须是“首个resident绘制回调尾→下一stage ENTER入口”，不能写“完整首帧”“所有渲染之后”或把约2秒直接称CPU耗时。记录stage回调序号，合格停止必须是启动后第一次到达；若同次广播稍后才到stage，也诚实保留实际短窗。采样结束与实际ready/激活时刻分别对齐；空档若落在此窗外，则本方案没有覆盖它。
3. **槽与采样器所有权。** 聚合helper已用 `rconnectPaintTimingBridge===own` 校验，另一个包装器覆盖它会制造冲突；只能从同一个外部receive转交，不能再换原生槽。对准确early2、host03导出源码、原场景驱动/聚合helper及已读RV/WB/CS/Sand/LAD源码的只读搜索未发现flash.sampler调用；这不是对全部已加载SWF的二进制证明。旧after-render诊断确会clear/start/stop，必须不同时加载。后续runner应冻结本次加载清单及唯一采样入口，helper用本实例令牌防止自重入，无法确认独占就标conflict并不清空/暂停他人数据；`getSampleCount()==0`不能证明无人采样。不改变外部分析器设置，不安装新的全局sampler callback。start/pause调用失败、无可用样本均单列，不能当作零CPU证据。
4. **边界、身份与上限。** 预先准备一条小记录；依次保存ensure finished、observer进入、setup开始/结束、startSampling调用前/返回后、stop入口、pause返回、collect开始/结束，全部含getTimer与Date墙钟。首尾核对同一world/game/renderer/loc及槽所有权，保留segment、roomKey/epoch/term和stop原因；epoch自然推进只记录，不据其自动要求暂停。复用不同栈最多1024、每栈64层，不保留Sample/被采样对象；另给枚举总条数32768的硬上限，跳过分配/删除样本也计访问数，达到上限标sampleTruncated并记录暂停时总数、已访问数、CPU数、栈/深度截断数。这个上限只限制整理，不承诺采集缓冲本身有固定内存上限。没有next-stage回调时，正常finish/abort/dispose仍先暂停再清理并标incomplete；不能靠Timer保证阻塞中的2秒硬截止，不为凑完整样本延长游戏流程。
5. **避免整理成本冒充游戏耗时。** pause返回后才getSampleCount/getSamples、建字符串、聚合和清理；末尾独立记录stop/clear及总collectMs，日志输出另列flush成本，尽可能到场景结束统一写出。窗口CPU枚举不含收集本身；但收集在下一stage入口执行，会推迟该帧及原旅行/输入统计，不能简单从结果减掉collectMs来宣称产品变快。本轮始终 diagnosticOnly / performanceQualified=false，原失败与门槛不改，是否流畅只采信另一次无采样运行。CPU栈比例仅针对保留下来的CPU样本；没有样本的墙钟时间仍未知，不能径称GPU、休眠或网络等待。
