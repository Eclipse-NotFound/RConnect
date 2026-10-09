# M50 近战子任务交接（RConnect (5)）

2026-10-09。唯一共享源/构建/AIR/部署负责人仍为原 RConnect 会话 `01a086bb-378c-7f60-b8e1-50d90ffa0996`。本会话只修改独立近战四文件及实验记录，无自主构建、AIR、版本号、release、总记忆或提交。

## 当前状态

- `probe-peer-02` 的旧近战四文件已随诊断候选编译（47b60925，142215B），未跑近战专项，不能称运行修复通过。
- 原会话随后授权本会话在四文件范围核对 PlayerBodyEffects（R13）并补原生隐身 alpha 问题。此处的新修订尚未编译、尚未部署；保留旧 probe，不修改其副本。
- 读取/发送跨会话消息当前出现 MCP `-32000` 失败。此前发送的接口/四文件冻结已确认；这次世界层修订的告知发送失败，故留下本区书面交接供统一负责人读取。不把失败消息当作已送达。

## 新修订及接入

四文件：`src/rconnect/game/MeleeVisuals.as`、`src/fe/weapon/RConnectMeleeAccess.as`、`tests/MeleeAnimationTestDoc.as`、`tests/fe/weapon/MeleeTestAccess.as`。签名不变。

MeleeVisuals.apply 现把 WClub 武器和 visvzz 放入 body.parent 世界层，记住原 parent 与颜色，forget 时归还。原版 UnitPlayer.setFilters 的 stealth 只把 pony.vis.alpha 设 .5；世界层 weapon.vis 不一定跟着变。若武器仍在远端 body 子层，需要局部 alpha>1 才能还原部分原生状态，DisplayObject 会钳值，无法靠单一除法解决。复制实际 weapon/trail 的独立 ColorTransform 与 alpha，同时保留既有队友 .75 标记；尾迹的10/rapid alpha不除角色透明度。敌人仍按本机/源端身体视距透明度比例处理。body.visible 继续门控。

请统一接入负责人复核：分房/隐藏/死亡/房间过渡时，现有 despawn/removeWeaponVis 必须调用 WeaponDisplay.forget（已接），以移除世界层视觉；若某条分支只隐藏 body 并跳过 driveGhost，应同时隐藏世界层 WClub。正常同房 apply 每帧更新 visibility。

精确只读复核补充：updateRemote 的不同房分支直接 despawnGhost 后将rec.ghost=null，后者只remObj，没先removeWeaponVis。syncRemoteWeapon 没有把新weapon加入 ghost.childObjs；原生Unit.remVisual只遍历childObjs，世界层WClub/trail不应指望此路径自动清掉。removeRemote又先delete _remotes[id] 再removeWeaponVis，forget取不到原weapon。建议由统一负责人在despawnGhost入口（记录仍在时）调用removeWeaponVis(id)，并确认removeRemote删记录前清理；不需要本会话越权改共享文件。应覆盖离房、断线、重建、换装、换枪等同房展示路径。

需要与 R13 对齐：PlayerBodyEffects.apply 当前先 `root.alpha=.75*s.a` 后 `tint(root,s.c)`；后者设置 ColorTransform.alphaMultiplier，可能覆盖标记的透明度。应按原生字段语义核对设置顺序，近战专项新增断言会直接检查 body=.75*nativeAlpha。本会话不编辑其文件。

## 独立专项

现为11个双向案例，原9个加真实 stealth 物品使用的刀与能量剑，检查原生 body=.5、远端 body=.375，weapon/trail 各自原始 alpha×.75；没有对尾迹做角色 alpha 归一化。角色开始冻结前须生命/工作阶段正常（t_work 的 die/res、animOff 被门控），避免在尸体姿势上伪测动画。当前其他假设/原生对照方式详见 `knowledge/experiments/2026-10-09-m50-melee-animation.md`。

请先用同一最终夹具建立旧21原症状负控，再跑新候选专项；禁止把编译、基础启动或别组 PeerVisual 的结果替代近战行为证据。正式候选完整回归/部署、记忆更新及统一提交仍由原会话进行。

## 最新输入冻结与已观察构建

2026-10-09 01:07左右复核：probe-peer-03 的 production 已含世界层MeleeVisuals（6a54f60a）并编译成功，候选0ce470db / 150378字节。此前“世界层尚未编译”描述是消息发送失败时的状态。此候选不是已部署release；没有近战运行通过结论。probe03的MeleeAnimationTestDoc为8715ce7c，早于下列带真实活体工作阶段门控的e7902619。请下一次专项使用同一完整最新夹具做旧21/候选对照，旧probe副本不修改。

四文件本轮修改已结束，冻结SHA256如下；共享接线仍只读交给原会话：

- src/rconnect/game/MeleeVisuals.as：6a54f60a60d96ee623e9eb4273ccddd329fcf3b6869205e58f1c8c9bfb9946a6
- src/fe/weapon/RConnectMeleeAccess.as：2f55938707bc2e0ce0dd72304e4126acad7b958faf712a72fced5d817a27a658
- tests/MeleeAnimationTestDoc.as：e7902619e50fc740bf590dddf31905e25b25462bc1ae45b6bc0206619f2f8312
- tests/fe/weapon/MeleeTestAccess.as：2e982b2288c28eb642b3dde648045cc80139f0e24793b7699224c7ed03577bee
