# 原生防御字段快捷表补齐：隔离候选

2026-10-22。当前仅源码和静态核对。**没有编译、AIR实跑、性能通过或安装变更。** 使用 remains-auto-testing 既有组件入口；不创建新运行器。

## 实际候选

唯一生产覆盖：`src/rconnect/game/GameBridge.as`，准确18源SHA `3fe9bb83a16a57300e733806cddbe74ce55bcaf323bec15554814f4714eba967` → 候选 `a1d12650073d1f57736f80323a0403a6e04f9ea91fb31767dacc499e8e5724bb`。

差异仅在原NATIVE_UNIT_FIELDS表追加18个已核验的公共变量，详见 `proposal.patch`。probe、probeOptional、unitFields、readUnitsSnapshot及readEnemyMotion方法正文全部原样；没有第二张运行时白名单、跨帧缓存、新参数、采集提前、输出复用、同步频率或异常处理变化。每字段仍判原生类型；确定的字段省去后续两次成员存在性检查及保护读取的activation。

**不要用这个整类覆盖已包含其它修改的20或活动源。** 根会话应只合入已审阅的表项差异，再核对其它方法没有被覆盖。本目录不修改或重建这些候选。

读取准确BEFC宿主的既有audit_native_slots.inspect_swf，纯只读stdout已再次确认：22个defense字段均为空公共namespace（kind22）、trait kind0变量，Unit继承fe::Obj；类型为13 Number、4 Boolean、3 int、1 Array、1 Object。具体类型和二进制SHA记录于 `extraction.json`。此次没有改变生产SWC声明，所有运行时访问仍使用原Object动态属性路径。

## 为什么不采用一次判类型的草稿

MirrorHitUnit.DEFENSE是public const Array：引用固定但内容可变。先前草稿给整组启用直接读取，会使第三方追加的未知getter失去旧逐字段容错。它已放弃；补丁、提取指纹及75项计划的静态记录保留在 `draft-rejected-single-type/`，未曾编译或运行，不属于有效组件输入。

现候选只对已核实变量快捷读取。后来追加的缺失字段、可抛错getter、动态扩展字段继续走原probe规则。真实Unit的继承public var不能被普通AS子类替换为同名getter；非Unit的同名getter、Proxy或其它加载域中不属于当前Unit的对象，都不会命中这个表。

## 组件与边界

`components/defensecheck/DefenseBefore.as`、`DefenseAfter.as`包含准确旧新probe、probeOptional、unitFields完整函数及各自三张真实表；包装器仅暴露调用入口，不改实际函数。NativeRoomState.numbers也逐字提取。`components/fe/`是明确的槽位/继承替身：字段名和类型绑定上述核验，只运行读值语义，不加载游戏、不运行构造器或其它模组。

预计 **81项运行断言**（不是已通过）：basic32、edgeValues10、fallbacks18、ordering7、otherGroups4、mutableNames6、verifyBench4。覆盖：

- 22项存在性、声明类型与旧新枚举顺序，真实Unit式公共槽、动态Unit子类；
- null/undefined省略，false/0保留，NaN、正负Infinity、负零不清洗；
- vulner数值转换和稀疏数组，opt数组浅复制、普通Object引用、每次新输出与旧快照不被后续修改；
- 非Unit getter异常/undefined仍只跳过当前字段；Proxy的has/get次序、missing/has抛错/get抛错/undefined五类；Pt而非Unit的同名getter；
- vulner元素valueOf修改后续dexter和opt：下一字段必须在当前转换后才读；转换抛错仍向外传播，不能提前读取或吞掉；
- 非defense字段组、XMLList levit_max转换、可选扩展字段仍用原逻辑；
- 公开FIELDS追加extension、failingExtension、absent、extra：包括未知getter副作用、单次执行、抛错、缺失和动态值；测试末恢复原22项。

这里没有试图通过代理观察真实原生slot的读取本身：顺序由完整函数提取、Proxy独立22项读取序列、以及真实槽valueOf修改后续字段这三种证据组合约束。仍不代替完整游戏与第三方模组实测。

## 成本测量与执行

组件按ENTER_FRAME分阶段执行；功能检查后先各路径暖身1000次，再完整 **A1→B1→B2→A2**。每次测20000次真实防御组采集，另10000次普通对象回退采集；计时循环只有完整capture调用和保留末输出，不含准备、断言、日志、JSON或采样器。两路径都保留每次输出对象与数组转换的原分配。

只测一个ABBA块、服从既有60秒总期限。benchmarks逐条保留毫秒，无硬编码性能通过阈值；数值小于计时粒度、两次新路径不一致或回退退化，都不足以推进。没有清楚局部收益则停止，不靠再扩缓存或减少工作量追结果。即使局部有收益也不赋予整机性能资格。

根会话运行，工作目录`mods/RConnect`：

```powershell
python -B -X utf8 tools/validation/run_recovery_component.py --source experimental/recovery-unit-defense-read/components --entry DefenseReadChecks.as --output build/m52/recovery-unit-defense-component-01 --expected 81 --registry-wait 900
```

`python`替换为本机解释器。原入口负责共享game登记、独立AppID、后台桌面、内存限制、仅清自己进程、源/安装指纹和每项断言核验。不要复用已有输出目录或降低期限。

当前纯Python静态核对49项通过，核对整类唯一表差异、旧新完整方法、22字段顺序/类型、81项运行计划及计时范围；结果在 `static-checks.json`。完整文本输入SHA见 `source-manifest.json`。准备/静态脚本仅生成和核对AS/文本，不编译、启动或复制二进制；交付后不要在根会话冻结/运行期间重跑生成器。
