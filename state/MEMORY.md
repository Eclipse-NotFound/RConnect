# RConnect — 开发记忆入口

## 1. 模组与当前职责

Remains 1.02 双人合作，入口 RConnectMod。A 为普通游戏入口现用同步；B 为独立主侧统一执行架构，本轮不恢复或混入 B。
本会话 `01a086bb-378c-7f60-b8e1-50d90ffa0996` 统一整合、验证和部署。用户要求回退下午的 motion2 后重做加载、玩家念力光晕、击墙效果、高速运动与性能，并减少跨对话打断。**回退已完成，光晕已有限交付；四项尚未全部解决。**

## 2. 玩法、授权及协作

- 中文通俗交流。加载目标是实际可操作耗时达到单人对应流程；不能只隐藏交接UI。未换房者继续运行，共同换图出生一致。
- 普通房可分头，无人房暂停保留本轮进度；剧情/挑战共同进入，宿主发起整图旅行。掉落一份先到先得，经验双方奖励，存档点共享解锁各存角色。
- 跟随/共享菜单及SATS暂停/被念力抓/抛掷伤害/友伤默认关，WASD挣脱默认开；安保破解默认共享，切换保留已有权限。
- 所有 RConnect 会话可协调，本会话唯一部署。FA念力兼容、指定RV/WB局部优化及LAD/CS测试部署协调已有授权；不能扩展为任意其他模组修改。
- A 独立 Sand 加载兼容接口已获授权并在隔离验证中，无需再问。B 的 TDFC/MSW/RV/Sand 授权仍限 B。
- **WB首次初始化 refreshView 删除提案仍待用户答复**；旧WB两处比较授权不覆盖它，未答前不改WB。
- 常规测试走 ModLoader 共享 game 登记，编译/AIR/部署由根串行；子代理独立目录、里程碑交付。没有新实质证据不跨会话发状态消息，不要求其他会话暂停。
- 唯一AIR ID、私有后台桌面/存储；只清自有实例，不关闭用户程序，不写真实存档。Littlepip29只读复制测试槽9；未点名Ghost，不使用。
- 双实例6GiB、单实例3GiB、组件/编译1GiB启动余量，运行512MiB保护不降低。用户已答释放内存后继续，不重复提问。
- 省D盘；可重建副本测试后清理，唯一证据和旧失败保留。合格后可直接部署；此前直接部署例外被回退要求取代，不放行失败候选。公网/重连/多人/其它版本不在本轮。

## 3. 安装与准确候选

**正式 `0.2.24-aura1`，SHA `df0fa0e2ca952e77e5132e75d71e73558dc919c7b8cdeba5da05fc9e94dc01e7`，186738字节。** 2026-10-23有限部署成功；回执 `build/m52/recovery-aura-offline-deploy-02/deployment.json`，实际安装双人smoke `7d45932e01` 通过。仅修复队友被念力抓起的身体光晕，继承offline1离线优化；其余加载/击墙/运动性能仍未完成。

本次回滚备份为同部署目录 `RConnectMod.before.swf`（EB365/0.2.24-offline1）。再上一层574D备份仍在 `recovery-offline-deploy-01`，勿混淆。当前宿主BEFC、CS7F1F、WB14112、SandCEC6、RV6DBA；本次22项安装只有RC变化。RV会话先行正式更新v0.33.7，本会话未改它；历史构建和59无游戏组件仍保留真实RV83D8记录，新16/20轮与安装smoke均为RV6DBA。不混入motion2、未合格恢复22或传输实验。

| 分支 | 准确目录/指纹 | 资格与缺口 |
|---|---|---|
| 活动恢复源13 | experimental/recovery-integrated，1177EB | 加载/密集失败，别把它当最新22 |
| 恢复22 | build/m52/recovery-22，746EEF…B3E93 | 大图最终uint一致；普通房漏22墙沿像素，密集/及时性未合格 |
| 暂停23 | recovery-pause-flush，87FAFD…F6C | 50组件、八轮功能过，暂停对齐无改善，不合后继 |
| early2加载 | recovery-early-exit-compile-01，D356483F…ACB3 | 重访死锁修复，三段出生1/0/1px；耗时仍未达标 |
| A Sand003 | mods/Sandevistan/build/out/a-travel-hold-20261022-003，3E220…31C | 76组件、41零冷却、43非零冷却功能过；完整旅行/敌方补步缺口 |
| 玩家念力光晕 | build/m52/recovery-aura-offline-01，DF0FA0E2…DC01E7，aura1 | 当前已部署；59组件、591光晕、444抓投、新8图及实际安装smoke通过 |
| 独立离线优化 | build/m52/recovery-offline-production-01，EB365353…A5FEE，offline1 | 由当前aura1继承；56生命周期、86原生弹丸历史、首次双游戏39+39及实际安装smoke通过 |
| 普通墙面结构代 | recovery-ordinary-wall-sv-production-01，C6A3B113…3496D；新mask-host-02 6616B1A5…40289B | 153组件/90类；修正遗漏11原生mask后真实rooms01为25+53，pixels01四轮最终像素全同；时序/密集仍未过，未部署 |

