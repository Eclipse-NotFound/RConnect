# M50 / 0.2.22-dev 本机候选部署

2026-10-09已完成。仅更新本模组release/RConnectMod.swf；正常加载双端检查7ec5eb4ec4通过。游戏本体、描述符、玩家存档和其它模组未修改，155项外部保护指纹一致。公开安装包及玩家文档仍对应0.2.8，本次不推送。

## 本轮行为

- 队友外观与枪械：同步真实翅膀状态，避免未使用飞行药水也出现翅膀；武器采用原生旋转、翻转及后坐姿态，弹道按实际枪口和原生显示帧重放。换枪后的在途弹继续显示，接收侧不再执行一次攻击。
- 动画衔接：主动念力搬运使用100ms目标缓冲；自动掉落接收突发数据时保留已收到的轨迹，避免直接跳到批末。火焰存续期间让角色、枪口和火焰共用时钟以正常速率推进，结束后恢复渐进追赶；不预测未收到的位置。
- 同步效果与合作回归：集成并验证近战、爆炸、重型弹、能量命中、火焰/燃烧、墙痕、传送、护盾/隐身等身体效果；玩家地雷保持宿主权威，换房重返时恢复到当前显示层。友伤及个人投掷伤害默认关闭；跟随恢复和队友导航一并验证。
- 减少地形同步扫描的临时对象：先比较13个字段，仅对变化格生成快照。固定分配计数改善不等于整体FPS保证。

紧凑浮窗、个人透明度、被抓许可/WASD挣脱设置沿用已部署实现；本轮未新增任务、背包或交易同步规则。

## 验证依据

最终冻结build/m50/final-presentation-30：69源文件、197验证输入、68生产类，163453字节。生产实际编译于final27；之后只修独立测试的观察前提和启动确认，生产字节一致。30按实际驱动类表、编译依赖、运行资源、配置及原日志指纹严格保留29的37组成功，新增跟随4ce63cbedf；这些保留记录没有冒充新运行。

**38组、4760 PASS / 0 FAIL，全部双端DONE。** [完整审计](../knowledge/experiments/m50-validation-evidence.json)绑定源、候选、独立驱动、实际运行配置、150张PNG及原21对照。14张恢复截图无已定义白块；抽看HUD折叠/透明度、小窗压力、火焰、隐身轮廓和护盾图片。没有把全部150图称作逐张人工检查。

原21负控051e28e849双向七角度14项假翼、14项弹道几何失败，两端正常结束；只证明原始两类症状可被捕获。最终候选相应检查通过。正常加载7ec5eb4ec4不使用测试驱动，加载全已安装模组，双方显示v0.2.22-dev，心跳与加入握手通过（150秒上限）；开局没有敌人时单位同步为0/0，不能拿这次启动检查替代战斗专项。

| 专项 | 原始运行 | PASS / FAIL |
|---|---|---|
| TelekinesisMotionTestDoc | 60474944d6 | 198 / 0 |
| TelekinesisTestDoc | 080a67b242 | 108 / 0 |
| EnemyGrabTestDoc | 18c879b0df | 256 / 0 |
| LightningSmartTestDoc | 2b57275a3d | 27 / 0 |
| BeamTerrainTestDoc | 92a41bac2d | 31 / 0 |
| SatsTestDoc | 82c82d53d5 | 26 / 0 |
| CoopPauseTestDoc | 81c88e2749 | 438 / 0 |
| RoomCooperationTestDoc | 809a4c5eb8 | 74 / 0 |
| ProjectileNetworkTestDoc | 68219316d5 | 14 / 0 |
| CombatNetworkTestDoc | 05f0e62a5a | 33 / 0 |
| AnimationGapsTestDoc | 61325d39ca | 27 / 0 |
| GameplayNetworkTestDoc | 91254387bb | 31 / 0 |
| MirrorMaskRestoreTestDoc | 5e23aa560b | 327 / 0 |
| HudTestDoc | 2adbb14e60 | 154 / 0 |
| FastHeldTestDoc | 907ae9aea7 | 85 / 0 |
| WeaponAngleTestDoc | 243bb969d2 | 79 / 0 |
| PresentationContinuityTestDoc | 75da417cd1 | 34 / 0 |
| TargetLifecycleTestDoc | 2e7b88935a | 10 / 0 |
| RespawnRoomTestDoc | 93ab06d2c8 | 27 / 0 |
| PeerGripTestDoc | 621ba42a7d | 162 / 0 |
| PeerVisualTestDoc | 9bca2158ee | 106 / 0 |
| FriendlyFireTestDoc | 6fa7d25236 | 180 / 0 |
| ExplosiveVisualTestDoc | a87de7c21b | 248 / 0 |
| HeavyProjectileTestDoc | 31b20e8ba0 | 82 / 0 |
| MeleeAnimationTestDoc | fab12f811c | 234 / 0 |
| EnergyImpactTestDoc | 4f59704d28 | 221 / 0 |
| FlameVisualTestDoc | 0e4162cfc5 | 264 / 0 |
| MineSyncTestDoc | e28a6a1289 | 55 / 0 |
| MineRoomTestDoc | d041a47263 | 29 / 0 |
| BurnVisualTestDoc | 5f768c073f | 31 / 0 |
| WallImpactTestDoc | 1a257a900d | 118 / 0 |
| TeleportVisualTestDoc | 2d0163af99 | 284 / 0 |
| PeerThrowDamageTestDoc | 7e8ba19dc0 | 278 / 0 |
| BodyEffectsTestDoc | 724b8382d3 | 264 / 0 |
| FollowRecoveryTestDoc | aa45e6ec8b | 53 / 0 |
| FollowNetworkTestDoc | 4ce63cbedf | 10 / 0 |
| TeammateNavigationTestDoc | f0326bb2d1 | 55 / 0 |
| HiddenRoomFollowTestDoc | 7bd8ef26b0 | 107 / 0 |

