# RConnect — 开发记忆入口

## 1. 模组与当前职责

Remains 1.02 双人合作。A 是普通入口现用同步架构；B 是独立主侧统一执行架构，两者并行。本会话 01a086bb-378c-7f60-b8e1-50d90ffa0996 统一整合、验证、部署。
用户要求撤回下午部署的 motion2，重新修复加载、念力光晕、击墙效果和高速运动，减少对话互相打断。**回退已完成；本轮不恢复 B。**

## 2. 已确认玩法、授权及协作

- 中文通俗交流；加载目标是实际恢复操作达到单人对应流程耗时。不能只隐藏交接UI；未换房者继续运行，共同换图出生一致。
- 普通房可分头，无人房暂停保留本次进度；剧情/挑战共同进入，宿主发起整图旅行。物品一份先到先得，经验双方奖励，存档点共同解锁各存角色。
- 跟随默认关；共享菜单/SATS暂停默认关。被念力抓默认关、WASD挣脱开、抛掷伤害/友伤默认关。安保破解默认共享，切换保留已有权限。
- B 双方有人房由主侧执行；共享时停，回放时结算伤害。B 独立 TDFC/MSW/RV/Sand 接口授权不能自动用于 A 新接口。
- 用户授权所有 RConnect 会话协调；本会话唯一部署。FA 念力兼容已交还所有者；RV/WB 指定局部优化及 LAD/CS 测试部署协调已授权。未点名 Ghost，不使用。
- 常规测试仅走 ModLoader 共享登记 game；根串行编译/AIR/部署。子代理只写独立目录，里程碑交付；不反复向其它会话广播状态或争抢时段。
- 唯一 AIR ID、后台桌面、隔离存储。只清自有测试，不关闭用户程序、不写真实存档。Littlepip29 仅只读复制到测试槽9。
- 双实例6GiB/单实例3GiB/组件1GiB启动余量，运行512MiB保护不降低。省D盘，清可重建副本，唯一失败证据保留。
- 本机验证及门禁通过后可直接部署。用户此前“先部署”例外已被回退要求取代，不再放行失败候选。公网/重连/多人/其它版本不在本轮。

## 3. 安装与准确候选

**安装仍 0.2.23-coop-bundle2 / 574d2b51490ae8b25a1396555600f56a301f8a20ae50104c0e35cf2796441afe。**
回执 `build/m52/motion2-user-rollback-20261021-215647/rollback.json`；精确授权用毕撤销，勿重做或再问。
宿主 BEFC，CS7F1F、WB14112、Sand CEC6；每次冻结22项。RV于2026-10-22约18:25由其会话更新为AB461FF3…F23871，之前本轮实测使用7852…E86764。已实读确认其部署备份保留准确旧7852，后续重访诊断将显式注入旧RV到隔离副本并单独核对当前安装；不回退用户RV安装。没有将其它模组回退，不能称整个下午全部安装均恢复。

| 候选 | 准确来源和用途 | 状态 |
|---|---|---|
| 13 / 1177EB…FDDB1 | `recovery-integrated`活动源仍是13，87AS | 加载/密集失败 |
| 18 / 11B795…38FE4D3 | `recovery-wall-color-buildsrc`，16的大图桥+原生反查色表 | 90AS，大图仍有极少1级差异 |
| 19 / B9CD3F…DFEEA5 | `recovery-wall-base64-buildsrc`，18仅改编码尾段 | 90AS，组件63/0；实际密集失败 |
| 20 / 0674019c4aeea22900aef3e2390a31aed4fafc7850e0f3a74bc5ebb2facce9f5 | `recovery-defense-buildsrc`，19仅补18个原生变量快捷表+版本 | 90AS，组件81/0、完整编译及密集失败；未部署 |
| 21 / 9ac7ede757c253bbf61e0c44334870b4a95112f976c1b40f2f390822a8b7e7ba | `recovery-wall-decode-buildsrc`，准确20仅两解码类+版本，87类字节不变 | 67/0组件、编译；密集前两段仍失败，未部署 |
| 22 / 746eef5713985f23fe13a57792516789bebd37a5e4142639ba8cc8b6590b3e93 | `recovery-small-color-buildsrc`，准确21仅两处普通房最终写色+版本，88类字节不变 | ACC大图四例最终uint一致；普通房加入plamg漏掉22个墙沿像素，其余三例过，未部署 |
| 23 / 87fafd6646b5fa07fd8fa280ed7e82f7e69631850e67b0748d9cad22de2f0b6c | `recovery-pause-flush`，22仅CoopPause/Session暂停边沿补发+版本，87类不变 | 50/0组件，八轮功能过但首次暂停观测对齐无改善；不作为已验证优化合入下一版 |
| early / 10B249…1FAE6 | `recovery-early-buildsrc`，16+并行早交付，单独分支 | A Sand003已接入隔离测试；首进/基地过，缓存重访超时，未达单人耗时 |

