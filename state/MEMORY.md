# RConnect —— 开发记忆入口

> 2026-10-08 当前安装：**0.2.20-dev**，126293字节，52生产类，SHA256 `77e3886f7f76885db35558ba7da4a591ec486ab65faab37f95c14116d67bb3ee`。M48念力曲线、容器掉落、共享SATS停止位置已部署；同字节17组1880/0/DONE，正常无驱动150秒752a939f9e通过；36个最终专项/冒烟自有游戏PID退出，其他56保护未变。[部署与回滚](deployment-m48-2026-10-08.md)。

> M48已收尾。最终冻结build/m48/final-continuity-02，53源/156验证；生产实际编译及17组运行在01，02只修正审计读数并增加核对工具，实际相同输入全部保留，不冒充新运行。Continuity 8358dbf884稳定暂停差/恢复跳0、掉落停顿0/53ms；FastHeld 23d4d17633双向110–120ms。原版负控bd9ceaf401及逐项候选c8d15f6da4/78545f377c/dbe366d129保留。详见knowledge/experiments/2026-10-08-m48-presentation-continuity.md。

> root统一源码、测试、编译/AIR与部署；RConnect (2)/(3)已交回窗口，仍只读。未推送或对外分发。真实鼠标/中文输入法、背景门原反馈及密集卡顿仍需后续实测。历史失败见journal及各实验原件，不由本轮绿倒推所有旧因果。

## 1. 定位与边界

双人合作，各自原生角色进入同一世界。同房由宿主结算，普通房分头时各端运行所在房的原生战斗；RoomSync交接空房/汇合状态。玩家、活跃念力箱/掉落及新生/飞行中普通掉落约20Hz，敌人/完整场景约5Hz，显示逐帧推进。当前根游戏1.02，World.constructor.boxDamage=0.2；参考路径game-reference/decompiled/1.02/src102/scripts。入口RConnectMod.init(main)，AIR/amxmlc、swf-version=38。

只写RConnect；游戏SWF/描述符、game-reference、其他模组默认只读。loader路径app:/mods/Rconnect/release/RConnectMod.swf（小写c），勿改目录/文件/入口名。根application.xml实际指向pfe.swf，app.xml是另一版本，不能混淆。先读AGENT_SCOPE，再按需GOVERNANCE。

## 2. 用户授权与玩法

- 已授权修复已有合作功能、允许大幅重构和候选部署；不新增任务/背包/交易规则，排除稳定重连、三人以上、公网和版本兼容。
- grilling Q1–Q5已确认：同地图普通房自由分头；空房暂停并保留进度；宿主发起共同换图；剧情/挑战共同进出；跨游戏退出沿用原版保存，不新增随机房完整战斗存档。不得重复确认。
- 地面物品一份，先拾取者原生入包；经验点双方奖励；存档点共同解锁，各自保存角色。跟随默认关，地图标记/主动传送沿用共同旅程限制。
- 任一端菜单/SATS可触发全队暂停（含分房），双方全部关闭才恢复；两开关默认关、宿主设置。网络、菜单、聊天与SATS排队继续。
- 用户查看浮窗HTML后已明确“开始实装”“继续”。常驻280×36、通常展开280×240、四页/滚动/标题拖动/四角停靠、分别保存位置和开合；主字号12；设置页30–100%窗口不透明度，各角色本机分别保存、暂停提示独立alpha1。原版Enter全屏保留，Ctrl+Enter普通游玩开聊、输入框Enter发送、Esc收起，F10隐藏/恢复。释放Shift等键交原生接口，暂停原因独立显示。
- 用户授权与RConnect (2)/(3)三方直接协调，由本会话统一验证/版本/部署/记录。其余会话不得各自覆盖release；后续AIR/编译窗口串行。
- 同机第二角色保留自己身份与存档；原生读档列表选择角色，首次迁移保留原件，以后不重复覆盖。Start-Coop.bat只管理自己启动的进程。

## 3. 当前安装、证据与回滚

