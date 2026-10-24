# RConnect — 开发记忆入口

## 1. 当前任务

A 为普通入口的双人联机；B 独立架构本轮不碰。根会话 `01a086bb-378c-7f60-b8e1-50d90ffa0996` 统一整合、编译、AIR测试及部署。
用户最新重点：删除“房间交接中”定制界面，双方加载达到相应原单人流程耗时，解决新房间不同步，并按git核对性能倒退。**10月24日用户明确要求先部署再继续，roomfix5已实际安装；大场景性能目标尚未完成。**
之前的高速弹丸/念力/掉落/击墙动画也尚未全修；不要用局部通过声称全部完成。本轮优先房间，不扩回B或无关视觉任务。

## 2. 玩法、授权和执行约束

- 普通房可分头；无人房暂停保留本次进度；剧情/挑战共同进入；宿主发起整图旅行，同入口。未换房者不应被另一个人的加载暂停。
- 掉落一份先到先得，经验共享，存档点共享解锁各存角色；安保破解共享/分别可选，切换保留已有权限。
- 跟随、共享菜单/SATS暂停、被队友念力抓、抛掷伤害、友伤默认关；WASD挣脱默认开。
- 所有RConnect会话可协调，根唯一部署。指定FA/RV/WB修正、LAD/CS测试协调已有授权；不能扩展成任意其他模组写入。A独立Sand加载兼容已授权；B的其他接口授权仍限B。WB首次初始化删除refreshView提案仍待答，不改WB、不以此阻止RC工作。
- 共享ModLoader game登记，JVM/AIR串行；子代理只做独立目录源码/审查。无实质新证据不跨会话发状态消息，不逐个要求停测。普通授权不重复确认。
- 唯一AIR ID、私有后台桌面、只读复制Littlepip29至测试槽9；不写真实存档、不关闭用户程序、不调用未点名Ghost。AIR写独立AppData需require_escalated；已授权测试范围内执行，不维护新护栏授权表。
- 启动余量：双6GiB/单3GiB/组件编译1GiB，运行512MiB保护，不降低。用户已答释放内存后继续，不重复提问。测试时读取当前余量，旧内存状态不是现在的结论。
- 10月24日上午用户允许测试前关闭 LAD、RV、CS：仅用官方启动器改隔离副本，正式选择不变。普通房必须重测同组合solo，不借历史大图基准。用户答会保存退出；其普通实例随后确实退出，不需再问。
- 省D盘，清自有可再建副本；保留失败、唯一证据及旧版。10月24日用户明确“先部署，再继续”，已依此提前安装roomfix5，不把未完成测试说成通过，也未降低后续性能目标。公网/多人/重连/其他版本不在本轮。

## 3. 实际安装与候选

正式RC：`0.2.24-roomfix5`，`release/RConnectMod.swf` SHA `78c052aea963f1689b705ae1e14d274916ae1a1f7e81933390caf8d1a88f4699`，195147B。
用户要求先部署后继续；回执`build/m52/recovery-room-user-deploy-01/deployment.json` SHA16EF10BA，22项仅RC变化；同目录备份DF0F/aura1。执行脚本原字节冻结deploy-executed.py（639166DB），随后维护源失败路径已加固但未重跑。安装后单实例smoke ed2fa23d99已通过：78C准确字节、14模组初始化、tick200及日志检查；installed-smoke.json SHA BCAD4048，独立副本已清理，仅启动资格。性能资格仍false。准确产品源/编译在recovery-room-production-05，不是历史src/dev版本。
此前aura1回执recovery-aura-offline-deploy-02，smoke7d45932e01及EB365备份保留；上一层574D见recovery-offline-deploy-01。房间修正本次首次交付，高速运动等尚未全交付。

12:39正式ModLoader另行更新为2050E023，启动smoke实际用了该新字节；旧性能证据仍是BD71不重标。新测试需另记telemetry.json存在/内容/隔离复制。post_deploy.py先前预检通过，但现在正确拒绝这项额外变化，不继续叠历史适配。

