# 加入侧 fake Unit 字段消费者审计（供字段裁剪决策）

> 对象：B3-0.1-smooth1 准确源 `build/ab/b190-visual-motion-smooth04-source/src`；原生参考 `game-reference/decompiled/1.02/src102`。
> 方式：只读 grep/read；未编译、未启动游戏、未改 `.as`/release/A。唯一写入本文件。
> 背景：诊断显示 `FrameDelta.decode` 长帧 41–49 ms；每个 fake unit 的 `fields` 记录约 200+ 键，clone 整份 fields 是主要嫌疑（`FrameDelta.as:20-49`）。**本审计只列消费者与候选，不修改字段，不把“未找到读取”当成“一定可删”。**

## 0. 一句话结论

- 加入侧对 fake Unit 的**直接消费者很少**：显示/插值只读 `NativeFields.MOTION` 的 10 个字段 + `setVisPos/setPos/addVisual/visDetails/setHpbarPos/remVisual/AuthorityAnimation.apply` 等少数原生方法；B 自身通过 `hover`/`applyUnit`/`applyPlayer` 只读一小撮字段（见 §2）。
- **但 fake Unit 位于 `world.loc.units`，会被已加载的 MSW / FA / Sandevistan（以及 RV 开启时）的本地代码扫描**（证据 §3）。这些字段不能仅凭“B 不读”裁掉。
- 最稳的首轮裁剪只针对**非玩家 scene unit 类**，并只裁“宿主 AI/物理/音效/脚本用的、B 与已查模组都不读的”字段。建议第一阶段 40 个（§5 S1）；第二阶段按组追加，S1+S2 总量最多控制在 80 个（需插桩验证）。
- 不能删的硬底线：位置/包围盒/可见性、`hp/maxhp/shithp/armor*`（血条/伤害/SATS/MSW）、`sost/disabled/trig/trigDis/invis/isVis`、`fraction/npc/noAgro`（MSW/FA/Sandy 识别）、`id`（构造 cid）、`code`（FA 键）、`animState`（至少玩家）、`t_throw/damWall/postDie/levit`（MSW/Sandy 读）。

---

## 1. 加入侧对 fake Unit 调用了哪些原生方法，这些方法读哪些字段

fake Unit 是原生 Unit 子类实例（敌人由 host 的 `s.cls` 定义创建；玩家是本地 `world.gg` 或 `access.createPlayer` 的 `AuthorityPlayer`）。加入侧不 step 这些 Unit（`World.step` 在 `onPause` 时跳过 `land.step`：`fe/World.as:1256-1270`；B 在 join 设 `onPause=true`：`RConnectMod.as:147`、`ClientReplica.as:56`）。因此字段消费者 = B 主动调用的原生方法 + 这些方法调用的方法 + 其他模组的本地扫描。

### 1.1 场景单位（非玩家）每确认帧/首帧

