# RConnect —— 开发日志

> 协议见 GOVERNANCE.md §8：只追加不改写，**新条目插在最上面**。

## 2026-08-28 M24 可移动物品（Loot）全量同步

- 做了什么：盘点敌人同步（M4/M8/M19/M21 已闭环，无结构性缺口）→ 物品侧补齐：宿主 Loot 稳定键（Dictionary 对象键，L#n）+ unitsync `loots` 数组（空数组也发=移除信号）→ joiner 认领/生成/位置镜像/缺席移除；joiner 拾取与推动经新消息 MSG_LOOT 上报宿主权威落位；readNewObjs 退役 Loot 坐标键（避免与 M24 双重生成）；测试钩子拆成 lootSpawnTest/lootPushTest/lootTakeTest（M2_LOOTTEST/M2_LOOTJOIN）。
- 关键决定/发现（→ knowledge/experiments/2026-08-24-m24-loot-sync.md，文件名 2026-08-28）：
  - `Item(构造器)` param2 赋给 id 而非 base——物品身份键读 item.id（读 base 恒空 → spawnLoot 静默拒绝）；
  - "缺席即移除"必须真的发空数组，否则 joiner 无限重复上报 picked；
  - 测试钩子动作窗口必须 ≥ unitsync 广播间隔（200ms），否则物品生命周期短于采样窗永远不可见（6 轮迭代定位）；
  - AS3 对象键映射必须用 Dictionary（Object 键字符串化全撞键）。
- 遗留/下一步：suction 动画不镜像（直接落位）；同 base 重位误认领（仅键归属，无增减）；推动限频 1s/键；其余按 MEMORY §6。

---

## 2026-08-28 M23 幽灵趴姿+悬浮根治（皮肤语义映射）+ 开机门控

- 做了什么：用户报告 M16a/M18 修复后幽灵仍趴姿+悬浮 → 每消息 dump 定位真正根因：玩家皮肤 idle 主段是 "stay"（free1/2/3 只是偶发小动作），而幽灵皮肤 stay=趴/卧——**同标签不同皮肤语义相反**，1:1 镜像必然大部分时间趴。修复：idle 族映射 stay→free1（freeX/移动标签透传）+ levit 压制。另修复 startGame 无 landData 门控问题（夜间并行 TDFC v0.5.0 的 AutoTest 劫持测试实例暴露）。
- 关键决定/发现（→ knowledge/experiments/2026-08-28-m23-pose-skin-mapping.md）：
  - 跨皮肤镜像必须建语义字典，镜像"渲染意图"而非"播放头位置"；M16a 的日志级验证抓到 free3 瞬间误判已修——呈现类 bug 需密集采样/真人观感；
  - TDFC AutoTest 激活条件（appid != "pfe"）比其文档宽，劫持 pfe2/pfe3 抢开新档打坏开机链；RConnect 补 landData 门控自保，TDFC 侧问题只报告不修（见 MEMORY §5）。
- 遗留/下一步：悬浮消失需用户真人观感最终确认；坐下/爬行不镜像（标签层不可分）；TDFC 激活条件待转告。

---

## 2026-08-27 M22 门/容器交互状态同步（Interact ist 镜像）

- 做了什么：查证 M16 的 door/door_opac 字段同步是无效同步（XML 类型常量）→ 真实状态在 `Interact`（open/lock/loot/mine）→ 实现 ist 快照/应用（宿主 `save()`+实时 open 打包，joiner `setAct()` 官方存档恢复路径幂等应用）+ 门死亡走 die(-1) 清瓦片 + doorIcTest/boxLootTest 钩子 + M2_PORT/M2_DOORTOGGLE/M2_BOXLOOT/M2_HOSTWALK 测试变量。11 轮双实例迭代验证。
- 关键决定/发现（→ knowledge/experiments/2026-08-27-m22-door-interact-sync.md）：
  - 宿主须广播"曾经非默认"字段（ever-seen），否则关门/解锁永远到不了 joiner；
  - autoClose 门 open 不同步（游戏存档语义）+ open/lock 滞回（10 条 unitsync）——rbl door3 是游戏侧 1.4s 周期循环门，忠实镜像会变 setAct 风暴；
  - 同机残留测试实例抢 23456 端口致串线：bind 失败现在写 RConnect.log，测试换 M2_PORT；
  - 本机工具链：flexsdk 在 D:\RemainsMod\...\tools（AIR SDK 51.3.3，须显式 -swf-version=38），Java 11 在 _sandevistan_dev\jdk-11（build_mod.py 已修）。
- 遗留/下一步：门被摧毁 die(-1) 未做双实例专项；客户端交互上报宿主（双向门）未做；容器搜刮 joiner 侧等有容器房间现场验证；其余按 MEMORY §6。

---

## 2026-08-27 外置记忆迁移

- 由 state/current-status.md + 顶层 HANDOFF.md 拆分迁移（原文在 git 历史）：现行状态 → state\MEMORY.md；14 条关键坑清单 → knowledge/facts/engineering-pitfalls.md；M1-M20 里程碑流水浓缩为下方条目。
- 注意：HANDOFF 提及的 M21 仅存在于 git 提交信息，无实验文档——后续接手者应从 git log 补认。

---

## 开发历程（M1–M21，每条含实验文档指针，新在上）

### 2026-08-21 M21 敌人可见性漏洞修复 + 会话报告诊断
- 内容详见 git 提交（无独立实验文档）。

