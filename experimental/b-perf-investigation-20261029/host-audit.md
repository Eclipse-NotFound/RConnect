# RConnect B3-0.1-smooth1 主侧（host）战斗场景每帧/每消息开销审计

- 审计日期：2026-10-29（Asia/Shanghai）
- 审计对象：`mods/RConnect/build/ab/b190-visual-motion-smooth04-source/`（安装版 `B3-0.1-smooth1` 的准确源码；该目录共 144 份 `.as`＝`src/` 129 份＋`stubs/` 15 份，另有 2 份 json；`src/authority/BuildInfo.as:8` 仍是 `__SOURCE_HASH__` 占位，属编译前源）
- 方式：只读 grep/read 产品源码与 `state/B-MEMORY.md`、`state/b-scalar-optimization-2026-10-27.md`、`experimental/b-smooth-20261029/README.md`、`build/ab/b-dense-profile01/result.json`、`experimental/b-field-dense-profile/profile01-analysis.json`，以及 `game-reference/decompiled/1.02/src102` 的原生调用点、`tools/host_authority/patch_native.py` 的原生钩子注入点；未编译、未启动游戏、未做 git 操作、未修改任何 `.as`/`release/`。
- 证据等级（全文统一标注）：
  - **【实测】** 来自 profile01 的插桩样本（旧基线 field22 字节，80 敌人 366 帧；插桩本身有额外计时，不能当净 CPU 或端到端延迟；均值单位 ms/帧或 ms/次）。
  - **【静态】** 由源码控制流/数据流直接确认（含频率与分配）。
  - **【推断】** 未直接计时，按代码量与调用次数估算，**未验证**。

---

## 0. 结论摘要（TL;DR）

1. **主侧一帧＝一个原生世界 tick＝一个渲染帧（标称 30Hz）**：`MainMenu.mainStep`（`game-reference/.../fe/MainMenu.as:804-844`，`World.step` 在 `:842`）由 `Event.ENTER_FRAME`（`:85`）驱动；patched `Land.step` 被 `rconnectRoomStep` 截为 `RoomRuntime.stepLand`（`src/authority/RoomRuntime.as:120`），发布在 `Event.EXIT_FRAME` 的 `presentFrame`（`:174`）里完成。根 `pfe.swf` SWF 头 frameRate 实测 30，原生 `World.fps=30`（`fe/World.as:44`）。**tick 率与帧率强耦合：一帧超 33.3ms 就直接少一个模拟 tick、少一次发布**，加入侧 `PlaybackClock` 会把缓冲从 65ms 抬到上限 250ms（`src/authority/PlaybackClock.as:16-23`），这就是“主侧卡、加入侧更卡”的放大链。
2. **主侧 publish 的大头是“逐单位采集”，不是网络**：profile01 中 80 敌人时 `host.publish` 均值 43.68ms（p50 38），其中 `host.sceneAndPlayers` 33.29ms，`capture.units` 24.40ms（字段 11.56、身体 8.42、血条 1.87、原生动画帧 1.65），`host.delta` 5.70ms，`host.send` 3.55ms（`wire.serialize` 1.49＋`wire.compress` 1.07）。与任务给出的当前版 publish≈32ms、simulate≈16ms 比例一致。【实测】
3. **固定成本里最显眼的是每帧全房间瓦片扫描**：`capture.tiles` 均值 3.77ms/帧（p50 4，max 7），8 敌人时也有 3.63ms/帧——**与敌人数无关、与房间面积成正比**，约占 33.3ms 帧预算的 11%。【实测】
4. **同一 tick 内同一个原生对象链被完整遍历最多 6 次**：`RoomRuntime.capture` 3 次（stepPlayers 内 `:117`、stepLand `:154`、presentFrame `:185`）＋`SceneSnapshot` 特效链 1 次（`SceneSnapshot.as:129`）＋`PlayerPointer` 每名玩家 1 次（`PlayerPointer.as:15`，由 `PlayerActor.as:66` 每步调用）。profile 只给其中 2 次计时（`simulate.projectileCapture` n=732＝2/帧），第 3 次在 presentFrame 内未计时。【静态＋实测频率】
5. **完全没有“多客户端重复构造同一负载”**：B3 主侧只接受一条 `Link`，第二个连接直接 `close`（`RConnectMod.as:207-210`），`HostSession` 只有一个 `link` 字段（`HostSession.as:4`）。但存在“同一负载在主侧内部构造多次”：`RoomRuntime.capture×3`、`projectilesForRoom×2`（`HostSession.as:160-161`）、`TimeBridge.snapshot×2`（`:134`）、`keyFor`（每弹丸/每音效/每房间 summary 拼字符串）、`NativeFields.capture(room)×2`（full 帧，`SceneSnapshot.as:45` 与 `:63`）。
6. **加入侧确实和主侧对称地跑同一份状态机**：主侧 `NativeFields.capture` 11.56ms/帧 ↔ 加入侧 `NativeFields.apply` 5.56ms/次；主侧 `VisualPose.capture` 8.42ms ↔ 加入侧 `VisualPose.apply` 3.07ms；血条 1.87ms ↔ 0.85＋0.64ms；弹丸记录两侧各建一份。可下沉/分工的候选集中在“显示记录紧凑化、状态快照按事件发生、非显示房不做视觉采集”。【实测＋静态】

---

## 1. 主侧一帧与每条消息的调用链（含频率与 file:line）

### 1.1 时钟与驱动源（先澄清任务里问到的 HostSession 与 Timer/ENTER_FRAME 关系）

- `HostSession` **自身没有 Timer、没有 ENTER_FRAME/EXIT_FRAME 监听**（全文件 `src/authority/HostSession.as` 只有 `getTimer()` 用于 `frame.time`，`:132`）；它只把发布请求转成标志：`publish()` → `runtime.requestPresentation()`（`:117-119`）。
- 主侧两个真正节拍源：
  1. `RConnectMod.before` 挂在 `stage.ENTER_FRAME`，priority 100000（`RConnectMod.as:97-98`）→ **每个渲染帧 1 次**（在原生 `World.step` 之前跑，因为 MainMenu 的监听是默认优先级）。
  2. `RoomRuntime.presentFrame` 挂在 `world.swfStage.EXIT_FRAME`，priority -100000（`RoomRuntime.as:50`）→ **每个渲染帧 1 次**，仅当 `presentationPending` 为真才真正发布（`:179`）。
- 世界 tick：`MainMenu.mainStep`（`fe/MainMenu.as:804`）→ `world.step()`（`:842`）→ `World.step`（`fe/World.as:1227`）→ 在 `allStat==1 && !onPause` 时 `this.land.step()`（`:1269`）→ patched `Land.step`（`fe/loc/Land.as:1567`，原生 `this.loc.step()` 在 `:1572`）→ 钩子 `rconnectRoomStep`（注入点 `tools/host_authority/patch_native.py:74-85`）→ **`RoomRuntime.stepLand`**（`RoomRuntime.as:120`）。
- 其它异步源：`Link` 的 `drain` 有 8ms 预算并在剩余完整包时 `setTimeout(drain,1)`（`Link.as:94,110,116`）；`finish()` 用 25ms 轮询等对端 ack（`:64-70`）。`RCLocale` 的 `Timer(200)`（`modlocales/connect/RCLocale.as:85-86`）与主侧战斗无关。**没有其它定时器参与战斗循环。**
- 同步节拍与帧率耦合的具体表现：
  - tick 只随 `ENTER_FRAME` 推进；`RoomRuntime.stepLand` 每 tick 只 `requestPresentation()` 一次（`:165`），`presentFrame` 每帧最多消费一次 `presentationPending`（`:174-179`）。**帧慢 → tick 少 → 发布少且包更大**。
  - 若 `presentFrame` 遇到 `stepping` 或 `access.scope.depth!=0` 会把发布推迟到下一帧（`:178`，`deferredPresentations` 计数），该 tick 的中间状态被跳过。
  - `PlaybackClock.pace` 用主侧 `frame.time` 的到达间隔与抖动估计播放延迟，延迟只增很慢降（65→250ms，`PlaybackClock.as:16-23`），所以主侧一次性 40ms+ 的帧会持续抬高加入侧播放缓冲。

### 1.2 每帧 · ENTER_FRAME 阶段（`RConnectMod.before`，30Hz）

按执行顺序（只列主侧对局路径；probe 分支见 §5）：

