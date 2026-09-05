# RConnect 自动化测试技能文档

> 主题：**从"启动游戏"到"进入实战"的全自动测试流程**——写给想学习这套
> 技能的模组开发者。以 RConnect 的真实工作为例，包含环境、API 驱动、
> 可测试性设计、验证方法论与全部踩过的坑。
>
> 适用：本模组工具链（`mods/Rconnect/tools/`）+ 游戏本体 1.02（AIR 30）。
> 最后更新：2026-08-17。

---

## 0. 这套技能解决什么问题

本游戏（Remains）是 AIR SWF，**没有内置测试框架**，也没有"专用测试桩"。
想在改动后验证"能进游戏、能打怪、联机正常"，手动点 10 分钟成本太高、
容易漏。这套流程把"测试员"变成**一堆可重复执行的脚本 + 日志关键词**：

1. **程序化驱动**：用游戏公开 API 模拟"玩家开新档/读档/传送到有敌人的
   地图"——游戏以为自己被正常游玩；
2. **可测试性设计**：模组内埋"配置驱动的测试钩子"（默认关，不影响真玩）；
3. **日志即断言**：把每个里程碑要验证的现象变成日志行（伤害闭环/镜像
   匹配/动画在动/心跳未挂死），脚本跑完 grep 关键词即可断言；
4. **真机双实例**：两个独立游戏窗口（不同 app id）同一台机器互联，验证
   联机逻辑，**全程不碰用户真实存档、不干扰用户正在开的游戏**。

---

## 1. 环境与隔离（第一课：先学会"安全地开第二个游戏"）

### 1.1 工具链

| 工具 | 作用 |
|---|---|
| ffdec-cli（JPEXS） | 反编译/重编译游戏 SWF（改 MainFE 做加载器补丁，见 `patch_game_swfs.py`） |
| Flex SDK + AIR 30 runtime（adl64.exe） | amxmlc 编译模组 SWF；adl64 启动测试实例 |
| Python 3 | 编排脚本（启动/等待/日志/清理） |

### 1.2 AIR 的"单实例转发"陷阱

一个 app id 同一时刻只能有一个实例（后者的事件会被转发给前者并退出）。
**测试实例必须用全新唯一 app id**（RConnect 用 `pfe2`=host、`pfe3`=join），
配临时描述符：

```xml
<application ...>
  <id>pfe2</id>
  <content>pfe.swf</content>
  ...
</application>
```

启动：`adl64.exe -runtime runtimes\air\win64 app_rconnect_test_pfe2.xml`。

### 1.3 存档与存储隔离（红线）

- **绝不写用户真实存档**（`%APPDATA%\pfe\...`——那是应用 id `pfe` 的存储）。
- 测试实例用自己的存储：`%APPDATA%\<appid>\Local Store\`。
- 需要"同进度/不同进度"对照？把用户存档**复制**一份当模板放到测试存储，
  框架允许按槽位选择（`M2_SAVE` / `M2_JOIN_SAVE`）。
- 模组配置也写各自存储：`<appid> Local Store\Rconnect_config.txt`。

### 1.4 日志通道（trace 不可靠）

Windows 上 ADL 的 `trace()` **不进 stdout**——模组必须记录到文件，
且**应用目录可能只读**（Program Files 下）,因此：

```
%APPDATA%\<appid>\Local Store\RConnect.log
```

（写应用目录失败时回退到 storage——见 `rconnect/core/Log.as`。）

### 1.5 与"用户正在玩"互不干扰

用户真机启动命令含 `application.xml -nodebug`；测试实例用
`app_rconnect_test_<id>.xml`。清理/杀进程时**只按命令行特征匹配测试
实例**，绝不动用户实例。

---

## 2. 核心：程序化驱动游戏"进实战"（API 速查）

所有驱动都在**进游戏后**（`fe.World.w` public static 可得）。

### 2.1 关主菜单（第 0 步）

- `World.step` 被 `World.mm.active`（主菜单）门控——菜单开着游戏主循环不跑。
- **`mm["active"] = false`**（等价程序化关菜单）→ 世界开始正常 step。

### 2.2 开新游戏 / 读档（两种进游戏路径）

```text
开新档：World.newGame(0,"LP",null)  → 内部 ng_wait 两段流程（newGame1→2）
读档：  World.comLoad = 槽位号       → 内部 comLoad 两帧流程（↓ 下一帧 loadGame）
```

关键坑（已写成公共知识，见 shared-knowledge `save-load-api` & `world-objects`）：

- **读档前置依赖**：`gui`/`sats` 只在 `newGame()` 里创建。**从未建过世界
  直接读档会 `#1009`**（`this.sats.gg` 空引用，弹错误对话框冻结游戏）。
  → 先 `newGame` 让骨架建好、`gg` 出现，再走 `comLoad` 读档。
