# 真实枪弹与移动闪电：最终画面连续性补测

仅测试增量。没有改生产源码、`recovery-tests/prepare.py` / `run.py` 或正在冻结的 `drivers-01`，没有启动 AIR 或编译。这里的场景数与门槛是待执行断言，不是通过结果。

## 为什么补这个入口

| 已有入口 | 实际覆盖 | 此次缺口 |
|---|---|---|
| `NativeProjectileReplayTestDoc` | 原生闪电贴图、合成路径、手动时钟推进 | 不经过真实 Weapon/Bullet 或 TCP |
| `ProjectileNetworkTestDoc` | 原生天角兽与 TCP，统计可见像素/帧数 | 没有逐弹路径、停顿和末端断言；旧玩家枪没有放进背包 |
| `PresentationContinuityTestDoc` | 掉落、身体、SATS、最终 RENDER | 没有真实枪弹飞行 |
| `A22PlasmaTestDoc` / 旧 `EnergyImpactTestDoc` | TCP 对侧 `moves > 0`、`intermediate > 0` | 不能排除整段内多次卡住，也不检查末段；旧背包夹具有缺陷 |
| 修正后的 `HeavyProjectileTestDoc` | 真正背包装备、火箭/重弹/榴弹源端原生轨迹和对侧路径/寿命 | 没有普通高速弹、速射等离子弹、移动闪电的逐次最终 RENDER 停顿记录 |

## 新入口

`NativeFlightContinuityTestDoc.as`，suite 名称 `native-flight-continuity`，8 个原生场景：

1. 轻机枪 `lmg`：主到加、加到主，各一发。
2. 速射等离子枪 `quick`：主到加、加到主，各一发。
3. 等离子机枪 `plamg`：主到加、加到主，各一发。
4. 真正 `UnitAlicorn` 的 `alilight`：宿主生成、加入侧观察，左右方向各一发。

每轮一发是为了唯一对应源弹和复制弹，**不代表密集连射或整体 FPS 合格**。高射速武器的单发连续性与密集开火负载是两件验收事项；后者仍由统一会话安排原有压力驱动。

玩家枪通过 `Invent.addWeapon`、`changeWeapon` 装备，并检查背包、当前武器和 childObjs 三者是同一个对象。只把新角色的装备等级限制设为 0，弹匣放入恰好一次原生 `rashod` 的弹药。天角兽使用其构造器产生的原生 currentWeapon，没有把 NPC 武器装进玩家背包。

保留原来的弹速、速度随机数、散布、后坐力、准备时间、重力、加速度、伤害和寿命。角色被测试夹具暂停，驱动每帧只调用一次真实 Weapon.step；Bullet 继续由原生 Location 对象链推进。没有手调 Bullet.step，没有直接调用生产接收器、插值器或时钟，没有新增生产钩子。

隔离测试房清空飞行走廊、保留真实边界，把原有敌人移到走廊外。用原生 `Camera.setZoom(2)` 看全房，避免末段仅因飞出窗口而没有像素。每轮检查至少 1000 世界像素的走廊；地图不满足就明确失败，不能默默降低采样数。所有改变只在隔离运行副本内，结束不保存。

## 记录与判定

双方在 Stage `Event.RENDER` 最末优先级 `-2147483647` 采样，包括实际位置、朝向、scale/alpha、动画帧、viewport 矩形、稳定显示对象 ID、ENTER_FRAME 序号和每次 RENDER 的时间。空画面帧也保留，不把缺帧丢掉。源端另记真实 Bullet 的 X/Y、速度、剩余寿命、in_chain 和终止坐标。

每侧每轮做一次真正舞台合成的有/无弹体像素比较，临时 visibility 在 finally 恢复；不是只画一个独立 clip。该操作耗时写入 `probe.costMs`，原始慢帧不被排除，不能拿此轮数据宣称总体性能通过。

飞行结束后才输出/发送整段采样，避免逐帧写日志或传测试消息干扰飞行。日志包含：

- `FLIGHT NATIVE SHOT`：真实武器配置、实际弹速和原生弹体类。
- `FLIGHT SOURCE TRACE`：源端每次最终 RENDER、真实终点。
- `FLIGHT REMOTE TRACE`：对侧每次最终 RENDER、逐项指标。
- `COOP PASS/FAIL native-flight-continuity ... case=N`，两侧各自 DONE。

