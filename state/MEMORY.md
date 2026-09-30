# RConnect —— 开发记忆入口

> 协议见 GOVERNANCE.md §8；参数与边界见 ../AGENT_SCOPE.md。

## 1. 模组定位

双人合作：各自角色进入同一世界。同房由宿主结算，普通房分头时各端运行所在房的原生战斗。RoomSync交接空房与汇合状态，玩家约20Hz、敌人和场景约5Hz、显示逐帧推进。入口RConnectMod.init(main)，AIR/amxmlc，swf-version=38。

## 2. 用户偏好与最新决定

- 已授权修复已有合作探索/战斗/交互，允许大幅重构和候选部署。不新增任务/背包/交易规则，排除稳定重连、三人以上、公网和其他版本。
- 此前炮塔显示与分房请求点名grilling，Q1–Q5全部确认“符合，按此实现”：同地图普通房自由分头；空房暂停保留；宿主发起共同换图；剧情挑战共同进出；关闭游戏沿用原版，不新增随机房完整战斗存档。不得重复确认。
- 最新M39九项反馈：密集敌人卡顿，炮塔/地雷/狮鹫索敌，容器掉落与拾取，跟随队友，闪电/双方开火/天角兽护盾，经验点与存档点。用户确认：地上物品一份，先拾取者获得；经验点双方奖励；存档点共同解锁，各自保存角色。继续既定修复/候选部署授权。
- 只写RConnect；其他模组仅最小必要读取。测试隔离新角色和唯一AIR标识，只结束自己创建的进程；全部输入在任一端启动前冻结。用户进程和存档不动。
- 保留M31共享探索、M32轻机枪/天角兽伤害与不同护甲、M33动作平滑、M34开火/机械死亡/破墙、M35八类炮塔。旋翼机是UnitVortex，无马机是UnitDron。

## 3. 当前安装状态

- **M39 / 0.2.11-dev已部署并通过正常加载冒烟（2026-10-01）**，87440字节，SHA256 `42d10ea384ce1b731ad4515359ba941a511a83bb67401cf8f5ce70e01c15411d`。37生产类，无存根/测试类；build/m39/final/source-input.json冻结源码。
- 最终同字节13组517 PASS/0 FAIL，证据`knowledge/experiments/m39-validation-evidence.json`；真实启动入口launcher-1f523a5b4e和部署后无驱动双端冒烟049f83595f通过。52项游戏/其他模组/配置保护指纹不变。
- 旧M38备份`build/backup/m39-release-20261001-020127-723248/RConnectMod.before.swf`，SHA `c6c4e97848ae5fe3e456057316a2b839b22fa9bc98c11c6eeffbeeced6c2f005`；仅复制回RConnect release并重启双端可回滚。回执build/m39/deployment.json为deployed-smoke-passed，未发布远程包。
- **同机双人使用Start-Coop.bat**：保存关闭原窗口再启动两端。它仅将自己新建的游戏进程设为HighQoS，防止后台降速；不改电源计划/注册表/亲和性/优先级。主pfe和第二pfe2各自保存；旧second_player不再覆盖存档或结束已有进程。可能增加耗电，退出后结束。

## 4. 实现与当前接点

- M39九项反馈的实现与候选验证完成：单份掉落由所有者裁定、真实原生入包；开柜由所有者生成；双方武器/弹道、天角兽闪电/护盾、地雷activateTrap、炮塔/狮鹫原生感知；F10跟随默认关；经验点共享、存档点共享解锁各自保存。
- Windows持续测试的后台策略经验已回流共享知识KB-000071 revision 1；原区保留全部运行记录，无重复公共正文。
- GroundItemState修复Item第四参数应为变体而非耐久、save漏multHP/shpun，owner回执入包实际耐久222且去重。Raider新发现远端后先自然findCel再巡逻，三次自然攻击通过；停止姿态先blit再放独立手臂，暗房连续15帧无缺失。
- 性能：移除重复EXIT_FRAME显示处理；不使用失败的本体缓存。29237459b8原策略57帧/8s→HighQoS124/120→恢复60，固定计算38ms→19/23→38，确认本机后台策略为后半段骤降原因。固定快核心及显隐窗口均不足，失败证据保留。
- 正式启动器相同策略：72853a34e1原密集门禁33通过（121帧/8s，p95 96ms）；d8619f757d持续56秒51通过（117–127帧/8s，p95 86–98ms），全部原阈值保留。**约15FPS，不承诺任意大规模战斗满帧；SWF单独不能设置Windows策略。**
- 其余最终11组433项通过：GameplayGap 7681a4add4/24、Presentation f75dcd4048/26、GameplayNetwork c4041c1d55/31、CombatState 53b3fb75fa/22、Turret d89206ce0f/60、EffectsTerrain 64e5283eff/29、SATS ea26855383/24、Coop ae3c3ef6a4/132、Room 3ecb649b06/66、Projectile bb143b3e3a/9、Follow 5123a494d1/10。夹具失效/早退漏断言的历史红灯保留。
- 地图经验点在loc.bonuses、存档点在acts，Box在objs；随机经验点按owner数组槽位/位置同步并维护saves/uidObjs。详见M39实验记录。缓存/固定计算原型已移入build/m39/debug，持续负载和Windows启动检查保留为测试。