| 工作 | 频率 | 位置 |
|---|---|---|
| HUD 刷新（`ui.refresh();hud.refresh()`） | 每 100ms（≥100ms 闸门） | `RConnectMod.as:115` |
| `access.ready()` 等就绪判断、5 帧启动闸门 | 每帧 | `:121,141` |
| `host.menus()`：对 2 名玩家 `takeMenus()`（**每次分配 taken/rest 两个数组**，`Commands.as:64-68`），执行本帧到达的 native 菜单动作；**并无条件** `scope.run(remote.context, gui.step())` | 每帧（每玩家） | `RConnectMod.as:156` → `HostSession.as:96-116`（`takeMenus` `:99`，`gui.step` `:114`） |
| `host.pause.update(host)`：读 `world.pip/stand/gui.guiPause/mm` 与远端暂停位 | 每帧 | `RConnectMod.as:156` → `SharedPause.as:13-30` |
| `applyPreferences()`：读 5 个偏好并 `[...].join(":")` 与 `lastPolicy` 比较（**每帧分配数组＋字符串**） | 每帧 | `RConnectMod.as:157,271-286`（join 在 `:277`） |
| `input.acknowledge(...)`；`input.frame(w,…)`：读 `world.ctr` 13 个 HELD、27 个 ONCE、`world.celX/celY`、`SharedPause.requested(world)`（每帧调 3 次，`InputSource.as:30,32`），构造**新输入对象＋actions 数组**，`flight=flight.concat(a); a=flight.slice(0,16)`（两次数组分配） | 每帧 | `RConnectMod.as:159-161` → `InputSource.as:12-33`（`:29`） |
| `frame.msw/addons`（启用对应模组时）、identity 字段 | 每帧 | `RConnectMod.as:163-168` |
| `host.localInput(frame)`：`inputs[0].accept()` 验证（含 actions≤16 遍历、actions.concat）＋ `personal()` 4 键 | 每帧 | `:170` → `HostSession.as:86-95`；`Commands.as:21-52`（`:49` concat） |
| `vision.step()`：`getTimer()-lastAt<100` 早退；到点则 `remember(room)`、可能发包 | 每 100ms | `RConnectMod.as:172` → `SharedVision.as:28-38` |

### 1.3 每 tick · 模拟阶段（`RoomRuntime.stepLand`，30Hz，1 帧 1 tick）

```
stepLand(land)                                  RoomRuntime.as:120
├─ awaitFirstView 闸门                          :124
├─ access.view.prepare()（仅 RV 桥）            :129
├─ travel.rebind(land)                          :130
├─ ++tick; time.beginTick()（Sandy 时停）       :131-133
├─ replay 分支：requestPresentation(); return    :134-136
├─ rooms.occupied()                             :138 → OccupiedRooms.as:59-76
│    （新数组 + 每 record indexOf；room.prob.over/out 时进 scope）
├─ for each 占用房 (通常 1，分房时 2)：         :139-157
│   access.scope.runRoom(representative,…)      :143 → NativeScope.as:17-66（26 个 FIELDS＋7 个 LAND 字段整份拷贝/恢复，两处 AppearanceState.capture）
│   ├─ music.step(room)                         :145 → SessionMusic.as:39
│   ├─ worldStep && room.step()                 :147 → 原生 Location.step（fe/loc/Location.as:3348）
│   │   ├─ this.gg.step() 被替换为 rconnectPlayerStep → stepPlayers(room)  RoomRuntime.as:104
│   │   │   ├─ for actors（仅 loc===room 的）:
│   │   │   │   inputs[i].consume(getTimer())   :109 → Commands.as:53-61（新建 result 对象/数组）
│   │   │   │   actor.step(command)             :110 → PlayerActor.as:32-84
│   │   │   │     ├─ grips.prepare（抓取/被抓）  :37-38 → PeerGrabs.as:13-28
│   │   │   │     ├─ 写 13 个 HELD、清 27 个 ONCE、执行 actions（含 NativeIntents/SatsActions/equip）:43-55
│   │   │   │     ├─ security.player(actor, stepNative) :69 → SecurityTerminals.as:57-75（每次扫 room.objs+room.acts 建 Dictionary/Array，`inRoom` `:42-49`）
│   │   │   │     └─ sight.withCursorLight → PlayerPointer.run → unit.step() :64-69
│   │   │   │           - PlayerPointer.run：**整条 firstObj 链**＋room.units.concat＋3 个 Dictionary + 每个 onCursor 对象 getQualifiedClassName/NativeAccess.get（`PlayerPointer.as:6-67`，链扫 `:15-18`，类名 `:25`）
│   │   │   ├─ weapons.beforeObjects                 :115
│   │   │   └─ capture(room)  ← 第 1 次对象链/弹丸采集  :117 → :194-210
│   │   ├─ 原生 Location.step 的对象链 while：每个 obj → rconnectObjectStep → stepObject  :52-67
│   │   │   ├─ 子弹判定 5 个 in/属性探测（每个对象）  :54
│   │   │   ├─ 子弹：grips.retireProjectile→projectile()（**每次弹丸每 tick 新建 state 对象**） :55-56
│   │   │   ├─ time.withSource（Sandy）或直接 stepOwnedObject :57-58
│   │   │   │   ├─ security.stepObject（每个对象）    :69 → SecurityTerminals.as:78-101
│   │   │   │   ├─ interactionOwners / WorldClaims.step / WorldClaims.choose :70-77
│   │   │   │   │     └─ choose：对**每个对象** getQualifiedClassName（WorldClaims.as:8）
│   │   │   │   ├─ owner 循环（2 名玩家；own 对象用 scope.runRoom 包原生 step）:79-85
│   │   │   │   ├─ `room.units.indexOf(object)`（对每个非玩家对象线性扫 units）:88
│   │   │   │   ├─ 敌对 AI 选目标：2 名玩家距离（Math.pow）:89-95
│   │   │   │   └─ object.step()（原生）              :97
│   │   │   └─ 子弹：再 projectile() 并写 ended/recent :59-65
│   │   └─ weapons.afterRoom / tactics.step          :150-153
│   └─ capture(room) ← 第 2 次采集                   :154
├─ actors.finishWorldServices()                 :159 → PlayerActor.as:94-105
│    （仅玩家 1：sight.update()→ActorSight.as:10-51（暗房每 tick 全房间瓦片＋原生 lighting）；sats.step2；质量重算）
├─ transfers.commit(); lives.step(); rooms.occupied(); rooms.showHost() :161
│    （showHost 每 tick 写回 world.loc/land/grafon/cam 并 `grafon.warShadow()`，OccupiedRooms.as:94-107）
├─ requestPresentation()                        :165
```

原生侧注入点证据：`patch_native.py:52-64`（`Location.gg.step()`→`rconnectPlayerStep`；对象链两处 `obj.step()`→`rconnectObjectStep`，含 `stepInvis`）、`:65-85`（`Land.step` 的 `this.loc.step()` 整块让位给 `rconnectRoomStep`）、`:34-43`（`Unit.findCel` 前插 `rconnectFindTarget`→`NativePerception.find`）。

**频率要点（本节）**：
- `stepLand`：每帧 1 次。
- `stepPlayers`：每个“占用房”每 tick 1 次（分房 2 次）；内部按玩家。
- `stepObject`：**房间对象链上每个对象每 tick 1 次**（80 僵尸场景实测 `simulate.object.fe.unit::UnitZombie n=29280`＝80/帧；另有 `fe.graph::Part` n=7467≈20/帧、Bullet n=1254）。【实测】
- `RoomRuntime.capture`：每 tick 每房最多 3 次（见 §1.4）。
- `NativePerception.find`：每个敌对单位每次 `findCel` 1 次，内部对**每名玩家**各跑一次 `scope.run(findCel)`（`NativePerception.as:18-43`，`scope.run` 在 `:22`）。
- `ActorSight.update`：玩家 1 每 tick 1 次（暗房才做全房瓦片运算，`ActorSight.as:14,29-47`）。

### 1.4 每 tick · 发布阶段（`presentFrame` → `capturePresentation`，30Hz）

