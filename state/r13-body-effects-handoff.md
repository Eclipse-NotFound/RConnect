# R13：隐形、护盾及角色本体效果（M50 合并项）

2026-10-09。用户要求修复道具隐形小马、护盾在对侧不显示，并全面检查类似本体动画效果。统一集成、构建、隔离 AIR 与部署由原 RConnect `01a086bb-378c-7f60-b8e1-50d90ffa0996` 负责；R13 `01a11c5b-7a4d-79f0-96d4-1f99e7333e85` 只写本文及以下两个独立文件，没有写共享接线、版本、工具、MEMORY、release，没有构建或启动 AIR。

## 本次独立交付

- `src/rconnect/game/PlayerBodyEffects.as`：显示状态采集、应用、清理。
- `tests/BodyEffectsTestDoc.as`：真实道具/法术/Effect 到 Session/TCP 再到最终 RENDER 的双向专项。54 轮玩家状态（每项后有 clear），再两轮敌人冰冻/恢复，共 56 轮。计划通常约 160 秒，加启动等待；建议单组至少 360 秒预算。**尚未编译、未实跑，不能标为验证通过。**
- `tests/PlayerBodyEffectsTestDoc.as`：仅继承上述专项的入口别名。协调者当前 runner登记的是PlayerBodyEffectsTestDoc、driver choices一度是BodyEffectsTestDoc，为避免入口不一致留此薄适配；两者运行同一套测试，不得算两组覆盖。

## 原生源码审计

原生路径均为 `game-reference/decompiled/1.02/src102/scripts/`。以下为代码证据，不冒充游戏实测。

| 原生状态/事件 | 实际显示变更 | 处理 |
|---|---|---|
| Invent.useItem("stealth") → Effect("stealth")；stealth_armor | UnitPlayer.setFilters：root alpha=.5、osn BlurFilter | 同步实际 alpha/filter；正常/移除态也发，保留既有队友 .75 淡化因子 |
| Spell.cast_mshit → shithp>0 | UnitPlayer.otherVisual：vis.shit 从1播至20，再保持；耗尽隐藏 | 白名单原生附件与时间轴；不会每包重开护盾 |
| Spell.cast_cryst / actions | vis.cryst 展开、保持、收尾；crystal_492在5/15帧stop | 同步独立附件状态及原生起止 |
| potion_shadow | osn DropShadowFilter，hideObject=true | 保留完整原生滤镜参数 |
| bloodinv | osn 两层红色 GlowFilter | 同步并在解除时清空 |
| dash / levit / 被念力抓取 /二段跳 | osn BlurFilter/GlowFilter | 捕获最终显示参数，不在远端施加物理 |
| freezing | Effect.visEff：vis根 ColorTransform（冰蓝，叠加房间颜色） | 玩家及敌人同步，退出时恢复源侧正常色 |
| inhibitor | vis.inh显隐、展开后停止；inhibitor_438第30帧stop | 原生附件重放；测试同时验证展开帧与保持状态 |
| potion_rat | ratOn/off：osn/rat互斥 | 同步两个子树的显隐，不在远端执行变身及背包/宠物逻辑 |
| fetter | vis.fetter显隐、长度与旋转 | 按源侧相对角色的几何同步 |
| 角端施法光、受惊/眨眼、天空光层 | morda.magic、morda.eye、vis.svet | 白名单真实子剪辑状态（不猜技能、魔力或本机全局外观） |
| 死亡/复活 | UnitPlayer.animate改osn alpha/颜色/Glow，setNull/resurect清理 | 同步实际子树状态；ghost重建/离房/结束必须forget/reset |
| 飞行翅膀、燃烧粒子、Q传送、武器/念力物体光晕 | 已由 PeerAppearance、BurnVisuals、TeleportVisuals、WeaponDisplay/TelekinesisVisuals 负责 | 本模块不复制其行为；根alpha/颜色仍自然作用于本体附件 |

`Effect.secEffect` 中中毒/湿身/失明等主要是伤害、周围粒子或本机界面；没有新增对应本体滤镜。没有把全体 Effect 在对侧重跑。`UnitPlayer.damage` 主要结算伤害和击退；姿势仍由原姿态同步负责。敌人隐形的 invis/isVis/alpha、天角兽护盾仍走已有专用路径，不能用玩家透明规则覆盖。

旧代码在创建 ghost 时只设固定 alpha=.75，并在 preparePlayerVis 隐藏 shit/inh/cryst/fetter/rat/svet。玩家快照没有这些本体状态；原来的姿势/武器同步不会执行真实 UnitPlayer.setFilters/otherVisual。**固定alpha是在初始化处，不是每次driveGhost重新赋值。**

## 最小接线（原会话负责）

实例接口：

```as3
observe(u:Object, stamp:int):void
capture(u:Object):Object
apply(u:Object, state:Object, paused:Boolean=false):void
forget(u:Object):void
reset():void
```

