# 加入侧动画与遮罩热点：限定只读审查

2026-10-22。准确 recovery-13 / recovery-14；只解析现有原生采样及源码，没有运行 JVM/AIR、改生产、增加候选或改其它模组。详列指纹和原始代表栈见 `evidence.json`；`analyze.py` 可重复生成此文件。

**结论：没有证据支持删减枪口动画或降低敌人动画频率。能确认一处小而确定的 RC 重复计算，以及一个较大的跨对象遮罩重复处理机制；后者不能仅靠删除 MirrorMasks 安全解决。两条都未证明能解决当前整帧停顿。**

## 采样与准确来源

| 加入侧包含式 CPU 样本 | 13：3b8269a9a7 | 14：a6a7e27789 |
|---|---:|---:|
| 总样本 | 1385 | 1259 |
| GameBridge.tickFrozenAnims | 272（19.6%） | 278（22.1%） |
| UnitPresentation.tick | 111 | 111 |
| UnitPresentation.play → gotoAndPlay | 71（5.1%） | 71（5.6%） |
| UnitPresentation.apply / animateBody | 10 / 3 | 16 / 5 |
| MirrorHitUnit.syncMotion | 35 | 29 |
| MirrorMasks 全路径 | 38 | 42 |
| RV hideEnemies，其中 applyMask | 164，其中122 | 150，其中123 |

这些行互相嵌套，不能相加；也不是调用次数、净耗时或预期收益。play 的全部采样均来自 tick 的开火分支，reload/apply 分支为0；phase0没有 play 样本。71个样本里包含 `[execute-queued]`、Sprite 子对象构造和 FocusManager addedHandler/GC，不能把这些一概当作重复枪口调用。

13 SWF `1177eb1a…4bfddb1`；14 SWF `225a7940…efbe5f7`。本报告涉及的 GameBridge、UnitPresentation、RemoteMotion、WeaponDisplay、RConnectAnimationAccess、MirrorMasks、MirrorHitUnit 七份源码在两个冻结版本中逐字节相同。

RV 使用已冻结 `RealisticVision/build/regression-recovery-output/production-singlepass/src`，全部6份源码对 manifest 原字节哈希通过；SWF `7852f61e…be86764` 与两次实际 run.json 输入一致。未用 RV 根 src。原生武器规则只引用公共1.02 Weapon.as，未声称本次重新审计安装宿主对应方法字节。

14普通密集 `4277cc066e` 仍有14项失败、加入侧各段36/40/41/42/41/40/41帧、p95约306–405ms；此处两个 profile 只是归因证据，不赋予性能资格。

## 动画链：已有去重与实际可省工作

1. `GameBridge:129–135,342–362,6389–6428`：普通帧只由 ENTER_FRAME 的 onMirrorFrame 调 tickFrozenAnims；不再用 EXIT_FRAME。重入有 `_animatingMirrors`；RENDER 的第二入口只处理共同暂停且收到新姿态的 `_pausedMotionDirty`。两轮采样没有递归 tickFrozenAnims 栈；这不是严格每帧调用计数，但源码不支持“常规整段重复跑两遍”的判断。
2. `GameBridge:6412–6419` 仅新 selected 身份变化时 apply，并传 `deferTick=true`，随后统一 tick 一次。`UnitPresentation:325,386–387,465–475` 的 apply/animateBody 都可能接收一次 blit姿态，但后一份是按当前源时间插出的姿态，不能简单删除。`RConnectAnimationAccess:103–107` 已按动画id/整数帧/visData去重实际 blit；MovieClip 连续播放也已有身份/状态门控。
3. `UnitPresentation:430–439` 每枪每帧最多消费一项队列，只有 flash≤1 才 `gotoAndPlay("shoot")`。公共原生 `Weapon:1599–1608` 同样在 t_shoot≤1 才启动并置3，`Weapon:1233–1235` 在 step 递减。`play:395–396` 查 currentLabels 有小开销，但采样主要在真正 gotoAndPlay 及其触发的执行/构造。**不能把“当前label仍是shoot”当作不必重启的依据：原生连发在同标签也要重新闪光。**
4. **确定的局部无效计算**：`UnitPresentation:415–428` 总是先算第二套按本机到包间隔的 m/p/angle，并写 w.X/Y/rot；若 clockSample.weapons 中存在匹配的 slot/id/variant/stream，紧接着把三个值全部覆盖为 RemoteMotion 已插值的值。两组写入之间没有 animate、读回或回调；公共原生 Weapon 的 X/Y/rot 是普通数值字段。可先找匹配源姿态：有则直接赋最终值，无则完整保留旧回退公式。elapsed 仍须保留给 prep/reload。**这是可做等价组件的最小 RC 单方法方向，不跳帧、不改枪口播放、冷却或源时钟；收益还未知，不能把71个 play 样本算作可节省部分。**

