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

**正式仍 `0.2.23-coop-bundle2`，SHA `574d2b51490ae8b25a1396555600f56a301f8a20ae50104c0e35cf2796441afe`。** 回执 `build/m52/motion2-user-rollback-20261021-215647/rollback.json`，精确护栏授权已撤销，勿重做。
当前宿主 BEFC、CS7F1F、WB14112、SandCEC6、RV83D8；最近完整22项安装核对仍一致。仅RC回退，不能称所有模组均回到下午前。

| 分支 | 准确目录/指纹 | 资格与缺口 |
|---|---|---|
| 活动恢复源13 | experimental/recovery-integrated，1177EB | 加载/密集失败，别把它当最新22 |
| 恢复22 | build/m52/recovery-22，746EEF…B3E93 | 大图最终uint一致；普通房漏22墙沿像素，密集/及时性未合格 |
| 暂停23 | recovery-pause-flush，87FAFD…F6C | 50组件、八轮功能过，暂停对齐无改善，不合后继 |
| early2加载 | recovery-early-exit-compile-01，D356483F…ACB3 | 重访死锁修复，三段出生1/0/1px；耗时仍未达标 |
| A Sand003 | mods/Sandevistan/build/out/a-travel-hold-20261022-003，3E220…31C | 76组件、41零冷却、43非零冷却功能过；完整旅行/敌方补步缺口 |
| 独立离线优化 | build/m52/recovery-offline-production-01，EB365353…A5FEE，offline1 | 准确574D仅3类+版本；56生命周期、86原生弹丸历史过，双游戏门禁未过 |

精确完整SHA、冻结输入和所有失败均见各 prepared/compile/RESULTS；不可仅凭候选号混用。加载诊断使用host03 29D36与旧RV7852，**不是当前安装RV83D8**；准确入口能识别此差别，不回退用户RV。所有候选尚未部署。

## 4. 当前实测结论与卡点

- **离线分支最新完成**：CS真实574D/EB365独立进程各1200帧、90项。平均间隔69.615→58.866ms、中位64→54、P95 96→80，最长306→473ms；自然人口147/149、warm工作量不同且LAD/WB/RV显示关闭。只支持限定离线改善，不是完整配置净收益或双人资格。见 `experimental/recovery-cs-offline-review/NATIVE-PRODUCTION-REVIEW.md`。
- **实际会话生命周期56/0**：7a10b4a47f，driverAD26，12阶段、真实主持/拒连/退出/断开/重试/占端口；6Socket和4ServerSocket清理。v1准备失败、v2清理#2002失败原样保留。预期#2031有严格有界证据，非通用错误豁免。见 `recovery-offline-production/LIFECYCLE-REVIEW.md`。
- **实际弹丸采集86/0**：f6eece7606，driver3DF94，六阶段。每段原生flamer运动三帧后驱动capture一次；virgin历史0，null/throw/false/字符串true/首次主持后各3不同时间位置与原生匹配。共享runner错误规则不变，原枪null，恢复/清理、22安装均核过。只证明玩家弹丸历史，不含body/双人/性能。见 `recovery-offline-collector/RESULTS.md` 及独立 `recovery-offline-collector-review/REVIEW.md`。
- **最新资源**：收尾free_commit=3545227264 bytes，约3.30GiB；没有启动新双人。CS也已在其任务记录同一资源阻塞，未请求新实验。无需回复日常状态或再次问用户。
- **加载真实瓶颈**：early2不再缓存重访死锁；恢复许可要等early成功完成才清。主/加三流程功能过、出生一致，但不达单人时间。加入grant已早于主ensure，不是在等主绘完；restore约1.58s（地形约0.49、单位约0.65s）。Stage -100尾段约2.5s包含WB和FA，不能全归WB。单人分段探针已经够，停止扩大。
- **高速/念力/掉落**：准确21单发8组最大观察空档52–71ms；密集仍失败。念力85/0、容器/SATS52/0、跳跃12/0只证明旧功能；重算发现念力249ms、掉落空中160ms空档，smoothness不合格。新掉落观察轮空中主39/加46ms但未重现旧故障，不能称已修复。
- **画面**：准确21玩家光晕591项+8图通过，仍须在最终整合候选复验。22大图四例最终uint一致，普通房加入等离子漏22个碰撞空格中的真实墙沿像素，稳定7.6s仍漏；不属于1级颜色误差。

