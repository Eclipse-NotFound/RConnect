# RConnect — 开发记忆入口

## 1. 当前任务

A 为普通入口的双人联机；B 独立架构本轮不碰。根会话 `01a086bb-378c-7f60-b8e1-50d90ffa0996` 统一整合、编译、AIR测试及部署。
用户最新重点：删除“房间交接中”定制界面，双方加载达到相应原单人流程耗时，解决新房间不同步，并按git核对性能倒退。**10月24日用户明确要求先部署再继续，roomfix5已实际安装；大场景性能目标尚未完成。**
用户现已建立持续目标：首次场景加载、双向远端角色/念力运动、加入侧本机尤其跳跃掉帧，三项都继续。之前高速弹丸/掉落/击墙动画也尚未全修；不要用局部通过声称全部完成，不扩回B或无关功能。当前三项证据与停点见 `state/three-performance-goals-2026-10-25.md`。

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

**独立 B 会话补充（2026-10-25）**：原 `build/ab/b3-playable-190` 已更新窄修 `B3-0.1-startup2` / SWF `2c536b5d`，修复大旧档加入失败及取消/失败后 TDFC 接口未释放。49 项专项＋部署后双侧 22 项通过，原 Player-1/2 与存档 ID 保留；普通 A 不受本次更新影响，B195 未晋升，未重跑 B 全套性能。回执 `build/ab/b190-startup2-deploy-20261025-01/deployment.json`；详情及回滚见 `state/b190-startup-repair-2026-10-25.md`。用户已保存退出旧 B 窗口，本次全部自有 AIR/JVM 已结束，测试副本清理约 313 MB；A 后续占用仍以共享登记和当时进程核验为准。

正式RC：`0.2.24-roomfix5`，`release/RConnectMod.swf` SHA `78c052aea963f1689b705ae1e14d274916ae1a1f7e81933390caf8d1a88f4699`，195147B。
用户要求先部署后继续；回执`build/m52/recovery-room-user-deploy-01/deployment.json` SHA16EF10BA，22项仅RC变化；同目录备份DF0F/aura1。执行脚本原字节冻结deploy-executed.py（639166DB），随后维护源失败路径已加固但未重跑。安装后单实例smoke ed2fa23d99已通过：78C准确字节、14模组初始化、tick200及日志检查；installed-smoke.json SHA BCAD4048，独立副本已清理，仅启动资格。性能资格仍false。准确产品源/编译在recovery-room-production-05，不是历史src/dev版本。
此前aura1回执recovery-aura-offline-deploy-02，smoke7d45932e01及EB365备份保留；上一层574D见recovery-offline-deploy-01。房间修正本次首次交付，高速运动等尚未全交付。

12:39正式ModLoader另行更新为2050E023，启动smoke实际用了该新字节；旧性能证据仍是BD71不重标。新测试需另记telemetry.json存在/内容/隔离复制。post_deploy.py先前预检通过，但现在正确拒绝这项额外变化，不继续叠历史适配。

当前宿主A796：`a796827173af7d6fab9885fb66ecc62182ab5335918a30c7cce4c44914a238b7`，CS于10月24日上午从ABE2独立更新Grafon两处颜色方法，回执`mods/ContinuousScene/state/scene-tint-deployment-20261024.json`已verified。前一ABE2来自Camera.calc修正，旧回执`vertical-camera-band-deployment-20261023.json`。RV于15:17左右独立部署为BF4AC9CD (`bf4ac9cd87272b03fae7ec22ee67d045f037362f412ee801cad3f9ba9fe3afef`)，其会话回执effect-load-v3-output/deployment；此前0DBE为历史组合，其余CS7F1F/SandCEC6/WB14112等未变。旧80CF/ABE2/6DBA的历史不改写、不与新宿主耗时混算。

