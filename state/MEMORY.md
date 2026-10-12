# RConnect —— 开发记忆入口

> **2026-10-12 当前停点**：B171 / 原生019(b3-v12) / TDFC004 / RV003 / MSW011 / Sandy001，44组串行exec48960（build/ab/b3-suite-171），禁止改运行器。已过普通枪、两种正常退出、普通/特殊时停、分房五轮、28阶段身体、14阶段敌人、角度、四轮SATS、枪械/近战友伤等。motion主81/0加86/1：四轮念力/掉落位置与光晕全一致，末段只有9个移动插值样本未达到>10。工作源已冻结172，增加第二次真实开箱和聊天/控制台屏蔽时停输入，编译成功未跑。171的状态复用/精确差量已通过64帧数据语义检查，性能收益未测。169密集两分钟146/0但加p95 205ms仍卡。最终全套/抖动/新压力/无驱动启动与玩家包继续，A安装22不动，未部署。

> 继续完整实现既定 B 游玩范围并回归历史问题，不以技术检查点结束。证据与失败见[当前实况](host-authority-playable-2026-10-11.md)，设计见[并行计划](../design/host-authority-parallel-plan-2026-10-11.md)。较早构建号和红项保留历史，优先按本页停点与实况末节接续。

## 1. 模组与职责

RConnect是Remains 1.02双人合作模组，覆盖同地图普通房分头探索、战斗、交互与共享奖励。M51修复远端弹道连续性、门的错误碎屑、命中/特殊武器效果、护盾透明度和队友被抓光晕，调整友伤开关，并降低同步分配开销。运行入口为release/RConnectMod.swf。

原RConnect会话01a086bb-378c-7f60-b8e1-50d90ffa0996是唯一合并、构建、游戏测试和部署者。用户允许全部当前/后续RConnect会话协调；R2–R14已交接停写，分叉继承记忆不等于获得部署权。[协调记录](m50-coordination.md)。

## 2. 用户决定与保护边界

- 讲解偏好（10-11）：用户完全不懂编程，要求通俗语言、多图辅助，同时保持专业准确；机制主图与可展开的技术依据分层。已制作 [技术图解](../design/implementation-explainer/index.html)，示例与实测、安装版与候选明确区分。

- 已授权现有合作功能修复、大幅重构、实机测试与本机候选部署。稳定重连、公网、三人以上、其它版本、新任务/背包/交易同步排除。
- 保留其它程序，不擅自结束或改优先级/亲和性。只用独立AppID/数据测试，不碰玩家存档；仅管理自有PID。WallBlend不发送消息，测试冲突时等待其结束。
- 普通房可分头，无人房暂停并保留本次联机进度；宿主发起整图旅行，剧情/挑战共同进入。退出沿用原版保存，不新增随机房完整战斗存档。
- 地上物品一份、先拾取者获得；XP双方奖励；存档点共同解锁，各自保存。跟随默认关。
- 菜单/SATS任一端可全队暂停，全部关闭才恢复；开关默认关、宿主管理，保留网络/聊天/SATS队列。
- 个人被抓许可默认关，WASD挣脱默认开；友伤默认关、宿主管理，个人投掷伤害默认关。紧凑浮窗280×36，各自30–100%透明度；Ctrl+Enter聊天/F10显隐，原生Enter不变。
- 常规仅写本模组；用户另明确授权RealisticVision探索接口的局部缓存优化、测试、部署及必要协调，已完成。该授权不扩展至其它模组或RV其它功能。游戏本体/描述符/game-reference只读，失败证据不覆盖。
- 2026-10-11先暂停旧修复，随后明确恢复已选B架构实施；A旧候选缺陷不自动结案。MSW非致命武器影响队友时仅短暂限制视野，沿用MSW持续时间并保留操作。
- 同日后续：新分叉RConnect (3)（01a129bf-18dd-7bc3-8654-0f7f8fa08e47）用户明确“请继续被暂停的任务，重点关注房间生成锁死问题”，已read_thread核对。允许该支线独立AppID/目录/存档的地图专项诊断编译测试；正式集成审计、门禁与部署仍由主会话收口，不改安装版/游戏本体。此地图支线不替代主会话随后获准实施的 B 架构。
- 最新决定：A 保留现有架构，B 采用主侧统一执行；同图分房时主侧同时运行双方房间。用户已明确“请进行实现”并持续要求继续，无需再询问是否开工。已建立 master 下独立源码、构建、AppID/存储；公共地图与外部接口进入比较前需对齐，不把公共修复计作架构收益。
- 10-12 新授权：MSW 必要双玩家执行、RV 必要显示隔离均采用独立接口，与原版接口/状态隔离；仅构建隔离测试版，可按提案进行必要协调，不部署其它模组。
- 10-12 后续授权：Sandevistan 独立 B 接口及协调纳入本轮；任一人发动、两人正常行动、世界统一变慢、共享暂停冻结时停/回放。用户明确选择回放时结算主要伤害。正源已迁至本区 mods/Sandevistan（独立git，旧D:/RemainsMod不存在）；已与“sandevistan迁移”确认，修改仅src/SandyAuthority.as、SandevistanMod.as，隔离输出在RConnect/build/ab/sandy-build-001。默认未attach仍走单人路径，但同字节实际对照未完成；原正式配置/音乐/SWF未改。
- 10-11 新授权：允许为 B 修改 TDFC 必要的多玩家/房间调度、感知记忆和攻击属性接口，并可与 TDFC 会话协调；先只构建隔离测试版，不部署 TDFC。提案的单条临时护栏授权已成功使用并立即撤销，不能复用。


