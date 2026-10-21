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

每侧每轮在首次可见飞行和首次原生接触位置各做一次真正舞台合成的有/无弹体像素比较，临时 visibility 在 finally 恢复；不是只画一个独立 clip。耗时分别写入 `probe.costMs` / `contactProbe.costMs`，原始慢帧不被排除，不能拿此轮数据宣称总体性能通过。

飞行结束后才输出/发送整段采样。源弹原生 `babah` 首次成立时额外发送一次接触位置通知，供对侧在缓冲播放到该位置时检查接触像素；该通知不驱动生产播放，不逐帧传测试消息。日志包含：

- `FLIGHT NATIVE SHOT`：真实武器配置、实际弹速和原生弹体类。
- `FLIGHT SOURCE TRACE`：源端每次最终 RENDER、真实终点。
- `FLIGHT REMOTE TRACE`：对侧每次最终 RENDER、逐项指标。
- `COOP PASS/FAIL native-flight-continuity ... case=N`，两侧各自 DONE。

断言检查至少 3 个实际可见源帧和对侧帧、唯一弹体、正向前进、相对源真实轨迹偏差不超过 3 世界像素、飞行期间位置不连续停住超过 85 ms、整段可见 RENDER 间隔不超过 `max(85 ms, 源端 p95 × 1.5 + 15 ms)`。末段检查覆盖至少 65% 原生路径，剩余尾段不超过原生一帧最大移动量的 1.1 倍（最少容差 20 像素），并在结束后确实移除。会动的原生 clip 分飞行和接触两个阶段检查动画帧推进。接触段另外要求双方有实际合成像素、对侧至少跨两个游戏帧、位置保持原生接触位置、帧值来自原生接触段，且两侧可见停留时长之差不超过同一帧间隔门槛。双 RENDER 发生于同一 ENTER_FRAME 不算两个游戏帧。报告保留整段和分阶段的原始指标，以上有限容差不是“完全无延迟”的证明。

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

分析器独立从逐帧采样重算路径、停顿、间隔、动画帧和末端指标；拒绝缺轮、重复轨迹、两侧元数据不一致、COOP FAIL 或缺 DONE。元数据只允许有限非整数数字的最多一个 binary64 ULP（相邻可表示数）往返误差，并逐项列出；字段集合、数组顺序、字符串、布尔、整数与零的符号仍严格相等。该容差不用于像素、轨迹或连续性。它只会给 `sampled_flight_checks_passed`，永久保留 `functional_only=true`、`performance_qualified=false`、`dense_fire_qualified=false`。22 指纹、版本、登记和其它模组日志仍由外层验证负责。

## 2026-10-22：a9441a62e1 只读复核后的测试修正

原运行及 `build/m52/recovery-flight-native-02/flight-summary.json` 保持原样，不将新判据倒写成通过。冻结 `drivers-05` 未改。本次只改此目录外部测试；没有启动 JVM/AIR。

- case 1/3/5/6/7 的远端最大位置停顿 105/112/138/86/156 ms 全部位于已经到达原生接触终点的尾段。源端对应尾段为 60/106/130/62/144 ms。新测试分段判定，并新增尾段像素、至少两游戏帧、位置、帧来源、时长及动画断言，不通过删除尾段来制造成功。
- case 0 源端 20 条可见记录，对侧仅 2 条且都在同一游戏帧；下一游戏帧相隔 257 ms 后弹体已经消失。其首次远端可见比源端晚 545 ms，原始覆盖为 0。这是真实末端渲染丢失，继续保留失败。旧驱动没有 prepare/armed/首个 ENTER_FRAME 和接收包时间，尚不能把 545 ms 全部归为网络。
- case 2/4/7 的对侧可见帧间隔 91/88/110 ms 仍超过原有 85 ms 门槛。case 6 飞行中坐标继续前进，动画 f=1 却保持 167 ms，其中两次游戏帧间隔约 82 ms；源动画四帧循环。仍保留动画失败，不能仅凭同一帧值认定已耗尽轨迹。
- 5 组元数据严格不等均为约一个 ULP 的 JSON 数字往返差异，无字段或语义差异。新增比较只覆盖这个明确边界。
- 新 `phases` 记录准备开始/结束、armed、首次活动 ENTER_FRAME/RENDER、首次可见、原生发射/接触/结束、收到接触/整段数据以及评估时间；不预热、不延迟到平稳才开始，不跳过首发。`wire` 在原有 TcpLink 消息监听上被动复制当前试验枪弹的已解码帧范围、时戳和帧值，最多 1024 条，达到上限明确失败。监听时间位于生产 Session 消息处理后，不等于内核网络到达时间；没有读取生产私有游标，也没有修改生产时钟。
- 旧记录缺少新增接触像素或 phase 时明确记为缺证，不能据此声称新驱动已验证。原始 COOP FAIL 始终保留。

对实际同步代码的只读判断：所有 8 组在碰墙前均未观察到跨 ENTER_FRAME 的相同位置停留；case 0 只有一个可见游戏帧，不能由此排除未显示期间的问题。case 2/4/6/7 加入侧可见期间分别约 24.4/25.7/24.4/25.9 帧每秒，源端约 29.9/30.2/29.9/28.4。证据首先指向整帧工作耗时，不支持先增加所有弹体的缓冲延迟或外推轨迹。

`recovery-02/src/rconnect/net/TcpLink.as:174` 在一次 SOCKET_DATA 回调中持续解码并同步分发全部完整包；case 0 加入侧 prepare 至下轮的 521 次 RoomCodec 解码合计日志耗时 938 ms（这是整个区间合计，不能误当成单次阻塞）。`RemoteMotion.as:147` 在偏移纠正较大时可推进游标，`:184` 限在最新身体样本；`ProjectileFrameStream.as:16` 让弹体使用身体游标；`ProjectileVisuals.as:175` 在绘制前按结束时戳移除。因此“批量处理积压后游标跨过剩余寿命”是有具体代码支持的待核假设，但旧日志没有包到达/弹体游标证据，不能宣布已经找到唯一原因。先用新 phase/wire 记录区分初始化和积压，再局部削减同步处理成本；如证实批量分发饿死 RENDER，再评估保序、有时间预算的收包处理，不能丢弃命中/结束消息。

本次外部测试修正验证：`test_analyze.py` 的 8 个纯离线分类测试已通过，覆盖 1 ULP 边界、结构/布尔/整数/有符号零严格比较、碰墙与飞行停顿分开、真实飞行停顿/整帧间隔仍失败、尾段无像素/同游戏帧重复 RENDER/错误帧/超长寿命/缺尾段仍失败。Python AST 与 AS 括号结构检查通过，不代表 AS 编译通过。只在内存中重算了旧 8 组日志；全部仍不合格，原文件未改，未生成新实机通过记录。

## 本次交付验证边界

只做静态检查：Python AST、命令行帮助、AS 结构/依赖与原生参考交叉阅读。另在内存中用合成数组检查了分析器的四个数学分支：正常路径、停顿、过早消失、无像素；后面三种均被相应断言拒绝。此检查没有生成游戏通过报告，不是实机证据。尚未编译，尚未实机跑，当前没有任何新原生场景通过结论。源依据：1.02 `fe/weapon/Weapon.as` 的 `attack` / `shoot`、`fe/weapon/Bullet.as` 的 `step`、`fe/inter/Camera.as` 的 `setZoom`、`fe/unit/UnitAlicorn.as` 与 `fe/AllData.as`。