**10月25日02:39:37 RV再次独立部署**：正式RV现为 `638e2d408e2cf46683c41114f75773829a1b4417d74bffe9d08855a4fe343710` / v0.33.10-render-cache，回执 `mods/RealisticVision/state/deployment-v03310-2026-10-25.md`。根随后实际核22项仅此一项从BF4A改变，RC78C/宿主A796未改。上文截至02:37的原生测量与host03构建仍属BF4A，不能重标或将新RV速度计入RC收益。原生UI已编译产物可保留，但旧探针验证器强绑历史安装，下一测试入口须准确区分编译时与运行时环境；不伪造installed()、改旧回执或无谓重编宿主。

**房间对照候选roomfix4**：`build/m52/recovery-room-production-04`，SWF `34a17de66e9a89165b4bde75d22ec1dd3d4295bb496b903124687af80422b703`，195145B；prepared093916CF，compile3CDE928E。编译时80CF/0DBE，已完成实测ABE2/0DBE须分清。源配方`experimental/recovery-room-production-v4`。roomfix5为78C052，已按用户要求部署，真实遮罩/性能仍待验证。
来自准确aura1的11类房间修正：并行生成，未换房者不停，当前原房不自恢复，实际入口放置，绑定原生Land/Room交接与连续过门请求，READY观察标记去重、暂停时不耗跟随期限，原生加载素材与文本，地块完整标量表/准确绘制缓存。v4仅比v3删除RoomCodec每次同步文件诊断（候选误留，正式版无此日志）及改版本。房间生成/字段/伤害不删减。

诊断专用roomtime1：`recovery-room-loading-counter-product-02`和`recovery-room-loading-counter-driver-01`已编；来源`experimental/recovery-room-loading-counters`。只测首次grant及随后2帧9函数、14阶段标记、消息累计；原场景/断言不变，不能部署也不给净性能资格。product01因AS try/finally返回分析编译失败，原失败保留。

## 4. 最新实测与卡点

