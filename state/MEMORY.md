# RConnect —— 开发记忆入口

> 2026-10-04 当前安装：**M45 / 0.2.16-dev**，110626字节，SHA256 `59a03d1eb3ca7d8467015c709301bc1fbe6d585342de5857e984344a33572790`。念力抓敌与换枪光晕、可选全队菜单/SATS暂停及慢换图修复已部署：10组1003项及正常加载冒烟通过。[部署/回滚](deployment-m45-2026-10-04.md)。背景房与密集战斗边界保留。

> 2026-10-05 本会话完成浮窗**设计规划与独立HTML预览**，尚未实施/部署UI：[方案](../design/2026-10-05-hud-ui-plan.md)、[预览](../design/ui-preview/index.html)。本地file:被内置浏览器策略拒绝，实际渲染未验；静态检查范围见预览目录validation.md。

> 协议见 GOVERNANCE.md §8；参数与边界见 ../AGENT_SCOPE.md。

## 1. 模组定位

双人合作：各自角色进入同一世界。同房由宿主结算，普通房分头时各端运行所在房的原生战斗。RoomSync交接空房与汇合状态，玩家约20Hz、敌人和场景约5Hz、显示逐帧推进。入口RConnectMod.init(main)，AIR/amxmlc，swf-version=38。

## 2. 用户偏好与最新决定

- 最新UI任务只要求设计和规划，可创建HTML：现有浮窗过高且遮挡关键游戏操作。推荐常驻状态条＋四分页方案，等待用户查看反馈；不能把此预览称为已接入游戏，也不为本轮设计自动部署。
- 已授权修复已有合作探索/战斗/交互，允许大幅重构和候选部署。不新增任务/背包/交易规则，排除稳定重连、三人以上、公网和其他版本。
- 此前炮塔显示与分房请求点名grilling，Q1–Q5全部确认“符合，按此实现”：同地图普通房自由分头；空房暂停保留；宿主发起共同换图；剧情挑战共同进出；关闭游戏沿用原版，不新增随机房完整战斗存档。不得重复确认。
- M39九项反馈：密集敌人卡顿，炮塔/地雷/狮鹫索敌，容器掉落与拾取，跟随队友，闪电/双方开火/天角兽护盾，经验点与存档点。用户确认：地上物品一份，先拾取者获得；经验点双方奖励；存档点共同解锁，各自保存角色。继续既定修复/候选部署授权。
- 用户最新偏好：第二窗口保留自己的角色，启动时选择已有存档，已由R2落实手动启动和迁移保护。
- 最新M41反馈为加入侧血条缺失、数字位置/数值或颜色异常。用户已明确授权与「RConnect (2)」互通进度，并由本会话统一合并验证和部署；该会话另修掉落/肉食灵/蜘蛛地雷显示，保留双方改动，不并行跑性能测试。
- M43用户进一步明确授权与「RConnect (2)」「RConnect (3)」三方直接协调，仍由原RConnect统一合并、验证、版本、部署、MEMORY/journal及提交。R2负责光束/墙体，R3负责地图标记与主动传送；编译/AIR窗口串行，其他两会话不各自覆盖release。
- 只写RConnect；其他模组仅最小必要读取。测试隔离新角色和唯一AIR标识，只结束自己创建的进程；全部输入在任一端启动前冻结。用户进程和存档不动。
- 保留M31共享探索、M32轻机枪/天角兽伤害与不同护甲、M33动作平滑、M34开火/机械死亡/破墙、M35八类炮塔。旋翼机是UnitVortex，无马机是UnitDron。

## 3. 当前安装状态