```
presentFrame(event)                                    RoomRuntime.as:174
├─ stepping/scope.depth 非 0 → 推迟（deferredPresentations++） :178
├─ if !presentationPending return                       :179
├─ captureFrame: for each 占用房 capture(room)  ← 第 3 次采集（未计时） :185
├─ afterStep() → HostSession.capturePresentation        :186 / HostSession.as:120
│   ├─ injury.afterWorld(actors) / weapons.present/snapshot / addons :123-125
│   ├─ grips.present(); combat.update()（循环 2 玩家）  :126
│   ├─ runtime.snapshot()：把 latestByRoom（所有房）每个弹丸 push 进数组 + recent 事件数组 :127 → :230-235
│   ├─ frame.type/session/room（`access.keyFor(actors[1].unit.loc)`）:127
│   ├─ frame.control/time/paused/pausePolicies         :131-135
│   ├─ frame.timeControl = time.snapshot(...,1)；time.present(time.snapshot(...,0)) ← **两次 snapshot** :134
│   ├─ frame.map = MapState.capture(land)（遍历 land.locs 三维网格 + listLocs） :136 → MapState.as:9-19
│   ├─ frame.players = [actors[0].snapshot(inputs[0].consumed), actors[1].snapshot(...)] :137 → PlayerActor.as:106-127
│   │    每名玩家：NativeFields.capture(UnitPlayer≈282 字段)、VisualPose.capture(unit.vis)、武器 pose/fields、held、action、personal 深拷贝、房间 key；玩家 1 另做 GroundMotion.capture（满足走路条件时再扫一次 firstObj 链，GroundMotion.as:27-33）
│   ├─ scene.id()/held.key/actionAck 回填               :138-142
│   ├─ frame.audio = sound.snapshot(room,tick,paused)   :145 → SessionSound.as:47-62
│   ├─ frame.scene = scene.capture(actors[1].unit.loc, actors, tick) :146 → SceneSnapshot.as:40-197（见 §2）
│   ├─ frame.character = CharacterState.capture(actors[1]) :148 → CharacterState.as:9-24
│   │    含 `PlainData.copy(g.invent.save())`（**两层深拷贝**）、maps/effects/spells/armors、`gui.modalState()`（3 个对话层 VisualPose.capture）、`gui.rconnectMessages()`（events.concat）、`saveRequests.concat()`
│   ├─ frame.resources（读 hold/hp/mana）               :153-154
│   ├─ lastFrame=frame；lastFrame 保留两房完整生命周期 :155
│   ├─ outgoing = PoseTween.copy(frame)（**浅拷贝**，不是深拷贝）:159
│   ├─ outgoing.projectiles = projectilesForRoom(...)；projectileEvents 再来一次（**两次全量过滤＋两个新数组**）:160-161,167-173
│   ├─ packet = encoder.encode(outgoing)（FrameDelta 全树 diff）:162 → FrameDelta.as:7-12,58-94
│   └─ link.send(packet)                                 :163 → Link.as:30-38 → WireCodec.as:11-20（AMF3 writeObject；≥4096B 再 compress）→ socket.write/flush
│       成功后 projectileSelection.published(outgoing)   :164 → ProjectileSelection.as:36-50
│   计时：host.sceneAndPlayers / host.character / host.delta / host.send / host.publish（`HostSession.as:147,152,162,165`）
```

**频率要点（本节）**：`presentFrame` 1/帧；`capture(room)` 1/占用房/帧（第 3 次）；`SceneSnapshot.capture` 1/帧（只采玩家 1 所在房）；`SceneSnapshot` 内部按单位/物件/特效/瓦片；`FrameDelta.diff` 每条“变化记录”1 次；`Link.send` 1 包/帧；`CharacterState.capture` 1/帧；`MapState.capture` 1/帧；`sound.snapshot` 1/帧；`player.snapshot` 2/帧。

### 1.5 每条网络消息（加入侧→主侧，约 30 包/秒）

```
socket ProgressEvent SOCKET_DATA                      Link.as:84-90（读进 buffer）
└─ drain()（8ms 预算，每次最多处理若干完整包）       Link.as:91-123
   ├─ 取 4B 长度 → 复制 payload（新 ByteArray）        :98-101
   ├─ WireCodec.decode（可能 uncompress + AMF3 readObject）:105 → WireCodec.as:21-30
   └─ message(item) → RConnectMod.receive              RConnectMod.as:220-260
      ├─ probe.message（仅 probe）
      ├─ exploration / chat / leave 等分支（cheap）
      └─ host.receive(value)                          :244 → HostSession.as:66-85
         ├─ inputs[1].accept(value,getTimer())         :68 → Commands.as:21-52
         │    （逐字段验证 + 每个 action 验证 + `actions=actions.concat(staged)`）
         ├─ pause.remote/remoteMenus/remoteSats        :69
         ├─ awaitingFirstView confirmation 判定        :70-73
         ├─ personal(actors[1], value.settings)（4 键）:74
         ├─ identity 不一致且首帧未完成 → publish()     :79-83
         └─ reason!="" → link.send({type:"rejected"})  :84
```

**频率要点**：`drain` 每次 socket 事件（≈30/s）1 次；`Commands.accept` 每条输入 1 次；`personal` 每条 1 次；无逐帧成本。主侧**没有**每消息的 JSON 编解码：B 的线格式是 AMF3（`WireCodec.as`），`JSON.stringify` 只出现在偏好/日志/字段长度校验与探针（`RConnectMod.as:47,347`、`WeaponBridge.as:58`、`Log.as:11` 等），不在战斗热路径。

### 1.6 频率总表

| 粒度 | 工作 | 位置 |
|---|---|---|
| 每帧 | `before()` 全部主侧逻辑（HUD 100ms 闸门除外） | `RConnectMod.as:104-175` |
| 每帧 | `presentFrame`→`capturePresentation`→encode→send | `RoomRuntime.as:174-193`、`HostSession.as:120-166` |
| 每 tick | `stepLand`＋每占用房 `room.step`＋2 次 `RoomRuntime.capture` | `RoomRuntime.as:120-172` |
| 每 100ms | `ui.refresh/hud.refresh`、`SharedVision.step` | `RConnectMod.as:115`、`SharedVision.as:28-31` |
| 每 5 tick | hum 音量衰减 | `SessionSound.as:57-59` |
| 每单位/每 tick | `stepObject` 包装、`WorldClaims.choose`、`room.units.indexOf`、AI 选目标；`SceneSnapshot` 的字段/身体/血条/原生帧采集 | §1.3/§2 |
| 每弹丸/每 tick | 3 次 `RoomRuntime.capture` 各建一份 state＋`VisualPose.capture(clip)`＋`keyFor(room)`；发布时 2 次 room 过滤 | `RoomRuntime.as:194-228`、`HostSession.as:167-173` |
| 每特效/文字/每 tick | 链上松散显示对象的 `DecorativeEffects.capture`/`VisualPose.capture`/`AuthorityParticle.capture`/`speech.capture` | `SceneSnapshot.as:127-149` |
| 每记录/每发布 | `FrameDelta.diff` 逐键比较、`path.concat()`、`WireCodec` AMF3 遍历 | `FrameDelta.as:58-94`、`WireCodec.as:11-20` |
| 每条消息 | `Link.drain` 解码＋`receive` 验证 | §1.5 |
| 每次伤害 | `damagePlayer` 包一层 `scope.run` | `RoomRuntime.as:99-103` |
| 每次抓取/丢弃 | `PeerGrabs` 的 `scope.run`（dropTeleObj） | `PeerGrabs.as:21,34,58` |

---

## 2. 主侧战斗开销的增长点（按预估影响排序）

排序依据：优先用 profile01 的 80 敌人分项【实测】，其次用调用次数×单位成本【推断】；同一行注明增长维度（敌人/弹丸/特效/血条/文字/房间面积/固定）。

