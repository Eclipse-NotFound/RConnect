# RConnect —— 开发记忆入口

> 协议见 GOVERNANCE.md §8；参数与边界见 ../AGENT_SCOPE.md。

## 1. 模组定位

双人合作：各自角色进入同一世界。同房由宿主结算，普通房分头时各端运行所在房的原生战斗。RoomSync交接空房与汇合状态，玩家约20Hz、敌人和场景约5Hz、显示逐帧推进。入口RConnectMod.init(main)，AIR/amxmlc，swf-version=38。

## 2. 用户偏好与最新决定

- 已授权修复已有合作探索/战斗/交互，允许大幅重构和候选部署。不新增任务/背包/交易规则，排除稳定重连、三人以上、公网和其他版本。
- 此前炮塔显示与分房请求点名grilling，Q1–Q5全部确认“符合，按此实现”：同地图普通房自由分头；空房暂停保留；宿主发起共同换图；剧情挑战共同进出；关闭游戏沿用原版，不新增随机房完整战斗存档。不得重复确认。
- 最新反馈加入侧SATS/getUnits #1009；已完成M37修复、验证和候选部署，无需重复确认修复/测试/部署授权。
- 只写RConnect；其他模组仅最小必要读取。测试隔离新角色和唯一AIR标识，只结束自己创建的进程；全部输入在任一端启动前冻结。用户进程和存档不动。
- 保留M31共享探索、M32轻机枪/天角兽伤害与不同护甲、M33动作平滑、M34开火/机械死亡/破墙、M35八类炮塔。旋翼机是UnitVortex，无马机是UnitDron。

## 3. 当前安装状态

- M37 / **0.2.9-dev已部署并通过正常路径冒烟**，76715字节，SHA256 `7f8e65ff7cb617894253ec908a7bfc6e61ada9b273d6549dc4a7f3846f499432`。
- 同一正式字节共247 PASS/0 FAIL：SATS e7537480f5（24），完整合作f8df825ae5（131），分房1e614a79fa（66），画面42db1a0cda（26）。SATS/分房/画面加载当前全模组，完整合作RC+RV。
- 正式包28类，仅模组和三个RConnect同包访问器，无原生存根或测试入口。外部测试驱动不部署。
- 旧M36/0.2.8备份 `build/backup/m37-release-20260927-201937-320917/RConnectMod.before.swf`，SHA `0e808f082e30fe00444f4534ff67b9eca312a35e2921837022c3d5f474301925`。只复制回RConnect release并重启可回滚，不替换根游戏SWF。
- 部署回执 `build/m37/deployment.json`为deployed-smoke-passed，83d542142e正常路径双端0.2.9初始化/连接/房间协议/tick200通过。保护文件部署前后及最终一致，仅替换本模组release。没有发布远程安装包。

## 4. 实现与当前接点

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
- 当前根游戏1.02、RV0.30。保护指纹与各轮其他模组输入见证据JSON，不把旧时期版本哈希当作当前版本。
- 磁盘曾不足：测试runner已只复制所需8个运行SWF及xml/cfg，启动前检查空间；已清理三个旧试验的可再生成游戏副本，日志/候选/备份保留。不得为腾空间删用户存档或其他模组。

## 6. 下一步

1. 用户双方完全退出并重启，按F10核对0.2.9-dev，测试加入侧实际战斗中的SATS选敌和射击。
2. 按反馈推进，不扩大排除范围。中断期间仓库历史及英文README已由外部更新；本轮基线fae082b，保留双语文档，不改写历史，不自动推送。

## 7. 记录与工具入口

- 最新 `knowledge/experiments/2026-09-27-m37-sats.md`、`m37-validation-evidence.json`。M36分房报告/evidence及design/separate-rooms.md保留。公共SATS图像契约见shared-knowledge/ui-systems/facts/sats-unit-visual-contract.md。
- 构建 `tools/build_mod.py --java <java> --output build/<轮次>/RConnectMod.swf`；必须显式候选输出，默认写release。
- 同字节外部驱动 `tools/build_effects_driver.py --candidate <正式SWF> --java <java> --output build/<轮次>/driver --entry SatsTestDoc`。另可RoomCooperationTestDoc/CoopTestDoc/TurretTestDoc/EffectsTerrainTestDoc/PresentationTestDoc。
- runner `tools/run_coop_regression.py --candidate <SWF> --effects-driver <目录>`：分房加`--effects --all-mods --land random_mane --seconds 240`，完整合作`--with-vision --seconds 340`，炮塔/特效`--effects --all-mods --seconds 180`，画面`--presentation --all-mods --seconds 210`。正常路径不加driver，用`--smoke --with-vision --seconds 150`。
- Python C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe；Java C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe；SDK D:/RemainsMod/mods/Sandevistan/build/tools/flexsdk。AIR/FFDec沙箱受限走正常工具审核。
