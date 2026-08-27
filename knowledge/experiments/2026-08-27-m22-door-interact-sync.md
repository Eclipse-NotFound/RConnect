# 实验：M22 门/容器交互状态同步（Interact ist 镜像）——2026-08-27

- 游戏版本：1.02（双实例）
- 前提：M16b 已同步 objs 的 dead/hp/door/door_opac 字段——但本次查证发现
  **door/door_opac 是 XML 类型常量（Box 构造时从 AllData 读入后不再变），
  同步它们等于什么都没同步**。门/箱的真实动态状态全部在 `Interact` 上。

## 机制查证（反编译 1.02）

- `fe.Obj.inter`（public）→ `fe.serv.Interact`：
  - `open:Boolean`（public）：门/容器开合实时状态；autoClose 门由
    `t_autoClose` 计时到 1 时 `command("close")` 自动关。
  - `lock:int`（public）：0=未锁，1..N=锁等级，100=卡死/破坏（101/102 是
    saveLock 语义值，见下）。
  - `cont:String`（public）：容器内容键；搜刮后 `cont="empty"`。
- **真实开关入口** = `Box.setDoor(open)`：遍历 `Box.tiles` 把门矩形覆盖的
  **瓦片** `phis/opac` 置 0/恢复 + `setVisState("open"/"close")`（视觉帧 +
  音效）+ 开门时 `loc.isRelight/isRebuild`（整房重光照）。
  只写 `Box.door` 字段**不触发以上任何效果**（M16 的无效同步根因）。
- **官方状态恢复路径** = `Interact.setAct(kind, value)`：
  - `"open",0|1` → open + （door 则 setDoor / knop 则切视觉）+ 开时清 lock/mine；
  - `"lock",v` → v<100 设锁；101=解锁；102=卡死；
  - `"loot",v>0` → saveLoot=v、active=false、cont="empty"、视觉 open；
  - `"mine"` / `"expl"` 同理。
  游戏存档恢复正是走它（`Location` load 对每 obj 调 `inter.load→setAct`）。
- **官方状态打包** = `Interact.save(obj)`（public）：写出
  `{lock:saveLock, lockLevel, mine:saveMine, loot:saveLoot, open:saveOpen,
  expl:saveExpl, dif, sign}`。注意 `saveOpen/saveLock/saveMine/saveExpl`
  是 **internal**，模组只能经 save() 间接读；且 autoClose 门的 saveOpen
  不落盘 → **open 一律用实时 `inter.open` 读，其余字段用 save()**。
- 门类 Box 的**死亡**（die()）在 door>0 分支清 tiles 的 phis/opac/hp +
  "die" 视觉帧 + `inter.off()`；只翻 `dead` 字段不清碰撞。加载恢复同款
  路径是 `die(-1)`（负参=无声、无粒子、不跑 scrDie）。
- `Location.setDoor(n,fak)`（Land 建图调）是随机图通道口开凿，建图期
  静态行为，M13 播种后双端一致，无需同步。

## 方案（纯模组侧，零游戏补丁）

宿主权威单向镜像，"持久状态持续广播 + 幂等应用"（沿 M17 教训）：

- 宿主 `readObjsSnapshot()` 每 obj 附 `ist`（仅在非默认状态时携带）：
  `{lock, mine, loot, expl}`（save() 打包值）+ `open`（实时值）。
- 加入方 `reconcileObjs()` 对同房同 id obj：
  - `dead` 翻转且 `door>0` → 调 `die(-1)`（替代字段翻转）；
  - `ist` 按 id 记 `_istLast` 锁存（换房重置——不同房可有同名 id），
    **仅变化字段**调 `setAct`（setAct 会播音效/重光照，200ms 重放会刷屏）；
  - 已 dead 的 obj 不再应用 ist（die 视觉优先，防 open 帧覆盖 die 帧）；
  - `dead` 只单向置 true（不回写 false——游戏语义死亡不可逆，且防止
    宿主快照把加入方本地破坏"复活"）。
- 阻挡关门的边界：宿主关门时若有单位堵门，游戏自身语义是门保持开
  （`attDoor()` → open=true + infoText），镜像会如实跟随，宿主下次
  变更前不重试。
- 客户端本地开关门/搜刮在宿主动作前不被覆盖（只在宿主 ist 变化时应用）
  ——与整体宿主权威架构一致；客户端交互上报宿主列为后续课题。

## 复现钩子（config 驱动，默认关）

- `autoDoorToggle`（宿主）：80s `inter.command("open")` / 150s
  `command("close")` 第一个活门（真实使用路径），日志附 tilePhis 证明
  瓦片碰撞切换；`M2_DOORTOGGLE=1` 透传。
- `autoBoxLoot`（宿主）：80s 对第一个非空容器 `setAct("loot",2)`；
  `M2_BOXLOOT=1` 透传。
- 断言关键词：host `doorIcTest open/close 'id' tilePhis=N` /
  `boxLootTest looted 'id'`；join `ist apply open=1/0 'id' tilePhis=N` /
  `ist apply loot=2 'id'` / `ist apply lock=N 'id'`。

## 验证（双实例真机，1.02，rbl / random_mane）

8 轮迭代（m22_run1~8.log）。核心断言全部通过，期间揪出三个环境/语义坑：

