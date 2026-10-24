# 原生加载显示：独立构建接线

仅接已冻结 `goal-native-loading-ui`（manifest A4792939），产品基底准确 roomfix5/78C052，宿主准确 A796。原源码、旧构建工具、release、其他模组都只读。本目录不包含游戏副本；`--check` 不启动编译器，也不复制 XML/SWF。

## 执行口

以下命令工作目录为 RConnect，仅由根执行真实构建：

```text
python experimental/goal-native-loading-build/build_product.py --check
python experimental/goal-native-loading-build/build_host.py --check
python experimental/goal-native-loading-build/build_product.py --build --output build/m52/goal-native-loading-product-01
python experimental/goal-native-loading-build/build_host.py --build --output build/m52/goal-native-loading-host-01
```

两入口均支持 `--prepare`（只冻结独立输出）、`--verify`（只读），以及 Python `verify(output)`。`--build` 是唯一启动 Java 的选项。已有输出/失败回执不可覆盖。编译前取得同一共享 game 登记；启动需 1 GiB 可提交余量，运行沿用原 512 MiB 保护、300 秒上限、隐藏进程及 finally 回收。没有 AIR 或部署代码。

产品只覆盖 RoomEntryView 与入口版本，完整复制准确 78C 源与其原构建工具，使用 v5 原来的 compc/mxmlc 两条受监控命令。当前真实 22 项仅在开始 prepare 时冻结，必须仍为 A796/78C；之后每次编译和结束均核其完全不变，其他模组不是假借历史安装表。

宿主复用 `recovery-room-first-raster-host-current/build.py` 原六步 import / donor XML / serialize / final XML / AS / P-code，以及原 raw-tag splice、ABC decoder、命名空间和 activation 溯源。原工具字节固定在 inputs.py；明确差分见 reused-tools.diff。只复制一份待导入 World 源，未预复制 92 MB 基底 XML 或 SWF。

## 精确保留边界

- resizeScreen、loadGame、ativateLoc、setLoadScreen、offLoadScreen、showScene、unshowScene、endgame：在**原 body 字节**前插 `getlocal0; callpropvoid private rconnectUiNativeDisplay,0`。
- newGame：原 body 前插 `getlocal0; pushtrue; callpropvoid private rconnectUiNativeDisplay,1`，保持已冻主菜单交入规则。
- 九个方法的原 flags、签名/可选参数、局部变量数量、scope 深度、activation traits 和全部原指令字节不采用 donor。只按所需峰值抬 max_stack；异常 start/end/target 同移前缀长度，其余字段与顺序不变。旧分支及 lookupswitch 原相对字节保留；跳旧入口不会重新执行前缀。
- exitStep 是唯一取 donor 的旧 body；method_info 仍要求与原版精确相同。七个新增助手复制完整方法 metadata/异常并核本地 activation/catch 槽位来源。新增六 slot 无显式初值；World 构造器、静态初始化器和所有非目标原方法逐字节保留。没有静态初始化器尾缀。
- 新 helper 使用精确规范化的 World 私有 QName；仅公开 rconnectLoadingView 与 faults 字段使用 public QName。八次无参调用依赖助手保留 optional Boolean false，另行硬核其 metadata。
- activation 溯源沿用原实现，只增加 newobject/throw/convert_u/coerce_s 的明确栈语义；未知 opcode、非本次 activation 或 catch 的 getslot/setslot 继续拒绝，不做宽免。

最终结构校验要求序列化后的实际 XML 与 retained XML 精确一致；其他 ABC、原类列表/脚本/trait/索引和资源原字节保持。产物回执 `compiled/build_checks_passed` 只表示结构性检查，`validated=false`、玩法/性能资格恒 false。**根必须再读实际 World 源/P-code，确认助手异常控制流及唯一 donor exitStep 语义后，才给予单独原生准入。** 九前缀的调用解析错误在 helper 自身 try 外，准确 private QName/默认参数证明不可省。

当前准备状态：未编译、未启动 AIR、未部署。本目录没有新增测试运行框架，沿用原 37 组件及原三程/普通分房/背景门验证。
