# 实验：M11 不同存档加入的场景加载修复——2026-08-18

- 游戏版本：1.02（双实例 pfe2=host / pfe3=join，马哈顿 random_mane）
- 用户报告：玩家 1、2 存档不同时，玩家 2 的场景无法正常加载。

## 复现

`M2_JOIN_LOADSAVE=1`（join 加载自己不同进度的存档，PFEgame1）+ 宿主在马哈顿：

- join 跟随宿主时陷入 `followed(loc0_4)` **反复重进循环**（约每 8s 一次）；
- `injected 0`、`unitsync matched 1/10`（永不收敛）；
- AIR stdout 出现异常耗时：`4666 Создание местности`（正常约 1-2ms）。

## 根因

**过渡期外部干预与游戏入场逻辑打架**：

1. 加入方加载自己存档后，其世界处于（或即将进入）入场过渡；
2. 宿主在别处（或宿主死亡回城），加入方的 autoFollow 在**过渡中**就发起
   gotoXY/travelToLand——过渡未完成时跳房会被入场逻辑（enterLand 按
   checkpoint/出生点重置）打回出生点，房间永不落定；
3. 每 8s 冷却一过就重试 → 反复重进、loc 对象始终在变/未变，
   reconcileWorld 的"同 land 同 loc"门控永远不满足 → 注入归零。

## 修复

1. **`GameBridge.isTransitioning()`**：`World.t_exit>0 || World.t_die>0 ||
   World.comLoad>=0` 视为过渡期（读档/退出/死亡任一进行中）。
2. **过渡门控**：`followHostWorld`（跨图+同图换房两分支）、`travelToLand`、
   `autoMove`、`damageTest` 全部加 `!isTransitioning()` 门槛——过渡期一律
   跳过（跟随返回 `skip-transition`，不记录日志，冷却后自然重试）。
3. **跟随抑制窗口**：`autoLoadSave` 每次尝试读档时设 `_followSuppressUntil`
   （8s）；跟随条件加 `getTimer() > _followSuppressUntil`——读档完成 + 世界
   稳定前不跟随。
4. 诊断增强：心跳日志带 `world=land/loc t_exit comLoad clickReq verror`；
   `dumpGameError` 空文本可见也记录一次；跨图跟随记录 `travel a -> b`。
5. 复现钩子：`autoHostKill`（宿主自毁，确定性触发"宿主死亡回城→加入方跟随
   到基地"路径）。

## 验证

- 复现场景（不同存档 + 宿主马哈顿 + 宿主自毁回城）：
  - join 稳定跟随到随机图（random_mane/loc0_4，`t_exit=0 comLoad=-1
    clickReq=0 verror=false`），注入收敛 `5/5` → `14/14`；
  - 宿主死亡回城后 join 跟随到 rbl/loc0_0，注入收敛 **27/27**（基地 27 单位
    全镜像）；
  - 全程无 `followed(loc)` 循环、无心跳停滞、无错误对话框。
- 默认 M10 战斗场景回归：`applied 4 / relayed 5 / died 2 / revived 2`，
  双方心跳正常（过渡门控未破坏标准链路）。

## 经验

- **任何"自动改位置/旅行"逻辑都必须以"世界未在过渡"为前提**；过渡期的
  判断三字段：`t_exit`（退出/入场）、`t_die`（死亡流程）、`comLoad`（读档）。
- 检测"过渡卡死"的最快手段：心跳日志附 `t_exit/comLoad/clickReq/verror` +
  AIR stdout 的 `Создание местности` 耗时（>100ms 即异常）。
