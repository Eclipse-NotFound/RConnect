# 普通墙面宿主：只移植两处 Location 方法

2026-10-23。此目录只准备离线移植与核验工具；没有运行 JVM、AIR 或部署。
`build_final.py` 由独立编排代理维护；`method_transplant.py` 由本审查代理维护。

## 为什么采用此路线

host03 的整类 import 实际把未修改 `createObj` 的 `@id == id` 编成了两次读取本地 `id` 的恒真比较，严格审计已拒绝。失败产物、原审计与 host01/02 的失败不改写。
先从 ACC 仅 import Grafon 得到 host04，再将新供体的 `Location.hitTile`、`Location.dieTile` 方法体放回 host04 的原表位置。Grafon 与 Location 共用同一个 ABC，不能整块使用 host03 的 ABC。

host03 donor 与 host04 的常量前缀确实不相容（字符串首差 8125，多名称首差 9639），因此已放弃该供体。由 host04 再仅 import Location 产生的 `location-donor-01` 已逐项通过全部 10 种常量池前缀检查。

## 精确输入与改动范围

- host04 `grafon-only.swf`：`9b3622541784fdab1104a2fd01b9858e94297388b5df102d50f62e8dba2f913f`
- host04 `grafon-only.xml`：`51a6730dd22edddbf83fb87d69b071e0e4931ff85c892b0ad704b7de47f61011`
- location-donor-01 `donor.xml`：`01b1d3341c4066ab6f52f6b288dc374b428a026f8bedde0eee4beb6947597a59`
- helper：`c422c540490d553e6a21415b9cdb4232f287069b4b1f18a075e51d224a59268e`
- 唯一非标准库依赖：只读 `ContinuousScene/build/native-crop-audit.py`，`ac4383a6fa899ee62caa54282ae6f31e5ddb83cebabfc65a920ea5954f0f46de`。`dependencies()` 返回自身与该文件的绝对路径及指纹。

仅把目标完整方法体复制到原 index234、235（包括所有指令、分支字节偏移、执行帧、activation 六槽、异常表），把 index234 的 flags 从 8 改为 10。其余 method_info、body、instance/class/script 表、构造器、旧常量前缀逐项保持。原 debug 方法名也不换为供体名字。新增常量仅附加：字符串 72、namespace 2、namespace set 1、multiname 140。

两个目标的实际指令、局部槽、异常信息只引用旧 namespace 的直接 QName，没有 private 或 namespace set 操作数。因此此工具**不实现也不猜测私有命名空间映射**；发现不同形状即拒绝。新增供体 private 常量虽随池附加，但目标不引用，旧 body 也不改索引。`newfunction/callstatic/newclass/callmethod/getouterscope/global-slot` 一律拒绝。

## 三个接口

```python
retain(base_xml, donor_xml, out_xml)
audit(base_xml, final_xml, retained_xml=None)
splice(base_swf, serialized_swf, out_swf)
```

均成功返回可 JSON 序列化的 `passed: true`，失败抛异常。输出只能是 `RConnect/build/m52` 内的新文件，不覆盖已有结果。`retain` 锁定上面两个 XML；`audit` 除了检查完整旧内容，还锁定新目标的准确完整 body 与追加常量；正式编排必须传第 3 参数，核验序列化后的 ABC 与 retained XML 一致。`splice` 仅取第 0 个 ABC（原始 tag332），原宿主的其它所有 tag 含资源、帧头、第二 ABC 原始字节保留。拼接后必须重新导出 XML 再运行 audit；工具返回 `runtimeValidated: false`，不授予游戏运行资格。

## 已完成的只读自检

已用上述真实新供体检查：全部常量前缀、两个完整 body 指纹、flags/frame、六 activation 槽和单一 catch、原参数与可选值、桥声明及调用参数数量（Prepare=2、Pending=3、tileDie=3），均通过。尚未由本代理调用 retain 写入，也没有序列化或运行游戏。

`hitTile` 新 init_scope_depth=5、max_scope_depth=10，旧值为4/7。没有擅自把5改成4：ACC 原生同一 Location script/newclass 中，非 activation 方法为 init4，而 createObj/buildLoc/stepInvis/step 已是 init5。两版 script 指令相同。Adobe AVM 实现读取这两个字段后保存其差值作为方法局部 scope 容量，实际捕获链取自 declaringScope；此证据解释为何不必改变类脚本。[MethodInfo.cpp](https://raw.githubusercontent.com/adobe/avmplus/master/core/MethodInfo.cpp)（648–651）、[Verifier.cpp](https://raw.githubusercontent.com/adobe/avmplus/master/core/Verifier.cpp)（1253–1271）。这仍不替代最终 AIR 字节码校验、catch 路径及真实墙面像素验证。

## 后续资格

根负责按登记串行运行 `build_final.py`；最终必须保留全部未改方法、资源、loader/World 等回读，核验真实 pcode 绑定与异常控制流，再进入准确原生像素测试。此处的成功不表示普通墙沿缺点、结构破坏、重访或性能已经通过。
