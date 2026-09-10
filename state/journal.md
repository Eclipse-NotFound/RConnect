# RConnect —— 开发日志

> 协议见 GOVERNANCE.md §8：只追加不改写，**新条目插在最上面**。

## 2026-09-10 M28 候选部署完成，供用户测试

- 按用户授权部署 10d46ac 对应普通候选至 release/RConnectMod.swf，44963 字节，SHA-256 2A65D5F83567BD1FB8D537270BEE4499FBAA7BF6EF2EAF89BE161BFDE0A8CF56；旧版备份 build/backup/m28-release-20260910-153718-905444/RConnectMod.before.swf。配置及游戏三份 SWF/主描述符前后哈希一致。
- 正式资源根独立 ID 两次建图 #1009 均回滚；只读确认 MSWAutoTest 对全部非 pfe 自动开档，错误时 RR 房间未 finalize。旧版延长观察在 35 秒通过。未改其他模组，未把全组合判为通过。
- 最终从正式 release 读取产物，隔离 host/join 检查 80abe809ae 的新版初始化、心跳、welcome、单位同步通过，测试进程已清理。未改源码/重新编译，此前 42 项功能证据仍适用。
- 详见 state/deployment-m28-2026-09-10.md；用户重启后 F10 测试，完整组合与真人体验待反馈。主侧顺序完成，无委托。

---

## 2026-09-10 M28 部署首次检查失败并回滚

- 用户明确要求部署候选；核验候选与既有测试哈希后，备份至 build/backup/m28-deploy-20260910-152024-b20615/RConnectMod.before.swf。
- 正式资源根下独立测试实例的 0.2.0-dev 初始化成功，随后 Land.prepareRooms/newGame2 报 #1009，未到 tick 200；已自动回滚旧 release 并关闭本轮 PID 7204，未动用户进程/存档。
- 原因待核验；证据在备份目录 RConnect.log、stdout.log、deployment.json。再次部署必须重新通过检查。

---

## 2026-09-10 M28：补齐已有合作交互、角色显示与退出清理

- 做了什么：按用户排除稳定重连/三人以上/真实网络/版本兼容、暂不扩展任务背包交易的范围，新增房间内对象稳定身份；修双向关门/解锁/破坏、脚本门与 Box 补建；特殊敌人改原生地图参数构造；玩家内外层姿态与换装实际替换；拾取物完整堆叠/状态、吸入移动与无 60 件截断；念力插值基线、EXIT_FRAME 显示和退出恢复访问过房间的原 AI 标记。
- 关键发现：真实双实例曾发现脚本门关闭意图被旧瓦片同步覆盖，修为保留待确认意图直至宿主回应；收尾复核补跨房间恢复记录。原 M27 日志的“加载顺序保证”不成立，本轮改用帧事件阶段消除该依赖，但未声称实际 RV 组合验收通过。
- 验证：e8f2045028、563e74694c 两轮各 40 项通过；最终 65e809e940 为 35 项直接桥接/原生对象检查 + 7 项真实双实例 = 42 项通过；最终普通候选 5ce32a15a1 启动/连接通过。失败轮 a33ec2e235 保留。测试全程独立游戏副本、随机专用 AIR ID、全新角色、仅清理本轮 PID。Python 语法、输出保护和 diff 检查通过。
- 产物：源码版本 0.2.0-dev；普通候选 build/m28/RConnectMod.swf，44963 字节，SHA-256 2A65D5F83567BD1FB8D537270BEE4499FBAA7BF6EF2EAF89BE161BFDE0A8CF56。release 及游戏 SWF 未改，当前安装仍为旧版。新增 tests/ 三入口、tools/run_coop_regression.py；构建脚本支持独立候选和测试入口。
- 证据/遗留：knowledge/experiments/2026-09-10-m28-cooperation-validation.md 与 m28-validation-evidence.json 保存覆盖表、失败修复、断言和哈希。真人观感、实际多模组组合、全部地区/Boss 阶段/完整流程留待后续；同名对象初始重合、循环门语义与排除目标没有伪称完成。由主侧顺序完成，未委托子代理。

