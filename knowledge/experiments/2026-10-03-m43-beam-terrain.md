---
domain: rendering
type: experiments
game-version: ["1.02"]
confidence: high
verified: true
discovered-by: RConnect
date-updated: 2026-10-03
evidence:
  - kind: runtime-experiment
    summary: "统一final2候选以相同生产字节完成隔离双端激光/破墙23项及雷电/玩家弹道9项回归，发布仍由原RConnect负责。"
  - kind: decompiled-game-code
    game-version: "1.02"
    symbol: "fe.weapon::Bullet.step; fe.loc::Location.hitTile; fe.graph::Grafon.tileDie/drawLoc"
---

# M43 激光与远端破墙显示（专项通过，已交接）

本轮用户反馈加入侧炮塔及其他敌人的激光闪断，以及非玩家破墙动画不流畅；明确补充“光束断断续续、闪一下就消失”。基线`ce56ecc`已含M41修复和中英俄界面，安装SWF93060字节、SHA256 `2b25a7d2301d1baac40e04e70ba48e9bc40b5c292c0b3938a69bf6b151b41186`。冻结副本/源码在`build/m43-beam-terrain/baseline`，54项其他文件指纹在protected-before.json。

本会话RConnect(2)负责ProjectileVisuals、UnitPresentation、TerrainSync和GameBridge特效帧接口；已获用户授权与原RConnect及新RConnect(3)协调。RConnect(3)负责地图/队友传送；按用户最新指示及三方确认，原RConnect负责隐藏房问题和最终合并冻结、门禁、版本、部署、MEMORY/journal及提交。三方完成前不部署，AIR与编译时段串行。构建定位候选使用冻结基线仅覆盖本会话所属文件，避免吸入其他未完成改动。

## 已运行证据

统一入口：`tools/build_effects_driver.py --candidate <SWF> --source-root <冻结src> --entry BeamTerrainTestDoc --java <本机Java> --output <目录>`，然后`tools/run_coop_regression.py --candidate <SWF> --effects-driver <目录> --effects --all-mods --responsive --seconds 115`。运行实际Session/TCP、原生Weapon.shoot、Bullet.step/run与粒子；唯一AIR标识、新角色、双方同字节。

|轮次|结果与意义|
|---|---|
|49e578e777|强制66ms射击：光束存在性检查通过，但远端碎片count/frames/changes均0；墙体数据已收敛。只靠存在性不能验证光束节奏。|
|656faacd65|按原生间隔（turret2=10帧，robolaser=30帧）并裁剪视口：炮塔原生可见1641ms，加入4719ms；机器人593/2975ms。此轮仍是显示边界，未读真实像素，不能把包围盒当发光内容。碎片仍0。|
|7c2634cd8e|最终RENDER逐帧像素差：炮塔1882/4181ms，时长一致性失败；机器人685/876ms，在本轮容差内。碎片仍0。原生枪口/子弹本身运行，未修改生产字节。|
|6378765d05|full1修复候选：13条断言通过。炮塔原生2064ms/加入2167ms，最长暗段262/297ms；机器人790/789ms、暗段910/914ms。双方碎片均6个，加入连续可见50帧、位置变化49次；物体显示层身份保留。两端DONE、runner PASS并清理。|
|7dd047f40c|同一full1生产字节，新增边界后21条通过。炮塔1883/1751ms、机器人665/738ms；碎片仍仅6个，可见57帧、位置变化56次。停火无残留、重复事件不重播、原生重绘后像素恢复、换房/重置清空、纯显示不新增模拟对象通过。两端DONE、runner PASS并清理。|
|de6dbdaa29|同一full1生产字节，ProjectileNetworkTestDoc修正原生光束夹具后9条通过。加入端雷电实际像素78帧，护盾开启/耗尽显示正确；双方玩家弹道89/88帧，枪械动画33/62帧。两端DONE、runner PASS并清理。|
|052160141a|full1新增死亡中断后21PASS/2FAIL：炮塔在光束有真实像素的帧死亡，源没有记录结束、加入端残留冻结光束，两项均失败；其他用例继续通过。两端DONE、runner FAIL并清理，证实死亡观察过滤有缺口。|
|1114773ed7|full2补死者武器采样后23PASS/0FAIL，死亡中断两项转绿。炮塔2196/2448ms、机器人759/934ms；碎片6个、57个可见帧、56次移动。两端DONE、runner PASS并清理。|
|f8dd272d67|统一final1（0.2.14-dev）23PASS/0FAIL。炮塔1952/2048ms，暗段269/267ms；机器人722/776ms，暗段909/913ms；碎片6个、54帧、53次移动，死亡中断等边界均通过。两端DONE并清理。|
|f5d3d57b3a|同一统一final1的ProjectileNetwork 9PASS/0FAIL。雷电像素68帧；双方弹道83/82帧，枪械动画31/60帧，护盾开启/耗尽通过。两端DONE并清理。|
|a3d8680409|统一final2（0.2.14-dev）BeamTerrain 23PASS/0FAIL。炮塔1903/1960ms，暗段260/257ms；机器人663/719ms，暗段934/942ms；碎片6个、55帧、54次移动，死亡中断等边界均通过。两端DONE并清理。|
|07f2f248b6|同一统一final2的ProjectileNetwork 9PASS/0FAIL。雷电像素74帧；宿主所见加入弹道87帧/枪动画62帧，加入所见宿主弹道88帧/枪动画33帧；护盾开启/耗尽通过。两端DONE并清理。|

