# 蒙版单方法修正：可编译供体源码入口

原 host01 编译失败已保留：其供体来自反编译回读文件，含 `§§findproperty`，不能作为 FFDec 导入源；另有沙箱拒绝 JPEXS 日志写入。没有候选产物或安装变化。

本入口默认准备 `build/m52/recovery-ordinary-mask-host-02`。供体改为已成功编译的 `recovery-ordinary-wall-sv-host-v2/src/fe/graph/Grafon.as`，严格 SHA `dd6299fb…15a085`。仅追加同样十一类名单，其余源码逐字符保持。仍从准确 host05 SWF 编译供体，最终只取 `ordinaryMaskBounds`。

复用原冻结 `single_method.py`（C84E369C…C0CBE4），不复制或修改。原帧、原几何尾段、private 绑定、全部非目标方法、常量前缀、原始资源和双次序列化回读审计保持。最终源码比较仍以 host05 的反编译方法形状为基准只增加名单，不能拿供体里的 for/while 格式差别放宽检查。

准备/验证不运行 Java；只有根会话执行 `--build`。共享登记、内存保护、唯一输出、失败保留及结果 schema 与 v1 相同，`validated` 始终为 false。独立准入和原生房间/像素测试待后续进行。
