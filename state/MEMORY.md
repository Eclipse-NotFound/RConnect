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
宿主 BEFC，RV7852、CS7F1F、WB14112、Sand CEC6；每次冻结22项。没有将其它模组回退，不能称整个下午全部安装均恢复。

| 候选 | 准确来源和用途 | 状态 |
|---|---|---|
| 13 / 1177EB…FDDB1 | `recovery-integrated`活动源仍是13，87AS | 加载/密集失败 |
| 18 / 11B795…38FE4D3 | `recovery-wall-color-buildsrc`，16的大图桥+原生反查色表 | 90AS，大图仍有极少1级差异 |
| 19 / B9CD3F…DFEEA5 | `recovery-wall-base64-buildsrc`，18仅改编码尾段 | 90AS，组件63/0；实际密集失败 |
| 20 / 0674019c4aeea22900aef3e2390a31aed4fafc7850e0f3a74bc5ebb2facce9f5 | `recovery-defense-buildsrc`，19仅补18个原生变量快捷表+版本 | 90AS，组件81/0、完整编译及密集失败；未部署 |
| early / 10B249…1FAE6 | `recovery-early-buildsrc`，16+并行早交付，单独分支 | 217组件、编译及宿主独立回读通过；缺真实A Sand接口 |

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

## 5. 仍待决定与限制

- A并行加载需要暂停准确CEC6版Sand独立步进。已一次向用户询问A独立接口，**未获回复**；不复用B授权、不写Sand、不重问。提案`recovery-sandy-travel-hold-proposal/README.md`：22行+独立载体，闲置才准入，时停/回放继续旧加载。
- early217组件通过不代替真实Sand/原生加载。独立宿主2D415D…DD29原回读因init2变量声明移位失败；严格独立recheck通过，原失败保留。
- 所有最终目标必须在同一准确候选重测；组件/握手/祖先局部通过均不替代最终画面和性能。没有新部署资格。
- B195及旧独立候选遗留不在当前恢复轮混合处理。历史大量明细已移至[证据快照](recovery-evidence-before-profile-settings-2026-10-22.md)，并有journal和git原记录。

## 6. 下一步

1. 实际配置574D/20和一次原CPU采样均完成；目前瓶颈落在原采样窗外，准备有界RENDER后→下一ENTER诊断。原源/驱动不改、单独输出，不以采样轮FPS作为门禁。正式双开HighQoS与默认测试未用responsive存在启动差异，尚无实测因果，不直接当优化。
2. 等A Sand授权后才做真实接口+early宿主的双人/单人加载对照；未回答期间继续独立问题。
3. 依据新实际证据选择主要瓶颈；停止没有整机收益的微优化堆叠。小房反查色两处85/0尚未合并，墙色极少残差保持开放。
4. 准备同一候选的完整光晕、击墙、高速/念力/掉落、加载及性能复验。未通过保持574D，合格后备份部署及安装路径复测。

## 7. 入口与工具

- [统一清单](recovery-2026-10-21.md)、[日志](journal.md)、[历史详细证据](recovery-evidence-before-profile-settings-2026-10-22.md)；实验README与prepared/intent/results绑定精确字节。
- Python `C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe`，加`-B -X utf8`；Java `C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe`；SDK `mods/Sandevistan/build/tools/flexsdk`。PowerShell login:false。
- 正式构建 `tools/validation/prepare_recovery.py <新build/m52目录> --source <experimental完整源> --version <准确版本> --build --registry-wait 900`。
- 组件 `tools/validation/run_recovery_component.py --source <组件源> --entry <入口.as> --expected N --output <新目录>`。
- 默认密集 `experimental/recovery-density-corridor-readyfix/run.py` + drivers03；对应实际配置新入口独立冻结，不修改老wrapper使其输入失效。所有输出新目录，旧失败不覆盖。