当前宿主A796：`a796827173af7d6fab9885fb66ecc62182ab5335918a30c7cce4c44914a238b7`，CS于10月24日上午从ABE2独立更新Grafon两处颜色方法，回执`mods/ContinuousScene/state/scene-tint-deployment-20261024.json`已verified。前一ABE2来自Camera.calc修正，旧回执`vertical-camera-band-deployment-20261023.json`。RV于15:17左右独立部署为BF4AC9CD (`bf4ac9cd87272b03fae7ec22ee67d045f037362f412ee801cad3f9ba9fe3afef`)，其会话回执effect-load-v3-output/deployment；此前0DBE为历史组合，其余CS7F1F/SandCEC6/WB14112等未变。旧80CF/ABE2/6DBA的历史不改写、不与新宿主耗时混算。

**房间对照候选roomfix4**：`build/m52/recovery-room-production-04`，SWF `34a17de66e9a89165b4bde75d22ec1dd3d4295bb496b903124687af80422b703`，195145B；prepared093916CF，compile3CDE928E。编译时80CF/0DBE，已完成实测ABE2/0DBE须分清。源配方`experimental/recovery-room-production-v4`。roomfix5为78C052，已按用户要求部署，真实遮罩/性能仍待验证。
来自准确aura1的11类房间修正：并行生成，未换房者不停，当前原房不自恢复，实际入口放置，绑定原生Land/Room交接与连续过门请求，READY观察标记去重、暂停时不耗跟随期限，原生加载素材与文本，地块完整标量表/准确绘制缓存。v4仅比v3删除RoomCodec每次同步文件诊断（候选误留，正式版无此日志）及改版本。房间生成/字段/伤害不删减。

诊断专用roomtime1：`recovery-room-loading-counter-product-02`和`recovery-room-loading-counter-driver-01`已编；来源`experimental/recovery-room-loading-counters`。只测首次grant及随后2帧9函数、14阶段标记、消息累计；原场景/断言不变，不能部署也不给净性能资格。product01因AS try/finally返回分析编译失败，原失败保留。

## 4. 最新实测与卡点

- **16:05当前组合三程对照完成**：A796/BF4A/2050、全14模组，正式roomfix5双人7cadcc8267主9.040/2.401/5.189秒、加15.068/2.321/8.208；solo fc4111c750为6.642/1.732/3.101秒。局部roomperf1候选1E26BDF3（195459B）双人6f633cee8e主9.531/3.632/5.171、加15.358/2.043/8.259。三轮原驱动检查通过、双侧三程出生距离0、真档/正式22项未改，私有实例已清；telemetry和CS偏好首个AIR前写入两端并核回。**未见明确速度收益，roomperf1不部署**；同布局seed不固定原生敌人数量，单pair不是正式性能判定。详见recovery-room-current-comparison/RESULTS.md。正式仍roomfix5，单人水平未达标。
- **首次绘制当前移植在做**：RC5类只移旧early2的共同大场景票据与退出许可，保留当前普通分房/READY/返程修复；宿主另在recovery-room-first-raster-host-current准备A796的World/Game/Grafon最小补丁。准确A796导出source02双JVM通过，3类AS/pcode及输入回执齐全；source01仅日志编码后处理失败，原失败留存。尚未编译或实测新桥。不能用旧2D宿主替换A796颜色/相机修正；未改方法保留原字节，新成员另核。旧Sand003仅候选仍未正式安装。
- **15:22单实例机制取证通过**：`recovery-room-terrain-solo-native-01` / `19ef6da857`，准确9A诊断、当前A796/BF4A/2050、私有Littlepip槽9，两次原生读档/生成240×125，27检查、种子1380142925及构造参数/新对象身份一致，一次真实codec/foreign restore。beforeRole53/role58/objects308/terrain876/units1578/effects1699/total1778ms（累计诊断，非性能资格）。首拒因tile(11,74).shelf false→true；完整源快照cp(480,2959)脚落11/12,74，源为实墙phis1/backA。仅自然注入alarm/exit，不是旧双侧5门复现。目标原cp坐标未采，不能断定创建/移动分支；真实存档副本字节未变、运行副本清理。新入口只固定准确产品及宿主/正式RC，其他真实输入按本次构建冻结，不继续追逐旧环境适配。旧preflight在新RV出现时先拒绝，无Java/输出，后才按新机制范围运行。
- **不能直接忽略shelf**：原生轮廓在实墙且背景非空有逻辑等价特例，但准确WB14112的eligible要求!shelf，且大场景revision相同时跳过重查；准确A796的refresh涉及方法不推进surface修订。因此全组合保留full redraw，继续研究原生首次绘制之前应用checkpoint以避免重复绘制。尚无新钩子实现。
- **历史路线已重新接上，勿重做**：10月22日94d4672d0f已抓到另一shelf拒因；early2/D356已有栅格等待票据、constructed通知、完整restore后首绘，三程f95499e5a7与6b322acc0f功能过，但未达单人耗时。A796没有这些桥，不能直接装旧2D宿主；新目录recovery-room-first-raster-current只核最小移植，不重新写一套协议。旧67项NativeTileState循环优化、154项TerrainSync本地破坏观察优化均未在当前roomfix5；当前控制源逐字相同，后者组件已经包含前者。准备与本轮55项合成roomperf1小候选，用实际当前环境三程对照。
- **局部简化55项通过**：`experimental/recovery-room-restore-allocation` 已准备两类源：删除从未读取的byId扫描；unchanged改直接严格比较，省去30,000格成功比较时的30,000临时数组。`recovery-room-restore-allocation-component-01` 真实AIR55/55、旧新完整类/每字段/NaN/类型/door/短路与refresh像素和调用顺序一致。GameBridge删除仅源差异核验；尚未编译为完整候选或部署，不授整体性能资格。