| # | 开销点 | 增长维度 | 80 敌人实测/估计 | 证据 |
|---|---|---|---:|---|
| 1 | **逐单位标量字段采集** `NativeFields.capture`（单位实体＋`inter` 各一次/单位/帧） | 敌人数×字段数（UnitPlayer 282 项；普通 Unit 相近量级） | **11.56ms/帧**（`capture.unit.fields`；全量 `capture.nativeFields` 178 次/帧 共 11.8ms） | `SceneSnapshot.as:89`、`NativeFields.as:18-78`；profile01 实测 |
| 2 | **逐单位身体姿态** `VisualPose.capture`（每帧新建候选记录＋每节点读 transform/color/filters＋类名） | 敌人数×显示节点数 | **8.42ms/帧**（`capture.unit.body`；`capture.pose` 199 次/帧） | `VisualPose.as:37-152`（`:60-63,99`）；profile01 实测 |
| 3 | **模拟阶段每对象包装＋原生 step** | 对象数（敌人＋弹丸＋碎片＋箱子＋掉落） | `host.simulate` 19.96ms/帧；`simulate.room` 15.57ms（含 players 6.33、tactics 2.73）；单僵尸 step 0.095ms×80≈7.6ms | `RoomRuntime.as:52-98,104-119`；profile01 实测 |
| 4 | **FrameDelta 全树差异＋AMF3 编码＋压缩＋发送** | 变化记录数×树深；弹丸/特效/文字越多越大 | `host.delta` **5.70ms**；`wire.serialize` 1.49（n≈1.3/帧）、`wire.compress` 1.07（≥4096B 才压）；`host.send` 3.55 | `FrameDelta.as:58-94`、`WireCodec.as:11-20`、`Link.as:30-38`；profile01 实测 |
| 5 | **每帧全房间瓦片扫描**（37 字段比较×tile） | 房间面积（与敌人数无关） | **3.77ms/帧**（8 敌人 3.63ms→80 敌人 3.77ms，常数项） | `SceneSnapshot.as:66-84`；profile01 实测 |
| 6 | **弹丸记录：同一 tick 建 3 份＋每份一次 `VisualPose.capture`/`keyFor`/类名/currentFrame** | 活弹丸数×3＋发布时 2 次过滤 | 计时到的 2 次合计 0.30ms/帧；第 3 次未计时；弹幕密集时线性放大 | `RoomRuntime.as:117,154,185,194-228`、`HostSession.as:160-161`；【静态＋实测频率】 |
| 7 | **血条采集** `HealthBarPose.capture`（每单位每帧 `known()` 做 getChildByName/类名/`filters`/图形回读＋逐槽 transform） | 带血条单位数 | **1.87ms/帧** | `SceneSnapshot.as:92`、`HealthBarPose.as:22-96`；profile01 实测 |
| 8 | **原生动画帧/像素标识**（`AuthorityAnimation.capture`：`getColorBoundsRect` 像素扫描＋`blitRect`） | 有 blitData 的单位数 | **1.65ms/帧** | `AuthorityAnimation.as:7-14`（`:12`）；profile01 实测 |
| 9 | **场景其余部分**（房间/land 字段、backdrop、ink、玩家快照、map、audio、桥模组） | 玩家/地图/事件数 | `host.sceneAndPlayers`(33.29) − units(24.40) − tiles(3.77) − objects/effects(0.62) − untracked(0.41) ≈ **4.0ms/帧**；另 `host.character` 1.10ms | `HostSession.as:136-151`、`SceneBackdrops.as:17-31`、`MapState.as:9-19`、`SessionSound.as:47-62`、`CharacterState.as:9-24`；profile01 实测 |
| 10 | **特效/文字/碎片**（松散 Pt：`DecorativeEffects.capture`→拒绝则全量 `VisualPose.capture`＋`AuthorityParticle.capture`（含 `getColorBoundsRect`）＋`speech.capture`） | 特效/伤害数字/血花数量 | 本次 80 敌人测试仅 0.62ms（`capture.objectsAndParticles`）；爆炸/火/血花密集时按对象线性上升，且 `getColorBoundsRect` 是像素级操作 | `SceneSnapshot.as:127-149`、`DecorativeEffects.as:22-53`、`AuthorityParticle.as:5-16`（`:15`）、`AuthorityAnimation.as:12`；【静态＋实测小样本】 |
| 11 | **地形墨迹（弹孔/烧灼/血）块采集** `TerrainInk.snapshot` | 新增脏块数×64×64 | 每次脏块 `getPixels+compress`＋`copyPixels`；持续射击每秒十余块，爆炸会成片 | `TerrainInk.as:43-60`、`PixelSurface.as:9-14`；【静态】未单独计时 |
| 12 | **感知桥：每敌对单位 findCel 跑 2 次＋每次包 `scope.run`** | 敌人数×感知节拍 | `native.scope` 40732 次/366 帧≈**111 次/帧**；`native.scope.prepare+restore` 均值 0.026+0.013=0.039ms/次 → 包装本身约 4ms/帧量级（含包住整个 room.step 的大调用，不能全算开销） | `NativePerception.as:11-46`、`NativeScope.as:25-66`（`:35-36` 字段表、`:32` 外观）、`patch_native.py:34-43`；profile01 实测计数 |
| 13 | **每个玩家步的 `SecurityTerminals.player` 全房 objs/acts 扫描** | 房间物件数×2 玩家 | 未计时；每步新建 Array＋Dictionary，`owns` 每条读 `inter.allact/prob` | `SecurityTerminals.as:42-49,57-75`；【静态】 |
| 14 | **每个玩家步的 `PlayerPointer.run` 全对象链扫描＋3 Dictionary** | 对象链长度×2 玩家 | 未计时；`room.units.concat`＋整链遍历＋每个 onCursor 对象 `getQualifiedClassName`/多处 `NativeAccess.get`（try/catch） | `PlayerPointer.as:6-67`、`PlayerActor.as:64-69`；【静态】 |
| 15 | **暗房时远玩家光照** `ActorSight.update`：全房间瓦片同步＋原生 `lighting()`（O(面积)，每 tile 含 sqrt） | 房间面积×远玩家移动 | 未计时；暗房行走时每 tick 触发原生全房光照（`Location.as:3108-3256`）＝主侧光照成本近似翻倍 | `ActorSight.as:10-51`、`PlayerActor.as:94-97`；【静态】 |
| 16 | **共享探索的每帧 RENDER 覆盖**：`render()` 对全房瓦片 `charAt/indexOf/getPixel32` | 房间面积 | 未计时；默认“共享探索”开启；10 万像素级/帧的字符串＋BitmapData 读 | `SharedVision.as:19-20,131-151`（`:146-150`）；【静态】 |
| 17 | **`keyFor` 字符串拼接**：每弹丸每 capture、每音效、每房间 summary/场景 key | 弹丸数×3＋音效事件数＋房间数 | 每次 6 段拼接＋`NativeAccess.get`（try/catch）；弹幕/连射时数百次/帧 | `RoomRuntime.as:218`、`SessionSound.as:31,48`、`SceneSnapshot.as:44`、`NativeAccess.as:98-101`、`OccupiedRooms.as:111`；【静态】 |
| 18 | **杂项每帧分配/重复**：`MapState.capture` 全网格、`CharacterState` 双层深拷贝、`PlainData.copy(personal)`、`concat`、`applyPreferences` join、`TimeBridge.snapshot×2`、full 帧 `NativeFields.capture(room)×2`、`rooms.summary()`、`spawnsByPlayer.concat()` | 固定/随物品数 | `host.character` 1.10ms（其中深拷贝占比未拆）；其余合计约 0.2-1ms | §2.11；profile01 `host.character` 实测 |

### 2.1 全量扫描与重复遍历（重点）

**对象链（`room.firstObj`→`nobj`）每 tick 最多 6 次**：
1. `stepPlayers` 末尾 `capture(room)`（`RoomRuntime.as:117`，`RoomRuntime.as:194-210` 的 while）。
2. `stepLand` 在 `room.step()` 之后再 `capture(room)`（`:154`）。
3. `presentFrame` 对每个占用房再 `capture(room)`（`:185`，未计时）。
4. `SceneSnapshot.capture` 的松散特效链（`SceneSnapshot.as:127-149`）。
5.／6. 每名玩家各一次 `PlayerPointer.run`（`PlayerActor.as:66` → `PlayerPointer.as:15`），除非 SATS 停步（`PlayerActor.as:58`）或移动预测分支。

**`room.units` 线性扫描**：`RoomRuntime.stepOwnedObject` 的 `room.units.indexOf(object)>=0`（`:88`，每个非 owner 对象每 tick）；`WorldClaims.choose` 的距离循环（`WorldClaims.as:11-15`）；`SecurityTerminals.grant` 的 `for each unit in owner.loc.units`（`:118`，仅激活时）；`OccupiedRooms.repairRoster` 的 indexOf/splice（`:51-58`，转移时）。

**`room.objs/acts/bonuses` 每帧扫描两处**：`SceneSnapshot.as:106`（采集环境对象）与 `SecurityTerminals.as:44`（找终端，逐玩家步）。两处目的不同但都在每 tick 全表遍历。

**逐弹丸重复**：同一 tick 对同一弹丸 `projectile()` 三次（三次 capture），每次都新建 `{id,room,x,y,dx,dy,bx,by,tick,owner,clip,rotation,visual,sx,sy,frame,layer,born}`＋`VisualPose.capture(clip)`＋`getQualifiedClassName(clip)`＋`access.keyFor(room)`＋`NativeAccess.get(clip,"currentFrame")`（`RoomRuntime.as:211-228`）；发布时再 `projectilesForRoom` 扫两遍（`HostSession.as:160-161,167-173`）。此外 `stepObject` 对每颗弹丸在 step 前后各调一次 `projectile()`（`RoomRuntime.as:56,61`），即**每 tick 每弹丸最多 5 次 state 构造**（step 前、step 后、3 次 capture；实际受对象链遍历顺序约束，见代码）。

### 2.2 逐单位字段采集（最大项，11.56ms/帧）

- 每帧 `SceneSnapshot.capture` 对 `room.units` 里每个非玩家单位做 `NativeFields.capture(u)`；`interaction(u.inter)` 再做一次 `NativeFields.capture(inter)`（`SceneSnapshot.as:89,198`）。profile01 全量 `capture.nativeFields` **178 次/帧**（80 单位＋2 玩家＋2 武器＋房间＋land＋80 个 `inter` 等）。【实测】
- `NativeFields.capture` 的路径（`NativeFields.as:18-78`）：首次 `describeType` 建 schema（缓存，`schemas`）；之后每 tick 对每个字段 `value[name]` 动态读取＋`isFinite/is` 类型判定（`:48-64`），变化字段写进 `updates`，变更记录走 `deltas[out]={from,updates,removed}`（`:68-75`，弱键 Dictionary）供 `FrameDelta` 快速分组（`:67-68`）。**每单位每帧都要把全部字段读一遍才能知道“没变”。**
- 与加入侧对称：`NativeFields.apply` 在加入侧 5.56ms/次（profile01 `replica.unit.fields`），同样是全字段循环（`NativeFields.as:86-118`）。
- 结论：这是“按读取者裁剪字段”和“变更信号化”的主战场；`state/b-scalar-optimization-2026-10-27.md:65` 已把它列为下一瓶颈（“按具体读取者审核哪些状态确实需要反复复制”）。

### 2.3 身体姿态（8.42ms/帧）与每节点分配

