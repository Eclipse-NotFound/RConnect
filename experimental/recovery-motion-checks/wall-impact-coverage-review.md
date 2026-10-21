# 击墙与特殊命中特效覆盖表（2026-10-22）

本次只读核对原生1.02参考、冻结 recovery03/04 及 driver09；未改生产/测试、未运行 JVM/AIR。**“代码已采集”不等于原生验证通过；14轮普通枪不能代表全部武器。**

03/04 的 UnitPresentation、BallisticImpactVisuals、EnergyImpactVisuals、ProjectileExplosionVisuals、ProjectileVisuals、BurnVisuals、MeleeVisuals、ImpactEventQueue 逐字相同；04仅在墙痕类追加解码缓存，没有补下表特殊效果。

| 原生/特殊路径 | recovery03/04 采集与重现 | driver09四入口及本轮证据 | 明确缺口 |
|---|---|---|---|
| 普通弹：Bullet.popadalo，硬材质1/2/5/7 → iskr_bul，弹体跳到命中帧；命中生物另有血粒子 | BallisticImpactVisuals核对真实新Part再发送分组，接收重放原生Emitter；弹体帧另走ProjectileVisuals | **普通14例**：lmg/autor/shotgun双向、敌方lmg及慢弹、12发连射、无命中消亡、血粒子。recovery02原生40814ef14c主106/0、加104/0 | 有实际普通枪功能证据，**不是03/04重新通过**；首例收包到首粒子2754 ms仍未关闭，不代表延迟合格 |
| 材质分支：3/4/6本来不喷普通火星 | 真实Part存在才采集，原则上可保持无火星 | **材质14例**：lmg双向×材质1–7，3/4/6要求双方无粒子；driver09已编译，未找到本轮原生运行回执 | 仅驱动待测；不能从默认材质2的普通枪结果推及全部材质 |
| 能量弹/光束：plasma/plasma1/plasma2、laser等 → flPlasma/flPlasma2/flLaser等 | EnergyImpactVisuals限Bullet/SmartBullet与已知flare，配对真实新Part，传位置/帧/色变/透明度；非爆炸 | **能量15例**：nova/plam/prism/blaster双向；plamg双向12发；敌方alilight；cflamer双向；plamg无命中消亡双向。已编译，未实测 | 多弹丸与短闪光有驱动，射速/延迟/完整连续性未过；明确无MSW专用项 |
| **速射等离子plamg**：80速度、rapid4、plasma2 → flPlasma2；tipDecal16墙痕 | 飞行、短闪光及frontBmp墙痕是三条独立路径，均有代码 | 上行能量入口含12发双向，但未设置interpolate标志，因此其“中间飞行位置”断言不会执行；独立高速入口不是墙痕像素验收 | 有驱动未测；12发命中通过也不能证明持续高速平滑或墙面留痕平滑 |
| **天角兽alilight闪电**：lightning、flare=spark → flSpark | 真实飞行帧＋EnergyImpactVisuals spark配方；不是按激光瞬时线处理 | 能量入口1例：宿主创建天角兽并直接调用其武器攻击墙；已编译未实测 | 不测试敌人自行寻敌/AI开火，也不测试连续闪电压力；原生效果未验证 |
| 魔法武器：telebul/mbul/ice/lightning/mray/dray/skybolt | 同Bullet/SmartBullet flare链；telebullet/sparkl/ice/spark/plasma/dray/plasma2均在白名单 | **魔法14例**：上述7种×主/加，已编译未实测 | 这是Weapon.attack用例，**不是一般Spell技能、范围魔法或魔法爆炸用例** |
| 普通爆炸/投掷：Bullet/PhisBullet.explosion→explVis；expl/flare/iskr、plaexpl、impexpl、iceexpl/snow、水下explw/bubble、自定义visexpl | 首次isExpl采集ProjectileExplosionVisuals配方；有vis历史的弹体可带爆炸重现；PhisBullet非爆炸popadalo本来无普通flare | **四入口均无爆炸用例。** driver09仅携带ExplosiveVisualTestDoc/SpecialWeaponTestDoc/MagicExplosionTestDoc源码，未列为编译入口 | 仅已有测试源码，不是可运行入口/当前通过证据；爆炸与高速弹功能应分开补验 |
| **酸性投掷acidgr**：acidexpl＋acidkap飞溅＋explLiquid("acid")→地面visualAcid | 爆心/随机飞溅有配方；BurnVisuals.captureGround只接受tipDamage3火焰，酸液10没有地面采集重现 | 四入口**无acidgr**；未编译的SpecialWeaponTestDoc有acidgr，且检查地面acid与≥30飞溅 | **地面酸液确定缺口**；已有测试源码能针对它检查，不能称已运行或已覆盖 |
| **gasgr重复脉冲**：explKol12，后续explRun反复生成gas；pinkgas同类 | UnitPresentation只在shot.explosion为空时采集首次isExpl；play虽接受repeat，生产无后续repeat事件发送 | 四入口**无gasgr**；未编译SpecialWeaponTestDoc含gasgr/pulses:true | **后续脉冲确定缺口**；不能把首次爆炸显示当多次效果完整同步 |
| **MSW跳弹/智能普通弹**：沿用原生Bullet并可能重生；附加MSWSmartTrail | 原生Bullet/weap在采集链内，普通命中可能沿用已有路径；独立Sprite拖尾不在该采集链 | 四入口无MSW开关/智能锁定/多次反弹用例；普通lmg不等于专门开启并断言这些机制 | 原生弹部分仅代码适用性；智能拖尾及转弯/重生/命中组合无本轮资格 |
| **MSW可编程榴弹无vis爆炸**：MSWBullets.explode创建vis=null的dummy Bullet再explosion | scanBullets可能看到dummy，但captureFlight始终null且无lastFlight；发送只允许无flight的impact，**不独立发送explosion** | 四入口与上述三个爆炸测试源码均无该MSW用例 | **明确采集/发送缺口＋原生用例完全缺口**，不能套用普通grenade覆盖 |
| MSW非致命激光/激光笔/闪光弹：MSWLaserBeam(Pt)、MSWPointerBeam(Sprite)、MSWFlashPulse(Pt) | 不属于Bullet/SmartBullet/原生Part白名单；FlashBullet虽是PhisBullet子类，其爆炸改用onFlash→自绘pulse，原生explVis配方不能重现 | 四入口与三个爆炸测试源码均无MSW专用用例 | **专用视觉缺口**；未审查/判定致盲玩法结算是否同步，不把视觉结论扩大为伤害结论 |
| 持久墙面贴花/焦痕：Location.hitTile→Grafon修改frontBmp | WallImpactVisuals采集接触区域实际像素；03/04都有，04仅缓存验证过的解码词组 | 四入口只看Part/显示对象与其像素，没有比较两侧frontBmp留痕、重访保持或增长延迟 | **本轮原生墙痕验收缺口**；短暂命中火花与持久留痕不能互相替代 |

