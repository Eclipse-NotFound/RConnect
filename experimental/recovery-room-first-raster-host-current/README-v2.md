# 供体 02 的有界继续构建

2026-10-24。01 因 FFDec AppData 锁失败；02 的 import/export 两条 JVM 真正成功，但保留器拒绝尚未证明的 getslot/setslot。两轮结果与原脚本、原 source-manifest 都不改写。v2 仅增加本目录新文件，继续使用准确 A796 源补丁和 02 供体，不重新导入三类。

实际 13 个方法没有直接 method/class/global-slot/getouterscope 指令。World.step/exitStep 各两个 catch 槽访问；Grafon.sceneOpen 有 33 个 activation 与 2 个 catch 访问；drawLoc 有 202 个 activation 与 6 个 catch 访问，合计 247。`activation_slots.py` 遍历实际控制流与异常入口，跟踪操作数、局部寄存器及本地作用域的对象来源：仅本次 newactivation 的随 body 携带槽表，或本次 newcatch 的异常变量槽 1 可用；this、未知对象、越界槽、未支持指令均拒绝。异常入口清本地 scope，保留原局部变量。未知/不可达槽指令不能偷偷放行。

保留供体实际 frame 与 NEED_ACTIVATION。sceneOpen 新 init/max=5/10，两个无 activation 的 World helper 为 4/5；不与原 World.step 的 5 硬比，也不把供体 init 改成 4。旧 `recovery-ordinary-host04-review/README.md` 的 Adobe MethodInfo/Verifier 证据已说明：局部 scope 容量取 max-init，getscopeobject 指向本地 scope，外层 declaring scope 由原类/script 保持。此处仍需真实最终 AIR 校验，纯 Python 不能授运行资格。

Game.enterToCurLand 更窄处理：供体重新生成匿名 private 集合 165→183，故不复制其主体。原 659 字节仅取前 658 字节，在唯一末尾 return 前加入准确供体九指令 conditional constructed 尾部。原 277 条指令、20 个跳转（最大目标 646）、原 frame 原样；新 ifeq 在 662 跳 678，原 max_stack=6 覆盖新峰值 4，没有异常或 activation 区域。新尾部只绑定 public rconnectTravelBridge，避免引入 Game 新词法集合。其他七个现有方法、五个 helper 和原 cinit 字面量尾部沿原明确白名单。

`build_v2.py` 只读核实 02 原失败回执、原 source/import/tool 指纹及真实两条成功 JVM；03 的 `historical_donor` 明列它们，并保持 `original_result_passed=false`。03 自己只运行 serialize、final-xml、readback、pcode 四条 JVM，仍原登记、1 GiB 启动/512 MiB 运行、512 MiB JVM、300 秒、自有 PID 回收、22 安装不变。完整供体不复制第二份，只读引用 02；新产物只写新 output。`verify(output)` 区分历史供体与四条本轮命令，校验全部输入、产物、保留器/最终回读证明，不授实机/性能资格。

仅根执行，从 mods/RConnect：

```text
python -B -X utf8 experimental/recovery-room-first-raster-host-current/build_v2.py --check
python -B -X utf8 experimental/recovery-room-first-raster-host-current/build_v2.py --build --output build/m52/recovery-room-first-raster-host-current-03 --registry-wait 900
```

本次作者只做文本准备及实际供体的 Python 静态检查，没有启动 JVM/AIR，也没有生成或修改 SWF。