## 5. 已否决方案及未解决边界

- 普通墙沿按当前front alpha保护：组件136项135过1失败，普通erase后晚到ink被过滤但ACK承诺已画。**不得用回写透明ACK掩盖缺口**。结构支持涉及decal-before/tileDie实际eraser/成功drawLoc/gwall；两端破坏变体也可能不同，接收侧本地alpha不能作最终裁定。建议由房间权威（分房时也可能是加入侧）统一最终uint；结构快通道、旧ACK、同bitmap重绘及已有弹孔初始化仍需闭合。详见 `recovery-ordinary-edge-review/structure-feasibility.md` 与 `authority-support-contract.md`，只读结论，生产未改。
- 解码21局部ABBA有改善迹象，整体密集前两段仍失败；14时闪电空档前已有未来点，不能只怪缺包。收包诊断无同批多个完整快照，长回调也有无墙数据的快速包；不靠合并包/降频/删动画或改ACK凑通过。
- 延后完整currentSample会被输入别名改变结果，实际组件8项2失败；地形observed复用50项等价但无稳定收益；数组容器70项等价无稳定收益；暂停23补发无改善。全部停止，不继续微优化或用组件代替整机收益。
- A Sand采用准确CEC6的22行入口增量和独立helper，非B源。当前测试未覆盖敌方补步及活动/回放中实际完整旅行回退。旧active/replay拒绝持有测试不等于旅行完成测试。
- 旧汇总及未改变的失败完整保存于 [证据快照](recovery-evidence-through-offline-collector-2026-10-23.md) 和各实验目录；不要重跑或改判它们。

## 6. 下一步

1. 内存达到原门槛后补offline1真正首次双人接入、对侧新开火/一个body效果、离线旧事件不重播。已核现有runner `--connect-after-load`、FastHeld前置、NativeFlight前两轮、BodyEffects freezing可复用；旧驱动不绑定EB365。保留同枪、静默窗、记录尝试次数，不手清历史或隐去重试。路径/边界在 `recovery-offline-production/RESULTS.md`，尚未写新大驱动；不再用离线跑分代替。
2. 加载优先等WB初始化提案答复，仅删一次无消费者refreshView，合格后才能修改/部署；其余原生加载/Sand验证依现有准确入口，不再扩散单人探针。
3. 墙沿先收敛房间权威统一最终像素及结构支持最小契约，再实现并覆盖ordinary erase→late ink、tileDie→old ink、同bitmap重绘、gwall新增/到期。不要直接合首个wall-edge失败方案。
4. 依据真实长帧定位再改运动路径；最终恢复候选需同一准确输入验证加载、光晕、击墙、高速/念力/掉落及性能。独立离线优化有自己的有限门禁，不冒称解决上述四项。
5. 合格再备份、部署、按实际安装入口复测；当前无新整合发布资格，正式保持574D。

## 7. 入口与工具

- [日志](journal.md)、[近期完整证据快照](recovery-evidence-through-offline-collector-2026-10-23.md)、[更早证据](recovery-evidence-before-profile-settings-2026-10-22.md)、[恢复总清单](recovery-2026-10-21.md)。只按当前分支需要深入，避免每次全读历史。
- Python：`C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe -B -X utf8`；PowerShell login:false。
- Java：`C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe`；SDK `mods/Sandevistan/build/tools/flexsdk`。
- 正式候选准备：`tools/validation/prepare_recovery.py <新build/m52目录> --source <准确实验源> --version <版本> --build --registry-wait 900`。候选有专用freeze入口时优先用它，旧prepared/source/tools不可改。
- 组件：`tools/validation/run_recovery_component.py --source <组件源> --entry <入口.as> --expected N --output <新目录>`；原生：现有专用wrapper→`tools/run_coop_regression.py`，共享登记/内存/独占/清理不得绕过。
- 当前未提交的 `experimental/recovery-probe-fast*` 与 wall-decode两个merge预览为其他工作，勿混入本轮提交。根仅提交自己的原生collector及记忆/审查。