- **M38完成主要修复（2026-09-28）**：尸鬼scY=0及抗性XMLList跨JSON失效；现同步碰撞尺寸并数值化vulner/begvulner。真实TCP轻机枪原生/加入/宿主45一致，只结算一次。
- RemoteDamageUnit捕获原始命中，NativeHit保留弹体/武器参数，由实际UnitPlayer计算；五种炮塔弹种52/22/7/52/22与原生一致。保留直接HP变化的旧兜底；特殊反伤对象上下文未穷举。
- RConnectAnimationAccess同步原生AI与播放状态、逐帧推进显示，房间恢复也恢复姿态；血翼fly与接管控制通过。炮塔保持专门显示路径，展开第1帧等待炮管子画面就绪再更新，避免被捕获#1009；武器角度/位置逐帧插值。
- 场景机关VirtualUnit保持由原生Box管理；不进入敌人快照或重建绘制链。f18a1d8964精确复现旧#1009，最终新增5项检查保留对象身份、owner与伤害类型过滤。
- 门柜首次快照立即应用；本地操作保留至宿主确认，重复快照不重启动画。loot=1/2统一为已搜刮；open=1同时确认原生自动解锁，防止省略lock字段产生持续上报。
- 同步改为真实经过时间调度，防止AIR合并回调把4次计数延长到500ms；显示重入保护减少重复扫描。80敌人整体仍低帧；本任务外AIR实例未干预，帧数不是隔离性能基准。不能宣称大规模战斗已完全流畅。
- 最终候选`build/m38/final5/RConnectMod.swf`，外部驱动`build/m38/final5-*`；脚本`build/m38/run_final.py`、`evidence_and_deploy.py`。历史失败均保留于M38报告：loot=1、SATS早采样、生命周期替身缺接口、护甲测试互扰和开门解锁确认遗漏。最终原断言全部通过。
- 公共机制已归档`shared-knowledge/entities/facts/unit-vulnerability-serialization.md`及`shared-knowledge/world-objects/facts/box-virtual-unit-ownership.md`。本轮不修改游戏SWF、其他模组、用户配置或存档；所有本任务测试实例已结束。

- **M37完成（2026-09-27）**：95d1afef99在旧0.2.8准确复现原生堆栈，原因是受击代理vis为空；仅补图bf8f801f9d通过。MirrorHitUnit借用本体vis/hpbar，同步名称/等级/隐身/护甲最大值与SATS资格，缺图不参选；GameBridge view同步isSats。退役代理标sost=4并释放引用，不能复活或伤害本体。没有开启镜像AI或复制显示对象。
- e7537480f5通过原生按键、悬停、攻击入队与UnitPlayer/Weapon/Bullet真实步进：轻机枪弹90→84，双方hp2000→1948，AP消耗；25次开关、隐身/禁选、空图与房间交接后目标清理通过。实际分房和既有战斗/画面回归另行通过。报告knowledge/experiments/2026-09-27-m37-sats.md。
- RoomSync按地图epoch/roomKey/term管理归属；帧前后暂停交接，先发完旧房伤害/场景修改，再采集完整房态，双方确认后继续。loc_t=0禁止旧房stepInvis；同图普通房建立协议后停止强制跟随。
- NativeRoomState与同包Unit/Interact访问器保存原生构造XML、AI/武器/奖值/交互计时标量；完整瓦片、掉落与按房对象键。优先保留本地原生实例，跨端接管按真实难度重建。UnitTrap需null cid；隐藏炮塔需保存hidden与正确底座。
- TravelGuard在CLICK捕获阶段拦截地图/返回卷轴，跨图/挑战/脚本交互action=0；t_exit兜底，死亡恢复例外。宿主换层增加epoch；挑战进出全队同房。加入侧抑制入口脚本/波次；本地未建挑战按原生buildProb补建。
- TerrainSync.finishReports用于交接，发完在途批次之后的全部剩余墙体伤害，不等待穿越交接屏障的回执；日常场景扫描5Hz、伤害20Hz。
- 本轮代码、验证和部署完成，测试进程均已结束，下一步是用户实际游玩反馈。正常路径直接加载release，无测试包装器；证据与部署回执已更新。
- 中间失败与夹具修正均见M36报告：随机挑战缺失、UnitTrap参数、旧测试roomEpoch、动画采样共享夹具；不得删失败或称所有历史试验都通过。

