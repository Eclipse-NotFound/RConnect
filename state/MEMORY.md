# RConnect —— 开发记忆入口

> 2026-10-10：第一轮架构整理和定向验证已保存：SnapshotPublisher / WeaponCapture分责、四条旧消息分支删除、房间清理收口。接续冻结49/ee1112df（74源/73类/236验证），与45/48可执行代码相同；11种检查取得双侧成功。**压力与火焰时长仍红，安装仍22，未部署。** 准确旧42也失败，但不能据此排除回退。所有测试实例已退出，45→47的精确复制授权已撤销。[本轮整理与验证](architecture-2026-10-10.md)、[前期M51记录](validation-m51-2026-10-09.md)保留全部证据。RV正式字节未改，另一可见性提案仍待授权。

## 1. 模组与职责

RConnect是Remains 1.02双人合作模组，覆盖同地图普通房分头探索、战斗、交互与共享奖励。M51修复远端弹道连续性、门的错误碎屑、命中/特殊武器效果、护盾透明度和队友被抓光晕，调整友伤开关，并降低同步分配开销。运行入口为release/RConnectMod.swf。

原RConnect会话01a086bb-378c-7f60-b8e1-50d90ffa0996是唯一合并、构建、游戏测试和部署者。用户允许全部当前/后续RConnect会话协调；R2–R14已交接停写，分叉继承记忆不等于获得部署权。[协调记录](m50-coordination.md)。

## 2. 用户决定与保护边界

- 已授权现有合作功能修复、大幅重构、实机测试与本机候选部署。稳定重连、公网、三人以上、其它版本、新任务/背包/交易同步排除。
- 保留其它程序，不擅自结束或改优先级/亲和性。只用独立AppID/数据测试，不碰玩家存档；仅管理自有PID。WallBlend不发送消息，测试冲突时等待其结束。
- 普通房可分头，无人房暂停并保留本次联机进度；宿主发起整图旅行，剧情/挑战共同进入。退出沿用原版保存，不新增随机房完整战斗存档。
- 地上物品一份、先拾取者获得；XP双方奖励；存档点共同解锁，各自保存。跟随默认关。
- 菜单/SATS任一端可全队暂停，全部关闭才恢复；开关默认关、宿主管理，保留网络/聊天/SATS队列。
- 个人被抓许可默认关，WASD挣脱默认开；友伤默认关、宿主管理，个人投掷伤害默认关。紧凑浮窗280×36，各自30–100%透明度；Ctrl+Enter聊天/F10显隐，原生Enter不变。
- 常规仅写本模组；用户另明确授权RealisticVision探索接口的局部缓存优化、测试、部署及必要协调，已完成。该授权不扩展至其它模组或RV其它功能。游戏本体/描述符/game-reference只读，失败证据不覆盖。

## 3. 当前安装与验证

- **0.2.22-dev**：163453B、68类、SHA256 `32602e77a21b206d1f7ff0e927b953878c28254e7201529455818923a3539732`。
- 最终build/m50/final-presentation-30，69源/197验证输入；生产实际编译27。30严格保留37组相同编译/运行输入，跟随4ce63cbedf新跑；38组4760/0、全双端DONE，150张PNG。保留旧运行不等于重新运行。
- 原21负控051e28e849仍产生14假翼/14弹道几何失败；正常全模组、无驱动加载7ec5eb4ec4双端新版本/心跳/握手通过。38组+对照+启动共80实例描述符，实际宿主均退出。
- 快速念力四组110/110/100/90ms；原生容器空中最长停顿0/30ms；SATS停止差及恢复跳变0px。80敌人压力8秒88帧/p95 133ms，仅证明本轮达到原门槛，不保证长局流畅。
- 地形/握持/掉落固定回放新增66/0，Python资产/输入门禁11/0。固定回放不加载游戏档，也不替代实机。
- [M50审计](../knowledge/experiments/m50-validation-evidence.json)、[全部部署与回滚](deployment-m50-2026-10-09.md)、[历史失败](validation-m50-2026-10-09.md)。公开安装包/玩家README仍0.2.8，未推送。

## 4. 本轮实现与判断

- SnapshotPublisher沿现有50ms定时器负责玩家/移动掉落和约200ms场景快照。playerstate到达只更新队友，不再重复采样广播；没有队友时不制作无人消费的周期包。握手/离开即时名单、探索100ms保持。
- WeaponCapture专管源端真实弹道/近战/特殊命中采样与历史，UnitPresentation专管远端播放。离线停录，独房敌人保留活动弹道和最近700ms结束短窗供交接；有消费者时先捕获结束再退役，无图形弹丸也能退役。
- damage/loot/objs/terrain由既有RoomSync.report唯一结算；拒绝的过期请求不再有旧分支兜底。房间显示与命中别名清理收口，roomRole不再重复整套重置。会话级AI原值/注入单位和持久房间进度保留。[当前架构](../design/architecture.md)。
- 已有玩家源时间、100ms主动握持、掉落批次缓冲、火焰速率、原生特效、护甲/翅膀等算法未改。敌人身体/枪械的混合播放时钟未解决，不能把玩家路径结论推广到全部敌人。

