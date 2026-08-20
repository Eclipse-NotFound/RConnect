# 实验：M15 双存档下随机图布局差异（landStage）与幽灵趴姿——2026-08-20

- 游戏版本：1.02（双实例，马哈顿 random_mane）
- 用户报告：双方"继续游戏"进入马哈顿，房间布局仍不一样（但能互相看见）；
  幽灵在对方视角固定为趴姿。

## M15a：双存档布局差异 = landStage（随存档持久化）

- 现象：M13 种子补丁后，host-新档+join-读档场景 8 点 grid 全一致；但
  **双方都读档**场景首采样点不一致（host=墙/join=地）。
- 根因：`LandAct.landStage` **随存档持久化**（save/load 序列化 st 字段），
  而 `newRandomLoc(landStage,...)` 用它过滤房间池（`_loc8_.lvl <= landStage`）。
  双方存档 landStage 不同（实测 join=4, host=0）→ 种子虽同、**池不同** →
  选出不同房间模板。M13 只对"同生成输入"保证确定性。
- 修复：worldInfo 携带宿主 landStage/visited；加入方旅行到 rnd 土地前
  `adoptHostLandParams`（采纳宿主 landStage + `act.land=null` 强制重建）；
  同土地内若 stage 不一致也采纳并 `gotoLand` 重入重建（_adoptedSame 防循环）。
- 验证：双存档场景采纳 `landStage 4 -> 0` 后，**两侧 8 点 grid 全一致**
  （多次复现）；host-新档场景同样 8/8。

## M15b：幽灵"固定趴姿" = 被击倒/击杀后的尸体姿态

- 诊断：幽灵 osn 标签与本地玩家一致（均 lbl=stay fr=1——站姿正确），
  动画切换正常（M14a 已修）；怀疑点为幽灵在宿主世界被敌人击倒/击杀后
  sost≥2 → 游戏画倒地/尸体帧，且 driveGhost 不重置 → "固定趴姿"。
- 修复：driveGhost 每帧强制 `ghost.sost = 1`（化身是镜象，姿态由快照
  标签驱动；血量死亡流程仍由 scanGhostHp 重建处理）。
- 验证：幽灵 sost 恒 1；战斗回归正常（applied/relayed/took/died/revived）。

## 教训

- 确定性种子只保证"同一生成输入 → 同一输出"；凡**随存档变化的生成输入**
  （landStage、visited 等）必须显式采纳宿主值并强制重建（act.land=null
  + gotoLand 重入），否则联机布局仍会分歧。
- 镜象单位的 sost 等"本体状态"必须由远端快照驱动，不能放任宿主世界
  的战斗副作用污染（尸体/倒地姿态）。
