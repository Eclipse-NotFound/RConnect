# 高速弹体只读归因副本

本目录只回答三个具体问题：首发已收到轨迹却晚约半秒显示时，真实显示时钟在哪里；140 ms 的整帧空档落在哪一段；墙面相同输入为何反复解码。**它不是性能候选，不得部署，不得以它的耗时宣称优化通过。** 没有启动 JVM/AIR，没有编译或实机通过记录。

准确基线为冻结 `build/m52/recovery-05/src`，二进制 SHA-256 `bf15665a7457eb5997009b45717524512a6622bd8efccc7388e269f14ab045ae`，版本仍 `0.2.24-recovery5`。不是 recovery-06，也不包含父会话正在制作的默认关闭 RoomCodec 诊断日志修正。两者的 RoomCodec 覆盖**不能直接叠加**；本副本特意保留 05 原来的同步日志费用。

原驱动固定为 `build/m52/recovery-drivers-09/tests/NativeFlightContinuityTestDoc.as`，SHA `e530e573a67a4e0ed6c5d231be9c134806de999b677adf5b4c1bae12ff26c5bf`。相同的 8 轮轻机枪、速射枪、速射等离子和天角兽移动闪电、真实背包装备、首次开火准备时间、各轮期限、全部原生接触/像素/运动/85 ms 判据均保留。没有预热、扩大地形修改、跳过首发、延长预测或弹体寿命。

## 已有接口与最小插点

- `GameBridge.presentationTiming` 已有公开计时槽，复用其中 `viewMs/viewCalls/motionMs/motionCalls`，不改 GameBridge。只在原值为 null 时绑定自己的对象，结束时确认身份再恢复；被其它观察器占用则记录诊断不完整，不能抢占。
- `RemoteMotion.sourceTime/latestSampleTime` 是无副作用的读取接口，直接读取。不额外调用 `sample/settle`，不改变游标。私有 `offset/sampledAt/arrivedAt/delay/frames` 无公开读取接口，因此只在原函数中加观察点。
- `ProjectileFrameStream.receiveClock` 记录传入及实际采用的 offset、delay、motion 关联、首收时间与 detach/shift，保留原逻辑。`sourceTime()` 不增加逐次钩子，实际被 tickBeam 使用的 time 由其调用点记录，减少重复插点。
- `ProjectileVisuals` 记录实际 owner 对象身份、player 标记、武器流、真实帧范围及 end；每次原 tick 的参数时刻和真实 getTimer 分开记。tickBeam 原选择执行前记录等待/结束决定，实际位置写完后另记一次。移除前只读观察，不改变移除条件。
- `WallImpactVisuals` 缓存命中只加计数；miss/保护像素直接 unpack 的完成时长、FIFO 淘汰原因保留有界行。每 250 ms 最多一份累计摘要（换轮/结束额外封口）。记录原始 payload 文本的有界身份与字符数，结束后导出原文，可离线按 SHA 去重和解码，热路径不编码、不压缩、不算 hash。
- `RoomCodec` 两行原来的 `Log.d` 原样保留；只在每行前后读时钟，分开“日志前编解码”“第一行同步日志”“第二行字符串化与同步日志”。实际 Log.d 包含 open/write/close，观测的是整段日志调用成本，不能拆成纯磁盘时间。第二行前的原 `timing` 赋值仍在两段之外。

## 目录与构建接法

`src/` 是 5 个既有类的稀疏覆盖，加一个 `rconnect.diagnostics.FlightDiagnostics`；`tests/` 是原驱动的诊断副本及独立记录器。`make_overlay.py` 只生成本目录覆盖并写 `inputs.json`，绝不运行编译器。它先核验整个冻结 05 源清单和二进制；删除每个 `FLIGHT_DIAGNOSTIC_BEGIN/END` 标记段后，5 个类与原驱动必须逐字符还原基线（仅统一 CRLF/LF）。不是只核对断言数量。

统一会话使用**新的隔离构建目录**复制准确 05 源树，再应用本 `src/`；原 `RConnectMod.as` 和版本字符串不变。按已有登记构建配方编译这个准确副本，并从这个副本重新生成 `ProductionDeclarations.swc`，其中必须包括新 FlightDiagnostics 类。测试驱动只使用本 `tests/` 的两个 AS 文件、准确副本声明 SWC、原 GameCombatStubs.swc；生产声明必须是 external-library，不能将另一个 RConnectMod/FlightDiagnostics 编入外部驱动。Harness 可复用冻结 09 的同字节产物。