| 原生调用（B 调用点） | 原生方法体读取的 Unit/Obj/Pt 字段 | 原生 file:line | 频率 |
|---|---|---|---|
| `u.putLoc(room,X,Y)`（`ReplicaScene.as:199`） | 构造期初始化，理论读大量字段；**但 B 在 putLoc 之后才 `NativeFields.apply`**，故它只看到构造默认值，不约束裁剪 | `Unit.as:1515-1696`（putLoc；内部读 `loc.mirror`、坐标等） | 每个新单位一次 |
| `u.setVisPos()`（`ReplicaScene.as:211`） | `X,Y,storona`；`vis`（对象） | `Unit.as:2969-2977`；炮塔 override 仅 `X,Y`：`UnitTurret.as:288-292` | 每个 unit 每确认帧 |
| `u.addVisual()`（`ReplicaScene.as:217`；仅 `u.hpbar==null`/`s.healthBar==null`/`u.boss` 时） | `disabled,trig`（`checkTrig`）、`player,hpbar,hero,invis,loc.active,sloy,vis,childObjs`；成功创建 hpbar 后调 `visDetails()` | `Unit.as:2870-2914`；`checkTrig`：`Unit.as:1499-1513`；`Pt.addVisual`：`Pt.as:36-42` | 首帧/条件触发 |
| `u.visDetails()`（`ReplicaScene.as:217`） | `hp,maxhp,armor_qual,armor_hp,armor_maxhp,hero,invis,boss`；boss 时调 GUI | `Unit.as:2979-3019` | 首帧/条件触发 |
| `u.setHpbarPos()`（`ReplicaScene.as:217`；插值缺 healthBar 时 `:173`） | `boss,stayY,Y,X`；`loc.zoom`；boss 时 `cam.screenX` | `Unit.as:3021-3041` | 首帧/条件触发 |
| `u.remVisual()`（`ReplicaScene.as:211/220/311` 等） | `hpbar,childObjs`；父 `Pt.remVisual` 读 `vis.parent` | `Unit.as:2916-2934`；`Pt.as:44-50` | 移出/换 clip |
| `AuthorityAnimation.apply(u,s.blit)`（`ReplicaScene.as:212`）→ `unit.blit(id,frame)` | `blit` 读 `blitX,blitY,blitData,blitRect,blitPoint,visData` —— **全是内部/BitmapData 对象，不在 fields 里**；apply 写 `animState/animState2`；blank 时读 `visData` | `fe/unit/AuthorityAnimation.as:15-20`；`Unit.as:2863-2868` | 每个 unit 每确认帧 |
| `HealthBarPose.apply(u.hpbar,s.healthBar)`（`ReplicaScene.as:301`） | 只操作 hpbar DisplayObject，**不读 Unit 标量字段** | `HealthBarPose.as:101-105`；`VisualPose.as:202-324` | 每个有血条 unit 每确认帧/插值帧 |
| `VisualPose.apply(u.vis,s.pose)`（`ReplicaScene.as:225`） | 只读 `vis` 显示树（x/y/scale/rotation/matrix/color/filters/text/children），**不读 Unit 字段** | `VisualPose.as:202-324` | 每个 unit 每确认帧 |
| RConnect 自己的 `attach` | `sost`（`NativeAccess.get(o,"sost",1)`） | `ReplicaScene.as:303-307` | 每个 unit 每确认帧 |
| 原生 SATS（仅 SATS 暂停/重建时） | `isSats,sost,invis,vis,nazv,level,hp,maxhp,skin,armor,armor_qual,marmor,scY,X,Y,dexter,hpbar.visible`；`gg.look` 另读目标 `visibility,stealthMult,demask` | `Sats.as:453-540`、`:323-358`、`:360-392`；`Unit.look`：`Unit.as:4577-4601`；`Unit.isMeet`：`Unit.as:4522-4525`；`Unit.getTileVisi`：`Unit.as:4527-4530` | 仅 SATS UI 重建（`ClientReplica.as:179-186`） |
| 原生 GUI（本地玩家） | `setHp` 读 `hp,maxhp,healhp,rad,drad`；`setMana` 读 `mana,t_culd,currentSpell,teleObj,dmana,h2o,stam,currentArmor,pers`；`setWeapon` 读 `currentWeapon`（对象）；`setPet` 读 `pet,noPet` | `GUI.as:938-972`、`:988-1058`、`:831-886`、`:1088-1116` | 每个确认帧（`ClientReplica.as:174`） |

### 1.2 玩家（本地 `world.gg` 与远端 fake AuthorityPlayer）

| 原生调用（B 调用点） | 读取字段 | 原生 file:line | 频率 |
|---|---|---|---|
| `g.setPos(state.x,state.y)`（`ClientReplica.as:231`） | 写 `X,Y,X1,X2,Y1,Y2`；读 `scX,scY`；调 `setCel`（读 `X,scY`，写 `celX,celY,celDX,celDY,celUnit`） | `Unit.as:1871-1880`、`:4703-4735` | 每 render（确认+插值） |
| `g.setVisPos()`（`ClientReplica.as:234`） | `X,Y,storona` | `Unit.as:2969-2977` | 每 render |
| `g.addVisual()`（`ClientReplica.as:202`，vis 无父时） | UnitPlayer override → `Unit.addVisual`：`disabled,trig,player,hpbar,hero,invis,sloy`；再对 `throwWeapon/magicWeapon` 调 addVisual2 | `UnitPlayer.as:679-690`；`Unit.as:2870-2914` | 首帧/重新挂树 |
| `g.dx/g.dy/g.storona/g.hp/g.maxhp/g.mana = ...` | 直接写（不是读） | `ClientReplica.as:231-234` | 每 render |
| `g.setVisPos`/pose apply | `vis.scaleX/Y`、VisualPose 显示树 | `ClientReplica.as:234-235`、`:260` | 每 render |
| 原生 GUI 4 件套 | 同 §1.1 最后一行（本地 gg） | `GUI.as:938-1116`；`ClientReplica.as:174` | 每确认帧 |

