# 无图像爆炸：独立事件最小提案

状态：**仅源码，未编译、未运行组件或原生双人、未部署。** 源码祖先 `build/m52/recovery-04/src`；准备了叠加到已冻结 recovery05 的逐方法差异，保留它的离房时钟修复。这里没有改 integrated、冻结产物、游戏本体或 MSW。

## 实际依据与边界

| 来源 | 已核实事实 | 能据此做什么 |
|---|---|---|
| `game-reference/decompiled/1.02/src102/scripts/fe/weapon/Bullet.as:135,666` | `new Bullet(owner,x,y,null,true)` 没有 `vis`，仍进入真实对象链；`explosion()` 设 `isExpl=true` 后执行原生爆炸 | 沿用当前采集器对 `isExpl` 的观察；不按半径、消失、`babah` 或弹道终点推断爆炸 |
| `mods/MoreSkills&Weapons/src/MSWBullets.as:695` | `explode()` 新建上述 dummy，写原武器/爆炸参数，调用原生 `explosion()`，最后 `liv=1`；与飞行弹是不同对象 | 现有逐帧链索引已经能发现它，不新增扫描或写 MSW |
| MSW `MoreSkillsWeaponsMod.as:178,247`；RC `GameBridge.as:132,340` | MSW 在 ENTER_FRAME 优先级 0 处理子弹；RC 在 -10000 观察链，RENDER 刷新已有观察 | 源码顺序允许在下一步删除 dummy 前观察；实际安装版与顺序仍须原生驱动证明 |
| RC `UnitPresentation.capture/captureEffects` | 已缓存 `shot.explosion`，但只放进 `flight.explosion`；无 `vis` 时 `captureFlight=null`，快速包直接跳过 | 在同一 shot seq 下补 `event.explosion`，无需造图像或新伤害对象 |
| 原版 `Bullet.as:131,240–250,684–691,930–951` | 多次气体脉冲依赖 internal `expl_t`；公开 `explKol/explPeriod` 是设定值，`isExpl` 只发生一次变化 | **不推算 gasgr 后续实际脉冲**。帧间可能漏掉原生步骤，按时间/配置补次数不能证明真实发生 |
| 原版酸液 `explVis→explLiquid("acid")` | 酸液地面足迹另走原生 Part 路径；现有 BurnVisuals 的 ground 是火焰 | **酸液地面仍为独立缺口**，本提案不改配方/伤害/地面采集 |

`isExpl` 是既有原生引爆标记，不是 explRun 成功返回计数；本次没有增强这个旧前提。原生驱动另要求源侧真实爆炸 Part 和像素存在，以免内部异常被误判为有效视觉证据。

## 三类方法改动

- `UnitPresentation.capture` / `captureEffects`：仅当 flight 为 null，且已有真实 `shot.explosion`，附加独立爆炸字段。完整包仍能补回漏掉的快包；有图像弹体仍保留原 `flight.explosion`。无重复扫描，发送频率、64 点历史、终末保留窗口不改。
- `ImpactEventQueue.receive` / 新增私有 `enqueue` / `tick`：同时接受独立字段与旧 flight 字段；按 `hit:seq` / `explosion:seq` 分别去重，共用原显示时钟、512 待播上限、2048 接收历史和 15 秒期限。同一发弹的火星与爆炸不互相压掉；重复快包/完整包只播一次。
- `ProjectileVisuals.tickBeam`：去掉另一处爆炸播放，统一交上述队列，防止“先无图像事件、后补图像”时重播。其它轨迹、贴图和终止逻辑不改。

`proposal.patch` 是相对 04 的准确差异；`inputs.json` 记录三个祖先/覆盖哈希。**不要把 `src/` 整树覆盖到 05。** `method-delta-on05.patch` 和对应 JSON 只替换上述方法，静态核对 05 的 `ImpactEventQueue.forget/setPaused`、`ProjectileVisuals.forget` 保持逐字相同；新增 enqueue 也保留 bounded pending 的 `channel` 强引用。生成器只写本提案目录，没有应用合并。

