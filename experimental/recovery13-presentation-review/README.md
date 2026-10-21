# recovery13 每帧显示路径：只读审阅

2026-10-22。准确候选 `build/m52/recovery-13` / `0.2.24-recovery13`，SWF `1177eb1ae9b227bcf3c0eb39dedad92b63ac16dcb7ffb0b421ea0a2024bfddb1`。已逐项核对 prepared.json 全部 source 指纹；输入清单在 [inputs.json](inputs.json)。只读生产/冻结目录，未启动 JVM/AIR、未取新采样。

**结论：有一个可验证、无需新缓存的分配假设；没有足够证据说明它是当前109ms等整帧空档的主因，也没有根据立即改生产。** 优先用13的原生 profile 核对 `GameBridge.captureUnitDamage`。旧574D的CPU比例与 timing08 的区间仅用于选择核查对象，不能移作13的热点或收益。

## 优先假设：无伤害检查仍分配新的防御基线

准确位置 `GameBridge.as:5831–5857`。每次进入有效、已有基线的镜像敌人检查，先读取HP/护甲/护盾并算差，再无条件执行：

```as
_baseHp[u] = cur;
_baseDefense[u] = {armor:armor,shield:shield};
if(dmg <= 0 && armorLoss <= 0 && shieldLoss <= 0) return;
```

因此即使80个敌人完全没受伤，依然每次80个短命Object。调用不仅来自 `tickFrozenAnims:6401` 每实际游戏帧，也来自 `scanAndReportDamage:5822`（Session.flushRoomReports:1174，联机定时器路径1004）；完整修复包还在 `applyUnitsSync:5654` 先捕获待结算伤害。默认tickMs=50，但AIR在负载下可能合并定时器，**不能按20Hz当实测次数**。

可复现条件是：加入侧已收到80个活体基线、无伤害、持续运行原密集phase0；直接由该分支可确定分配次数等于成功走到这里的调用次数。若实际30游戏帧/秒，单逐帧路径就是2400个Object/秒；这是条件性算术，**不是本轮分配采样，也不代表分配字节或耗时**。敌人少、帧率低时规模也随之降低。

最小可能改法是保留已经存在的 `_baseDefense[u]` 小对象，算完旧差值后原位写 armor/shield；仅缺失时创建，不新增跨帧缓存或读数跳过。静态查遍 `_baseDefense` 的全部使用点：它是GameBridge私有Dictionary；除快照初始化/重置/删除外，只在该函数读取，没有发送或外部保存这两个字段对象的引用。因此这是明确的临时分配机会。但**不能删掉逐帧/报告前读取**：本地命中可能在任一原生回调发生，报告前与应用宿主HP前必须先取走已有损失，不能把“同帧”当不变保证。

若后续获准做隔离候选，必要等价边界包括首次缺基线、无变化、HP/护甲/护盾各自减少、回复后再受伤、同帧多次命中/读数、完整快照重置、删除/换房、暂停。仅证明对象分配少了不够；若当前CPU采样稀少、无采样整帧无可辨收益，就应搁置，不能重复单位lookup那种微小收益却增加维护的方案。

## 如何用当前已有原生采样证伪

复用新走廊同冻结驱动的 `--profile` 入口：仍是已有 ProjectileProfileTestDoc / SustainedDensityTestDoc 采样逻辑，无需新增生产hook或诊断架构。读取加入侧的 `GameBridge.captureUnitDamage`、`tickFrozenAnims` 调用链样本，分别看无开火phase0与开火phase1/5/6；分母只用真正CPU采样窗口，包含子调用的计数不能相加。先看它是否在13上仍达到值得处理的规模，再决定是否写小补丁。

现有采样把 NewObjectSample 只按类型汇总，**不保留分配栈**，故 Object总量不能精确归到captureUnitDamage。该工具能验证/否定函数CPU负载是否明显，不能单凭Object总量证明这一处占多少；有需要才用实际生产类小组件做新旧等价与分配计数，不能从这份只读报告宣告收益。profile本身的帧率不作性能验收；原七阶段、109ms原失败及原生最终显示检查保持。

## UnitPresentation 中确认的次要机会与保护边界

`observeWeapon:145` 每次都生成 `frameBullets[w].concat()` 或空数组，再把不在索引中的最后一颗Weapon.b补到尾部。宿主ENTER路径 `GameBridge.onMirrorFrame:346` 经observe逐武器调用；最终RENDER `onVisForceFrame:258` 经observeFinal再调用；完整capture:196又以stamp=0观察计数。已确认有临时数组，但没有13耗时证据。若当前主侧采样落在 observeWeapon/Array.concat，可考虑直接遍历已存在的同帧索引，再独立处理不在其中的Weapon.b，保留原发现顺序和seen去重；不需要新长寿命缓存。本次未实施，也不把有限几个数组的删除说成整帧修复。

不能直接把ENTER和RENDER两次观察合并：Flash帧脚本可能在中间改变位置、动画帧、枪口/近战尾迹；`observeWeapon:167` 明确以最终RENDER覆盖同stamp样本。第一帧出生、已从链表移除但仍要发送的终态、换枪后的旧弹、散弹/连发、同stamp修正都依赖这些语义。射击计数也是读取当前ammo/kol_shoot，而不是纯旧数组计算。

## 已存在的去重，不再另堆缓存

- `scanBullets:77` 已按loc+stamp只建一次弹链索引，`beginCaptureBatch:36` 已在同步批次共享历史武器归属索引。不是“每敌人扫描全链”。
- `tickFrozenAnims:6412` 只在所选visual对象身份变化时apply整套枪/姿势；`RConnectAnimationAccess.tick:91` 只在id/整数帧/visData变化时blit。不能把全部80实体每帧调用等同80次重画位图。
- `UnitPresentation.tick:431–438` 已限制枪口clip的实际重启，不能据旧profile的gotoAndPlay栈直接删射击动画。`play:395` 每次遍历currentLabels有小分配可能，但现阶段没有引入标签缓存的依据。
- `MirrorHitUnit.syncMotion` 已与克隆抵抗数组的sync分开；逐帧只更新运动/碰撞/指示状态。继续合并会影响加入侧命中与SATS，不能作为无风险去重。
- `PlayerBodyEffects.tint` 已使用直接通道比较，旧“每body四个数组”的说法不适用于13。最终RENDER的视野/遮罩/重挂仍有必要，不能仅因为ENTER已经处理就删掉。
- UnitPresentation.tick 的备用枪口插值会在匹配到clockSample.weapons后被覆盖（416–429），是少量冗余算术；elapsed同时用于prep/reload，且没有匹配时需要回退，不能整段移除。目前不优先。

## 本轮边界

未重新提出BinaryMessageCodec改写或单位lookup；后者实际净0.0225ms/全量查询的证据与搁置决定仍保留。没有对13做CPU排名，没有认定GC导致长帧，没有新增缓存、候选、测试驱动或新运行。最可执行的下一步只有：用已经可调用的13原生profile确认上述函数级假设；若不是主要成本，直接停止这一微优化方向。
