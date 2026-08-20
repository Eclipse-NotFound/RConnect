# 实验：M18 外观镜像 + 悬浮/飞行药水效果修复——2026-08-20

- 游戏版本：1.02（双实例，马哈顿 random_mane）
- 用户报告：①对方形象与本地玩家一样（幽灵长得像自己）；②对方身上有
  "飞行药水效果"；③对方仍为趴姿（之前一直存在但遗漏）。

## 根因（同一源头）

- `visualPlayer` 在**构造时从全局静态 `fe.inter.Appear` 读取外观**
  （ggArmorId/护甲、trFur/trHair/trHair1/trEye/trMagic 颜色变换、
  fEye/fHair/visHair1/hideMane）+ `World.app` 实例色（cFur/cHair/
  cHair1/cEye/cMagic）→ **每个幽灵都按"本地玩家"的外观构造**，于是：
  幽灵形象=宿主（加入方看宿主幽灵=自己形象），姿态/效果等视觉状态
  也连带从本地初始化（趴姿初始帧、悬浮等）。
- "飞行药水效果"：potion_fly 的效果本体是 `isFly=true` + 黑色粒子拖尾
  （Effect.as:168/353 `newPart("black",15)`）；幽灵若被游戏悬浮物理带起
  （isFly 未被压住），视觉上就是"带飞行药水效果"。

## 修复

1. **外观镜像（M18a）**：快照带 `ap`（Appear 全局静态 + World.app 颜色 +
   ColorTransform 六元组）；幽灵构造时**临时把全局 Appear 换成对方值 →
   new visualPlayer() → 还原本地值**。验证：宿主幽灵 armor=assault（加入
   方护甲）、加入方幽灵 armor=pip（宿主护甲）——互相穿上对方外观 ✓。
2. **防悬浮（M18b）**：driveGhost 每帧 `isFly=false` + sost=1——幽灵垂直
   位置只由快照 setPos 决定，游戏自身飞行/悬浮物理不再把幽灵带起。
3. 趴姿：M16 姿态镜像（对方真实标签）+ M15 sost 强制 + 出生即驱动，组合
   消除初始趴姿帧。

## 验证

- 外观字段流：`styled armor=assault / pip`（双方各异=镜像生效）；无崩溃。
- 默认战斗回归：applied 3 / relayed 4 / took 4 / 心跳正常。

## 限制

- 外观在幽灵**生成时**套用（护甲/换装在会话中变化需重生成/重新接入才
  更新；死亡重建/重连会刷新）。换装热同步可后续做（监听快照 ap 变化重建）。
