# 实验：M17 瓦片破坏 + 新物品/Loot 同步（宿主权威补齐）——2026-08-20

- 游戏版本：1.02（双实例，马哈顿 random_mane）
- 目标：用户要求"加入方真实存在于宿主存档"的最后两项——宿主造成的房间
  破坏（瓦片）与宿主现场生成物品（掉落/脚本）在加入方可见。

## M17a：瓦片破坏差分同步

- 机制：宿主每 200ms 对 `loc.space` 与"进房基线"对比（phis/front/back/
  zad/zForm/water/stair/hp），把变化瓦片随 unitsync 广播；改变瓦片作为
  **持久状态持续广播**（不推进基线），晚到加入方也能收敛；加入方按需应用
  + `World.w.redrawLoc()` 整房重绘（变化检测去抖：仅真正改变才重绘一次）。
- 验证：宿主 `tileBreakTest opened 8,1` → 加入方 `tile patch applied 1`
  + **仅 1 次重绘**（去抖生效）；重复补丁不重绘。
- 瓦片破坏的真实入口（游戏侧）：爆炸→`damageWall`→`Tile.hole()`
  （Tile.as:264/356 phis=0）+ redrawLoc；本同步覆盖其结果变化。

## M17b：新生成物品/Loot 镜像

- 机制：
  - Loot/脚本生成的 Box **不在 `loc.objs`**（只在 Pt 链 firstObj→nobj，
    `loc.addObj` 只挂链不推数组）——宿主沿 Pt 链扫描 `fe.loc` 系 Obj；
  - 进房建立模板 id 集（loc.objs），之后每个 unitsync 报告**非模板** Obj
    （Loot 恒定上报：位置+item base 作键）；
  - 加入方按键**幂等去重**：Loot 用 `new Item(null, base, 1)` + `new Loot(
    loc,item,x,y,false,false,false)`（Loot 构造自注册入 loc），其它 Obj
    尽力 `new cls(loc,id,x,y,null,null)`（失败跳过记录）。
- 验证：宿主 `objSpawnTest spawned loot 'kofe'` → 加入方 `obj spawn recv
  spawned=2 skipped=1`（kofe 生成成功；checkpoint 等非物品类安全跳过）。

## 关键坑

1. **unitsync 曾设 `units.length>0` 门槛**——房间无敌人时瓦片/物品数据全
   不发；已移除（空单位列表也广播世界增量）。
2. **一次性事件 vs 持久状态**：deltas 若只发一次、加入方晚到就永久错过；
   改"非默认状态每帧广播 + 加入方幂等"，天然支持迟加入收敛。
3. **getQualifiedClassName 用 `::` 分隔**（`fe.loc::Loot`）——`indexOf(
   "fe.loc.")==0` 匹配不到，需 `"fe.loc"==0`。
4. Loot 在 Pt 链不在 objs 数组（先前读 objs 导致完全收不到）。
5. 持续补丁需要**变化检测去抖**，否则每 200ms 整房重绘（性能）。

## 现状总结（对用户"宿主权威世界"诉求）

布局一致 ✓ 敌人一致 ✓ 物品/箱状态与破坏 ✓ **瓦片破坏 ✓ 新生成/
Loot ✓** 姿态/武器/探索一致 ✓。仍边界：随机图敌人内容以注入为准、
boss（alicorn）远端镜像受限。
