# RConnect —— 开发记忆入口

> 2026-10-09：**安装仍为0.2.21-dev，M50/0.2.22-dev未部署。** 按请求完成本轮实机尝试：final24四组失败（其中外观组开局超时）、34组及旧21对照未跑；全部自有实例已退出。等待WallBlend测试结束后才续测，未向其发消息。生产代码仍是7aaceec检查点；本轮仅追加诊断及状态记录。

## 1. 模组与当前职责

RConnect是Remains 1.02的双人合作模组，支持同地图普通房分头探索、战斗、场景交互和共享奖励。本轮原始问题是远程玩家假飞行翅膀及枪口/弹道错位，随后统一接入各协作会话的相关修复。

唯一统一合并、构建、游戏测试及部署者：原「RConnect」会话01a086bb-378c-7f60-b8e1-50d90ffa0996。用户授权当前及后续所有RConnect开发会话互通；R2–R14已交接停写，分叉继承记忆不等于获得部署权。[协调记录](m50-coordination.md)。

## 2. 用户决定与保护边界

- 最新决定：恢复实机测试并在验证后部署；此前暂缓游戏测试已被此次明确请求替代。仍保留其它程序，不擅自结束或调整其优先级/亲和性。实机使用独立AppID和数据，不碰玩家存档。
- WallBlend协调请求被用户明确拒绝：不发送消息，等它测试结束；RConnect全会话协调授权不延伸到其它模组。
- 已授权现有合作功能修复、大幅重构及本机候选部署；稳定重连、公网、三人以上、版本兼容、新的任务/背包/交易系统排除。
- 普通房可分头；无人房暂停并保留本次联机进度；宿主发起整图旅行，剧情/挑战共同进入。退出游戏沿用原版存档，不新增随机房战斗存档。
- 地上物品仅一份、先拾取者获得；经验点双方奖励；存档点共同解锁、各自保存角色。跟随默认关。
- 菜单/SATS任一端可全队暂停，全部关闭才恢复；两开关默认关、宿主管理，暂停保留网络、聊天和SATS队列。
- 仅写本模组；游戏本体、描述符和game-reference只读，其他模组必要最小只读。独立AppID/数据/自有PID，未改玩家存档；失败输入与日志保留。

## 3. 版本与实际验证状态

- **已安装21**：131147B、53类，SHA256 5c372cf5d970212f0fd4e95bea5c0acfaabfe321c3ca531c80ed7e299c2914bd。M49的20组2095/0、正常无驱动全模组冒烟3611e15340通过。[部署记录](deployment-m49-2026-10-08.md)。
- **最新构建24**：build/m50/final-presentation-24，69源/196验证输入/68类/163276B；SHA256 d62c0bd218995256fe4a26583b8a684df4a35b850f83c514459318c6ac1bb3f9。编译及完整类表核对通过；38组中4红/34未跑，旧21对照未跑。PAUSE.request保留；FFDec日志锁警告未影响完整类表核对。
- **固定回放03：60/0**，build/m50/terrain-fixed-replay-03。180固定步/227条结果新旧地形一致，覆盖重复伤害、在途确认、离房清队列、尺寸变化、可选字段及已有持物/掉落回放。原生存档、碰撞、渲染、武器、传送、网络时序不在范围内。
- 分配计数：320格，双方各扫描100次，未变格快照64000→0，每次一格变化64000→200。计数只加在独立副本，不进入生产；不能换算成真实FPS保证。
- 11项Python资产/输入门禁测试已通过，本轮未改工具而未重复执行。收尾69源、196验证输入及157保护条目全部匹配；实际宿主CIM确认AIR为空（14:38），CPU单次48%。23/24失败队列均未恢复。
- M50保存为本地代码检查点，提交见git log；没有发行审计、21部署备份、部署/正常冒烟收据或推送。公开安装包及玩家README仍对应0.2.8。

## 4. 最新代码判断与保留的失败

