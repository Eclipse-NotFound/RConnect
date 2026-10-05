---
domain: rendering
type: experiments
game-version: ["1.02"]
confidence: medium
verified: false
discovered-by: RConnect
date-updated: 2026-10-05
evidence:
  - kind: runtime-experiment
    summary: "两端真实 MSWConfig 均启用智能武器。M45 实际 MSW 拒绝 npc=true 的镜像代理。最终相同夹具A复现长闪电结束丢失，B的27项专项全部通过，涵盖真实HUD、原生引导、准确结算及最终RENDER结束；联合部署与红外特殊分支未验证。"
  - kind: decompiled-game-code
    symbol: "fe.weapon.Bullet.step/popadalo; fe.inter.Camera.calc; fe.inter.Ctr.onMouseMove1"
---

# 天角兽闪电与 MSW 智能武器兼容排查

## 已确认

用户反馈加入侧天角兽闪电显示异常、MSW 智能武器不可用，并澄清自己不确定开关是否开启。本会话只修改 RConnect；MSW 与游戏参考源码只读。原 RConnect 会话负责最终版本、联合门禁、release、MEMORY/journal 和提交；与 RConnect (2) 串行使用编译/AIR窗口。

基线为已安装 M45 / 0.2.16-dev，110626 字节，SHA256 `59a03d1eb3ca7d8467015c709301bc1fbe6d585342de5857e984344a33572790`。只读复制的两份实际 `MSWConfig.sol` 中 `smartEnabled` 均为 AMF3 true；配置与实际日志证据在 `build/r3-20261005-lightning-smart/user-input`。没有修改真实设置、存档或用户运行的进程。

专项驱动加载精确生产 SWF，与实际已安装 MSW 的控制器交互，不创建第二份 MSW。使用全模组、独立 AIR applicationID、与启动器相同的后台进程策略。真实天角兽原有 `alilight` 走 `Weapon.attack/step`；真实轻机枪同样走该入口，子弹由原生 Location.step 推进。没有 NativeTestGun、直接 shoot/run、手工锁定或注入子弹引导。

## 观察到

| 运行 | 输入与结果 | 解释边界 |
|---|---|---|
| ab114316ae | M45，boot 超时 | 初版加载时间被计入场景期限，夹具失败。 |
| 54badfa580 | M45，MSW 查找 #1065 | MSW 在兄弟 ApplicationDomain，夹具查找方式错误。 |
| 588502380d | M45，专项中途换地图 | 握手开始早于指定地图就绪，时长不可归因于产品。 |
| 5a1cf29cbd | M45，闪电主侧1529ms／加入514ms | 实际原生闪电红例；智能目标一度在视口外，不能用 visible=false 证明兼容问题。 |
| 7e1eee0101 | M45，闪电1712／903ms；MSW targetAllowed=false、visible=true；单锁、多锁、HUD、引导均0 | 有效旧版红例，代理 npc=true 是可见敌人仍被拒绝的原因。 |
| 07db38cd60 | 候选 A，闪电2205／6028ms；资格、可见性及多锁真实HUD50帧通过 | FAIL保留。此轮单锁准星被 Camera.calc 覆盖，不能当成产品单锁失败。 |
| 291d4e6d7b | A原字节；闪电1656／5877ms；单锁57帧、实际HUD65帧、原生引导36／转弯35通过 | 第1发线上 end=0，后3发 end>0；真实离链340–459ms。扣血0、排除阶段HUD可见仍FAIL，夹具朝向／枪口和额外可锁敌人尚待校准。 |
| 464e856e9f | A原字节，校准准星／枪口／额外目标后22项PASS；双方损失11.592383475603128 | 不是end修正红例。实际5发均收到end；旧失败不回写。 |
| 04db69972e | B原字节；5发end均到，仍FAIL：1663／1229ms、0引导／0损失 | 夹具中无敌天角兽代理在弹道上，noAgro不会阻止原生碰撞；晚Pt开火也不符合原生MSW钩子顺序。 |
| 58c418a970 | A，原生Ctr射击7发命中血翼代理，双方损失104.45502153062262；真实长闪电life1177ms | 确定边界红例：加入end=0，6000ms后记录count=1、显示4192ms；全资格／HUD／引导检查通过。 |
| 10376e54bc | B，同一Ctr与长飞行夹具；双方损失297.46241026908683，真实life1469ms、加入end收到且count=0 | 长边界通过。唯一FAIL是旧短光统计1662／1316ms；逐对象记录证明其中318ms是visalilight枪口准备，5发实际Bullet.vis共1344ms，不能归因于生产闪电过短。 |
| bf89d6d4e4 | 最终夹具首轮A，专项前宿主已死亡、加入Land/buildProb #1009，0项专项断言 | 启动阶段失败原样保留；未归因于闪电／智能武器。仅按本轮命令行身份清理测试3828／66680，后续双方夹具均增加boot期invulner保护。 |
| 662fe779ea | 最终夹具A，25项PASS／2项FAIL；短闪电1304／1286ms，双方损失201.1750396996722；长life1125ms | 2项FAIL均为结束边界：原生born74042、end75167，源事件同帧clear75167；加入从未收到end，6000ms后记录count=1、实际显示5402ms。单锁108／HUD119／引导1104／转弯1088、多锁118等通过。 |
| 6ffd54450d | 最终相同夹具B，27项PASS／0项FAIL；短闪电1221／1194ms；13发LMG均只命中血翼代理，双方损失178.08563171312562 | 长born72693、原生end观察74082／wire源end74078、life1389ms；源事件clear74785＝原生end＋703ms。加入首次end收到57403、最终RENDER clear57503（＋100ms），count=0；实际长显示1356／1355ms。单锁100／HUD111／引导819／转弯806、多锁109等全部通过。 |
| 2164a466c5 | B原字节，原BeamTerrainTestDoc，23项PASS／0项FAIL | 原turret2／robolaser的目标、断言及阈值不变；停止射击／源死亡不残留、不重启；原生破墙碎片6个，加入连续动画49帧／48次变化，未重建整房对象层。 |
| ac4e2a497a | B原字节，原SatsTestDoc，24项PASS／0项FAIL | 只适配代理查找；25次开关、唯一目标与真实血条／名字、排队射击、弹药／行动点、权威单次结算、隐身／资格、vis缺失／空vis／恢复、交接后旧目标退出与无旧伤害全部通过。 |