### 2026-08-20 M14–M20 观感与"宿主权威"全面补齐（六连发）
- **M14** 幽灵走路动画修复（密封类 #1069 中断 driveVisAnim）+ 武器镜像（new Weapon 挂幽灵手）+ 探索迷雾同步（visi 掩码广播）。→ knowledge/experiments/2026-08-20-m14-*
- **M15** 双存档随机图布局差异根因 = LandAct.landStage 随存档持久化参与房间池过滤 → adoptHostLandParams 采纳宿主 stage；幽灵趴姿修复（sost 每帧强制 1）。→ m15-landstage-pose
- **M16** 姿态终局（幽灵优先镜像对方真实 osn 标签）+ 物品/箱破坏状态同步（objs 快照按 id 镜像）。→ m16-pose-mirror-objs-sync
- **M17** 瓦片破坏差分广播（200ms 对比 loc.space，仅 1 次重绘）+ 新生成物品/Loot 镜像（沿 Pt 链扫描）。→ m17-tile-loot-sync
- **M18** 外观镜像（快照带 Appear 六元组，构造时临时换全局）+ 悬浮药水假象修复（isFly 每帧 false）。→ m18-appearance-mirror
- **M19** 敌人同步三件：皮肤 vf、死亡掉落、仇恨朝向 cx/cy。→ m19-enemy-sync
- **M20** 鲁棒性：兜底姿态 free1、外观热更 restyleGhost、近身敌人转火（每轮≤4）。→ m20-robustness

### 2026-08-19 M13 随机图（rnd）房间布局确定性
- 根因：房间几何结构随机点仅 7 处、全在 Land.as，双实例 Math.random 时序不同 → 布局分歧。
- 修复（游戏文件，已授权）：tools/patch_land_determinism.py 给 Land 加静态 PRNG（fnv1a(act.id) 播种），rnd 土地自动播种 → 双端同布局；内容随机保留。三份 SWF 一并补丁（备份+双标记+全加载器校验）；基线刷新至 build/backup/current-merged-20260819/。
- 验证：双实例同 locId+同坐标+同 8 点 tile 指纹。→ knowledge/experiments/2026-08-19-m13-rnd-layout-determinism

### 2026-08-18 M11–M12 用户报告的两个阻断性问题
- **M11 不同存档加入场景加载失败**：根因 = 加入方在世界过渡期（t_exit/t_die/comLoad）被 autoFollow 拉着跳房 → 反复重进注入不收敛。修复：GameBridge.isTransitioning() 门槛 + 读档前后 8s 跟随抑制。→ m11-save-follow-settle
- **M12 同地点两侧房间不同（失焦冻结）**：根因 = 窗口失焦游戏自动开 PipBuck 且无复位 → allStat=2 冻结。修复：优先级 1000 拦截 DEACTIVATE + forceCloseOverlays 兜底。→ m12-blur-pip-freeze；贡献 shared-knowledge window-blur-pip-allstat

### 2026-08-17 M8 + M10 世界注入与双向战斗收尾
- **M10a** 敌人打客户端化身：根因 = 化身 disabled=true 时 isMeet() 恒假；活体化（disabled=false + id_replic="" 禁言）。**M10b** 死亡/复活全链路（化身被动化→客户端原版回城→复活重建）。两个关键坑：中继伤害不能钳制（护甲减伤收敛陷阱，须中继原始命中量）；hp<0 是致死一击正常状态。→ m10-death-aggro
- **M8 房间内容同步**：reconcileWorld 扩到中立单位（fraction 0..99）；程序化读档 autoLoadSave（先 newGame 骨架再 comLoad，防 #1009）；三个连带修复（travelToLand 防护 / 世界替换基线重置 / 每轮重冻结）。→ m8-room-mirror

### 2026-08-16 世界注入 + 威胁归属（宿主权威两支柱）
- **世界注入**（worldInject）：宿主有本地无 → 按 AllData XML 动态生成傀儡；本地多出 → 移除；只处理敌人，单轮 8 上限幂等收敛。实测不同进度存档加入后 unitsync 6/6。
- **敌人威胁归属**（ghostCombat）：客户端幽灵在宿主世界成可攻击化身（显式关 invulner）；拉仇恨（priorUnit/celUnit 指化身）+ 伤害回传（化身 hp 下降 → 客户端 gg.damage 走原版流程）。实测双向 50 伤害闭环。

### 2026-08-15 建仓 + M1–M6 联机管道全线打通
- 授权补丁三份游戏 SWF（loader 注入，patch_game_swfs.py 幂等+备份+双标记）；版本指纹落地（World.boxDamage）；入口类 #2023 陷阱（RConnectDoc 空 Sprite）。
- **M1** 测试容器双实例全链路（加载契约/TCP 握手/中继/聊天）；**M2** 幽灵双向同步；**M3** 姿态动画+HUD+断线重连+聊天；**M4** 世界身份握手+单位镜像 27/27；**M5** 战斗权威闭环+跨房传送（gotoXY 挂死教训：autoTravel 移除）；**M6** 傀儡动画（像素级采样验证 blit 帧真渲染）+幽灵半透明/名字标签+跨地图传送。
- 深夜马哈顿闭环：UTF-8 帧长 bug 修复（长度前缀=字节数非字符数，俄文房间名曾流错位）；随机地图单位匹配率 ~60% → 成为 M8/M13 课题。