20不含15姿态、17地形、小房反查色修正或early。19→20另外88类逐字相同，GameBridge只合表项，没有旧整类覆盖。完整清单见各integration/prepared，不能凭版本名混用。

## 4. 近期实际证据与结论

- **原生加载**：13/FD92双人96b09cd943，三流程同出生；加入首进/基地/重访17356/2836/12868ms，对单人7928/1960/4032ms，未达到目标。确认先宿主绘制、交付后加入侧再绘是串行关键路径。
- **光晕/普通效果**：祖先03双向玩家光晕591项及目检过；05普通墙击210项；09酸液92项+24图；11念力85、容器/SATS52、跳跃12过。仅对应这些准确祖先，不赋予20整体资格。
- **高速长帧**：14实际闪电95ms空档前已有未来轨迹，缺中间真实游戏帧；不能只归因缺包。气体末姿态32ms区间可被42ms正常游标跨过，不以延寿补帧改绿。
- **墙面大图**：14/FD92四例源有墙痕、对侧0，是真负例。18/ACC旧轮仍有两opaque错点；386a671a97完整crop四例最终uint精确过，源core/gutter实有1级不同。保留旧失败，不宣称已完整归因。publish-core扩展会牵涉raster先重放与ACK顺序，已停止生产扩展；见`recovery-wall-core-ownership`。
- **编码局部**：19组件63/0，24块ABBA完整编码平均529.833→398.250ms/246次，仅局部24.83%下降。20防御组件81/0，原生20000次ABBA517/275/273/549ms；普通回退242/232/238/260ms。未知getter/公开名单追加字段仍容错，不改读取顺序/频率。
- **准备差异已修**：driver02加入侧原生随机初始枪使同型枪弹匣hold为0或12，准备只核id；hold不是冷却。driver03仅准备期一次补齐原7参数、检查完整武器字段及对象身份，原80本体/39枪/12开火/7段/阈值不变，23静态过、实际编译及准备过。不是产品弹匣同步修复。
- **默认组合有效密集对照**：driver03、BEFC，18 run9d69429997主29/0加39/15；19 cb78be831e主29/0加40/14；20 ab6af44ac3主29/0加40/14。19/20严格prepared与corridor差异均0，22安装和独占成立；逐帧与瞄准每段各失败，20加入七段37/41/36/41/39/39/40帧，p95 338/389/395/355/363/379/370ms。没有整体收益或发布资格。原raw非链命中代理dx差异另列，不能宣称所有原字段完全一致。审查见`recovery-density-ready-review`。
- **停止零散优化**：14采样只支持一处同回调重复采公共敌人状态，未量化足够收益；无证据把积压/重复动画当主因。保留本体与命中代理责任，不删动画、减频率或改ACK换FPS。见`recovery-longframe-review`。
- **实际玩家配置对照已完成**：两份只读RV设置均enabled0，574D run7575281d1c主29/0加46/8，20 bd9a4b01e7主29/0加49/5。七段加入帧数旧59/74/74/74/73/74/76、新73/79/80/81/79/76/78；p95旧208/225/210/222/251/210/238ms、新178/196/194/175/196/202/180ms。配置模板、安装、驱动、实际RV启动日志和用户设置不变均确认，20严格prepared差异0。仅一次A/B，新版仍未达标，不算FPS收益或发布资格。默认开启条件的原失败全部保留；不是关闭RV的优化提案。入口`recovery-density-profile-settings`45纯检查过，独立审核在`recovery-density-player-settings-review`。
- **实际配置CPU诊断043b72eaec**：原driver03十一AS不变、只切既有profile入口，编译和实际采样完成；主1546/加958 CPU样本，各24窗。加入一帧间隔320ms中窗内27ms、窗后293ms，前后无记录采样；另294=30+264ms。原采样在首次RENDER入口结束，未覆盖最卡部分，不能据tickFrozenAnims的230个包含样本指定主因。准备有界窗外诊断，不再加生产微优化；采样帧率无门禁资格。两轮真实日志及独立分账见`recovery-mirror-cost-review`。
- **窗外CPU诊断b3d7b8558b已完成**：保持旧RENDER -1000000到下一stage ENTER +1000000，61纯检查、独立编译、双方24完整采样窗，无丢行/栈截断。主854/加1614 CPU样本；加入TcpLink.onData包含811，handleMessage585、墙痕receive178、applyUnitsSync177，叶render410/pre-render257。含关系不能相加或当收益比例；最慢样本窗182ms，另有采样整理217ms单列，不能用诊断FPS授资格。原生绘制与收包处理都落在此前漏掉的范围，正只读审查接收路径具体重复。准确证据`build/m52/recovery-after-render-sampler-20-01`，真实设置/22安装未改，自有副本已清理。只读API核两自有PID的control_mask/state_mask均0，仅确认未显式设置，不证明节流因果。