- **M45 / 0.2.16-dev已部署**，110626字节，SHA `59a03d1eb3ca7d8467015c709301bc1fbe6d585342de5857e984344a33572790`，48生产类无原生存根/测试类。源与测试输入冻结build/m45/final；证据knowledge/experiments/m45-validation-evidence.json。
- 同字节10组1003 PASS/0 FAIL，正常无驱动双端冒烟`c09279cc99`通过；56项保护指纹不变，测试进程已退出。仅更新本模组release，需保存后完全重启两端。
- 旧M44备份`build/backup/m45-release-20261004-183127-3afe1d/RConnectMod.before.swf`，SHA `8b6fb844bb5295448d3a29e763378a6f3d63f111eb83dc0a5a381da49ff569ae`；复制回release并重启可回退SWF，不回滚玩家存档。未推送或对外打包。
- 同机仍用Start-Coop.bat。第二角色手动身份pfe-modsettings-rconnect-player2，首次继承旧pfe2存档/配置且保留原件，后续不重复覆盖；启动原生读档列表由玩家选角色。

## 4. 实现与当前接点

- **浮窗设计待实施**：拟常驻280×36、展开280×240，连接/队友/聊天/设置四页，拖动与四角停靠，隐藏/收起分离，未读角标与暂停原因独立。示例HTML具备状态和尺寸切换；6项静态检查含9组尺寸公式通过，浏览器file:被拒绝，不声称视觉或游戏交互通过。详见design/2026-10-05-hud-ui-plan.md及ui-preview/validation.md。
- **M46联合候选尚未部署，当前停在Aura验收**：0.2.17-dev、112519字节、49生产类，SHA256 `0f86141b7d51bfc34bf261e6abcd338de78c2b67798cc1b92b7df11d803d1280`。R2 C13与R3闪电/智能锁定真实资格的重叠已逐项合并；生产源50文件已冻结，独立生产49类无测试/原生存根链接。原会话本轮AIR已全部退出，保存检查点后交回念力源码/编译/AIR诊断窗口给R2，R3只读建议；部署与最终状态维护仍由本会话统一。原安装M45不变。
- 合并范围：Box/Loot每帧200ms源时间插值，抓持租期/松手/落地及离房交接清理；原生天角兽指针保护/冷却桥接；MirrorHitUnit真实id/npc/isVis资格且保留noBox；原生闪电帧记录与结束事件保留。既有暂停/抓敌/换图规则不变。源码审计`build/m46/source-merge-audit.json`；R2独立证据`knowledge/experiments/2026-10-06-movable-telekinesis.md`、R3`2026-10-05-lightning-smart.md`不能替代联合验收。
- **Motion已验绿，但旧失败保留**：首轮d8ea183f0c为179/2，leave后首帧Q清除缺原生前帧，根因未认定。final-3同驱动d88300c9bc为178/3，捕获pinok21.537→65.234越过原生松手阈值。final-4仅隔离夹具无关弹丸（invulner+transp），原181项时序/阈值保留，新增5项真实damage松手负向对照；57e3f54387、94364eb1ad、f6b92f575b三轮各186/0，M45同测试源码/复制档0967e8a9df为142/44且5项原生对照通过。不倒推d8与C13早期Style4原因。独立审计`motion-control-audit.json`已过。
- **Aura仍红，后续10组及部署停止**：final-4 begin的18a43bd475加入侧5像素失败；同候选/同已编译驱动换random_mane的b37e2b7e3a为95/8，武器恢复但箱子像素失败、地图原有咖啡使findLoot错选L#1，宿主持L#3。原二轮没有PNG，不能声称有截图。
- **取证与同源码C13对照**：final-5只加逐轮身份/显示链和实际PNG，不改原103项断言/时序；联合9404d939d7为92/11，C13 1ed5b50412为93/10，两端DONE。联合join round0白块覆盖Box；本体及所有祖先visible/alpha1、Stage/坐标/Glow/CT正确，C13同位置无白块并有像素。两轮均有NPC提前失持4项与咖啡错身份6项，不能都归因R3。16张/轮场景PNG和日志在对应build/cooperation目录。
- **当前诊断假设未实证**：RV按单位分别建遮罩，本体与真实资格代理共享vis，可能形成孤立白色遮罩；需确认具体Shape和受控开关。旧q=true续报的force trackBoxPos还会调用releaseEnemyCaster，可能取消新NPC，但需首次丢失前的moved.q/sampleTime/t_tele证据；不能拒绝合法新玩家抢箱。R2/R3只读建议，不写他模组，不先改生产抓握规则。
- **冻结与接续**：final原始50源/131验证；final-2字段错误在编译/AIR前发现未运行；final-3/4/5为诊断副本（132验证），候选字节始终相同。当前live验证输入匹配final-5。runner在任一端启动前备齐双方输入，保存配置/描述符/input.json；57项保护含安装版不变。真实复制档只供Motion，Aura为隔离新角色；不同随机内容以实际日志区分。
- 最新实证见`knowledge/experiments/2026-10-06-m46-joint-validation.md`与journal顶部。UI只完成规划/HTML；原生HP免疫与击退松手是两条不同路径，测试隔离未修改生产伤害。
- **M44完成**：武器快照补真实GlowFilter和root/kor目标；Box/Loot/Unit补光晕/ColorTransform，加入侧本地抓持经玩家稳定键反向送达。TelekinesisVisuals只管显示，不写levit/AI；本地抓取优先，松手/替换/换房/离线清理，保留无关滤镜。最终八阶段c59e4214a4通过；详见2026-10-04-m44-telekinesis.md。
- **M45完成**：EnemyGrip把加入侧原生抓持意图交给唯一房间模拟端，保留原版耗魔/抓取资格/挣脱；投掷只转发原版冲量一次。RoomSync交接前释放本机及远端抓持，Session停止时清理网络抓持，离线原生持有保留；M44光晕显示与实际控制保持分离。
- **可选联机暂停完成**：用户确认任一端触发全队暂停（含分房），双方都关才恢复。F10两开关默认关、宿主设置保存；菜单范围按已说明的全部原版暂停菜单实现。网络/UI/SATS排队继续，恢复后执行战斗；不以暂停阻塞房间/地图交接。
- 关Pip后的allStat残留一帧误松手已在联合测试中修复；最终抓取包含暂停位置/耗魔/挣脱计时、恢复、短持、精确投掷去重。原型失败、测试阈值修正及其他模组暂停检查分别留在2026-10-04-m45-enemy-grip.md与2026-10-04-coop-pause.md，最终同字节1003项通过。
- 三方本轮已统一合并、验证、部署；R2负责抓敌，R3负责暂停，原会话负责最终候选与门禁。后续仍串行编译/AIR，不各自覆盖release。
- **慢换图许可修复**：首次冻结ff977候选在b82c882fb0/ee5790974c连续初始换图超时。受控检查和修复详见2026-10-04-m45-travel-permit.md；最终以目的地匹配授权一次原生退出，跨过15秒仍可完成且允许Encounter本轮重定向，结束/重启/断开后不能复用旧许可。保留原45秒房间交接保护。
- **换枪光晕修复**：syncRemoteWeapon与driveWeaponVis共用同一RemoteMotion采样，避免最新武器配旧帧光晕。旧e9b候选c64816fd73宿主485帧9错；最终e2bdb8a864为102项通过，宿主485帧/加入450帧零错。原失败、开场黑幕和Timer夹具修正见2026-10-04-m45-weapon-aura-timing.md；原84断言完整保留。

