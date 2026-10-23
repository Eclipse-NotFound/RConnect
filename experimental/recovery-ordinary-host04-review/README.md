# host04：ACC → 仅 Grafon 中间版的独立审查

日期：2026-10-23。只读取既有 XML/SWF 导出，运行本目录的 Python 比较；没有 JVM、AIR、构建候选或部署。本报告**不授予最终宿主、游玩或性能资格**。

## 结果

`evidence-final-static.json` 为收敛后的机读证据，`review.py` 为对应检查源码。

- ACC → Grafon-only：两个 ABC 共 **5,661 个非 Grafon 原方法体完整相同**，包括 codeBytes、调用帧、异常表及 activation traits；对应 method_info、所有非 Grafon 类结构和脚本表也保持原样。旧常量池全部前缀相同，只追加常量。
- Location 的 **75 个具名方法（含实例/静态初始化）**、完整方法体及类 traits 均保持原样，`createObj` 没有引入 host03 的重编译结果。
- Grafon 与已审 host03 供体：104 个具名方法中，89 个 body 原样相同，另 15 个解析常量引用后，其指令、分支、帧、异常表和 activation traits 等价。类布局对应一致。
- 24 个匿名方法明确属于 Grafon `sceneDrawSteps` 的 `newfunction` 引用链，其中有 4 个嵌套匿名方法。原/新两侧均扫描了所有方法的 method-index 引用，未发现其它类引用这些闭包。不能将它们简单归为“无名即可忽略”。它们在中间版与供体之间的实际 body 也相同。
- ABC 数量、非 Grafon 类/具名方法索引、完整脚本表均保持。新增加的 12 个方法全部属于 Grafon。

比较只忽略 FFDec XML 的 `bytes`、`fileOffset` 导出注释；未改 body 使用完整相等检查。Grafon 对供体的常量解析保留 namespace kind、URI、私有 namespace 的实际 index，以及命名空间集合顺序，未用“去掉 private”或“只比名字”的宽松规则。异常 `start/end/target` 端点按实际指令边界核对。

首轮 `evidence.json` 和中间 `evidence-resolved.json` 保留：首轮未将已追明的 Grafon 闭包归入所属类，且现成比较器对新字符串索引只作原始数字比较，因而记录 false。后续明确补充所有权链及完整常量解析，未修改输入。最终资格字段 `finalHostQualified`、`gameplayQualified` 均仍为 false。

## hitTile 的 init_scope_depth 4 → 5

这里没有发现必须把供体改回 4 的依据：

1. 实际 ACC、中间版、host03 的 Location 类脚本初始化代码为同一段 16 字节，`newclass` 仍指向类索引 14，作用域入栈顺序相同。ACC/中间版脚本 method index 为 266，供体为 3129；只是方法索引变动，捕获流程没有增加一层。
2. Adobe VM 的 `MethodInfo::_buildMethodSignature` 读取两个 depth 后仅将差值保存为本地作用域栈容量；已捕获的外层作用域另由类声明链维护。因此不能把 `init_scope_depth=5` 直接解读为“必须捕获五层”。见 [MethodInfo.cpp 643–655](https://github.com/adobe/avmplus/blob/master/core/MethodInfo.cpp#L643-L655)。
3. `getscopeobject` 的编号指向本地作用域，外层链由另一个 `getouterscope` 操作处理；异常入口会清空本地 scope。见 [Verifier.cpp 的 scope 操作](https://github.com/adobe/avmplus/blob/master/core/Verifier.cpp#L1915-L2024)及[异常入口](https://github.com/adobe/avmplus/blob/master/core/Verifier.cpp#L919-L943)。
4. 供体 hitTile 在入口依次压入 this、当前 activation，所以 `getscopeobject 1` 指向这次调用的 activation。唯一 catch 也重新压入这两者后建立单独 catch 对象；没有 `getouterscope` 指令。完整保留供体 init/max = 5/10、六个 activation 槽及 NEED_ACTIVATION 标记，有相应静态依据。

这项结论基于一手 VM 实现和本次真实指令，不借用旧 `Location.step` 用例替代证明，也不代表当前 AIR 已运行通过。最终新供体、移植结果及原生执行仍应分别验证。

## 固定输入

均位于 `build/m52/recovery-ordinary-wall-sv-host-04/`：

| 文件 | SHA-256 |
|---|---|
| `acc.xml` | `9b01992ac70cdfab2e2747230780720cb5e24b6d3450eb36e6e91a66a8af0998` |
| `grafon-only.xml` | `51a6730dd22edddbf83fb87d69b071e0e4931ff85c892b0ad704b7de47f61011` |
| `donor03.xml` | `4e47c6528fe7518585a5bde6bdea31229b001bb9ee549404c808577d9967ee82` |

新 `location-donor-01` 不在本次三个输入内；本报告没有把旧供体证据自动迁移给它。