- **04:31 首程账已闭合，无需新宿主计时器**：34df同一轮主创建4584+进入771+LAD913+WB前景923/背景496=7687ms，剩132；加入4504+706+910+927+458=7505，剩143。计时不互含，WB最后重建次数/真实RENDER已对齐，不能叠累计心跳或借6d367旧轮数值。LAD普通房两次重绘位于原生进入之后；现有首绘接口限定sceneLarge，尚在只读准备最小接口提案，**LAD代码改写未授权**。小采样组件真实9/9：跨事件保留正常，回调0次未覆盖，长游戏零样本仍失败，不继续同样采样。细账见three-performance-goals。两旧测试音乐副本逐字去重210份，释放1043MiB，保留证据和恢复回执。正式78C/A796不变。
- **04:16 首次加载CPU诊断失败，游戏/UI通过**：34df1bfb97于04:13实际启动并完成；原主23/加12与双方11显示观察通过，三程入口0px。新增诊断整体失败：主7819ms/加7648ms的RENDER20→19窗口、暂停/清理/身份均完整，但双方totalSamples/cpu为0，不能据此判为GPU或等待。原共享runner的PASS只覆盖游戏/UI；新result.json明确false，失败证据保留。22安装和全部输入未变，自有89280/125272进程已退出、副本已清。先以同AIR运行时小组件区分跨事件保留、缓冲耗尽及回调是否真正支持，不重复全游戏空采样。下条04:10排队状态已结束；正式78C/A796不变。
- **04:10 首次加载调用栈诊断已编译**：新 `goal-loading-cpu-probe` 清单C323BBC0、prepare E10112B0，五AS只给原三程增加4接点，原35+11保持；`goal-loading-cpu-driver-01` 真正单Java成功，驱动35A7A1B2、Harness D52E，登记78bba40b，PID60724已回收、22安装/输入不变。`goal-loading-cpu-native/run.py` 77B4B319独立窄审及实际--check通过，实际扫描23份运行二进制无其他显式sampler API。首次真实RENDER20→19采样，pause后下一ENTER整理清空，截断不给完整资格、全轮不给净性能。根已启动run输出 `goal-loading-cpu-native-01`，34df1bfb97 / 登记44e7fb7目前排队；exec session89700，未有结果，不误称AIR已开始。共享队列非FIFO导致后发先获，已向获授权CS/RV一次协调当前步骤后不追加，不中断现有测试。CPU探针不涉及另一个待答精确记录授权。
- 分房运行接线 `goal-native-loading-split-native` 已准备并根窄审私有设置修正，run10E478F6/README56DC9039。复用原600秒流程及hidden-only准确CS=false/telemetry私有前后核验；真实--check仍因被拒的source.diff/source-manifest和未编驱动not-ready。没有重试被拒写入或制作替代清单。相关源和03:44状态已提交882e77a；无新正式部署。
- **03:44 最新结论（覆盖下列03:34/03:07待运行状态）**：12轮背景门 `goal-native-loading-hidden-01` / cdf04eb69d 已全部通过主121/加157检查：宿主仍控制自己、真实背景门往返、死亡不复活、存活敌人血量保留、汇合后轻机枪单次伤害。14模组/22安装与源未改，全部自有进程和副本已回收。原生UI现有普通三程与背景门功能资格；尚缺一人换房另一人不遮挡的准确新观察驱动。其清单/差分写入精确授权仍待答，不复用上一条授权、不换工具绕过。最小单编译入口 `goal-native-loading-split-build` 已准备，真实预检明确not-ready，不会伪造缺失清单。
- **03:44 自身快照裁剪未获得稳定收益**：反向78C `goal-self-echo-native-baseline-held-02` / 6f756a7883也通过原43/42及四完整窗，加权主15.676/加15.045fps；候选9305为15.929/14.847。三轮次序为旧12.361/12.348→候选15.929/14.847→旧15.676/15.045，首次改善不能归候选；候选不部署，不继续无依据重复。反向旧>100ms主13/加8、候选13/14，抓取延迟旧120/120/100/110ms、候选120/120/110/110ms。正式78C/A796保持。当前没有根AIR/JVM；共享队列由CS最终复测使用，不抢先部署或另排冗余测试。
- **03:34 原生UI首次真实通过**：用户已批准上一条准入记录精确授权；根原命令成功写4FDA39，8分钟单条grant执行后立即撤销，其余授权保留。`goal-native-loading-native-01` / 6d3672b9e3 原23/12及双方11显示检查全过；三程同房同入口距离0，真实vwait同对象/父层、零旧复制节点/桥故障，根已查看终态PNG正常。主8430/2251/3876ms，加8540/2266/4015ms；首程RENDER长段7346/7653ms均exit20→19，停顿前vwait已显示且black alpha0。**只授普通三程UI功能，不授加载速度或全面发布**。14模组/当前22安装未变、无压力/并发停止，副本回收。背景门12轮 `goal-native-loading-hidden-01` / cdf04eb69d 正在运行，原生分房探针仅改一份AS，其清单/差分记录原调用被同类护栏误拒，另一条精确文本授权已问待答；不得复用上条grant或换工具重试。
- **03:34 自身快照完整产品与对照**：新配方清单318748F6、builder30BEF16C，生产/组件AS均保持原100项通过字节；完整产品 `goal-self-echo-product-01` / 9305CEAD /195216B 两条Java成功。新当前环境独立运动入口 `goal-self-echo-native` 冻结8F0EE633/CFC69DD8，历史BF4A与当前638E分开。78C基线85acfc3f17、9305候选49cb60281b原43/42和四窗均过，加权主12.361→15.929/加12.348→14.847fps；延迟120/120/110/120→120/120/110/110ms，初步改善仍须排除时段负载。反向78C `baseline-held-02` /6f756a7883在共享队列，不提前授收益/部署资格。正式78C/A796仍未更换。
- **种子与加载对照补正**：准确driver01确实给solo/host同布局种子，并非只记录标签；A796 Land仍有未纳入种子的Math.random（隐藏区域/敌群/出生），Location亦有随机。旧普通solo92ec与dual7eb实际入口同为161.8,320（此前不同落点是另一组大图）；units含玩家/代理，不能直接叫敌人数。严格首次生成等负载不能只看seed，普通旧房可复用同一已构造Land；首次构造随机回放尚无实现，不以恢复快照冒充首次生成。
- **03:07停点与独立推进**：原生UI宿主03根语义审查已保存 `root-semantic-review.md`，但写 `runtime-admission.json` 的准确混合命令被护栏误判SWF写入；用户精确授权问题仍待答，不可自行维护表/换工具绕过。`goal-native-loading-native-v2` 已在根明确重开后冻结为A5B2CE70、清单7D62B3D6；保留4dc936f旧形态，原真实installed不改，严格分开历史BF4A和当前638E，21项不变、RV准确回执固定。三份实际产物只读验证通过，根实跑--check仍明确仅缺准入JSON，未启动双人。授权到达后执行原被拒命令、撤销精确grant，然后该v2的--check与原35+11实机入口，不重编宿主。
- **自身快照裁剪组件实际100/100**：`experimental/goal-self-echo-prune` 冻结清单1FDD8C00；生产只改Session和版本selfecho1，79类不变。唯一开放认证连接与唯一peer精确对应时，仅发送给本人的snap改null，保留id/name/名单、原peer.snap和全部广播时序/事件。原完整两方法+真实编解码/HostServer组件 `goal-self-echo-prune-component-01` / a72f84aecffc4246a88f4c308ed542a3 已通过，SWF A4757765，JVM/AIR退出、源码和当前638E组合22安装未变。非真实TCP/游戏/性能资格，完整产品未编，后续需在新环境做单变量对照。不能合并旧传输提案中的取消收包广播改动。
- **10月25日02:45最新接续**：78C回测 `goal-three-issues-native-held-baseline-02` / 0bde20bba6 原43/42和四段测量通过，延迟110/110/110/100ms，旧170ms未复现；新运动v2的独有收益不成立，后半掉帧风险保留。独立探索noop产品1B921137、`goal-exploration-noop-native-held-01` / 54916ecb8b 同样43/42通过，延迟110/130/110/110；加入加权fps14.87→15.75，但主15.54→14.53，不能授整体性能或部署资格。两个新运行均完整、无压力/重叠中断，准确14模组/原驱动/22安装不变、已清理。
- **真正原生加载UI已编译，尚待双人**：产品 `goal-native-loading-product-01` 为9C8536A7，宿主 `goal-native-loading-host-03` 为2DB0B4EB，实际保留审计和根/独立代理P-code核对通过；探针driver01为877B05DA。host01被JPEXS正常日志写权限拒，host02因证明器不认识0xB0拒；host03独立V2只补二元比较的栈语义，未放宽检查。实际原exitStep只加t16尾调用、两个Boolean缺参均false，其余3275方法/资源保留。`goal-native-loading-native-v2`冻结，仅替换宿主验证器/host03，原35+11/600秒检查保持。根语义记录已写，保存runtime-admission.json的混合读哈希/写JSON命令被本机护栏误判SWF部署；精确授权问题待答，不绕过、不改安装。
- **普通生成已经重叠**：ordinary-dual-02 首程宿主exit20→19为6680ms、加入6766ms，整程仅7488/7519ms；二者不可能串行相加，种子hook在生成主体前发送prepare。缺实际首帧vwait可见证据由新探针补；不要再把普通首入误判为宿主生成完才通知加入。原生生成期间视觉模组仍计入，尚不能归纯地图算法。
- **新运动v2：功能通过，性能资格仍否**：B25E477A/195281B，68实际组件全过，原生跳跃e7f61547df双6/6通过，无v1两秒追播，严格空中移动重复0/163；本机主20.65/加20.27fps，加入仍183ms长帧。四轮抓取23ba08ed52已完成原43/42，拟合延迟110/110/110/120ms；原失败箱子加入抓170→110ms，但后两轮本机主约14.6→11.8fps、加入约14.8→12.8fps，长帧增加。输入/驱动相同但单次时段对照不足归因，必须回测准确78C，不部署v2。审查见goal-motion-clock-v2-native-review。
- **加载显示与重复探索合并**：原生World.vwait候选实际37/37组件通过（e91371bb），仅结构组件，宿主实际移植仍待编译/检查；UI产品goal-native-loading-product-01正排共享队列。重复探索合并候选实际104/104组件通过（6751b245），完整产品未编、原生收益未测。普通三程显示观察器goal-native-loading-probe已冻9BFC73C2，原35检查另加11项真实RENDER观察；未编译。正式依旧78C/A796/CEC6。独立11模组原基线c783ed51d1主28.83/加27.56fps，只能作三模组组合归因，正式选择不变。
- **10月25日01:30普通双人与CPU已完成**：ordinary-dual-02 / 7eb70d4ed0 原35项通过，主7.488/2.301/3.563秒，加7.519/2.320/3.726秒；三程同房同入口距离0，加入恢复仅67/81/77ms，长段在原生exit20→19（含其间模组工作），不是本轮普通房握手多耗数秒。不同solo人口/淡出流程，不能据此给单人等速资格。local-frame-cpu-native-01 / c6b41f812f原双6/6和六窗诊断通过；主113、加131个样本，pre-render/render分别77/68。加入23样本在ExplorationSync.receive，其中22进RV合并，全部集中第6窗；不是全程稳定占比。帧渲染样本无AS归属，不能指认某模组或“两遍GPU”。无新增部署，所有本轮自有AIR已回收。关闭LAD/RV/CS的同驱动跳跃薄入口在准备。
- **10月25日三项目标接续**：正式仍78C/A796。实际用户帧记录与最近一次初始化日志已只读冻结于 `build/m52/goal-three-issues-user-session-01`；两端最后版本roomfix5。会话先合并图term2，后普通图term4，不能整段归一种场景；普通term4宿主记录7072ms、加入恢复1271ms。帧记录两个300窗口仅约51秒重叠，前后台差异明显，不能整体对比当同负载，更不能以Y位移证明跳跃。
- **RemoteMotion最小候选已实际否决**：`goal-remote-motion-current-product-01`，89F1B923/0.2.24-motionclock1，37组件通过但真实跳跃99eea9cf09出现追播旧轨迹，严格空中移动的加入侧重复2/152→6/149，不能部署。原6/6只是动作功能通过。审查与缺失的累计校准回放见 `experimental/goal-motion-clock-review`；v2独立候选正在准备，冻结旧源不改。本机gg不走该插值，本机掉帧另测。
- **玩家已退出后恢复测试**：00:17两B190试玩仍在，随后B会话收到用户保存退出确认，根提升CIM核实退出；不重复提问。沙箱内进程空数组曾是假阴性，运行器在提升上下文核独占。新37组件全部通过；普通solo92ec33a932完成11检查，10.431/5.551/6.897s、首程exit20→19最大6587ms，源/输入不变，无压力或重叠停止。不能与旧合并图混比。普通dual232889205c排到后无其他AIR但仅5.83GiB，未启动，失败保留；3/6GiB门槛不变。
- **已安装版**78C/roomfix5 的当前全14组合三程双人7cadcc8267与单人fc4111c750均通过；双侧房间/入口/控制一致，但加入大图首入15.068、重访8.208秒，单人6.642/3.101，未达目标。原生“加载中”素材取代自定义交接UI；本轮没有再部署相同字节。
- **新首绘桥已完成并实跑**：6D/roomload1 + FBA27宿主 + Sand003（3E220）。原驱动384e92463c双41项通过，主10.152/2.545/5.588秒、加10.153/2.423/5.772；两次真实constructed/activated同票据，三程入口差1/0/1px。首入/重访总耗时明显减少，但主侧自身慢了，仍未达到单人速度，未部署。
- **单人退化风险仍在**：原基线三组6.642/1.732/3.101、7.448/2.103/3.021、7.028/1.901/3.154；新组合两组9.223/2.176/3.659、8.086/1.836/3.396秒。旧大图落点161.8,4320，新1161.8,4800，原生人口也不同；三组旧/两组新规律原因尚未解释，不能声称无回退或全是随机。RC离线未启early/改偏好/搬位，但新旧还含不同Sand，非单变量。详细回执见NATIVE.md。
- **真实四节点诊断通过**：02/cd917646ad为41原检查+20附加检查。授权前及完整恢复内没有地形绘制，绘制后才恢复控制，四块抽样身份保留；非全图仅一次、GPU或逐像素证明。01/9d81因观察器缓存roomKey取旧房失败，原失败保留，唯一修正roomKey(refs.loc)。driver02=4FC274，来源已冻。
- **2.4秒首次绘制长帧仍是主线**：cd917加入grant-after37483→first-raster-ready39881为2398ms，ready仅再1ms；当时exit0/fadingfalse，排除固定退出动画和ACK延迟。期间图块0→24/regionPass35→40；不能把全部CPU归Grafon，仍包括同帧视觉模组。World.step→cam→Grafon.sceneTick/sceneEnsure/sceneEnsureUpcoming/sceneFirstWindow为优先读点。busy会挡unitsync/地形等新包，玩家worldstate仍可处理，不能照搬旧14次unitsync归因。
- **两类循环候选也已测，不部署**：roomload2/FBFB8389，product loop-product-01，200069B；仅版本及NativeTileState/TerrainSync，79类不变，实际双Java编译通过。7852f0beae双41检查通过，主10.358/2.464/5.984、加10.414/2.301/5.979，整体未改善。terrain段省79/91ms，但grant→ready多683/719ms；落点/人口不同。52冻结及22正式输入未变，私有副本/PID已清。之前290e8bf987仅5.714GiB启动余量不足，无AIR，失败不改写。
- **资源状态以当下为准**：7852启动7.845、最低3.073GiB，69采样无压力/重叠停止。根本轮AIR/JVM均已结束；不要继续沿用17:48内存阻塞。编译/测试排队使用共享登记，不发无意义跨会话催促。
- **冻结协作已收紧**：配方编译后审查方擅改三文件触发预检拒绝；根保留unapplied-loop-builder-review.patch，再按原SHA恢复，SWF/源/编译回执没改。之后7852按准确冻结配方运行。冻结后只报告意见，根明确重开写范围前任何agent不得续改。

