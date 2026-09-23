# RConnect —— 开发记忆入口

> 协议见 GOVERNANCE.md §8；参数与边界见 ../AGENT_SCOPE.md。

## 1. 这个模组是什么

双人合作：加入者以自己的角色进入宿主世界，宿主结算敌人、伤害和场景，加入者上报行为并接收镜像。玩家约20Hz、敌人与场景约5Hz，位置与动画逐帧推进；共享探索变化行最快100ms、三秒全量补齐。入口 RConnectMod.init(main)，AIR/amxmlc，swf-version=38。

## 2. 用户偏好与协作约定

- 已授权补齐已有合作探索、战斗、交互，允许大幅重构并部署候选。排除稳定重连、三人以上、真实网络、其他版本；不新增任务/背包/交易规则。
- 最新反馈：敌人不开火动画、旋翼机无死亡动画、加入侧枪械破墙不同步且墙后敌人不显示。旋翼机原生 id=vortex / UnitVortex，UnitDron 是无马机，不能混称。
- 前轮反馈本机流畅，对方动作/共享视野跳，加入侧贴近宿主仍无敌人；武器为轻机枪打天角兽。M31 探索、M32 伤害/护甲、M33 动态显示修复须保留。
- 本轮只写 RConnect；其他模组仅必要的冲突定位和测试复制读取。用户存档、进程和根游戏不动。独立新角色、随机应用标识，只结束本轮创建的 PID。
- 两端所有输入必须启动前统一冻结，避免别的模组同期部署造成测试双方版本不同。共享探索保持双方独立接收开关、关闭后保留；RV 可选，不授予额外交互/看穿机制。

## 3. 当前状态

- **M34 / 0.2.6-dev 已部署**，57505 字节，SHA256 `cab160ba34ce7c2bedc84c68b9f85a2900811c426b4aeb523a0aa3cf5f549b86`。正式路径重启 **07638f0926 PASS**：双方新版初始化、连接、tick200/单位同步。受保护文件前后指纹一致。
- **直接正式字节、全模组专项 ded0968377：27 PASS / 0 FAIL**。原生枪械开火帧、无额外本地子弹、UnitVortex/UnitDron 死亡及重复快照不重播、加入侧 Bullet 破墙→宿主 native hitTile→回执收敛。墙后敌人实际场景像素2154。
- **RC+RV 完整合作 b63258d97b：131 PASS / 0 FAIL**；轻机枪/天角兽护盾与HP、双方不同护甲、门箱、探索、死亡和退出清理保留。
- **全模组 M33 画面回归 74fbb372df：26 PASS / 0 FAIL**。三敌人实际视口可见、连续15个最终绘制帧缺失0；双方包间7个不同位置/动画帧，停止帧保持，探索差分通过。不是任意负载帧率承诺。
- 新增 TerrainSync：正确space[x][y]，遮光/形状/碰撞状态，宿主原生结算与回执，保护在途预测、去重、换房清理、128块轮转；HP变化不重绘。
- 新增 UnitPresentation：逐帧把原生短促开火转成持久事件号，只播放武器显示和机械爆裂，不重复子弹/击杀。房间重绘后同时检查 vis.stage，解决 parent非空却挂在旧离树图层的敌人。
- 旧版备份 `build/backup/m34-release-20260923-183657-115022/RConnectMod.before.swf`，SHA `683f8573…52fff2e6`。仅复制回release/RConnectMod.swf并重启双方可回到0.2.5；不能恢复旧根SWF覆盖他人loader。部署回执 `build/m34/deployment.json`。

## 4. 正在进行与停点

- 本轮修复、正式字节行为验证、部署及正式加载路径重启检查完成，等具体存档实玩反馈。
- 基于M33提交0925667；正式包20类，不含测试入口/游戏存根。外部驱动只有EffectsTerrainTestDoc/TerrainRegression两类，未携带另一份模组代码，测试包装器不部署。
- 根游戏仍为1.02、manifest loader v2，SHA `b7824465…8003305ac`；RV0.30 SHA `ce3abb8d…3a8dfb5b`。全组合各文件指纹随报告保留。

## 5. 已知问题与验证边界

- 未穷举全部武器、Boss、持续伤害/死亡覆写和焚毁；本轮机械离体以原生金属/小爆炸显示为主，不声称复制所有敌人专属特效或远端弹道。
- 地形上报从原生已接受的耐久差采集；两端初始生成结构严重不同、连接前已损坏地形初始基线仍有边界。门走已有对象协议；320块与回执次序采用独立小网格验证，真实枪械案例另走完整TCP。
- 全合作在RC+RV，全部已装模组验了显示/特效/破墙专项，未验长期全组合战斗及每个地区。
- 普通受击器使用基础Unit损伤规则，特殊Boss覆写未全覆盖。近身320px补发现保留原生墙/朝向/隐身判断；TDFC战术目标、完整发现度/听觉未重做。
- 初次同id/class就近认领，绑定后按实例键；初次重叠、几何差异仍有限制。稳定重连、公网、三人以上和其他版本不在本轮范围。
- 红测/失败包含测试初始造墙观察不足、错误厚墙位置，以及真正旧图层失联；不要把前三项或单一像素失败误归因网络，也不要只检查parent/visible。

## 6. 下一步

1. 用户双方保存、完全退出并正常重启，确认面板0.2.6-dev。
2. 具体存档复测敌人开火、旋翼机死亡，以及加入侧连射破墙后宿主墙洞与墙后敌人。
3. 若仍有个别单位不显示，同时查room/key、sost、invis/isVis/alpha、vis.stage与实际主场景像素；特殊死亡按具体类核对，不能调用完整die造成二次掉落。

## 7. 深入了解

- M34：knowledge/experiments/2026-09-23-m34-effects-terrain.md、m34-validation-evidence.json；build/m34/deployment.json；tests/EffectsTerrainTestDoc.as与TerrainRegression.as。
- 正式字节外部驱动方法已归档共享知识 KB-000061（修订1）；报告已追加全局测试台账。游戏旧图层机制在shared-knowledge/rendering/discoveries/frozen-unit-detached-layer.md。
- M33：knowledge/experiments/2026-09-23-m33-presentation.md；M32：knowledge/experiments/2026-09-20-m32-hit-feedback-armor.md；M31：docs/shared-exploration.md。蓝色S -数字为护盾损耗。
- 构建：tools/build_mod.py --java <java> --output build/<轮次>/RConnectMod.swf；--cooperation-tests / --presentation-tests / --effects-tests 为测试入口。默认无--output会写release，候选阶段必须显式输出。
- 回归：tools/run_coop_regression.py --candidate <SWF> --with-vision；完整合作--seconds360，专项--effects --all-mods --seconds180，画面--presentation --all-mods --seconds210，正式重启--smoke --seconds150。
- 正式字节行为测试：先普通构建，再 tools/build_effects_driver.py --candidate <正式SWF> --java <java> --output build/<轮次>/driver；runner加 --effects-driver <该目录> --effects --all-mods。它将正式SWF与只引用外部声明的驱动分开加载；必须审查两者类清单及两端production哈希。
- Python C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe；Java C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe；SDK D:/RemainsMod/mods/Sandevistan/build/tools/flexsdk。AIR/FFDec沙箱受限时走工具审核，不以启动通过冒充行为通过。
