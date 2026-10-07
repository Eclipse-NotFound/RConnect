# 0.2.19-dev 部署记录

2026-10-07，本机候选已部署并通过正常双端加载。双方保存后完全退出并重启游戏；仍可使用Start-Coop.bat。未推送或制作分发包。

## 变化

- 浮窗设置页可调不透明度30–100%，默认100%，减/增每次10%；焦点内方向键/Home/End可调，各角色分别保存。暂停提示保持完全不透明。保留280×36常驻条、通常280×240展开、四页、滚动、拖动和停靠。
- 活跃念力箱子/掉落物随原20Hz玩家通道更新，用100ms源时间缓冲显示；阻挡旧完整场景快照倒退位置/复活抓持，释放后交还原版速度和重力。完整场景和敌人通道频率未变，敌人托举仍走EnemyGrip。
- 对方武器使用原版实际显示姿态，包括武器自己的旋转和翻转，抵消角色父级镜像；原版工厂创建同款/变体，开火闪光在同一缓冲样本消费，不再由新弹道包抢先播放。显示路径不执行第二次攻击或伤害。

## 验证

生产53项/52个AS类，验证151项；最终冻结build/m47/final-presentation-07。实际编译在final-presentation-01，随后仅独立夹具/审计改变，53个生产源和SWF完全相同，candidate-reuse.json记录复用。十五组保留原运行（五组02、六组05、四组06）：检查实际driver类表不含改动的独立测试类，核对生产、存根、测试、运行依赖、存档与配置；不是新增运行。显示恢复组在07重新运行。

| 入口 | 双端run | 宿主PASS | 加入PASS | FAIL |
|---|---|---:|---:|---:|
| TelekinesisMotionTestDoc | beef32a462 | 110 | 88 | 0 |
| TelekinesisTestDoc | 5ebc724bd1 | 53 | 55 | 0 |
| EnemyGrabTestDoc | c0cbc2dbc5 | 115 | 141 | 0 |
| LightningSmartTestDoc | a31bc28757 | 10 | 17 | 0 |
| BeamTerrainTestDoc | 4f399ce6c8 | 17 | 9 | 0 |
| SatsTestDoc | 3c3a825c89 | 3 | 23 | 0 |
| CoopPauseTestDoc | e4bfb0ca07 | 217 | 221 | 0 |
| RoomCooperationTestDoc | dffc8ce3ac | 22 | 52 | 0 |
| ProjectileNetworkTestDoc | 72d8431c5d | 9 | 5 | 0 |
| CombatNetworkTestDoc | 8985a8de9b | 22 | 11 | 0 |
| AnimationGapsTestDoc | 64246bcc9e | 17 | 9 | 0 |
| GameplayNetworkTestDoc | 7b3fb12c4e | 27 | 4 | 0 |
| MirrorMaskRestoreTestDoc | 8bc997dac6 | 163 | 164 | 0 |
| HudTestDoc | 52601ca525 | 69 | 69 | 0 |
| FastHeldTestDoc | bef1c63bb8 | 37 | 36 | 0 |
| WeaponAngleTestDoc | 50605d6f47 | 36 | 29 | 0 |

合计16组1860 PASS/0 FAIL，各端DONE。正常无驱动加载ca43e3b445：150秒、全部已安装模组、版本19、心跳和世界匹配通过。32个最终专项和2个冒烟自有游戏PID已核对退出；其他56项保护文件不变。游戏SWF、描述符、其他模组及用户存档未改。

快速搬运同机对照：旧8cf53db5a2的箱子host→join/join→host为350/370ms，掉落物为340/350ms；最终bef1c63bb8分别140/130ms、120/110ms。来自原版抓持/实际移动/真实TCP/最终显示的曲线拟合；不用于生产预测。旧d8de7e1749原生轻机枪七角度×双端，右向对照通过、其他12例方向错误；最终50605d6f47全部方向及本机/远端开火帧通过。

失败保留：HUD256bf95f2a只因alpha断言容差低于AIR的1/256精度；独立真实AIR探针证实，只改容差。EnemyGrab bf1024bfd0/711f601d49暴露夹具只写角色瞄点、原版actions重读World鼠标，且未隔离自主AI/场景。最小原样18/9002d2885f和19/ecf7818e25均证实瞄点被改；新夹具保持原位移1/35、阻力18、时间与14案例，固定原版输入/空旷原生地面，关闭测试敌人自主控制，继承原生物理与阻力，增加落地/瞄点/负例无自主上移前提断言。bd031ffdfe为夹具误写物品专用字段#1056，删除该字段后全新冻结。Projectile3c02aaf0f5远端muzzle三红；同字节25776b546b实证两端源枪parent=null/staged=false/display=null，原测试只用fireAt造子弹。正式夹具改为完整原版工厂/addVisual/逐帧attack和step，补源枪舞台/原生shoot与子弹前提，原闪电/护盾/弹道像素/远端shoot要求及5500ms窗保留。恢复c2dcc052bd各163/0且14PNG无白块，但在真实世界帧前leave导致runner网络前提红；仅等待实际TcpLink上rooms.accepts的unitsync再退出，原326恢复断言和时间不变，最终8bc997dac6通过。未改生产以追这些夹具绿色，不覆盖失败结果。

证据：[完整验证](../knowledge/experiments/m47-validation-evidence.json)、[调查记录](../knowledge/experiments/2026-10-07-m47-opacity-held-weapons.md)、[宿主70%](../design/ui-preview/native-0.2.19-opacity-70.png)、[加入侧40%中文](../design/ui-preview/native-0.2.19-opacity-40-zh.png)。HUD各69项通过、24张原生PNG；目视两端不透明度及小窗200%。

## 边界

上述延迟来自1.02同机双人，不能推断公网或所有高负载下同样改善。武器专项为原生轻机枪，未穷举所有特殊武器、连续扫过翻转边界及第三方动画。真人实体鼠标/中文输入法仍需实测。背景门后宿主失控/死敌重现和密集战斗卡顿仍保持原状态；本轮不声称全部修复或普遍提高帧率。稳定重连、三人以上、真实网络和版本兼容不在本轮范围。

## 安装与回滚

- release/RConnectMod.swf：125466字节，SHA256 `4008999be4c15a84ae6975115886fe481983c5b1c4151197c5795b57c2a2de6a`。
- 备份：build/backup/m47-release-20261007-184315-8618b6/RConnectMod.before.swf。
- 上一18 SHA256：`044382765a2340ce9babe6f3d01eb61197a438f7d1f9ea70262601535714f042`。
- 回滚只恢复模组SWF：双方保存退出，复制该备份至release/RConnectMod.swf，再完全重启；不回退角色保存。

```powershell
Copy-Item -LiteralPath 'D:\Program Files\Steam\steamapps\common\Remains\mods\RConnect\build\backup\m47-release-20261007-184315-8618b6\RConnectMod.before.swf' -Destination 'D:\Program Files\Steam\steamapps\common\Remains\mods\RConnect\release\RConnectMod.swf'
```

## 发布门禁

构建/生产类表 → 版本19 → 全部自动验证 → 既有候选部署授权 → 游戏文件未改（loader核对不适用） → 唯一备份 → 本模组部署 → 正常加载通过 → 回滚路径 → MEMORY/journal → 本版本记录（无已有changelog） → 本地Git提交并确认干净。无外部推送。