- M48安装20/77e3886f/126293B/52类，最终final-continuity-02同实际字节17组1880/0/DONE，正常加载752a939f9e通过。02相对01只改audit_m48读数语义、增加carry_m48_checks；candidate-reuse与carried-checks核对源码、实际生产与外部驱动、全部测试/编译/运行依赖、配置和角色模板。不是重编译或新增测试。
- 回滚到19：build/backup/m48-release-20261008-164301-39b69b/RConnectMod.before.swf，SHA4008999be4c15a84ae6975115886fe481983c5b1c4151197c5795b57c2a2de6a。双方保存退出，复制回release/RConnectMod.swf再重启，不回退存档。安装基线build/m48/integration-baseline-0.2.19已完成，下一轮另建基线，不重跑此部署。
- 当前证据m48-validation-evidence.json；36个最终专项/冒烟自有PID退出、其他56保护不变。24张原生HUD图中目视70%/40%和小窗200%；14张mask恢复图无已定白块。尚无真人IME/实体鼠标认证。
- 以下为M47历史出处，不是当前安装或当前回滚：
- 最终冻结build/m47/final-presentation-07：53源/151验证/52生产类。真实编译在final-presentation-01；后续只改独立测试/审计，源与SWF完全相同，candidate-reuse.json如实记录。实际driver不混入生产/native实现。
- 16组1860/0/DONE；十五组保留原运行（五组02/六组05/四组06），carry_m47_checks.py核对实际类表不含改动测试类及全部编译/运行依赖、配置、成对档，恢复组07新跑。原失败不覆盖。
- 快速原生搬运bef1c63bb8：箱host→join140ms、join→host130ms；掉落120/110ms，旧有效负控350/370/340/350ms。不是通用FPS改进。武器50605d6f47为七角度×双向原生LMG/开火；旧12错误角度负控有效。
- HUD52601ca525各69/0，24原生PNG，目视宿主70%/加入40%中文/小窗200%；不是真人IME或实体鼠标认证。正常加载ca43e3b445无driver、全已安装模组、150秒，版本/心跳/世界匹配绿。
- 回滚build/backup/m47-release-20261007-184315-8618b6/RConnectMod.before.swf，上一18 SHA `044382765a2340ce9babe6f3d01eb61197a438f7d1f9ea70262601535714f042`。双方保存退出，复制回release/RConnectMod.swf后重启；不回退角色保存。
- evidence=m47-validation-evidence.json，实际来源、字节、配置、驱动、日志、PNG、负控、保护与部署闭合。M46/18、UI17的1648/681项和回滚记录保留，不由19绿色反推全部旧失败。

## 4. M48实现及M47历史边界

- RemoteMotion≤50ms高频坐标/瞄点用保形三次插值，保存前一真实样本、按相邻坡度连续连接，端点有界、反向归零，不外推或新增延迟。57固定20Hz包边界速度变化0.08810→0.002647px/ms；真实快速Q四场景110–120ms，不等于所有网络/FPS表现。
- 普通掉落由readLootSync(true)挑新生/运动/落地500ms尾段，附既有worldstate并加房间epoch/term。applyLootSync(motionOnly=true)不按缺席删除，快轨迹阻挡旧慢包重置；首个坐标立即起播，持有物仍由既有归属通道接管。原生容器两方向0/53ms空中最大停顿，旧273/220ms；单份拾取和换房回归保持。
- coopPaused时tickFrozenAnims/queueUnitMotion收齐停止末帧、同步hit代理及原生SATS覆盖图层坐标；不重新getUnits、不改选择/攻击队列、不在暂停期间推进AI/反馈/伤害。稳定位置差和恢复跳约30px→0，完整暂停队列回归通过。initialGap=endpoint消息到达时刻，可非0；稳定断言是1200ms后的abs(pausedX-endpoint)。审计按原生断言修正，不改测试阈值。
- 初次隔离运行CIM权限/子进程GBK、独立速度测试漏赋值符均在场景前失败，原件保留，不算有效负控。19原样、暂停单变量、再加曲线、再加掉落四阶段保留剩余问题红，因果分离成立；未把候选专项绿当完整发行。