## 5. 已知问题和不能省略的语义

- Git已查：574D→EB365→DF0F房间/旅行/遮罩源码相同，旧加载修正当时没有交付；不是“已修又坏”。不能用局部候选或函数等价否认用户性能退化。准确报告见PERFORMANCE-REVIEW.md。
- 正式roomfix5首改共同旅行/普通分房/同入口/原生加载图，历史普通分房与背景门实际通过；新6D/FBA组合仍需普通分房、背景门和持续游玩最终回归。当前大图速度证据不授密集场景资格。
- shelf实变使原视图不可复用；WB14112也依赖该字段，不能忽略。首绘桥在完整checkpoint恢复后才允许真正绘制，避免重复栅格化。不能手工清isRebuild/isRecalc省必要水体/照明处理。
- NativeRoomState单位段含原生外来实体退休/重建，不是纯镜像创建；mapxml、脚本、武器、掉落引用不能凭U序号或150px位置复用。不能删字段/动画/伤害/完整状态换速度。
- 不整体丢弃worldstate/unitsync只留最新，里面包含冲击、武器、轮转地块等一次性事件。预采集最多可重叠约416ms，但READY前可靠地图奖励包仍会改世界，暂不新增复杂失效缓存。
- 小循环roomperf1没有真实整段收益；roomload2也没改善。MirrorMasks.capture实测29ms不是3秒主因，不做复杂全局索引。已部署单行mask优化仍待当前准确输入的8轮原生遮罩补测。
- A Sand003仅候选：允许共享加载冻结，缺桥或活动/回放走现有路径。正式CEC6不变；WB首次初始化删除refreshView提案无答复不动它。
- 高速弹丸、击墙、念力、掉落及持续性能目标仍未完全完成。真实用户Unit.run #1010在隔离Littlepip29未复现，不称已修。

