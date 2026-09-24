# 同地图分房合作：决定与实现

2026-09-24。用户请求修复加入侧炮塔，并增加双方处于不同房间的功能；点名 grilling。玩法已获Q1–Q5确认。M36候选已实现，安装版状态与最新验证以state/MEMORY.md为准。

## 用户决定（2026-09-24 已完成共同理解确认）

- Q1 已选：同一张地图内分房间；本轮不做跨地图各自行动。
- Q2 已选：无人房暂停并保留战斗、破坏和门箱进度。
- Q3 已选：由宿主发起共同换图，加入侧跨图出口提示并阻止单独换图。
- Q4 已选：普通房分头，剧情/挑战共同进入；不扩大到任务/挑战同步。
- Q5 最终共同理解已确认：本次联机内离房重访保留进度，关闭游戏沿用原版保存，不新增随机房完整战斗存档。
- 既有范围：允许大幅重构和候选部署；不新增任务/背包/交易规则，不做稳定重连、三人以上、公网和其他版本。新决定只能由用户改变范围。
- 用户已明确“符合，按此实现”，开始实施；不重复请求相同许可。

## 已核对的机制

1. `Session.handleMessage(MSG_UNITSYNC)` 持续执行 `followHostWorld`；同地图异房会调用 `Land.gotoXY` 并把加入玩家放到宿主位置。同房首次距离较大还会位置对齐。配置 autoFollow 默认开启。
2. 伤害、门箱、掉落、瓦片请求和快照全部依赖双方同房。关跟随不会自动得到独立战斗与状态合并。队友化身在异房移除的现有逻辑可保留。
3. 原生 `Land.step` 完整运行当前房，前一房仅短暂 `stepInvis`。`Location.step` 会推进全局玩家，视线方法访问 `World.w.loc`，奖励访问 `World.w.pers`。不能直接在宿主遍历两个 Location.step。
4. `Land.locs/probs` 保留房间引用，但没有完整 Location.save/load。Unit/Box.save 主要保存死亡与交互；随机 Land.saveObjs 不落这些状态。重返 Location.reactivate 会调用 Unit.setNull(true)，可回血、回甲、回出生点。
5. 当前镜像单位固定难度100创建，并设置 doop/unres/disabled，不能直接解冻当作可执行敌人。Unit.mapxml/aiState 为 internal，动态访问不可用。优先保留原生实例；新增可执行单位须有准确构造和战斗数据。同包访问器加外部存根方案已由4118f518e5在双实例验证。
6. 挑战子房可能同名 loc0_0，身份必须包含 landProb 和地图生成世代。地图层数/房间名不能区分一次重建。现 M13 几何种子补丁和 landStage 采纳只约束布局，敌人和掉落仍可能随机。
7. Unit.runScript 会推进任务、死亡脚本和挑战波次，现单位/场景协议没有这些状态。这是 Q4 的实际取舍依据。

原生依据：1.02 的 `fe.loc.Land.step/saveObjs/activateLoc`、`fe.loc.Location.step/reactivate/saveObjs/isLine`、`fe.unit.Unit.setNull/save/runScript`。本地接点：Session 的 MSG_UNITSYNC/sameHostRoom/MSG_PLAYERDMG，GameBridge 的 followHostWorld/reconcileWorld/spawnUnitPuppet，ObjectIdentity.enter、TerrainSync.enter 及 Loot 身份表。

## 已实现结构

RoomSync在宿主维护按地图实例、挑战区域、X/Y/Z索引的房间记录：归属端、交接世代号、单位/箱门/掉落/地形及原生标量。ObjectIdentity保留各房原生对象键；地形和显示插值基线在交接时重建。完整状态用RoomCodec压缩。

分房时各端运行所在房原生战斗；同房由宿主结算。交接先冻结原归属，收最终完整状态，新归属应用并确认后再启用战斗。原生帧前后检测房间切换，loc_t置零，阻止旧房stepInvis。旧房未确认批次后的全部瓦片伤害通过有序连接先发完再提交状态，不能只发一批。

状态/伤害/交互包绑定roomEpoch + roomKey + roomTerm，拒绝旧地图、旧房或旧归属迟到请求；playerdmg也带这一门槛。交接期间允许尚未结算的玩家受伤回执按旧房身份处理。完整快照允许units=[]表示已清空。

NativeRoomState与fe.unit/fe.serv同包访问器恢复真实构造、装备、奖励和行为标量。首次独房保留原生实例，另一端交来的敌人按实际难度重建；捕兽夹使用null构造，隐藏炮塔保留原生底座。地形交接校验尺寸并恢复完整瓦片。保存沿用原版，不新增跨游戏退出的随机房战斗存档。

TravelGuard在按钮消耗卷轴前拦截独立换图，限制挑战/脚本出口；宿主换层创建新地图世代。挑战共同进出，加入侧入口脚本与波次提前停用；宿主随机选择的挑战在加入侧缺失时按原生流程补建。

## 验证范围

- 两人异房不被拉回，双方敌人均正常攻击、受伤和死亡。
- 加入侧独房击杀、破墙、搜刮后宿主进入，结果保留且不重复掉落。
- 覆盖合流、离开后的归属转移、连续破墙后立刻交接及旧批次过滤；同时互换房和失联交接未穷举。
- 空敌人房间重访、原生 reactivation 回血覆盖、同坐标不同挑战防串房。
- 覆盖同地图重生成世代、共同旅行、地图/卷轴入口拦截；所有死亡回城时序和跨游戏保存未做新承诺。
- 保留既有共享探索、动作平滑、护甲、轻机枪/天角兽伤害及炮塔显示回归。

原生依据、失败、最终候选回归及部署见 `../knowledge/experiments/2026-09-24-m36-separate-rooms.md`。分房由交接协议管理，玩家无需关闭autoFollow。