- 错误诊断入口：`World.verror.txt.text`（TextField）可读到 showError 的
  `message + stackTrace`——模组把它写进自己日志（RConnect `dumpGameError()`）。

### 2.3 跨图传送（进入"有敌人的地图"）

```text
Game.beginMission(landId)  → 内部设定后调 gotoLand
Game.gotoLand(landId)      → curLandId=id; World.exitLand()（完整退出流程）
```

- **禁止直接** `curLandId=x; game.enterToCurLand()`（跳过退出序列→挂死）；
- **禁止** `Land.gotoXY(x,y)` 跳任意房间（M5 实测整个挂死）；
- **旅行门控** `Pers.dopusk()`：身体部件（headHP/torsHP/legsHP/bloodHP）
  任一 ≤1 时 gotoLand 只弹提示**不执行**——死亡回城后要先治疗
  （测试用 `Pers.healAll()`）；
- **就绪防护**：世界仍在加载（`curLandId` 为空）或目标=当前土地时旅行
  会挂死（rbl 实测，主线程卡死连心跳都停）——`travelToLand()` 见
  GameBridge：返回 Boolean，可重试。

### 2.4 实战目标（选图）

| 地图 | 特点 | 用途 |
|---|---|---|
| `random_mane`（马哈顿废墟） | 敌人最丰富（raider/zombie/bloat/turret/alicorn/tarakan…） | 首选战斗/联机验证 |
| `stable_pi` | 确定性内容、NPC 多 | 中立单位/确定性对照 |
| `raiders` | loc2_1 开局无敌对单位 | 特定场景 |
| `rbl` | 基地、无敌人 | 出生地/跟随起点 |

（随机地图内容按 Math.random 生成，双实例可能不一致——联机验证注意。）

### 2.5 拉怪/打怪钩子（进入"实战"的决定性一步）

自动化要"真的打起来"：

- **移动到最近敌人旁**：扫 `loc.units`，找 fraction ∈[1,99]、
  sost<3 的最近单位，`gg.setPos(x-150,y)` 站到旁边（触发敌人发现/反击）；
- **打最近敌人**：对目标 `unit.damage(60,0,null,false)`；
- 过滤器必须：`fraction 1..99`、跳过 `id` 以 `rconnect_ghost` 开头的单位、
  **跳过 `UnitTrigger` 类**（攻击触发器 trigcans 曾崩宿主）。

### 2.6 死亡/复活（联机闭环的一部分）

玩家死亡走**游戏原版流程**（无需干预）：
`t_die=300 → 150 回城(enterToCurLand) → 100 resurect() → 1 controlOn`。
测试需要"死了能重新加入战斗"→ 复活后 `pers.healAll()` + 回满血
（身体部件伤重会挡旅行）。

---

## 3. 可测试性设计（模组侧的第二门课）

写钩子时遵循的规范（RConnect 的 `auto*` 配置键）：

1. **配置驱动，默认关**：`Config.DEFAULTS` 里每项都给安全默认；
2. **命名约定**：`autoRole/autoGame/autoMove/autoDamage/autoFollow/
   autoHeal/autoLoadSave/autoTravelLand/testGhostDmg/autoGhostDmg`；
3. **幂等 + 可重试**：例如"进游戏"钩子看 `gg==null` 才动作；"传送"钩子
   返回 Boolean、失败下个周期重试；