- **接收批次实测 e53cb3730a**：外部观察器78纯检查、编译及原生双人完成，七段加入823批/240完整/648快速；没有一批含多份完整快照，最长117ms批含3快速，其中单条100ms且无墙痕，不能将全部长帧归墙解码；另单完整同步回调88/94ms，墙痕5–6格/约40–48k字符。双方观察完整、零诊断fault和运行异常，原5项性能失败保留。完整输入/配置/安装不变，`fixture-audit`为无reference诊断，不能拿默认input_comparable=false误称准备不一致。报告`recovery-socket-batch-review`。旧netMax=78378已证实为density-commit进入load时netAt仍0的跨阶段计时污染，不是真78秒收包。
- **正式进程策略实测 c77d41be46**：只在owned测试PID使用原正式双开HighQoS，两侧启动回执1/0及helper/描述符验证通过；主29/0、加入47/7。七段71/76/79/73/77/76/78帧、p95 164/214/191/250/204/205/179ms，仍失败，不把策略差异当修复。独立对照已完成：driver03、当前RV模板、22安装、runtime_signature完全相同，双方prepared/走廊零差异；raw加入侧非链MirrorHitUnit.dx差异保留。普通轮无策略读回，运行时间、内存和准备前历史不同，不能作策略效果的因果结论。见`recovery-formal-policy-review`。
- **解码21实测**：67/0实际组件，W1固定ASCII表/双字节写入及省重复数值检查，旧格式/缓存/整包ACK不变；组合冷解码ABBA旧880/870/845/833ms，新634/665/648/631ms，仅局部。新鲜20→21原生对照7491942feb/ca32e42aaa，原driver03、正式策略、玩家RV模板及22安装一致，严格prepared/走廊差异0。加入20为48/6（5帧+1瞄准失败），21为52/2（前两段帧失败），主均29/0；21帧72/77/83/82/85/83/84，p95 183/192/172/175/174/156/163ms。有改善迹象但仍未过门槛，不部署；见`recovery-wall-decode-fast-review`。定向原生驱动01在两入口编译后，无关旧impact组件缺ProjectileExplosionVisuals闭包而失败；原失败保留，随后仅编译原生入口的02已完成，不放宽运行断言。
- **准确21定向原生已完成**：薄入口仅清可选COMPONENTS，原prepare/run不改，02两原生驱动编译通过；01失败保留。光晕d460ff8f14主296/0、加295/0，双方16轮完整，8张抓取/对照/释放图实际目检，身体光晕有像素贡献且清理通过。高速cc7e8dfe50主63/0、加77/0，8组lmg/quick/plamg/alilight及独立最终RENDER分析全部过，对侧最大可见间隔52/57/71/64/67/65/65/60ms。仅单发功能，非密集资格；两次22安装不变，自有副本已清。报告`recovery21-native-review`。
- **剩余快速接收成本**：`recovery-fast-receive-review`确认独立采样中applyEnemyMotion链116样本、queue79、sampleTimed52，含武器/身体插值24/10；包含不可相加，也非100ms那次同一运行。queue只消费x/y却完整求姿态，但5处currentSample消费者及嵌套输入别名使延后计算不等价。`recovery-position-alias-component-01`实际8项6过2失败，已算武器X6/身体帧3.4被延后方案改为36/5.8；同游标位置仍相同。没有生产覆盖，方案停止；正常游戏链主动改输入的故障未被证实，不把API反例冒称实机根因。
- **准确21三项运动复验**：正式策略、实际RV模板、同22安装下，f8bc3462f4念力85/0、60ccbb7140容器/SATS52/0、8a6260b367原生跑跳12/0，原结果保留。但`recovery21-motion-native-review`核得持有段观察249ms采样空档、掉落空中160ms空档且提前144ms已收到后点位置、SATS首暂停帧落后9px并在159ms后才观察到端点。原85ms只检查相邻坐标重复，漏掉换位置的长帧；跑跳截图造成4个约1.2秒污染间隔，另仍有205ms非截图帧首空档。**smoothness_qualified=false**，功能绿灯不关闭卡顿问题；不是新旧性能配对。
- **镜像步进审查**：20/21四关键类一致；旧诊断513 ENTER对应513 motionCalls、1024 viewCalls，未证实身体/武器双推进；终视野RENDER重复实际存在，不能直接删去。`recovery-render-cost-review`记录禁步、blit去重及采样范围。`recovery-offscreen-body-review`确认80敌人实际全部在视口内，屏外负载前提不成立；不实施屏外优化，也不将render样本直接归因于身体上传。
- **22写色修正及大图**：21完整墙面类仅put/replay两处调用NativeWallColor.setter，保留最新解码、ACK与逻辑颜色。`recovery21-small-wall-component-01`85/0，组件c456e3…dd0；90AS中88不变，完整22编译通过。driver04+ACC实际58af664bec四例lmg/plamg双向最终native/display uint完全一致，164/105/1169/1223个期望像素，无漏/多/错色。旧PNG表示检查失败原样保留，独立复核仅接受同预乘字节的PNG表示差，源/对侧仍严格uint零容差；详见recovery22-reanalysis-01.json。首次观察等待778/313/163/1341ms、采样空档最高577ms，不能据最终一致关闭及时性问题。普通房仍缺准确宿主的持久像素原生覆盖，不能用火星粒子测试代替。