---

## 2026-09-10 接手调查：目标与 M27 执行现状核对

- 做了什么：读取权限、记忆、设计、近期实验及网络/会话/游戏桥接源码，确认代码基线 master/a32633f；新增 state/handoff-2026-09-10.md 的目标—实现—待验矩阵，更新滞后于 M26/M27 的 MEMORY。
- 关键发现：区分 WORLDSTATE 与 UNITSYNC 频率；M26 念力平滑已实现，TDFC 测试误触发已在其 v0.5.4 修复。M27 加载先后保证与离线显示清理仍待验证；手动 Join 默认不自动重连，监听失败后模式提示不一致。完整内容、多人与真实网络验收不能由同机双实例记录推定。
- 验证边界：仅静态检查及工具路径存在性核对，未编译/运行/部署，未修改源代码、release、游戏文件或用户存档；旧游戏 loader 核验仍标历史，不假称本轮通过。
- 遗留/下一步：当前同步缺口与 M26/M27 体验验收优先；自动化前核实 pfe2/pfe3 占用与存档模板，避免旧脚本干扰用户第二窗口。详细证据和范围见接手报告。

---

## 2026-09-07 M27 强制显示宿主可见敌人（用户拍板 a："队友报点"）

- 做了什么：applyUnitsSync 每轮重建存活镜像集（sost<3 且非 invis），GameBridge 构造时挂 ENTER_FRAME 每帧恢复 vis.visible+prior（被 RV 视距整只隐藏的镜像敌人）。
- 关键发现：零闪烁靠**同帧注册顺序**——RV 的隐藏也在 ENTER_FRAME 且先于本模组初始化，同帧回调按注册顺序，我们的恢复必然在其后。
- 验证（m27_run1）：M26 实证 s=0 的敌人 → 全部 s=1；RV 在视野内软边遮罩（m=1）原样保留；5/5 匹配零错误。
- 遗留/下一步：观感待用户实测（黑暗中敌人现在应可见）；window1 类无 inter 脚本门不同步仍待用户确认是否为其测试对象；RV 会话可选做联机豁免（选项 b，未动）。

---

## 2026-09-07 M26 念力平滑 + 门复验 + RV 视距敌人隐藏定位

- 做了什么（grilling 轮答后）：①念力平滑（上报 1Hz→5Hz + 接收端 tween 插值）；②注入/镜像落点校验（修 rr_showroom #1010 崩溃）；③诊断埋点（宿主门清单 + joiner 敌人可见性采样）；④双实例复验门/箱全通。
- 关键发现（→ knowledge/experiments/2026-09-07-m26-*）：
  - **敌人"不显示"根因 = RV（RealisticVision）视距机制 × 联机**：RV 把不在本地玩家视线内的敌人整个隐藏（hideUnit→vis.visible=false），采样实证 merc2 s=0。宿主看得见的敌人在加入端自己的黑暗里。修法待用户拍板（A 强制显示镜像敌人 / B RV 侧豁免 / C 现状）；
  - 门机制复验通过（doorIcTest 开关→joiner ist apply open 双向）；random_mane 门清单 door1/door1a 均 ac=0 可同步，**window1 类无 inter 的脚本门不同步**（宿主开它走 scrOpen，我们读不到）——用户测试的门可能属此类或当时不同房；
  - 扫描提速后 ist 稳定性门 3→6 次（5Hz 下 ≈1.2s，循环门照滤）；
  - phoenix p=0（vis 未挂树）观察项待跟。
- 遗留/下一步：敌人显示修法等用户第二轮拍板；脚本门同步评估待确认；念力平滑观感待用户实测。

---

## 2026-09-06 Steam 还原游戏 SWF 事件（#1009 报错根因）+ 恢复

