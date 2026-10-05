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
- **本日联合修复准备，尚未部署**：R3已交付闪电原生轨迹/结束保留与真实敌人锁定资格补丁；本会话核对冻结源码、候选和日志指纹，B专项27＋光束23＋SATS24项通过，只覆盖其独立产物。R2真实存档同夹具对照已完成：M45 ace3667797为74 PASS/15 FAIL；仅念力C5 71e0740d59为83 PASS/6 FAIL，尚未验绿。C5修正掉落物持续静止与挣脱阈值，但松手响应、落地及部分低帧率采样检查仍FAIL；编译/AIR窗口归R2。既有三方授权由本会话统一合并、门禁、部署，不改UI。联合准备与M45安装基线在build/m46，未构建联合候选。
- 已向R2提出原生天角兽levit=2持箱与远端抢夺的位置控制竞争风险，尚未复现。R3红外识别按原生类名匹配的特殊分支未覆盖；不得把普通可见目标通过解释成完整兼容。交付细节见knowledge/experiments/2026-10-05-lightning-smart.md；失败记录保留。
- R2 C11（f13fe768…/112269字节）19817e0dfb动作/生命周期176项首绿，M45同驱动c960697dc1已核对130 PASS/46 FAIL；但C11 Aura回归1d792dc4a2为98 PASS/4 FAIL，**C11不能作为最终候选**。新失败为加入侧round2武器换色25/31帧与round3天角兽持箱颜色/染色/像素。R2保留并加源端持续指针断言做旧版对照，再修较晚Q释放覆盖新native levit2/敌方指针的交接竞态；窗口仍归R2，联合候选未构建。
- 本会话已提示旧释放、旧Box缓动及remotelyHeldObject视觉回调都需保护新的真实敌方指针；presentHeldVisuals先于tickBoxTweens，旧tween.q会让旧玩家光晕继续覆盖新NPC。保护只按房间模拟端真实指针，不能用镜像残留指针拒绝权威快照，也不能拦住真正新Q抢敌方箱子。换色失败先与旧版同夹具区分，不改阈值；C10的偶发退出Q丢失仍未归因，原失败保留。
- R2 C12（89dd544b…/112361字节）已编译未验绿；C11加强Aura 9988740d17已核对99 PASS/4 FAIL，源端held=true但levit0/glow=null。本会话读到C12保护旧释放与缓动、RENDER先清缓动后画光晕，但onMirrorFrame的ENTER_FRAME入口仍先presentHeldVisuals，回调未直接排除新NPC指针，仍可能提前覆色；已要求核对冻结源码并另冻修改，尚未实测C12失败。当前先跑M45 Aura同输入对照，窗口归R2。
- RemoteLoot着地stay已随位置进入同一RemoteMotion样本，C9原失败保留。活动远端Box使用levit1与原生天角兽指针/冷却桥接，旧纯光晕断言已明确改为实际抓持契约。退出Q根因尚未认定：Session/RoomSync退出不直接走hold，原生actions会检查celDist/teleDist、魔力与levitPoss；endSession还会恢复敌人disabled，已提示R2保留诊断并与旧版区分，不能为保Q绕过原生资格。
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
2. 等R2交付最终冻结输入、原版/候选同夹具对照及释放测试窗口，核对实际敌方持物与原生着地证据、活动Box标志清理和长暂停；再冻结联合源码与测试输入、构建并跑受影响回归及正常加载冒烟后统一部署。R3独立74项、旧M45门禁及UI静态检查均不计联合产物通过。
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