精确完整SHA、冻结输入和所有失败均见各 prepared/compile/RESULTS；不可仅凭候选号混用。加载诊断使用host03 29D36与旧RV7852，**不是当前安装RV6DBA**；准确入口能识别此差别，不回退用户RV。offline1优化与aura1光晕已有限部署，其余仍为隔离候选。历史验证器若硬锁574D/EB365安装会拒绝当前版，应明确记录准确RC及RV基线变更，不能改写旧回执。

## 4. 当前实测结论与卡点

- **光晕最小修正正式交付**：准确DF0FA0E2/aura1，仅四类小改动与版本；59组件通过。f871ad9d98（RV83D8）和989013e148（新RV6DBA）均双向16轮296+295，根分别实际目检8图。额外抓投旧3ebf5d73eb首轮超时；仅观测16edfc422f第9轮捕获原生重算把临时质量1000/master1变成0.6/0并真实拒绝hold。另旧生命夹具healAll不清伤级造成不一致。新8FDA8D98外部夹具用原生技能、heal同步伤级，保留所有原绝对HP断言/容差；46b56c60e3双向20轮222+222全过，40份最大HP稳定10280，18次敌弹各40，10正例墙伤48.70–120.57、8禁伤负例零墙伤、2drop零伤。产品未因测试失败修改，旧失败保留。部署01导入路径失误在替换前失败；补路径后audit02/deploy02与实际release 7d45932e01通过，自有实例/副本已清，其他21项安装保持。详见`experimental/recovery-aura-offline/RELEASE.md`。
- **旧运动消费者证据已缩小**：`recovery-motion-consumer-review/REVIEW.md` 重算旧21/14实际轨迹。闪电95ms跨度内无中间最终RENDER回调，不能认定消费者被调用但卡住；TK249ms/掉落160ms记录按gameFrame去重，不能据此证明无中间RENDER。当前offline1/aura1没有旧ProjectileFrameStream，不把旧流水线推论直接移植到当前版。
- **主动读取无收益，停止该分支**：准确AB61C7/receivepump1+6616，真实05fe881aee原四轮、双34/0、像素53/50/1147/971全过；主543/加556次检查均零非空读取，新增覆盖与总体passed=false保留。真实Socket组件21/0只证明人为迟通知下正确。原36C5对照主/加等离子画面延迟中位55→130.5、132→146ms，最大147→181、248→313ms；顺序单对及采样开销不支持净性能因果判断，无一致收益，不合入。自有进程/副本已清，22安装不变。见recovery-ordinary-receive-pump/README.md及first-pair.json。其后光晕已最小移植并作为aura1交付；本传输分支不合入。
- **接收分段证据**：准确36C5AD5C/wallrxtime1+6616/41/ns30，a3ded11cae原四轮像素过；199条配对、半包全0，回调前中位51/最大315ms，回调内2/17ms、codec1/8ms；36条长跨度34条主要已发生在入口前。原新rx方向检查过严而passed=false保留，supplemental-01独立核实际8份方向及全部原标量通过。没有改判历史。见recovery-ordinary-wall-rx-analysis/README.md。
- **完整游戏低延迟Socket首对没有一致收益**：已冻结产品02/3B6DF6（SWF38）+单字节header51宿主4772/ns51，off5490301650和on02e3b166ed均原四轮/像素/8份Socket证据通过。真实连接setter及每轮getter各自false/true，证明API可用；关闭/开启加入等离子八阶段中位96→150ms、report往返122→204.5ms，四轮paint中位有升有降，不能当修复。两组133个≥100ms区间均有发送方RENDER，132个有接收方，余1采样边界；不能归为整端持续停帧或把flush当底层已发。没有采用/部署NoDelay或升级正式运行上下文。构建01仅因冻结前LF行尾变化被拒，保留；新02真编过。详见recovery-ordinary-socket-native/RESULTS.md、first-pair.json。下一步原SWF41/ns30接收回调/解码/同批前序处理分段，先最小设计，勿增加生产分支。
- **真实墙传输计时已收敛**：57713116 / wallacktime1 + 6616，22c68450e9原四轮与最终像素全过（150/154/1173/1158，错漏多0）；8份有界诊断完整无溢出/故障。加入等离子报告→ACK往返109–245ms，主处理4–12ms、加处理1–7ms；8次ACK仅1次有可发队列，下一发等32ms，暂不合快发。主要跨度在flush→对侧解码派发，70个≥100ms区间有68个仍见4–6次RENDER回调；另4组相邻包集中派发。不能称纯网络延迟或等同独立显示帧，原像素采样本轮最高131ms也阻止净性能结论。下一步相同51外层/namespace下off/on真实tcpNoDelay对照，核实际主动/accept端读回，旧API-only不够；见recovery-ordinary-wall-ack-timing-native/RESULTS.md。安装未变。
- **房间首因修正已实际通过**：旧rooms01 / 2e1db25ddc破墙汇合失败，诊断618e7154ac捕获原生11类mask被误拒，旧失败未改判。新mask-host-02 / 6616B1A5只补ordinaryMaskBounds名单，8JVM与回读过，5,788其余方法及5,038非目标资源tag保留。原BF6真实dcc5152202主25/加53、双方DONE、无错误；死亡/破墙/伤害/容器/掉落随交接重访保留。原字段14,290/14,496差异0。最大观察空档仍1547/1755ms，无性能资格。host01供体因§§findproperty及日志权限失败保留，v2使用原已编译源。见 `recovery-ordinary-mask-native/RESULTS.md` 和mask-host-fix-v2。
- **新6616宿主四轮墙痕复验已过**：5dd018810d，原驱动/分析器，最终102/92/1230/1101像素全同。补充phase-timing显示LMG首发44/47ms、主/加plamg首发71/152ms；加plamg八阶段仍140–264ms落后，不能声称流畅。两轮原框架、自有清理、22安装及冻结输入均过，未部署。下一步补report出站/ACK真实时间再判断快发草案。
- **普通墙面原生四轮已过**：准确C6A3+host05 / native01 / 76b2f38ec6，直接复用旧ordinary驱动，原框架及逐uint分析exit0；两端各34/0，四轮原生前景+最终显示完全一致（118/96/1030/1059像素，错/漏/多余均0）。旧加入等离子墙沿22点不再复现。原分析器73/155/54/328ms匹配最终颜色，连射时会漏掉被后发覆盖的第一发；已向用户纠正：加入等离子实际命中→远端首显129ms，八阶段画面对画面121/50/48/121/191/172/190/113ms，仍未合流畅度。最大观察间隔190ms，结尾批量读回2秒非游玩长帧。普通mat2、CSnative关闭、低地形伤害，不代替结构/重访/全配置密集。共享runner清自有进程及副本、22安装不变。下一步现有RoomCooperation物理交接回归及真实阶段延迟定位；旧结果不改判，现wire缺report出站/ACK，不能直接断言网络分段原因。
- **墙面宿主编译风险**：host03整类import错误改写原createObj的E4X条件，已拒绝。host04只Grafon；host05仅移植Location两方法及必要flags，00C7C511…AA48，保留5,787非目标body和原资源；独立准入及四轮真实像素已过，后续房间实测发现上述名单缺项。新修正必须继续仅换目标方法，不能重新接纳供体整类。安装仍EB365/BEFC，详见ordinary-wall-sv/RESULTS、ordinary-host03/04-review。
- **ACK草案与坏压缩数据**：原ACK组件01实际第7项抛#2058，发现ordinaryDecode缺少解码拒绝；最小catch只返回null，不吞其它错误。独立ACK返回语义+decode修正真实组件02为20/0、regression01为153/0，源码及安装未变。三类ACK后立即发送草案仍未完整编译或测Socket/性能；不能用组件通过冒充改善及时性。见 `recovery-ordinary-wall-ack-decode-checks/RESULTS.md`。
- **CS离线墙面采样已回读**：准确EB365的19FF54A4聚合探针、原240×125持续交火夹具，1200帧/26项通过。四窗外层墙采集0.463/0.450/0.370/0.407ms每帧，重建/克隆/格比较均0；稳定场景不是20ms差额大头，不为此关闭历史。六敌、补弹/低伤/部分显示关闭，未测冷入图/重建，不授予双人或净性能资格。原来源CS dense-rc-wall-20261023-scene-r1，根核SHA和原结果，见 `recovery-offline-wall-profile/RESULTS.md`。
- **实际安装冒烟通过**：deploy.py 11ED24DF…B9F04，audit02过，在原runner共享登记内备份并原子替换准确EB365，再从release读取、无外部测试SWF启动两游戏。ae58b8049b双方版本/tick200、加入welcome/unitsync及原错误检查过；exit0、22项仅RC变、两个自有进程与副本回收。纯smoke不支持defer-visible，保留私有桌面、6GiB/512MiB和原runner全部检查。回滚源指纹574D已回读；未改host/config/src。见recovery-offline-production/RELEASE.md。
- **离线分支最新完成**：CS真实574D/EB365独立进程各1200帧、90项。平均间隔69.615→58.866ms、中位64→54、P95 96→80，最长306→473ms；自然人口147/149、warm工作量不同且LAD/WB/RV显示关闭。只支持限定离线改善，不是完整配置净收益或双人资格。见 `experimental/recovery-cs-offline-review/NATIVE-PRODUCTION-REVIEW.md`。
- **实际会话生命周期56/0**：7a10b4a47f，driverAD26，12阶段、真实主持/拒连/退出/断开/重试/占端口；6Socket和4ServerSocket清理。v1准备失败、v2清理#2002失败原样保留。预期#2031有严格有界证据，非通用错误豁免。见 `recovery-offline-production/LIFECYCLE-REVIEW.md`。
- **实际弹丸采集86/0**：f6eece7606，driver3DF94，六阶段。每段原生flamer运动三帧后驱动capture一次；virgin历史0，null/throw/false/字符串true/首次主持后各3不同时间位置与原生匹配。共享runner错误规则不变，原枪null，恢复/清理、22安装均核过。只证明玩家弹丸历史，不含body/双人/性能。见 `recovery-offline-collector/RESULTS.md` 及独立 `recovery-offline-collector-review/REVIEW.md`。
- **首次双人已完整通过**：native08/d0048aff49使用driver07 BD777339…ED2A3、AS F6F006B6…7EB24A。两边39/0、各首次连接一次、十项覆盖全true，宿主真实finishAck、全部清理通过；原runner和wrapper退出0、22安装未变。实际远端弹道移动/枪口及冻结恢复最终像素已核，离线旧事件全窗未重播。独立复核原始日志无错误、进程/副本清理。之前路径、净空、FA弹匣退款基线及收尾竞态失败均保留，产品与原runner始终未改。仅给首次接入功能资格，不给密集性能或四项恢复资格。见recovery-offline-first-connect/RESULTS.md。
- **资源恢复**：用户通过CS侧告知已退出并要求优先推进；实际可提交余量已到8GiB左右，双实例确实启动，当前不再是内存阻塞。沿用6GiB/512MiB保护；写独立AppData存储需本次系统权限，不能用真实存档回避。根唯一运行与部署，不再接收重复瞬时资源通知。
- **墙面实现边界**：普通cell结构代sv、权威完整1600像素、预测与确认分离、prepareRestore→原生redraw→finishRestore、房间owner交接已进入C6A3。组件01 disposed shadow #2015失败保留，清空引用后组件02为153/0；完整构建及原墙沿22点实机已过。结构像素、迟到ACK、分房重访及流量性能仍未合格，房间失败优先处理。
- **加载真实瓶颈**：early2不再缓存重访死锁；恢复许可要等early成功完成才清。主/加三流程功能过、出生一致，但不达单人时间。加入grant已早于主ensure，不是在等主绘完；restore约1.58s（地形约0.49、单位约0.65s）。Stage -100尾段约2.5s包含WB和FA，不能全归WB。单人分段探针已经够，停止扩大。
- **高速/念力/掉落**：准确21单发8组最大观察空档52–71ms；密集仍失败。念力85/0、容器/SATS52/0、跳跃12/0只证明旧功能；重算发现念力249ms、掉落空中160ms空档，smoothness不合格。新掉落观察轮空中主39/加46ms但未重现旧故障，不能称已修复。
- **画面**：准确21玩家光晕591项+8图通过，仍须在最终整合候选复验。22大图四例最终uint一致，普通房加入等离子漏22个碰撞空格中的真实墙沿像素，稳定7.6s仍漏；不属于1级颜色误差。

