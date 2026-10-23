# 原生蒙版名单修正：执行记录

2026-10-23。首因及49项真实资源核对见 `../recovery-ordinary-wall-room-failure/MASK-REVIEW.md`。

首轮 `build/m52/recovery-ordinary-mask-host-01` 实际调用JVM后失败：沙箱拒绝JPEXS自身日志目录，且作为输入的反编译Grafon包含工具不支持的 `§§findproperty` 语法。JVM退出1并回收，compiled=false，源码及22项安装未变。原始stderr、build.json和供体输入完整保留，不重写为成功。

第二轮改用此前已成功编译的精确native-v2源码（DD6299FB…15A085）生成供体，只追加11个审核过的Class比较。仍仅取供体的ordinaryMaskBounds，最终实际几何尾段须与host05相同；其他方法、所有类声明和原资源保留。反编译回读与host05原目标加名单的预期比较，避免把for→while的正常反编译形式当成源码更改。

`build/m52/recovery-ordinary-mask-host-02` 已实际完成8次JVM，均退出0并回收，最终SWF `6616b1a5d90e541980954ea8831949c5c5f72e945ef8378275567b9ade40289b`。准确方法体仅一处改变，5,788个其他方法体、全部method_info、类/traits/scripts和原常量前缀保持；5,038个非目标原始tag和第二个ABC保持。目标flags=0、scope=4/5、regs=12、stack=5；三个private方法和两个namespace-set引用在真实供体中均复用原身份，几何尾段一致，17个列明类接受、未知类仍拒绝。

根已回读最终AS、method-audit、splice和完整build回执，确认与单纯追加名单一致。`root-review.json` 和 `runtime-admission.json` 仅授予新宿主的隔离原生测试资格，未声称游戏或性能通过。新的原room/pixel适配 `recovery-ordinary-mask-native/run_native.py --check` 已通过，实际绑定准确C6A3产品、6616宿主和当前EB365/BEFC正式22项安装。未修改旧绑定或错误判据，没有部署；先运行原BF6房间场景。
