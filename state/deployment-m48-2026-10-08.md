# 0.2.20-dev 部署记录

2026-10-08，本机候选已部署并通过正常双端加载。双方保存后完全退出并重启游戏；可继续用Start-Coop.bat。未推送或制作分发包。

## 修复

- 念力及队友高频移动使用有界平滑曲线，减小每次收包时的速度折角；不预测未知位置、不增加既有缓冲。快速原生箱/掉落双向110–120ms，未超过既有160ms要求。
- 普通新生、飞行中掉落改用约20Hz的位置更新，首个坐标立即起播，落地补500ms尾段；完整场景仍负责存在性与删除。持有物保留原归属路径，部分运动消息不删除静止物品。原生开箱对照空中停顿由273/220ms降至最终0/53ms。
- 共享SATS暂停时收齐已收到的敌人停止位置，同时对齐可攻击代理及原生选敌图层；保留选择/攻击队列。稳定暂停位置差及恢复跳变从约30px降到0；最后数据包到达前仍可能短暂有位置差，不能宣称瞬时零网络延迟。

## 验证

最终冻结build/m48/final-continuity-02：53生产源/156验证输入/52类。实际生产编译及17组运行在final-continuity-01，02只修正审计读数语义（initialGap是endpoint消息到达瞬间；正确稳定值为abs(pausedX-endpoint)）并增加保留运行核对工具。生产、原生测试、构建/运行依赖、配置和真实角色模板完全相同；candidate-reuse.json及carried-checks.json记录出处，没有重跑或冒充新运行。原始01、负控与探针全部保留。

| 入口 | 双端run | 宿主PASS | 加入PASS | FAIL |
|---|---|---:|---:|---:|
| TelekinesisMotionTestDoc | 4f1a2ef2a6 | 110 | 88 | 0 |
| TelekinesisTestDoc | 0842df6149 | 53 | 55 | 0 |
| EnemyGrabTestDoc | b383c86c67 | 115 | 141 | 0 |
| LightningSmartTestDoc | 1b078625c7 | 10 | 17 | 0 |
| BeamTerrainTestDoc | 68e5e5fff0 | 17 | 9 | 0 |
| SatsTestDoc | 5f6ce0104c | 3 | 23 | 0 |
| CoopPauseTestDoc | 3143828fd6 | 217 | 221 | 0 |
| RoomCooperationTestDoc | 5abf71a389 | 22 | 52 | 0 |
| ProjectileNetworkTestDoc | 982a0fd0ed | 9 | 5 | 0 |
| CombatNetworkTestDoc | 1c36e12776 | 22 | 11 | 0 |
| AnimationGapsTestDoc | a5a0b7d33e | 17 | 9 | 0 |
| GameplayNetworkTestDoc | 91ebce7651 | 27 | 4 | 0 |
| MirrorMaskRestoreTestDoc | 9dae1733da | 163 | 164 | 0 |
| HudTestDoc | 5e5e2bc327 | 69 | 69 | 0 |
| FastHeldTestDoc | 23d4d17633 | 37 | 36 | 0 |
| WeaponAngleTestDoc | 4074a94c30 | 36 | 29 | 0 |
| PresentationContinuityTestDoc | 8358dbf884 | 5 | 15 | 0 |

合计17组1880 PASS/0 FAIL，各端DONE。正常无驱动全模组启动752a939f9e持续150秒，版本20、心跳与世界匹配通过。34个最终专项及2个冒烟自有游戏PID退出；其他56项保护文件未变。游戏SWF、描述符、其他模组和用户存档未修改。

原生HUD回归24张PNG，目视宿主70%、加入40%和小窗200%；显示恢复14张PNG无既定白块。原生SATS选敌/命中、完整共享暂停队列、伤害、弹道、敌人抓取、抢持/释放、掉落单份仲裁、容器、房间进度、UI均通过。

因果对照：19/bd9ceaf401有7条预期问题红；只修暂停c8d15f6da4后暂停本体/图层/恢复绿，但速度/掉落仍红；只再加曲线78545f377c后速度绿、掉落仍红；再加活动掉落路径dbe366d129专项全绿。曲线固定20Hz轨迹57个边界的速度突变0.08810→0.002647px/ms，位置始终在已收端点范围内。这不是全场景FPS对照。最初CIM受限/GBK解码及独立测试语法失败未作为有效负控，原件保留。

证据：[完整验证](../knowledge/experiments/m48-validation-evidence.json)、[调查记录](../knowledge/experiments/2026-10-08-m48-presentation-continuity.md)。

## 边界

游戏1.02同机双人实测；稳定重连、三人以上、公网、其他游戏版本不在本轮范围。受控移动敌人隔离显示问题，不能替代全部自主AI或第三方动画测试。密集战斗整体卡顿、背景门后宿主失控/死敌重现保持原已知状态；不因本轮绿色宣称这些全部修复。实体鼠标/中文IME仍需玩家实测。

## 安装与回滚

- release/RConnectMod.swf：126293字节，SHA256 `77e3886f7f76885db35558ba7da4a591ec486ab65faab37f95c14116d67bb3ee`。
- 上一19备份：build/backup/m48-release-20261008-164301-39b69b/RConnectMod.before.swf。
- 上一19 SHA256：`4008999be4c15a84ae6975115886fe481983c5b1c4151197c5795b57c2a2de6a`。
- 回滚只恢复模组：双方保存退出，复制该备份到release/RConnectMod.swf，再重启；不回退角色存档。

## 发布门禁

构建/生产类表 → 版本20 → 同字节17组 → 既有候选部署授权 → 游戏文件未改（loader核对不适用） → 唯一备份 → 本模组部署 → 正常加载通过 → 本记录回滚路径 → MEMORY/journal → 本版本记录（无既有changelog） → 本地提交并确认干净。无外部推送。
