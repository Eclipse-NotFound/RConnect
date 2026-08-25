# RConnect 交接文档（HANDOFF）

> 本文档供新会话快速恢复项目上下文。接手新会话时按本文档顺序阅读，
> 全部细节以文中所引文件为准。最后更新：2026-08-17。

## 1. 项目定义

为同人 Flash 游戏《Fallout Equestria: Remains》（Steam 路径
`C:\Program Files (x86)\Steam\steamapps\common\Remains`，AIR 30 运行时）
开发多人联机模组 **RConnect**：安装了该模组的玩家通过互联网一起游玩。
核心卖点：**加入方无需准备与房主一致的存档，直接玩房主的存档**
（宿主权威架构）。

当前阶段：0.1.0-dev，**M1–M10 全部完成并通过真机双实例自动化验证**，
尚未公开发布。

## 2. 新会话恢复步骤（按顺序）

1. 读 `mods/Rconnect/AGENT_SCOPE.md`（**权限规则，最高优先**：只写
   mods/Rconnect；shared-knowledge 可读+谨慎写；游戏文件默认只读；
   其他 mods 禁改）。
2. 读 `shared-knowledge/README.md` + `shared-knowledge/knowledge-validation/`
   的 interop 事实（modding 约束：只可访问 public 成员、密封类 #1069、
   internal 不可访问、每字段独立 try 探测）。
3. 读 `mods/Rconnect/state/current-status.md`（里程碑完成记录 + 剩余课题 +
   协作状态 + 授权记录）。
4. **M11–M21 的本轮全部变更**（多次修复与里程碑：失焦冻结、随机图布局
   确定性+landStage、姿态/武器/探索/外观镜像、瓦片/掉落/敌人同步）——全部
   记录在 `state/current-status.md` 各节与 `knowledge/experiments/2026-08-20-*`、
   `2026-08-19-*` 中，优先通读 state 了解现状再动手。
5. 读 `mods/Rconnect/design/architecture.md`（架构）、
   `mods/Rconnect/decisions/2026-08-15-load-patch.md`（游戏 SWF 补丁决策）。
6. 需要时再读 `mods/Rconnect/knowledge/`（facts/discoveries/experiments）。
7. 本文件 §3 的摘要 + §7 的测试手册足够开始工作。

## 3. 现状摘要（里程碑）

| 里程碑 | 内容 | 状态 |
|---|---|---|
| M1 | 模组加载 + TCP 握手 + 测试容器 | ✅ |
| M2 | 幽灵单位双向同步（可见对方） | ✅ |
| M3 | 姿态动画 + HP 显示 + 断线重连 + 聊天 | ✅ |
| M4 | 世界身份握手 + 单位镜像（27/27） | ✅ |
| M5 | 战斗权威（客户端命中→宿主结算）+ 跨房传送 | ✅ |
| M6 | 冻结敌人傀儡动画（像素级验证）+ 幽灵标签/半透明 + 跨地图传送 | ✅ |
| M7 | 世界注入（不同存档加入：房间敌人镜像成房主世界） | ✅ |
| M9 | 敌人威胁归属：宿主侧战斗化身 + 伤害回传（双向战斗） | ✅ |
| M10 | 敌人索敌均衡（化身活体化）+ 死亡/复活全链路协调 | ✅ |
| M8 | 中立单位镜像 + 程序化读档钩子 + 三个连带修复 | ✅ |

联机体验现状：**任意存档加入 → 房主世界权威 → 一起打怪、互相可见、
敌人双向战斗、死亡回城复活协调、换图跟随、聊天、断线重连**。

## 4. 架构速览

