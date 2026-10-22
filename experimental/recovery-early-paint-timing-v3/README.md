# 绘制计时诊断 v3

仅隔离诊断源。准确宿主仍为 2D415D…DD29，只导入 Grafon，不部署。v1 编译失败、v2 编译后被拒的所有源与回执均保持不动。

v2 的真实 P-code 在 observer 异常路径丢失 finally 分支选择值；因此 `build/m52/recovery-early-paint-host-02` **不可运行**。拒绝证据在 `build/m52/recovery-early-paint-host-recheck-02/receipt.json`。本版不使用 finally：原生 preload/upcoming 以 if/else 执行且 try 内没有 return；catch 用独立 Boolean 保存是否失败，并用 `*` 保存原始异常值；外部观察器独立 try/catch 完成后，按 Boolean 决定是否重抛原值。这也覆盖 `throw null` 和 `throw undefined`，不把异常值本身当真假条件。

原 waiting/fully-resident 两个提前 return、订阅槽、时钟边界、21 个回调字段、对象身份和外部 32 条缓冲契约不变。无订阅仍不执行显式对象/Date 分配；额外局部变量与异常路径结构存在诊断开销，不能声称零开销。两个旧水循环的合法输入还原完整继承 v2 的准确 ACC 来源证明。

`check.py` 只允许 sceneEnsure 的 15 个明确局部声明提升（初始化赋值留原位置）及 21 个回调对象键加引号；不允许任意变量改名、语句重排或忽略异常表。其他方法/字段外壳/资源核查不变。保留原 `flash.utils.*`，未新增显式 import：Multiname 与未改原调用逐字对照仅是结构证据，**真正的绑定作用域与 catch/rethrow 控制流仍需对实际 host03 独立审核**，构建回执保持 validated=false。

源准备 SHA：`eb487597d89073d61e1dffc7789c46130379c45276a9fde5f180008d87e0f960`。

根会话可串行执行（本子代理未执行 JVM/AIR）：

```text
experimental/recovery-early-paint-timing-v3/build_host.py build/m52/recovery-early-paint-host-03 --build --registry-wait 900
```

沿用已有 Python `-B -X utf8`。不带 --build 只准备新输出；共享登记、内存保护、22 项安装冻结、原方法/代表类/类表/非代码资源核对均沿用 v2。`handoff.json` 是最终冻结入口，`source-check.json` 仅为离线检查，不代替真实编译回读和实际运行。
