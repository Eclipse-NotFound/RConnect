# R9：持续燃烧与地面火焰视觉（M50 合并项）

2026-10-09。用户报告：加入侧无敌人燃烧；双方无远端队友燃烧；双方无远端燃烧瓶等火爆武器留下的地面火焰。用户明确改由原始 `RConnect` 会话 `01a086bb-378c-7f60-b8e1-50d90ffa0996` 唯一合并、构建、AIR 验证和部署。R9 只写独立模块和专项，未写共用接线、版本、release、验证编排或主记忆。

## 机制依据

- 原版 `Effect.stepEffect` 在 `burning` 状态每游戏步 `Emitter.emit("flame", owner.loc, X, Y-scY/2)`；`secEffect` 每 30 步才结算燃烧伤害。冻结的敌人、队友化身不推进这一步。
- 原版 `Bullet.explVis` 的 D_FIRE 首爆在非水中调用 `explLiquid("fire",-33)`，按瓦片表面发 `sprFire` Part。现有 `ProjectileExplosionVisuals` 只重播 fireexpl/flare/iskr，没有地面火焰。
- `fe.graph.Part.step` 不执行伤害或碰撞；本模块仅调用 Emitter，不调用 Effect.step、Bullet.explosion、explLiquid 或 explRun。公共源码结论见 `shared-knowledge/rendering/discoveries/burning-and-surface-fire-particles.md`；未经过双实例实测，不标运行通过。

## 独立文件和接口

- `src/rconnect/game/BurnVisuals.as`：`capture(unit):Boolean` 读原生有效 burning；实例 `present(main,unit,burning,paused=false)` 每帧发一个原版 flame、25ms 去重，`reset()` 清弱引用；`captureGround(bullet):Array` 在源房间按原版瓦片条件记录火点；`playGround(main,room,points)` 在对侧播放原版 fire Part。火点上限 256，半径上限 800 像素，非有限输入被拒绝。没有网络会话、伤害或对象所有权代码。
- `tests/BurnVisualTestDoc.as`：隔离双实例五轮：宿主敌人燃烧、宿主玩家燃烧、加入玩家燃烧、宿主燃烧瓶落地、加入燃烧瓶落地。状态用真实 `Unit.addEffect`，落地由真实 `Weapon.attack/step` 创建 Bullet 后把本测试弹的寿命和落点压短以稳定触发原生 `Bullet.explosion`。逐帧扫描 `fe.graph.Part` 身份及其真实显示树归属。地面火焰两轮还对照源弹生成后的原生 Part 与 `captureGround` 预期点：数量逐点相等，源侧横向允许原生随机 ±2px，接收侧要求中心坐标，初始寿命限定原生 100–129 游戏步；宿主触发真实共享菜单暂停，双侧检查 Part 寿命冻结、恢复后递减且按时出链/从显示树摘除，比较两端最晚消散时间（放宽随机寿命与显示缓冲）；接收侧放置可受伤的隔离探针，测试弹直击/爆炸伤害均置零，检查纯视觉重播不使其掉血。输出 `COOP PASS/FAIL burn-visual` 与 `COOP EFFECTS DONE burn-visual`。**live 新测试尚未编译或运行**；原会话冻结的旧 probe 驱动输入不变，不能把新断言算作已验证。

Live 测试输入 SHA256（2026-10-09）：`BAF93768E2051B9DA0FACD12B23C90047065F48545D7ACA52A34DFC8BBDB22FD`。逐点最多 24 条样本的坐标、初始/最大/暂停/恢复寿命及清理结果写入 `BURN VISUAL METRIC`，供失败定位。静态括号配对、尾空白检查通过；AS3 编译、双实例日志与显示树实际结果仍由原始 RConnect 会话接续。该会话消息接口连续返回错误时，以本记录和文件哈希作为可核对交接，不把消息失败当作测试通过。

## 最小共享接线（原会话负责）

1. `GameBridge.readSnapshot` 增加 `s.burning=BurnVisuals.capture(gg)`；`readUnitsSnapshot` 每个单位增加 `burning:BurnVisuals.capture(u)`。
2. `GameBridge.driveGhost` 在按缓冲样本更新坐标后，调用 `_burnVisuals.present(main,ghost,snap.burning===true,coopPaused)`；离房/结束会话可 `reset()`。如果存在同一帧多个 drive 调用，模块已有 25ms 去重。
3. `UnitPresentation.apply` 保存 `rec.burning=snapshot.burning===true`，`tick` 在镜像活体分支调用自有 BurnVisuals 实例的 `present(main,u,rec.burning)`；`reset` 时调用其 `reset()`。暂停时 `GameBridge.tickFrozenAnims` 本就不调用 presentation.tick。
4. `ProjectileExplosionVisuals.capture` 对 D_FIRE 首爆附 `ground:BurnVisuals.captureGround(b)`；`play` 在 D_FIRE 且 !water、!repeat 时调用 `BurnVisuals.playGround(main,loc,state.ground as Array)`。`ProjectileVisuals.tickBeam` 现有 `exploded` 标记与 sourceTime 保证每弹只播放一次。不要在远端调用原版 `explLiquid`，它与爆炸方法绑定并可能带来伤害和地形重算。
5. 把 `BurnVisualTestDoc` 加入 M50 独立测试构建和双实例门禁。先对已安装 21 跑负控，预期对侧粒子检查为红；修复候选要让五轮双向专项及总回归全绿。旧版若尚无 GroundFire 事件，落地两轮也应红。

## 风险与限制

- 地面火点记录复现瓦片中心及 `phY1-33`，不读取原版的 ±2 随机横向抖动；视觉范围应接近，尚需实测像素和火点数量。R10 贴图 Part 与本 Part 区分，互不复用。
- `captureGround` 只覆盖有网络 projectile shot 的 D_FIRE 爆炸；死亡爆炸和其他原生直接粒子入口未覆盖。
- **粒子退场存在知识冲突**：1.02 反编译 `Part.setNull → Location.remObj → Pt.remVisual` 明确会把 `vis` 从显示父节点摘除；旧 `shared-knowledge/rendering/facts/part-lifecycle.md` 及 Sandevistan 实验却记有运行时鬼影。后者 v1.110 又指出该模组自己的录像/重挂是鬼影主因。不能将旧“原生 setNull 必留孤儿”当作已证游戏本体事实，也不能抹去旧实验；专项在粒子出链后检查 `vis.stage`，若矛盾重现需查具体版本/重挂路径。
- 伤害探针验证的是本测试零伤害弹下“纯视觉接收不额外扣血”；它不代替真实非零伤害武器的结算回归。
- 独立文件未使用原始真实存档，也未运行 AIR；当前 release 仍为 0.2.21-dev。接入前请确认两个新文件哈希和源码无并发改动。