```
mods/Rconnect/
  src/                        AS3 源码（amxmlc 编译，AIR 30）
    RConnectMod.as            入口类（默认包，static init(main)，加载器契约）
    RConnectDoc.as            空 Sprite 文档类（防 #2023 + 强引用防死代码消除）
    rconnect/game/GameBridge.as  游戏桥接（最大文件 1840 行：幽灵/镜像/世界注入/
                                 旅行/死亡协调/测试钩子）
    rconnect/core/Session.as     状态机 + 协议处理 + 宿主权威中继（845 行）
    rconnect/core/Config.as      配置（DEFAULTS + release/config.txt + 用户存储）
    rconnect/net/                TcpLink（长度前缀=UTF-8 字节数！）/HostServer/Protocol
    rconnect/ui/NetHud.as        F10 面板（host/join/chat/状态）
  release/RConnectMod.swf     编译产物（游戏经 app:/mods/Rconnect/release/ 加载）
  tools/
    patch_game_swfs.py         游戏 SWF 加载器补丁（幂等、锚点、自动备份、双标记）
    build_mod.py               编译（amxmlc，AIR_HOME=flexsdk 根目录）
    run_m2_dualtest.py         真机双实例联机测试（详见 §7）
    make_release.py            打玩家安装包（build/RConnect-v0.1.0.zip：INSTALL.txt
                               + 三份已补丁 SWF + mods/Rconnect 本体）
    patch_land_determinism.py   随机图布局确定性补丁（改 Land.as，三 SWF 已打）
    second_player.bat          双开第二窗口（GBK 编码！）：手动双人联机测试用；
                               依赖 tools/second_player_descriptor.xml（pfe2 身份），
                               自动写 %APPDATA%\pfe2 的手动模式配置
  state/current-status.md      持续更新的状态（本交接文档之外最重要的文件）
  knowledge/                   本模组私有知识（facts/discoveries/experiments）
  build/backup/                游戏 SWF 备份（current-merged-20260815/）
  README.md                    用户向教程（安装/使用/FAQ/已知限制）
```

启动链：Remains.vbs → 1.BAT → `adl64.exe -runtime runtimes\air\win64
application.xml` → pfe.swf（1.02，用户默认版本；DLC/pfe.swf=1.03、
DLC/pfeUI.swf=1.04）。游戏 SWF 内 MainFE 已含 4 个模组加载器
（Sandevistan/RConnect/RealisticVision/MoreSkills&Weapons）。

协议：TCP 帧 = uint32 BE 长度 + UTF-8 JSON；宿主权威：客户端发
PLAYERSTATE/伤害上报，宿主广播 WORLDSTATE(玩家)+UNITSYNC(5Hz 单位+
worldInfo)，MSG_DAMAGE 中继、MSG_PLAYERDMG 伤害回传。

## 5. 关键坑清单（编号与实验文档对应）

1. **mxmlc**：函数内所有 return 都在 try/catch 里 → 误报"无返回值"，
   需尾随兜底 return；表达式上下文别用全限定名（`flash.utils.X`），先 import。
2. **#2023/死代码消除**：入口类不能当文档类；RConnectDoc 空 Sprite +
   强引用 MOD_CLASS。
3. **UTF-8 帧长度**：长度前缀必须用 UTF-8 字节数（ByteArray.writeUTFBytes
   后 .length），不是 String.length（俄文房间名曾导致流错位）。
4. **isMeet 要求 !disabled**：disabled=true 的单位永远不被索敌
   （shared-knowledge/entities/facts/findcel-targeting.md）。
5. **UnitPonPon 构造自带 invulner=true**；战斗化身须显式关闭
   doop/unres/invulner/disabled（disabled=false 才能被打）。
6. **冻结会被游戏解除**：setNull 流程与 command("activate") 都会
   disabled=false 且 setNull 重置 hp=maxhp（UnitNPC 实测自我解冻、
   hp 漂移）→ 冻结必须每轮同步重写；伤害上报只限 fraction 1..99
   （shared-knowledge/entities/facts/frozen-units-unfreeze.md）。
7. **幻影伤害**：客户端世界被替换（读档/换图）后旧 hp 基线误报伤害
   （实测 152 条）→ 按 loc 对象引用变化重置基线。
8. **旅行挂死**：加载中（curLandId 未就绪）或目标=当前土地时
   beginMission/gotoLand 会挂死游戏（rbl 实测）→ travelToLand 有防护；
   同地图 gotoXY 跳任意房间也挂死（M5 教训，autoTravel 已移除）。
