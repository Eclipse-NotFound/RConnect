# RConnect — 当前开发状态

> 本文件频繁更新，不是长期事实。游戏机制结论请查 knowledge/ 与 shared-knowledge/。
> **交接上下文入口：`mods/Rconnect/HANDOFF.md`**（新会话恢复顺序、里程碑表、
> 关键坑清单、测试手册、自检清单）。

- 最后更新：2026-08-17
- 版本：0.1.0-dev（尚未发布）

## 任务目标（长期）

让安装了 RConnect 的《Fallout Equestria: Remains》玩家通过互联网联机游戏。

## 本次会话授权记录

用户于 2026-08-15 明确授权：

1. **补丁游戏 SWF**：修改游戏目录中三份补丁后游戏 SWF（`pfe.swf` / `DLC/pfe.swf` /
   `DLC/pfeUI.swf`），在 MainFE 里加装独立的 RConnect 加载器，与 Sandevistan
   加载器并存（详见 decisions/2026-08-15-load-patch.md）。
2. **版本策略**：不确定实际游玩版本 → 尽量兼容 1.02 / 1.03 / 1.04。

## 已完成

- [x] 项目上下文恢复（AGENT_SCOPE / shared-knowledge / 启动链）。
- [x] 确认注入模型：补丁后 MainFE 用 Loader + 子 ApplicationDomain 加载模组，
      契约 = `getDefinition("<ModClass>").init(main)`，`init` 为静态方法，
      参数是 MainFE 实例（knowledge/facts/loader-contract.md）。
- [x] 查明三份游戏 SWF 只有单模组加载器（只加载 Sandevistan），无多模组机制。
- [x] 工具链确认：ffdec-cli 26.2.1（反编译/重编译）、AIR SDK + Flex SDK
      （位于 C:\Users\micha\Documents\_sandevistan_dev\，不在本仓库内）。
- [x] 补丁工具 `tools/patch_game_swfs.py`（幂等、自动备份、双标记校验），
      副本验证通过（1016 类无增减，差异仅三处新增）。
- [x] 补丁已应用到三份游戏 SWF，备份在 `build/backup/`。
- [x] 模组源码 + 编译链路：`tools/build_mod.py` → `release/RConnectMod.swf`
      （12 类，swf-version 38，AIR 内容）。关键坑：
      - 入口类不能当 mxmlc 主类（否则 #2023），需空 Sprite 文档类 RConnectDoc
        并强引用 RConnectMod 防死代码消除；
      - mxmlc 对"全部 return 在 try/catch 内"的函数误报"无返回值"，需尾随
        兜底 return；
      - Windows ADL 的 trace 不进 stdout，模组日志必须写文件
        （Log 类，app:/ 写不进时回退 applicationStorageDirectory）。
- [x] 独立测试容器（build/testapp，AIR 30 运行时）双实例联机全链路通过：
      加载契约、TCP 握手、peer 分配、worldstate 中继、聊天转发
      （knowledge/experiments/2026-08-15-testcontainer-m1.md）。
- [x] **真机冒烟测试通过**：三份补丁后游戏 SWF 都能正常启动，Sandevistan 与
      RConnect 加载器并存工作（互不影响）；`fe.World.w` 可访问、world=true、
      HUD 上屏。
- [x] **版本探测落地**：启动链真相 = `application.xml → pfe.swf`（**1.02**，
      用户默认游玩版本；app.xml → 1.03，app104.xml → 1.04）。版本指纹 =
      `World.boxDamage`（0.2=1.02 / 0.3=1.03|1.04），从 World 实例
      constructor 读取；三版本真机实测吻合
      （knowledge/facts/version-fingerprint.md）。

## 进行中 / 已完成

- [x] **M2 完成**：幽灵单位双向同步（真机 1.02 双实例验证通过）。
- [x] **M3 完成**（2026-08-15 真机双实例验证）：
  - **姿态动画**：幽灵换用 visualPlayer 视觉，按位移驱动
    `osn.gotoAndStop(标签)+osn.body.play()`（stay/run/walk/jump 双向实测，
    机制见 shared-knowledge/rendering/facts/player-vis-anim-pipeline.md 与
    knowledge/experiments/2026-08-15-m3-ghost-anim.md）。
  - **HUD 血量**：状态面板显示远程玩家列表与 hp。
  - **断线重连**：意外断线自动重连（2s 间隔、限 20 次、单通道防竞态），
    kill 宿主→持续重试→宿主回归→自动恢复+幽灵重建，实测通过。
  - **聊天**：自己消息本地回显、发送后焦点保持。