## 5. 仍待决定与限制

- 最新普通房215270505b框架双侧34/0；严格像素前三例过，加入plamg→主侧1089期望中22点保持baseline超过7.6秒、0额外。已确认原生墙沿伸入phis=0邻格，而WallImpactVisuals全链只认实碰撞格；不是反查色1级误差。独立ordinary-wall-review/ordinary-color-review逐点核对。正在准确22上修普通房真实前景支持，不合23；原失败保留。大图case2的5390ms包含8发跨4550ms，末源变化→完整实际观察区间347–925ms，非5秒静止传输延迟。
- 暂停边沿23实际组件02为50/0，SWF7c71008a…334f5e；01控制类替换污染setCoopPaused的编译失败保留。准确正常背包枪八轮22 b09eac8fb3、23 4582357f26均主26/0加137/0，无运行异常。首次暂停观测→端点22为58–81ms、23为68–85ms，未见改善；身体位图8/8一致，恢复跳变0。无宿主补发单次耗时/次数，环境敌人准备移除9→6，缺完整场景指纹，不作全局性能因果判断。23不作为已验证优化合入后继；报告recovery-pause-native-review。旧裸赋枪9a806dee8c的FA 12条#1009整轮FAIL保留，不凭新轮通过判定旧错误唯一根因。
- 掉落有界显示观察c463d3510f在准确23、正常背包continuity驱动中完成，主21/0加31/0；原操作/断言不变。两侧2秒、合计256行上限，实际179/190行、无fault/溢出/对象身份变化。独立recovery-drop-render-observer-review核得空中RENDER最大间隔主39/加46ms；加入95ms间隔在落地后，其间一次ENTER；同帧额外RENDER主60/加59次均无新位置。14次loot到达含6空中/8落地，空中到达最大79ms但画面其间仍推进。首落地包→首次落地显示108ms期间持续运动，不是108ms停帧。旧160ms空中空档未重现，不认定修复；无FPS资格，原始在recovery-drop-observer-native-01。
- 普通墙沿第一修正没有合入：`recovery-ordinary-wall-edge`只凭当前alpha保护空格；组件01缺Bullet import编译FAIL。独立v2只修外部导入/既有Grafon警告并加同像素反例，实际组件02为136项135过1失败，SWF5c990fe3…be60e，唯一134暴露先擦空→后到新墨迹时ACK承诺颜色却不绘制。不是旧22点漏传的同一故障。生产源保持冻结，不改验收转绿。`ordinary-edge-review/structure-feasibility.md`核出最低结构通知涉及tileDie/decal/drawLoc/gwall；普通弹孔与结构擦除不同，同bitmap原地毁墙、半透明裁剪及两端不同破坏变体仍需统一权威颜色设计。尚未写宿主/实现支持缓存，不新增未经审查的长期状态。
- 结果数组微优化`recovery-weapon-container`实际70/0等价组件，SWF5a687099…45cd7；ABBA每块12000次×4武器，现代旧306/321新309/296ms、兼容212/221→216/201、混合274/265→259/306。未见稳定局部收益，不建完整24、不据此再跑双实例或宣称FPS改善；结论在recovery-weapon-container-review。

