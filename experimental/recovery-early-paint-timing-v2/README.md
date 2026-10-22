# 原生绘制计时桥 v2：仅还原两个旧匿名循环自增

v1 首次宿主编译 `build/m52/recovery-early-paint-host-01` 失败，未产生 SWF。错误是原 2D 宿主回读的 Grafon 已带有两处 `§§findproperty`，v1 漏掉了导入前的伪码检查。原冻结目录、原失败产物和回执全部保留；这里是独立 v2，不修改它们。

## 精确来源和还原范围

- 实际宿主基线仍是 2D415D…DD29。
- 2D 回读 Grafon 与 ACC `recovery-wall-surfaces-host-01/after/scripts/fe/graph/Grafon.as` **全文件字节相同**，SHA E6B414…B7A0。
- ACC 当时实际使用的 import 源 SHA `625db5c71c4319f4c942e581e039b7419dc070065dc3fb148e23003b715abb04`。
- 仅 `sceneDrawSteps` 的同一个匿名瓦片／水循环结尾有差异：ACC import 是 `j++;`、`i++;`；2D 回读把它们展开成取属性容器、Number加1、写回三条语句。
- 将这两个完整片段还原后，**整个 sceneDrawSteps 方法逐字等于 ACC import 的完整方法**。不是只比较循环尾，也没有更换全类或忽略方法内部。

i/j 都是外层显式声明的 `*` 局部变量，匿名函数中没有 `with`。两条自增语句的旧值未被使用；回读临时名 `_loc1_/_loc2_` 仅用于这两处。这里恢复当时确实已编译为同一回读结果的输入表达式，不推广为任意伪码或变量改名规则。

完整证明、原方法指纹和01失败回执指纹在 `prepared.json`；差异在 `water-loop-import-repair.patch`。修正后的导入源 SHA `3bdc70d8c81d7ca2cdda070cb16421e3d7b412bb34a54d6b7d4aae2446e7ad07`。与 v1 相比只改变这两个自增片段，原计时桥契约和 `sceneEnsure` 每个字节都保持。

## 准入和回读

导入前 `verify_source` 强制整个源不含任何 `§§`。基线、v1冻结文件、ACC实际import/after、两处完整片段和原完整方法都先核对；多一个伪码或改动即失败。

真实回读时，`sceneDrawSteps` 只接受两种完整方法的词法表示：准确ACC合法输入，或准确2D既有伪码输出。它们的全部循环体、作用域、变量和边界均参与比对；不接受新局部名、加数改变、另一目标属性或其他方法里的伪码。其余90个方法仍严格逐个核对，其中只有计时 `sceneEnsure` 按预期新源比较。字段外壳、代表类、资源与P-code时钟/异常后续审查不放宽。

实际 Python 离线检查已通过，确认91方法中89个导入文本完全未改，另一个为已证明的输入还原，一个为原计时修改；11个源反例、5个回读反例全部被拒。没有运行JVM/AIR。旧v1的“90方法不变”是它当时未还原伪码的来源事实，不套用为v2文本计数。

## 根会话入口

```text
experimental/recovery-early-paint-timing-v2/check.py --output experimental/recovery-early-paint-timing-v2/source-check.json
experimental/recovery-early-paint-timing-v2/build_host.py build/m52/recovery-early-paint-host-02 --build --registry-wait 900
```

使用既有 Python `-B -X utf8`。不带 `--build` 只准备全新输出，不启动JVM。共享登记、内存保护、22项安装/准确输入核对、只导入Grafon、仅诊断不部署均沿用v1。实际新finally的异常控制流仍待首个编译成功产物逐路核验，`validated=false / exception_semantics_review_required=true` 保持，不借此次还原绕过它。

外部缓冲器及契约说明仍见 `../recovery-early-paint-timing/README.md`。没有新增观察字段或扩大计时范围；外部驱动需在独立v2清单中绑定本目录最终源。
