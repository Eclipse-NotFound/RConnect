# RConnect —— 开发记忆入口

> **2026-10-13 当前停点**：B188在第28组msw-sweep停止，exec12557退出1；前27组4895项通过，第28组主90/1加78/0且双方DONE，唯一失败为队友电池/预付余量应不变。加入侧上一阶段激光笔仍亮，下一阶段正常继续耗电；缺该次按键轨迹，先查关闭点击是否漏发。B189被动输入/消费诊断正在exec83950运行（b3-msw-pointer-diagnostic-189）。已结束副本归档，安装A22不变，B未交付。

## 1. 模组与职责

RConnect是Remains 1.02双人合作模组。用户要求保留A旧架构，同时完整实现B主侧统一执行架构，并回归历次主要问题。当前开发位于experimental/host-authority、工具tools/host_authority、隔离产物build/ab。B主側持有两名原生玩家、运行双方所在房间；加入側发送输入，显示主侧确认的结果。

本会话01a086bb-378c-7f60-b8e1-50d90ffa0996统一合并、验证和部署。用户允许全部当前/后续RConnect会话协调；旧分支不得覆盖安装候选。[协调记录](m50-coordination.md)。不因任务复杂自动新增子代理。

## 2. 已定玩法、授权与边界

- 中文、通俗说明，交付说明运行效果与证据。已授权大幅重构、隔离实机验证与本机候选；不重复确认开工。
- 普通房可分头，主侧同时执行双方房间；无人房暂停并保留本次联机进度。宿主发起整图旅行，剧情/挑战共同进入；不新增随机房完整战斗存档。
- 地上物品一份、先拾取者获得；XP双方奖励、存档点共同解锁，各自角色/背包/保存独立。跟随默认关。
- 菜单/SATS任一侧可共同暂停，全部原因解除再继续。两项策略默认关、宿主管理；暂停期间网络/聊天/选择仍工作。
- 个人被抓许可默认关、WASD挣脱默认开、投掷伤害默认关；友伤默认关、宿主管理。MSW非致命光照队友只短暂限制视野、保留操作。
- B共享斯安维斯坦：任一人发动，两人正常行动、世界变慢；**主要伤害保留到回放时按原生规则结算**。共享暂停冻结记录/回放，正常离开和主侧换图等待回放结算。
- 紧凑浮窗280×36，各自30–100%不透明度；Ctrl+Enter聊天/F10显隐，原生Enter不变。
- 用户明确授权独立TDFC、MSW、RV和Sandevistan必要B接口及协调；仅构建隔离版，不部署这些模组。Sandevistan正源已迁至本区独立仓库，与“sandevistan迁移”确认，当前接口327d3a9/Sandy001。
- 2026-10-13用户要求精简D盘无用测试文件：单项也优先用run_suite.py --scenarios <单项> --archive；特殊参数单跑结束后立即archive_evidence。保留源码、基线、原失败日志/截图/回执及无损恢复索引。旧未确认退出或输入变化的测试不盲删。
- 保留用户其他程序，勿关闭/改优先级或电源设置；只管理独立AppID的自有测试PID，不触碰用户原存档。WallBlend不得发消息，测试冲突等待结束。
- 排除稳定重连、公网、三人以上、其它游戏版本、新任务/交易/互看背包玩法。旧A问题不因B进展自动结案。

## 3. 当前版本与实际证据

- 安装A：0.2.22-dev、SHA256 32602e77a21b206d1f7ff0e927b953878c28254e7201529455818923a3539732，未替换。[原部署](deployment-m50-2026-10-09.md)。准确安装整体基线build/ab/baseline-001。
- 当前B188：源码8d8aaf1019b3d21b97c98974725ce55aa73629b7d0f70233827fb6a787671896，SWF1306c3d09a77f66063cb4dd0ff8b4d37d6aeeef485f442012e82b17c14a1a310，源提交2ce4153；原生019/TDFC004/RV003/MSW011/Sandy001保持。与185仅EnemyVisualProbe/BuildInfo变化。44组exec12557在第28项停止，前27组4895项通过；旧182、185及诊断结果不能混作188完整验收。
- 完整44组build/ab/b3-suite-179已完成收集，38组/6966项完整通过，6类未通过。后续同179同输入补跑可经审计保留原失败；若改生产源，须新冻结候选回归，不混为同字节。
- 179真实字段配对164/0：移动对象采样主少19.5%、加少14.4%，静止约同；仅局部成本。180类型缓存让静止慢11–13%，弃用并逐字节还原179，旧实验保留。
- 179两分钟80原生敌人、双侧持续开火146/0：主均194.42ms/p95 278ms，加均102.26ms/p95 168ms，采样队列最大1；仍慢，不是严格A/B性能证明或长局无泄漏证明。
- 默认未attach对照：原生原始/019配同TDFC004/RV003/MSW011/Sandy001，各34/0；TDFC逻辑74/0。默认清单外部指纹在external_manifests，不是联机的扁平键。
- 独立b3-playable-179已有Player-1/2.cmd，probe=false/autoGame=false，不限定谁当主侧；稳定B档与A分开，尚未启动验证或交付。创建目录不是门禁通过。

## 4. 实现与近期修复