- 2026-10-22用户已明确授权A独立Sand加载接口及隔离合格后部署；不再等待或重复询问。基于准确CEC6的`recovery-sandy-travel-hold-proposal/README.md`：22行+独立载体，闲置才准入，时停/回放继续旧加载，不混入B源。用户也回复释放内存后继续实测，仍需实测启动余量。
- A Sand准确CEC6兼容候选已在`mods/Sandevistan/build/out/a-travel-hold-20261022-003`编译，3e220b595f54249c82fcad36e1b13364c0456c4e8b5f4e20f876c3964c7d331c；原10文件中9不变，entry只加22行，新增helper只补两个ASC末返回，未混B。独立94方法静态复核通过。真实helper组件03为76/0；01夹具多定义编译失败，02后台桌面权限失败未AIR、登记已核对释放，原记录保留。不是完整游戏时停或加载资格。入口`recovery-sandy-hold-build`及`recovery-sandy-hold-components-v2`。
- early217组件通过不代替真实Sand/原生加载。独立宿主2D415D…DD29原回读因init2变量声明移位失败；严格独立recheck通过，原失败保留。原生薄适配`recovery-early-sandy-native`已编译并实测：双人3b3c31c5f5首进/基地完成，缓存重访双方exit=0却未ready，主侧45秒交接超时，原95秒驱动失败。单人925d5f32df三段通过，elapsed 7178/2018/3290ms；双人首两段主10366/2438、加10508/2917ms。尚无绘制区间重叠证据，票据释放/完成的轮询样本不能代替真实绘制计时。正在独立有界诊断，不部署。
- A时停真实单实例9180342e9d完成41/0：原生Stage热键启动active/replay、两阶段真实载体及MapGeneration均拒绝加载持有，空闲持有12回调保持状态并拒绝热键启动，释放后再次启动/回放正常结束，无许可泄漏，22安装不变。当前配置cooldown=0、enemyEnabled=false，不授非零冷却/敌人补步冻结或完整旅行回退资格。证据`build/m52/recovery-sandy-hold-native-01`，仅功能通过。
- 同early/2D宿主而旧SandCEC6对照9435e4acd1首进已完成首次绘制，但加入无输入基线超过原1000ms门槛，加入结束后主侧等待超时，没到重访，不能作为重访控制组。原失败保留，不改阈值重跑。源级审查排除了restore drawLoc必然换票据这一简单猜测，真实卡点仍需有界日志。
- 有界诊断5b404cdea1完整复现且记录有效：运行二进制/资产/非RC配置与3b3c31c5f5一致，两侧旧RV7852、安装仍新AB46。重访加入grant发生exit=10；无条件TravelGuard.endTravel提前清掉同次原生退出许可，下一before.guardTravel把curLandId回写rbl且强制exit0，实际Land仍random_mane。票据false、Grafonready、身份全同，early.destination因地图编号矛盾失败，保持关闭至95秒。不是绘制卡死或换错票据。独立报告`recovery-early-sandy-evidence/revisit-probe01.md`。
- 精确early2源码`recovery-early-exit-authorization`仅RoomSync两处及版本，88/90类字节不变：early grant不endTravel，completeEarly成功释放外部许可后再endTravel，取消路径不改。319项静态来源检查，真实TravelGuard+RoomSync新旧回归及旧217组件待实际运行；完整编译已提交共享队列，输出`build/m52/recovery-early-exit-compile-01`。新的准确运行薄入口`recovery-early-exit-native`待编译产物freeze，不借用旧候选资格。
- 所有最终目标必须在同一准确候选重测；组件/握手/祖先局部通过均不替代最终画面和性能。没有新部署资格。
- B195及旧独立候选遗留不在当前恢复轮混合处理。历史大量明细已移至[证据快照](recovery-evidence-before-profile-settings-2026-10-22.md)，并有journal和git原记录。