> `UnitPlayer.setNull/addVisual` 只在 `access.createPlayer`（首次创建远端玩家）或 `addVisual` 首次调用，读 `sost,boss,effects,disabled,...` 等构造/重置字段（`UnitPlayer.as:501-679`）。这些字段必须在**首帧**正确；之后可只在变化时同步（§4 Tier2）。  
> `grafon.warShadow()`（`Grafon.as:357-369`）只读 `World.pers.infravis`，**不读 Unit 字段**；`grafon.drawLoc`（`Grafon.as:371-685`）只处理 tile/backobj，**不读 `loc.units` 的 Unit 字段**。

---

## 2. RConnect 自身代码直接读/写的 Unit 字段

| B 位置 | 读/写 | 字段 |
|---|---|---|
| `ReplicaScene.applyUnit`（`ReplicaScene.as:184-241`） | 读 wire 状态 `s.fields.id/tr/X/Y/sloy`；读 fake unit `u.player,u.disabled,u.sost,u.hpbar,u.boss,u.vis,u.childObjs`；通过 `NativeFields.apply` 写全部 `s.fields` | 见字段；`s.fields.id` 只用于选 cid（`:188-197`） |
| `ReplicaScene.attach`（`:303-307`） | 读 `u.sost`（`NativeAccess.get`）；写 `u.vis` 的 parent | `sost` |
| `ReplicaScene.selection/hover`（`:27-53`） | 读 `disabled,sost,isVis,invis,X,X1,X2,Y,Y1,Y2,scX,scY,prior`；写 `onCursor` | 指针/悬停字段 |
| `ReplicaScene.interpolate`（`:168-183`） | 仅 `NativeFields.motion`（MOTION 10 字段）+ hpbar/weapon 显示；不读其他 Unit 字段 | `X,Y,X1,X2,Y1,Y2,eyeX,eyeY,celX,celY` |
| `ClientReplica.applyPlayer`（`ClientReplica.as:190-265`） | 读 `g.vis.parent,g.pet,g.childObjs,g.currentWeapon,g.visSel`（对象字段）；写 `g.dx,g.dy,g.storona,g.hp,g.maxhp,g.mana,g.teleObj,g.actionObj,g.pet,g.childObjs[0/2],g.currentWeapon`；`NativeFields.apply/motion` | 直接写字段：`dx,dy,storona,hp,maxhp,mana`；`motion` 同 MOTION |
| `ClientReplica.applyProjectile`（`:266-296`） | 只读 wire `state.*` + `projectiles/pointers` DisplayObject；**不读 Unit** | — |
| `NativeFields.MOTION`（`NativeFields.as:17`） | 每插值帧读取/写入 | `X,Y,X1,X2,Y1,Y2,eyeX,eyeY,celX,celY` |
| `PoseTween.fields`（`PoseTween.as:69-79`） | 只对 **wire native 对象**做 MOTION 插值，不读 fake Unit | — |
| `HealthBarPose`/`SceneEffects`/`VisualPose` | 显示对象；`SceneEffects` 只对 fake `fe.Obj` loot 指针 `NativeFields.apply`，**不读 Unit** | — |
| `MovementPrediction`（`:33-71`） | 只读 wire `frame.players[1].native`/`motion`；不读 Unit | — |
| `WeaponBridge.resolve`（`WeaponBridge.as:31-38`） | **把 fake scene Unit 对象暴露给 MSW**（`r.scene.units[key].unit`，或扫 `access.world.loc.units`） | 字段由 MSW 决定，见 §3 |
| `RConnectMod.meetReason`（`RConnectMod.as:338-343`） | 读 wire `f.players[0/1].hp`，不读 fake Unit | `hp`（wire） |

