# 绘制计时 v2：匿名循环合法源还原的独立审查

结论：可以接受这一处精确还原，未发现 v2 源准备/回读允许集合中的阻断缺陷。它只解决诊断宿主重新导入失败；不证明新诊断已编译或异常控制流正确。未运行 JVM、AIR 或修改他人文件。

原失败 `build/m52/recovery-early-paint-host-01` 的导入日志指向 `§§findproperty`。它实际是 `sceneDrawSteps` 同一个匿名闭包内 j、i 的两组自增语句，并非两个新添的水循环。

独立核对使用的准确来源：

- ACC 实际 import `build/m52/recovery-wall-surfaces-host-01/import/fe/graph/Grafon.as`：`625db5c71c4319f4c942e581e039b7419dc070065dc3fb148e23003b715abb04`。
- ACC 实际 after 与2D实际 after 全文件逐字相等，均为 `e6b4142462c1187388c4bb9c8151dd6c2605ce4e4b9fedd421cf4749c54bd7a0`。
- 最终 v2 导入源：`3bdc70d8c81d7ca2cdda070cb16421e3d7b412bb34a54d6b7d4aae2446e7ad07`。

独立脚本提取整个 `sceneDrawSteps`，仅将两组完整的 `findproperty → Number(value)+1 → 写回` 还原成 ACC 原源的 `j++;` / `i++;`；还原后整个方法逐字等于 ACC 当时实际编译的输入，两个辅助临时名无剩余引用。i/j 是外层明确声明的 `*` 局部变量，没有 `with`，这两处自增旧值未被消费；闭包仍写回原捕获变量，不是新增局部变量。方法其余循环边界、瓦片访问和水体绘制均不变。

已审 v2 `prepare.py` / `check.py` / `build_host.py`：

- 先核对 v1 冻结清单，再核准确 ACC 源/宿主及完整方法指纹；只改该两个表达式的完整固定方法，不以去除任意伪码修补编译。
- 导入源禁止任何 `§§`。91方法中89方法导入文本不变，`sceneEnsure` 是诊断逻辑变化，`sceneDrawSteps` 独立列为导入还原，未将两种改动混称为只有一个文本变化。
- 回读只允许 `sceneDrawSteps` 等于完整 ACC 合法表示或完整2D既有伪码表示。其它方法和类外壳仍核对；该方法之外任何 `§§` 被拒绝。不是跳过整个方法。
- builder 绑定 v1 冻结文件、ACC 输入/产物/回读、旧01失败回执及失败日志；没有通过旧失败记录获得运行或性能资格。

本代理实际运行了只读 `check.py`（未提供输出文件）：源码检查通过，11个源变化负例及5个回读变化负例全部拒绝，包括错误步长、错误写回目标、闭包局部变量类型变化、循环体变化和其它位置伪码。

仍待首个实际产物的检查：新 getTimer/Date 的真实 P-code 绑定，以及 sceneEnsure 正常return/正常结束/绘制抛错三条路径经过 finally 后的异常对象保存与重抛。v2没有预先授予这项资格，原01失败及冻结源保持原样。