9. **读档前置**：gui/sats 只在 newGame 创建，直接 loadGame 会 #1009 →
   先 newGame 骨架再走原版 comLoad 通道读档
   （shared-knowledge/world-objects/facts/save-load-api.md）。
10. **中继伤害不能钳制**：客户端 gg.damage 有护甲减伤，中继"剩余血量"
    会收敛永不致死；中继原始命中量（hp 可为负不是探测失败）。
11. **dopusk 旅行门控**：身体部件（headHP/torsHP/legsHP/bloodHP）任一
    ≤1 时 gotoLand 只弹 nocont 不执行——死亡回城后需治疗才能再旅行。
12. **AIR 测试实例**：单实例转发需唯一 app id（pfe2/pfe3）；日志在
    `%APPDATA%\<id>\Local Store\RConnect.log`；trace 不进 stdout。
13. **版本探测**：mod 域读 loaderInfo.url 返回自身 URL——用
    `World.boxDamage` 指纹（0.2=1.02）+ 实例 constructor。
14. **触发器类 UnitTrigger**（trigplate 等）曾致宿主崩溃——测试钩子
    一律跳过（isTrigger 过滤）。

## 6. 安全约束与授权记录（必须遵守）

- **权限模型**见 AGENT_SCOPE.md（只写 mods/Rconnect；绝不写其他 mods
  （Sandevistan/RealisticVision/MoreSkills&Weapons）；游戏文件默认只读）。
- **已获授权**：补丁三份游戏 SWF（加载器注入，2026-08-15）；未授权任何
  游戏本体内容的修改（如随机种子替换 Math.random）——新方案涉及改游戏
  文件必须先向用户确认并检查其他开发者改动（见下）。
- **改游戏文件前必查**：对比 `build/backup/current-merged-20260815/` 哈希。
  2026-08-17 交接时核验：三份游戏 SWF 均 UNCHANGED（无他人新改动）。
- **绝不触碰用户真实存档**（%APPDATA%\pfe\...）；测试通过复制到临时
  app-id 存储（pfe2/pfe3）+ 全新 app id。
- **不干扰用户自己运行的游戏实例**：识别方式 = 命令行含
  `application.xml -nodebug`（测试实例用 `app_rconnect_test_*.xml`）。
  交接时已确认无测试实例残留。
- 跨模组 bug 只报告不修复；shared-knowledge 贡献仅限"删除本模组后仍成立"
  的知识。

## 7. 测试手册（真机双实例自动化）

```bash
cd "C:\Program Files (x86)\Steam\steamapps\common\Remains\mods\Rconnect"

# 编译
python tools/build_mod.py

# 双实例测试（host=pfe2 / join=pfe3，临时描述符，自动开新游戏）
M2_LAND=random_mane python tools/run_m2_dualtest.py run     # 默认 M10 场景
python tools/run_m2_dualtest.py cleanup                     # 收尾必跑

# 场景矩阵（环境变量）
M2_LAND=<landId>         宿主 autoTravelLand 目标（空=留在出生地）
M2_SAVE=N / M2_JOIN_SAVE=N   宿主/加入方存档模板槽位
M2_TESTGHOSTDMG=0|2000   宿主伤害驱动（0=纯自然拉仇恨；2000=死亡循环）
M2_JOIN_QUIET=1          join 只跟随+镜像（无 autoMove/autoDamage）
M2_JOIN_LOADSAVE=1       join 加载自己存档（autoLoadSave=0，不 newGame）
```

日志：`%APPDATA%\pfe2\Local Store\RConnect.log`（host）、`pfe3\...`（join）；
AIR stdout 在 `build/m2_host.log` / `m2_join.log`（含游戏侧时间度量与
showError 痕迹）。验证关键词：`relayed/took`（伤害双向）、
`applied/reported`（客户端命中闭环）、`injected/removed/matched N/N`
（世界镜像）、`died/revived`（死亡协调）、`RConnectDbg: tick`（心跳=未挂死）。