- **M43背景房调查未复现、未认定根因**：用户明确宿主角色消失/无法控制，不能解释为正常跟随。最终实际存档/视野设置下，界面+跟随五轮`5fd52e55f0`117项、关闭跟随五轮`735ea3ffd7`107项通过。早期冻结玩家、缺RENDER、累计走出房、浮点尾差等测试干扰已留档；一次门时序失败未认定原因，不抹去。候选仅加最多32次背景房切换的只读诊断，未修改背景房玩法。详见2026-10-03-m43-hidden-rooms.md。
- **M43三方合并完成**：R2光束逐帧记录/死亡后结束、墙碎片；R3地图位置与主动传送。最终专项32+55项，既有分房66、反馈16、动画26、密集51项通过。80敌人连续七段、每段约8秒，加入侧每段100–107帧（约12.5–13.4 FPS），p95 104–116ms。没有同负载基线配对，不作性能增减归因；密集战斗仍可能卡顿。
- **M41完成**：镜像血条每帧按原生规则刷新与跟随，显示层重建后重挂；HP数字回归原生弹着点、暴击/持续伤害样式和10模拟帧合并窗口，只维护反馈计数不运行AI。最终41项原生对照、16项真TCP通过，普通LMG显示40且宿主扣40。专项中的单次损伤本来一致，不声称本轮修复所有伤害运算。
- **联合动画修复完成**：掉落沿宿主轨迹逐帧显示，保留武器10px偏移、本地念力/吸取接管及房间权属；肉食灵以实际帧变化补足isPlaying错误，并显式处理同帧停止/恢复与动画对象替换；蜘蛛地雷等单次死亡只播放粒子/声音，不重复伤害掉落。26项动画、24项交互、31项真网络业务通过。两端API播放标志与实际帧不一致的红绿链见动画记录。
- **M41性能边界**：80敌人持续03c66a5357的7段各约8秒，加入侧109–117帧/段（约13–15 FPS），p95 95–109ms；51项既有阈值通过，但仍有卡顿。没有同负载M40配对，不作性能增减归因；整机另有语言适配任务，不能声称独占负载。
- **M40完成，无待运行检查**：RemoteMotion按真实游戏帧采样时间保存短队列，敌人和玩家统一逐帧插值；重复发送不伪造新帧，收包不额外推进显示。初始旧帧/大时间偏移重校准，传送与长停顿重置，不无限外推。加入侧只对原生UnitZebra/UnitAlicorn保留正alpha淡影，invis/isVis/isSats保持。
- 最终平滑15、双向TCP10、画面26、战斗状态22、SATS24、合作133、分房66、弹道9、战斗网络33、持续密集51全部通过。aceb915c53中三条运动流0停顿，队友各16种身体帧、敌人24帧；隐身轮廓有最终场景像素。密集41fa69404b连续56秒每8秒133–137帧，p95 81–87ms，约16–17FPS，原门槛保留；不声称通用帧率提升。
- M40失败/夹具边界留在实验记录：旧M39抖动58次；RENDER会重复，按ENTER_FRAME去重；新档开场anim("die",true)并非死亡；internal lurked不可动态写。Appearance测试Timer可能读到绘制中间态，4e85806305显示2次中间态错误但262次最终RENDER全正确；改按最终绘制验证后完整合作61829fb49d通过、护甲136帧一致，生产护甲代码未改。
- M39合作规则保留：地面物品只有一份，由房间所有者裁定、先拾取者原生入包；开柜由所有者生成；双方武器/弹道、闪电/护盾、地雷/炮塔/狮鹫感知，F10跟随默认关；经验点双方奖励、存档点共同解锁各自保存。地图经验点在loc.bonuses、存档点在acts、Box在objs。
- M38伤害/动画修复保留：尸鬼碰撞尺寸与数值化抗性；RemoteDamageUnit + NativeHit交实际UnitPlayer结算，原生/加入/宿主LMG伤害一致、五种炮塔弹种一致。血翼AI/播放状态、炮塔展开后炮管、门柜首次立即/重复不重启动画。Box管理的VirtualUnit不进入敌人快照与重建链。
- M37 SATS沿用原生vis/hpbar及隐身/锁定资格，退役代理失效。M36 RoomSync按地图epoch/roomKey/term交接，旧房伤害/场景修改先发完；loc_t=0禁止旧房stepInvis。空房由NativeRoomState保留，交接期间暂停，优先沿用本地原生实例。跨图/挑战由TravelGuard限制，房间细则见design/separate-rooms.md。
- Windows后台策略因果证据见KB-000071 rev1与M39报告；不以重编译/后台状态不同的性能数字作代码对照。M40公共原生淡影机制见shared-knowledge/entities/facts/camouflage-render-vs-targeting.md；模组插值和测试方法记录留模组内。