- HostSession、PlayerActor、NativeScope隔离双方角色、输入、资料、房间引用；OccupiedRooms只推进有人房，同房不双步。RoomTransfers在原生步边界提交转房；两侧各自镜头/原生视野。
- 原生战斗、特殊枪械/魔法/投掷、敌人、念力、奖励、门箱、地形、保存/复活、各自菜单与UI均已有路径及专项。Body/weapon/effect同主时钟采样，确认间只插值变换。详细证据以[完整游玩实况](host-authority-playable-2026-10-11.md)末节为准，不沿用早期“异房画面尚未实现”的结论。
- SharedTimeHistory只保存运动和视觉，不倒退HP/背包/AI；DeferredHits保留真实来源和归属，回放走原生伤害，不再次耗弹/魔力。正常Leave用应用层确认收尾，实际断线立即清理，不实现重连。
- EXIT_FRAME可在原生事务中途同步触发；RoomRuntime.stepping和NativeScope.depth保护完成帧发布，修复SATS回放身体/武器不同步；图像矩阵专项通过，旧红保留。
- NativeFields179复用不变记录，连续变化时单次读取建表；FrameDelta只有前份身份精确匹配时复用采样差量，旧确认保持不变。时停/动作/敌人/枪口/地形的最终统一字节回归仍进行。
- 原生019导入处E4X查询改显式attribute，避免同名局部变量让地雷/魔法构造误变普通枪。原生钩子默认空，默认分支有针对性对照，不宣称全部行为等价。

## 5. 已知问题与结论边界

- 性能对照启动差异：旧tools/validation/run_m51.py传--responsive，keep_test_responsive.ps1仅为其自有PID设置HighQoS；B tools/host_authority/run_probe.py未设该策略。以后严格A/B需统一启动策略，不能直接比较旧跨工具FPS。没有修改当前进程策略或用户电源设置。
- 密集场景仍明显慢。现有性能只是实际记录；严格相同公共地图修复的A/B配对未完成，不能把分时后台负载差异算架构收益。
- 171爆炸序列曾有56秒阻塞/2MB积压，178完整20阶段280/0未复现但根因未知；179完整爆炸序列20阶段280/0通过，仍不代表旧阻塞根因已查明。
- 51项历史目标映射在design/host-authority-regression-map.json，仍有旧同字节待验或具体组合缺口；不能只凭映射宣布完成。枪火/特殊效果自然到期、水中、全部第三方组合、真人鼠标/中文输入法等不得过度声称覆盖。
- 两分钟内存数据不证明长局稳定。早期原生初始化#1009、旧A背景门低频问题等保留历史，受控专项绿不代表所有低频条件已排除。

## 6. 直接接续顺序

1. exec12557已退出1，188在msw-sweep停下，回执cf41ce62e9d703ea60db1a8cfc185447f05a9d4ef42e0a86f53a73ca4c12bba6。原输入窗口65≤elapsed<69可能被加入侧确认时钟跳过；只是线索，先接续B189被动诊断exec83950，记录每次生成的按钮/序号和主侧接收消费、pointer亮灭与两人电量。不得把已收集28组误说全部通过；已向用户更正。
2. 181诊断证据保留：movement确证重复RESIZE后Pip打开、预显示unsafe-anchor；hud/pause-holders远端额外Pip持有暂停。personal诊断自身因装备切换时currentWeapon暂空而#1009，不算生产新错误；原179 personal失败已由182完整复验通过。若182失败据真实证据修复；若全过继续下列门禁。
3. 实跑有序回环抖动（--jitter-ms 0,20,80,10,40），继续内存/流畅度证据。严格对照未有结论则明确保留。
4. 完整audit_suite加逻辑/默认/压力等精确输入审计；audit_checkpoint已拒绝原始error日志。单组输入预检b3-input-check-179已通过：当前源码/完整外部接口匹配、逻辑74/0、默认两组各34/0；不等于整套验收。
5. 为实际通过回归的候选新建玩家目录（188若最终通过则b3-playable-188），重新prepare_playable；旧b3-playable-179不能交付。再用check_playable_startup.py复制出新AppID验证普通无驱动启动；不启动稳定玩家档，不冒充真人鼠标/IME验证。
6. 核对候选说明、最终记录/版本/提交后才交付独立B测试入口，安装A不动；完整发布门禁尚未完成。不把技术检查点当全部游玩目标结束。

- 容量完整回执：[清理记录](test-storage-2026-10-13.md)，61组旧副本无损归档，原始失败保留。exec28920及183/184诊断已结束，完整性复核通过。

## 7. 工具与深入入口

- [B并行计划](../design/host-authority-parallel-plan-2026-10-11.md)、[完整实况](host-authority-playable-2026-10-11.md)、[journal](journal.md)。旧A暂停事项：[地图/友伤/地雷](cooperative-hazards-2026-10-11.md)、[同步审查](../design/sync-audit-2026-10-10.md)。早期图解描述旧呈现收口方案，不当B已验收证明。
- Python：C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe，父子进程都-B -X utf8。Java C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe；SDK/FFDec由tools/host_authority/common.py探测。
- AIR正常沙箱无法创建新测试Local Store（#3003）；隔离AIR启动使用已经授权的require_escalated，已获自动审查批准。读/编辑/编译默认权限即可。不把启动环境失败算玩法失败或成功。
- 所有构建/测试显式新建build/ab子目录，失败不覆盖；archive_evidence.py验证自有进程退出及所有输入后无损存储重复实物，原日志/图片/回执保留。测试运行器正在用时勿改。
- 实际application.xml→根pfe.swf1.02；app.xml不是启动正本。原始参考在game-reference/decompiled/1.02/src102/scripts。安装loader拼写Rconnect与目录RConnect的大小写保持。
- git身份eclipse；本地提交不推送、不重写历史。B整套与A并行，回退只需保存退出B后从原入口启动A，不单独替换任何一个SWF。