## 5. 已知边界

10-10审查发现的无消费者弹道记录累积已在候选45修复并通过真实原生枪的生命周期检查；尚无长局堆内存曲线。敌人位置/弹道走源时间，身体/枪械仍部分按收包/本地时间推进，此项本轮未重写。详细保留约束见[审查](../design/sync-audit-2026-10-10.md)。

长局高密度卡顿未证明稳定解决；M43背景门原宿主消失/失控未可靠复现。受控隐藏房往返通过不覆盖全部低频条件。镜像地雷的拾取/拆除/枪击/念力交互、旧Trap/Area #1063、其它#1009与全部NPC/武器/第三方组合仍不能保证。真人鼠标、中文输入法、公网及其它版本未覆盖。

持续火焰保持正常速率可能保留已有积压；没有对缺失数据外推，也不靠降阈值放行。旧23–29失败及所有诊断完整保留，当前绿不反推旧红全已解释。

## 6. 下一步

本轮接续为final-architecture-49/ee1112df，生产源和可执行AS3代码与45相同，重新构建仅令产品信息不同；不能跨不同验证输入冒充完整同字节门禁。架构、普通分房、隐藏房、复活、暂停、遮罩、普通弹道、友伤、念力、角度和光束破墙取得双侧成功；工具11/0、静态15项通过。结果与全部失败见architecture-2026-10-10.md和49/architecture-diagnostics.json。压力仍9项失败，火焰时序5项失败；准确旧42也失败，但新旧随机装备与运行波动不同，新火焰偏差更大，不能宣称改善或排除回退。

新正式清单为48组（原47加ArchitectureTestDoc）；没有完成全48组、最终审计或23正常加载。本次针对性检查不抵消压力失败。下一阶段先定位可重复的性能/时序问题，再决定进一步统一敌人播放时刻和帧阶段；不要把剩余全部回调/原生代理直接删掉。

测试准备已收口：TestRoomReadiness等待配置目标原生世界及当前房间；Beam/Mask不再在begin夹具中途换图。FastHeld读档后正常关闭原生Pip，再等换装动作自然结束，真实搬运四组延迟160/150/110/120ms。47角度启动有World.resizeScreen→MainMenu.resizeDisplay #1009及房间交接超时，48正常启动后79/0；此低频原生初始化问题尚未修复，日志与stdout都要核对。11:57实际CIM无AIR/本轮运行器；临时授权已用后撤销，不能复用。

此前已发出的RV“敌人可见性扫描缓存”扩展授权问题仍待回复（[可审阅提案](../build/m51/vision-sight-proposal-04/REVIEW.md)）。这不是已完成的探索接口缓存。获准后按RV范围/验证/部署流程实测，若改变正式RV字节，要保留旧基线并建立新的精确集成基线和对照，再冻结RConnect正式候选。没有新授权就保持RV正式源码与产物不动；本模组内的审查和整理不依赖该授权。

本模组当前可复用证据：原生光束固定时钟负例及恢复回归；探索编码每端768次原算法对照；检查点编码96组和全部尾部padding逐字节一致；新RV+准确旧RConnect22的三个功能负控在red-vision-cache-02。所有旧失败原样保留。新RConnect部署须唯一备份准确22，M50既有备份是21。

回滚必须双方保存退出后，把 `build/backup/m50-release-20261009-182002-d83866/RConnectMod.before.swf` 复制回release/RConnectMod.swf，再重启；备份SHA `5c372cf5d970212f0fd4e95bea5c0acfaabfe321c3ca531c80ed7e299c2914bd`。M49备份是旧20，不能混用。

## 7. 接续入口与工具

- [journal](journal.md)、[呈现实验](../knowledge/experiments/2026-10-09-m50-peer-presentation.md)、[验证工具](../tools/validation/README.md)。M50原安装基线integration-baseline-0.2.21-native-assets有157条（自身SWF大小写双记录），发行外部保护155条/98原生资产；保持历史原样。
- AIR/amxmlc、SWF38；build_mod默认写release，开发构建务必显式--output到新build目录。loader硬编码app:/mods/Rconnect/release/RConnectMod.swf，大小写怪癖勿改。
- 实际application.xml→根pfe.swf 1.02；app.xml不是启动正本。反编译首选game-reference/decompiled/1.02/src102/scripts。
- Python：C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe，所有父子进程显式-X utf8。
- Java：C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe；SDK D:/RemainsMod/mods/Sandevistan/build/tools/flexsdk，FFDec同tools/ffdec；编译日志可能GB18030。
- 实际宿主CIM核对AIR，失败不可当成空列表。新测试使用唯一目录和原生完整资源/配置；源码或测试变化另建freeze，不改旧清单。
- 本模组git使用build/m43/empty.gitignore、core.safecrlf=false；eclipse/helloimyyt@163.com本地提交，不推送、不改写历史。
