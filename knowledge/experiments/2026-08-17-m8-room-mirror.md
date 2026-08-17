# 实验：M8 房间内容同步（中立单位镜像 + 读档机制）——2026-08-17

- 游戏版本：1.02（双实例 pfe2=host / pfe3=join）
- 验证：run_m2_dualtest.py（random_mane / stable_pi / rbl 多场景）

## 结论

### 世界注入扩展到中立单位（fraction 0..99）

`reconcileWorld` 从"仅敌人（fraction 1..99）"扩展到"全部非玩家阵营单位
（fraction < 100：敌人 + 中立 NPC/装饰/动物）"：
- 缺失 → 按类名 + AllData.d XML 生成傀儡（doop/unres/disabled，视觉+状态同步）；
- 多出 → 移除（含 `_frozen` 动画驱动残留清理）；
- 玩家阵营（fraction 100：宠物、玩家放置的陷阱）不同步。
- 实测：random_mane 注入 tarakan/merc×3/vortex/turret0、移除 trigridge/
  damshot/damgren 等，unitsync 7/7 全匹配，宿主心跳持续（无挂死）。

### 不可同步的部分（边界确认）

- **门/箱是 `fe.loc.Box`（Obj，瓦片级对象），不在 loc.units**——镜像需碰
  瓦片/渲染层，公开 API 不可行；联机时房间结构（门/箱布局）仍以加入方
  本地生成为准（已知限制）。
- **随机地图生成直接调用 `Math.random`（无 RNG 类）**——种子同步需改游戏
  本体（Land.as），暂不做；rnd 土地联机内容差异仍存在。

### 程序化读档（autoLoadSave 测试钩子，原版 Continue 通道）

- 原版 Continue = `World.w.comLoad = nSave`（PipPageOpt.as:707），World.step
  两帧流程（pip/load screen 准备 → loadGame）完成。
- **关键坑 1**：`gui`/`sats` 只在 `newGame()` 里创建（World.as:859/863）——
  从未建过世界直接 loadGame 会 `#1009`（`this.sats.gg` 空引用，错误对话框
  冻结游戏循环）。流程必须先 newGame 初始化骨架，gg 出现后再 comLoad 读档。
- 实测：join 成功加载用户存档（第二次"Персонаж"痕迹 + 世界替换），
  rbl/loc0_0 与宿主 25/25 单位匹配。
- 诊断工具：`dumpGameError()`——showError 把 `message+stackTrace` 写进
  `verror.txt.text`（公开可读），错误对话框文本直接进日志。

## 三个连带修复（都来自实测暴露）

1. **travelToLand 就绪/重入防护**：新游戏加载流程中（curLandId 未就绪）或
   目标=当前土地时发起旅行会挂死游戏（rbl 实测挂死，主线程卡死无心跳）。
   travelToLand 改返回 Boolean，测试钩子重试。
2. **世界替换后基线重置**：客户端世界被替换（读档/换图）后旧 `_baseHp`
   基线产生幻影伤害上报（读档场景实测 152 条上报、宿主被打几百点）。
   按 loc 对象引用变化重置 `_baseHp/_frozen/_animLogged` 后归零。
3. **UnitNPC 自我解冻**：`disabled=true` 会被游戏自身翻回 false（vendor
   实测），其 step 跑起来后 hp 漂移（41899→34200→39700→33100→32000）→
   幻影伤害。修复：每轮同步都重写 disabled=true；且**伤害上报只限
   fraction 1..99**（中立单位自身逻辑会改 hp，不参与客户端命中检测）。

## 回归验证

- M10 战斗回归（random_mane，默认场景）：56 applied（客户端伤害→宿主权威）、
  2 轮死亡/复活闭环（took 2000 → died → revived）、世界注入正常。