## 共用组件反例

入口 `tests/SpecialImpactChecks.as`；已组装 `components/control`（真实 04）与 `components/proposal`（04 + 三覆盖），**共用完全相同的测试源码和替身**。未跑，不能填写通过数量。

真实生产类：UnitPresentation、ProjectileVisuals、ProjectileFrameStream、RemoteMotion、ImpactEventQueue、ProjectileExplosionVisuals、BinaryMessageCodec。替身边界：Unit/Bullet 为动态壳，原生模拟与美术/声音未加载；Emitter/Snd 只记录调用；Ballistic 是明确的已命中 fixture；Energy、火焰地面、身体/武器显示采集均为替身。因此这是运输与播放次数组件，不是原生命中、像素、TCP 或性能资格。

检查包括：dummy 不等于 Weapon.b 且 vis 为 null；真实 isExpl 字段采集；快包/完整补包/终末无帧；未来源时间等待；更低 seq 晚确认；同 seq 同时火星与爆炸；重复与旧 flight 格式；先独立事件后有图像；换枪及仍在 units 中的死亡射手；无 isExpl 不造事件；暂停、回房 reset、非法数值、15 秒过期与 512 上限。死亡用例只验采集器，不声称 GameBridge 会对死亡单位继续发送快速 enemyMotion。

父会话可串行使用现有登记 runner（路径相对 RConnect；不要同时跑）：

```text
tools/validation/run_recovery_component.py --source experimental/recovery-special-impact/components/control --entry SpecialImpactChecks.as --output build/m52/recovery-special-control-01
tools/validation/run_recovery_component.py --source experimental/recovery-special-impact/components/proposal --entry SpecialImpactChecks.as --output build/m52/recovery-special-component-01
```

旧版应在独立事件相关断言失败；不接受编译失败或意外异常作反例。最终逐方法合入后，再运行 `prepare_component.py --variant observed --source build/m52/<最终候选>/src --name final-01`，使用生成的 `components/final-01` 再验证真实合入源码，同时回跑现有 detach35 组件。脚本只组装 AS 源码，不编译、不启动 AIR。

## 独立原生驱动

`native/MSWNoVisualExplosionTestDoc.as`：两轮，主发一次、加入发一次。使用现有隔离 `rconnect-coop-` 应用和正常外部驱动装载链，通过已安装 MSW 的 `testInstance` 临时把其**内存** wallHits 设为 1，结束恢复，不调用 save、不修改 MSW 源码或安装配置。

驱动通过原生 Invent.addWeapon/changeWeapon 和 Ctr.keyAttack 开火，严格要求：

1. 首发确实是 `mswglau` 的原生 Bullet，带图像、damageExpl>0、explRadius=0，证明走 MSW 接管支路。
2. 源侧观察到不同对象的原生 Bullet，vis=null、isExpl=true、explRadius>0、liv=1；不是驱动调用 explosion。
3. 对侧通过真实 TCP 收到唯一无 flight 的 `event.explosion`，位置匹配源侧 dummy。
4. 双侧各出现一次原生 `expl` Part，并有实际舞台像素，位置与 dummy 相符；对侧不新建 MSW 原生伤害 Bullet。已存在粒子排除，不拿旧特效作证。

`native-plan.json` 记录驱动、driver09 外部声明 SWC / 存根和现成 harness 的哈希；这些声明仅 external-link，不能把生产 RC 链接进外部驱动。主会话可按既有驱动构建流程冻结新入口，不需要修改通用工具的 choices。逻辑完成必须两轮且两侧 done，无 `COOP FAIL`；源码尚未证明当前安装 MSW 一定暴露测试入口。

只对爆炸补发负责：不验这把武器完整反弹轨迹、不验伤害数值/抛掷、不验 gasgr 后续脉冲或 acid 地面，更不把它作为高速流畅度或性能通过。原生截图像素比较本身会增加诊断开销，应与性能轮分开。
