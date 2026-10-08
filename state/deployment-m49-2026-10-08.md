# M49 / 0.2.21-dev 本机候选部署

2026-10-08 已完成。只更新本模组 release/RConnectMod.swf；游戏本体、描述符、用户存档和其他模组未改，其他56项保护指纹一致。公开下载包仍为0.2.8，本次没有推送源码或更新公开安装包。

## 本轮行为

- 死亡与重返：彻底死亡的炮塔/蜘蛛地雷同时退出原生绘制链；房间恢复不再复制链表成员标志，避免死敌重新被画出。不重复执行死亡/奖励结算。
- 个人念力设置：浮窗“设置”页增加“允许队友念力抓起我”和“被抓时 WASD 挣脱”。双方各自保存；默认允许关、挣脱开。关闭允许立即释放；关闭挣脱时移动键不会解除抓取。被抓玩家自己执行原生运动/碰撞；施法者承担原生魔力并可用E投掷。共享暂停保持握持并收齐双方停止位置。
- 松手后换目标：镜像敌人的鼠标命中标志逐帧更新，清理已离开鼠标的旧目标，继续使用原生抓取/释放。
- SATS重影：停止末帧到达后，重新拍摄原生暂停背景，同时保持选中目标和攻击队列。队友暂停显示也收齐最终位置。

## 验证

最终冻结 build/m49/final-lifecycle-16：54源文件、163验证输入、53生产类，实际生产编译于10。源及候选字节始终一致；后续只修独立测试时序与诊断。18组保留实际原始运行（10四组、14两组、15十二组），16新跑武器与连续性两组；保留依据包含实际driver类表与全部编译/运行/配置/模板依赖，未冒充重新运行。

20组、2095 PASS / 0 FAIL、全部双端DONE。审计证据：[m49-validation-evidence.json](../knowledge/experiments/m49-validation-evidence.json)。正常游戏加载（无测试驱动、全已安装模组、150秒上限）3611e15340通过；最终40个专项及2个正常加载实例PID均退出。各原始失败、负控与快照均保留。

| 专项 | 原始运行 | 结果 |
|---|---|---|
| TelekinesisMotionTestDoc | d90b29e5e2 | 198 / 0，双端DONE |
| TelekinesisTestDoc | b39ea4aeed | 108 / 0，双端DONE |
| EnemyGrabTestDoc | 48fc004aea | 256 / 0，双端DONE |
| LightningSmartTestDoc | af182fb2d5 | 27 / 0，双端DONE |
| BeamTerrainTestDoc | f705a9c39d | 26 / 0，双端DONE |
| SatsTestDoc | 2f2251dde0 | 26 / 0，双端DONE |
| CoopPauseTestDoc | fa7f16bc5a | 438 / 0，双端DONE |
| RoomCooperationTestDoc | 0c1f00e98b | 74 / 0，双端DONE |
| ProjectileNetworkTestDoc | e13a0daa03 | 14 / 0，双端DONE |
| CombatNetworkTestDoc | e8c6489ee4 | 33 / 0，双端DONE |
| AnimationGapsTestDoc | e474432b7b | 26 / 0，双端DONE |
| GameplayNetworkTestDoc | 51f35a9df5 | 31 / 0，双端DONE |
| MirrorMaskRestoreTestDoc | d09b1f4d2a | 327 / 0，双端DONE |
| HudTestDoc | 9dba6ccf2d | 154 / 0，双端DONE |
| FastHeldTestDoc | 618d0b58a6 | 73 / 0，双端DONE |
| WeaponAngleTestDoc | aa7eb649b6 | 65 / 0，双端DONE |
| PresentationContinuityTestDoc | 6347112b03 | 20 / 0，双端DONE |
| TargetLifecycleTestDoc | 1f5ba08739 | 10 / 0，双端DONE |
| RespawnRoomTestDoc | 3376200cb2 | 27 / 0，双端DONE |
| PeerGripTestDoc | 3d74518763 | 162 / 0，双端DONE |

已安装20负控确认：SATS背景位置差24.5px、旧敌人换抓失败，死机器两轮复活/重返6项失败。最终SATS原生位图位置差0px，换抓与死亡重返均绿。新增队友念力12个双向场景包含拒绝/允许、挣脱/不挣脱、撤销、真实E投掷和共享暂停；实际E曾发现冲量漏传，已在化身原生step前转交给被抓玩家。

快速念力四场景延迟100–140ms；原生容器两方向空中最长停顿0/45ms；稳定暂停位置差与恢复跳变均0px。武器七角度双向零错误、开火可见。14张恢复图片未发现已定义白块；24张HUD图片，目视个人开关与透明度显示，外框仍为240高。这些指标对应受控场景，不等于整体FPS、真人操作或所有动画已被证明。

测试过程中修正了独立驱动的投掷检查竞争、按墙钟跳过原生物理帧、先抓起再让对端检查地面，以及一端提前停止维持枪械输入的问题；未降低原位移/落地/释放/零错误要求。12有1131ms整帧中断，13单次首箱通道等待超时未重现；15的两帧武器错误缺逐帧轴值，不能倒推完全由夹具解释。最终16有额外轴日志、700ms以后源角度无变化且零错误；历史失败未被改为绿色。详见[调查记录](../knowledge/experiments/2026-10-08-m49-target-lifecycle.md)。

## 安装与回滚

- 当前文件：release/RConnectMod.swf，131147字节，SHA256 `5c372cf5d970212f0fd4e95bea5c0acfaabfe321c3ca531c80ed7e299c2914bd`。
- 上一20唯一备份：build/backup/m49-release-20261008-232026-727eb9/RConnectMod.before.swf。
- 上一20 SHA256：`77e3886f7f76885db35558ba7da4a591ec486ab65faab37f95c14116d67bb3ee`。
- 使用新版：双方先保存，彻底退出并重启游戏；现有进程不会热更新。
- 回滚：双方保存退出，将上述备份复制到release/RConnectMod.swf，再重启；不回退角色保存。
- 本次收尾：build/m49/final-lifecycle-16/closeout.json；部署和正常加载收据也在该目录。

## 边界与发布门禁

同机隔离双人、1.02与当前已安装模组组合。密集场景整体卡顿、长期运行稳定性、真实鼠标/中文输入法仍需实测；M43背景门后宿主控制丢失的原报告仍未稳定复现，不以本次死亡清链宣称已解决。稳定重连、公网、三人以上与其他版本不在范围。本次没有新增跨游戏随机房完整战斗保存。

构建/类表 → 版本21 → 同字节20组 → 既有候选部署授权 → 游戏本体未改（loader补丁不适用） → 唯一20备份 → 本模组部署 → 正常加载通过 → 回滚记录 → MEMORY/journal及本版本记录 → 本地提交并确认干净。不推送。