- [ ] M3 遗留：动画阈值（run≥6px/walk≥1px/50ms）按真实联机观感校准；
      幽灵与玩家视觉区分（名字标签/半透明）待定。
- [x] **M4 完成**（世界一致性 MVP，2026-08-15 真机双实例验证）：
  - 世界身份握手：welcome 携带 {curLandId, curCoord, locId, x, y}，
    双方进游戏后对比——**同模板新档 = 同地图（rbl）同房间（loc0_0）
    同坐标源**（landMatch=true locMatch=true）。
  - 单位镜像：宿主 5Hz 广播 loc.units 快照（id/坐标/朝向/sost/hp/fraction），
    客户端按 Unit.id 匹配驱动——**27/27 持续全匹配**，无异常。
  - 详见 knowledge/experiments/2026-08-15-m4-world-sync.md；
    世界身份公开字段已贡献 shared-knowledge/world-objects/facts/
    world-identity-determinism.md。
- [x] **M5 完成**（战斗权威 + 跨房传送机制，2026-08-15 真机验证）：
  - **M5a**：客户端冻结被同步单位 AI（freezeAI 配置）消除镜像抖动，
    实测无异常；副作用=客户端敌人成"雕像"（M6 待傀儡动画驱动）。
  - **M5b**：伤害事件化闭环——客户端命中检测（hp 低于同步基线）→
    上报 {id,dmg} → 宿主 `Unit.damage` 权威结算 → unitsync 回流。
    实测：`reported 4/5 damage hits` ↔ `applied 4 client damage hits`。
  - **M5c**：宿主 unitsync 附 worldInfo，客户端按 autoFollow 调
    `Land.gotoXY` 跟随换房 + gg 摆到宿主坐标；机制已接线。
    **教训**：自动化测试用 gotoXY 跳任意房间会把游戏整个挂死
    （AIR 单线程死循环），autoTravel 已移除；真实走门换房跟随待手动验证。
  - 详见 knowledge/experiments/2026-08-15-m5-combat-travel.md。
- [x] **M6 完成**（2026-08-15）：
  - **M6a 傀儡动画（像素级验证通过）**：unitsync 附 animState，客户端冻结
    单位按公开 `animate()` 驱动（blit 管线在游戏侧执行，免触碰 internal）。
    实测：冻结凤凰（blit）显示位图采样 `599552 -> 49439` —— 帧真实渲染，
    雕像问题解决。
  - **M6b 幽灵视觉区分**：半透明 0.75 + 头顶名字标签（翻转抵消），无异常。
  - **跨地图传送**：标准入口 `Game.beginMission/gotoLand`（含 exitLand 流程）
    实测进入马哈顿废墟（random_mane，击杀 alicorn 证实）；贡献
    shared-knowledge/world-objects/facts/land-travel-api.md。
- [ ] M6 遗留 / M7 候选：
  - **敌人房间完整战斗测试**：raiders 的 loc2_1 开局无敌对单位
    （unitsync 仅 1/1），需找"确定性且开局含敌"的场景（nio/core/garages
    待选）或真人手动测试；
  - 随机地图（random_mane 等 rnd）内容按 Math.random 生成，双实例不一致，
    联机同步宜限定 story/base 土地；
  - 敌人威胁归属（冻结后敌人不打客户端玩家，需宿主侧判定方案）；
  - 幽灵标签/透明度观感调优。

## 最新验证（2026-08-15 晚，RVision 修复后）

- 游戏 SWF 无他人新改动；RVision 修复生效（传送后无 #1056）。
- **跨地图跟随闭环**：宿主 travelToLand(raiders) 无挂死、心跳持续；
  客户端 `followed-land(raiders)`；双方 `raiders/loc2_1`
  landMatch=true locMatch=true（同房间同坐标源）。
- 傀儡动画在新地图继续 LIVE（像素采样 599552→49439→30208）。
- 伤害测试过滤器收紧为 fraction 1..99（曾命中中立触发器导致宿主崩溃）。

## 马哈顿（random_mane）联机验证通过（2026-08-15 深夜）

- **关键协议 bug 修复**：长度前缀此前用 String.length（字符数）而体用
  UTF-8 字节——含俄文房间名后流错位（bad frame length，连接循环）。
  改为 ByteArray 计字节数后消失（knowledge/discoveries/utf8-frame-length.md）。