结论：B 自身每帧直接读的 Unit 字段只有位置/包围盒/可见性/血条/SATS/指针这一小组；**真正不可裁的集合主要由原生被调方法和外部模组决定**，不是由 B 的 `applyUnit`/`applyPlayer` 行数决定。

---

## 3. 其他已授权模组在 join 侧是否读 fake Unit 字段（只列有证据）

**重要前提**：join 的 fake units 被放进 `room.units`（`ReplicaScene.as:200`），房间最终赋给 `world.loc`（`:91`）；因此已加载模组的本地 ENTER_FRAME 代码（不只 B 桥 API）可能扫描它们。B 桥只是其中一条通道。以下证据来自工作区源码；**安装 SWF 与源码版本不一致时以实际字节为准**。

| 模组 | B join 的桥调用（证据） | 模组本地代码读 fake Unit 的证据 | 结论/字段 |
|---|---|---|---|
| MSW | `access.weapons.input()` 每帧（`RConnectMod.as:163`）；`present(frame.character.msw)` 每确认帧（`ClientReplica.as:175`）；`resolve` 暴露 fake Unit（`WeaponBridge.as:31-38`） | `MSWAuthority.present` 只读 `world.gg.hp`（`MSWAuthority.as:167`）；MSW 本地模块扫 `w.loc.units`：`MSWLaserGeometry.as:9-13`（hp,sost,disabled,trigDis,scX,scY,loc,storona,fraction,npc,noAgro）、`:20`（scX,scY）、`:32`（storona）、`:36-40`（shithp）；`MSWSmartWeapons.as:44-48`（hp,sost,disabled,trigDis,fraction,npc,noAgro）、`:130-131/377`（X1,X2,Y1,Y2）、`:367-380`（isVis,invis,X1..Y2）、`MSWLaserHUD.as:56-57`（isVis,X,Y1）、`MSWPointerSweep.as:14-15`（X1,X2,Y1,Y2）、`MSWBlindController.as:121,167,194-195,228`（radioactiv,onCursor,isVis,X1..Y2,storona,scX,scY,fraction）、`MSWFlashbang.as:181-185`（扫描 units 并施加 blind） | **有证据**：`hp,maxhp`（SATS/GUI 之外）、`sost,disabled,trigDis,scX,scY,storona,shithp,fraction,npc,noAgro,isVis,invis,X1,X2,Y1,Y2,X,Y,code?`、`radioactiv`（blind 控制器，是否 join 执行待核）、`currentWeapon`（对象）、`loc`（对象） |
| FA | `access.addons.present(frame.character.addons)`（`ClientReplica.as:176`）；`input()`（`RConnectMod.as:164`） | B 桥查找 `FAAuthorityAPI`，但当前 FA 源未找到该 API（安装字节/源码版本存疑）。FA 自身 `Runtime.before` 在 `ready()` 时运行（`FirearmAttachments/src/fa/Runtime.as:145-169`），`LootSources.bindFloor/tick` 扫描 `loc.units`：`LootSources.as:44-48` 读 `code,fraction,currentWeapon,sost,X,Y`；`:82-84` 读 `sost,X,Y` | **有证据（本地代码）**：`code,fraction,sost,X,Y`；桥 API 本身未找到证据 |
| Sandevistan | B join 仅 `access.time.present(frame.timeControl)`（`ClientReplica.as:104`）；`SandyAuthority.present` 只 paint state（`SandyAuthority.as:28-32`） | Sandy 自身代码扫 `world.loc.units`：`SandevistanMod.as:1362-1374`（disabled,fraction,sost）；`:1458`（sost,postDie）；`:3006-3015`（t_throw,damWall）；`:3048-3052`（currentWeapon,celX,celY）；`:5998-6003`（sost,disabled,trigDis,loc,fraction,X,Y） | **有证据**：`disabled,fraction,sost,postDie,t_throw,damWall,celX,celY,trigDis,loc,X,Y` |
| PermanentInjury | B join 仅 `access.injury.present(character.injury)`（`ClientReplica.as:177`；`InjuryBridge.as:25`） | PI 源 carrier 只暴露 `{version,dispatch,snapshot,open}`（`PermanentInjury/src/PermanentInjuryMod.as:16-17`），**与 B 的 `attach/beforePlayer/snapshot/present/detach` 契约不一致**；PI 源未扫 `loc.units` | **未找到证据**；桥契约与当前 PI 源不一致，需以安装字节核对 |
| AddictionSystem | B `AddonsBridge.present(state)`（`ClientReplica.as:176`） | `AddictionSystem/src/addiction/Runtime.as:23-30,90` 只操作 `world.gg/pers/invent`，未扫 `loc.units` | **未找到证据**（对 fake Unit 字段） |
| TDFC | B join attach（`TacticsBridge.as:12`），但 `stepRoom` 只允许 host（`TDFC/src/AuthoritySession.as:17-18`）；join 无 `step/bind` 调用 | 源码 `loc.units` 命中集中在 fixtures/probes 与 host `AuthorityRoom`（`TDFC/src/AuthorityRoom.as:13-58`、`AimFixture.as` 等），join 显示路径未找到 | **未找到证据** |
| RV | B join 每 render 调 `view.prepare()`（`ClientReplica.as:101`；`ViewBridge.as:15`）→ `RVAuthorityView.prepare` 只做 `restore()`（`RVAuthorityView.as:21,43-54`，操作 display/mask，不入 Unit 字段） | RV 自身源（`RealisticVisionMod.as:800-803`）读 `Unit.player,npc,fraction`，并维护 `unitVis`（`:396-398`）；RV 关闭时不会加载/attach | **有证据（RV 开启时）**：`player,npc,fraction`（另有大量 vis 显示读取，未逐条列） |
| WallBlend | B 启动代码没有 WallBlend 桥（`RConnectMod.as:176-184` 只挂 rv/fa/addiction/injury/msw/sandy/tdfc） | WallBlend 源只读 `backobjs`（`WallBlend/src/wallblend/BackgroundBlendLayer.as:151`、`SceneBlendCache.as:86`），未见 `loc.units`/Unit 字段 | **未找到证据** |