## 3. 当前安装与验证

- **0.2.22-dev**：163453B、68类、SHA256 `32602e77a21b206d1f7ff0e927b953878c28254e7201529455818923a3539732`。
- 最终build/m50/final-presentation-30，69源/197验证输入；生产实际编译27。30严格保留37组相同编译/运行输入，跟随4ce63cbedf新跑；38组4760/0、全双端DONE，150张PNG。保留旧运行不等于重新运行。
- 原21负控051e28e849仍产生14假翼/14弹道几何失败；正常全模组、无驱动加载7ec5eb4ec4双端新版本/心跳/握手通过。38组+对照+启动共80实例描述符，实际宿主均退出。
- 快速念力四组110/110/100/90ms；原生容器空中最长停顿0/30ms；SATS停止差及恢复跳变0px。80敌人压力8秒88帧/p95 133ms，仅证明本轮达到原门槛，不保证长局流畅。
- 地形/握持/掉落固定回放新增66/0，Python资产/输入门禁11/0。固定回放不加载游戏档，也不替代实机。
- [M50审计](../knowledge/experiments/m50-validation-evidence.json)、[全部部署与回滚](deployment-m50-2026-10-09.md)、[历史失败](validation-m50-2026-10-09.md)。公开安装包/玩家README仍0.2.8，未推送。

## 4. 本轮实现与判断

- **当前接续优先读[当前实况末节](host-authority-playable-2026-10-11.md)**。101起恢复的AIR证据按各自冻结字节登记，不把编译或旧绿推广为当前全部功能通过。017资源/类表/loader回读不变，默认原生分支的配乐/墙面/传送仍需运行对照；只管理自有测试PID。

- **B3当前实现优先读[完整游玩实况](host-authority-playable-2026-10-11.md)**。真实地形/敌人/武器/特效、统一播放时钟、可靠差分压缩、原生输入/菜单、各自资源、SATS、复活/地图交接、个人念力、跟随/宠物/共同挑战、友伤/地雷、紧凑UI与共享探索已接。跟随/宠物/挑战两轮通过；UI退出继续修复验证。程序绘图运输与原生局部栅格对照一致，原始矢量到局部表面仍有AIR自身的少量像素差异，不能称原始画面完全一致。Native011导入15类，新增字段和回调默认空，未部署。
- B3发现FFDec把同名局部变量的E4X过滤属性符号丢掉，导致地雷/魔法构造为普通枪；已转显式attribute查询并回读核对，014真实原生武器回归通过。新原生改动的默认分支仍需扩大等价回归。地图seed修复已接入B专用原生副本，A对照仍需同时对齐。