- 做了什么：用户报"进入游戏 #1009（Invent.addLoad）"→ 排查发现三份游戏 SWF 于 09-06 05:46 被 Steam 还原（体积 -7.5KB、loader 标记全无、今早 07:11 主游戏以纯原版启动）——原版物品表没有存档里的 MSW 模组物品 → `Invent.addLoad` 的 `this.items[id].kol` 空引用。**存档本身没坏**。按 remains-game-update runbook + 2026-08-15 授权，从基线备份恢复：备份 Steam 原版（build/backup/steam-restore-20260906-0546/）→ 覆盖 current-merged-20260819 三份 SWF → 测试实例验证指纹 `game version=1.02 bd=0.2` + RConnect 初始化 ✓。
- 关键发现：
  - 诊断捷径：模组日志**完全无新行**（连 mod init 都没有）= loader 不在；先查 SWF mtime/标记再怀疑代码。
  - 基线恢复比重跑 6 个模组补丁脚本更稳（current-merged-20260819 含 6 loader + M13 Land 补丁，字符串扫描校验过）。
  - 跑测试实例遇到"静默无输出"先别当挂死——原版游戏开到菜单就是静默的（stdout 缓冲不 flush）。
- 遗留/通知：主游戏 07:11 起的实例是原版（内存里没 loader），**用户需重启游戏**；其他模组会话请核验各自功能（loader 已随基线恢复）；若 Steam 再次校验，重跑本恢复路径即可（原版备份 + 基线都在 build/backup/）。
- 附带：run_m2_dualtest.py 加 M2_LOADSLOT（程序化读档槽位可配）。

---

## 2026-09-05 second_player.bat 存档镜像（用户工具改进）

- 做了什么：用户报告第二窗口读档菜单为空——根因是 pfe2 实例存储与主档案（%APPDATA%\pfe\）天然隔离且从不复制。重写 bat（纯 ASCII/CRLF）：启动前把主档案全部 PFEgame*.sol + config.sol **只读镜像**到 pfe2（每次启动刷新到最新进度），并清理残留第二窗口实例（只按描述符特征匹配，绝不动主窗口）。
- 冒烟：11 槽全部镜像 ✓、第二窗口进程起来 ✓、模组初始化 ✓（读档入口在游戏菜单，需用户手动加载后 F10 加入）。
- 注意（已写进 bat 注释与文档）：第二窗口是测试实例，它自己存的进度会被下次启动的镜像覆盖；主档案只读不写。

---

## 2026-09-05 M25 念力移动物品同步 + 门/容器状态双向

- 做了什么：读用户真实联机日志诊断三项报告——敌人"不渲染"实为 boss(alicorn)/mine 类注入受限（其余 27/27 正常，注入失败日志已加堆栈）；念力 Box 位置与门 ist 补双向：objs 快照带 wall/托举态，joiner id+就近落位（含边界+抗重力）；新消息 MSG_OBJS 上报 joiner 移箱与 ist 变更，宿主 setAct+ever-seen 重播收敛；本地偏差保护（镜像不吞本地移动，M24 loot 推动同洞一并修）+ 3s 稳定性门（滤循环门风暴：545→0）+ ist 扫描按对象实例跟踪（同 id 多箱互殴修复）。
- 关键决定/发现（→ knowledge/experiments/2026-09-05-m25-levit-box-ist-bidirectional.md）：
  - 双向同步三件套：镜像保护+上报通道+收敛检测（基线刷新时机是止振关键）；
  - 按 id 的状态机在同 id 多实例房间必然互殴——一律按对象实例+附位置就近匹配；
  - 新档 travelToLand 到基地型土地（rbl/stable_pi）触发游戏侧 buildProb #1009（测试环境坑，random_mane 稳定）；
  - 用户真实日志（%APPDATA%\<appid>\Local Store\RConnect.log）是最快诊断入口。
- 遗留/下一步：alicorn 注入待用户实测堆栈定位；念力动画平滑度（5Hz 近似）；其余按 MEMORY §6。

---

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