> 说明：MSW/FA/Sandy/RV 的本地模块是否在 join 真正运行，取决于当前安装版与配置；B 默认环境记录里 RV/CS/LAD 关、MSW/FA/Addiction/Injury/Sandy/TDFC 开（`state/B-MEMORY.md:24-25` 与部署 config）。**上表“有证据”只证明源码可读到这些字段，不等于当前每局都执行到**；裁剪前必须在实际安装组合下计数。

---

## 4. 字段三档清单

> 范围：以 `Unit` 基类 188 个 scalar public var + `Pt`/`Obj` 被 `NativeFields` 捕获的字段为主。`Pt`/`Obj` 的对象字段（loc/vis/inter/cTransform/currentWeapon/teleObj 等）本就不在 wire fields 内，不裁剪。  
> **所有“可省”都只建议用于非玩家 scene unit 类；玩家类（UnitPlayer/AuthorityPlayer）暂不裁**，因为本地原生 GUI/相机/模组自身还会读本地玩家。

### Tier 1 — 每帧必须 / 不能删

**位置、包围盒、可见性、指针**
`X,Y,dx,dy,X1,X2,Y1,Y2,scX,scY,storona,sloy,eyeX,eyeY,celX,celY,prior,onCursor,stayY`

**生命/血条/伤害可见性**
`hp,maxhp,shithp,armor,armor_qual,armor_hp,armor_maxhp,marmor,skin,dexter,hero,boss,invis,isVis,sost,disabled`

**识别/阵营/接口**
`id,code,player,npc,noAgro,fraction,trig,trigDis,isSats,level,nazv`

**SATS/瞄准目标**
`visibility,stealthMult,demask`

**玩家本地 GUI（仅玩家类必须；scene unit 可另裁）**
`healhp,rad,drad,mana,h2o,stam,t_culd,noPet`（`currentSpell/currentArmor/pers/teleObj/pet/currentWeapon` 是对象，不在 fields）

**状态/模组接口**
`t_throw,damWall,postDie,stun,levit,radioactiv`（MSW/Sandy 证据）

**动画**
`animState`（至少玩家；scene unit 的 AuthorityAnimation 会写但它不是 wire 写入的直接消费者；保守保留）