4. **不影响正常游玩路径**：测试钩子只走公开 API，与游戏逻辑解耦；
5. **日志埋点**：每个可验证现象一行日志，且**一次性日志去重**（每单位
   只打印首次，避免刷屏）。
6. **环境变量透传**（脚本层）：`M2_LAND/M2_SAVE/M2_JOIN_SAVE/
   M2_TESTGHOSTDMG/M2_JOIN_QUIET/M2_JOIN_LOADSAVE` 让同一脚本覆盖多场景。

---

## 4. 双实例联机测试编排（run_m2_dualtest.py）

### 4.1 时序

```text
1. kill 旧测试实例；清空日志；
2. 写 pfe2(host) / pfe3(join) 的配置与临时描述符（含存档模板复制）；
3. 启动 host，睡 45s（游戏加载 + autoGame 进图 + autoTravelLand 传送）；
4. 启动 join，睡 120s（连接 + autoFollow 进图 + 战斗/死亡闭环跑几轮）；
5. 打印两份 RConnect.log；finally 终止进程。
cleanup 子命令：杀测试实例 + 删临时描述符。
```

### 4.2 场景矩阵

| 环境变量 | host 效果 | join 效果 |
|---|---|---|
| `M2_LAND=<landId>` | autoTravelLand 传送到该图 | （跟随） |
| `M2_SAVE=N` / `M2_JOIN_SAVE=N` | 存档模板槽位 | 同左 |
| `M2_TESTGHOSTDMG=0\|N` | 0=纯自然拉仇恨；大值=确定性击杀/死亡循环 | （受击） |
| `M2_JOIN_QUIET=1` | — | 只跟随+镜像（无移动/伤害干扰） |
| `M2_JOIN_LOADSAVE=1` | — | 加载自己存档（不同进度→世界差异） |
| `M2_PORT=<port>` | 换监听端口（默认 23456，被同机其他宿主实例占用时必换） | 同左 |
| `M2_DOORTOGGLE=1` | 宿主 80s 开门 / 120s 关门（inter.command 真实路径） | （跟随镜像） |
| `M2_BOXLOOT=1` | 宿主 80s 搜刮第一个容器（setAct("loot",2)） | （跟随镜像） |
| `M2_LOOTTEST=1` | 宿主 50-60s 生成 Loot、80s 推走、120s 捡起 | （生成/移动/移除镜像+拾取上报） |
| `M2_LOOTJOIN=1` | — | joiner 70s 强制拾取本地 Loot（验证拾取上报→宿主移除） |

### 4.3 手动双开（无脚本时给玩家/自己的速测）

`tools/second_player.bat`（GBK 编码！）——自动建 pfe2 描述符 + 写手动
配置 + 启动第二窗口。第一窗口 Host、第二窗口 Join（IP 127.0.0.1）。

---

## 5. 验证方法论（第三门课：怎么证明"真的没问题"）

### 5.1 日志关键词闭环（断言表）

| 要验证的 | host 日志 | join 日志 |
|---|---|---|
| 客户端命中→宿主权威 | `applied N client damage hits` | `reported N damage hits` |
| 敌人打客户端（影响回传） | `relayed X damage to '...'` | `took X damage from host world` |
| 世界镜像 | `injected/removed ...` | `unitsync matched N/N` |
| 门开关同步（M22） | `doorIcTest open/close 'id' tilePhis=N` | `ist apply open=1/0 'id' tilePhis=N` |
| 容器搜刮同步（M22） | `boxLootTest looted 'id'` | `ist apply loot=2 'id'` |
| 门被摧毁同步（M22） | （boxKill 覆盖门类） | `door destroyed synced 'id'` |
| Loot 生成/移动镜像（M24） | `loots tx first ... k=L#1`、`lootTest pushed` | `loot spawn 'L#1'`、`loot move 'L#1' -> x,y` |
| Loot 拾取上报（M24） | `loot pick applied 'L#1'` | `loot report picked=1`、`loot removed 'L#1'` |
| 死亡/复活闭环 | `ghost passive/combat restored/respawned` | `died/revived`, `healTest` |
| 游戏没挂 | `RConnectDbg: tick N`（10s 心跳持续） | 同左 |
| 错误对话框 | `game error dialog: ...`（dumpGameError） | 同左 |