已跑通的历史场景：random_mane（马哈顿，敌人最丰富）、stable_pi、
raiders、rbl（基地）；rbl 作为 autoTravelLand 目标会触发防护跳过。

## 8. 其他开发者协作状态（2026-08-15 起无变化）

- 根 pfe.swf 含 4 个模组加载器；DLC/pfe.swf、DLC/pfeUI.swf 只有
  Sandevistan+RConnect（新模组如需支持 DLC 版本按同模式合并）。
- 其他开发者贡献的公共知识：mod-loader-patch-structure（LoaderContext(false)
  未传域=同域加载修正）、grafon-drawallobjs 冲突（待运行时验证）、
  bullet-wall-impact、world-rooms-field-injection（RandomRooms：运行时
  注入房间池，对 M8 遗留的随机地图同步有参考价值）等。
- 本模组贡献的 shared-knowledge（截至 2026-08-18，12 则）：
  - 早期：menu-worldstep-gating、findcel-targeting、player-vis-anim-pipeline、
    world-identity-determinism、land-travel-api；
  - M10/M8：frozen-units-unfreeze、save-load-api、
    programmatic-gameplay-driving（methods）；
  - 2026-08-18 经验沉淀：player-death-respawn-flow、spectator-avatar-unit、
    mod-loader-cross-domain-anomaly、trigger-damage-crash、version-fingerprint；
    land-travel-api 补充挂死点清单（加载中旅行/重入当前土地）。
- Sandevistan 同步可能覆盖补丁：重跑 `tools/patch_game_swfs.py` 恢复；
  锚点缺失会明确报错需人工适配。

## 9. 下一步候选（用户未指定时，建议先做 1 或 2）

1. **真人体验测试**：用户确认有条件后，双开/邀请朋友按 README 手动联机，
   反馈观感问题（幽灵标签/透明度、换房跟随手感）——当前无真人测试条件。
2. **门/箱（Obj）同步 + 随机地图种子**：两者都要改游戏本体（瓦片层 /
   Land.as 的 Math.random）——**需用户授权 + 与其他开发者补丁合并**。
3. **NAT 穿透 / 公共中转服务器**（远期）：MVP 是直连 IP+端口（需端口转发）。
4. 未决小项：M3 遗留（动画阈值观感校准）；玩家攻击中立 NPC 的权威处理；
   rbl 房间为基地（无敌人）时联机体验验证；发布版本号/打包流程。

## 10. Git 状态（2026-08-17 建立）

- 仓库：`mods/Rconnect/.git`（仅本模组文件夹，不含游戏文件与其他 mods）。
- 已跟踪：src/ tools/ state/ knowledge/ decisions/ design/ 及全部文档。
- **不入库**（.gitignore）：`build/`（备份/分析/测试日志/安装包，均可再生成）、
  `release/*.swf`（编译产物，改源码后跑 `python tools/build_mod.py` 重建）。
- 每次工作结束建议 `git add -A && git commit`（提交信息用中文简述本段改动，
  如"M11：xxx"）；身份沿用全局（eclipse / helloimyyt@163.com）。
- `tools/second_player.bat` 为 GBK 编码且 CRLF——git 不做换行转换
  （该文件已按原样入库，勿用工具改写行尾）。
- 注意：build/backup/ 里的合并基线不在 git 内，改游戏文件前的哈希比对
  依赖磁盘上的 build/backup/current-merged-20260815/。

## 11. 新会话自检清单（开工前 30 秒）

- [ ] 读 AGENT_SCOPE.md 权限规则
- [ ] state/current-status.md 为最新（§3 摘要无出入）
- [ ] `python tools/build_mod.py` 编译通过
- [ ] 无测试实例残留（`python tools/run_m2_dualtest.py cleanup`）
- [ ] 改游戏文件前：三份 SWF 与 build/backup/current-merged-20260815/ 哈希比对
- [ ] 用户真实游戏实例（application.xml -nodebug）不受干扰
