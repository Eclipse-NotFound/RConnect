# 外置加入侧真实时序采样器

2026-10-25。`BClockTrace.as` 只利用 field9 已公开的回调和字段，不改产品、不替换时钟、不再次解码、不调用apply/present/take、不发包，也不推进游戏。**源码准备完成，尚未编译或运行AIR；根会话决定接入哪次隔离测试。** 根驱动未修改。

## 能准确观察什么

- 每次 `Link.message` 收到的frame消息：回调入口时刻、原回调开始/返回时刻、serial/base，以及原回调结束后真实 `replica.lastFrame.time/tick`。
- `replica.frames` 前后差值，是否通过原接受路径；每条确认的房间、pauseEpoch、两名玩家epoch/roomEpoch、时停phase/cycle，少量地形revision/弹丸数量。全部复制成小型标量记录，不保留完整frame、显示树或像素。
- `replica.confirmed` 的每次调用：真实离散state已经执行render之后的本机时间及源tick/time。原confirmed回调继续执行一次。批量消费时会记录每条确认，不只记最后一条。
- 每个正常屏幕事件中，在RConnect的 `before(priority=100000)` 前后读取position/delay/underflows/queued/current/next。这些字段读数准确，采样位置是外层事件前后。

每个原回调都以原对象作为receiver、同一个参数对象调用一次；原回调抛出的异常仍沿原路径传播。观察器自身读记录失败只计fault，不使原回调漏执行。停止时，仅当回调仍是本工具安装的函数才还原；其他人已替换的回调不会被覆盖。没有改变 `Link.closed`、Socket监听器或网络队列。

## 必须保留的近似边界

1. **arrival不是网卡收到字节的时刻。** Link先从Socket读入私有buffer，在8ms预算内分批WireCodec.decode，之后才调用公开message。采样入口已晚于WireCodec.decode，也包含此前积压；无法外置获得私有缓冲中每个包最早到齐时刻。
2. **实际clock.push时刻是区间。** 原RConnect.receive会进行FrameDelta.decode和prediction.confirm，随后才push；边界还会立即present(true)。`arrival.forwardAt ≤ push时间 ≤ arrival.returnAt`。非边界回调也不是零成本，不能把入口直接等同push。
3. **普通present时刻也是区间。** Stage的100001/99999优先级包围整个RConnect.before；其中还包括界面、偏好、输入和探针工作。不能把两端之差当作纯present耗时。相同优先级附近的第三方监听器也可能混入。没有状态变化时无法证明内部present到底调用还是早退，`takeObserved=false`表示未知。
4. **边界flush通过到包回调包围。** 其confirmed行有arrivalSeq；普通屏幕中的确认有screenSeq。不会另行手动flush。公开时钟的current已是这批take取出的最后一条，因此一批中的首个confirmed的state.tick可能早于同一记录的clock.currentTick，这是正常现象。
5. **通过replica.frames门槛不等于整个处理成功。** 如果原路径在frames++之后失败，最后状态仍可能更新。本工具用queued变化和同期confirmed数量补充queueAccounting；异常/不完整记录应拒绝做精确对照。
6. **未捕获起点的私有历史无法补造。** 最好在link/replica创建后、第一条frame抵达前start。晚启动时仍可测收到→显示等待，但header.completeHistory=false；私有offset/最近32项节拍历史不能从公开字段恢复，不能声称完整复现原时钟。

这些限制意味着采样结果适用于“真实到包节拍的区间回放”，不是给内部时钟加了精确探针。`qualifiesExactTakeTimes` 和 `qualifiesNetworkArrivalTimes` 永远为false。

## 根外置驱动的最小接法

将本目录两个AS源按需加入**外置测试驱动**的source-path；不要打进RConnectMod，也不要改被冻结产品源。无需任何authority类导入，参数通过已存在的Object接口读取。

