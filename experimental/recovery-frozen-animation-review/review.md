# 准确14冻结敌人动画：有界只读复核

2026-10-22。只读 `build/m52/recovery-14/src` 和密集加入侧 `a6a7e27789/join.log`。未改生产、驱动或旧结果，未编译或启动 AIR/JVM。本目录的分析器重新解析原采样，并在读取前后核对全部88份AS、run.json和join.log；完整SHA见 `evidence.json`。

**结论：没有找到新的、证据足够且能保留全部显示与玩法的较大优化。停止扩展这条微优化路线。** 普通帧并未重复运行两遍整套敌人动画，命中代理也没有再跑原生AI/武器step。278个包含式样本中，有大量真正枪口播放、源时钟采样和必要命中状态更新，不能直接当成可删成本。此前15的姿态算术、已审过的blendWeapons中间数组，不作为新方案重新推进。

## 重新计算的证据

总计1259 CPU样本；tickFrozenAnims包含278，分成74种调用栈，其中67以`[reap]`为叶节点。没有逐对象调用次数、分配调用栈或每条CPU样本的独立时间戳，不能把GC停在某函数上解释为该函数产生了全部垃圾。

| tickFrozenAnims内部包含式项目 | 样本 |
|---|---:|
| UnitPresentation.tick |111|
| 其中play→原生gotoAndPlay |71|
| RemoteMotion.sampleTimed |72|
| MirrorHitUnit.syncMotion |29|
| captureUnitDamage |25（其中reap叶12）|
| UnitPresentation.apply / animateBody |16 / 5|
| MirrorMasks / maskReferences |10 / 0|
| TelekinesisVisuals |10|

这些项目嵌套，不能相加、换算毫秒或预期FPS。gotoAndPlay子树分别有26个Sprite构造和26个FocusManager样本，二者也可能嵌套。非开火phase0仍有71个tick样本，但play为0；phase1/5/6的play为21/18/32。采样只涵盖这四段，不能冒充完整七阶段逐帧追踪。

## 确定排除的重复执行

- `GameBridge:132,135,242–254,340–362,6389–6428`：常规由晚优先级ENTER调用一次；无EXIT_FRAME入口，重入有守卫。RENDER补调用仅在共同暂停且新姿态脏时发生，用于SATS最终画面。删除它会重新引入暂停姿态滞后。
- `GameBridge:6402–6419`：一次sample/settle后，身体和武器读取同一currentSample；选中snapshot身份变化才apply，且`deferTick=true`，不会在apply末尾再tick一次。`UnitPresentation:407,461`没有另一次sample。
- `UnitPresentation:310–315,350–370`：呈现记录仅首次建立；原生武器factory只在新/变化槽位且实际武器id/variant不匹配时运行，不是每渲染帧重建武器。逐帧gotoAndPlay引发的原生子对象构造是另一件事，不能混同factory重复。
- `UnitPresentation:430–443`：每枪每帧最多取一项队列，只有flash≤1才重启shoot并置3。公共原生1.02 `Weapon:1599–1608`采用同一冷却；`animate:1966`只处理显示、蓄力帧和朝向，不会再次调用shoot。不能按“当前标签仍是shoot”跳过重启，连发的下一次枪口闪光会消失。
- `GameBridge:5714,5770–5778`冻结本体并把命中代理放进loc.units；代理未加入firstObj步进链。`MirrorHitUnit:52–70`的syncMotion是字段同步，`tickFeedback`仅维护受击反馈。公共原生 `Unit.step:1766`遇disabled立即返回，后面的childObjs.step不会执行。当前RC动画路径没有调用Weapon.step/actions/attack。这里是静态路径证明，不声称重新反编译核对了本次宿主所有方法或其它模组独立回调。

## 对象身份与缓存为何不能草率合并

1. **身体、命中代理共享同一个vis，确实会被RV重复处理。** 这在前次审核已证实；本次没有新的安全RC内消除办法。按Unit身份缓存会留下两个显示状态，按vis合并却可能忽略双方字段在不同回调阶段的差别。去掉代理、把它设为npc/disabled或临时清空vis，会改变子弹碰撞、SATS和锁定条件。不能为了降低遍历量这样处理。
2. **武器呈现记录按slot，原生对象按引用。** slot/id/variant/stream与视觉对象不是同一身份。源码允许旧slot记录留在guns中，但本轮日志没有每枪引用/slot历史，未证实密集场发生两个记录共用一枪或重复animate。不能据此改成按id去重：两把同型号武器可以都是真实武器，换枪后stream又可能不同。这是缺少实际证据的生命周期风险，不计作本轮性能根因，不新建诊断。
3. **命中代理的vis.width/height不能只按vis引用缓存。** `MirrorHitUnit:68–70`用于判断SATS可绘制性，同一MovieClip换帧、子对象、缩放或武器挂载都可能改变边界；同一引用出现0宽→非0宽是反例。要保证完全等价须捕获全部失效条件，当前没有稳定原生版本号，缓存成本与风险可能超过收益。
4. **念力滤镜不能只缓存“上次期望颜色”。** `TelekinesisVisuals.weapon/paint`已经比较实际滤镜；原生动画或其它效果可能在同一根对象上替换filters，内部kor也可能随时间轴重建。跳过实际读取会丢光晕或覆盖新效果。应失效于根/子对象身份、实际滤镜任何变化、释放和reset，而现有接口不能廉价完整通知这些变化。
5. **遮罩修复并非每敌人每帧整树扫描。** MirrorMasks.prepare会在不同帧阶段重复检查vis/hpbar，但阶段间确可重建显示对象；capture仅有新mask进入pending才调用maskReferences。原样本此函数0命中，无法把278样本归因于它反复扫树。

## 唯一新确认的小分配，当前不推进

`GameBridge:5845`每次captureUnitDamage都创建`{armor,shield}`，包括完全没有损伤时。它只由私有_baseDefense保存；全部读写位置为5711、5841/5845、5890、6049、6199，没有外部持有者。因此在计算旧值差额后更新同一私有记录、仅缺记录时新建，理论上可消除一份短命对象，不需要缓存敌人输入，也不改调用次数。

若未来单独考虑，必须仍在本次读取hp/armor/shield之后计算差额，再原顺序更新；保留缺记录、护甲/护盾恢复、被打后立即发包、权威快照重置、死亡/替换/换房清理。不能把`scanAndReportDamage:5822`那次capture顺便删掉：本机命中可能发生在逐帧capture之后、发送/交接之前。

**本轮不建议为此再立候选或组件。** 25个capture样本包括必要的字段探测、差额和字典操作；其中12个GC样本不是该literal的独占成本。现有证据不能把这一对象分配与密集长帧联系起来。15与17已经说明局部等价收益不保证整机改善；继续堆此类小改动不符合本轮目标。

## 停点

保留所有动画、源采样频率、射击队列、命中代理和视野规则。没有新增生产实现、缓存、诊断框架或游戏测试建议。本轮结论是停止在该278样本子树中继续寻找未经证实的大幅“去重”，不把已有局部热点报告成已找到长帧修复。
