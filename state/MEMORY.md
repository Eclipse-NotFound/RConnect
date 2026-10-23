# RConnect — 开发记忆入口

## 1. 模组与当前职责

Remains 1.02 双人合作，入口 RConnectMod。A 为普通游戏入口现用同步；B 为独立主侧统一执行架构，本轮不恢复或混入 B。
本会话 `01a086bb-378c-7f60-b8e1-50d90ffa0996` 统一整合、验证和部署。用户要求回退下午的 motion2 后重做加载、玩家念力光晕、击墙效果、高速运动与性能，并减少跨对话打断。**回退已完成，四项整体尚未解决。**

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

**正式 `0.2.24-offline1`，SHA `eb3653533cfb305bcca0b0cfe5e81bc306ea28fa400aae751ab7b5ae1cfa5fee`。** 2026-10-23有限部署成功；回执 `build/m52/recovery-offline-deploy-01/deployment.json`，实际安装双人smoke `ae58b8049b` 通过。仅减少从未联网时的显示采集开销，四项恢复仍未完成。
旧574D备份为同目录 `RConnectMod.before.swf`。当前宿主 BEFC、CS7F1F、WB14112、SandCEC6、RV83D8；22项安装仅RC变化。回退后的574D是本版准确来源，不混入motion2或恢复22的未合格部分。旧回退回执和授权撤销记录保留，勿重做。

| 分支 | 准确目录/指纹 | 资格与缺口 |
|---|---|---|
| 活动恢复源13 | experimental/recovery-integrated，1177EB | 加载/密集失败，别把它当最新22 |
| 恢复22 | build/m52/recovery-22，746EEF…B3E93 | 大图最终uint一致；普通房漏22墙沿像素，密集/及时性未合格 |
| 暂停23 | recovery-pause-flush，87FAFD…F6C | 50组件、八轮功能过，暂停对齐无改善，不合后继 |
| early2加载 | recovery-early-exit-compile-01，D356483F…ACB3 | 重访死锁修复，三段出生1/0/1px；耗时仍未达标 |
| A Sand003 | mods/Sandevistan/build/out/a-travel-hold-20261022-003，3E220…31C | 76组件、41零冷却、43非零冷却功能过；完整旅行/敌方补步缺口 |
| 独立离线优化 | build/m52/recovery-offline-production-01，EB365353…A5FEE，offline1 | 已部署；56生命周期、86原生弹丸历史、首次双游戏39+39及实际安装smoke通过 |
| 普通墙面结构代 | recovery-ordinary-wall-sv-production-01，C6A3B113…3496D；host05 00C7C511…AA48 | 153组件/90类/host05静态准入过；native01四轮最终像素全一致；显示最迟328ms，结构重访/性能仍待，未部署 |

精确完整SHA、冻结输入和所有失败均见各 prepared/compile/RESULTS；不可仅凭候选号混用。加载诊断使用host03 29D36与旧RV7852，**不是当前安装RV83D8**；准确入口能识别此差别，不回退用户RV。仅offline1有限部署，其余仍为隔离候选。历史验证器若硬锁574D安装会拒绝当前版，应明确记录本次单RC基线变更，不能改写旧回执。

## 4. 当前实测结论与卡点