M47历史：

- GameBridge只把有稳定键的本地活跃box/loot放入已有20Hz玩家消息；RemoteMotion(50)保留100ms源缓冲，释放重复500ms，受房间/epoch和本地握持限制。旧完整场景包不能回绕高频游标/复活抓持；单位仍走EnemyGrip。
- WeaponDisplay采集原生武器世界显示矩阵，插值位置/短角度、离散反射，抵消幽灵父级翻转；同游标换枪/同变体工厂创建，缓冲开火计数播放剪辑。没有执行远端Weapon.step/actions/第二份伤害。
- opacity本机SharedObject，30–100/默认100/步10，焦点内方向键/Home/End；AIR alpha按1/256量化，256bf95f2a容差0.001是假红，经独立AIR探针仅修断言，生产不变。
- EnemyGrab bf1024bfd0/711f601d49夹具瞄点被原生actions重读World鼠标、随机场景和自主AI未隔离；18/9002d2885f与19/ecf7818e25均确认。保留原位移1/35、阻力18、时窗和14案例，固定真实输入/原地形清空物件/只关测试敌人自主控制，增落地/瞄点/负例前提。bd031ffdfe为夹具误写Unit无osnova字段#1056；删除后c0cbc2dbc5全部通过。未改生产追夹具绿，原件留存。
- Restore c2dcc052bd实际326/0但过早leave、缺首次世界同步；独立夹具等待真实接受的unitsync，8bc997dac6通过，runner网络要求与生产不变。
- Projectile3c02aaf0f5 muzzle红；25776b546b实证两端源枪无parent/stage、display=null。仅独立夹具改完整原生factory/addVisual/attack/step/Camera，保留原显示要求与时窗并补源枪实际显示/开火前提；生产不变。

## 5. M46历史实现与失败边界

- 念力旧q=true续报解除NPC指针已有包前后实证；新Q可合法抢箱。共享body/proxy显示引用产生已归属的孤立遮罩，隐藏四个对象时光晕像素0→523；只隐藏孤立副本，保留无关滤镜/活跃引用，不读或释放RV的像素存储。
- MirrorMasks在共享前保存直接原生mask，删除按绘制顺序/几何猜认所有权；早ENTER_FRAME只观察引用，晚RENDER捕获/去重。退出/roomHold/原生字段重建均清理；引用不可安全还原时用自有过渡图形。case7覆盖最后观察后出现新持有者，非全部第三方时序。
- getChildAt可能在原生MovieClip报告numChildren>0时返回null；恢复链加空守卫。孤立旧alias隐藏与同签名清理修复已观测的case4白块，不能把全部匿名Timer认作同因。
- 共享暂停收到末帧时settle收齐掉落缓冲，恢复不倒播；源时钟offset改善时cursor同量换算，固定累计时序族最少9帧触发旧显示迟滞。延迟/TTL/传送/无时间戳路径保持。
- 天角兽闪电实际spring1/visbullightning，记录真实显示帧和结束，结束从max(出生,结束)+700ms保留。代理传递id/isVis/npc/noAgro/isSats及数值化抗性；借用真实vis/hpbar而不运行本体AI，原生隐身/资格规则保持。红外特有类型匹配尚未穷举。
- Beam原夹具人工300→60真实误发240破坏；只修host布局接收/基线，并保留原23断言/时窗。SATS远距look0、近距look20红绿，只修测试角色位置、保留原24项，空目标先报FAIL不再读selected.v。Projectile旧fireAt跳过显示且立即移除，31个真实事件帧全空；原生武器输入原9项通过，正式补一项武器前提。生产破墙/锁定/弹道未因这三条夹具修正而修改。
- 原e329/5640错色和匿名Timer、7df暂停掉落、31184 Beam、6bd SATS及d4ef弹道失败全部保留。新控制证明固定路径，不逐条反推旧随机失败原因；没有宣称所有1009均修复。收尾表格误读roles字段的KeyError在正常加载之后，记录/截图已完成，随后核对原日志补表，不属运行故障。

## 6. 已知边界与接续

