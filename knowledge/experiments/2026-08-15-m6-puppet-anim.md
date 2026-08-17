---
domain: knowledge-validation
type: experiments

game-version:
  - "1.02"

confidence: medium
verified: false

discovered-by: RConnect

evidence:
  - kind: decompiled-game-code
    summary: "BlitAnim（fe.serv）全公开；blit 单位动画管线在各单位自身公开
      animate() 内：animState 变化→anims[animState].restart()→blit(id,f)→step()"

  - kind: runtime-experiment
    summary: "真机双实例：unitsync 携带 animState、客户端冻结单位（freezeAI）、
      幽灵半透明+名字标签均无异常；开局房间无 blit 单位，姿态转换未能在
      该房间实测"

date-updated: 2026-08-15
---

# 实验：M6 傀儡动画与幽灵视觉区分

## 关键调研结论（反编译 1.02）

- `fe.serv.BlitAnim` **全公开**：字段 id（行）/f（帧）/firstf/maxf/df/st/replay
  + step()/restart()/setStab()。
- blit 单位（Raider/Merc/Alicorn/Ant/Phoenix/Necros 等）的动画管线在各单位
  自身的 **public `animate()`** 内：
  ```
  if(animState != animState2) { anims[animState].restart(); animState2 = animState; }
  if(!anims[animState].st) { blit(anims[animState].id, anims[animState].f); }
  anims[animState].step();
  ```
  （`anims` 是 internal，但 animate() 在游戏侧执行——**模组只要写公开
  `animState` + 调公开 `animate()`，无需触碰 internal**。）
- 时间轴视觉单位（NPC/炮塔等）的 MovieClip 自带循环播放，冻结（disabled）
  不影响其动画——"雕像"问题只存在于 blit 单位。

## 实现（M6a）

- 宿主 unitsync 每单位附加 `anim`（animState 公开字段）。
- 客户端对冻结单位：animState 变化时写入并记录（每 id 一次日志）；
  每 tick 调用 `unit.animate()`（游戏自身完成 restart/blit/step）。

## 实测结果（M6）

- freezeAI + animState 传输 + animate() 驱动：**运行无异常**；
  27/27→25/25 镜像（秒杀测试后死亡单位被双方移除，数量一致）；
  伤害中继继续正常（reported/applied 双向）。
- **未能完成姿态转换的运行时验证**：开局房间 loc0_0 内全部是时间轴视觉
  单位（NPC/炮塔/凤凰），无 blit 单位；凤凰 animState 恒为 fly 且不死亡
  （凤凰重生机制，hp 可负值存活）；炮塔无死亡动画（与 shared-knowledge
  既有结论一致）。像素级活性探测（vis→Sprite→Bitmap 采样）因找不到 blit
  目标而无输出。
- 附带发现：vendor 类 NPC 受击后自愈（godmode 式）；炮塔/商人可被 99999
  伤害击杀且无动画变化。

## 幽灵视觉区分（M6b，已实现）

- 幽灵 vis.alpha=0.75 + 头顶黄字名字标签（TextField，`_rconnect_label` 存
  引用）；setVisPos 整体翻转（vis.scaleX=storona）后标签反向抵消，文字始终
  正向可读。多轮双实例无异常，观感待人工确认。

## 待办（下一轮）

- 在含 blit 敌人（raider 等）的房间做姿态转换实测（依赖真实走门换房或
  手动开新场景）。
- 观感：半透明 0.75 与标签字号/位置人工调整。

## 追加验证（同日第二轮）：像素级证据 + 跨地图传送

### M6a 像素级验证通过

- 开局房间的凤凰（UnitPhoenix）是 blit 单位（ctor 调 initBlit）且多帧飞行动画。
- 客户端冻结凤凰后经显示树采样 blit 位图（vis→Sprite→Bitmap.getPixel）：
  ```
  puppet probe start 'phoenix' px=599552
  puppet anim LIVE 'phoenix' px 599552 -> 49439
  ```
- 结论：**公开 animate() 驱动真实渲染帧**——冻结单位不再是雕像，M6a 闭环。

### 跨地图传送（马哈顿废墟）

- 标准入口 = `Game.beginMission/gotoLand`（含 exitLand 退出流程）；直接
  `curLandId + enterToCurLand` 会挂死游戏（已记入
  shared-knowledge/world-objects/facts/land-travel-api.md）。
- `beginMission("random_mane")` 实测**成功进入马哈顿废墟**（宿主击杀
  alicorn1/alicorn2 证实）；但传送存在间歇性挂死，且**复现定位到跨模组
  bug**：进入新土地后 RealisticVision 的 hideEnemies→applyMask 抛
  `ReferenceError #1056（Cannot create property mouseEnabled on Shape）`，
  随后宿主整体无响应（本模组心跳同步停止）。单次异常即连带挂死，
  疑似其掩码状态破坏后游戏下一帧死循环。
- 随机地图（rnd）内容按 Math.random 生成：即使无该 bug，双实例传送后
  房间内容也不一致，单位 id 匹配会失败——联机同步宜限定 story/base 土地。

### 已上报事项

- 跨模组：RealisticVision 在新地图有敌人时崩溃（#1056），阻塞"传送后
  联机同步"的宿主侧测试——按 AGENT_SCOPE 未修改对方模组，需协调其修复。

## 第三轮验证：RVision 修复后 raiders 全链路（2026-08-15 晚）

- 前提确认：三份游戏 SWF 相对 current-merged 备份无他人改动；RVision 修复
  在其自身模组内生效（传送后无 #1056）。
- **跨地图跟随闭环**：
  ```
  HOST: travelToLand -> raiders，心跳持续（tick 1200+，无挂死）
  JOIN: followed-land(raiders)
        host=raiders/loc2_1@1385,860 mine=raiders/loc2_1@926,880
        -> landMatch=true locMatch=true
  ```
  双方经标准旅行入口进入同一土地同一房间（loc2_1），坐标同源。
- **傀儡动画继续验证**：puppet anim LIVE 两次（599552→49439→30208）。
- 教训：damageTest 曾命中中立触发器 'trigcans'（fraction 0）导致宿主崩溃
  （脚本对象被打触发死循环/栈溢出）——伤害目标过滤器收紧为
  fraction 1..99（排除中立 0 与友好 100）。
- 遗留：raiders 的 loc2_1 开局无敌对单位（unitsync 仅 1/1），
  敌人房间的完整战斗同步测试仍需一个"确定性且开局含敌"的场景
  （nio/core/garages 待选）或真人手动测试。