- `VisualPose.capture` 每个节点（`:45-152`）：`display.transform.colorTransform`（`:48`）与 `display.transform.matrix`（`:49`）——AIR 每次返回**新对象**；`display.filters`（`:62`）返回**新数组**；然后 `var s:Object={...}`（`:60`）**无条件新建候选记录**，即便与上一帧完全相同也在 `:122-143` 比较后丢弃、返回旧记录；每个子节点还要 `getQualifiedClassName(child)`（`:99`）。【静态】
- 频率：`capture.pose` 199 次根调用/帧（80 敌人＋血条＋特效/物件/玩家），每次递归若干节点；80 敌人 `capture.unit.body` 8.42ms/帧。【实测】+【静态】
- 该目录的 smooth04 已做“静止子树/差异提示”复用（`VisualPose.as:122-150`、`PoseTween.copy`、`NativeFields.delta`），但**每节点候选对象的创建与 transform/filters 读取仍在**；`state/b-scalar-optimization-2026-10-27.md:11-13` 记录了“类名/位图配方缓存组合在轻场景约慢 4%”的反例，任何进一步缓存都必须单因子 A/B，不能按组合收益推算。

### 2.4 血条 / 原生动画帧 / 特效文字

- **血条 1.87ms/帧**：`HealthBarPose.capture`（`SceneSnapshot.as:92`）先 `known(display)`（`HealthBarPose.as:36-67`：`getChildByName`×3、类名、`child.filters.length`（分配）、`graphics.readGraphicsData` 图形回读），再 `captureRoot`＋逐槽 `part()`（`:80-96` 读 transform/color 并比较）。`known()` 的结果只取决于显示结构，却在每 tick 重算。【实测＋静态】历史：紧凑血条曾因此前“实际 hpBar 有嵌套动画”而回退（`experimental/b-smooth-20261029/README.md:33`）。
- **原生动画帧 1.65ms/帧**：`AuthorityAnimation.capture`（`SceneSnapshot.as:91`）在 `visData!=null` 时做 `getColorBoundsRect` 全像素扫描（`AuthorityAnimation.as:12`）——对每个带 blitData 的单位每 tick 一次。【实测＋静态】
- **特效/文字**：`SceneSnapshot.as:127-149` 对链上每个可见对象：先 `DecorativeEffects.capture(o)`（伤害数字走紧凑配方，`DecorativeEffects.as:22-53`；否则 `reject`），再 `VisualPose.capture(o.vis)`、`AuthorityParticle.capture(o,atlas)`（含 `getColorBoundsRect`，`AuthorityParticle.as:15`）、`speech.capture(o)`、必要时 Loot 的两次 `NativeFields.capture`。文字/伤害数字越多，这条与 `FrameDelta`、`SceneEffects.apply`（加入侧）成本同步上升。【静态＋小样本实测 0.62ms/帧】

### 2.5 编码/发送/压缩

- `FrameDelta.encode`：先 `{type,session,serial,base}`，首帧 `full=frame`，之后 `diff(prior,frame,[],changes)`（`FrameDelta.as:7-12`）。`diff` 对每个变化记录：`simple()` 判定、`NativeFields.delta`/`VisualPose.delta` 命中则整条分组（`:67-76`），否则逐键遍历（`:78-94`），每产出一个操作 `path.concat()` 复制路径（`:62,63,67,68,93`）。【静态】成本随“变化记录数”线性（单位移动、弹丸、特效、背包/弹药变化），profile `host.delta` 5.70ms/帧。【实测】
- `WireCodec.encode`：AMF3 `writeObject`（`WireCodec.as:11-13`），`body.length>=4096` 则 `body.compress()`（`:15-17`），再复制进带 TAG 的新 `ByteArray`（`:18`）；`Link.send` 检查 `bytes.length>1MB` 或 `socket.bytesPending>2MB` 即断线（`Link.as:34`）。**线格式是 AMF3 而非 JSON**；两台机经 `127.0.0.1` TCP（`RConnectMod.as:191`）——压缩纯属本地 CPU 换本地带宽。【实测 wire.serialize 1.49＋compress 1.07】
- 加入侧对应 `WireCodec.decode`（uncompress＋readObject，`WireCodec.as:21-30`）与 `FrameDelta.decode`（分支克隆，`FrameDelta.as:13-51`；`branch` `:52-56`）。README 记载加入侧解码约 6ms/轮（`experimental/b-smooth-20261029/README.md:10`）。【外部记录】

### 2.6 无谓深拷贝 / 每帧对象分配清单（“逐单位 new Object/Dictionary/数组”）

| 分配 | 频率 | 位置 | 备注 |
|---|---|---|---|
| `NativeFields.capture` 的 `out`/`updates` 新对象＋弱字典 `deltas[out]` | 每个“有变化”的记录/帧 | `NativeFields.as:26,58,66-75` | 移动单位每帧都走 eager 新对象 |
| `VisualPose.capture` 的候选 `s` 对象＋（变化时）`m/c/filters` 数组 | **每个显示节点/帧**（未变也新建） | `VisualPose.as:55-63` | 主要 GC 压力源之一 |
| `RoomRuntime.projectile` 新 state 对象 | 每弹丸×最多 5 次/tick | `RoomRuntime.as:218-224` | 3 次 capture＋step 前后 |
| `RoomRuntime.snapshot` 的 `objects` 数组（全房弹丸）＋`recent` 交换 | 每帧 | `RoomRuntime.as:230-235` | |
| `projectilesForRoom` 两个新数组 | 每帧 2 次 | `HostSession.as:160-161,167-173` | 纯过滤即可 |
| `PoseTween.copy(frame)` | 每帧 1 次 | `HostSession.as:159` | **浅拷贝**，本身便宜 |
| `CharacterState.capture`：`invent.save()`＋`PlainData.copy(...)` 双层深拷贝、maps/effects 复制、`events.concat`、`saveRequests.concat` | 每帧 | `CharacterState.as:14-22`、`PlainData.as:6-23`（`visit` 对每个节点 `getQualifiedClassName`＋预算检查）、`Invent.as:1787-1869` | 物品/武器/护甲越多越贵；`host.character` 1.10ms/帧 |
| `PlainData.copy(personal)`（4 键） | 每玩家/帧 | `PlayerActor.as:124` | 小 |
| `MapState.capture` 的 `visits` 数组＋每访问房 4 元数组 | 每帧 | `MapState.as:9-19` | 与 land 网格规模相关 |
| `InputSource.frame` 新对象＋actions 数组＋`flight.concat/slice` | 每帧 | `InputSource.as:12-33`（`:29`） | 2 个数组/帧 |
| `applyPreferences` 数组＋`join(":")` 字符串 | 每帧 | `RConnectMod.as:277` | 微 |
| `TimeBridge.snapshot` 两个对象 | 每帧（Sandy 开启时） | `HostSession.as:134`、`TimeBridge.as:71-75` | 可合成一次 |
| `rooms.summary()` 新数组＋每房 `keyFor` | 每帧 | `RoomRuntime.as:234`、`OccupiedRooms.as:109-113` | |
| `spawnsByPlayer.concat()` | 每帧 | `RoomRuntime.as:234` | 2 元数组 |
| `Commands.consume` 的 result 对象＋`takeMenus` 两个数组 | 每次 consume/takeMenus | `Commands.as:53-68` | 每玩家每帧 |
| `NativeFields.capture(room)` **两次** | full 帧（首帧/换房） | `SceneSnapshot.as:45,63` | 只有 full 帧浪费 |
| `NativeAccess.get` 每读一次 `try/catch` | 每次调用 | `NativeAccess.as:102-104` | `PlayerPointer`/`GroundMotion`/`EnemyVisualProbe` 高频使用 |

### 2.7 同步节拍与帧率耦合（归纳）

- 世界 tick＝`ENTER_FRAME`（`fe/MainMenu.as:804-844`），发布＝`EXIT_FRAME`（`RoomRuntime.as:50,174`），标称 30Hz（SWF 头 frameRate=30；`World.fps=30`，`fe/World.as:44`）。
- 主侧 publish≈32ms＋simulate≈16ms（任务给定）＞33.3ms → 帧率落到约 20fps，tick 与发布同步变少；加入侧 `PlaybackClock` 观测到到达间隔变长，把 `delay` 抬到 100-250ms（`PlaybackClock.as:16-23`），README 记载密集播放等待均值 162-168ms（`experimental/b-smooth-20261029/README.md:43`）。
- `presentFrame` 的推迟条件（`stepping`/`scope.depth`，`RoomRuntime.as:178`）会在时停回放/嵌套 scope 时**整 tick 丢一次发布**；`deferredPresentations` 是现成观测点。
- 主侧每帧工作全部发生在同一 AIR 帧内：`before`（输入采集）→ 原生 `World.step`（simulate＋2 次采集）→ `EXIT_FRAME`（第 3 次采集＋场景采集＋编码＋发送）。任何一项超预算都直接减少 tick 数，不是“只在后台多花点 CPU”。

---

## 3. 主侧与加入侧的重复工作、可下沉/分工候选