受控场景结果：快速搬运四方向延迟110/110/100/90ms；两次原生容器掉落空中最长停顿0/30ms；SATS稳定停止位置差0px、解除后跳变0px。双向七角度武器对照通过，火焰原九场景双向时长/几何及新增六项时钟边界通过。轻机枪对尸鬼单次伤害原生与加入侧均为45；五类炮塔实际检测、发射和伤害检查通过。

80敌人压力场景8秒88帧、帧间隔p95 133ms，满足本轮原门槛，但这是单轮受控结果，不能声称大量敌人已稳定流畅。保留其他程序、未调整其优先级/亲和性；WallBlend新测试出现时下一组守卫暂停，未联系或操作它。保留的近战fab12f811c末段与该实例重叠，原功能断言通过，但不作为控制负载下的性能结论。

## 失败与测试修正

全部历史失败和诊断保留，详见[验证过程](validation-m50-2026-10-09.md)。正式29的FollowNetwork在准备确认阶段超时，受控迟监听旧夹具复现、新夹具完成全部原断言；正式30另行验证，未用诊断代替发行证据。[启动确认实验](../knowledge/experiments/2026-10-09-follow-fixture-startup.md)。

PeerGrip曾把松手几秒后余额当作扣费依据，已改为真实持有期间观测法力下降，原抓取/许可/挣脱/投掷/暂停/释放断言及时间窗保留；这不是游戏法力修复。[法力实验](../knowledge/experiments/2026-10-09-peer-grip-mana-observation.md)。武器角度曾遇宿主原生与远端坐标轴同时为零，三次诊断未复现；新增原生坐标有效性检查后正式通过，不宣称原零轴原因已修复。[坐标实验](../knowledge/experiments/2026-10-09-native-coordinate-precondition.md)。

## 安装与回滚

- 当前release/RConnectMod.swf：163453字节，SHA256 `32602e77a21b206d1f7ff0e927b953878c28254e7201529455818923a3539732`。
- 上一21唯一备份：build/backup/m50-release-20261009-182002-d83866/RConnectMod.before.swf，SHA256 `5c372cf5d970212f0fd4e95bea5c0acfaabfe321c3ca531c80ed7e299c2914bd`。
- 部署及正常加载收据：build/m50/final-presentation-30/deployment.json；收尾：同目录closeout.json。
- 最终38组、原21对照和正常启动共80个实例描述符已核对退出；实际宿主AIR为空。检查来源是获准实际宿主CIM，未用沙箱空列表代替。
- 使用新版：双方彻底退出并重新启动游戏；已有进程不会热更新。
- 回滚：双方保存退出，把上述唯一21备份复制回release/RConnectMod.swf，再重启。不回退角色保存。M49备份属于旧20，不用于本次回滚。

## 边界与门禁

验证范围为本机双实例、1.02与当前安装的模组组合。长局密集卡顿仍待真人验证；背景门原“宿主消失或失控”低频报告未可靠复现，不能由本次受控往返通过断言其已彻底解决。镜像地雷拾取/拆除/枪击/念力交互、旧Trap/Area #1063以及其它未覆盖组合仍有边界；没有保证所有历史错误全部消失。稳定重连、公网、三人以上、其它游戏版本和新的任务/背包/交易系统不在本轮。

构建/类表 → 版本22 → 同字节38组与原21负控 → 用户既有部署授权 → 游戏本体未改 → 唯一21备份 → 本模组部署 → 正常加载通过 → 回滚记录 → MEMORY/journal及本版本记录 → 本地提交并确认干净。正常加载失败的自动回滚未触发。