## 5. 已知边界

- 只承诺当前地图、本次联机内房间保留；跨游戏退出保存沿用原版。任务/波次没有新增同步协议，挑战只允许宿主带队。
- 源码标量与简单数组可交接，特殊状态效果对象引用、Boss全部分支、第三方新增敌人和长期全组合未穷举；不声称任意原生对象图可序列化。
- 同时互换房、失联交接及全部死亡回城时序未穷举；稳定重连在排除范围。几何尺寸不一致会暂停交接并提示。
- 当前根游戏1.02；RV及其他模组具体构建按本轮输入指纹区分。保护指纹与各轮其他模组输入见证据JSON，不把旧时期版本哈希当作当前版本。
- 原有Area场景对象注入#1063后跳过仍在日志中，旧0.2.9对照也存在；M45暂停组还记录spikes/fspikes的Trap #1063，被现有重建逻辑捕获。该构造路径未在本轮修改，不把行为门禁通过解释成所有历史诊断消失；最终证据逐组保留这些日志。
- 磁盘曾不足：测试runner已只复制所需8个运行SWF及xml/cfg，启动前检查空间；已清理三个旧试验的可再生成游戏副本，日志/候选/备份保留。不得为腾空间删用户存档或其他模组。

## 6. 下一步

1. 用户查看design/ui-preview/index.html的占位与展开方式；后续按反馈实施AS3，依方案验收真实字号、输入焦点、鼠标和多语言。不把本轮设计预览自动变成生产UI部署。
2. R2接续M46念力诊断窗口：先修测试咖啡唯一身份，确认并修加入侧孤立遮罩，捕获NPC失持的首次报文/原生状态；按新输入分别对照、保留旧失败，再冻结受影响源和测试并交回本会话。Aura通过后本会话继续其余10组、整体审计与正常加载冒烟，备份后仅统一部署本模组release。R3只读建议；独立74/495项、M45门禁及UI静态检查均不计联合通过。
3. 当前已部署M45仍需重启两端生效。背景房若重现，核对两端RConnectRoomTrace与角色状态；未认定根因，不盲改。性能边界和排除范围保持，不自动推送。