- B 技术原型：独立 `experimental/host-authority` 与 `tools/host_authority`；主侧持有原生 UnitPlayer + AuthorityPlayer、各自 Pers/Invent/Ctr/Sats/GUI/外观与待处理负重任务。NativeScope隔离玩家和房间的全局引用；OccupiedRooms按实际占用推进原生房间，同房不双步、空房保留；RoomTransfers在房间步之间提交原生出口请求。主侧显示只跟自己，作用域外World/Location/Land的玩家引用统一恢复为宿主。加入侧只发送动作并显示确认；异房确认尚无完整场景重现，明确提示并隐藏旧房画面。
- TDFC 可选接口：未attach走旧单人入口，attach后由host按房间调用、join零战术步。按玩家出生代次分别保存观察/报告/噪声，决策正文共用。原生Unit.findCel在原有检查时机分别检查两名玩家。B2已经运行两房真实掠夺者与炮塔；当前绿/红以[B2实况](host-authority-rooms-2026-10-11.md)为准，不能推广到全部敌人或完整多人呈现。
- 10-11前一呈现方案的[详细规划](../design/remote-player-entity-plan-2026-10-11.md)与[eli5图解](../design/remote-player-entity-preview/index.html)仍保留历史。原建议沿用RemoteDamageUnit集中显示，不包含现在选定的主侧完整执行；其P1–P6不是新B的实施顺序。玩家枪械变换已有源样本，开火队列仍用本机now/cadence。图解静态/链接/JS语法通过，CUA本地文件策略阻断，桌面/窄屏/点击未验；不混用另一图解的浏览器证据或称其对应新架构。
- 10-11未完成候选：MineSight复用原生感知；友伤回报一次结算的实际数字；PlayerMines增加布设者策略/队友感应/拆雷请求；FriendlyOptics读取MSW公开规则并应用原生blindness。56源与工作树一致，未部署；详细实测与缺口见[暂停登记](cooperative-hazards-2026-10-11.md)。
- 地图支线已完成 bbb526b：定位旧 M13 每个地图 ID 固定种子，62/64 模组须配套 58 原生地图补丁；准确安装 22 的负控失败保留，新探索/分房/背景门五轮/复活专项共 237/0。没有改 RandomRooms；尚未合入 B 或部署，见 state/map-generation-2026-10-11.md。
- A 的对侧是 RemoteDamageUnit（UnitPonPon 派生）+原生显示/武器，并非截图同步。B 现采用真正的 UnitPlayer 派生 AuthorityPlayer；attach 对全局资料的写入在 NativeScope 中隔离。旧“尚未选定基类”结论仅属于早期讨论。
- SnapshotPublisher沿现有50ms定时器负责玩家/移动掉落和约200ms场景快照。playerstate到达只更新队友，不再重复采样广播；没有队友时不制作无人消费的周期包。握手/离开即时名单、探索100ms保持。
- WeaponCapture专管源端真实弹道/近战/特殊命中采样与历史，UnitPresentation专管远端播放。离线停录，独房敌人保留活动弹道和最近700ms结束短窗供交接；有消费者时先捕获结束再退役，无图形弹丸也能退役。
- damage/loot/objs/terrain由既有RoomSync.report唯一结算；拒绝的过期请求不再有旧分支兜底。房间显示与命中别名清理收口，roomRole不再重复整套重置。会话级AI原值/注入单位和持久房间进度保留。[当前架构](../design/architecture.md)。
- 已有玩家源时间、100ms主动握持、掉落批次缓冲、火焰速率、原生特效、护甲/翅膀等算法未改。敌人身体/枪械的混合播放时钟未解决，不能把玩家路径结论推广到全部敌人。

## 5. 已知边界

10-10审查发现的无消费者弹道记录累积已在候选45修复并通过真实原生枪的生命周期检查；尚无长局堆内存曲线。敌人位置/弹道走源时间，身体/枪械仍部分按收包/本地时间推进，此项本轮未重写。详细保留约束见[审查](../design/sync-audit-2026-10-10.md)。

长局高密度卡顿未证明稳定解决；M43背景门原宿主消失/失控未可靠复现。受控隐藏房往返通过不覆盖全部低频条件。镜像地雷的拾取/拆除/枪击/念力交互、旧Trap/Area #1063、其它#1009与全部NPC/武器/第三方组合仍不能保证。真人鼠标、中文输入法、公网及其它版本未覆盖。

持续火焰保持正常速率可能保留已有积压；没有对缺失数据外推，也不靠降阈值放行。旧23–29失败及所有诊断完整保留，当前绿不反推旧红全已解释。

## 6. 下一步

**当前执行顺序**：收回171同字节44组（exec48960），保留motion样本不足一红及其余可能失败，禁止改运行器。结束后172测motion第二开箱、HUD聊天/控制台输入保护；不要将171绿直接记为172同字节绿。正常退出回执与64帧NativeFields语义已过。再新字节分钟级压力/抖动、无驱动启动、可比A/B条件及玩家包。169压力仍卡；原始/019＋外部未attach各34/0不是全游戏等价证明。未部署。

**继续完成B全部既定功能。** 051并发商店/武器柜/外观、052原生对话已通过；继续共享探索/汇合与新增GUI步的暂停回归、特殊武器/MSW、读档生命周期、无驱动正常启动、本机预测。独立启动器准备脚本已写但未生成玩家候选。统一时钟仍需快速念力/掉落/枪口、抖动注入、重复暂停与长局压力实测，并对齐A/B公共地图基线和原生默认分支。旧51组问题必须映射到B验收，不能只凭内核绿灯部署。当前源experimental/host-authority，工具tools/host_authority，输出build/ab。