## 6. 下一步

1. 22+ACC大图最终像素已过；普通房漏掉真实墙沿原因已定位，但首个alpha保护方案被136项中的同像素反例否决。先明确原生结构擦除与跨端最终颜色的最小契约，再实现及同一原生驱动复验；不直接合当前wall-edge。23暂停补发及容器微优化未见稳定收益，保留实验，不合入后继；没有完整24。不删采样、改时钟或降频凑结果。
2. A Sand独立接口已完成76组件与41原生生命周期检查。early实际三段对照暴露缓存重访卡死、首进约慢49%；先用有界票据/视口就绪观察定位重访，修正后再做同组合双人/单人对照。保留当前574D安装，合格前不部署。
3. 依据完整运动过程的实际空档选择瓶颈，补足只看重复位置/最终端点的验收缺口；停止无整机收益的微优化。新有界掉落诊断未复现旧空中长空档，先核查所有RENDER与落地分段，不重跑碰运气。念力/密集/加载仍未合格。
4. 准备同一候选的完整光晕、击墙、高速/念力/掉落、加载及性能复验。未通过保持574D，合格后备份部署及安装路径复测。

## 7. 入口与工具

- [统一清单](recovery-2026-10-21.md)、[日志](journal.md)、[历史详细证据](recovery-evidence-before-profile-settings-2026-10-22.md)；实验README与prepared/intent/results绑定精确字节。
- Python `C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe`，加`-B -X utf8`；Java `C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe`；SDK `mods/Sandevistan/build/tools/flexsdk`。PowerShell login:false。
- 正式构建 `tools/validation/prepare_recovery.py <新build/m52目录> --source <experimental完整源> --version <准确版本> --build --registry-wait 900`。
- 组件 `tools/validation/run_recovery_component.py --source <组件源> --entry <入口.as> --expected N --output <新目录>`。
- 默认密集 `experimental/recovery-density-corridor-readyfix/run.py` + drivers03；对应实际配置新入口独立冻结，不修改老wrapper使其输入失效。所有输出新目录，旧失败不覆盖。