## 7. 记录与工具入口

- 最新M45见 `state/deployment-m45-2026-10-04.md`、`knowledge/experiments/m45-validation-evidence.json`、抓敌与暂停两份实验记录。
- M44历史见 `state/deployment-m44-2026-10-04.md`、`knowledge/experiments/m44-validation-evidence.json`与`2026-10-04-m44-telekinesis.md`；启动器见`2026-10-04-manual-second-player.md`。
- M43历史 `state/deployment-m43-2026-10-04.md`、`knowledge/experiments/m43-validation-evidence.json`及三份M43实验记录；历史 `knowledge/experiments/2026-10-03-m41-feedback.md`、`2026-10-03-m41-animation-gaps.md`、`m41-validation-evidence.json`；M40连续运动与淡影见2026-10-03-m40-presentation.md。M39合作与后台策略见2026-09-30-m39-gameplay.md；M38伤害、M37 SATS、M36分房历史证据和design/separate-rooms.md保留。
- 构建 `tools/build_mod.py --java <java> --output build/<轮次>/RConnectMod.swf`；必须显式候选输出，默认写release。
- 同字节外部驱动 `tools/build_effects_driver.py --candidate <正式SWF> --java <java> --output build/<轮次>/driver --entry SatsTestDoc`。另可RoomCooperationTestDoc/CoopTestDoc/TurretTestDoc/EffectsTerrainTestDoc/PresentationTestDoc。
- runner `tools/run_coop_regression.py --candidate <SWF> --effects-driver <目录>`：分房加`--effects --all-mods --land random_mane --seconds 240`，完整合作`--with-vision --seconds 340`，炮塔/特效`--effects --all-mods --seconds 180`，画面`--presentation --all-mods --seconds 210`。正常路径不加driver，用`--smoke --with-vision --seconds 150`。
- Python C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe；Java C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe；SDK D:/RemainsMod/mods/Sandevistan/build/tools/flexsdk。AIR/FFDec沙箱受限走正常工具审核。
- 性能及同机双端使用runner --responsive（同Start-Coop的helper），SustainedDensityTestDoc连续7段；启动函数回归tests/windows/VerifyCoopLauncher.ps1需要--keep-copies保留的隔离模板。旧tools/make_release.py仍是0.1.0整包脚本，本轮未运行；以后分发前需更新包清单纳入启动器，不能当作本轮发布工具。
