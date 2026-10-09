# RConnect候选门禁入口

当前安装 **0.2.21-dev / 5c372cf5…**。最终20组2095/0、各DONE；正常无驱动加载3611e15340通过（150秒上限）。42个最终专项/启动实例PID退出，其他56保护未变。见state/deployment-m49-2026-10-08.md。新版本另建安装基线，不重跑旧部署或覆盖失败。

下述脚本固定本次UI17→18验证链，现在直接重跑prepare/deploy会被安装基线守卫拒绝。后续发行建立新的安装基线、版本和冻结目录，不覆盖本轮基线或结果；已完成本轮无需重复运行。

## 已完成UI发行

独立编排ui_release.py只从已验证M45冻结源派生，不使用含M46的工作树核心。最终build/ui-20261006/stable-ui-07保存50源/131验证/49类、四组同字节、22原生PNG与部署/正常加载receipt。生产仅NetHud、新HudLayout与版本变动；17UI不能替代18核心验证。

所有入口用明确UTF-8启动：`python -X utf8 tools/validation/ui_release.py <mode> --snapshot build/ui-20261006/<新目录>`。prepare/build/test/audit/deploy/smoke；每步新输入在启动前冻结，输出不覆盖。当前脚本绑定M45安装起点，已经部署后不再重跑prepare或deploy。首次默认GBK读取deployment receipt在AIR前失败已先回滚，原错误和receipt保留；同字节-X utf8重试正常加载成功。该失败不是UI运行崩溃。

## UI之后的M46核心

- 旧build/m46/integration-baseline仍保存M45；旧final-* / build/m46执行副本/全部失败不改。
- build/m46/integration-baseline-after-ui-20261006保存当时UI17字节、57保护、UI源出处与正常加载run。只能创建一次，不能用新基线抹去旧失败。
- 正本在本目录执行，**不再复制覆盖旧build/m46脚本**；新freeze冻结所有本目录Python及验证依赖，源manifest记录baseline路径和指纹。validation_baseline.py检查当前输入，拒绝旧M45基线用于新安装、篡改baseline hash、18核心复用17版本、漏掉Hud专项。
- 最新冻结build/m46/final-after-ui-clock-05：52源/146验证，0.2.18-dev、123147B、51生产类、SHA044382765a2340ce9babe6f3d01eb61197a438f7d1f9ea70262601535714f042；编译出处clock-01，52生产源及实际产物相同，后续只更换测试/审计输入时如实记录候选复用，不冒充重编译。
- clock-original-02与固定100ms延迟控制均15/3，共享真实RemoteMotion补偿为18/0。14组全部1648/0，旧恢复905负控8221fc329d两端各130/33/DONE、实际空mask；正常无驱动eb84c49f11绿。本轮已部署，全部源/实际字节/测试/配置/日志/PNG/保护/负控/进程/部署证据在m46-validation-evidence.json。
- Beam固定300→60产生真实240伤害请求、SATS固定远距look0/近距look20、Projectile旧fireAt提前移除使31个真实闪电事件帧全空，各有同生产字节的复制红/绿对照。只修正式测试前提，原断言/时窗保留；全部旧失败和复制输入不覆盖。对应控制由audit_final核对实际生产/驱动/日志与源差异。

顺序：新freeze → 显式输出候选构建 → FFDec类清单 → finalize_restore_build → 明确回归入口串行 → 当前不变恢复驱动旧905负控 → audit_final → 备份部署 → 正常无驱动加载，失败先回滚。

1. `python -X utf8 tools/validation/prepare_integration.py baseline`已创建新安装基线；不要重复执行或覆盖。
2. `python -X utf8 tools/validation/prepare_integration.py freeze build/m46/final-after-ui-N`冻结源、AS3测试/存根、正本工具和原真实模板档；目录必须全新。
3. 显式输出候选，不能用默认构建（会写release）。类清单与当前build/GameCombatStubs.swc都按本次编译记录，然后`python -X utf8 tools/validation/finalize_restore_build.py build/m46/final-after-ui-N`。
4. `python -X utf8 tools/validation/run_final_regressions.py --list --snapshot build/m46/final-after-ui-N`只列计划；执行必须明确entry。Motion须传本次冻结的两份profile。14组为原13组加HudTestDoc；导航/慢换图仍可按变化额外跑。不放宽时长/阈值追绿，任一红停后续并即时记journal。
   独立夹具变更时，carry_same_byte_checks.py只允许已完成的八个入口：生产源/SWF、所有编译与运行依赖、存根、角色档、配置必须一致，并实际导出driver类表确认不含改过的测试类。只有审计工具变化时也须全新冻结和同样核对；收据明确“保留旧运行”，保留origin递归出处，不增加运行次数。改过的入口必须重新运行，不沿用旧绿。
