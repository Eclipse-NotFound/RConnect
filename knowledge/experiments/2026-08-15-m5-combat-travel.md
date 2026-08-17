---
domain: knowledge-validation
type: experiments

game-version:
  - "1.02"

confidence: high
verified: true

discovered-by: RConnect

evidence:
  - kind: runtime-experiment
    summary: "真机双实例：客户端本地命中检测→上报→宿主 Unit.damage 结算→状态回流
      全链路通过；gotoXY 任意房间跳转会挂死游戏（重要教训）"

date-updated: 2026-08-15
---

# 实验：M5 战斗权威与跨房传送

## M5a 客户端 AI 冻结（freezeAI）

- 客户端对"被同步单位"在首次镜像后置 `disabled=true`（视觉已挂，仅停 step）：
  本地 AI 不再挪动单位 → 不再与宿主权威位置打架（M4 抖动问题消除）。
- 副作用：被冻结单位在客户端成为"雕像"（无行走动画、不反击玩家），
  且其本地 hp 只随客户端自己的攻击变化——恰好让 M5b 的命中检测变干净。
- 代价评估：客户端侧敌人无动画/无威胁，观感差；M6 再考虑
  "傀儡动画驱动（blit 管线公开 animState/blit）"。

## M5b 战斗权威（客户端命中 → 宿主结算）

- 机制：客户端以宿主同步的 hp 为基线（_baseHp），本地单位 hp 低于基线 =
  本地命中 → 上报 {id, dmg} → 宿主 `Unit.damage(dmg, D_BUL=0, null, false)`
  权威结算 → 宿主状态经 unitsync 回流（hp 覆盖式，无双重伤害）。
- 实测日志（双向）：
  - join：`damageTest hit 'phoenix' hp=189.2` → `reported 4/5 damage hits`（持续）
  - host：`applied 4 client damage hits`
- 结论：伤害事件化管道可用。客户端命中判定基于"本地伤害"，合作模式下
  可接受；反作弊不在此列。

## M5c 跨房传送

- 实现：宿主 unitsync 附 worldInfo（curLandId/roomId/locId/landX/landY/landZ/
  x/y）；客户端按配置 autoFollow 调用公开旅行入口 `Land.gotoXY(x,y)`
  （locX/locY→ativateLoc→玩家进房）后把 gg 摆到宿主精确坐标。
- **重要教训**：宿主自动化测试用 `gotoXY(1,0)` 直接跳任意房间——
  **游戏整体挂死**（AIR 单线程，模组 Timer 一并停止，日志戛然而止）。
  说明 gotoXY 到非预期/未初始化房间存在游戏侧死循环风险；真实换房应走
  游戏自己的门流程。
- 状态：跟随机制已接线，但**真实换房同步未验证**（需真人走门测试，
  autoTravel 已从自动化配置移除）。

## 结论 / 下一步（M6 候选）

1. 傀儡动画驱动（blit 单位用公开 animState/blit 驱动姿态）解决雕像问题；
2. 真实走门换房 + 客户端跟随的手动验证；
3. 敌人阵营：宿主权威下客户端冻结敌人后，敌人不攻击客户端玩家——需要
   "客户端可见威胁"方案（宿主敌人状态照常回流，客户端玩家被攻击的判定
   移到宿主侧——更大课题）。