1. GameBridge 建立 `_bodyEffects:PlayerBodyEffects`；在原生玩家动画之后、`onMirrorFrame` 的源侧观察阶段调用 `observe(gg,_sampleAt)`。`readSnapshot` 加 `s.bodyEffects=_bodyEffects.capture(gg)`。已观察的逐帧帧数用于识别 isPlaying=false 仍实际前进的原生剪辑；capture不修改源对象。
2. `driveGhost` 用**与身体相同的 motion sample/settle 样本**调用 `apply(ghost,snap.bodyEffects,coopPaused)`，放在 `driveVisAnim` 后；最终 RENDER 中 RemoteArmor/姿势重建后再 apply，防新子剪辑继承默认可见状态。先应用root alpha再驱动武器，便于武器/近战按最后父alpha合成。
3. 玩家本地Q抓队友时 TelekinesisVisuals 对根节点的临时光晕/颜色仍在 `presentHeldVisuals` 后应用。本 helper 不改根filters，也不改根visible/mask/位置，避免接管本地视野。osn才完整同步原生身体滤镜。
4. `despawnGhost` / 删除 / 替换visual前 `forget(ghost)`；`endSession` / 角色世界重置 `reset()`。helper会检测visual对象身份变化并恢复旧节点。`apply`拒绝真实 `u.player===true` 本机角色，避免接线错误污染本地玩家。
5. 敌人：`readUnitsSnapshot` 加 `bodyEffects:_bodyEffects.capture(u)`。敌人的 capture自动只发root颜色和可选inh，不发送rootalpha、invis、isVis。在 UnitPresentation 状态中保存，并在原生 `animateBody` 之后/最终 `enforce` 应用；暂停路径也需要apply来接收最后的源状态。相应reset/失效单位forget。可用独立 helper 实例。
6. 协调者把 BodyEffectsTestDoc加入编排（当前已看到 build_effects_driver.py choices 有该入口），先21负控，后候选绿测；不要把已有负控中未包含的新断言算通过。

## 透明度交叉边界

DisplayObject.alpha与ColorTransform.alphaMultiplier共用通道（[AIR官方参考](https://airsdk.dev/reference/actionscript/3.0/flash/geom/ColorTransform.html#alphaMultiplier)）；不能先设`.75*原生alpha`再写回原生CT，否则会被覆盖。自查中发现并修正了首版helper的此问题：玩家一次合成CT，乘上.75的alphaMultiplier与alphaOffset；敌人只替换RGB，保留当前alphaMultiplier和alphaOffset，避免覆盖GameBridge已有的隐身渐隐；restore亦遵守RGB所有权。测试oracle相应检查合成后的alpha通道。此前交付哈希已作废，不能与此修正版混用。

真实玩家武器经常挂世界层，ghost武器挂本体下；将root alpha从固定.75改为 .75*实际隐形后，会影响继承的武器alpha。现有MeleeVisuals最新实现对body child仅赋p.a，世界层trail赋p.a*body.alpha，已经避免`.75`平方。R5与协调者仍需按既有“队友淡化”语义核对是否需要把隐形也作用于武器；不能为提高武器亮度把body child alpha设置为>1（Flash会钳制）。若要求与原生独立世界层武器的最终alpha完全一致，需要改变挂载/补偿方式，不能仅除alpha。本模块本次没有改武器。

## 专项测试的证据边界

- Stealth调用真实 `invent.useItem("stealth")`，shield/crystal调用真实 `Spell.cast`，其他状态调用真实 `addEffect`；不调用PlayerBodyEffects、不伪造生产快照。
- 每种状态一侧有、另一侧无，随后clear，然后交换方向；用独立oracle对照真正源显示与ghost最终显示，检查alpha、滤镜、颜色、显隐、束缚几何、护盾保持帧。每轮源原生效果必须自身成立，不能只见没有崩溃。
- 源player用disabled保持位置，测试在原生更新点每帧仅调用一次公开actions/animate；暂停时不推进。rbl剧情可能遗留animOff，setup记录并用真实 `g.anim()`退出覆盖。输出entry/first mismatch/每轮metrics，失败不吞掉。
- 护盾、inhibitor在早期采样展开帧；本来都是一次展开后停止，不要求一直循环。
- SATS轮由真实Sats.onoff触发共享暂停，验证两端paused及护盾保持；不假设原版所有无关装饰时间轴在SATS都会停。
- 全画面PNG位于隔离应用Storage的 `body-effects-<round>.png`，主要状态两方向共20张；必须检查实际画面。不能仅根据字段匹配断言遮罩/组合像素正确。
- 通常战斗死亡→复活、穿门换房、换装重建还需总回归与针对性观察，当前专项的clear不等价于完整死亡链。当前未测试未知状态或未来版本；无效输入参数做有界过滤，不宣称版本兼容。

## 当前验证状态

已完成原生代码审计、独立实现/专项编写；未构建/未AIR/未部署。当前release仍是0.2.21-dev。工作树包含其他会话的持续编辑，禁止整体回滚、提交或覆盖。公共MEMORY/journal由协调者记录本handoff。

- 静态检查：AS3实现/专项括号平衡，无行尾空白；不是AS3编译通过的替代。最终指纹见同目录 `r13-body-effects-input.json`；首版cf3834b1/19d571ff已因alpha合成修正作废。
- 发给原会话的前期接口信息成功；最终交付和R5透明度协调消息、随后read_thread均连续返回Codex app tool request failed，**未确认最终交付消息送达**。所以完整交接落本文件。后续只读检查已看到原会话开始GameBridge接入：capture/observe、最终RENDER apply、despawn forget、reset；runner也改为BodyEffectsTestDoc/360秒。原会话协调表记录了相同的消息服务故障，可继续从文件收取。
- 接入复核提醒：截至这次只读检查，driveGhost自身（driveVisAnim后、driveWeaponVis前）还未调用_bodyEffects.apply，只有restyle和RENDER处，武器父alpha依赖请核对；敌人只在RENDER用viewMotion样本apply，需确保新/静止/暂停对象也有对应样本，不漏首帧/停帧。不修改共享代码抢占协调者接线。
- R13最终停点：上述独立源码、两种入口、专项与指纹已可冻结；未收到编译/运行结果。主集成继续时先核对最新e58645ec/861b5a8d，旧指纹禁止沿用。当前release读回SHA仍 `5c372cf5d970212f0fd4e95bea5c0acfaabfe321c3ca531c80ed7e299c2914bd`。