| 轮次 | 场景 | 结果 |
|---|---|---|
| run1 | rbl，端口 23456 | 宿主 bind 失败（端口被残留 RV 测试实例抢占），joiner 连上别人的宿主——但意外证明了 ist 管线端到端可用（lock×5 + open=1 tilePhis=0 全部生效） |
| run2 | random_mane | 开门/搜刮宿主侧生效；敌对怪把宿主和 joiner 都打死，同居窗口破碎 |
| run4 | rbl | 门开+关门钩子均执行；joiner 收到 open=1/lock=3，但关门不回同步（引出 seen 广播修复） |
| run5 | rbl + seen 广播 | 关门同步生效（`ist apply open=0 tilePhis=1`）——但 joiner 每 350ms 重放 open/lock 4 连块（2089 次/105s） |
| run6/7 | + 每消息诊断 | 消息粒度真相：宿主 door3 以 ~1.4s 周期循环 `open×5 → 关+锁3 → 关+解锁`；TX==RX==apply 流完全一致——**镜像无罪，宿主游戏侧在抖** |
| run8/9 | + autoClose 语义 + 滞回 | 宿主玩家走开（autoWalk）仍循环——滞回正确拒绝不稳定值（无 apply 风暴，open 也不应用） |
| run11 | 双侧每消息对账 | TX/RX 流逐条一致；door3 循环与玩家位置无关（rbl 基地脚本门，`lock='3' hack='1'`，疑似 loc.prob 周期事件）；滞回稳定过滤 |

## 结果（最终形态）

- **根因链**：rbl door3 是带基础锁 3 的脚本循环门（AllData:4871
  `lock='3' hack='1' time='15'`），宿主侧游戏自身让它按 ~1.4s 周期
  开→关+锁→解锁（与玩家/鬼影位置无关，run9/10/11 证实）。镜像忠实
  转发会让 joiner 陷入 setAct 风暴（音效+重光照每周期一次）。
- **修复三件套**（最终代码形态）：
  1. **autoClose 门的 open 不广播**——游戏存档本身就不持久化它
     （`setAct("open"): if(autoClose==0) saveOpen=...`），瞬态同步是噪声；
  2. **open/lock 滞回**（IST_STABLE_N=10 条 unitsync = 2s 稳定才应用）——
     run8~11 实测把 1.4s 周期循环完全滤成零应用，lock 稳定值正常通过；
  3. **ever-seen 广播**（曾经非默认的字段回默认后显式广播 0 值，否则
     "关门/解锁"永远到不了 joiner——run4 缺口）。
- **端到端验证矩阵**：
  - lock 同步 ✓✓（run1/2/5/8/9/10/11：lock=23/14/9/8/6/4/3/0/101 全覆盖，
    含探索锁定箱、门、解锁态）；
  - 门 open 同步 ✓（run4/5：宿主稳定开门窗口内 joiner `ist apply open=1
    tilePhis=0`，双端瓦片碰撞一致）；
  - 门 close 回同步 ✓（run5：`ist apply open=0 tilePhis=1`）；
  - 容器搜刮：宿主钩子 ✓（run2 `boxLootTest looted 'chest'`）；joiner 侧
    loot 应用与 lock/open 走同一 applyIst 分发器，判定代码路径等价覆盖
    （rbl 出生房无可搜刮容器，暂无现场）；
  - 门被摧毁 → die(-1)（清瓦片）：代码路径 = 游戏存档加载同款，未做
    双实例专项（需 5000hp 门打穿，程序化成本高），记为已知待验证。
- 心跳健康、零错误对话框、无死亡干扰（rbl 场）；random_mane 场宿主/
  joiner 均会被敌对怪打死（run2 教训），稳定验证选 rbl。

## 教训

- ** objs 快照必须房间内消费**：Session 的 unitsync 已按 landId+locId 门控
  （M7），实测跨房时正确屏蔽（run1 joiner 与 RV 宿主同房才应用）。但要
  警惕 `locker/door1a/explbox` 这类**跨房间通用 id**——门控一旦失效会
  跨房误应用，考虑未来把 locId 编进 obj 快照做二次校验。
- **端口抢占会静默串线**：同机残留测试实例（RVTest）占 23456，宿主
  bind 失败仅 trace 到 adl stdout、mode 仍显示 hosting，加入方连上
  别的宿主继续"成功"测试。修复：bind 失败写 RConnect.log +
  `M2_PORT` 换端口重跑。杀残留实例前先确认不是并行 agent 的工作。
- **镜像忠实 ≠ 正确**：宿主游戏侧状态高速振荡时（autoClose 门 + 堵门
  + 脚本），1:1 镜像变成 joiner 的 setAct 风暴（音效+重光照每 350ms）。
  状态同步要区分"持久状态"（lock/loot/dead）与"瞬态物理"（autoClose
  门的 open），后者对齐游戏存档语义直接不同步；其余加滞回。
- **hysteresis 的采样教训**：2s 粒度的周期 dump 显示"相位稳定"，
  消息粒度才暴露 350ms 振荡——诊断instrumentation 的粒度必须高于
  怀疑对象的频率。
- **存档模板与 autoGame 组合注意**：joiner newGame 后 autoFollow 跨图
  跟随宿主在 random_mane 可行（followed-land），但敌图会死人；稳定
  验证选 rbl（无敌人、有门、确定性布局）。
- 工具链：本机（D 盘 Steam + 用户 hello）无 flexsdk——实际工具链在
  `D:\RemainsMod\mods\Sandevistan\build\tools\`（flexsdk=HARMAN AIR SDK
  51.3.3 含 amxmlc；ffdec 同层）。AIR 51 的 air-config 默认 swf-version=51
  （游戏运行时 ≤39，超了静默不加载）——build_mod.py 已显式
  `-swf-version=38`。编译需 Java 11+：`C:\Users\hello\Documents\
  _sandevistan_dev\jdk-11.0.32.1+1-jre`（Temurin 11，PATH 挂 bin 即可）。