当前冻结56/8f02fef5的FriendlyHazards主34/3、加34/3，MapGeneration主10/3、加3/0，均双端DONE。54/cb5e1bd723地雷显示7/0、d7c8cb92ea普通友伤236/0，不冒充56同字节完整门禁。正式清单为51组（原48加MineSight/FriendlyHazards/MapGeneration），未跑完、未审计、未部署。

原架构接续49/ee1112df与45可执行AS3相同；11类定向功能取得双侧成功，但压力9项、火焰5项仍失败。准确旧42也失败但不足以排除回退，见architecture-2026-10-10.md和49/architecture-diagnostics.json；敌人混合播放时钟未重写。

测试准备已收口：TestRoomReadiness等待配置目标原生世界及当前房间；Beam/Mask不再在begin夹具中途换图。FastHeld读档后正常关闭原生Pip，再等换装动作自然结束，真实搬运四组延迟160/150/110/120ms。47角度启动有World.resizeScreen→MainMenu.resizeDisplay #1009及房间交接超时，48正常启动后79/0；此低频原生初始化问题尚未修复。10-11暂停时实际CIM仅见用户AIR PID43448/9436，自有测试/运行器均退出；156项保护一致。45→47临时授权已用后撤销，不能复用。

此前已发出的RV“敌人可见性扫描缓存”扩展授权问题仍待回复（[可审阅提案](../build/m51/vision-sight-proposal-04/REVIEW.md)）。这不是已完成的探索接口缓存。获准后按RV范围/验证/部署流程实测，若改变正式RV字节，要保留旧基线并建立新的精确集成基线和对照，再冻结RConnect正式候选。没有新授权就保持RV正式源码与产物不动；本模组内的审查和整理不依赖该授权。

本模组当前可复用证据：原生光束固定时钟负例及恢复回归；探索编码每端768次原算法对照；检查点编码96组和全部尾部padding逐字节一致；新RV+准确旧RConnect22的三个功能负控在red-vision-cache-02。所有旧失败原样保留。新RConnect部署须唯一备份准确22，M50既有备份是21。

回滚必须双方保存退出后，把 `build/backup/m50-release-20261009-182002-d83866/RConnectMod.before.swf` 复制回release/RConnectMod.swf，再重启；备份SHA `5c372cf5d970212f0fd4e95bea5c0acfaabfe321c3ca531c80ed7e299c2914bd`。M49备份是旧20，不能混用。

## 7. 接续入口与工具

- [主侧统一执行与 A/B 计划](../design/host-authority-parallel-plan-2026-10-11.md)：当前路线与七阶段、原生隔离、双房/暂停、角色资料、对照和整套回退。已创建独立 B 技术入口；B 尚不是第二个日常可玩版本。
- [零基础专业图解](../design/implementation-explainer/index.html)：8节机制、4组交互；核心基于f81c4d9，补录0927470暂停状态。已做桌面/手机页面检查，[记录](../knowledge/experiments/2026-10-11-eli5-rconnect-explainer.md)。这是讲解产物，没有恢复开发、游戏测试或部署。

- [journal](journal.md)、[呈现实验](../knowledge/experiments/2026-10-09-m50-peer-presentation.md)、[验证工具](../tools/validation/README.md)。M50原安装基线integration-baseline-0.2.21-native-assets有157条（自身SWF大小写双记录），发行外部保护155条/98原生资产；保持历史原样。
- AIR/amxmlc、SWF38；build_mod默认写release，开发构建务必显式--output到新build目录。loader硬编码app:/mods/Rconnect/release/RConnectMod.swf，大小写怪癖勿改。
- 实际application.xml→根pfe.swf 1.02；app.xml不是启动正本。反编译首选game-reference/decompiled/1.02/src102/scripts。
- Python：C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe，所有父子进程显式-X utf8。
- Java：C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe；SDK D:/RemainsMod/mods/Sandevistan/build/tools/flexsdk，FFDec同tools/ffdec；编译日志可能GB18030。
- 实际宿主CIM核对AIR，失败不可当成空列表。新测试使用唯一目录和原生完整资源/配置；源码或测试变化另建freeze，不改旧清单。
- 本模组git使用build/m43/empty.gitignore、core.safecrlf=false；eclipse/helloimyyt@163.com本地提交，不推送、不改写历史。