| 工作 | 主侧（host） | 加入侧（join） | 判断/候选 |
|---|---|---|---|
| 单位标量状态 | `NativeFields.capture` 全字段扫描 11.56ms/帧（`SceneSnapshot.as:89`） | `NativeFields.apply` 全字段写入 5.56ms/次（`ReplicaScene.as:209`，`NativeFields.as:86-118`） | 同一 schema 两侧各遍历一次；可下沉为“按消费者裁剪字段＋变更分组”（主侧省扫描，加入侧省写入），但要先做字段消费者证据 |
| 身体姿态 | `VisualPose.capture` 8.42ms（`SceneSnapshot.as:89`） | `VisualPose.apply` 3.07ms（`ReplicaScene.as:225`） | 对称但方向不同；可继续“紧凑配方化”（血条/伤害数字/BackObj 已做），减少两侧节点遍历 |
| 血条 | `HealthBarPose.capture` 1.87ms（`:92`） | `HealthBarPose.apply` 0.85＋0.64ms（`ReplicaScene.as:294-302`） | 已有紧凑血条但曾因嵌套动画回退；需先证明哪些 hpbar 符号可 compact |
| 弹丸 | 每 tick 3 次 state＋视觉采集，只发 `frame.room`（`HostSession.as:160-161`） | `applyProjectile`（`ClientReplica.as:266-296`）＋每屏幕帧插值 | 主侧可为“非加入显示房”的弹丸省掉视觉采集；同房场景无效 |
| 地图/角色/音频/菜单/消息 | 每帧构造（`MapState.capture`、`CharacterState.capture`、`sound.snapshot`、`menus.capture`） | 每离散帧 apply（`MapState.apply`/`CharacterState.apply`/`sound.apply`/`AuthorityMenus.apply`） | 只有加入侧消费；可按“访问变化/序列变化/事件”触发，而不是每帧构造（需验证不会延迟显示） |
| 差异计算 | `FrameDelta.encode`（`FrameDelta.as:7-12`） | `FrameDelta.decode`＋分支克隆（`:13-51`） | 不重复：主算 diff、加入按 op 重建；但加入侧 `branch()` 会为每条变化路径分配新对象 |
| 显示树 | 读取原生显示树（capture） | 重建成新显示树（apply/SceneEffects） | 两侧都必须触碰同一棵树；可把更多“静态符号树”变成主侧只发配方 id＋变化标量（已在血条/伤害数字/BackObj 试过） |
| 探索 | 自己的 `own` 行捕获＋`render` 覆盖（`SharedVision.as:28-38,132-151`） | 自己的 `own`＋收到的 `memories` 合并（`:109-130`） | 双向设计，不是同一份数据；但主侧对自己的 `own` 做每帧像素压暗是否有显示意义存疑——**未验证**，若只是保存记忆可去掉每帧 apply |
| 多客户端 | 不存在（`RConnectMod.as:207-210` 拒绝第二条 socket；`HostSession.as:4` 单 link） | — | “对每个客户端重复构造负载”当前**不适用**；若将来多客户端，`FrameDelta.encode` 结果可缓存复用，但要注意 `projectileSelection.published` 与 serial 语义 |

**可下沉/分工的具体候选**（不改同步语义优先）：
1. 主侧只构造“加入侧显示所需”的视觉（弹丸非显示房不采视觉；玩家不同房时其 `visual/native` 是否仍需要——需确认加入侧 UI 是否显示离房队友）。
2. 地图/角色/菜单/音频快照从“每帧”改为“变化时/事件时”（访问变化、`serial/revision` 变化、音效事件本身已事件化）。
3. 让加入侧消费更紧凑的描述：更多原生符号（非血条）走“配方 id＋变化标量”，减少两侧节点遍历；每类符号都要有像素/姿态断言（现有 enemies/textmotion/visualfield 可复用）。
4. 探索：主侧只记录自己的 `own`，不每帧 `render` 覆盖（若本机原生光照已足够）——需视觉对照。

---

## 4. 优化候选（不改变同步语义/伤害/动画结果）

> 每条含：机制、预期收益量级（相对当前 30Hz 帧预算 33.3ms 或 profile 分项）、风险、验证方式、涉及 file:line。
> “低风险先行”＝只删重复/常量、或纯本地缓存且失效点可枚举；“需实测”＝可能触碰显示/交互语义或收益不确定。

### 4.1 低风险先行项

#### C1. 去掉 `RoomRuntime.capture` 的同 tick 重复调用（3 次→1 次）
- 机制：`RoomRuntime` 记录 `lastCapturedTick[room]`（或直接在 `stepLand` 保留调用、删 `presentFrame` 的重复 capture），同 tick 第二次起直接复用 `latestByRoom[room]`；`recent` 事件在唯一一次采集里生成。
- 收益：每 tick 每房省 2 次全对象链扫描＋每条活弹丸 2 份 state/VisualPose/类名/keyFor。profile 中可计时的 2 次共 0.30ms/帧，第 3 次未计时；弹幕越密收益越大（**估计 0.3-1.5ms/帧 @ 密集弹幕，未实测**）。
- 风险：弹丸 `ended` 事件时点/顺序变化；极短命弹丸（出生即消失）的可见帧数与 `recent` 内容。已避免改伤害/命中。
- 验证：现有 rockets-02/enemies 场景（双方真实开火、命中、死亡）＋对比 `frame.projectiles`/`projectileEvents` 的 tick 序列与加入侧截图；统计 `RoomRuntime.recent` 长度与 `spawns`。
- 位置：`RoomRuntime.as:104-118,120-172,174-193,194-228`。

#### C2. 缓存 `NativeAccess.keyFor(room)`（房间 key 字符串）
- 机制：以弱键 Dictionary 缓存 `loc → key`，在换房/`land.rconnectLayoutSeed`/坐标/`landProb` 变化时失效（失效点可枚举：`RoomTransfers.relocate`、`OccupiedRooms.showHost`、`SharedVision` 的 key 使用点、`createPlayer`）；或缓存在 `OccupiedRooms` 的 record 上。
- 收益：每弹丸每 capture 一次 6 段字符串拼接（`RoomRuntime.as:218`）、每次音效一次（`SessionSound.as:31`）、每房间 summary/场景 key；弹幕/连射时数百次/帧（**估 0.2-1ms/帧，未实测**）。
- 风险：缓存过期导致线包 room 身份错→加入侧拒绝/错房；用 4-6 个分量廉价校验兜底。
- 验证：换房/挑战/传送/分房/重进地图的全套 UI/loading/security 断言＋日志中 host/join `room` 字符串一致。
- 位置：`NativeAccess.as:98-101`、`RoomRuntime.as:218`、`SessionSound.as:31,48`、`SceneSnapshot.as:44`、`OccupiedRooms.as:111`。

#### C3. 合并 `projectilesForRoom` 的两次过滤
- 机制：一次循环同时产出 `projectiles` 与 `projectileEvents` 两个数组（或复用上一帧数组，仅在内容变化时新建）。
- 收益：省一次全量弹丸遍历＋一个数组（**估计 0.05-0.2ms/帧 @ 数百弹丸，未实测**）。
- 风险：顺序必须保持（含同一 tick 内出生即结束的弹丸，`HostSession.as:169-171` 注释）。
- 验证：`rockets`/`enemies` 的弹丸事件断言与加入侧显示顺序。
- 位置：`HostSession.as:160-161,167-173`。

#### C4. `TimeBridge.snapshot` 每帧两次→一次
- 机制：`HostSession.as:134` 里 `snapshot(paused,1)` 与 `snapshot(paused,0)` 只差 `cooldown`，合并成一次快照后按玩家填 cooldown；或只给加入侧发一次、本机 present 复用。
- 收益：省一个对象＋`hits` 计数读取（**<0.05ms/帧**，纯清理）。
- 风险：无（字段不变）。
- 验证：沙盒时停/回放功能断言（`timecontrol-01`）。
- 位置：`HostSession.as:134`、`TimeBridge.as:71-75`。

#### C5. 去掉每帧重复的偏好读取/字符串拼接与场景内重复读取
- 机制：
  - `applyPreferences()` 增加“偏好版本”判断（Preferences 变更时才 join 5 项），`RConnectMod.as:157,271-286`。
  - `SceneSnapshot` 单位循环外 hoist `access.time.phase=="replay"`（`:88` 每单位读一次）。
  - `NativeFields.capture(room)` 在 full 帧不要采两次（`:45` 与 `:63` 合并）。
  - `SecurityTerminals.player` 先查“本房是否有 hack_robot 终端”的缓存布尔，无终端直接 `operation()`（`SecurityTerminals.as:57-63`；失效点：房间转移/`room.isRebuild`/终端激活）。
- 收益：**合计估 0.1-0.5ms/帧**；C5 的 Security 部分在物件多的房间更明显（未实测）。
- 风险：偏好即时生效的 UI 断言；终端缓存失效点遗漏会忽略破解（需覆盖 `security-01`）。
- 验证：UI/安全/换房/换图断言＋帧时间 A/B。
- 位置：`RConnectMod.as:157,277`、`SceneSnapshot.as:45,63,88`、`SecurityTerminals.as:57-63`。

