# RConnect —— 开发记忆入口

> 2026-10-07 当前安装：**0.2.18-dev**，123147字节，51生产类，SHA256 `044382765a2340ce9babe6f3d01eb61197a438f7d1f9ea70262601535714f042`。紧凑浮窗保留，M46核心已完成联合验证与部署：14组1648/0、各端DONE；正常无驱动150秒eb84c49f11通过。32个最终专项/旧905负控/冒烟自有游戏PID已退出，其他56保护未变。[部署与回滚](deployment-m46-2026-10-07.md)。

> root统一源码、测试、编译/AIR与部署；RConnect (2)/(3)已交回窗口，仍只读。本轮无待运行检查，未推送或对外分发。真实鼠标/中文输入法、背景门原反馈及密集卡顿仍需后续实测。历史失败见journal及各实验原件，不由本轮绿倒推所有旧因果。

## 1. 定位与边界

双人合作，各自原生角色进入同一世界。同房由宿主结算，普通房分头时各端运行所在房的原生战斗；RoomSync交接空房/汇合状态。玩家约20Hz，敌人/场景约5Hz，显示逐帧推进。当前根游戏1.02，World.constructor.boxDamage=0.2；参考路径game-reference/decompiled/1.02/src102/scripts。入口RConnectMod.init(main)，AIR/amxmlc、swf-version=38。

只写RConnect；游戏SWF/描述符、game-reference、其他模组默认只读。loader路径app:/mods/Rconnect/release/RConnectMod.swf（小写c），勿改目录/文件/入口名。根application.xml实际指向pfe.swf，app.xml是另一版本，不能混淆。先读AGENT_SCOPE，再按需GOVERNANCE。

## 2. 用户授权与玩法

- 已授权修复已有合作功能、允许大幅重构和候选部署；不新增任务/背包/交易规则，排除稳定重连、三人以上、公网和版本兼容。
- grilling Q1–Q5已确认：同地图普通房自由分头；空房暂停并保留进度；宿主发起共同换图；剧情/挑战共同进出；跨游戏退出沿用原版保存，不新增随机房完整战斗存档。不得重复确认。
- 地面物品一份，先拾取者原生入包；经验点双方奖励；存档点共同解锁，各自保存角色。跟随默认关，地图标记/主动传送沿用共同旅程限制。
- 任一端菜单/SATS可触发全队暂停（含分房），双方全部关闭才恢复；两开关默认关、宿主设置。网络、菜单、聊天与SATS排队继续。
- 用户查看浮窗HTML后已明确“开始实装”“继续”。常驻280×36、通常展开280×240、四页/滚动/标题拖动/四角停靠、分别保存位置和开合；主字号12。原版Enter全屏保留，Ctrl+Enter普通游玩开聊、输入框Enter发送、Esc收起，F10隐藏/恢复。释放Shift等键交原生接口，暂停原因独立显示。
- 用户授权与RConnect (2)/(3)三方直接协调，由本会话统一验证/版本/部署/记录。其余会话不得各自覆盖release；后续AIR/编译窗口串行。
- 同机第二角色保留自己身份与存档；原生读档列表选择角色，首次迁移保留原件，以后不重复覆盖。Start-Coop.bat只管理自己启动的进程。

## 3. 当前安装、证据与回滚

- 最终冻结build/m46/final-after-ui-clock-05：52源/146验证输入/51AS生产类。实际编译出处clock-01，后续只有测试/审计变更，生产源及SWF完全相同，candidate-reuse.json如实记录；无原生存根/测试类混入。
- 14组念力108、运动198、抓持211、Lightning27、Beam26、SATS26、Pause438、Room74、Projectile10、Combat33、Animation26、Gameplay31、Restore326、HUD114，共1648/0。前八组核对实际driver类表、源/运行依赖后保留旧绿，不伪称新跑；原红/编译失败/设置失败均保留。
- 源时钟独立原类与固定100ms控制均15/3，实际共享修正18/0；最终恢复旧905负控8221fc329d两端各130/33/DONE、记录真实空mask。新恢复8case和14即时PNG通过；UI22PNG，目视常驻/中文设置/640×480与200%窗口。
- 正常加载eb84c49f11无driver、全部已安装模组、150秒，版本/心跳/世界匹配绿；32自有游戏PID退出。knowledge/experiments/m46-validation-evidence.json闭合实际源、配置、日志、PNG、控制、保护和部署出处。
- 回滚备份build/backup/m46-release-20261007-024209-047d31/RConnectMod.before.swf，上一UI17/M45 SHA a5698f9f5941b27c2fd47de56366c4d867bf256b2dcb7d484596844dea093971。双方保存退出，复制回release/RConnectMod.swf后完全重启；不回退角色存档。
- 原UI17独立发布681/0与正常加载4a3257643f保留在deployment-ui-2026-10-06.md、ui-20261006-validation-evidence.json。首GBK读取预检失败先回滚、-X utf8重试成功，原receipt不覆盖。更早M45备份/1003项历史仍保留。

## 4. M46实现与失败边界

