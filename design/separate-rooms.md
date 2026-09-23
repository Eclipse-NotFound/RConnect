# 同地图分房合作：调查与待定方案

2026-09-24。用户请求修复加入侧炮塔，并增加双方处于不同房间的功能；点名 grilling。本文是调查结果和方案前沿，**不是已实现功能**。

## 用户决定

- Q1 已选：同一张地图内分房间；本轮不做跨地图各自行动。
- Q2 待答：无人房暂停并保留战斗/破坏/门箱状态，还是保留原版重置。
- Q3 待答：只有宿主发起共同换图，还是任一方都能发起。
- Q4 待答：普通房分头、剧情/挑战共同进入，还是扩大到任务/挑战同步。
- 既有范围：允许大幅重构和候选部署；不新增任务/背包/交易规则，不做稳定重连、三人以上、公网和其他版本。新决定只能由用户改变范围。
- 上述待答项解决后概括具体玩法，请用户按 grilling 确认共同理解再实施；不能把沉默当作选了推荐。

## 已核对的机制

1. `Session.handleMessage(MSG_UNITSYNC)` 持续执行 `followHostWorld`；同地图异房会调用 `Land.gotoXY` 并把加入玩家放到宿主位置。同房首次距离较大还会位置对齐。配置 autoFollow 默认开启。
2. 伤害、门箱、掉落、瓦片请求和快照全部依赖双方同房。关跟随不会自动得到独立战斗与状态合并。队友化身在异房移除的现有逻辑可保留。
3. 原生 `Land.step` 完整运行当前房，前一房仅短暂 `stepInvis`。`Location.step` 会推进全局玩家，视线方法访问 `World.w.loc`，奖励访问 `World.w.pers`。不能直接在宿主遍历两个 Location.step。
4. `Land.locs/probs` 保留房间引用，但没有完整 Location.save/load。Unit/Box.save 主要保存死亡与交互；随机 Land.saveObjs 不落这些状态。重返 Location.reactivate 会调用 Unit.setNull(true)，可回血、回甲、回出生点。
5. 当前镜像单位固定难度100创建，并设置 doop/unres/disabled，不能直接解冻当作可执行敌人。Unit.mapxml/aiState 为 internal，动态访问不可用。优先保留原生实例；新增可执行单位须有准确构造和战斗数据。同包访问器加外部存根的方案尚未验证。
6. 挑战子房可能同名 loc0_0，身份必须包含 landProb 和地图生成世代。地图层数/房间名不能区分一次重建。现 M13 几何种子补丁和 landStage 采纳只约束布局，敌人和掉落仍可能随机。
7. Unit.runScript 会推进任务、死亡脚本和挑战波次，现单位/场景协议没有这些状态。这是 Q4 的实际取舍依据。

原生依据：1.02 的 `fe.loc.Land.step/saveObjs/activateLoc`、`fe.loc.Location.step/reactivate/saveObjs/isLine`、`fe.unit.Unit.setNull/save/runScript`。本地接点：Session 的 MSG_UNITSYNC/sameHostRoom/MSG_PLAYERDMG，GameBridge 的 followHostWorld/reconcileWorld/spawnUnitPuppet，ObjectIdentity.enter、TerrainSync.enter 及 Loot 身份表。

## 建议实现结构（未批准、未实测）

宿主维护按地图实例、挑战区域、X/Y/Z 索引的 RoomRecord：归属端、交接世代号、快照序号、单位/箱门/掉落/地形及原生可存状态。每个房间保留自己的实例身份、地形基线和请求回执，显示插值可随当前房重建。

分房时各端运行所在房原生战斗；同房由宿主结算。交接先冻结原归属，收最终完整状态，新归属应用并确认后再启用战斗。逐帧检测房间切换；还需防旧房 stepInvis 在离开后继续改变状态。

所有状态/伤害/交互包绑定 roomKey + authorityTerm，拒绝旧房或旧归属迟到请求。现 playerdmg 仅含 dmg，尤其需要补这一门槛。完整快照必须允许 units=[] 表示已清空；现 reconcileWorld 的空列表保护不能沿用为完整交接语义。

单位恢复不能只写 HP 和打开 disabled；需还原真实构造、装备、奖励和行为标志。地形交接须完整状态及几何核对；现差分适合同源几何，不能当任意不同地图的转换器。固定图可保存 code 状态应同步宿主实际缓存对象，防自动保存再覆盖；跨游戏退出保存随机房完整战斗状态目前没有承诺。

## 实现验收前沿

- 两人异房不被拉回，双方敌人均正常攻击、受伤和死亡。
- 加入侧独房击杀、破墙、搜刮后宿主进入，结果保留且不重复掉落。
- 同时换房、互换房间、合流时的在途伤害和断线期间归属不重复。
- 空敌人房间重访、原生 reactivation 回血覆盖、同坐标不同挑战防串房。
- 同地图重生成世代、共同换图、死亡回城、原生保存边界。
- 保留既有共享探索、动作平滑、护甲、轻机枪/天角兽伤害及炮塔显示回归。

必须先实现准确房态与交接，再取消同图强制跟随；单独配置 autoFollow=0 不作为交付。