### 5.2 像素级动画验证（可选进阶）

冻结的 blit 单位（视觉走显示位图管线）"动画在动"用**显示树采样**：
取 `vis` 的子 Bitmap.bitmapData 若干像素求和，两次采样不同 = 帧在渲染
（M6 用该方法验证了傀儡动画 LIVE）。

### 5.3 世界替换/基线的坑（防"假阳性"）

- 客户端世界被替换（读档/换图）后，旧血量基线对新世界单位会**误报幻影
  伤害**（实测 152 条、宿主被打几百点）——按 `loc` 对象引用变化重置基线；
- **冻结会被游戏解除**（UnitNPC 的 setNull/command("activate") 会翻回
  disabled=false 且 setNull 重置 hp=maxhp）——冻结必须每轮同步重写；
  伤害上报只限 fraction 1..99。

---

## 6. 完整坑清单（照方抓药）

1. **mxmlc**：函数内所有 return 在 try/catch 里 → 误报"无返回值"，需
   尾随兜底 return；表达式上下文别用全限定名（先 import）。
2. **#2023 / 死代码消除**：入口类不能当文档类；空 Sprite 文档类 +
   强引用主类。
3. **AIR 单实例转发**：测试实例必须唯一 app id。
4. **trace 不进 stdout**：写文件日志 + storage 回退。
5. **UTF-8 帧长度**：长度前缀用字节数（writeUTFBytes().length），不是
   String.length（俄文房间名曾流错位）。
6. **挂死操作清单**：直接 enterToCurLand、gotoXY 跳任意房、加载中旅行、
   旅行到当前土地。
7. **读档 #1009**：先 newGame 骨架再 comLoad。
8. **dopusk 旅行门控**：身体部件伤重禁止旅行，死亡复位后要治疗。
9. **幻影伤害**：世界替换后重置基线；上报只限敌人 fraction。
10. **UnitTrigger 攻击崩溃**：测试钩子过滤触发器类。
11. **`disabled` 会被解冻**：每轮重写。
12. **批处理编码**：中文 .bat 必须 GBK（cmd 按系统码页解析,UTF-8 会乱码
    断句）；路径层级易错（tools\ 上三级才到游戏根目录）。
13. **清理纪律**：跑完 `cleanup`（杀测试实例 + 删临时描述符）；识别
    用户实例（`application.xml -nodebug`）绝不动。

---

## 7. 照做清单（给想复制这套技能的最小步骤）

```text
1. 准备：ffdec/amxmlc/AIR runtime/Python；确认能编译出你自己的 mod SWF。
2. 隔离：给测试实例新 app id（如 <mod>2/<mod>3）+ 临时描述符 + 独立存储。
3. 驱动：mm.active=false；newGame 或 comLoad 读档；beginMission 传送到
   马哈顿；moveTest 站到最近敌人旁;damageTest 打它。
4. 可测性：在 mod 里加 auto* 配置钩子（默认关、幂等、带日志）。
5. 验证：grep 心跳（没挂）+ 伤害闭环/镜像/动画等关键词（每里程碑埋点）。
6. 清理：脚本 finally 杀实例；cleanup 删描述符。
```

---

## 8. 相关位置

- 编排脚本：`tools/run_m2_dualtest.py`、`tools/second_player.bat`
- 钩子实现：`src/rconnect/core/Session.as`（onTick 周期驱动）、
  `src/rconnect/game/GameBridge.as`（驱动 API 封装：startGame/
  tickAutoGame/loadSaveTest/travelToLand/moveTest/damageTest/healTest/
  ghostDamageTest）
- 公共知识（模组无关，可引用）：shared-knowledge 的 `save-load-api.md`、
  `land-travel-api.md`、`menu-worldstep-gating.md`、`frozen-units-unfreeze.md`、
  `knowledge-validation/methods/programmatic-gameplay-driving.md`
- 完整实验记录：`knowledge/experiments/20xx-xx-xx-m*.md`
