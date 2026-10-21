# 825a566b2a CPU 采样失效只读审阅

结论：采样在首个目标房间 grant 处理内丢失了原生缓冲，之后没有恢复。**0 CPU 不能用于归因。** 目前没有证据证明被其它 AS 驱动清空；VM 自行停止/清空与证据相容，但不能仅靠公开旧 VM 源码确定 AIR 51.1 的具体触发原因。未启动 AIR/JVM、未新增驱动或修改冻结产物。

## 实际时间与输入

加入侧 `room-input-cpu-profile.json`：37752ms 的 `grant-handler-before` 为 nativeOrdinal=3；40297ms 的 `grant-handler-returned` 已变为0。整个 grant 回调约2545ms。到43571、43818ms的后续 driver-frame 和45644ms停止时仍为0；最终 drains=1、callbackDrains=0、fault为空、cpuRows为空。辅助对象自己的 running 标志没有检测到 VM 停止。

原始 JSON SHA：`1957ced4ef1897b68f968fd6e13834fd64b998f28f2e577f4afd663fd63e2ed0`。原失效证据另存在 `build/m52/recovery-input-cpu-invalid-01/join-cpu-profile.json`；collector 已拒绝序号递减，不能标“采样完整”。

准确冻结 `recovery-input-cpu-driver-01` 清单逐文件 SHA 全匹配；两侧运行回执绑定同一 EffectsDriver `8e31168c…c77a2`、EffectsHarness `d52ef430…21086`。RoomInputCpuProfile 原文与冻结副本相同，SHA `7ff56fe3…84c3`。

- 编译使用 AIR 配置及两个 external-library-path。两个 SWC 的 catalog 均没有 flash.sampler 声明；不存在本地 sampler 空实现替代的证据。起始 getSampleCount=3也排除所有采样 API 始终空返回这一解释。
- 解压后核对准确 harness、RConnect13、本轮其它13个已验 SHA 的模组二进制，没有 clearSamples/stopSampling/pauseSampling/startSampling/setSamplerCallback 静态符号；准确 FD92 游戏也没有这些操作符号。游戏包含 flash.sampler 名称本身不等于操作了采样器。
- 新 helper 自身只在开始、bufferFull 或 finish 清空；callbackDrains=0排除了其 bufferFull 正常进入后清空。finish 在失败收尾才发生，解释不了 grant 返回前已归零。旧密集 diagBegin/diagEnd 不在本轮驱动或 harness 中。
- 以上排除静态直接调用；不宣称证明了所有可能动态调用或运行时内部行为。

## 官方 VM 源码能证明什么

Adobe [Sampler.cpp](https://github.com/adobe/avmplus/blob/master/core/Sampler.cpp) 的公开 master 源码（只作实现边界，**不是本机 AIR 51.1 精确源码**）：

- 202–244：回调只有特定条件才执行；Collecting/Reaping 时不执行，空间耗尽仍可 stopSampling。
- 434–442：删除对象采样调用 sampleSpaceCheck(false)，允许跳过回调。
- 475–556：stopSampling 清空计数和缓冲；pauseSampling 不清计数。
- 527–532：此公开分支的 setCallback 赋值被注释（bug614529）。
- 605–647：GC 标记栈溢出也可能直接停止采样。
- 228–231：回调检查严格 falseAtom，不能把 void 返回值简单解释为 Boolean false。更直接的是，本轮 callbackDrains=0，尚未进入回调，返回类型不能解释已观测现象。
- 387–402：sampleInternalAllocs(false) 仍记录 AS 对象分配，不能将采样数据规模等同于 CPU 样本数。

所以“回调注册看似成功、没有 AS 异常、计数归零”不排除 VM 内部停止。旧逐帧采样成功也不证明一个连续约7.9秒、跨加载/GC的窗口同样安全。现有记录没有缓冲字节峰值或 GC 内部原因，不能进一步定案。

## 不依赖满缓冲回调的最小替代

沿已有成功的 `SustainedDensityTestDoc.diagBegin/diagEnd`：只在少量选定 ENTER_FRAME 开始独立采样，配对的最终 RENDER 立即 pause、取样、stop；下一入选帧重新 clear/start。不注册满缓冲 callback，不保持跨帧长缓冲，不新造运行器或分析框架。保留原玩法、1000ms按键窗口及原失败；诊断只作成本线索。

优先限定加入侧 grant 返回后的首绘/解除暂停/输入基线阶段，低频抽取且限制总帧数；每帧独立记录开始、结束、原生计数及有效性。某帧零样本、计数倒退或失效必须独立标 invalid，后续帧可重新开始；不得将该帧当零成本或用其它成功帧补齐。采样枚举自身成本单列，不能用此运行验收加载性能。

此替代**不能恢复首个同步 grant 回调内已经丢失的样本，也不能保证单个超长帧绝不溢出**。当前最小目标是先获取返回之后导致首绘/按键迟滞的有效函数栈；grant 的2545ms仍只有端到端时间，不能伪造内部归因。本次仅提出入口，没有实现或运行新采样。