- 真人实体鼠标、中文IME提交和实际常用菜单遮挡需玩家测试；合成事件/截图不是满意度认证。HTML file:浏览器限制未绕过，原生AIR截图不冒充HTML浏览器验证。
- 背景嵌门原反馈为宿主失去自己的角色/控制、返前景死敌重现且无法伤害；不解释成正常跟随。M43实际档/视野下开跟随五轮117、关跟随107未可靠重现，诊断保留，根因未认定。后续若重现看两端RoomTrace/角色状态，不能盲改。
- 密集战斗仍可能卡顿。M46历史Combat 80敌人88帧、p95 126ms；基础254帧/8448ms/p95 44ms仅为同候选不同负载，不是版本性能配对，不声称提升。M40/M41/M43持续7段历史与后台策略KB-000071边界保留。
- 房间只保留本次同地图联机；特殊对象引用、全部Boss/第三方状态/所有换房竞争未穷举。IR分支、任意遮罩接管和全可见→部分可见组合没有完整证明；5px整Tile回退依赖当前RV格式。
- 既有Area/Trap #1063构造诊断仍可能出现并被捕获，旧版本已有，本轮未改此路径；总门禁绿不等于全部历史诊断消失。
- M48已收尾，当前无排队实现。用户保存后重启两端实测20，重点念力快速运动、开箱掉落和加入侧SATS暂停/恢复。未覆盖的旧问题不因本轮绿改变结论；不自动推送。

## 7. 记录与工具

- 当前发布deployment-m48-2026-10-08.md和m48-validation-evidence.json；M47/19及M46/18记录保留；门禁tools/validation/README.md。M48显示衔接、clock、Beam/SATS/Projectile夹具和native-mask-restoration各自实验；历史过程在journal。
- M45/M44/M43发布记录和各mXX-validation-evidence保留；M41反馈/动画、M40连续显示、M39合作/后台策略、M38伤害、M37SATS、M36分房机制均有原实验与设计证据。
- 构建tools/build_mod.py --java <java> --output build/<新目录>/RConnectMod.swf，必须显式输出，默认会写release。原子部署走release-gate，无游戏文件补丁时loader步骤不适用。
- M46历史链（不可对当前安装重跑）：prepare_integration → 显式构建/类表 → finalize_restore_build → 明确entry串行 → 最终测试旧905负控 → audit_final → 唯一备份/deploy_verified → run_smoke（失败先回滚）。全部Python用-X utf8。Motion须冻结真实角色模板与--connect-after-load。
- 外部driver用tools/build_effects_driver.py --candidate <SWF> --source-root <冻结src> --output build/<新目录>/driver --entry <Doc>；runner tools/run_coop_regression.py，--all-mods --responsive --effects。只管理自有AIR标识/PID，不动用户进程和存档；磁盘不足不删原日志/备份/唯一资料。
- Python C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe；Java C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe；SDK D:/RemainsMod/mods/Sandevistan/build/tools/flexsdk，FFDec同tools/ffdec/ffdec-cli.jar。AIR/编译受限走工具审核，不绕过。
- 旧tools/make_release.py是0.1.0整包脚本，本轮未运行；今后分发先更新包清单纳入启动器，不当作当前发布入口。

- M47链：prepare_m47 baseline/freeze → 显式编译/类表/built → 16组串行 → audit_m47 → deploy_verified/run_smoke。独立EnemyGrab/Projectile/Restore夹具变化由carry_m47_checks只保留实际证明不依赖改动类的相同字节运行；不是重新跑或丢弃旧红。当前18→19安装基线已完成，不重跑部署；下一发行新建基线。
- M48链：prepare_m48 baseline/freeze → 显式编译/类表/built → 17组串行 → audit_m48 → deploy_verified/run_smoke。carry_m48_checks仅允许审计工具变化；所有实际执行依赖相同才能保留原运行。Python子进程也用-X utf8；AIR后台策略需能查询自有PID，沙箱受限运行不算功能负控。19→20已完成，禁止覆盖旧冻结/失败或复用旧基线部署新版本。
