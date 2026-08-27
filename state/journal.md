# RConnect —— 开发日志

> 协议见 GOVERNANCE.md §8：只追加不改写，**新条目插在最上面**。

## 2026-08-27 外置记忆迁移

- 由 state/current-status.md + 顶层 HANDOFF.md 拆分迁移（原文在 git 历史）：现行状态 → state\MEMORY.md；14 条关键坑清单 → knowledge/facts/engineering-pitfalls.md；M1-M20 里程碑流水浓缩为下方条目。
- 注意：HANDOFF 提及的 M21 仅存在于 git 提交信息，无实验文档——后续接手者应从 git log 补认。

---

## 开发历程（M1–M20，每条含实验文档指针，新在上）

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
