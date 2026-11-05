# 武器／弹体安全读取的最小候选

2026-10-21。仅写本目录；没有改冻结源码、整合源码、编译存根或安装版，没有运行 JVM/AIR。当前结论是**安全边界有结构证据，实际收益尚未测量，暂不建议直接并入**。

## 改动和依据

生产覆盖只有 [GameBridge.as](src/rconnect/game/GameBridge.as)，相对 `build/m52/recovery-01/src` 的准确差异见 [proposal.patch](proposal.patch)：增加两个类型导入、两个小字段表，在原有 `o is Pt` 条件内识别 Weapon/Bullet 的已确认 public var。其他函数完全不动，`probeOptional` 原文保持不变。

- Weapon 13 字段：owner、b、kol_shoot、hold、rashod、id、variant、rot、t_prep、t_reload、rapid、flare、visexpl。
- Bullet 14 字段：owner、weap、babah、isExpl、vel、explRadius、spring、flame、parr、tilehit、tipDecal、inWater、tipDamage、flare。
- 这些字段的读取不会执行 getter；沿用旧版 `undefined → null`，其余值和引用原样返回。已确认类型的 public var 不能由子类替换为同名 getter。
- 新判断放在已有 Pt 分支内部：非 Pt 的 DisplayObject、普通对象及 Proxy 不会执行新的 Weapon/Bullet 类型判断；原有 Unit/Pt 命中分支仍短路。**不命中旧字段的其他 Pt 对象会多做类型判断**，所以必须测这一组反例成本。

参考是 `game-reference/decompiled/1.02/src102/scripts`，没有把旧目录导航中的 `src102` 直接当包根。核对 `fe.weapon::Weapon/Bullet → fe::Obj → fe::Pt`，以及 `PhisBullet/SmartBullet → Bullet`。字段出处、类型、行号与 SHA 见 [audit.json](audit.json)。

另用本目录轻量 SWF/ABC 结构读取器核对了**当前实际安装 BEFC…B82A 的 pfe.swf**：27 个字段均为 public Slot trait（kind=0，非 getter），6 条继承关系吻合，字段类型与参考逐一吻合。证据见 [native-slots.json](native-slots.json)。这一步只读解析二进制，不启动反编译器或游戏。安装宿主一旦变化须重验，不把本结论泛化到其他版本。

现有 `tools/stubs/fe/weapon/Weapon.as`、`Bullet.as` 只是编译身份声明，未完整声明字段，甚至没有 Obj/Pt 继承；**不能拿它们证明字段安全**。生产只新增动态对象的 `is` 判断，不改公共存根；后续完整候选仍须编译和原生加载验证。组件按参考构建密封字段/继承夹具，复杂游戏对象引用缩减为 Object，仅验证读出的身份，不运行游戏构造器。

## 语义对照组件

[prepare.py](prepare.py) 从冻结旧版和本候选中逐字提取字段表、`probe` 和 `probeOptional`，生成 `components/probecheck/ProbeBefore.as` / `ProbeAfter.as`。没有手写另一套“等价算法”替代生产方法。

[ProbeFastChecks.as](components/ProbeFastChecks.as) 已准备以下对照，**尚未编译／运行**：

- 27 字段所有基础类型的代表值；null、引用身份、NaN、±Infinity、±0；PhisBullet、SmartBullet 的继承字段。
- 动态子类扩展字段、密封类缺字段、内部字段、空对象和空属性名。
- Weapon 子类未知 getter、抛异常 getter、返回 undefined 的 getter。
- 非 Weapon 的 Pt 上有同名 hold getter；无关对象上的 hold/babah getter，确保不能只靠字段名放行。
- 可覆写 DisplayObject.width getter 抛异常时，仍返回旧版 null。
- Proxy 的成功、无属性、hasProperty 抛错、getProperty 抛错、返回 undefined；逐次比较访问顺序和次数，不能省掉原本的 hasProperty。
- 原有 Unit、Pt、Interact 白名单不变。

`negative/IllegalWeaponGetter.as` / `IllegalBulletGetter.as` 是必须被编译器拒绝的反例，不能放入正常组件源路径。未来单独用 compc 检查；必须确认错误确实指向 hold/babah 不能覆盖已有字段，不能把缺依赖或编译配置错误当作反例通过。

静态已通过：27 个参考字段与实际 SWF public slot 类型一致、6 条继承关系、Python AST、AS 括号平衡、旧新 `probeOptional` 完全相同。静态检查不是 AS 运行等价通过。

## 收益判断与基准安排

旧密集样本中 `probeOptional` 出现于主侧 139/2045（6.8%）、加入侧 40/1373（2.9%）的调用栈，但其中包括单位快照、场景属性、显示对象等；**不能把这些全部当成这27字段可省的开销**。主侧确有 observeWeapon、captureMotion、EnergyImpactVisuals 等相关栈；加入侧主要是其他路径。推测只会改善一小部分主侧采集分配，不能解决整体密集卡顿，更不能先报百分比。

未来有独占窗口时，按测试登记执行：

1. 先重新运行 `prepare.py` 与 `audit_native_slots.py`，核对冻结基线和宿主指纹；把组件复制到新 build/m52 子目录，保持此提案与冻结候选分离。
2. AIR 编译使用 `components` 为 source-path、`ProbeFastChecks.as` 为文档类；唯一 AIR ID、隐藏桌面、独立存储，沿现有小组件登记和内存规则。先跑功能，读取独立存储的 result.json。两个负例单独编译并核对指定诊断。任何真实字段语义差异即停止。
3. 只有组件工作目录放置 `benchmark-enabled.txt` 才启用基准。六组：新原生字段、旧快速字段、普通/显示对象路径、Proxy、未命中 Pt、混合夹具。每组先预热，再做六轮 AB/BA、每路60,000次读取；分配采样另做20,000次。Proxy 的基准关闭夹具访问日志，避免数组记录掩盖真实成本。混合比例只是夹具，明确不冒充真实游戏权重。
4. 分开报告耗时与分配；检查未命中 Pt 和所有旧快速路径是否回退。只有命中路径获益、混合和反例路径净收益稳定大于噪声，才值得构建全候选。微基准通过仍须无 sampler 的原生同场景 AB/BA，保留画面、命中和原生字段等价。

如果收益落在噪声内或其他 Pt 路径回退，就不合并这14行左右的生产改动。当前先保留候选和可检验方案，不因此延后主会话已有功能验收，也不扩大成全局探测重写。