- **10月24日上午后续**：遮罩单行优化 `recovery-room-mask-component-04` 实际392/392通过，旧新像素/归属/清理一致；前三次因登记视图占用、排队时共享工具更新、组件helper与Flash属性mask重名先后失败，原记录保留。`roomfix5` 已编译至 `recovery-room-production-05`，SWF `78c052aea963f1689b705ae1e14d274916ae1a1f7e81933390caf8d1a88f4699`（195147B），prepared `acdc405a6e214531831cbb532178337aaa7fb9f154a91a1f8b543a6480dd6c58`，compile `68fcca0717bd9800725822211650c6fd74787a98a839432b5ed0216cb0ae48d4`；相对roomfix4仅版本与MirrorMasks一行。当时真实游戏/速度未验证；随后已按用户明确要求部署，见§3。
- **新环境及两次原生尝试**：roomfix5编译后正式宿主从ABE2变为A796，其余21项未变。drivers-01在Java前拒绝该变化，原失败保留。CS回执verified；新verifier分核旧构建/A796运行，`recovery-room-mask-native-drivers-02`三条编译通过并回收。真实8轮native-01/f9b2ff57f2等待15分钟超时、无AIR；native-02/d9404f3e49于11:51:41取得占用，但freeCommit=4606550016（4.29GiB）且其它AIR为空，在启动前停止。原始失败不改判，当前没有根测试进程；不再因旧答“内存已恢复”假定当前足够。普通游戏确已退出；Java90944是用户Minecraft服务器，不关闭。详情mask-native/RESULTS.md。
- **定向诊断已编译**：`recovery-room-terrain-reason-product-01` / roomreason1 / SWF `9a128737ce470127db16ff903fe0bcbdd8280daead0f714c983515c52a14b1ef`（197497B），prepared9650B504、compile2402BBCA，两个编译进程成功并回收、源码/安装未变，run预检通过。准确roomfix5只加两类诊断与版本：记录首个复用拒因、复用判断前dirty及beforeRole单计时；原短路、墙痕采集次数和三程驱动不变。未运行AIR，尚无首拒因，不可部署。编译后freeCommit约3.62GiB；先满足资源再按ENTRY运行，不新增重复失败目录。
- **遥测归因排除**：native04和reduced双/单日志、输入、SWF核实均为ModLoader2.4.0/BD71，没有新版FrameRecorder，不能把这些慢帧归它。旧runner不复制/记账telemetry.json；若将来装2.5，缺文件默认开启将形成新基线缺口，须另加存在性/内容/复制核验，不能改写旧22项历史。当前未改ModLoader。
- **出生点补核完成**：原生地图种子的LCG不替换Math.random，setGGToSpawnPoint仍独立随机选原生点；双人都在同一最终点。早期161坐标日志是ghost，不证明主侧被搬位。缺原spawnPoints完整值，故保留跨模式性能配对限制；不是已证实新的出生错误。详见reduced-runtime/RESULTS.md追加段。
- **大图重绘链**：首次恢复触发全图redraw，Grafon重建sceneSurfaces后WB清除旧缓存重建；已有局部paint/water接口不能重绘任意Tile状态，当前没有通用公开分块重绘接口。首次5个门/出口注入可能改变door引用或isRebuild，具体首失配尚未记录，不能直接省略重绘。详见loading-counters/RESULTS.md。

