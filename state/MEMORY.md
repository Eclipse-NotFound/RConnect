# RConnect —— 开发记忆入口

> 协议见 GOVERNANCE.md §8；参数与边界见 ../AGENT_SCOPE.md。

## 1. 模组定位

双人合作：各自角色进入同一世界。同房由宿主结算，普通房分头时各端运行所在房的原生战斗。RoomSync交接空房与汇合状态，玩家约20Hz、敌人和场景约5Hz、显示逐帧推进。入口RConnectMod.init(main)，AIR/amxmlc，swf-version=38。

## 2. 用户偏好与最新决定

- 已授权修复已有合作探索/战斗/交互，允许大幅重构和候选部署。不新增任务/背包/交易规则，排除稳定重连、三人以上、公网和其他版本。
- 此前炮塔显示与分房请求点名grilling，Q1–Q5全部确认“符合，按此实现”：同地图普通房自由分头；空房暂停保留；宿主发起共同换图；剧情挑战共同进出；关闭游戏沿用原版，不新增随机房完整战斗存档。不得重复确认。
- M39九项反馈：密集敌人卡顿，炮塔/地雷/狮鹫索敌，容器掉落与拾取，跟随队友，闪电/双方开火/天角兽护盾，经验点与存档点。用户确认：地上物品一份，先拾取者获得；经验点双方奖励；存档点共同解锁，各自保存角色。继续既定修复/候选部署授权。
- 最新M40反馈是加入侧敌人和双方队友动作仍卡、加入侧看不到隐身斑马/天角兽的淡影；本轮修复与候选部署已完成，继续按实际游玩反馈定位，不重复确认既有范围。
- 只写RConnect；其他模组仅最小必要读取。测试隔离新角色和唯一AIR标识，只结束自己创建的进程；全部输入在任一端启动前冻结。用户进程和存档不动。
- 保留M31共享探索、M32轻机枪/天角兽伤害与不同护甲、M33动作平滑、M34开火/机械死亡/破墙、M35八类炮塔。旋翼机是UnitVortex，无马机是UnitDron。

## 3. 当前安装状态

- **M40 / 0.2.12-dev已部署并通过正常加载冒烟（2026-10-03）**，88270字节，SHA256 `0ea90fefda48aa50ba8f0a273c47594af28e8d86a04094767d810d21c359786c`。37生产类，无原生存根/测试类；build/m40/final2/source-input.json冻结源码。仓库master，本轮基线c48a8dc。
- 最终同字节10组389 PASS/0 FAIL；`knowledge/experiments/m40-validation-evidence.json`保留全部输入和历史失败。部署后正常路径、无外部驱动双端冒烟5ce0edab7a通过。54项游戏/其他模组/配置保护指纹不变。
- 旧M39备份`build/backup/m40-release-20261003-074022-034234/RConnectMod.before.swf`，SHA `42d10ea384ce1b731ad4515359ba941a511a83bb67401cf8f5ce70e01c15411d`；复制回本模组release并重启双端可回滚。回执build/m40/deployment.json为deployed-smoke-passed，未发布远程包。
- **同机双人使用Start-Coop.bat**：保存关闭原窗口再启动两端。它仅将自己新建的游戏进程设为HighQoS，防止后台降速；不改电源计划/注册表/亲和性/优先级。主pfe和第二pfe2各自保存；旧second_player不再覆盖存档或结束已有进程。可能增加耗电，退出后结束。M39真实启动入口launcher-1f523a5b4e已验证，本轮未改启动器。

## 4. 实现与当前接点

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
- 原有Area场景对象注入#1063后跳过仍在日志中，旧0.2.9对照也存在；M38未修改此构造路径，不把行为门禁通过解释成所有历史诊断消失。
- 磁盘曾不足：测试runner已只复制所需8个运行SWF及xml/cfg，启动前检查空间；已清理三个旧试验的可再生成游戏副本，日志/候选/备份保留。不得为腾空间删用户存档或其他模组。

## 6. 下一步

1. 用户保存关闭双方游戏，使用Start-Coop.bat重开，F10核对0.2.12-dev；重点观察加入端敌人和双方队友的连续动作，以及隐身斑马/天角兽淡影。
2. 新反馈按实际角色、敌人/武器和房间定位；本轮80敌人持续约16–17FPS，继续优化需同一进程策略和相同输入对照，避免把后台节能误判为代码退化。
3. 已完成部署与本任务测试实例清理，未使用门禁豁免。既定排除范围不变，不自动推送。

## 7. 记录与工具入口

- 最新 `knowledge/experiments/2026-10-03-m40-presentation.md`、`m40-validation-evidence.json`。M39合作与后台策略见2026-09-30-m39-gameplay.md；M38伤害、M37 SATS、M36分房历史证据和design/separate-rooms.md保留。
- 构建 `tools/build_mod.py --java <java> --output build/<轮次>/RConnectMod.swf`；必须显式候选输出，默认写release。
- 同字节外部驱动 `tools/build_effects_driver.py --candidate <正式SWF> --java <java> --output build/<轮次>/driver --entry SatsTestDoc`。另可RoomCooperationTestDoc/CoopTestDoc/TurretTestDoc/EffectsTerrainTestDoc/PresentationTestDoc。
- runner `tools/run_coop_regression.py --candidate <SWF> --effects-driver <目录>`：分房加`--effects --all-mods --land random_mane --seconds 240`，完整合作`--with-vision --seconds 340`，炮塔/特效`--effects --all-mods --seconds 180`，画面`--presentation --all-mods --seconds 210`。正常路径不加driver，用`--smoke --with-vision --seconds 150`。
- Python C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe；Java C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe；SDK D:/RemainsMod/mods/Sandevistan/build/tools/flexsdk。AIR/FFDec沙箱受限走正常工具审核。
- 性能及同机双端使用runner --responsive（同Start-Coop的helper），SustainedDensityTestDoc连续7段；启动函数回归tests/windows/VerifyCoopLauncher.ps1需要--keep-copies保留的隔离模板。旧tools/make_release.py仍是0.1.0整包脚本，本轮未运行；以后分发前需更新包清单纳入启动器，不能当作本轮发布工具。