**证据**：§1 表 + §2 表 + §3 表。位置/包围盒：`NativeFields.as:17,119-121`、`Unit.as:1871-1880,2969-2977,4703-4735`、`ReplicaScene.as:44-53`、`MSWLaserGeometry.as:10-20,32`、`MSWSmartWeapons.as:130-131,367-380`、`SandevistanMod.as:5998-6003`。生命/血条：`Unit.as:2985-3012,3021-3041`、`GUI.as:938-1116`、`Sats.as:453-540`、`MSWLaserGeometry.as:36-40`。识别：`Unit.as:2870-2914,4522-4530`、`MSWSmartWeapons.as:44-48`、`FA LootSources.as:44-48`。SATS：`Sats.as:323-358,453-540`、`Unit.as:4577-4601`。

### Tier 2 — 变化时才需要（可移出“每帧完整 fields”，但值变化时必须同步）

- 血条/伤害相关：`hp,maxhp,armor_qual,armor_hp,armor_maxhp,hero,boss,invis`（hpbar 创建/`visDetails` 只在首帧/条件触发；但 hp/maxhp/shithp 又被 MSW/SATS/GUI 每帧读，所以真正可移出的只有 `armor_qual/armor_hp/armor_maxhp,hero,boss` 的“每帧完整复制”，不是删字段）
- 本地 GUI：`healhp,rad,drad,mana,h2o,stam,t_culd`（GUI 可在数值变化时调用）
- 触发/首帧：`trig,trigDis,player,stayY`
- SATS（打开时才有）：`isSats,level,nazv,skin,armor,marmor,dexter,visibility,stealthMult,demask`
- 宠物：`noPet,currentPet`；动画：`animState2`
- 状态/模组（事件驱动）：`t_throw,damWall,postDie,stun,levit`（MSW/Sandy 事件时读；若协议改成事件同步可移出每帧）
- 对象/稀有：`massa,levitPoss,fracLevit`（念力交互/宿主；join 当前只 hover 不读，但为模组接口保守保留）

### Tier 3 — 仅首帧或可省略（候选裁剪）

> 这些字段的**已知消费者全部在 host 侧 AI/物理/战斗/音效/脚本**；join 不 step fake Unit（`World.as:1256-1270` + `RConnectMod.as:147`），B/原生被调方法/已查模组未见读取。**“未见”不等于证明**；按“不确定归保留”原则只选下列较明确项。

#### S1（40 个，建议先试，低风险）

| 字段 | 类别 | 证据（join 消费者未命中） | 风险 |
|---|---|---|---|
| `begX,begY` | 弹丸/出生几何 | B/原生被调方法/MSW/FA/Sandy 均未读；host `Unit` 物理用 | 低（远程弹丸几何由 projectile 记录） |
| `walk` | 移动状态 | MSW `MSWBlindController.as:81` 只写 `u.walk=0`，不读；B 未读 | 低 |
| `maxSpeed,walkSpeed,runSpeed,sitSpeed,lazSpeed,plavSpeed` | 移动速度常量 | host `forces/actions`；join 不 step；B/MSW/FA/Sandy 未读 | 低 |
| `accel,brake,levitaccel,knocked` | 物理参数 | 同上 | 低 |
| `jumpdy,plavdy,levidy,elast,jumpBall,ddyPlav` | 跳跃/漂浮物理 | 同上 | 低 |
| `grav,slow,tormoz` | 重力/减速 | 同上 | 低 |
| `porog,porog_jump` | 物理门限 | 同上 | 低 |
| `stayPhis,stayMat,tykMat` | 站立物理缓存 | 同上 | 低 |
| `levit_max,levit_r,levitAttack` | 念力/漂浮参数 | host `PlayerPointer`/PeerGrabs；join 不读 | 低 |
| `fixed` | 物理固定 | host step；join 不读 | 低 |
| `massaFix,massaMove` | 质量系数 | host 物理；join 不读 | 低 |
| `sitX,sitY` | 坐姿偏移 | host `setLocPos`/物理；join 不读 | 低 |
| `turnX,turnY` | AI 朝向 | host AI；join 不读 | 低 |
| `osndx,osndy` | 声音偏移 | host 声音；join 走 audio 事件 | 低 |
| `rasst` | 宿主距离缓存 | host `listen/sndRun`；join 不读 | 低 |

