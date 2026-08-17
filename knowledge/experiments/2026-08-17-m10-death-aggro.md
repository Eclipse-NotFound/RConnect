# 实验：M10 敌人威胁均衡 + 死亡/复活协调（2026-08-17）

- 游戏版本：1.02（random_mane 马哈顿，双实例 pfe2=host / pfe3=join）
- 验证方式：run_m2_dualtest.py 自动化（join 用不同进度存档 PFEgame1）

## 结论

### M10a：敌人现在会打客户端化身（自然索敌 + 拉仇恨闭环）

**根因**：化身此前 `disabled=true` → `Unit.isMeet()` 要求 `!param1.disabled`
→ 敌人 findCel 永远锁不到化身（M9 拉仇恨设的 priorUnit 下一帧就被清掉）。

**修复**：ghostCombat 下化身活体化（`disabled=false`，doop/unres/invulner=false）。
`UnitPonPon.control()` 只有气泡台词逻辑，`id_replic=""`（public）禁言后启用安全。

**闭环实测**（host 日志，无 ghostDamageTest 的自然运行）：
- join 每 5s 打最近敌人 → host `applied 1 client damage hits`（拉仇恨
  priorUnit=化身）→ 敌人转攻化身（findCel 粘滞，isMeet 通过）→
  `relayed 81.56 / 86.55 / ...` 连续 ~40 次真实伤害中继；
- join 侧 `took X damage from host world` 对应掉血。

### M10b：死亡→回城→复活→化身复位 全链路

客户端死亡 → 快照 sost/hp 带过去：
- 宿主化身被动化（doop/unres/invulner=true，停 step），**客户端死亡期间
  不上报伤害**（基线推进，防止复活后误报）；
- 客户端本地走原版流程：`t_die=300 → 150 回城(enterToCurLand) → 100
  resurect → 1 controlOn`；期间暂停自动跟随/移动/伤害（isPlayerDead 门控）；
- 复活后：化身按快照重建（sost=1/fraction=100/hp 镜像，跨土地时先隐藏）；
- 旅行门控：`Pers.dopusk()`（headHP/torsHP/legsHP/bloodHP 均 >1 才允许
  gotoLand）——身体伤重时 follow 探测并等冷却重试，不刷屏；
- 自动治疗钩子 autoHeal（测试用）→ `Pers.healAll()` 后重新跟随。

**确定性闭环实测**（testGhostDmg=2000，每 15s 一击）：
- join：`took 2000 → local player died → blocked-body → revived →
  healTest → followed-land(random_mane)`，3 轮完整循环；
- host：`relayed 2000 → passive (client dead) → despawned（回城跨土地）→
  spawned → combat restored (client alive)`。

## 两个关键坑

1. **中继伤害不可钳制为剩余血量**：客户端 `gg.damage()` 带护甲减伤（实测
   ~×0.57），若中继量≈客户端当前血量，减伤后永不致死（收敛陷阱）。中继
   **原始命中量**（`基线 - 现hp`，hp 可为负），护甲减伤由客户端游戏自身处理。
2. **`hp < 0` 不是"探测失败"**：致死一击会把化身 hp 打成负数；旧的
   `cur < 0 → return` 守卫会把死亡当失效吞掉。探测失败判定只看字段是否可读。

## 测试安全

- 触发器类 `fe.unit::UnitTrigger`（trigplate 等）从测试攻击钩子过滤
  （曾因攻击触发器 trigcans 崩溃宿主）。