- **git准确归因**：574D→EB365→DF0F的房间/遮罩/旅行源码相同，加载修正从未正式交付。并非“已修又坏”；这是交付缺口。无证据否认用户性能倒退。见`experimental/recovery-room-repair-review/PERFORMANCE-REVIEW.md`。
- **普通48×25（历史80CF/6DBA）**：旧aura1双24.780/13.300/19.241秒，重访错位1109px；同组合solo9.903/6.386/6.272。roomfix2主7.462/2.121/3.457、加7.520/2.097/3.488，入口一致。仅此样本，不代替大图/最终候选。
- **大240×125（80CF/0DBE同组合）**：solo1f971dc179为7.518/1.916/3.571秒；roomfix3 d86f5d2d22主10.161/2.364/4.640、加15.675/2.844/7.711，种子/房/入口一致、重复seal已消失；仍不达原单人。首次grant2.033秒（解码187、恢复1827ms），之后3.688秒长帧待定位。
- **当前ABE2/0DBE单人**：8d4cf6e1db，`recovery-room-scene-solo-current-host-02`，7.222/2.115/2.980秒通过原三程；这是之后新双人直接基准。旧solo01/fb00d86688因sandbox拒绝私有AppData，在AIR启动前失败；02升级权限后正常，未改真实存储。
- **最终roomfix4真实分房**：BF6 0de27b7e59 / `recovery-room-candidate-entry-04`，主25+加53通过；死亡/HP/弹药/墙破坏/容器/唯一掉落/静止同伴保留，22安装不变。根实际目检双方waiting截图，均正确原生Loading动画而非原定制交接字样；无性能资格。
- **背景门**：roomfix3 2b02103aa3 / `recovery-room-hidden-03`，真实12轮主121+加157；控制/跟随镜头/身体像素/前景死亡保留/返程轻机枪伤害均过。v4同房间源码和等价Codec，尚未另跑v4背景门。
- **组件**：真实RoomSync READY92/0，cross68/0及5条实等；实际UI20/0；最终新旧Codec211/0，交叉解码/地块/墙面字节相同且无文件日志。通过项不盲目重跑。
- **密集版本对照（ABE2/0DBE）**：旧574D c0657f7dd9对当前aura1 394edfb54d，fixture/dimension/driver/runtime成对可比；加入7窗P95旧456/627/1135/860/936/972/513、新442/587/706/533/512/515/465ms。两版都严重失败，21/18条阈值不合；新版两个同步间隔更差。一对墙钟刺激不能否认用户回退，也不给roomfix4资格。见`recovery-room-density-review/RESULTS.md`。
- **采样失败不是无开销**：573fe88372原场景功能过，但grant与首帧采样全丢、第二帧截断；不把0CPU样本当0开销，不重复已失效flash.sampler路线。已改有界真实函数计数。
- **三项关闭的普通房**：`recovery-room-reduced-solo-01`/15f9ba06c9，aura1为9.368/4.034/5.124秒；`recovery-room-reduced-dual-01`/a53ab258d9，roomfix4主6.376/1.118/2.275、加6.971/1.256/2.320。双方三程入口距离0、种子/房间/控制恢复通过。真实SOL重新解码确认三端requested=ok=11项、无err；正式22项未变。**跨模式random_mane入口不同**（solo161.8,320、dual1161.8,800），正在追查，不能叫同出生负载或完整性能资格。详见reduced-runtime/RESULTS.md。
- **全组合计数终于完整**：`recovery-room-loading-counter-native-04`/0c357d93b5，功能与3窗口均通过，counters-result DE183C21，原计数0E7E25C0。首次grant2262ms；返回→首ENTER1105ms，期间14次unitsync520ms、36次worldstate163ms。首帧3236ms，其中priority1→−1为1312、−99→−101为1674；RC mirror150/vis47，MirrorMasks.capture29，不能把主要开销归签名。第二帧234ms。返程role阶段2519/2643ms待查代理退休重复遍历。诊断无性能资格。详情loading-counters/RESULTS.md。
- **失败与资源已更新**：native-01内存不足；02用户AIR在场未启；03外来AIR中途出现仅启动host；04成功。用户释放后余量已满足，最新根AIR/JVM全已结束，自有副本清理。不要沿用昨夜内存阻塞。共享登记非FIFO，发生真实饥饿后已与RV一次性协调两轮窗口，已结束；CS随后约5分钟实测占用，根先做离线分析，无需再逐个请求用户许可。