- **马哈顿闭环实测**：
  - 双方 `random_mane/loc0_4` landMatch=true locMatch=true（随机地图下
    仍同房间，单位镜像 6/10~4/7 部分匹配——随机内容部分一致）；
  - 傀儡动画 LIVE（6547976→49669）；
  - 宿主死亡回城（rbl/loc0_0）也被客户端自动跟随——双向跟随完整。
- 结论：联机管道（传送跟随/单位镜像/傀儡动画/伤害中继/聊天/断线重连）
  在含敌地图全部工作。随机地图的单位匹配率（~60%）是 M8 课题
  （同步房间内容/随机种子）。

## 世界注入（房主权威存档）——2026-08-16 完成

- **需求**：加入方无需准备与房主一致的存档，直接玩房主的存档。
- 实现：worldInject（默认开）——客户端与宿主同 land 同 loc 时，
  `reconcileWorld` 把本房间敌对单位集合镜像成宿主快照：
  - 宿主有而本地没有 → 按类名 + `AllData.d` 单位 XML 动态生成傀儡
    （doop/unres/disabled，与镜像单位同样驱动）；
  - 本地多出（宿主世界没有）→ remObj+splice 移除；
  - 只处理 fraction 1..99（真敌人），不碰中立触发器/友好 NPC；
  - 单轮注入上限 8，幂等收敛。
- 实测（join 用完全不同进度的存档 PFEgame1，host 在马哈顿）：
  - `followed host to loc loc1_4`：从自己存档世界跟随进马哈顿；
  - `injected turret1/turret3/turret2` + `removed local extra slaver5/slaver6`；
  - **unitsync matched 6/6**（注入后房间 100% 镜像）。
- 限制：房间里的中立物体/触发器（门、箱）仍来自加入方本地世界生成
  （房间结构以加入方为准）；敌人威胁归属仍待做。

## 敌人威胁归属（宿主权威双向战斗）——2026-08-16 完成

- **宿主侧客户端化身**：ghostCombat（默认开）——客户端幽灵在宿主世界
  成为可攻击化身（doop/unres/invulner=false；UnitPonPon 构造自带
  invulner=true，必须显式关）；血量初始取客户端快照（hp/maxhp）。
- **拉仇恨**：客户端伤害中继结算时，宿主把敌人 priorUnit/celUnit 指向
  该客户端化身 → 敌人转向攻击化身（需在 isMeet 距离内）。
- **伤害回传**：宿主每 500ms 监测化身 hp 下降 → MSG_PLAYERDMG →
  客户端 `gg.damage()` 走游戏自身伤害流程（护甲/死亡 UI 正常）。
  化身 hp≤0 时在宿主侧保底为 1（死亡流程由客户端本地处理）。
- 实测闭环：`ghostDamageTest hp=1020 → relayed 50 damage ↔ took 50
  damage from host world`（双向 ×2）。
- 剩余课题已由 M10 完成（见下节）：敌人主动索敌、联机死亡/复活协调。

## 敌人威胁均衡 + 死亡/复活协调（M10）——2026-08-17 完成

- **M10a 敌人会打客户端化身了**：根因 = 化身 `disabled=true` 时
  `isMeet()` 恒假、敌人永远锁不上（M9 拉仇恨下一帧就被 findCel 清掉）。
  修复：ghostCombat 下化身活体化（disabled=false + id_replic="" 禁言，
  UnitPonPon.control 只有气泡台词）。实测：join 攻击→宿主拉仇恨→敌人
  转攻化身→~40 次真实伤害中继（relayed 81.56/86.55/... ↔ took 对应掉血）。
- **M10b 死亡/复活全链路**：客户端死亡→宿主化身被动化（停挨打、不上报）；
  客户端原版回城流程（t_die→enterToCurLand→resurect）；复活后化身重建、
  跨土地自动隐藏；follow 冷却 8s + `Pers.dopusk()` 身体伤重门控探测
  （不再 200ms 刷屏 travelToLand）；测试钩子 autoHeal（Pers.healAll）。
  实测 3 轮：took 2000 → died → blocked-body → revived → healTest →
  followed-land；host 侧 passive→despawned→spawned→combat restored。
- **两个关键坑（见 knowledge/experiments/2026-08-17-m10-death-aggro.md）**：
  ① 中继伤害不能钳制为剩余血量（客户端护甲减伤 → 收敛陷阱永不致死），
  必须中继原始命中量；② `hp<0` 是致死一击的正常状态，不是探测失败。
- 测试钩子过滤 `fe.unit::UnitTrigger`（攻击触发器曾崩宿主）。
- 新配置项：autoGhostDmg / testGhostDmg / autoHeal（测试用，默认关/50）。

