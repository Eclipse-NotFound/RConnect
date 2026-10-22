# 武器插值第二结果数组：单点隔离实验

准确基线为 `build/m52/recovery-22`，实际候选 SWF 为 `746eef5713985f23fe13a57792516789bebd37a5e4142639ba8cc8b6590b3e93`。本目录只准备文本源码和组件，**尚未编译或运行 AIR，没有局部实测收益、整体帧率或部署资格**。不合入活动源，不修改任何已冻结候选。

唯一生产覆盖 `src/rconnect/game/RemoteMotion.as`；`proposal.patch` 是全部生产差异。只在 `blendWeapons` 内复用 `WeaponDisplay.interpolate` 已经新建的数组，顺序替换无 display 的兼容项；不再创建第二个 out 数组及逐项 push。现代项的实际对象不变，兼容项的浅复制、四键匹配、Number 转换、位置和角度插值逐字保留。没有缓存、延后求值、时钟改动、输入复用或频率变化。

## 等价边界

1. 准确22只有一个私有调用点，先判两端 `is Array`。因此不会进入 `WeaponDisplay.interpolate` 的 null 返回输入分支；它必然创建新的本地 Array，按原枚举顺序 push 出稠密索引。空数组同样返回新数组。结果未暴露给源对象或外部回调。
2. 有 display 且匹配的现代项和 display 仍由原插值方法分别复制，melee 仍引用后包。未匹配的现代项仍保留原对象。无 display 项仍复制自身，嵌套引用及原 melee 不变；同一源项出现两次时，原来独立的复制仍独立，原来共享的引用仍共享。
3. 改为索引循环只遍历这个原方法新建的稠密结果；原始 first/last 数组允许空、稀疏、重复和命名可枚举项，仍由未改动的原方法枚举和匹配。输入、body pose、sample、push、settle、传送、有限速率持有者、输出时刻均不变。
4. 不声称支持外部恶意修改 `Array.prototype` 增加可枚举武器项后旧方法的双重继承枚举怪癖。准确22所有源码无 prototype 写入，普通网络快照也不执行这种写入。本实验针对现有原生数组/快照契约，不增加每次原型扫描或新容错行为。若未来发现实际运行依赖这种全局改写，应停止此候选而不是扩大实现。
5. NaN、缺失值、null、负零及有限跨圈角度保留原运算。**不测试无限角差**：原 while 已可能永不结束，本任务既不输入这种值，也不顺带修输入校验。t 的原生公共入口仍钳到 0–1，私有适配器另外比较有限越界值和 NaN。

## 真实类组件

`components/rconnect/game/RemoteMotionBefore/After.as` 各包含完整旧、新生产类，仅全标识符改名并加可剥除的 `componentBlend` 入口；原方法和其它成员没有摘改。`WeaponDisplay.as` 为准确22完整原文件；两份 `TeleportVisualsBefore/After.as` 同样复制完整原类，改名指向对应真实 motion。`GameBridge`、`MeleeVisuals`、`Log` 是仅供编译的外壳，任何被误调用的方法直接抛错；组件只执行真实插值及真实传送 split，不执行武器显示树、近战、游戏或 TCP。

`materialize.py --check` 检查准确基线 SHA、反向恢复全部类字节、单一生产差异、调用守卫和预计断言数。**静态检查不是编译或运行通过。**

预计 **70 条运行断言**：现代显示10、旧格式10、容器/多槽位12、数值12、完整公共采样路径20、局部成本结果6。明确比较数值、字段枚举顺序、输出/输入身份、嵌套共享关系、重复对象、空/稀疏/命名数组、四键匹配及第一匹配优先。完整 actor/held/enemy/drop 路径比较每次 sourceTime、latestSampleTime、latestPosition、currentSample 和结果；含零时间重复、暂停 settle/恢复、retainRate、同戳更新/旧包、原生传送 split、未标时及 null/non-Array 调用守卫。

这不会证明真实高密度场景、物品平滑或枪口/弹道最终像素；那些已有失败不变。

## 小成本实验和停止条件

功能检查后，仅在本组件中双方各100次准备；随后各有4武器的 modern / compatibility / mixed 输入分别做 **A1 → B1 → B2 → A2**，每块12,000次实际完整 blend。各块分到 ENTER_FRAME 步骤，计时循环仅调用真实方法并保留末结果；断言、序列化、输入检查、文件写入均在计时外。不会请求 GC，也不将某一时刻内存差当精确分配数。

源码只能证明每次有效 blend 少分配一个结果 Array 和省去一轮 push，**不能从现有CPU样本换算收益**。毫秒逐条保留，不设置“新版必须更快”的假断言。小于计时分辨率、ABBA不一致或局部微不足道即停止，不再延后姿态求值、扩大缓存或加其它微优化。即使局部有明确收益，仍须准确输入的实际密集对照，之后才考虑合入。

根会话唯一执行，工作目录 `mods/RConnect`：

```powershell
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/recovery-weapon-container/materialize.py --check
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 tools/validation/run_recovery_component.py --source experimental/recovery-weapon-container/components --entry WeaponContainerChecks.as --output build/m52/recovery-weapon-container-component-01 --expected 70 --registry-wait 900
```

复用原组件入口的共享game登记、唯一AppID、隐藏桌面、1 GiB启动/512 MiB终止、60秒总执行期限、自有进程清理、完整安装与源前后指纹核验。不添加运行器，不改变旧阈值，不在本目录运行编译或 AIR。完整文本清单在 `inputs.json`。