不要让通用 prepare 从旧 continuity-extra 模板覆盖本驱动，不改其 prepare.py/run.py，不改冻结目录。`driver-input.json` 须绑定新诊断候选 SHA、诊断驱动和 Harness SHA、本目录输入清单 SHA，标 `diagnostic_only=true/performance_qualified=false`。它依赖新增只读接口，**不能把同一驱动直接绑定到 574D 或原 05 二进制**。对照仍使用原 09 驱动字节与原候选。

运行仍由统一会话使用现有 run_coop_regression：全模组、独立桌面、defer-visible、wait-host-world、require-exclusive-air、唯一 AppID、共享 game 登记、双侧原有 6 GiB 启动/512 MiB 终止门槛、自有进程清理和安装前后完整 22 指纹。不因诊断减少门槛或绕过登记；本目录没有新的启动器。

本目录独立 `prepare.py` 已实现上述冻结和编译接法，仍未执行冻结或编译。只接受新的 `build/m52` 直接子目录：

```text
<Python> -B -X utf8 experimental/recovery-flight-diagnostics/prepare.py --output build/m52/<新诊断目录>
<Python> -B -X utf8 experimental/recovery-flight-diagnostics/prepare.py --output build/m52/<同一待编目录> --build --registry-wait 900
```

第一条只冻结源和输入；也可新目录单次加 `--build`。只有 `--build` 才申请共享 game 并启动 JVM；严格复用冻结05的 `tools/build_mod.py`，其 MOD_ROOT 只解析到新目录，空 release 子目录也只建在隔离目录。随后复用既有 compc 声明生成方式、external-library 驱动编译和 09 同字节 Harness。不会调用 AIR。编译前（含等待登记后）与编译后核对所有冻结/原始输入，失败产物和 compile.log 不会被重编覆盖。

`prepared.json` 与同字节 `meta.json` 保存全输入 SHA、准确05/覆盖清单、工具链路径和 `diagnostic_only`；成功后加候选、声明、存根、驱动、Harness、编译日志/指令的 SHA。`drivers/NativeFlightContinuityTestDoc/driver-input.json` 绑定实际诊断候选/驱动和同一全输入表。保持 version 为 recovery5，不伪装性能候选。通用 prepare/run 未改；主会话以此 driver 目录交现有 run_coop_regression，再照常做独立运行前后22指纹和所有模组日志审核。

## 有界记录与方法差异

默认 `FlightDiagnostics.sink=null`。记录器只在原驱动 setup 绑定；它既不接收/发送新的测试网络包，也不改变已有 driver 的包顺序。热路径为固定 Vector 数字写入、计数和受限身份/不可变字符串索引，不生成逐事件 Array/Object，不写文件、截图、JSON 或日志。原有驱动的两次像素探针和原 05 的日志仍存在。

- 数字记录上限 131072 行，每行 24 个 Number，预分配 24 MiB/侧；对象身份最多 8192 个，采用弱引用字典。
- 名称最多 256 个；payload 最多 2048 个且累计最多 2097152 UTF-16 字符（原压缩输入是 ASCII），保留引用，不复制解压数组。另有 20480 个累计数字计数。
- setup 中这项一次性分配会扰动内存/启动，观察点和 getTimer 也有开销。帧阶段观察自身成本属于诊断时间，不能从原失败中扣掉再判通过。
- 任意容量溢出、钩子抛错、时钟槽争用、未完成 unpack 都令 `complete=false`；不是丢掉超额样本仍报告完整。原生异常仍由原测试的错误处理登记，不在诊断层吞掉原生错误。
- 全部原操作与最后清理结束后才导出 `FLIGHT DIAG HEADER/ROWS/PAYLOAD/DONE`。有界分块 JSON 只在 finish 生成。外层必须收全两侧日志和 DONE；进程被取消或导出截断会被离线分析拒绝。此时原 COOP DONE 尚未写，不能提前清理。

事件顺序分段：ENTER_FRAME `2147483647 → 89999 → -1 → -6001 → -10001`，RENDER `2147483647 → -10001 → -2147483648`。末段在原驱动最终取样 `-2147483647` 之后，因此涵盖像素探针开销。阶段之间还可能有其它模组，**只可归因为这个区间，不能自动归因为某个函数**；`presentationTiming` 是已有函数计时的交叉证据。Socket/Timer 回调会继承最近阶段标记，RENDER 末尾改为 9 表示帧间事件，不等于内核收包时刻。

