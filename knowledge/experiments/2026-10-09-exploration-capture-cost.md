---
domain: rendering
type: experiments
game-version: ["1.02"]
confidence: medium
verified: false
discovered-by: RConnect
date-updated: 2026-10-09
evidence:
  - kind: source-inspection
    symbol: "ExplorationSync.packet; optional RVExplorationAPI.capture"
  - kind: runtime-experiment
    summary: "9a67e66d75每端6帧栈采样，探索读取及其垃圾回收占主要样本；采样与其它测试重叠，仅定位"
  - kind: runtime-experiment
    summary: "3df2612a46只改隔离副本读取间隔100到250ms，整体帧率显著恶化，未获得改善证据，未采用"
---

# 共享探索全房读取开销诊断

## 已确认

RConnect在联机定时器中每100ms调用ExplorationSync.packet。即使最终没有变化行发送，也先调用可选视觉API.capture读取整房。API版本1只有active/capture/merge，没有变化版本或分片读取接口；一次读取对未完全探索格逐一编码64个子格，再生成每格17字符的行字符串。收到的探索记忆单调合并，不能用原生整格可见性随意代替子格内容，否则会改变探索结果。

此前共享探索设计记录在2026-09-20-m31-shared-exploration.md。本记录只补充读取成本的诊断；未改变协议、开关语义或视觉模组文件。正式24生产SHA d62c0bd2保持不变。

## 观察到

build/m50/density-runtime-profile-01使用原24生产，只向CombatNetworkTestDoc的独立副本加入阶段/渲染时戳与flash.sampler。每端最多6个采样帧；9a67e66d75宿主capture栈56个样本、其GC19个，加入侧125+20个。JSON编码、视觉遮罩、地形扫描和HUD刷新也出现。该次存在另一个WallBlend测试实例，且采样有额外开销；不能据样本占比推算准确CPU百分比或帧率收益。

用户拒绝跨模组发送协调消息，要求等它测试结束。只读确认对方测试完成及AIR为空后，运行build/m50/exploration-cadence-probe-01：逐字节复制24生产源，只将packet门槛100改250ms。副本SHA 2e445783，测试逻辑和阈值不变。首个驱动构建输出路径校验失败发生在AIR启动前，原脚本与日志保留；修正输出位置后得到3df2612a46。

该次两端DONE，但加入侧低负载65帧/22274ms、p95 507ms；80敌人阶段5帧/p95 2724ms，部分炮塔未在原窗口结算。结束后CPU单次88%，后来只读快照显示《群星》运行、内存可用7632MB、无换页。副本未取得性能改善证据，未合并或部署。原24追加外观检查aea1fdd9e5也在开局60秒超时，未开始正式案例。

## 推测

减少全房读取可能释放主线程时间，但当前观测不能证明它是主要帧率瓶颈，也不能证明250ms是合适的取舍。外部负载明显变化可能干扰比较；这不是全部旧红由环境造成的证明。火焰的开头迟到/随后追赶还涉及角色播放时钟，不能仅靠探索读取实验解释。

## 尚未验证

需要在可比较负载下重新对照读取成本，并检查共享探索更新及时性、转向/破墙/离房与重新握手。不得把4Hz读取副本当作已修复版本，也不得改写其它模组以绕开本模组权限。后续若选择优化，先验证保持子格结果与房间边界，再执行新生产字节的完整回归。当前38组仍有4红/34未跑，安装21保持原样。

## 续验与窗口条件（15:45 更新）

正式25精确复用24的生产字节。Combat、FastHeld、Flame、PeerVisual、WeaponAngle五组均失败，后三组分别为真实火焰时长红、两次开局/换图准备超时；后两次尚未进入外观案例。连续准备超时后队列暂停，旧结果保留。火焰663735f268双端全部几何/轨迹配对通过，七个方向案例中的部分火焰显示时间缩短，最大281ms；不是火焰拖尾过久。

原自动测试描述符是visible=false，普通游戏描述符是visible=true。只在独立runner副本把窗口改为可见，保留生产、原驱动、所有模组、资产和判定：

- probe-01 / b44aaf37fa：Combat伤害与全部炮塔通过，密集69帧仍低于80阈值。开始CPU99%、结束30%，不能单凭这一组归因窗口。
- probe-02 / a16594b3f7：错误漏传原PeerVisual的基地旅行参数，虽然断言通过，但场景不同；明确作废比较资格，原输入和结果保留。
- probe-03 / f33cd79ca5：恢复原rbl参数，PeerVisual双端各53项通过、DONE，实际完成基地旅行。翅膀获得/移除、飞行动画及枪械原生轨迹均覆盖。
- probe-04 / aa03e2bdcb：原rbl场景的Flame双端九组全部通过。期间六次CPU样本83–96%；不等于稳定负载，也不构成已定位Windows具体调度机制的证明。

这些是诊断结果，不计入正式发行的38组。它们支持将实际可见游戏窗口纳入正式测试条件；不能将原隐藏窗口失败删除，或断言全部卡顿已修复。微软timeBeginPeriod文档说明Windows11可能不给不可见/完全遮挡窗口保证较高定时精度，但尚未证明本机AIR停顿由此造成：https://learn.microsoft.com/en-us/windows/win32/api/timeapi/nf-timeapi-timebeginperiod 。未调整系统定时精度、优先级、亲和性或其他程序。

另查RV源码否定了“explored=0即可跳过64个子格”的捷径：fillFogCache/recalcTile会在中心格不可见时仍记录可见角落的seenSub。这样跳过会丢失真实已探索边缘；未修改RV或采用该捷径。
