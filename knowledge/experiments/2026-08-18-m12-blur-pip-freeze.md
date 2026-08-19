# 实验：M12 失焦开 PipBuck 导致"两侧房间不同"——2026-08-18

- 游戏版本：1.02（双实例 pfe2=host / pfe3=join，马哈顿 random_mane）
- 用户报告：宿主和加入方进入同一地点（如马哈顿废墟）时，两侧显示的房间不同。

## 根因：失焦 → 游戏自动打开 PipBuck → 世界冻结

### 机制（反编译确认）

1. `World` 构造时注册 `swfStage.addEventListener(Event.DEACTIVATE, onDeactivate)`
   （World.as:397）。
2. 窗口失焦 → `onDeactivate`（World.as:768）执行 `pip.onoff(11)`——
   **强制打开 PipBuck（装备栏）**，并 `saveGame()`。
3. `PipBuck.onoff()`：`if(active && param1 == 11) return;`——已开状态再收到
   11 直接返回；**全代码库没有 ACTIVATE/resize 等恢复焦点时关闭它的机制**
   → pip 一旦被失焦打开就**永久打开**（除非玩家手动切掉）。
4. `World.step`（World.as:1384）：`allStat = (pip.active || sats.active ||
   stand.active || gui.guiPause) ? 2 : 1;`——覆盖层开 → **allStat=2** →
   World.step 的 gameplay 块（含 t_exit/exitStep 旅行过渡）整块跳过。
5. 影响：被失焦的一方**冻结在自己原来的房间**（旅行中途则 t_exit 停在
   16、新房间已切但控制不恢复）→ 两侧显示的房间不同/场景无法正常加载。

### 触发场景

- 双窗口同屏（second_player.bat 或测试框架）：点另一个窗口 → 另一个
  实例失焦 → pip 打开 → 冻结。**间歇性**（取决于焦点时序），
  自动化复现时约 1/3~1/4 轮次命中。

## 修复

1. **源头拦截（主要）**：`GameBridge` 构造时在同 one Stage 上以
   优先级 1000 注册 `DEACTIVATE` 监听，`stopImmediatePropagation()`
   抢在游戏 `onDeactivate` 之前拦下失焦事件——游戏开 pip 的路径
   永久不触发。副作用：失焦自动存档也不再发生（游戏周期性 t_save
   存档不受影响）。
2. **兜底**：`travelToLand`/`followHostWorld(gotoXY)` 在 allStat!=1
   （任何覆盖层开着）时先 `forceCloseOverlays()`（pip 用原生 onoff(0)、
   sats/stand 置 active=false、guiPause=false）并跳过本轮重试；
   过渡中（t_exit>0 && allStat!=1）每 2s 恢复守护强制关闭。
3. 诊断：心跳附带 allStat/pipA/satsA/standA/guiPause/t_exit/comLoad/
   clickReq/verror；复现钩子 `autoDeactivate`（模拟失焦）。

## 验证

- `M2_DEACT=1`（join tick 400 确定性派发 DEACTIVATE）：修复前
  pipA=true→allStat=2 永久冻结；修复后 **pipA 全程 false**，join 正常
  跟随并落定 random_mane/loc0_4（allStat=1）。
- 默认战斗回归 ×2：pipA=true **0 次**、allStat>=2 **0 次**，战斗/死亡链路
  正常（took 5/4）。

## 关联

- 本问题与"随机土地（rnd）房间内容按 Math.random 生成、两侧布局不同"
  是**两个独立问题**：前者（失焦冻结）已在本实验修复且无需改游戏文件；
  后者（rnd 布局同步）需要改游戏本体（播种/房间选择同步），另行评估。
- 涉及机制公共结论：`pip.active/sats.active/stand.active/guiPause -> allStat`
  门控、失焦开 pip 无复位、优先级抢 `stopImmediatePropagation`——均已记录
  或可提炼到 shared-knowledge。
