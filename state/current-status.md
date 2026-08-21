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

## 不同存档加入——场景加载修复（M11）——2026-08-18

- 用户报告：玩家 1、2 存档不同时，玩家 2 的场景无法正常加载。
- **根因**：加入方在**世界过渡期**（t_exit/t_die/comLoad 任一进行中）
  就被 autoFollow 拉着跳房/传送——入场逻辑把房间重置回出生点，
  反复重进、注入永不收敛（followed 循环 / injected 0 / matched 1/10；
  AIR stdout 土地建 4666ms 异常耗时）。
- **修复**：`GameBridge.isTransitioning()`（t_exit>0||t_die>0||comLoad>=0）；
  followHostWorld/travelToLand/autoMove/damageTest 全加过渡门槛；
  autoLoadSave 读档前后设 8s 跟随抑制窗口；诊断心跳附世界身份与
  过渡状态；`dumpGameError` 空文本也记录；复现钩子 `autoHostKill`。
- 验证（不同存档 + 宿主马哈顿 + 宿主自毁回城）：
  - join 稳定跟随 random_mane/loc0_4（t_exit=0/verror=false），注入 14/14；
  - 宿主死亡回城后 join 跟随到 rbl/loc0_0，注入 **27/27**；
  - 无重进循环、无卡死；默认战斗场景回归通过（applied 4/relayed 5/
    died 2/revived 2）。
- 详见 knowledge/experiments/2026-08-18-m11-save-follow-settle.md。

## 同地点两侧房间不同——失焦冻结修复（M12）——2026-08-18

- 用户报告：宿主和加入方进入同一地点（马哈顿）时两侧显示的房间不同。
- **根因**：窗口失焦时游戏 `World.onDeactivate → pip.onoff(11)` 自动打开
  PipBuck 且**无复位机制**（无 ACTIVATE 处理）→ `pip.active=true` →
  `allStat=2` → World.step 的 gameplay 块与旅行过渡（exitStep）整体冻结
  → 被失焦的一方卡在旧房间（旅行中途 t_exit 停在 16）。间歇性
  （自动化约 1/3 轮次命中）。双窗口同屏时点另一个窗口就触发。
- **修复**：
  1. **源头拦截**：GameBridge 构造时在同一 Stage 上以优先级 1000
     `stopImmediatePropagation()` 拦下 `DEACTIVATE`，游戏开 pip 路径
     永久失效（副作用：失焦自动存档取消，周期性 t_save 不受影响）；
  2. 兜底：`travelToLand`/`gotoXY` 前 allStat!=1 则
     `forceCloseOverlays()`（pip 原生 onoff(0)）+ 跳过重试；过渡中
     （t_exit>0 && allStat!=1）每 2s 恢复守护；
  3. 诊断：心跳带 allStat/pipA/satsA/standA/guiPause；复现钩子
     `autoDeactivate`（派发 DEACTIVATE）。
- 验证：`M2_DEACT=1` 确定性失焦——修复前 pipA=true 永久卡死，修复后
  pipA 全程 false、join 正常落定马哈顿 loc0_4；默认战斗回归 ×2
  pipA=0/allStat>=2=0，战斗链路正常。
- 新增 shared-knowledge：`ui-systems/facts/window-blur-pip-allstat.md`
  （allStat 覆盖层门控 + 失焦开 pip 无复位 + 优先级拦截法）。
- **注意区分**：随机土地（rnd）房间布局按 Math.random 生成、两侧内容
  不同，是与本冻结**独立**的另一个问题（需改游戏本体做确定性/种子同步，
  另评估）。

## 随机图（rnd）房间布局确定性（M13）——2026-08-19 完成

- 用户报告：host/join 进入马哈顿（random_mane）两侧房间不同、互相看不到。
- **根因**：房间几何由「模板+镜像+门位」决定，其结构随机点仅 7 处、全在
  Land.as（Explore 精读确认）；两实例全局 Math.random 时序不同 → 布局不同。
- **修复（游戏文件，已授权）**：`tools/patch_land_determinism.py`
  ~ Land 新增静态 PRNG（fnv1a(act.id) 播种 + LCG），构造 `if(this.rnd)`
  分支自动播种 → 双端同一 seed → 同一布局；7 处结构随机换 `rndNext()`，
  内容随机保留全局。已对 pfe/DLC/pfe/DLC/pfeUI 三份一并补丁（均备份+
  双标记校验+全加载器校验）。
- **mod 附带**：同房出生点对齐（首次同房相距>300px 一次性 setPos 到宿主
  坐标）；注入失败黑名单（boss alicorns 查不到 XML 时记一次、保持宿主
  权威，不再每轮刷日志）；debugTileGrid 8 点布局指纹。
