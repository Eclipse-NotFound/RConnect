# 实验：M13 随机图（rnd）房间布局确定性——2026-08-19

- 游戏版本：1.02/1.03/1.04（三份 SWF 一并补丁；验证在 1.02 双实例）
- 用户报告：host/join 进入马哈顿废墟（random_mane）后两侧房间不同、互相看不到。

## 根因（Explore 精读确认）

- 房间**几何**完全由「房间模板 + 是否镜像 + 门位连通」决定；
  `Location.buildLoc/setDoor/mainFrame` 零随机。
- 决定这三者的 `Math.random()` 仅 7 处、全部在 `Land.as`（全局唯一实现）：
  L192(mirror)、L878/L882(newTipLoc 选房)、L924/L935(newRandomLoc 选房)、
  L473/L485(通道打通)。
- 敌人/掉落/装饰等"内容"随机（`Land.as` 另 11 处 + `Location` 内）不碰几何，
  且敌人本就由 unitsync+世界注入同步。
- 两个实例的全局 Math.random 时序必然不同 → 结构随机也各自不同 → 布局不同。

## 修复：Land.as 确定性补丁（游戏文件，用户已授权）

`tools/patch_land_determinism.py`（幂等、anchors、双标记校验、备份）：
1. `Land` 新增静态 PRNG：`_rndSeed` + `rndDeterm/rndSeedFor/rndNext`
   （fnv1a(act.id) 播种 + LCG next，返回 [0,1)）；
2. Land 构造的 `if(this.rnd)` 分支自动播种：`rndDeterm(rndSeedFor(this.act.id))`
   ——双端从同一 XML 读到同一 act.id → 同一 seed → 同一布局
   （不依赖联网/广播/时序）；
3. 7 处结构 `Math.random()` → `rndNext()`；内容随机一律保留全局。

注：random_mane 为 conf3，不吃 visited/mbase 分支，生成顺序确定性良好。

## 老化验证（双实例，不同存档）

- **同 locId + 同坐标 + 同 tile grid 指纹**：join 跟随/对齐到宿主坐标
  （362,960）后，8 点瓦片 phis/zForm/stair/water 采样与宿主**完全一致**
  （3 轮复现均一致）→ 布局确定性确认。
- matched 5/5 收敛（可注入单位）；boss alicorns 若 AllData 查不到 XML 则
  注入失败——改为**黑名单记一次**（不再每轮刷日志），boss 保持宿主权威。
- 默认战斗回归：applied 3 / relayed 5 / took 5 / died+revived 各 1，心跳正常。
- 附带修复：**同房出生点对齐**——确定性布局下双方可能落在同房不同
  checkpoint（如 242,320 vs 442,960），首次同房且相距>300px 一次性 setPos
  到宿主坐标（`aligned to host`）。

## 已知取舍/限制

- 打过补丁的游戏里 rnd 图每次新档同一套布局（联机一致优先）；敌人/掉落
  等内容仍随机（联机敌人由宿主权威注入）。
- boss（alicorn）类的远端镜像仍受限：构造依赖 AllData XML，查不到时仅
  宿主权威（注入跳过并记录一次）。
- DLC(1.03/1.04) 已一并补丁（Land.as 同构）；未来版本若 Land.as 变化，
  脚本锚点失配即报错，需人工适配。