5. `python -X utf8 tools/validation/run_old_restore_control.py build/m46/final-after-ui-N`检查保留旧905实际生产字节；预期严格即时恢复红、两端DONE、实际空mask记录，不把崩溃当有效负控。编译声明来源和当前存根分别记receipt。
6. `python -X utf8 tools/validation/audit_final.py --snapshot build/m46/final-after-ui-N`核对14组/驱动/配置/实际字节/类/PNG/保护/负控。只在全部真绿后更新m46-validation-evidence.json。
7. `python -X utf8 tools/validation/deploy_verified.py --snapshot build/m46/final-after-ui-N`仅替换本模组release，唯一备份；receipt存该snapshot，旧记录不覆盖。
8. `python -X utf8 tools/validation/run_smoke.py --snapshot build/m46/final-after-ui-N`正常加载双端，失败先回滚。无snapshot只用于旧历史global receipt。

恢复PNG规则在../verify_mask_png.py：检测实证的32×24连续近白矩形，不能等同整场景像素一致或所有第三方绘图都合法。149原恢复断言/端＋14即时退役引用断言保留，实时PNG另验。新核心仍须用最终同驱动重新旧905负控。

Java/AIR路径与业务边界见MEMORY；只有当前源/测试/字节闭包及新基线同时满足才可能部署。R2/R3仍只读，root移交具体窗口后才能运行；不同时编译/跑其他AIR，不改用户进程、存档或其他模组。UI关闭/正常部署不算稳定重连修复。

## M47 显示发行（已完成）

prepare_m47.py建立18安装基线并冻结新目录；53生产源/151验证输入/52类，生产实际编译于final-presentation-01。最终build/m47/final-presentation-07保留十五组相同输入真实运行（五组02/六组05/四组06），恢复组07执行，carry_m47_checks.py核对实际driver类表及依赖闭包。run_final_regressions.py要求原13组、HUD、高速搬运和武器角度，共16组；audit_m47.py核对源/实际生产与外部驱动字节/类、配置、旧新原生负控、PNG和保护文件。部署及正常加载只走deploy_verified.py/run_smoke.py；smoke失败先回滚。当前基线绑定18→19，已经部署后不再重跑此链。

## M48 显示衔接发行（已完成）

prepare_m48.py建立19安装基线，baseline/freeze/built各阶段采用全新目录。原生容器/SATS与实际RemoteMotion负控为red-continuity-04/bd9ceaf401；暂停、曲线、掉落三个逐项候选保留未修部分的红。最终01实际编译77e3886f并跑17组；02只修正审计字段语义和新增carry_m48_checks，保留实际同字节运行，53源/156验证/52类。audit_m48检查正确稳定暂停差abs(pausedX-endpoint)，并核对旧负控、驱动类表/实际输入、全部17组、PNG及保护文件。原initialGap是收包瞬间差值，不是稳定暂停断言。

顺序：prepare_m48 baseline/freeze → 显式候选编译/类表/built → 原16组加PresentationContinuityTestDoc → audit_m48 → deploy_verified → run_smoke（失败先回滚）。所有Python包括子进程显式-X utf8；AIR后台策略的自有PID查询需要实际权限，受限启动失败不算功能负控。19→20已经部署，此链不可再当新发行重跑；下一轮新建安装基线。


## M49 生命周期与个人念力发行（已完成）

prepare_m49建立20安装基线；最终build/m49/final-lifecycle-16为54源/163验证/53类。生产实际编译10，5c372cf5/131147B；20组2095/0。原10四专项、14两念力组、15十二组由carry_m49_checks按实际driver类表与完整依赖保留，16新跑WeaponAngle/PresentationContinuity。该工具只允许列明的独立测试/审计变化，受影响driver不得保留；保留MirrorMask时同时核对原runner_exit、空白块列表与14张图的审计记录。

旧20负控red-target-06/9beba4f621与red-native-death-08/950b33f377不变，Target/Respawn原测试指纹一致。个人原生E的85c5a17770、暂停端点60b7441492及逐项候选均留存。测试时序/起点竞争修正不修改生产；12长帧、13未复现的单次通道超时及15两帧武器错误也保留，最终绿不反推所有旧红已解释。