**S1 共 40 个**。建议只对这些字段在 `NativeFields.capture` 的 schema 中排除（且条件 `!value.player`），先加计数确认 `fields` 键数从 ~200+ 降到 ~160–170。

#### S2（第二阶段候选约 60 个；建议按组推进，使 S1+S2 总量最多 80 个）

| 字段组 | 字段 | 证据 | 风险 |
|---|---|---|---|
| 音效字符串 | `sndMusic,sndDie,sndRun,sndRunDist,sndRunOn` | host `Unit.sound/die`；join 用 `SessionSound` 事件 | 低-中 |
| 名字/脚本/经验 | `id_name,id_replic,t_replic,questId,xp` | host 生成名/气泡/任务；join 气泡作为 effect 捕获 | 中（`id_replic/t_replic` 若被未查模组读取） |
| 武器技能/法术 | `weaponSkill,spellPower,weaponKrep` | host 伤害/UI；SATS `getPrec` 读的是 `gg.pers.weaponSkills`，不是目标 unit | 中 |
| 武器/法术坐标 | `weaponX,weaponY,weaponR,magicX,magicY` | host `setWeaponPos`；join 的 weapon pose 来自独立 weapon 记录 | 中（若原生 vis 依赖，未验证） |
| 伤害/暴击/减免 | `hpmult,critHeal,allVulnerMult,shitArmor,dexterPlus,dodge,undodge,damWallSpeed,dopTestOn,friendlyExpl,dam,tipDamage,radDamage,retDamage,relat,destroy,collisionTip,dieWeap,critCh,critInvis,critDamMult,precMult,precMultCont,rapidMultCont` | host `damage`/AI；join 不造成伤害；MSW/Sandy 未读 | 中（`shithp` 仍保留；`dam` 若 MSW/Sandy 读取未验证） |
| AI 感知 | `detecting,noise,noiseRun,noise_t,observ,vision,ear,vAngle,vKonus,aiTip` | host AI `Unit.actions/look/listen`；join 不 step；`SATS` 只读目标 `visibility/stealthMult/demask`（已保留） | 中（TDFC/PI 未查内部） |
| 其它状态 | `areaTestTip,msex,overLook,plav,showNumbs,activateTrap,t_emerg,max_emerg,wave,transT` | host AI/陷阱/伤害数字控制；join 显示 effect 由 host 捕获 | 中-高（`showNumbs` 可能影响 join 伤害数字生成者？host 端已决定） |
| 表现/死亡标记 | `blood,mat,acidDey,trup,isRes,noDestr,lootIsDrop,doop,plaKap,noBox,mHero,mech` | host die/视觉/掉落；join 不跑 die；`trup` 可能被原生渲染/模组读，**不确定** | 中-高；建议放最后验证 |
| 未归类保守保留 | `massa,levitPoss,fracLevit,unres,radioactiv,radrad,radtip,warn,uid,dist2,stay,onCursor` | 部分有 MSW/Sandy/RV/FA 证据或不确定 | **不裁**（保留） |

> S2 不建议一次全上；按 4 组分别 AB，任何一组出现 MSW/FA/Sandy/RV 相关视觉或行为差异就撤回该组。若要严格把总量控制在 80，建议只先取“音效 + 名字/脚本 + 武器技能/坐标”约 18 个，再加 AI 感知 10 个、伤害组 12 个；其余留待后续。
>
> 未在 Tier1/Tier2/S1/S2 显式列出的 Unit 字段（例如 `stay,uid,dist2,warn,unres,radrad,radtip,massa,levitPoss,fracLevit,radioactiv` 等）一律**默认保留**，不做首次裁剪；玩家类 `UnitPlayer` 的额外字段（如 `noRad,currentPet,...`）本轮不动。

---

## 5. 最小可试裁剪集与必须回归场景

### 5.1 最小试裁集（建议：先只裁 S1 的 40 个）