## 5. 已否决方案及未解决边界

- 普通墙沿旧alpha过滤方案136项有1失败，已否决，不改ACK掩盖。新的sv实现位于experimental，按房间权威最终uint；结构改变的40×40 cell会丢弃同格旧代迟到弹痕，inactive/rebase还可能清掉该格其他旧痕迹，范围外保留。魔法墙mat7/gwall和其他模组直接前景写入未纳入权威事务，不得称全部墙面已支持。详见recovery-ordinary-wall-sv/README、INTEGRATION、RESULTS及独立host目录。
- 解码21局部ABBA有改善迹象，整体密集前两段仍失败；14时闪电空档前已有未来点，不能只怪缺包。收包诊断无同批多个完整快照，长回调也有无墙数据的快速包；不靠合并包/降频/删动画或改ACK凑通过。
- 延后完整currentSample会被输入别名改变结果，实际组件8项2失败；地形observed复用50项等价但无稳定收益；数组容器70项等价无稳定收益；暂停23补发无改善。全部停止，不继续微优化或用组件代替整机收益。
- A Sand采用准确CEC6的22行入口增量和独立helper，非B源。当前测试未覆盖敌方补步及活动/回放中实际完整旅行回退。旧active/replay拒绝持有测试不等于旅行完成测试。
- 旧汇总及未改变的失败完整保存于 [证据快照](recovery-evidence-through-offline-collector-2026-10-23.md) 和各实验目录；不要重跑或改判它们。