- 正式24：Combat 3259fc84d2密集80敌人57帧/p95 214ms红，伤害/炮塔等通过；FastHeld 99d0f68fbd四组延迟260/170/230/190ms超过160ms；Flame 8dd4178a6c加入侧case0一项时长差254ms红。三组均双端DONE，原阈值不变。
- 密集诊断9a67e66d75（density-runtime-profile-01）在WallBlend测试占用时执行，仅定位不能验收：6帧/端CPU采样主要落于ExplorationSync每100ms调用RV.captureExploration；加入侧125个直接样本+20个GC样本。
- 独立250ms读取副本2e445783运行3df2612a46，两端DONE但密集仅5帧/p95 2724ms；低负载也只有65帧/22274ms。未获得改善证据，**未采用**。结束时CPU88%，只读快照见《群星》重新运行；这不证明全部旧红由外部负载造成。[探索采样诊断](../knowledge/experiments/2026-10-09-exploration-capture-cost.md)。
- 原24外观组aea1fdd9e5在boot/开局60秒超时，两端DONE但一个正式角度也未检查；后续WeaponAngle/Projectile尚未执行。执行器87028结束，不能据旧22成功宣称24外观通过。
- 原生采样27741832f6指向TerrainSync扫描及GC。24先直接比较13字段、变化后创建快照，基线按x/y两层存储，避免平面索引随房高变化串格；协议、频率、伤害与预测确认顺序未改。[地形实验](../knowledge/experiments/2026-10-09-terrain-scan-allocation.md)。
- **正式23已暂停：5组3绿/2红/33未跑，负控未跑**。Continuity49c49eaffb（74/0ms、SATS通过）、Animation3c6c4a4530、Combate6a777e74f（83帧）通过；Flameb0bd357966一发显示短194ms、FastHeldaa21ab823f箱170ms失败。PAUSE.request保留，不覆盖旧红。
- 23及此前d55字节的结果不能承接到24。旧SHA d55c2922f9a2bedd50e9baf2080e0305d71c92cbd479cd93e9c33e7199f24836。
- 85ms持物缓冲b173fa4d4a四项170/210/140/200ms；5%角色追赶c32f83ed18仍197ms红，**均未采用**。held04固定回放10–20ms收益不覆盖实战失败；生产仍持物100ms、角色10%渐进调整。
- 取消截图a4684717e6仍5项真实时长红，截图不是完整解释。采样本身改变时序，诊断不计发行。
- 最后地形诊断74ae636f61宿主启动超时，没有有效性能对照，不重跑游戏。期间整机CPU单次采样100%且《群星》运行；不是所有历史红项的因果证明。
- 固定回放01因CRLF归一化触发源指纹拦截，02缺运动边界依赖编译失败；均未启动AIR，原目录保留。03逐字节复制生产源，并对未测接口显式拒绝调用，60项通过。
- 旧13为38组36绿/2红，22为8组4绿/4红。04采样曾捕获Sound.play内485ms，测试副本遗漏Music已修复；不能由此解释全部旧长帧。[验证记录](validation-m50-2026-10-09.md)。

## 5. 集成内容与已知边界

- PeerAppearance同步真实翅膀；WeaponDisplay保留原生翻转、后坐/世界姿态；UnitPresentation/ProjectileVisuals重放真实Bullet帧、保留换枪在途弹，事件首次发送后留700ms，不重复攻击。原21双向7角度负控14假翼/14弹道失败；旧候选专项通过不替代24验证。
- R2友伤默认关、宿主管理；R12个人投掷伤害默认关；R8地雷唯一宿主权威，重返核对当前显示层。近战、爆炸、重型弹、能量命中、火焰/燃烧、墙痕、传送、本体效果和跟随恢复均已接线，见各state handoff。
- 已安装21个人允许被抓默认关、WASD挣脱默认开。浮窗常驻280×36、分页/滚动/拖动/停靠，各自30–100%不透明度；Ctrl+Enter聊天、F10显隐、原生Enter全屏不变。
- M43背景门后宿主消失/失控未可靠复现；旧Area/Trap #1063、全部#1009和密集长期卡顿不能宣称已解决。镜像地雷拾取/拆除/枪击/念力仍有边界。
- 真人鼠标/输入法、长期运行、全部NPC/武器和第三方组合未穷举；固定回放不是公网、全FPS或整体性能保证。

## 6. 下一步

1. 53170、64226、87028均已结束，自有AIR已清理。先处理真实时序失败；探索降频仅为未采用的诊断，不能当成已修复。后续在无其它游戏测试争用时建立新续验目录，保留24全部原红，不能覆盖驱动/结果来重试。
2. 若输入改变就新冻结，不改旧清单；保持原时间/图像门槛，逐项检查真实结果。不能由代码检查点直接跳过实机门禁。
3. 查清剩余真实时序问题；全过后实际宿主audit_m50→新建唯一21备份→部署自身SWF→无驱动全模组冒烟（失败先回滚）→保护文件/PID/记忆收尾。机器负载解释不能代替验收。

## 7. 接续入口与工具

- [开发日志](journal.md)、[M50呈现实验](../knowledge/experiments/2026-10-09-m50-peer-presentation.md)、[验证工具](../tools/validation/README.md)；历史原始证据保留。
- 当前基线build/m50/integration-baseline-0.2.21-native-assets：157保护条目/98原生资产；已补Music/JSON配置，9外部SWF/3配置按实际输入绑定。旧60/61项基线不覆盖、不跨基线继承；未改外部模组。
- M49的build/backup/m49-release-20261008-232026-727eb9/RConnectMod.before.swf是旧20备份（77e3886f），**不是21备份**，不得用于M50回滚。
- AIR/amxmlc、SWF38，入口RConnectMod.init(main)；loader路径app:/mods/Rconnect/release/RConnectMod.swf勿改。根application.xml→pfe.swf 1.02；勿误用app.xml。反编译首选game-reference/decompiled/1.02/src102/scripts。
- Python及子进程显式-X utf8：C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe。Java：C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe。SDK：D:/RemainsMod/mods/Sandevistan/build/tools/flexsdk，FFDec同tools/ffdec；日志可能GB18030。
- build_mod务必显式--output build/<新目录>/RConnectMod.swf，默认会写release。固定回放：tools/validation/run_fixed_terrain.py --baseline build/m50/final-presentation-23 --output build/m50/<新目录>，不复用目录。
- 沙箱空进程列表不代表整机；AIR启动或最终确认用已授权实际宿主执行器，只管理自有PID，查询失败不可声称清理完成。
- git用本模组build/m43/empty.gitignore及core.safecrlf=false；按区级eclipse身份本地提交，不推送、不覆写历史。
