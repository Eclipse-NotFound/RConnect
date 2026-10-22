# 外部收包批次诊断（未编译／未运行）

目标：确认准确 recovery20 的七个密集阶段，是否在**一次 Socket DATA 回调内**连续收到并同步分派多份完整单位快照。此目录只改外部驱动；不改 RC、发送频率、消息内容、处理顺序或性能门槛。78 项静态／纯模型检查通过，不代表 AS 已编译或原生表现合格。

## 证据与可观察范围

精确源固定在 `inputs.json`，均来自 `build/m52/recovery-20/src`：

- `rconnect/net/TcpLink.as`：`socket` 为公开成员；`wireEvents()` 把私有 `onData` 注册到 `ProgressEvent.SOCKET_DATA`，优先级默认 0。`onData` 在 while 中解出一个包就同步 `dispatchEvent(new NetMessageEvent(MESSAGE,msg))`，随后再读下一包。
- `rconnect/net/NetMessageEvent.as`：公开 `data:Object`，构造器无冒泡或取消行为。
- `rconnect/core/Session.as`：客户端连接前注册 `onLinkMessage`；主侧在 `onClientAdded` 注册 `onHostMessage`，均优先级 0。它们直接调用同步消息处理。`RoomSync.handle/accepts` 可拒收，因此低优先级返回**只证明同步监听已返回，不证明快照已被授权应用**。
- 原 driver03 的 `watch` 注册默认优先级测试消息处理以及 +100000/−100000 的原计时；新观察器使用 ±1000000。原 Session、其他模组与驱动监听之间的相对顺序保持。Socket 夹取包含该 DATA 分派中的所有既有回调，并非直接进入私有方法；MESSAGE 夹取也包括测试及其它同步监听。
- 原生无 `World.frame` 成员；新观察器仅使用驱动已有的 `phase/densityProbe/frames`，不访问该密封字段。

实际包名是 `unitsync`（full）与 `worldstate`（fast），不存在本诊断所假设的新 fullstate 类型：

| 观察项 | 原字段 | 边界 |
|---|---|---|
| 完整单位数量 | `unitsync.units.length` | 不扫描敌人显示对象 |
| 快速单位数量 | `worldstate.enemyMotion.length` | 空／缺失计 0 |
| 墙痕格数与字符总长 | `wallPaint.length`，每格已有 `d.length` | 最多 1200 格；不解码／复制字符串 |
| tick 分布 | 包顶层 `tick` | 不换算为毫秒 |
| 源采样时刻分布 | `sampleTime`、`units/enemyMotion[i].sampleTime`、`snap/players[i].snap.sampleTime` | 单位最多 512、玩家最多 16，超出标截断并使观察资格失败 |

协议**没有 sendAt**。sampleTime 是原生采样时间，tick 是 Session 逻辑计数；不能冒充真正发送时刻，亦不能把本地 getTimer 与远端数值相减称单程延迟。worldstate 的玩家数据和敌人数据可能不是同一源帧，min/max 不代表同一包在网线上花的时间。

## 输出与成本边界

结束时仅写一行 `SOCKET BATCH PROFILE {有界汇总}`，无逐包日志，无 CPU sampler。

- 七阶段各累计 batches/messages/full/fast、类型计数、时长／包数直方图、单位／墙格／字符数及 tick/sampleTime 范围与步长分布；非负载阶段放 `outside`，只作累计。
- `longest` 仅保留**从 load0–load6 开始**的最长 16 批。初始化大包不能挤占。每批保留前 64 个消息的标量摘要；超过后继续准确累计，增加 `rowsDropped`。不保存原消息／数组／单位对象。
- 批次 `start/beginReturnedAt/stop/duration` 和起止驱动帧／阶段；跨阶段批记入起始阶段并累计 `phaseCrossings`，不拆成两批。
- 每消息 `at/dispatchStart/stop/dispatchMs`；每批/阶段单列 `preObserveMs`（DATA 高监听）、`metadataMs`（MESSAGE 高监听全部统计）、`postObserveMs`（MESSAGE 低监听和 DATA 汇总）。毫秒计时量化及未计到的函数返回开销仍存在，不能据此精确扣掉诊断干扰。
- 外部不能读私有半包缓存；Socket `bytesAvailable` 是本次回调前可读字节，不是本批所有解出包的完整字节数。半包可以跨 DATA，批次按原生事件划分。
- `finish()` 如在 MESSAGE 里触发，先登记结束，待当前 DATA 低监听闭合再导出。原 DONE、七阶段时长、80 身体／39 枪／12 开火、按键和阈值不改。若原流程异常中止而低监听未执行，缺输出／未闭合将被拒收，不猜补终点。
- 附着从原 driver03 `watch` 时机开始，不能覆盖连接最早的握手；只确认已附着后的七阶段。丢低监听、嵌套事件、孤立 MESSAGE、Socket 替换、取数异常、截断均显式标记，分析器拒绝连续观察资格。

新增 helper 只移除自己的四个监听。唯一一次序列化对象是该有界统计，绝不 stringify 收到的包。`faults` 不吞生产异常，只捕获诊断自身错误；原 COOP FAIL/真实异常原样保留。

## 准确接入

原 source：`build/m52/recovery-density-corridor-drivers-03`，prepared SHA `5a8dbb9395c8dba8b6e980c49b112c6df3ae2e19e2f4950769d29756f8e1735c`。原十一 AS 中十份逐字不变，仅 `SustainedDensityTestDoc` 五处外部观察接入；新增 `SocketBatchProbe` 和 `SocketBatchTestDoc`，共十三 AS。`diagnostic.patch` 可逐行审阅。

`probe.py` 复用 readyfix 正式冻结／验证与已登记 `base.build`，仅切入口和合并三份声明覆盖；不另建编译器或二进制复制框架。`run.py` 是已冻结 current-profile-sampler 薄入口的五类替换，见 `run-edits.json`，仍调用同一已冻结实际设置 wrapper、原严格 fixture audit、22 项安装指纹、唯一 AIR ID、隐藏桌面和清理。1 GiB 编译门槛、6 GiB 双开启动、512 MiB 运行保护保持。

主会话从 `mods/RConnect` 执行（本代理未执行以下构建／运行）：

```powershell
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/recovery-socket-batch-probe/check.py
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/recovery-socket-batch-probe/probe.py --output build/m52/recovery-socket-batch-probe-drivers-01 --build --registry-wait 900
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/recovery-socket-batch-probe/run.py --candidate build/m52/recovery-20 --drivers build/m52/recovery-socket-batch-probe-drivers-01 --output build/m52/recovery-socket-batch-probe-20-01 --registry-wait 900
```

运行前后均核对用户真实 RV 文件与捕获 SHA；不改用户配置。两份模板依然来自当前 `pfe` 与 `pfe-modsettings-rconnect-player2`，均 RV enabled=0，只作为真实配置诊断条件，不宣称关闭 RV 是修正。

原 `result.json`／失败门槛保持；额外 `socket-batches.json` 仅声明诊断是否完整。无论采到什么都不赋予 FPS／发布资格。若同批确有多 full，只能先证明同步分派堆叠；是否重复应用、必要修复以及实际卡顿因果仍须结合原生产权限与时序判断。