上述第4项反例应包含：匹配/缺失 weapons、错slot/id/variant/stream、±π跨界、null clock、paused、枪械刚替换、prep/reload持续、同帧多枪。严格比较最终位置/角度、animate次数及顺序、shot queue/flash/play序列，再做原生密集对照。仅去掉被覆盖的临时数值，不借机重写整条动画链。

## 同一图像被两次处理：原因是碰撞代理共用图像

- `GameBridge:5770–5778` 在保留敌人本体的 loc.units 中追加 MirrorHitUnit。`MirrorHitUnit:46–69` 复制本体的 X/Y/scX/scY/fraction/npc/invis/sost 等，且直接借用同一个 vis/hpbar；只避免挂入 firstObj 的原生 step 链。它是命中和 SATS 真实功能需要的代理，不是另一张图片。
- 准确 RV `hideEnemies:3329–3404` 遍历整个 loc.units。没有 disabled 排除、没有以 vis 身份去重；exempt[vis] 只是后面 scanArms 的排除表，不阻止当前循环。非玩家、非npc、非隐形的敌人本体与代理因此会各自执行 enemyState；部分可见时各调一次 applyMask。
- `RV:2845–2876` 的 unitBBox 仅取已复制的坐标和大小；`RV:3002–3006,3048–3099` 的遮罩缓存以 **Unit身份** 分开，各建 s2/s3，先后赋给同一个 vis/hpbar。后一份覆盖前一份的 mask 引用，第一份 Shape 留在层里。RV 已缓存瓦片分类及每个单位的 maskInput，但没有跨本体/代理合并这个工作。复制的坐标通常相同，若中途状态改变仍应尊重各自输入，不能无条件按类型跳过。
- `MirrorMasks:79–126` 正是为此记录共用关系、识别并隐藏失去引用的遮罩，防白块；它没有把代理加入 units，也没有调用 RV。`capture` 仅遇新 mask 身份才导出图形/扫描层；已有同一 captured mask 会跳过。因此不能把 RV 的123个 applyMask样本全归给 MirrorMasks，也不能靠删除它解决重复遮罩。
- `MirrorMasks.prepare` 在一次普通帧会分别经 observe→register、tickFrozenAnims、capture→register 调用，重复查两项字段；已有 views 会很快返回。这是源码可证的重复检查，但阶段之间可能原生重建vis/遮罩，不能直接删两个阶段。它的38/42个总样本也包含必要的修复工作，目前没有证据支持为此扩改生命周期。

**本轮处理边界**：确认 RC 的代理布局导致 RV 对同一图像重复计算，未提出其它模组写入。不能临时移走 loc.units 的代理、改成npc/player或令vis=null规避遍历：分别会影响原生命中、敌我/锁定以及SATS无空值防护。也不建议围绕 RV 的某个回调“借走”字段；异常和监听顺序会把显示优化变成玩法问题。要在 RC 内消除这条成本，需要另行证明稳定的显示/碰撞职责隔离，当前不能给出已安全的小补丁。

**建议下一步只准备第4项的等价小组件；保留真实 shoot 和每帧更新。** 遮罩链先保留为已证实的结构成本，不根据包含式样本承诺减半或宣称其是全部卡顿根因。