#### C6. `InputSource.frame` 的两次数组复制
- 机制：`flight` 用环形/游标管理（`acknowledge` 已按 id 出队），`frame` 里避免 `flight=flight.concat(a); a=flight.slice(0,16)` 每帧两次分配（`InputSource.as:10,28-29`）。
- 收益：2 个数组/帧（GC 微优化，**<0.05ms/帧**）。
- 风险：动作确认顺序/上限（16/64）语义必须保持。
- 验证：动作菜单/换枪/控制类断言（controls/ui）。
- 位置：`InputSource.as:10-33`、`Commands.as:64-68`。

### 4.2 需实测项

#### C7. 单位字段采集按消费者裁剪（最大潜力）
- 机制：先做只读“消费者清单”（加入侧 `NativeFields.apply` 之后的原生读取者：`setVisPos/visDetails/setHpbarPos/addVisual`、HUD `setHp/setMana/setWeapon`、`ReplicaScene.applyUnit/applyObject`、`CharacterState.apply`、MSW/TDFC/Injury 桥），把 `NativeFields` schema 拆成 `每帧必发 / 变化才发 / 仅首帧`；对“只影响加入侧显示、且不进入战斗判定”的字段按变化/低频发。**不删字段值本身，只删不需要每帧重读的**。
- 收益：字段项 11.56ms/帧；按已发表建议（`state/b-scalar-optimization-2026-10-27.md:65`）保守估计可减 20-40%（**2-5ms/帧，需实测**），加入侧同步省 1-2ms。
- 风险：漏字段→加入侧 AI/UI/动画/桥模组状态错；必须先有静态消费者清单＋现有 enemies/textmotion/ui/rockets 断言。
- 验证：字段子集 A/B 跑 8/80 敌人 60 秒；逐字段对照“旧全量 vs 新子集”在加入侧的 native 读取值；保留 `NativeFields.delta` 协议不变。
- 位置：`NativeFields.as:18-78`、`SceneSnapshot.as:85-103`、`ReplicaScene.as:209,225`、`HudModel/NetHud`、`CharacterState.as`。

#### C8. 身体姿态采集的“静态节点快路径”
- 机制：`VisualPose.captureNode` 先用 `display.x/y/rotation/scaleX/scaleY/alpha/visible/currentFrame` 与上一记录比较（这些是免分配 getter），完全相同且上一记录有 `m` 时**直接返回上一记录**，跳过 `transform.matrix`/`colorTransform`/`filters` 读取和候选 `s` 分配；加“每 N 帧或每类变化时全量校验”兜底 skew/滤镜。类名可先做弱键缓存（单因子实验）。
- 收益：身体 8.42ms + 特效/物件姿态；若 70% 节点静态，理论省 3-6ms/帧（**需实测**；注意 `b-scalar-optimization-2026-10-27.md:11-13` 的组合实验曾在轻场景慢 4%，必须单因子 A/B）。
- 风险：漏检仅 skew/滤镜变化（原生 limbs 常见静态 skew）→ 视觉错位；血条/武器旋转必须仍有确认。
- 验证：`textmotion-02`（111/124）、`enemies-*`（像素/姿态断言）、`visualfield-01` 视觉对照；同时抓 `capture.pose` 分项。
- 位置：`VisualPose.as:37-152`（`:45-63,99,122-151`）、`SceneSnapshot.as:89`。

#### C9. 地形瓦片扫描从“每帧全量”改为“变化驱动/脏区”
- 机制：保留 full/换房/回放时的全量；平时仅在“可能改地形”的信号后扫描（`room.isRebuild/isRecalc/isRelight`、`cTransform` 变化、`TerrainInk` 有新脏块、门/梯/水相关对象 step 过、破坏事件），否则复用上一份 `tiles/plainFront`；或降频＋强制全量兜底（每 N 帧/每 0.5s）。
- 收益：`capture.tiles` 3.77ms/帧（≈帧预算 11%）；**低风险版本（事件驱动）可全拿，保守降频版本拿 50-80%**（实测口径见 profile01）。
- 风险：漏发地形变化→加入侧碰撞/视觉不同步（穿墙、看不见的破坏、水/门状态错）。**必须先把“哪些原生写入会改 `TILE` 字段”枚举清楚**——本次审计未完成这一步（未验证）。
- 验证：`terrainlive`（主130/加75）、`rockets`、`textmotion` 的破坏/像素断言；逐帧对比 host/join 的 `tiles` 差分与 `terrainRevision`。
- 位置：`SceneSnapshot.as:66-84`、`ReplicaScene.as:105-130`。

#### C10. 感知桥：减少“每敌人两次 findCel＋两次 scope 包装”
- 机制：对每敌对单位的同一次 `findCel`，在一次 `scope.run` 内依次切换两名玩家上下文（复用同一份 `unit` 状态快照），避免两次完整 `NativeScope.run`（26 字段拷贝/恢复＋两处 `AppearanceState.capture`）；或先按 `loc.units`/可见性做廉价预筛，只有候选玩家才跑原生 `findCel`。**结果必须与“先 priorUnit、再最近、再失败兜底”的原选择规则逐值一致。**
- 收益：`native.scope` 111 次/帧，`prepare+restore`≈0.039ms/次；含包住 `room.step` 的大调用，不能全算；**估 1-4ms/帧，未验证**。
- 风险：目标选择/仇恨结果变化（不允许），必须逐单位对比 `celUnit/celX/celY/priorUnit` 及命中/开火日志。
- 验证：`enemies`（124/117）、`stress`、`motion` 场景；对比“旧桥 vs 新桥”每 tick 的 `NativePerception` 输出与敌人开火次数。
- 位置：`NativePerception.as:11-46`（`:22` scope.run）、`NativeScope.as:25-66`、`patch_native.py:34-43`。

#### C11. 线包压缩阈值上调/免压（本机回环）
- 机制：`WireCodec.encode` 的 `packed=body.length>=4096`（`:15`）提高（如 64KB）或仅对 full 帧压缩；两台机经 127.0.0.1（`RConnectMod.as:191`），带宽不是瓶颈。
- 收益：host `wire.compress` 1.07ms/帧＋join 对应 `uncompress`（join decode≈6ms 的一部分）；**估 1-2ms 两侧合计，需实测**。
- 风险：未压缩大包触发 `Link.LIMIT=1MB`（`Link.as:12,34`）断线；`Link` 的 `bytesPending>2*LIMIT` 背压（`:34`）与 `setTimeout(drain,1)`（`:116`）行为需观察。需先记录实际 packet 尺寸分布。
- 验证：记录每包 `bytes.length`、`socket.bytesPending`；跑 8/80 敌人 60 秒＋分房/换图/时停回放；确认无 `backlog/peer closed` 日志。
- 位置：`WireCodec.as:11-20`、`Link.as:30-38,91-123`。

#### C12. 显示记录按“事件/序列”构造（map/character/audio/menus）
- 机制：`MapState.capture` 仅在访问集合或 land 身份变化时重建（房间转移/新发现）；`CharacterState`（尤其 `invent.save()`＋`PlainData.copy` 的双层深拷贝）在“输入动作/伤害/拾取/换枪/菜单序列”变化时重建，其余时候复用上一份不可变记录；`sound.snapshot` 已是事件驱动（保留）；`AuthorityMenus.capture` 按 `serial/revision` 变化。
- 收益：`host.character` 1.10ms/帧＋`sceneAndPlayers` 中 map/players/audio 约 4ms 的一部分；**估 1-2.5ms/帧，需实测**。
- 风险：加入侧显示滞后（弹药数/血量/地图/菜单）→ 属于“显示结果”变化，必须逐场景验证；`PlainData.copy` 去掉后若有运行时对象泄入线包会序列化巨型对象，需保留轻量校验。
- 验证：`ui`（主134/加91）、`textmotion`、`security`、`rockets`；A/B 对比加入侧 HUD 的 ammo/hp/地图与菜单打开时序。
- 位置：`CharacterState.as:9-24`、`PlainData.as:6-23`、`MapState.as:9-19`、`HostSession.as:136,145,148`。

#### C13. 暗房远玩家光照（`ActorSight`）与共享探索 `render` 的降频/缓存
- 机制：
  - `ActorSight.update`（`ActorSight.as:10-51`）只在“需要该玩家光照”的消费点按需计算（`withCursorLight`/`visible` 前），或在位置变化小于阈值时只跑 `lighting2`；避免每 tick 全房 `lighting()`。
  - `SharedVision.render`（`SharedVision.as:132-151`）用“行变化/原生重绘 epoch（`TerrainInk` epoch、`room.isRebuild`、换房）”做脏标记，未变时不扫全房瓦片。
