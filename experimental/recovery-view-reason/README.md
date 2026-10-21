# RoomTerrainView 首个失败原因：独立诊断

准确基线 `build/m52/recovery-11`，SWF `CD721F0E56679302747AB2C9E687E20BD877A1EE8F520D6D589C7C43FA64EBB5`。唯一覆盖 `rconnect/game/RoomTerrainView.as`，不改 GameBridge、其它生产类、驱动或安装版。

每个无效构造写一条；有效构造不写，unchanged 首个失败或全部成功写一条。若构造已经失败，随后 unchanged 的 !valid 不再重复写。记录 `RConnectViewReason`：构造/比较阶段、实例序号、本机 getTimer、宽高、identity/flags/bounds/style/backdrop/tile/exception、具体字段、期望/实际值、背景物索引或瓦片坐标。身份用相同/不同布尔值表示，不序列化对象；字段值来自本次原比较的数组，不重新读取 Tile/样式。字符串最多256字符；非有限值显式字符串；异常只标原捕获值类别。没有全图第二遍扫描或逐格日志。

插入的 guard 仅在原条件已为真时记录，并恒返回 true；原 OR 短路顺序、Tile数组构造与比较顺序、i++、异常捕获、返回和 refresh 不变。same 额外传递诊断上下文，无逐格额外数组/对象分配。全部插入有成对标记；去掉标记块后必须与11源码逐字节相同，生成器还必须能从11完全重现覆盖。这是静态代码完整性检查，不能替代实际AS行为验证。

只准备文本。离线核验：

```powershell
python -B -X utf8 experimental/recovery-view-reason/check.py
```

根会话串行登记编译/运行，必须使用全新 build/m52 目录：

```powershell
python -B -X utf8 experimental/recovery-view-reason/prepare.py --output build/m52/recovery-view-reason-diag-02 --build --registry-wait 900
python -B -X utf8 experimental/recovery-view-reason/run_native.py --candidate build/m52/recovery-view-reason-diag-02 --output build/m52/recovery-view-reason-native-01 --registry-wait 900
```

编译复用现有登记编译函数，前后22项安装审计；运行只适配已有 room-restore 独立入口的候选 audit、日志行采集和行完整性。scene12、E159宿主、600秒、独占AIR、内存、22输入、原驱动及原框架全部检查保留。原 `result.json` 字节不改，另存 framework-result/diagnostic-result；诊断结果的 passed/gameplay_qualified/performance_qualified 始终 false。沿用旧适配器的 `restore_rows_complete` 字段，此处指新日志的完整性：加入侧最后三个观察为240×125、48×25、240×125，宿主只capture时允许无观察。它只证明收到诊断，不证明重用应该通过，也不作加载性能资格。

根会话的 diag-01 实际编译失败、未启动 AIR：AS 将方法中的全限定 `rconnect.core.Log.d` / `flash.utils.getTimer` 识别为未定义属性。仅在未冻结覆盖中增加带剥离标记的显式 import，调用改用 `Log.d` / `getTimer`；离线12项包含准确导入检查，不冒充编译成功。diag-01 原始失败保留，下轮必须新建 diag-02。本代理没有编译或运行 JVM/AIR。