- **验证**：3 轮双实例——同 locId+同坐标+同 tile grid（362,960 处 8 点
  完全一致）；matched 5/5 收敛；默认战斗回归通过（applied 3/relayed 5/
  took 5/died+revived 1+1）；无失焦冻结。
- **基线已刷新**：`build/backup/current-merged-20260819/`（含本补丁）。
- 取舍：rnd 图每次新档同一套布局（联机一致优先）；boss 远端镜像受限。

## 幽灵动画修复 + 武器/探索迷雾同步（M14）——2026-08-20 完成

- 用户报告：互见+移动同步 OK；但看不到对方走路动画与武器，当前房间
  "地图"（探索迷雾）两侧不同。
- **M14a 走路动画失效已修**：根因 = M6b 起名字标签引用存在密封类
  UnitPonPon 上，driveGhost 读它 #1069 → try 中断 → driveVisAnim 从未跑。
  改存动态类 vis；driveGhost catch 改每 id 一次错误日志。验证：宿主侧
  幽灵动画切换 236 次（walk/stay/jump）。
- **M14b 武器镜像**：快照带 wi/wv；`new Weapon(ghost,id,variant)` 构造同款
  武器挂幽灵手上，按 storona/aim 每帧校正。验证 `weapon #1 -> lmg`。
- **M14c 探索迷雾同步**：`loc.space[x][y].visi`（Grafon 暗幕）宿主已探索
  掩码随 worldstate 广播，加入方同房点亮。验证 `applied seen mask rows=25`。
- 默认战斗回归正常。详见 knowledge/experiments/2026-08-20-m14-*。

## 双存档随机图布局差异（landStage）+ 幽灵趴姿（M15）——2026-08-20 完成

- 用户报告：双方"继续游戏"进马哈顿，布局仍不同（能互见）；幽灵固定趴姿。
- **M15a 布局**：根因 = `LandAct.landStage` 随存档持久化且参与房间池过滤
  （newRandomLoc 用 lvl<=landStage）——双方存档 stage 不同（join=4/host=0）
  → 同种子不同池 → 布局分歧。修复：worldInfo 带 landStage/visited；
  加入方旅行前 adoptHostLandParams（采纳宿主 stage + act.land=null 强制
  重建；同土地 stage 不一致也重入重建，_adoptedSame 防循环）。
  验证：双存档场景采纳 4->0 后 8 点 grid 全一致（多次复现）。
- **M15b 趴姿**：诊断确认幽灵标签与本地一致（lbl=stay=站姿正确）；真凶
  是幽灵在宿主世界被击倒/击杀后 sost≥2 画倒地/尸体帧且不重置。
  修复：driveGhost 每帧强制 sost=1（姿态由快照驱动；死亡流程仍由
  scanGhostHp 重建）。验证：sost 恒 1、战斗回归正常。
- shared-knowledge rnd-land-generator-structure 补充 landStage 生成输入说明。
- 详见 knowledge/experiments/2026-08-20-m15-landstage-pose.md。

## 姿态镜像 + 物品/箱破坏同步（M16）——2026-08-20 完成

- 用户诉求：加入方真实存在于宿主存档（房间/物品/破坏由宿主权威复制）。
- **M16a 趴姿终局**：本地玩家静止 osn 标签 = `free1`（站立待机轮播），
  而旧 driveVisAnim 把静止硬映射为 `stay`=蹲/趴 → 趴姿。修复：快照带
  `pose`（对方当前标签），幽灵**优先镜像对方真实标签**（待机/蹲/跳/走
  全对）。验证：幽灵 osn 显示 free3（对方真实待机）。
- **M16b 物品/箱状态同步**：宿主 loc.objs 快照（id/dead/door/hp）随
  unitsync 广播，加入方同房按 id 镜像——破坏/开门状态一致。验证：
  33/33、58/58；`boxKillTest destroyed 'septum'` → join `box destroyed
  synced 'septum'`。
- 仍限制：墙体/瓦片破坏（炸墙洞）未同步（需瓦片差分+重绘，下一课题）；
  物品现场生成（宿主新生成）未镜像。
- 详见 knowledge/experiments/2026-08-20-m16-pose-mirror-objs-sync.md。

## 瓦片破坏 + 新生成物品/Loot 同步（M17）——2026-08-20 完成

- 用户诉求的最后两项"宿主权威"：宿主造成的房间破坏（瓦片）+ 现场生成
  物品（掉落）加入方可视。
- **M17a 瓦片破坏差分**：宿主每 200ms 对比 loc.space（phis/front/back/
  zad/zForm/water/stair/hp）与进房基线广播变化瓦片（持久状态+去抖重绘），
  加入方应用 + `World.redrawLoc()`。验证：opened 8,1 → patch applied 1 →
  **仅 1 次重绘**。