每轮输入、双方日志与模块指纹在 `build/cooperation/<运行编号>`，构建与夹具快照在 `build/r3-20261005-lightning-smart`。最初数轮夹具错误不算产品红例；没有删改失败记录、原断言或阈值。

## 推测

资格问题已有实测支持，以下记录由此采用的最小修正；结束状态保留已取得最终相同夹具A红/B绿，联合候选门禁仍由原会话执行。

MSW 真实 `targetAllowed` 要求 !disabled、!npc、!noAgro、!trigDis，并以实际敌人 id 执行用户排除规则。镜像本体为了冻结原生 AI 被 disabled；用于本地命中的 MirrorHitUnit 旧版又固定 npc=true，因此没有合格锁定对象。候选让代理从真实本体复制 id、isVis、npc、noAgro，并在权威快照传递 npc/noAgro；仍不进 firstObj，真实本体 AI 仍冻结。没有普遍强制 npc=false 或 isVis=true。

天角兽实际闪电是 `fe.weapon::Bullet`、spring=1、`visbullightning`，不是 spring>=2 激光。旧显示以端点近似并快速淡出。候选把两种原生闪电图形纳入逐帧轨迹记录，仍只播放显示副本，不增加伤害、弹药或碰撞。

加入侧长残影进一步暴露结束状态保留不足：事件在尚未结束时不会因700ms过期；但一旦原生离链，若出生已超过700ms，结束记录会同帧清除，永远送不出去。若离链更早，剩余短窗口也可能错过实际世界快照。候选 B 按 max(出生,结束)+700ms 保留，普通弹寿命路径不变。真实长飞行最终A红/B绿已取得，真实计时见上表；不能将单轮短光通过外推为所有随机条件下都无偶发显示问题。

最终RENDER逐DisplayObject诊断发现短光时长夹具污染：host曾初始化beamClass为gun.vis的visalilight，开火前的枪口准备也被算成闪电；收到第一发后才切成真实visbullightning。最终夹具初始化为空，保持原80%–130%+100ms门槛，仅统计真实Bullet.vis。旧失败与原夹具保留，不能静默改算成原测试PASS。

原生Location.step先执行gg.step，再执行firstObj中的MSW钩子；晚插入Pt驱动玩家Gun会让新子弹晚于钩子，可能在被观察前碰撞。最终夹具通过原生Ctr.keyAttack让玩家Control/Weapon.step发射，Pt仅观察；非目标碰撞体双方本地trigDis=true，目标血翼距玩家360px，原生资格、防御和真实子弹liv/vel/碰撞不改。这些仅是隔离试验条件，不写入生产或宣称自然房间全部敌人正确排除。

已有7个测试文件中的8处代理查找从旧 rconnect_hit_ 前缀改成 MirrorHitUnit 类型和原生 body 对象引用，保留原生敌人、武器、所有断言和阈值。

## 尚未验证

候选 B 仅从冻结 A 源覆盖结束保留修正，避免吸入 RConnect (2) 的未验证念力改动。原最终夹具与源码清单在final-input；增加boot期测试角色保护后的相同夹具在final2-input，A/B已经完成复验。B的原BeamTerrain／SATS回归通过，三个场景共74项PASS。仍待原会话联合源码候选构建、原有门禁和部署，B的结果不能外推到尚未验证的联合产物。

MSW 的红外揭示例外按 getQualifiedClassName 精确匹配原生天角兽类；MirrorHitUnit 的类型不同。普通可见目标通过不代表这一特殊分支兼容，目前不声称覆盖它。

生产 release 当前仍是 M45；候选 A/B 不是部署完成。本会话不代写原会话的最终记忆和发布状态。交付清单为 `build/r3-20261005-lightning-smart/delivery.json`，四处生产改动的M45到B补丁为同目录 `r3-production.patch`；合并时保留RConnect (2)的运动／GRIP／noBox修改，不覆盖整份GameBridge或MirrorHitUnit。