断言检查至少 3 个实际可见源帧和对侧帧、唯一弹体、正向前进、相对源真实轨迹偏差不超过 3 世界像素、位置不连续停住超过 85 ms、可见 RENDER 间隔不超过 `max(85 ms, 源端 p95 × 1.5 + 15 ms)`。末段检查覆盖至少 65% 原生路径，剩余尾段不超过原生一帧最大移动量的 1.1 倍（最少容差 20 像素），并在结束后确实移除。会动的原生 clip 另检查动画帧推进。报告同时保留全部原始帧，以上有限容差不是“完全无延迟”的证明。

路径基准为源端真实 RENDER 样本，加上原生创建时的枪口和实际终点；枪口不是推算的点。对侧开始延迟、最后可见相对原生终止的延迟均按同机系统时钟记录。每侧帧间隔用自己的 getTimer，跨主机时不能直接解释 Date 的时差。

## 给统一构建和实测的接入方式

使用已冻结且与最终候选准确绑定的 `ProductionDeclarations.swc`、`inputs/GameCombatStubs.swc`、`EffectsHarness.swf`。在**另一个全新目录**只编译本文件为 `EffectsDriver.swf`：

```text
<现有 Java/AIR 编译器，-Xmx384m>
  -source-path=<本 continuity-extra 目录>
  -external-library-path+=<已冻结 drivers 的 ProductionDeclarations.swc>
  -external-library-path+=<已冻结 drivers 的 inputs/GameCombatStubs.swc>
  -output=<新输出>/EffectsDriver.swf
  <本目录>/NativeFlightContinuityTestDoc.as
```

编译仍须登记共享 `game` 资源。不要覆写已有 drivers-01，也不要链接生产 SWC 进驱动。复制相同 frozen harness 并写 `driver-input.json`，至少记录准确候选 SHA、driver/harness SHA、entry、本目录三个输入指纹以及依赖的冻结清单/声明 SHA。574D 对照使用**同一驱动字节**，只单独改绑定候选 SHA 为 `574d2b51490ae8b25a1396555600f56a301f8a20ae50104c0e35cf2796441afe`。本目录不另造编译/启动框架。

交给现有 `run_coop_regression.py --effects --effects-driver <新驱动目录>`，沿用 `--all-mods --private-desktop --defer-visible --wait-host-world --require-exclusive-air`、共享测试登记、内存门槛、唯一 AppID、自有进程清理。建议 `random_mane`，300 秒上限。**根 run.py 不含这个新入口，不能假装已被统一包装器审计**：统一会话须照其同样要求另查双侧版本、候选/驱动字节、全部模组错误日志、安装前后完整 22 项指纹和 8 轮完成。

保存双侧原始 RConnect 日志后，可额外运行本目录的纯离线分析器：

```powershell
& '<Python>' -B -X utf8 experimental/recovery-tests/continuity-extra/analyze.py --host-log '<host-rconnect.log>' --join-log '<join-rconnect.log>' --output '<新目录>/flight-summary.json'
```

分析器独立从逐帧采样重算路径、停顿、间隔、动画帧和末端指标；拒绝缺轮、重复轨迹、两侧元数据不一致、COOP FAIL 或缺 DONE。它只会给 `sampled_flight_checks_passed`，永久保留 `functional_only=true`、`performance_qualified=false`、`dense_fire_qualified=false`。22 指纹、版本、登记和其它模组日志仍由外层验证负责。

## 本次交付验证边界

只做静态检查：Python AST、命令行帮助、AS 结构/依赖与原生参考交叉阅读。另在内存中用合成数组检查了分析器的四个数学分支：正常路径、停顿、过早消失、无像素；后面三种均被相应断言拒绝。此检查没有生成游戏通过报告，不是实机证据。尚未编译，尚未实机跑，当前没有任何新原生场景通过结论。源依据：1.02 `fe/weapon/Weapon.as` 的 `attack` / `shoot`、`fe/weapon/Bullet.as` 的 `step`、`fe/inter/Camera.as` 的 `setZoom`、`fe/unit/UnitAlicorn.as` 与 `fe/AllData.as`。