- 念力旧q=true续报解除NPC指针已有包前后实证；新Q可合法抢箱。共享body/proxy显示引用产生已归属的孤立遮罩，隐藏四个对象时光晕像素0→523；只隐藏孤立副本，保留无关滤镜/活跃引用，不读或释放RV的像素存储。
- MirrorMasks在共享前保存直接原生mask，删除按绘制顺序/几何猜认所有权；早ENTER_FRAME只观察引用，晚RENDER捕获/去重。退出/roomHold/原生字段重建均清理；引用不可安全还原时用自有过渡图形。case7覆盖最后观察后出现新持有者，非全部第三方时序。
- getChildAt可能在原生MovieClip报告numChildren>0时返回null；恢复链加空守卫。孤立旧alias隐藏与同签名清理修复已观测的case4白块，不能把全部匿名Timer认作同因。
- 共享暂停收到末帧时settle收齐掉落缓冲，恢复不倒播；源时钟offset改善时cursor同量换算，固定累计时序族最少9帧触发旧显示迟滞。延迟/TTL/传送/无时间戳路径保持。
- 天角兽闪电实际spring1/visbullightning，记录真实显示帧和结束，结束从max(出生,结束)+700ms保留。代理传递id/isVis/npc/noAgro/isSats及数值化抗性；借用真实vis/hpbar而不运行本体AI，原生隐身/资格规则保持。红外特有类型匹配尚未穷举。
- Beam原夹具人工300→60真实误发240破坏；只修host布局接收/基线，并保留原23断言/时窗。SATS远距look0、近距look20红绿，只修测试角色位置、保留原24项，空目标先报FAIL不再读selected.v。Projectile旧fireAt跳过显示且立即移除，31个真实事件帧全空；原生武器输入原9项通过，正式补一项武器前提。生产破墙/锁定/弹道未因这三条夹具修正而修改。
- 原e329/5640错色和匿名Timer、7df暂停掉落、31184 Beam、6bd SATS及d4ef弹道失败全部保留。新控制证明固定路径，不逐条反推旧随机失败原因；没有宣称所有1009均修复。收尾表格误读roles字段的KeyError在正常加载之后，记录/截图已完成，随后核对原日志补表，不属运行故障。

## 5. 已知边界与接续

- 真人实体鼠标、中文IME提交和实际常用菜单遮挡需玩家测试；合成事件/截图不是满意度认证。HTML file:浏览器限制未绕过，原生AIR截图不冒充HTML浏览器验证。
- 背景嵌门原反馈为宿主失去自己的角色/控制、返前景死敌重现且无法伤害；不解释成正常跟随。M43实际档/视野下开跟随五轮117、关跟随107未可靠重现，诊断保留，根因未认定。后续若重现看两端RoomTrace/角色状态，不能盲改。
- 密集战斗仍可能卡顿。当前Combat 80敌人88帧、p95 126ms；基础254帧/8448ms/p95 44ms仅为同候选不同负载，不是版本性能配对，不声称提升。M40/M41/M43持续7段历史与后台策略KB-000071边界保留。
- 房间只保留本次同地图联机；特殊对象引用、全部Boss/第三方状态/所有换房竞争未穷举。IR分支、任意遮罩接管和全可见→部分可见组合没有完整证明；5px整Tile回退依赖当前RV格式。
- 既有Area/Trap #1063构造诊断仍可能出现并被捕获，旧版本已有，本轮未改此路径；总门禁绿不等于全部历史诊断消失。
- 本轮已收尾，无待运行门禁。不再重复跑已绿的同输入；新变化/实际失败才重开。若继续发行，建立新安装基线和新版本，不覆盖UI17/本M46冻结，也不直接重跑绑定UI17→18的旧prepare/deploy脚本。
- 后续用户保存后重启实测18；重点常驻/展开高度、真实拖动/四角、中文输入、念力光晕、断开后原生敌人/血条与闪电持续/结束。不自动推送。

## 6. 记录与工具

- 当前发布deployment-m46-2026-10-07.md和m46-validation-evidence.json；门禁tools/validation/README.md。clock、Beam/SATS/Projectile夹具和native-mask-restoration各自实验；历史过程在journal。
- M45/M44/M43发布记录和各mXX-validation-evidence保留；M41反馈/动画、M40连续显示、M39合作/后台策略、M38伤害、M37SATS、M36分房机制均有原实验与设计证据。
- 构建tools/build_mod.py --java <java> --output build/<新目录>/RConnectMod.swf，必须显式输出，默认会写release。原子部署走release-gate，无游戏文件补丁时loader步骤不适用。
- 正本tools/validation：prepare_integration → 显式构建/类表 → finalize_restore_build → 明确entry串行 → 最终测试旧905负控 → audit_final → 唯一备份/deploy_verified → run_smoke（失败先回滚）。全部Python用-X utf8。Motion须冻结真实角色模板与--connect-after-load。
- 外部driver用tools/build_effects_driver.py --candidate <SWF> --source-root <冻结src> --output build/<新目录>/driver --entry <Doc>；runner tools/run_coop_regression.py，--all-mods --responsive --effects。只管理自有AIR标识/PID，不动用户进程和存档；磁盘不足不删原日志/备份/唯一资料。
- Python C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe；Java C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe；SDK D:/RemainsMod/mods/Sandevistan/build/tools/flexsdk，FFDec同tools/ffdec/ffdec-cli.jar。AIR/编译受限走工具审核，不绕过。
- 旧tools/make_release.py是0.1.0整包脚本，本轮未运行；今后分发先更新包清单纳入启动器，不当作当前发布入口。