- **M17b 新物品/Loot 镜像**：Loot 在 Pt 链不在 objs——沿链扫描 fe.loc 系；
  模板 id 集过滤；每个 unitsync 报非模板 Obj（Loot 按 item base 重建）。
  验证：host spawn 'kofe' → join 生成（spawned=2 skipped=1，checkpoint 类
  安全跳过）。
- 关键坑：unitsync 无单位门槛会吞数据（已移除）、事件改持久+幂等、
  getQualifiedClassName 用 `::`、Loot 在链不在数组、持续补丁需变化检测。
- 详见 knowledge/experiments/2026-08-20-m17-tile-loot-sync.md。

## 外观镜像 + 悬浮/飞行药水效果修复（M18）——2026-08-20 完成

- 用户报告：对方形象与本地一样（幽灵都像自己）；对方有"飞行药水效果"；
  仍为趴姿。
- **根因**：visualPlayer 构造时从全局静态 Appear（ggArmorId/tr*/颜色）取
  外观 → 幽灵全按本地玩家外观构造；potion_fly 本体=isFly+黑色粒子拖尾，
  幽灵被悬浮物理带起即"飞行药水效果"；初始帧/姿态也连带本地初始化。
- **修复**：快照带 ap（Appear 静态+World.app 色+ColorTransform 六元组）；
  幽灵构造临时换全局 Appear → new visualPlayer → 还原。driveGhost 每帧
  isFly=false+sost=1（垂直位置只由快照决定）。验证：host 幽灵 armor=
  assault（对方）、join 幽灵 armor=pip（对方）——镜像生效；回归正常。
- 限制：外观在幽灵生成时套用，会话中换装需重建刷新（死亡/重连自动刷新）。
- 详见 knowledge/experiments/2026-08-20-m18-appearance-mirror.md。

## 敌人同步（A 外观 / B 死亡掉落 / C 仇恨朝向）——M19 完成（2026-08-20）

- unitsync 单位条目扩展 vf（小马 osn.pon 帧=皮肤）+ cx/cy（celX/celY=
  目标点/仇恨朝向）；加入方 applyUnitAppearance 应用到镜像与注入傀儡。
- 验证：A `enemy skin 'ponpon' hostVf=20 localPon=20`（确定性同皮，vf
  兜底分歧）；B 击杀→掉落 `obj spawn recv spawned=1 skipped=0`（M17 链
  零失败）+ sost 死亡回流；C celX/Y 每同步写入。
- 详见 knowledge/experiments/2026-08-20-m19-enemy-sync.md。

## 真机鲁棒性补强（M20）——2026-08-20 完成

- 兜底姿态 free1（"stay"=趴姿，旧客户端兜底绝不回落）；
- 外观热更（apKey 变化即 restyleGhost：换装即时，不依赖重生）；
- 近身敌人转火加入方（宿主每 1s，320px 内无目标敌人指向幽灵，每轮≤4）。
- 综合回归通过；战斗回归 relayed 5/took 5/died 3（转火生效）。
- 复测指引见 knowledge/experiments/2026-08-20-m20-robustness.md。

## 其他开发者协作状态（2026-08-18 更新）

- **新模组出现**：mods/ 下现有 6 个模组（新增 RandomRooms、TDFC，均由
  其他开发者维护，本模组一律不读取、不修改）。MoreSkills&Weapons 仍存在。
- **游戏 SWF 被再次合并**（2026-08-17/18）：
  - `pfe.swf`（1.02）：现含 5 个加载器（Sandevistan/RConnect/RealisticVision/
    TDFC/RandomRooms）——注意不再含 MoreSkills&Weapons 的加载器（他方合并
    选择，非本模组处理范围）；
  - `DLC/pfe.swf`（1.03）：Sandy/RConnect/RandomRooms；
  - `DLC/pfeUI.swf`（1.04）：Sandy/RConnect（未再变）。
  - **三份文件均仍包含 RConnect 加载器（已核验 app:/mods/Rconnect 标记）**，
    模组可正常加载。
  - 他方在游戏根目录留有各自合并前备份（pfe_1.02_before_tdfc_*、
    pfe_before_rrooms_*）。
- **合并基线已刷新**：`build/backup/current-merged-20260818/`（含我们加载器
  的当前三方 SWF）。今后"改游戏文件前必查"以 20260818 基线为准。
- 其他开发者新增公共知识（与本模组相关）：`world-objects/discoveries/
  world-rooms-field-injection.md`（World.w.rooms 原版恒 null；运行时注入
  房间池 + roomsLoad=0 + GameData.d 追加土地可行）——对 M8 遗留的
  "随机地图内容同步/种子"课题是重要可复用素材。
- **本模组 loader 段保留完整**（三版本核验）。重跑 `tools/patch_game_swfs.py`
  前必须先对照新基线（20260818）确认他人改动并合并，绝不直接覆盖。

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