## 6. 下一步入口

0. 当前先执行三项目标入口：`experimental/goal-ordinary-loading`（普通三程）、`goal-three-issues-native`（原生跳跃/抓取测量）、`goal-remote-motion-current`（已冻/已编最小运动候选）。原两B玩家窗口已退出；37组件和普通solo已完成，dual232889205c因5.83GiB未启动，下一新输出仍用原共享队列/内存/独占门槛。详细边界见three-performance-goals记录，不把下面历史合并图路径当成唯一目标。
   最新：轻量组合 `goal-ordinary-reduced-solo-02` / 7ad109f075实际通过14旅行检查和11模组真实加载核验，8.616/3.968/4.941s；出生/单位数不同，不能量化单模组收益。跳跃基线74932502cf和候选99eea9cf09均已完成动作检查，基线本机主20.20/加18.37fps；全后台、不授前台体验。候选实际追旧轨迹已否决。念力基线ad378fee3a已完成四轮但主侧观察加入抓箱延迟170ms超过原160ms门槛；失败保留，独立failed-measurement-diagnostics保留完整测量而不改判。两侧念力阶段约14–16fps，需CPU定位。
   测量驱动实际成功目录为 `build/m52/goal-three-issues-native-drivers-02`（跳跃9EE16FA6、抓取FEF72AB4）；01的Flex返回分析编译失败保留。不要按README首次示例误用01。CPU诊断驱动已编 `goal-local-frame-cpu-drivers-01`（13A5039C），真实运行及普通dual02均完成见§4。第6窗枚举耗122ms，会扰动后续帧，CPU轮不授净帧率资格。下一步原驱动轻量组合、运动v2及真实原生加载UI候选，不重复跑已否决89F1的抓取。
   加载UI核查补正：78C仍是独立黑底+原生素材副本，并未真正只用原版实例；此前“原生加载素材”不等于删除额外UI。`goal-ordinary-loading-review/REVIEW.md`列窄World生命周期桥和普通门边界；`goal-native-loading-ui`独立源码候选在准备，不能停t_exit或反复setLoadScreen。正式仍78C/A796，未新增部署。