```as3
// 加入侧：一旦mod.link和mod.replica出现就创建；最好还未收到首帧。
trace = new BClockTrace(mod, root.stage, 20000);
trace.start("field14/native021/dense-run-id");

// 可选的阶段标记，无文件IO。
trace.mark("rocket-mlau-start");

// 测试结束，先停止，离开当前消息/屏幕回调后写到新的证据文件。
trace.stop("measurement complete");
trace.writeTrace(new File(evidenceDirectory).resolvePath("join-clock-trace.jsonl"));
```

实际调用时替换buildLabel为运行的准确组合。工具不会自动寻找模块、启动游戏、修改连接或切换测试场景。若在当前回调内stop，等该回调返回后再export；不要在原confirmed回调内部写盘。建议先取60秒，避免高频场景超过行数上限。

输出最多20,000行，包含一行header、一行footer和中间记录；内存满后停止采样并还原自有回调，游戏继续处理所有消息，footer.truncated=true。没有环形覆盖或静默丢采样。未满时主动stop也不会消费剩余队列；footer.finalClock.queued可非零，离开采样窗口的末尾确认应当作尚未观察到，不能误判丢事件。

`writeTrace`只在明确调用后打开一次新文件、一次写入；不覆盖已有证据。失败保留内存，可换新路径重试。输出目录须已存在。也可 `trace.stop(); var data:Object=trace.data();` 交给驱动自己的结束写入器；不要两个写入器重复产同一份完整trace。

## 后续离线使用

- 到包回调序列不能重新排序；把acceptedCount==1、queueAccounting=true的到包关联到其真实frame时间。serial/base与confirmed tick另做唯一性核对。
- 对每个arrival分别以forwardAt和returnAt做上下界回放；普通屏幕取screen.at/endAt。若一条确认发生在其中，confirmed.at还提供“take已执行”的更紧上界。边界flush维持原顺序。
- 不要把这些区间任意相减拼成一个“精确内部时刻”。同一条输入下保守方案只有在两端分析都显示收益、而且空余量不明显退步时，才值得进入AS3隔离实验。
- 收到→确认等待可在同一加入侧getTimer下直接测：`confirmed.at-arrival.at`。它包括原FrameDelta/复制呈现开销，不能当成纯时钟排队；`confirmed.at-arrival.returnAt` 在到包触发flush时可能为负，这是边界确认发生在回调尚未返回造成的。
- 除header.completeHistory外，检查footer.truncated/faults/arrivalAnomalies/unpairedScreens；`usableForBracketedReplay=true`仍只授予区间回放条件，不授予实机性能资格。
- footer.observerMs是毫秒粒度的观察器自身记录累计开销，可能量化成0，不能据此声称零扰动。新增函数转发、数组分配也可能改变Link每批8ms预算；应另跑不采样对照，采样运行不自动成为净性能准入结果。

当前Python工具还使用理想等间隔renders，**本次没有把真实trace擅自接入它**。取得trace后需先加入实际screen区间输入，保留边界回调中的立即flush，再比较原field9回放是否覆盖实测position/queued/underflow读数。拟合不过，应先修采样或解释观测区间，不能通过调时钟公式“校准”结果。

已另备只读真实数据分析器 `../analyze_trace.py`，支持根驱动`join-clock-trace.json`及本工具JSONL；用法见 `../TRACE-ANALYSIS.md`。它只统计同一加入进程的收到→确认等待与节拍，没有运行候选时钟或宣称网络延迟。9项内存检查已通过，仍待真实trace。

## 可选的辅助类检查

```as3
BClockTraceChecks.run(root.stage, check);
```

这些检查只构造动态假的Link/Replica：原回调次数/receiver/参数、边界确认关联、标量记录不被原对象后改污染、异常原样传播、达到行数上限仍转发后续消息、停止时不覆盖新所有者。不会dispatch真实Stage事件，不使用游戏世界、不写文件；临时监听器在同步检查末尾finally移除。

这些检查源码也尚未运行。它们不能代替真实Stage优先级、真实Link delta序列及结束写入的AIR验证。