第一版全房重绘探针检查frontBmp对象身份，但Grafon.drawLoc会复用该BitmapData并清空/重画，故此项不能证明没有重绘；夹具已改为检查被drawAllObjs替换的visObjs[2]图层。6378765d05采用新探针通过，旧探针PASS不算此项修复证据。

测试初次启动53fec04ea7被沙箱拒绝Get-CimInstance身份核验，runner退出并清理自己启动的实例；改经正常工具审批运行。测试编译曾缺少DisplayObject显式转换，修正后成功；这些属于夹具/环境问题。

## 已通过的实现

- TerrainSync对普通实体墙的权威销毁，在原生grafon上执行一次tileDie视觉方法，不再次hitTile/dieTile；数据、碰撞和水重算仍按原有权威协议处理。仅更新前景位图并发出碎片。检查点/其他形状或背景变化保留全房重画。当前无命中材质类型的独立协议，采用普通碎片类型9；激光烧蚀/特殊融化样式没有据此宣称精确等同。
- UnitPresentation每个源游戏帧保存光束实际显示的坐标、缩放、透明度、帧及结束时刻；ProjectileVisuals以源时刻播放，重复快照只补全轨迹，不重新发射。普通抛射物继续原路径。显示层重建后将仍有效的显示副本重新挂到当前图层。
- 已生成仅TerrainSync变更候选`terrain/RConnectMod.swf`，93199字节、SHA256 `e80d2840460567526dc4f2af2d6f546e482898ddd99a47e25bf8235f7d20f442`，未运行。full1候选94183字节、SHA256 `8d2458e71ec19a50708599f967b3330b7ca368a8ba426097a2f4d6713aee1f6c`，通过首轮。实际两端SWF指纹已由run.json记录，生产release未改。
- 停止/重复快照/显示层重建/换房/重置边界已通过。修正旧NativeTestGun仅对光束执行原生step并保留其自然淡出；旧夹具run后立即remObj根本没有宿主显示帧，不能作为忠实播放的源证据。普通轻机枪夹具路径未变；雷电网络专项de6dbdaa29已通过。

## 最终交接

生产文件为`ProjectileVisuals.as`、`UnitPresentation.as`、`TerrainSync.as`及`GameBridge.as`的两个帧回调。外部驱动为`BeamTerrainTestDoc.as`、`NativeBeamGun.as`及原`NativeTestGun.as`的光束分支修正；公共构建入口新增BeamTerrainTestDoc，runner增加projectile visual failed过滤，同时保留另两会话的入口与过滤。

本会话不提交混合工作树，不修改release、版本和公共MEMORY/journal。full1的冻结源码/指纹位于`build/m43-beam-terrain/full1`，不将此处专项成功替代联合候选验证。收尾审查发现observe跳过死亡敌人会漏发光束end，新增真实开火后死亡用例证实并修复；前三轮成功仅代表各自覆盖范围，死亡完整覆盖由1114773ed7提供。

死亡补丁仅让死者武器继续采集已经发出的光束，尸体自身动画仍跳过。最终专项full2源码与产物冻结在`build/m43-beam-terrain/full2`，94183字节、SHA256 `6e380c60524d1d9d8e0738efab2fdb19e382ee9d700bd3301025a43408101454`；1114773ed7已通过23条断言。已向原RConnect交付并交还编译/AIR窗口，生产文件停止修改，等待它合并冻结、门禁和部署。

统一final1冻结在`build/m43/final1`，99888字节、SHA256 `72aa7139f53f0fd8067333049de69da63ddb86d5703146f1ca47006f5030b152`。45项冻结源指纹全部吻合，两个驱动均用对应source-root重编，两次运行的双端production指纹与候选一致，初始化均为0.2.14-dev。它的两组32项检查已完成，但原RConnect随后修正RoomDiagnostics对MirrorHitUnit/VirtualUnit的诊断误报，要求重冻final2；因此保留final1为历史证据，不能冒充最终部署字节的验证。我方不改生产/部署，窗口已交回原会话，并通知地图侧等新冻结。

最新统一final2冻结在`build/m43/final2`，99900字节、SHA256 `ed240f09883b091fef5474ff6ef5219bdeae669948ca1331c76007faeef24b20`。45项冻结源指纹全部吻合，相较final1仅`RoomDiagnostics.as`改变。两个驱动均以final2/src重新编译；a3d8680409与07f2f248b6两端production均为此SHA，初始化均为0.2.14-dev，合计32PASS/0FAIL，运行后候选指纹保持不变。没有修改生产源或部署，已向原会话交回编译/AIR窗口并告知地图侧，供其完成剩余统一门禁与部署。

## 验证边界与资料

采用已回读KB-000061 rev1的精确生产字节外部驱动与KB-000071 rev1的进程策略纪律。共享检索存在来源不可读，不等于没有经验。像素采样用于显示正确性，不将其耗时作为正常帧率或性能改进依据。游戏/其他模组/配置54项保护指纹复核全部相同；已补runner的projectile visual failed错误过滤。最终统一候选既有回归由发布执行者负责。历史Area #1063仍与基线一致，并非本轮通过所覆盖的修复。

统一部署补记（2026-10-04）：原RConnect已完成final2共9组470项及正常加载冒烟，部署0.2.14-dev、99900字节、ed240f。本专项的32项属于其中，未重复计数。完整部署与回滚见[统一回执](../../state/deployment-m43-2026-10-04.md)；背景房问题仍未确认修复。