## 房间内容同步（M8）——2026-08-17 完成

- **世界注入扩展到中立单位**：reconcileWorld 范围 = fraction 0..99（敌人+
  中立 NPC/装饰/动物），玩家阵营（100：宠物/玩家陷阱）不同步。实测
  random_mane：注入 tarakan/merc×3/vortex/turret0、移除 trigridge/damshot/
  damgren、7/7 全匹配；stable_pi/rbl 确定性内容 25/25。
- **边界确认**：门/箱是 `fe.loc.Box`（Obj，瓦片级）不可镜像；随机地图
  直接调 Math.random 无种子可同步（要改游戏本体，暂不做）。
- **程序化读档钩子 autoLoadSave**（原版 comLoad 通道）：关键坑 gui/sats
  只在 newGame 创建，直接 loadGame 会 #1009——先 newGame 骨架再 comLoad。
  join 已能加载用户真实存档联机（25/25 匹配）。
- **三个连带修复**（见 knowledge/experiments/2026-08-17-m8-room-mirror.md）：
  ① travelToLand 就绪/重入防护（rbl 挂死）；② 世界替换后基线重置
  （幻影伤害 152 条归零）；③ UnitNPC 自我解冻 → 每轮重冻结 + 伤害上报
  只限 fraction 1..99。
- 新诊断：dumpGameError()（verror.txt.text 错误对话框文本进日志）。
- 新测试钩子：autoLoadSave；M2_JOIN_LOADSAVE/M2_JOIN_QUIET 环境变量。
- M10 战斗回归通过（56 applied / 2 轮死亡复活闭环）。

## 其他开发者协作状态（2026-08-15 更新）

- 根 `pfe.swf`（1.02）已被 4 个模组 loader 合并（Sandevistan/RConnect/
  RealisticVision/MoreSkills&Weapons），**本模组 loader 段保留完整**（已反编译
  核验）。`DLC/pfe.swf`、`DLC/pfeUI.swf` 仍为 Sandevistan+RConnect。
- 其他开发者贡献了公共知识：mod-loader-patch-structure（含"LoaderContext(false)
  未传域=同域加载"修正）、grafon-drawallobjs 冲突记录、bullet-wall-impact 等。
- 本模组合并前备份已刷新到 `build/backup/current-merged-20260815/`。
- **改游戏文件前必查**：对比 `build/backup/current-merged-20260815/` 哈希，
  若他人有改动则按 patch_game_swfs.py 的锚点合并（失败即报错，不静默产出）。

## 已知风险 / 待验证

1. **Sandevistan 同步覆盖**：三份游戏 SWF 归 Sandevistan 部署同步管理
   （见游戏根目录 MODS_MIRROR_NOTICE.txt）。其 sync 可能覆盖本补丁；
   重跑 `tools/patch_game_swfs.py` 即可恢复。若其同步更新了 MainFE 结构，
   脚本会因锚点缺失而明确报错，需人工适配。
2. **运行时网络能力已确认**：ServerSocket/Socket 在游戏同款 AIR 30 运行时下
   实测可用（测试容器双实例互连通过）。
3. **跨域 loaderInfo 异常**：模组子域读 main/stage 的 loaderInfo 会返回模组
   自己的 URL（knowledge/discoveries/loaderinfo-cross-domain-anomaly.md），
   版本识别与一切跨域判断都以实例 constructor/类指纹为准。
4. **NAT 穿透**：MVP 直连（手动 IP+端口），公网联机可能需要端口转发；
   后续可考虑公共中转服务器。
5. **世界一致性前提**：需同模板/同存档开局才成立（M4 已实测同房间同坐标源）；
   不同进度的存档世界不兼容，单位状态由宿主 5Hz 权威覆盖。
6. 其他模组（Sandevistan 等）一律未读取、未修改。游戏原始文件除授权补丁外
   未改动。

## 下一步（剩余课题）

1. **门/箱（瓦片级 Obj）同步**：需碰瓦片/渲染层，公开 API 不可行；随机
   地图种子同步需改游戏本体（Land.as 的 Math.random）——两者都属"改游戏
   文件"级方案，需用户确认授权后才评估。
2. 观感/体验：幽灵标签与透明度调优、真实玩家手动双开体验测试（需用户参与）。
3. 网络：NAT 穿透（目前直连需端口转发）、公共中转服务器（远期）。
4. 回归验证：手动联机场景（换房跟随、跨地图跟随、读档联机）待真人确认。