## 5. 已知边界

- 只承诺当前地图、本次联机内房间保留；跨游戏退出保存沿用原版。任务/波次没有新增同步协议，挑战只允许宿主带队。
- 源码标量与简单数组可交接，特殊状态效果对象引用、Boss全部分支、第三方新增敌人和长期全组合未穷举；不声称任意原生对象图可序列化。
- 同时互换房、失联交接及全部死亡回城时序未穷举；稳定重连在排除范围。几何尺寸不一致会暂停交接并提示。
- 当前根游戏1.02；RV及其他模组具体构建按本轮输入指纹区分。保护指纹与各轮其他模组输入见证据JSON，不把旧时期版本哈希当作当前版本。
- 原有Area场景对象注入#1063后跳过仍在日志中，旧0.2.9对照也存在；M38未修改此构造路径，不把行为门禁通过解释成所有历史诊断消失。
- 磁盘曾不足：测试runner已只复制所需8个运行SWF及xml/cfg，启动前检查空间；已清理三个旧试验的可再生成游戏副本，日志/候选/备份保留。不得为腾空间删用户存档或其他模组。

## 6. 下一步

1. 用户保存关闭双方游戏，使用Start-Coop.bat重开，F10核对0.2.11-dev；重点实测九项原反馈和各自保存/拾取归属。
2. 新反馈按实际角色、敌人/武器和房间定位；密集80敌人约15FPS，继续优化需同一进程策略和相同输入对照，避免把后台节能误判为代码退化。
3. 门禁红灯时提出的“先发布功能版本”问题已被完整绿灯消解，未得到也未使用豁免授权。既定排除范围不变。M39基线ddf55e7，不自动推送。

## 7. 记录与工具入口

- 最新 `knowledge/experiments/2026-09-30-m39-gameplay.md`、`m39-validation-evidence.json`；已部署M38为2026-09-27-m38-combat-state.md与m38-validation-evidence.json。历史M37 SATS、M36分房证据和design/separate-rooms.md保留。
- 构建 `tools/build_mod.py --java <java> --output build/<轮次>/RConnectMod.swf`；必须显式候选输出，默认写release。
- 同字节外部驱动 `tools/build_effects_driver.py --candidate <正式SWF> --java <java> --output build/<轮次>/driver --entry SatsTestDoc`。另可RoomCooperationTestDoc/CoopTestDoc/TurretTestDoc/EffectsTerrainTestDoc/PresentationTestDoc。
- runner `tools/run_coop_regression.py --candidate <SWF> --effects-driver <目录>`：分房加`--effects --all-mods --land random_mane --seconds 240`，完整合作`--with-vision --seconds 340`，炮塔/特效`--effects --all-mods --seconds 180`，画面`--presentation --all-mods --seconds 210`。正常路径不加driver，用`--smoke --with-vision --seconds 150`。
- Python C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe；Java C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe；SDK D:/RemainsMod/mods/Sandevistan/build/tools/flexsdk。AIR/FFDec沙箱受限走正常工具审核。
- M39性能使用runner --responsive（同Start-Coop的helper），SustainedDensityTestDoc连续7段；启动函数回归tests/windows/VerifyCoopLauncher.ps1需要--keep-copies保留的隔离模板。旧tools/make_release.py仍是0.1.0整包脚本，本轮未运行；以后分发前需更新包清单纳入启动器，不能当作本轮发布工具。