## 6. 下一步

1. aura1光晕有限部署已完成，勿重复59/591/444或已完成的安装冒烟。ACK/NoDelay/receive-pump无一致实测收益，停止盲调。现安装DF0F/BEFC/RV6DBA；继续加载、击墙和运动长帧，先按当前实际源核消费者与最终渲染证据，不导入未合格旧整合分支。
2. 加载优先等WB初始化提案答复，仅删一次无消费者refreshView，合格后才能修改/部署；其余原生加载/Sand验证依现有准确入口，不再扩散单人探针。
3. 房间修好后仍需迟到包/结构像素/大图及密集性能。ACK三类草案仍不并入；其返回语义和独立坏数据拒绝已过20+153组件，不等于完整发送链路合格。host05基底ACC是安装BEFC增加Game/首栅格/墙面桥的后代，部署需核依赖边界；gwall未覆盖。CS稳定场景采样已收敛，不再扩大离线墙采集探针。
4. 依据真实长帧定位再改运动路径；最终恢复候选需同一准确输入验证加载、光晕、击墙、高速/念力/掉落及性能。独立离线优化有自己的有限门禁，不冒称解决上述四项。
5. 最终整合仍需合格后备份、部署、实际安装复测；当前交付aura1（含offline1），不让未合格恢复分支覆盖它。

## 7. 入口与工具

- [日志](journal.md)、[近期完整证据快照](recovery-evidence-through-offline-collector-2026-10-23.md)、[更早证据](recovery-evidence-before-profile-settings-2026-10-22.md)、[恢复总清单](recovery-2026-10-21.md)。只按当前分支需要深入，避免每次全读历史。
- Python：`C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe -B -X utf8`；PowerShell login:false。
- Java：`C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe`；SDK `mods/Sandevistan/build/tools/flexsdk`。
- 正式候选准备：`tools/validation/prepare_recovery.py <新build/m52目录> --source <准确实验源> --version <版本> --build --registry-wait 900`。候选有专用freeze入口时优先用它，旧prepared/source/tools不可改。
- 组件：`tools/validation/run_recovery_component.py --source <组件源> --entry <入口.as> --expected N --output <新目录>`；原生：现有专用wrapper→`tools/run_coop_regression.py`，共享登记/内存/独占/清理不得绕过。
- 当前 `experimental/recovery-probe-fast*` 与 wall-decode两个merge预览为其他工作，勿混入本轮提交。本轮自有首连驱动、ordinary-edge实现契约/审查、ordinary-wall-sv及-host、记忆/日志由根提交。