1. 正式仍78C/A796/CEC6，不重复部署或把未达标首绘桥替换安装。加载主线是首次可见区域生成/同帧视觉工作。准确Camera.calc在sceneTick前更新位置，跨房/急移重置，grant先place再allowPaint；正常路径不支持先画旧视口假说。六层backobjs重复查询存在但耗时未量化，不能据此另造微优化候选。下一有意义证据是同最终入口/视口的配对或有界实际首绘成本，不重复排查ACK/t_exit。
2. 准确首绘产物：build/m52/recovery-room-first-raster-product-01（6D）、recovery-room-first-raster-host-current-03（FBA27）、Sandevistan/build/out/a-travel-hold-20261022-003（3E220）。循环候选loop-product-01（FBFB）已经原驱动验证但无整体收益，勿盲目重跑。两组新solo也已完成，不能当作仍在跑。
3. 实机复用experimental/recovery-room-current-comparison/run.py，显式--product/--raster-host/--sandy-bridge/--mode；默认原scene-driver02与原run_coop_regression.py（7ECA）不改门槛。--diagnostic-driver只取阶段证据。每次新输出目录，原失败保留，当前输入变化必须准确记录。
4. 根唯一JVM/AIR；当前无根测试。最终候选须按当前实际组合取得大图/普通分房/背景门/密集证据再部署。用户允许隔离关LAD/RV/CS，但不同组合必须单独配原生solo，不混基准。

## 7. 详细记录

- 首绘实测总表与最新失败/收益边界：`experimental/recovery-room-first-raster-current/NATIVE.md`；当前桥源码与组件见同目录COMPONENTS/independent-review。循环配方目录冻结不可顺手维护，结果记NATIVE/state。
- 当前此前详细快照：`state/recovery-evidence-through-first-raster-2026-10-24.md`（归档中“正在进行”均按本快照为准）。
- 近期完整取证归档：`state/recovery-evidence-through-roomfix4-2026-10-24.md`；更早`state/recovery-evidence-through-offline-collector-2026-10-23.md`。
- 房间源/配方/测试准确绑定：`experimental/recovery-room-production-v4`、`experimental/recovery-room-repair-review`；旧检查器锁80CF，新`current_host_verifier.py`分别绑定旧构建和当前ABE2，不改历史回执。
- 现有正式候选发布：`experimental/recovery-room-production-v5/RELEASE.md`；旧aura发布说明保留。历史过程在journal顶部及各experimental/RESULTS；日志只追加，失败不改判。