## 导出数据字段

每行固定公共前缀 `[kind, 本机getTimer, 连续ENTER_FRAME号, 阶段, case, 连续RENDER号]`；其后最多 18 个数字。未用/非有限数字 JSON 输出 null，布尔用明确 0/1。

| kind | 后续字段，依次排列 |
|---|---|
| 1 motion | motionId, op(1 push前/2接受后/3原sample游标计算后), now参数, cursor, offset, 本次stamp, sampledAt, arrivedAt, 帧数, 实际delay, interval, 策略位(immediate=1/enemy=2/bufferLimit=4), wanted, rate, 旧state.x/y, 最新已收stamp |
| 2 clock | recordId, motionId, op(1 receive/2 detach/3 shift), now参数(-1=shift无此参数), 实际offset, delay, clockAt, detachedOffset, 当前motion游标, 最新motion样本, 传入offset(receive) |
| 3 receive | recordId, ownerId, motionId, player(0=敌人/1=玩家), 枪样本stamp, seq, cls名称索引, 武器流名称索引, 合并后帧数, 首stamp, 末stamp, end |
| 4 display | recordId, tick参数now, 实际使用的sourceTime, reason(0等待首帧/1准备画/2原end/3原15秒超时/4坐标已写/5原remove), 首stamp, 末stamp, 帧数, end, vis.x/y/f, 是否有vis, motionId, motion游标 |
| 5 tick | tick参数now, active数, pauseAt |
| 6 wall累计 | hit, miss, remember, evict, protected开始, reset, miss结束, protected结束, miss耗时和最大值, protected耗时和最大值, cache项/word/字符数, 已登记payload数/总字符 |
| 7 wall事件 | wallId, op(4淘汰/8miss unpack结束/9protected unpack结束), payloadId, 字符数, unpack整段耗时, cache项/word/字符数, detail(淘汰限制位1项数/2word/4字符；解码为word数) |
| 8 codec | op(1pack/2unpack), 开始, 第一日志前, 第一日志后, 第二日志前, 第二日志后, 压缩字符数, ByteArray当前长度 |
| 9 phase | 已有viewMs/viewCalls/motionMs/motionCalls累计值 |
| 10 marker | 0setup(+Date时钟锚)/1case开始(+编号)/2原驱动phase(+名称索引) |

payload 原文另行导出，`counts[op-1]` 对应 Wall op 1/2/3/4/5/7/8/9（未使用的 6 为零），最后一项累计 unpack 毫秒。cache hit 的 concat 仍会花时间，但本次不为每次 hit 加成对计时；区间成本保留。motion 行 op1 里的 stamp 是本次输入；最新已收 stamp 单列，故能辨认旧包/同 stamp 重复包没有走 op2。op3 的 x/y 是更新坐标前旧 state，仅用于身份核对，不把它当最终绘制坐标；最终坐标看 kind4 与原 FLIGHT RENDER 轨迹。

## 离线核对

原 `build/m52/recovery-drivers-09/analysis/native_flight.py` 仍独立运行并保留全部原断言失败。本目录 `analyze.py --host-log … --join-log … --output <新文件>` 只归因：拒绝缺块、乱序、缺轮，输出首收至首画、实际 tick 参数滞后、关联 motion/clock、帧阶段空档、墙面调用数、日志成本及 payload hash。任何 incomplete 均退出 2，报告永远 `performance_qualified=false`。

原 payload 在 Python 离线独立 base64/zlib/JSON 解码，记录输入/解压字节 SHA 和数字稀疏单元合法性，供后续同输入 AIR 等价回放使用；**Python解码成功不等于 AIR 缓存、Number 类型或最终像素等价已经实测**。保留原 payload 不重打包、不猜原渲染图。

已运行 9 项纯离线检查：冻结配方准确输入核验、准确输入/去除插点后的源码还原、原断言与期限保留、默认 null/热路径无新增 IO、Python 语法、AS 括号词法、真实压缩格式的数字稀疏单元解码、不合法数字单元拒绝、行字段与日志时间归因。全部通过；AS 词法不是编译检查。未动 integrated、已冻结候选/驱动、通用 runner、安装版或其它模组。