## 判定依据及边界

- 原生参考：[Bullet.popadalo/explVis/explLiquid](../../../../game-reference/decompiled/1.02/src102/scripts/fe/weapon/Bullet.as)、[PhisBullet.popadalo](../../../../game-reference/decompiled/1.02/src102/scripts/fe/weapon/PhisBullet.as)、[Weapon.flare默认与setBullet](../../../../game-reference/decompiled/1.02/src102/scripts/fe/weapon/Weapon.as)、[AllData武器/Part资源](../../../../game-reference/decompiled/1.02/src102/scripts/fe/AllData.as)。PhisBullet碰撞无普通火花是原生行为，不应凭消失造火星。
- 生产关键位置：[UnitPresentation.as:150](../../build/m52/recovery-04/src/rconnect/game/UnitPresentation.as#L150)、[ProjectileExplosionVisuals.as](../../build/m52/recovery-04/src/rconnect/game/ProjectileExplosionVisuals.as)、[EnergyImpactVisuals.as](../../build/m52/recovery-04/src/rconnect/game/EnergyImpactVisuals.as)、[BurnVisuals.as:52](../../build/m52/recovery-04/src/rconnect/game/BurnVisuals.as#L52)。MSW仅必要只读检查现源MSWBullets.explode、MSWFlashBullet/FlashWeapon、LaserBeam/PointerBeam/FlashPulse/SmartTrail；**未核验其现源与安装SWF等价**，上表MSW结论是所查源码链缺口。
- [driver09 prepared.json](../../build/m52/recovery-drivers-09/prepared.json) 是recovery04配方：compiled=true、air_started=false、native_qualified=false。普通/能量/魔法/材质合计57个场景，不能把它们当57次实测。原生普通枪通过来自[旧recovery02回执](../../build/m52/recovery-wall-ballistic-native-03/result.json)。
- 能量夹具将命中墙设为不可破坏、无水，固定瞄准/伤害，并调用真实Weapon.attack；不代表原生输入、AI行为、地形破坏、所有变种或水下命中通过。其像素/帧比较是功能检查，PNG虽已延后导出，仍不能用它证明无卡顿。过期和无粒子材质是必要反例，必须保留。

优先补齐表中明确缺口的独立原生用例，再逐机制修改；不要为本轮高速失败一次合并所有特殊武器机制。本审阅未扩大修改范围。