- 条件：仅 `value.player !== true` 的 scene unit（敌人/炮塔等）；玩家类保持完整 fields。
- 位置：`NativeFields.capture`（`NativeFields.as:18-78`）的 schema 生成处（`:28-45`）加“scene-unit crop 集合”排除；或 `SceneSnapshot.capture` 构造 `us.fields` 时过滤（`SceneSnapshot.as:89`）。**不要改 `NativeFields.MOTION` 的 10 字段**；不要改 `FrameDelta` 协议。
- 预期：每个 unit 的 fields 键数 −40（约 −18–20%），`FrameDelta.decode` 的 clone/AMF3 字段量相应下降；长帧 41–49 ms 应部分缓解（幅度未实测，不要承诺）。
- 不建议首轮：S2 的伤害/感知/死亡标记组；玩家字段；对象字段（loc/vis/inter/currentWeapon，本就不在 wire）。

### 5.2 必须回归的场景

1. **密集敌人 ABAB**：8/80 敌、持续轻机枪 60 s；原 5% 平均/P95、重复 1.2 门槛（`b-smooth-clean` 口径）；同时记录长帧直方图/最大帧。
2. **敌人显示/血条/受击**：`textmotion02`（主111/加124）、`enemies`（原生断言）、`rockets02`（57/57，2030 样本）——重点看 hpbar 显隐/位置/颜色、伤害数字、死亡/尸体。
3. **位置与插值**：`movement/motion/controls`（预测、镜头回摆、1–2 px）；确认 10 个 MOTION 字段未变。
4. **可见性/隐身/SATS**：暗处隐身敌人、SATS 暂停重建（`ClientReplica.as:179-186`）、`sats`/`visualfield`；确认 `visibility/stealthMult/demask/isSats/invis/isVis` 未被裁。
5. **模组接口（按当前安装组合）**：
   - MSW：激光/指针/智能锁定/闪光（读 X1..Y2,hp,sost,fraction,shihp,noAgro,npc 等）；
   - FA：floor 绑定/敌人掉落源扫描（读 code,fraction,sost,X,Y）；
   - Sandevistan：时停/回放（读 t_throw,damWall,postDie,celX/celY）；
   - RV（若开启）：玩家/敌人显示状态（player,npc,fraction）；
   - PI/Addiction/TDFC：按现有功能冒烟；当前源未见 fake Unit 字段读，但桥契约需实机核对。
6. **换房/加载/存档**：room full 帧、`drawLoc` 破坏帧、Join leave/save 路径；确认裁剪不影响 room 构造（`id/tr/X/Y` 仍在）。
7. **玩家本地**：GUI `setHp/setMana/setWeapon/setPet`、死亡/复活、Pip/Stand、SATS 面板；玩家字段未裁，作为对照。

### 5.3 验证方式

- 计数器：裁剪后每 unit `fields` 键数、`FrameDelta.decode` 的 change/clone 数、`receiveBatch` 分项（AMF3 vs delta）、长帧 50/100/200 ms 计数。
- 等价：用同一确认包比较裁剪前后 join 显示树（pose/HP 条/位置）与原生断言；不只看 FPS。
- 如出现 MSW/FA/Sandy/RV 差异，优先恢复 S2 对应组，再定位到字段；不要用“平均帧率未退化”掩盖功能差异。

---

## 6. 未验证/限制

- 未运行游戏；S1/S2 的“未找到读取”是工作区源码/B 路径的静态证据，不能证明所有安装字节、所有第三方模组与所有原生分支都不读。
- fake Unit 是否会被世界/其他模组 step 的边界：B 设 `World.onPause`，`World.step` 在 `:1256` 跳过 `land.step`；但未逐一验证所有 native ENTER_FRAME 子系统不读这些字段。
- PI/Addiction/FA/TDFC 的工作区源码与 B 桥契约/安装字节可能不一致（PI 明确不一致），需以实际 SWF 或运行计数核对；本报告对它们只写“证据/未找到证据”。
- 血条/抗性/隐身等字段的实际影响依赖当前 hpBar 形态；`HealthBarPose` compact 不命中已是既有记录（`state/B-MEMORY.md:13`、`README.md:33`）。
- 本报告不评估字段裁剪对 host 侧采集/diff 的收益，也未给出精确毫秒收益；裁剪比例 × clone 成本的量化需 probe 计数。
