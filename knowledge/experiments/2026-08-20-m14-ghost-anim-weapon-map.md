# 实验：M14 幽灵动画修复 + 武器/探索迷雾同步——2026-08-20

- 游戏版本：1.02（双实例 pfe2=host / pfe3=join，马哈顿 random_mane）
- 用户报告：能看到对方、移动同步；但看不到对方的走路动画与武器，且
  当前房间"地图"（探索迷雾）两侧不同。

## M14a：幽灵走路动画自 M6b 起失效（已修）

- **根因**：M6b 给幽灵加名字标签时，把标签引用存在**密封类** UnitPonPon
  实例上（`ghost["_rconnect_label"]`）。`driveGhost` 里读取该字段每次抛
  `#1069`（密封类无此属性）→ try 整体中断 → **`driveVisAnim` 从未运行**，
  幽灵动画标签从不切换（走/跑/跳全静止）。自动化只验证过 blit 单位
  animate()，从未检查幽灵 osn 标签，故多轮未暴露。
- **修复**：标签引用改存到**动态类 vis**（visualPlayer 是 MovieClip=动态）
  上；driveGhost 从 vis 读。另把 driveGhost 的静默 catch 改为每 id 一次
  错误日志（定位类 bug）。
- **验证**：M2_WALK 真机——宿主侧幽灵动画切换 **236 次**（walk/stay/
  jump 真实切换），driveGhost 0 错误。

## M14b：武器镜像（新增）

- 快照带 `wi/wv`（currentWeapon.id / variant）；幽灵侧用公开构造
  `new Weapon(owner=ghost, id, variant)`（Weapon 从游戏数据按 id 取参数与
  视觉），把 `w.vis` 挂到幽灵 visualPlayer 手上；每帧按快照 storona/aim
  校正位置与旋转；武器变化重建、失败黑名单。
- **验证**：宿主侧 `weapon #1 -> lmg` 构造成功、无失败日志。

## M14c：探索迷雾同步（新增）

- "当前房间地图"= 探索迷雾：`loc.space[x][y].visi`（Grafon 用它画暗幕，
  Grafon.as:695）；两侧探索半径不同 → 房间亮暗不同。
- 宿主把当前房间已探索掩码（每行 '1'/'0'，行间 '|'；visi>=0.5=已见）随
  worldstate 广播（按 loc 引用缓存，换房重建）；加入方同 loc 应用
  （visi 置 1 点亮）。
- **验证**：宿主构建掩码（25 行）；加入方 `applied seen mask loc0_4
  rows=25`。

## 回归

- 默认战斗场景：death 循环 took/relayed/died/revived 均正常，心跳存活。

## 备注

- driveGhost 等方法的 try 静默 catch 会掩盖 #1069 类 bug——统一改为每
  id/每单位一次的错误日志（本实验教训）。
