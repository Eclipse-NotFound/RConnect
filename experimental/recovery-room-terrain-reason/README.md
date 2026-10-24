# 首次大图画面不可复用原因：隔离源码提案

仅诊断，不是生产修复，不授性能资格；未编译、未运行 AIR。准确基底为 build/m52/recovery-room-production-05（0.2.24-roomfix5），SWF SHA 78c052aea963f1689b705ae1e14d274916ae1a1f7e81933390caf8d1a88f4699。prepare/run 仅薄接已有有界编译器与原三程场景驱动，不复制测试框架；使用说明见 ENTRY.md。

## 插入范围与原语义

只有 RoomTerrainView、GameBridge 两类。首次实际 restore 的 loc 尺寸超过原生 World.cellsX/cellsY，且 applicationID 以 pfe-modsettings-rconnect-coop- 开头时，每个进程只 arm 一次。没有配置、网络内容、新日志行、额外 checkpoint、额外 tileInputs/fields/colors 扫描；静默窗口及其他恢复刺激不变。完成时只在原 RConnectRoomTiming restore JSON 上附 terrainReuseReason。

原 constructor/unchanged 的复合条件与短路顺序不改；失败 return 前才记录。same() 仍按原数组顺序比较，直接取实际首个 !== 的既有数组值；没有为了找原因再运行 tileInputs。每格只更新几个静态诊断上下文字段，无逐格日志/持有整图副本。复合入口条件拒绝后，为标明具体字段，仅在拒绝分支内按原顺序回读这些原生数据字段；不调用 setter/世界回调。无法在同一失败分支复核到原因则标 fault，不编造字段。所有恢复、门操作、布尔返回、refresh/drawLoc 与异常传播路径保持原样；原 catch 仍吞原来会吞的异常，原未捕获异常仍传播。

仅首个原因保留：constructor 的 renderer/房间身份、尺寸范围、重建/重算标志、缺失 Tile 或异常；unchanged 的有效性/身份/尺寸/标志、style 首个字段、backdrop 数量/身份/首个字段、首个 tile 坐标和字段。doorPresent 对应原 t.door!=null，不能把它解释为门对象身份比较。对象身份失败以 matches 的布尔事实表示，不序列化世界对象；对象型值只记 typeof。字符串上限256，超出保留长度与前缀标记；非有限数显式编码。对象型异常仅记类型，不强行调用其 toString。

外部门禁的四个原短路 operand 逐项传入纯诊断函数，并原样返回实际 Boolean。admission.retained 对应 !retained，dirty 对应 !_terrain.dirty，incomingWallPaint 对应原传入墙痕为空，localWallPaint 对应原本地 checkpoint 为空；true 均表示允许继续。仅求值到首个 false，没有提前求值，没有额外 checkpoint 调用。首拒绝字段保留在 first，未执行的字段不出现。仅在原复用 if 紧前记录 reuseGuardDirty；false 表示当时无需进入重绘判断，不再保留重绘后的 finalDirty。紧靠 roomRole 前仅增加 timing.beforeRole，与原 timing.role 相减才是该函数段，不把原 role 总值叫 roomRole 独占耗时。

若原 restore 提前抛出异常，原错误照常，可能没有本次附加结果；不得把缺少结果认作通过。diagnostic 自身故障通过 faultCount/faults（最多4条）显式表示，任何 fault 使这份原因证据无资格。complete 只表示本次恢复到达原日志位置，performanceQualified 永远为 false；不能用本候选耗时作生产前后对照。

## 结果形状

附加字段 terrainReuseReason 含 schema、complete、performanceQualified、width/height、viewCreated、constructorValid、unchangedCalled、reused、admission、reuseGuardDirty、first、faultCount/faults。first 为 stage/field/expected/actual/x/y/index；无失败且复用成功时 first=null、reused=true。非首个符合条件的大图恢复不附加此字段。

## 精确源与可逆性

下表原 SHA 为磁盘真实字节；拟议 SHA 按各原文件原换行编码还原。生成时已逐项逆序撤销所有精确替换，核回原始字节完全相同：没有以删除任意语句、归一化正文或忽略错误来证明等价。剥离时删除带 TERRAIN-REASON 标记的新增块；其余无标记的行只撤销本 diff 中新增 diagnostic 调用和对应 return 大括号，保留原 if 表达式、循环、catch 与 i++。same() 的诊断、constructor/unchanged 的记录与上下文均在 diff 中可逐处审阅。

| 文件 | 原始 SHA256 | 提案 SHA256 | 精确替换数 | 原换行 |
|---|---|---|---:|---|
| rconnect/game/RoomTerrainView.as | a2eb59b8536414d26daa39a82c71c414009c5d4b29a7a24539e025d1b852877f | d97df7bd1482fc099194b650d7eebee581521ee575375ca9c6d7524bbaa6f0df | 14 | LF |
| rconnect/game/GameBridge.as | f7016bfd096ca3c88ea1214733117758b1998b579ec6f3ca9fc9332b605011a9 | be39fd4d4f94179d3e1632b8113c3c6e584c3486d65bc794315b9a3aca0a4fc3 | 6 | LF |

source.diff SHA256：`5a81d51f7552f0067e472b16ebbf466ef0569925bfea55ea56550c6ef4a3b49b`。它替代已审阅的17C13版本，新增仅四门禁值、复用 if 紧前 dirty 和 beforeRole 单计时；diagnosticBegin 末尾保留 ASC 需要的不可达 return false，不改变原路径。后续仅由根会话决定应用、构建与实际取证；不能仅凭静态可逆检查宣称 AS 编译或原生结果成功。

窄审修正：准确 product05 的外部声明没有静态 fe.World，故通过已有运行域的 getDefinitionByName("fe.World") 动态读取 cellsX/cellsY；不新增/修改 stub 或构建工具。动态类型解析失败时不启动诊断窗口，缺少本次附加结果按未取得诊断证据处理，不得当通过。此项只调整诊断限定条件，不改原游戏流程。