## 5. 未解决与已否决

- 要求仍是实际加载/操作速度，不是隐藏覆盖层。不能把功能通过或旧普通房速度当大图合格。
- MirrorMasks.capture实测首帧29ms，不是3.24秒主因，不写复杂索引。restore单行候选仅当attached(nativeMask,v)且v.mask不等于nativeMask时扫描首个refs；后续remaining扫描不变。RV0DBE的active只读已核，组件392项通过并编入roomfix5，真实RV的8轮待队列。目录recovery-room-mask-reference；已随roomfix5按要求部署，但8轮原生遮罩仍待补。
- 已排除“isRebuild导致第二次全图重绘”：准确宿主Location.rebuild仅重算水体并成功后清标志；active step还有照明，recalcWater还做落脚检查。不能为提速手工清isRebuild/isRecalc。首次画面复用拒绝原因尚待诊断，不把门注入猜测当实证；原timing.role包含RoomTerrainView构造和wall.checkpoint，不能全算成roomRole独占耗时。
- grant→ACK确实积压；unitsync/worldstate含weapons事件/impacts/melee、port和轮转tilePatch/wallPaint，整包只留最新会漏效果。字段级安全合并需新增较多状态分支，本轮先不实施；不能通过暂停全部网络消除积压。
- 不复用仅靠U序号/150px近邻的原生敌人；不完整恢复mapxml/interact/脚本引用会破坏炮塔/状态。不删快照/视野/动画或放宽门槛换速度。
- 当前Sand CEC6活动/回放绕过普通pause；A已授权接口候选未完成整段旅行验证，暂不并入。WB首次刷新提案无答复不动它。
- 旧墙面结构代C6A3与宿主6616有逐像素/分房功能证据，但等离子延迟和密集未合格；旧ACK/NoDelay/主动收包/暂停23等分支均无完整收益，不合入。详细已否决路径和准确旧证据见归档，不重建。
- 真实用户Unit.run #1010在Littlepip29隔离中未复现，不称已修。

## 6. 下一步入口

1. 正式roomfix5已安装且当前三程双人/单人检查完成，勿再部署同一字节或重复查shelf。roomperf1已编译、真实对照未明确改善，不部署。当前重点是recovery-room-first-raster-current与对应host-current实现，准确A796 source02已就绪。根唯一编译/AIR，遵守原6GiB/512MiB及共享登记。
2. 审核并编译当前RC5类与宿主3类首绘票据最小移植，复用旧early2证据但必须保留当前普通房修复；新增桥/成员和原方法字节保留单独核。配对旧Sand003必要兼容候选，缺桥或活动/回放走当前原流程。roomRole退休有真实平方级遍历，但mask与数组观察顺序有语义，不做复杂索引或删除完整恢复。
3. 最终准确生产候选需在当前实际组合取得可比大图与密集证据。旧ABE2/0DBE及80CF数据只作历史参考；局部组件通过不等于整体性能合格，三程出生负载仍需实际比对。正式8轮遮罩回归仍待补，原drivers-02需要独立核当前环境，不直接运行过期准入。
4. 高速运动、击墙、念力、掉落和大图加载目标继续开放；不能隐藏等待或删动画、损伤、完整状态来通过。资源失败不冒充产品失败或通过；出现真实安装功能失败才按精确字节评估回滚。

## 7. 详细记录

- 近期完整取证归档：`state/recovery-evidence-through-roomfix4-2026-10-24.md`；更早`state/recovery-evidence-through-offline-collector-2026-10-23.md`。
- 房间源/配方/测试准确绑定：`experimental/recovery-room-production-v4`、`experimental/recovery-room-repair-review`；旧检查器锁80CF，新`current_host_verifier.py`分别绑定旧构建和当前ABE2，不改历史回执。
- 现有正式候选发布：`experimental/recovery-room-production-v5/RELEASE.md`；旧aura发布说明保留。历史过程在journal顶部及各experimental/RESULTS；日志只追加，失败不改判。