- 收益：`ActorSight` 在暗房行走时每 tick 一次全房光照（原生 O(面积) 含 sqrt，`Location.as:3108-3256`），可能是 1-5ms/帧；`SharedVision.render` 每帧全房 `getPixel32/charAt`（估 0.3-1.5ms/帧）。均**未实测**。
- 风险：远玩家可见度/交互/敌人感知变化（语义敏感，需按玩家分别验证）；探索压暗可能滞后或漏压。
- 验证：暗房/光照场景（`visualfield`/`motion`）、mine/隐身/交互断言；A/B 像素对照加入侧光照与交互提示。
- 位置：`ActorSight.as:10-51`、`PlayerActor.as:94-97`、`SharedVision.as:19-20,28-38,132-151`。

---

## 5. 不在主侧正常战斗路径上的东西（避免误判）

- `EnemyVisualProbe` 只在 `config.probe===true && scenario=="enemies"` 时构造（`RConnectMod.as:56-71`）；它在主侧每 3 tick 对敌人/血条/武器/弹丸/特效做像素采样、`getBounds`、`BitmapData.draw`、hash，失败时还写 PNG（`EnemyVisualProbe.as:186-209,230-250,254-256`）。它属于**测试探针**，80 敌人性能对照的“插桩/额外归因”成本主要来自这类探针与 Timing，不应写进产品基线。
- 同类：`WeaponProbe/MswProbe/StressProbe/...` 均由 `config.probe` 或 scenario 选择（`RConnectMod.as:56-93`）；正常对局不创建。
- `PlayerLives` 是主侧真实路径（死亡/复活）：每 tick 只遍历 2 名玩家（`PlayerLives.as:21-37`），可忽略；但 `PlayerLives.died` 的 seam 决定复活语义，不要动。
- `TerrainInk`（主侧注册 `Grafon.rconnectInk`，`TerrainInk.as:14-18`）只在原生真正绘制/擦除时记录脏块，`snapshot` 每帧调用但无脏块时是空循环（`TerrainInk.as:43-60`）——成本集中在“有新弹孔/爆炸”的帧。
- `SceneEffects` 是加入侧应用器（`ReplicaScene.as:16,153`），主侧不使用；主侧对应物是 `SceneSnapshot` 的采集与 `DecorativeEffects` 紧凑配方。
- `FrameDelta` 的 `decode/branch` 只在加入侧（`ClientReplica.as:62`）；主侧只有 `encode/diff`。
- `TerrainInk/PixelSurface` 的块压缩是**每脏块**成本，不是每帧固定成本。

---

## 6. 关键证据索引（profile01 实测数值，旧基线 field22 插桩，80 敌人 366 帧）

| 计时键 | 均值 | p50 | p95 | n（样本/帧） | 说明 |
|---|---:|---:|---:|---:|---|
| `host.publish` | 43.68 | 38 | 74 | 366（1/帧） | 采集＋编码＋发送总包 |
| `host.sceneAndPlayers` | 33.29 | 30 | 55 | 366 | `capturePresentation` 前半（players/scene/map/audio） |
| `capture.units` | 24.40 | 21 | 45 | 366 | 80 单位整轮采集 |
| `capture.unit.fields` | — | — | — | 29280（80/帧） | 单次均值 0.1445，合计 11.56/帧 |
| `capture.unit.body` | — | — | — | 29280 | 单次 0.1052，合计 8.42/帧 |
| `capture.unit.bar` | — | — | — | 29280 | 单次 0.0233，合计 1.87/帧 |
| `capture.unit.blit` | — | — | — | 29280 | 单次 0.0206，合计 1.65/帧 |
| `capture.tiles` | 3.77 | 4 | 5 | 366（1/帧） | 常数项（8 敌人时 3.63） |
| `capture.objectsAndParticles` | 0.62 | 0 | 2 | 366 | 松散特效/文字 |
| `capture.untrackedEffects` | 0.41 | 0 | 1 | 366 | 层级未跟踪符号/掩码清理 |
| `host.delta` | 5.70 | 5 | 11 | 366 | FrameDelta diff |
| `host.send` | 3.55 | 3 | 7 | 366 | WireCodec 编码＋socket 写 |
| `wire.serialize` | 1.49 | 1 | 4 | 478 | AMF3 |
| `wire.compress` | 1.07 | 1 | 3 | 478 | ≥4096B 压缩 |
| `host.character` | 1.10 | 1 | 2 | 366 | CharacterState（含背包深拷贝） |
| `host.simulate` | 19.96 | 19 | 29 | 366 | 含 room/players/tactics |
| `simulate.room` | 15.57 | 15 | 24 | 366 | `room.step()` 整段（含 players 6.33） |
| `simulate.players` | 6.33 | 6 | 11 | 366 | 2 名玩家 step |
| `simulate.tactics` | 2.73 | 3 | 4 | 366 | TDFC 桥（外部模组成本） |
| `simulate.object.fe.unit::UnitZombie` | 0.095 | 0 | 1 | 29280 | 单僵尸 step 包装 |
| `simulate.projectileCapture` | 0.149 | 0 | 1 | 732（2/帧） | RoomRuntime.capture（第 3 次未计时） |
| `native.scope` | 0.297 | 0 | 1 | 40732（≈111/帧） | 含嵌套/包住 room.step 的大调用，不能相加 |
| `native.scope.prepare` | 0.026 | 0 | 0 | 40732 | 包装 overhead |
| `native.scope.restore` | 0.013 | 0 | 0 | 40732 | 包装 overhead |
| `capture.pose` | 0.070 | 0 | 1 | 72845（199/帧） | 根调用，含子递归，不能与分项相加 |
| `capture.nativeFields` | 0.066 | 0 | 0 | 65148（178/帧） | 全部 NativeFields.capture |

（8 敌人行对照：`outer_ms`＝`capture.units` 2.47ms，`capture.unit.fields` 1.10、`body` 0.87、`bar` 0.19、`blit` 0.19；`capture.tiles` 3.63；说明“字段/身体”随敌人数线性、“瓦片”近似常数。）

---

## 7. 未验证 / 需要补证据的点

1. **【未验证】地形变化来源枚举**：`TILE` 的 37 个字段里哪些会被原生在“不触发 Grafon 绘制/ink 变更”的情况下修改（水、门、梯、`isRebuild`、`recalcWater`）——这是 C9 能否安全事件化的前提。
2. **【未验证】字段消费者清单**：加入侧 `NativeFields.apply` 之后到底哪些 native 方法/桥读哪些字段（`visDetails/setHpbarPos/addVisual/setPos/HUD/桥`）；没有这份清单不能裁字段（C7）。
3. **【未验证】`SecurityTerminals.player` 与 `PlayerPointer.run` 的真实耗时**：本次只用静态调用次数估计，profile01 没有对应计时键。
4. **【未验证】`ActorSight`/`SharedVision.render` 在暗房/亮房的实际耗时与房间面积关系**：profile01 场景是同一测试房，未拆这两项；需要新插桩（只读实验）或对比 A/B。
5. **【未验证】第 3 次 `RoomRuntime.capture`（presentFrame）的实际成本**：profile01 只在 `simulate.projectileCapture` 盖到 2 次；第 3 次可能需要单独插桩确认。
6. **【未验证，有反例】类名/位图配方缓存的单独收益**：`state/b-scalar-optimization-2026-10-27.md:11-13` 记录“组合实验在较轻场景约慢 4%，全部撤出”；`experimental/b-smooth-20261029/README.md:15-17` 记录 smooth02 的弱身份表/数字编号只待实测。任何缓存项必须单因子 A/B 并有轻/重两档。
7. **【未验证】压缩阈值上调后的最大包尺寸**：需要记录 `bytes.length` 分布才能确保不触发 `Link.LIMIT`/背压。
8. **【未验证】加入侧消费地图/角色数据的“实时性要求”**：C12 的事件化是否会带来可见滞后，需要逐 UI 场景实测。
9. **【未验证】`BodyEffectsProbe` 等探针的计时是否混入某些历史性能报告**：本次未逐一核对历史测试的准备清单；引用 profile01 数值时已注明“旧基线＋插桩”。

---

## 8. 建议的下一步（最小成本顺序）

1. 先做**只读、无产品改动**的补测：给 `SecurityTerminals.player`、`PlayerPointer.run`、第 3 次 `RoomRuntime.capture`、`ActorSight.update`、`SharedVision.render` 各加一个 Timing 键（只插桩到隔离 build，不进产品），拿到与 profile01 同口径的分项。
2. 按 C1/C2/C3/C4/C5/C6 逐项做单因子 A/B（每项独立跑 8/80 敌人 60 秒，复用原 5%/P95/重复 1.2 门槛）；这些不改协议、不改包内容，最容易先落。
3. C7（字段裁剪）先出“消费者清单”文档与只读核对脚本，再谈删字段；C9（瓦片）先做变化来源枚举；C8（姿态）先做单因子 A/B 与视觉断言；C10（感知桥）先做逐单位输出对比。
4. 每项都要记录：host/join 帧时间、`host.publish` 分项、包大小、`PlaybackClock` 欠帧/等待、以及对应功能断言（UI/terrain/security/enemies/rockets/textmotion）。

---

*本报告只读审计，未编译、未启动游戏、未修改任何 `.as`、`release/` 或构建产物。*
