# RConnect —— 开发记忆入口

> 协议见 GOVERNANCE.md §8；参数与边界见 ../AGENT_SCOPE.md。

## 1. 模组定位

双人合作：加入者以自己的角色进入宿主世界，宿主结算敌人、伤害和场景，加入者上报行为并接收镜像。玩家约20Hz、敌人与场景约5Hz，位置与动画逐帧推进；共享探索变化行最快100ms、三秒全量补齐。入口RConnectMod.init(main)，AIR/amxmlc，swf-version=38。

## 2. 用户偏好与最新决定

- 已授权补齐已有合作探索/战斗/交互，允许大幅重构和候选部署。排除稳定重连、三人以上、公网、其他版本；不新增任务/背包/交易规则。
- 最新请求：加入侧炮塔不显示；希望双方在不同房间行动，点名grilling。**Q1已选同一地图内分房，跨地图共同旅程。**
- **仍待用户答复：Q2空房暂停保留进度还是原版重置；Q3只有宿主发起共同换图还是任一方；Q4普通房可分头、剧情挑战共同进入，还是扩大到任务/挑战同步。** 推荐前者。不要把等待当作推荐获准；回答后概括具体方案确认共同理解，再实施新功能。
- 炮塔修复属于既定故障修复独立完成；分房仅调查，尚未实现。design/separate-rooms.md保存调查与下一轮决策前沿，不是已批准设计。
- 只写RConnect；其他模组仅冲突定位及测试输入读取。用户存档/进程和游戏SWF不动。测试独立新角色、唯一应用标识，只结束本次创建的PID；所有输入在任一端启动前统一冻结。
- 保留M31双向探索、M32轻机枪/天角兽伤害与双方不同护甲、M33动作平滑、M34开火/机械死亡/破墙。旋翼机是UnitVortex，无马机是UnitDron。

## 3. 当前安装状态

- **M35 / 0.2.7-dev已部署**，58331字节，SHA256 `adfb72c5d2bce6a77b889759f63e7d9b4ceea02aafb57174fdb8e8e224685562`。
- 同正式字节、全模组：f65b37faef炮塔 **60 PASS/0 FAIL**；d45d24de9b特效/破墙 **27 PASS/0 FAIL**；a9138d5ff1画面 **26 PASS/0 FAIL**。三组共113项。正常加载路径677c0fd628（RC+RV、无包装器）双端初始化/连接/tick200通过。
- 新TurretDisplay：正确底座构造，宿主展开/收起状态、炮口/灯/晃动、内嵌开火动画。旧版构造参数错误和隐藏型始终收起已复现；frozen animate不再依赖本地AI决定展开。不调用本地射击或重复生成子弹。
- 正式包21类，无测试/游戏存根。外部驱动仅TurretTestDoc一类；新增可选入口也支持PresentationTestDoc，运行直接引用生产候选。
- 部署回执 `build/m35/deployment.json` 为deployed-smoke-passed，保护文件最终指纹一致。旧0.2.6备份 `build/backup/m35-release-20260924-071111-362542/RConnectMod.before.swf`，SHA `cab160ba…5f549b86`。仅复制回RConnect release并重启可回滚；勿恢复旧根SWF覆盖他人loader。

## 4. 分房调查接点（未实装）

- 拉回来自Session每次unitsync调用followHostWorld→同图异房Land.gotoXY。还有每房首次300px距离对齐；不能只删跟随分支。
- 伤害/门箱/掉落/地形都被sameHostRoom限制。原生单World只完整推进当前房；不能遍历多个Location.step（会复用本体玩家、视线和奖励）。
- 候选结构：各端运行所在房，宿主RoomRecord保存归属/世代/完整状态；合流前冻结并确认交接，同房宿主结算。需逐帧换房保护并抑制前一房stepInvis。
- Location无完整save/load；Unit/Box.save不保战斗数值。reactivate→setNull(true)可回血回甲回出生点；随机Land.saveObjs不保存这些状态。
- 显示傀儡难度固定100且doop/unres，不能直接解冻。准确运行数据和原生构造是实现前提；Unit.mapxml/aiState为internal，同包访问器方案尚未验证。
- 房间身份包含地图生成世代、landProb、X/Y/Z；挑战可能全部loc0_0。全部包特别playerdmg需房间及归属世代。完整units=[]需真的清空；每房身份/地形/掉落表不能enter即清。
- 剧情/挑战有Unit.runScript、任务和波次，超出现有协议，故Q4待用户决定。原生固定图code状态及随机图跨退出保存须明确边界。

## 5. 验证边界

- 本版仍同房合作，分房不在113项通过范围。等待上述玩法答复；不要重复启动探查、重新问已定Q1或自行选择分支。
- 当前根游戏1.02、manifest loader v2；配套RV0.30。八类原生炮塔已验，特殊第三方派生类/全部武器/长期全组合/其他版本未穷举。
- M34受击器普通Unit规则、Boss特殊伤害覆写和专属死亡未全覆盖；地形初始生成严重不同和连接前损坏基线仍有边界。近身补发现保留原生墙/朝向/隐身判断。
- M35失败41bfb35d39是测试访问internal字段；92d28b41ee是测试宿主展开后未持续animate。真实旧版红测f030c6fc6d为39 PASS/9 FAIL；两类失败不能混称游戏故障。
- 历史完整合作M34 b63258d97b为131 PASS/0 FAIL；本轮未重跑完整合作，不把历史结果称为M35新测试。

## 6. 下一步

1. 用户双方正常完全重启，确认0.2.7-dev并测试实际地图炮塔。
2. 接收Q2/Q3/Q4，按grilling完成共同理解确认；不再请求已经授权的构建/修复/候选部署许可。
3. 实现分房时先准确房态/归属交接，再解除持续跟随；测试双房同时战斗、加入侧独房操作后汇合、交换房间、迟到包、空房重访、地图世代和保存边界。

## 7. 记录与工具入口

- 本轮 `knowledge/experiments/2026-09-24-m35-turrets.md`、`m35-validation-evidence.json`；分房 `design/separate-rooms.md`。
- M34 `knowledge/experiments/2026-09-23-m34-effects-terrain.md`；M33/M32旧报告及M31 docs/shared-exploration.md。正式字节驱动方法KB-000061r1已记录，不重复建卡。
- 构建 `tools/build_mod.py --java <java> --output build/<轮次>/RConnectMod.swf`；必须显式候选输出，默认会写release。
- 外部驱动 `tools/build_effects_driver.py --candidate <正式SWF> --java <java> --output build/<轮次>/driver --entry TurretTestDoc`（默认EffectsTerrainTestDoc，另可PresentationTestDoc）。
- 运行 `tools/run_coop_regression.py --candidate <SWF> --effects-driver <目录> --effects --all-mods --seconds 180`；画面换成--presentation、210秒；正常路径--smoke --with-vision --seconds 150。每端生产/驱动/包装器哈希应相同，包装器不部署。
- Python C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe；Java C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe；SDK D:/RemainsMod/mods/Sandevistan/build/tools/flexsdk。AIR/FFDec沙箱受限时走工具审核。