顺序：prepare_m49 baseline/freeze → 显式编译/类表/built → 20组 → audit_m49 → deploy_verified → run_smoke（失败自动先回滚）→ 保护/自有PID收尾 → 记录及本地提交。正常启动3611e15340无驱动、全已安装模组通过；20→21已完成，禁止把旧基线再用于新发行。当前版本变化仅本机，公开8包与玩家README保持对应关系。


## M50 当前候选（未部署）

安装仍21。用户已退出普通游戏，实际宿主已核对；隔离旧21/候选14压力仍有帧数红，不能归因普通双开。15快拖有效原生步前提成立后仍检出180ms延迟，16只实装主动握持100ms缓冲上限。共享栅格原型无稳定收益，未采用。

当前final16实际编译SHA47bf9790/163002B/68类，69源/189验证输入。6组新字节通过，其余32组串行运行；没有承接77字节成功。本次Combat84帧达到原最低界，历史低于80的失败与波动保留，不表示性能问题全部解决。

全38组通过后才audit_m50（获准实际宿主CIM，查询失败致命，完整描述符区分PID复用）→唯一21备份→deploy_verified→无驱动全模组run_smoke（失败先回滚）→保护/自有PID收尾→记录与本地提交。实际字节/独立驱动类表/配置/负控/PNG门槛保留。当前没有M50发行证据或部署收据，不推送。完整实际状态见state/validation-m50-2026-10-09.md。

M50接续更新：当前final20为19实际编译d55c2922/163081B/68类（69源/190验证输入），只在自动掉落流追加批次缓冲；新字节尚需全38组，旧47/77绿不能承接。PresentationContinuity使用固定基地rbl，原真实容器/原生SATS及85ms条件保留；原随机废墟674ms缺帧失败与密集压力另行记录。实际状态以MEMORY/journal为准，尚无发行证据。

最新接续为final23：20基地规则不适用，21恢复废墟；22部分源端长帧仍红。独立栈采样抓到Sound.play停顿，runner遗漏Music已修正。`native_runtime_assets.py`统一枚举/复制98个原始资产；`validation_baseline.verify_runtime_inputs`绑定双方实际资产、外部SWF和TXT/JSON配置。新baseline `integration-baseline-0.2.21-native-assets`157项保护，旧基线不改、不跨基线承接。11项工具自测通过（临时目录在本模组build内）。23精确复用d55，69源/194验证输入，38组及21负控重新执行，未部署。诊断采样结果不计发行证据。
## M50最新：代码与固定回放

当前final24仅编译/固定检查通过，安装仍21。用户选择保留其它程序、暂缓双实例/时序测试；不要恢复23的PAUSE队列。24新字节不能承接旧游戏结果。

`run_fixed_terrain.py --baseline build/m50/final-presentation-23 --output build/m50/<新目录>`执行独立AS3计算，不加载游戏/角色存档。生产源逐字节复制，旧类只重命名；额外计数类只测快照分配。原生checkpoint、武器、传送事件调用明确失败，不替代这些功能的测试。03为60/0，Python自测11/0；原失败01/02保留，禁止复用输出目录。

固定回放不生成发行许可，不等于FPS/延迟达标。用户继续允许游戏验证后核对24输入与157保护条目，完整38组和旧21负控再审计部署。当前状态见state/MEMORY.md。

## M50正式27：火焰时钟修正的完整新验证

正式26六绿一红后暂停，不能继承到新生产。27冻结69源/197验证输入，构建32602e77/163453B/68类；完整38组加旧21负控重新执行。新增NativeEffectRateRegression的六项固定边界检查，原九组火焰时长/几何检查不改。独立effect-rate-fixed-replay-01共66/0；诊断与固定回放不生成发行许可。当前队列状态见MEMORY及27下result.json。

## M50正式26：正常可见窗口（历史）

用户要求WallBlend结束后续测。25隐藏窗口出现5组失败；独立可见窗口对照的原场景PeerVisual、Flame、FastHeld通过，Combat仍有一次69帧失败，旧结果完整保留。一次漏传rbl的诊断明确作废，不用来放行。

新freeze明确记录visible_windows=true；run_final_regressions、旧21负控和正常冒烟向runner传--visible-windows。runner保存两端实际描述符，审计核对描述符哈希和XML中的visible=true/pfe.swf，避免只凭命令行声明窗口条件。其它runner调用保持原默认隐藏，历史输入不改。没有修改生产SWF、各项测试断言或系统性能配置。

正式26仍为d62c0bd2/163276B/68类、69源/196验证输入。完整38组及旧21对照重新执行，不承接诊断通过；首组Combat a597b8a85f通过（密集114帧/p95 98ms）。结果以MEMORY与对应result.json为准，未全过不得部署。
