# 0.2.18-dev 部署记录

2026-10-07，本机候选已部署，正常无驱动双端加载通过。双方保存后完全退出并重启游戏；可继续使用Start-Coop.bat。未推送或制作分发包。

## 变化

- 保留紧凑浮窗：常驻280×36，通常展开280×240，连接/队友/聊天/设置四页，内部滚动、标题拖动、四角停靠和各自保存位置/开合。F10隐藏/恢复；Ctrl+Enter开聊、输入框Enter发送、Esc收起。原版菜单与Enter全屏优先，暂停提示独立显示。
- 念力旧续报不再解除NPC的新抓持；保留原版新Q抢握、耗魔、重量和抵抗规则。同步武器/物品的真实光晕与颜色。
- 源时钟改善时同时换算播放位置，避免交接后累计显示旧武器/光晕；共享暂停收到末帧后收齐掉落位置，恢复不倒播。
- 天角兽闪电同步真实显示轨迹和结束帧；镜像受击代理保持原生可见/目标资格，以供SATS与智能武器使用，不运行第二份AI。
- 共用显示遮罩只隐藏已归属的孤立副本，退出/换房/字段重建时保留仍存活的原生本体、血条与武器遮罩。原生引用无法安全还原时使用自有过渡图形，不释放其他模组的位图存储。

生产源52项/51个AS类，验证146项；最终冻结build/m46/final-after-ui-clock-05。实际编译出处clock-01，后续仅测试/审计输入修正时复用完全相同的52源与SWF，收据如实标记。NetHud/HudLayout与已安装UI17冻结字节相同。

## 验证

| 入口 | 双端run | 宿主PASS | 加入PASS | FAIL |
|---|---|---:|---:|---:|
| TelekinesisMotionTestDoc | 7864d5dd3d | 110 | 88 | 0 |
| TelekinesisTestDoc | ed10646da7 | 53 | 55 | 0 |
| EnemyGrabTestDoc | 95b90c5dcd | 96 | 115 | 0 |
| LightningSmartTestDoc | 79415bd76c | 10 | 17 | 0 |
| BeamTerrainTestDoc | 971dee243c | 17 | 9 | 0 |
| SatsTestDoc | aeab107386 | 3 | 23 | 0 |
| CoopPauseTestDoc | b4984a006a | 217 | 221 | 0 |
| RoomCooperationTestDoc | 0270e725e1 | 22 | 52 | 0 |
| ProjectileNetworkTestDoc | a5d5105cae | 7 | 3 | 0 |
| CombatNetworkTestDoc | f42326ba96 | 22 | 11 | 0 |
| AnimationGapsTestDoc | c2b1cebb60 | 17 | 9 | 0 |
| GameplayNetworkTestDoc | f9f71a19a9 | 27 | 4 | 0 |
| MirrorMaskRestoreTestDoc | 477e7a28b2 | 163 | 163 | 0 |
| HudTestDoc | c00c58c6a5 | 57 | 57 | 0 |

合计14组1648 PASS/0 FAIL，各端DONE；相同最终生产字节，所有编译/运行输入在启动前固定。前八组在独立夹具修正后核对源码、运行依赖、真实driver类表，保留原绿结果，不伪装为新的运行。恢复8case及14张退出即时全场景PNG通过，UI22张PNG保留并目视常驻、中文设置、小窗/200%。

独立时钟反例：原算法与固定100ms缓冲均15/3，实际共享修正类18/0。旧905原生遮罩负控8221fc329d，同一最终测试源码两端各130/33、各DONE，记录真实空vis/hpbar；它不部署。Beam的300→60夹具误发240伤害、SATS远距look0、旧Projectile手工移除闪电导致31事件帧全空，各有同生产字节红/绿控制。只修测试前提，保留原断言/时窗与失败原件。

正常无驱动加载eb84c49f11：150秒、全部已安装模组、版本18/网络心跳/世界匹配绿。32个最终专项/负控/冒烟自有游戏PID已独立确认退出，其他56项保护不变；游戏SWF、描述符、其他模组及用户存档未改。发布表格首次字段误用导致KeyError，发生在正常加载通过之后，记录与截图已完成；随后按原日志核对本表，不作游戏故障或悄然覆盖原错误。

证据：[完整验证](../knowledge/experiments/m46-validation-evidence.json)，[常驻画面](../design/ui-preview/native-0.2.18-compact.png)，[中文设置](../design/ui-preview/native-0.2.18-settings-zh.png)，[小窗口](../design/ui-preview/native-0.2.18-small-window.png)。原M45/UI17及全部M46失败证据保留。

## 边界

真人中文输入法和实体鼠标仍需实测。背景门后宿主失控/死敌重现未可靠复现或认定根因；密集战斗仍可能卡顿。当前80敌人回归88帧、p95 126ms，基础254帧/8448ms/p95 44ms仅为同候选不同负载，不是旧新版本配对，不作性能改进归因。旧错色/匿名Timer的每条因果仍未证明，不能由这轮绿宣称所有1009修复。红外特有分支、全部首领/第三方状态和任意遮罩时序未穷举。稳定重连、三人以上、公网及版本兼容仍在排除范围；只验证当前1.02同机双人。

## 安装与回滚

- release/RConnectMod.swf：123147字节，SHA256 `044382765a2340ce9babe6f3d01eb61197a438f7d1f9ea70262601535714f042`。
- 备份：build/backup/m46-release-20261007-024209-047d31/RConnectMod.before.swf。
- 上一UI17/M45 SHA256：`a5698f9f5941b27c2fd47de56366c4d867bf256b2dcb7d484596844dea093971`。
- 回滚只恢复SWF；双方先保存退出，再复制该备份回release并重启，不回滚角色保存。

```powershell
Copy-Item -LiteralPath 'D:\Program Files\Steam\steamapps\common\Remains\mods\RConnect\build\backup\m46-release-20261007-024209-047d31\RConnectMod.before.swf' -Destination 'D:\Program Files\Steam\steamapps\common\Remains\mods\RConnect\release\RConnectMod.swf'
```

## 发布门禁

构建零错/生产类清单 → 版本18 → 1648项自动验证 → 既有用户部署授权 → 游戏SWF未改（loader核对不适用） → 唯一备份 → 本模组部署 → 正常加载通过 → 上述回滚路径 → MEMORY/journal更新 → 本发布记录（无已有changelog） → 本地Git提交并确认仓库干净。未外部推送。