- **普通墙面原生四轮已过**：准确C6A3+host05 / native01 / 76b2f38ec6，直接复用旧ordinary驱动，原框架及逐uint分析exit0；两端各34/0，四轮原生前景+最终显示完全一致（118/96/1030/1059像素，错/漏/多余均0）。旧加入等离子墙沿22点不再复现。首显示观察73/155/54/328ms，最大观察间隔190ms，不能称流畅度已过；结尾批量读回2秒非游玩长帧。普通mat2、CSnative关闭、刻意低地形伤害，不代替结构破坏/换权威/重访/全配置密集。共享runner清自有进程及host/join/frozen副本、22安装不变。下一步现有RoomCooperation物理交接回归及本轮328ms时序定位。
- **墙面宿主编译器风险已处理至回读层**：host03全类import把未改createObj的XML `@id == id` 编为本地id恒真比较，独立pcode确认后严格拒绝；host01日志/环境、02多变量声明解析失败均保留。host04只导入Grafon，9B362254…913F；旧供体常量顺序不相容，另从host04导入Location取得BFC9供体。host05仅保留两方法完整body和必要flags，00C7C511…AA48；6Java退出0，5,787非目标body、旧池前缀/类脚本/原资源精确保留，最终回读通过。独立host04确认24匿名函数归Grafon且无外部引用。最终目标绑定审查和AIR仍待完成，不能凭build_checks_passed授予游戏资格。安装仍EB365/BEFC，详见ordinary-wall-sv/RESULTS、ordinary-host03/04-review。
- **实际安装冒烟通过**：deploy.py 11ED24DF…B9F04，audit02过，在原runner共享登记内备份并原子替换准确EB365，再从release读取、无外部测试SWF启动两游戏。ae58b8049b双方版本/tick200、加入welcome/unitsync及原错误检查过；exit0、22项仅RC变、两个自有进程与副本回收。纯smoke不支持defer-visible，保留私有桌面、6GiB/512MiB和原runner全部检查。回滚源指纹574D已回读；未改host/config/src。见recovery-offline-production/RELEASE.md。
- **离线分支最新完成**：CS真实574D/EB365独立进程各1200帧、90项。平均间隔69.615→58.866ms、中位64→54、P95 96→80，最长306→473ms；自然人口147/149、warm工作量不同且LAD/WB/RV显示关闭。只支持限定离线改善，不是完整配置净收益或双人资格。见 `experimental/recovery-cs-offline-review/NATIVE-PRODUCTION-REVIEW.md`。
- **实际会话生命周期56/0**：7a10b4a47f，driverAD26，12阶段、真实主持/拒连/退出/断开/重试/占端口；6Socket和4ServerSocket清理。v1准备失败、v2清理#2002失败原样保留。预期#2031有严格有界证据，非通用错误豁免。见 `recovery-offline-production/LIFECYCLE-REVIEW.md`。
- **实际弹丸采集86/0**：f6eece7606，driver3DF94，六阶段。每段原生flamer运动三帧后驱动capture一次；virgin历史0，null/throw/false/字符串true/首次主持后各3不同时间位置与原生匹配。共享runner错误规则不变，原枪null，恢复/清理、22安装均核过。只证明玩家弹丸历史，不含body/双人/性能。见 `recovery-offline-collector/RESULTS.md` 及独立 `recovery-offline-collector-review/REVIEW.md`。
- **首次双人已完整通过**：native08/d0048aff49使用driver07 BD777339…ED2A3、AS F6F006B6…7EB24A。两边39/0、各首次连接一次、十项覆盖全true，宿主真实finishAck、全部清理通过；原runner和wrapper退出0、22安装未变。实际远端弹道移动/枪口及冻结恢复最终像素已核，离线旧事件全窗未重播。独立复核原始日志无错误、进程/副本清理。之前路径、净空、FA弹匣退款基线及收尾竞态失败均保留，产品与原runner始终未改。仅给首次接入功能资格，不给密集性能或四项恢复资格。见recovery-offline-first-connect/RESULTS.md。
- **资源恢复**：用户通过CS侧告知已退出并要求优先推进；实际可提交余量已到8GiB左右，双实例确实启动，当前不再是内存阻塞。沿用6GiB/512MiB保护；写独立AppData存储需本次系统权限，不能用真实存档回避。根唯一运行与部署，不再接收重复瞬时资源通知。
- **墙面实际实现/检查**：普通cell结构代sv、权威完整1600像素、预测与确认分离、prepareRestore→原生redraw→finishRestore、房间owner交接已写入隔离源码。独立审查修正两条反例：同cell旧排除写入被ink夹带；continuing owner未就绪时被宿主旧记录回滚。组件01在第79项因已dispose的shadow引用#2015失败；最小清空引用后component02真实153/0，SHA534518C0…E846，生产类12682BFF…FF72。完整产品/宿主资源/真实墙沿22点/流量性能仍未验证。宿主源码生成器--verify已通过，87/90 Grafon、72/74 Location原方法未改，仍需真实资产测试。
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

1. offline1有限部署已完成，勿重复首连或安装冒烟。继续普通墙面宿主编译/回读及原生22点验证；新构建/测试明确绑定当前仅RC=EB365的新安装基线，旧失败和冻结输入不改。
2. 加载优先等WB初始化提案答复，仅删一次无消费者refreshView，合格后才能修改/部署；其余原生加载/Sand验证依现有准确入口，不再扩散单人探针。
3. 墙面真实类153组件及90类完整构建已过（prepare_product.py，精确22覆盖4类+版本）；下一步独立宿主编译与普通22点、破坏/迟到包/分房/重访/大图回归及密集性能。最短初测宿主基底为ACC，是安装BEFC增加Game/首栅格/墙面桥的后代；不是对BEFC仅两类小补丁，部署需核依赖边界。gwall仍明确未覆盖。
4. 依据真实长帧定位再改运动路径；最终恢复候选需同一准确输入验证加载、光晕、击墙、高速/念力/掉落及性能。独立离线优化有自己的有限门禁，不冒称解决上述四项。
5. 最终整合仍需合格后备份、部署、实际安装复测；当前只交付offline1，不让未合格恢复分支覆盖它。

## 7. 入口与工具

- [日志](journal.md)、[近期完整证据快照](recovery-evidence-through-offline-collector-2026-10-23.md)、[更早证据](recovery-evidence-before-profile-settings-2026-10-22.md)、[恢复总清单](recovery-2026-10-21.md)。只按当前分支需要深入，避免每次全读历史。
- Python：`C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe -B -X utf8`；PowerShell login:false。
- Java：`C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe`；SDK `mods/Sandevistan/build/tools/flexsdk`。
- 正式候选准备：`tools/validation/prepare_recovery.py <新build/m52目录> --source <准确实验源> --version <版本> --build --registry-wait 900`。候选有专用freeze入口时优先用它，旧prepared/source/tools不可改。
- 组件：`tools/validation/run_recovery_component.py --source <组件源> --entry <入口.as> --expected N --output <新目录>`；原生：现有专用wrapper→`tools/run_coop_regression.py`，共享登记/内存/独占/清理不得绕过。
- 当前 `experimental/recovery-probe-fast*` 与 wall-decode两个merge预览为其他工作，勿混入本轮提交。本轮自有首连驱动、ordinary-edge实现契约/审查、ordinary-wall-sv及-host、记忆/日志由根提交。
