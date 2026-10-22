# 离线采集门禁：真实单实例会话生命周期

2026-10-23，仅源码准备。尚未编译或运行，未改生产、安装、既有测试或其他模组。根会话负责构建和登记运行；本目录只有外部测试文档，不另建runner或测试框架。

目标是CS提案 `mods/ContinuousScene/build/generated/rc-offline-production-proposal-20261023-r1/src` 经根整合后的 `0.2.24-offline1`。测试实际读取 `RConnectMod.instance` 的Session、GameBridge、World/Game/角色身份。使用公开 `Object(mod.session).canSkipOfflinePresentation()` 和 `Object(mod.game).offlinePresentationEligibility`，不读写私有历史位、不伪造事件、不写mode、不替换资格函数。

## 构建与运行接线

- 入口 `tests/OfflineLifecycleTestDoc.as`，输出外部 `EffectsDriver.swf`。沿 `experimental/recovery-sandy-hold-native-lifecycle/prepare.py` 的外部文档方式，使用现有 `ProductionDeclarations.swc`、`GameCombatStubs.swc`，不把旧RConnect实现编进驱动。新API均经Object访问；版本通过运行时Class对象读取，避免旧声明SWC中的常量被内联。
- 用现有隔离runner启动**一个**原生游戏。应用ID必须为 `pfe-modsettings-rconnect-coop-host-` 前缀；`autoRole`必须为空，runner设自动旅行至rbl。驱动等待 `w.game.curLandId=="rbl"` 和 `w.land.act.id=="rbl"` 同时成立、加载状态结束并稳定5次ENTER后才记录对象身份，避免抢在runner自动旅行前开始。自动角色不是运行时改一个配置键就能关掉，驱动遇到非空会失败。测试只在必要时发送原生继续点击，不旅行、不改角色、不改暂停或战斗状态。
- 只有内存中的私有Config两个键会临时改变：hostIp固定 `127.0.0.1`，port为本机ServerSocket.bind(0)取得的端口；原值在finally中恢复，从不调用save，不访问真实应用存储。记录runner原端口；不扫描相邻端口、不连接外网。实际产品HostServer的原始监听地址行为保持不变。
- 根runner仍须设置独立绝对进程超时和资源清理；驱动自身总期限240秒、启动阶段180秒、其他阶段15秒，另用250ms Timer检查。ENTER和Timer都无法中断AIR主线程完全卡死，不能用内部计时器替代外部超时。

## 实际链路与必达标记

| coverage字段 | 真实操作与证据 |
|---|---|
| virgin | 初始offline、无server/link/peer，实际Session方法与原资格hook均返回true |
| virginLeave | 未尝试联机直接调用leave，跨真实回调仍true |
| hostNoPeer | 释放自己bind0的临时保留端口，调用startHost；实际server.bound、hosting、clients/peers为空，资格立即且持续false |
| hostLeave | 正常leave，资格仍false，传输引用清空 |
| joinFailed | 自有ServerSocket只bind、不listen，startJoin连它；必须观察实际TcpLink FAILED及底层Socket错误，连接关闭、原失败信息、资格false |
| failedLeave | 实际失败后leave，资格不恢复、link清空 |
| failedRetry | 再次公开startJoin，实际再次FAILED/Socket错误，资格false；这是手动重试 |
| loopbackConnected | 自有localhost监听器实际accept，真实TcpLink连接并发送原生HELLO；驱动只丢弃字节，不回应，不建立伪合作会话 |
| loopbackClosed | 关闭驱动持有的accepted Socket，游戏实际收到CLOSED并清理，资格false |
| loopbackRetry | 实际再连同一监听器并再次accept，资格false；仍仅传输层和手动重连 |
| occupiedHostFailed | 自有监听器占住bind0取得的端口，startHost实际bind失败：server.bound=false、原生host failed信息、自有监听仍有效、资格false |
| finalLeave | 最终leave清空传输引用，经过真实回调资格仍false |

初次主持的临时端口释放与产品重新bind之间有正常系统竞争窗口；意外占用会明确失败，不悄悄换端口绕过。非监听保留Socket用于拒绝连接，避免从一个刚释放的未知端口推断“没人监听”。真实FAILED是事后注册到新创建的TcpLink上的事件监听；若极端情况下同步失败发生在监听注册前，本轮会超时失败，不依据mode或字符串伪造已观察事件。

原574D的startHost在listen后无条件写HOSTING，真实端口失败最后可能仍显示hosting。测试以bound、占端口事实和原错误信息确认失败，不要求mode为offline，也不修改这个既有逻辑。若操作系统容许此次地址组合共享端口，断言会失败并清理，不能把成功bind当作失败用例通过。

所有自建监听器、accepted Socket、产品startJoin创建的Socket均登记在有界列表中，在finish的finally清理；同一真实Session调用leave释放产品HostServer。身份改变时不操作替代Session。无论成功、断言失败、事件异常、超时或驱动uncaught error，都立即结束，不继续下一阶段。

## 输出与资格边界

逐项输出 `COOP PASS offline-lifecycle ...` / `COOP FAIL offline-lifecycle ...`；结束为：

```text
OFFLINE LIFECYCLE RESULT { ... }
COOP EFFECTS DONE offline-lifecycle
```

结果含 `passed/checks/failed/version/applicationId/phase/abortReason`，每阶段起止时间及ENTER回调数，最多96条关键观察，12个上述coverage布尔值，实际端口、accept次数、丢弃的原生HELLO字节数，以及config/Session/socket清理结果。根应同时核对准确候选指纹、done、failed=0、passed=true、全部coverage=true、cleanup错误为空且两个清理确认均true；不要只依赖日志中出现过PASS。

这只是单个真实Session的功能验证。全程只有一次从未联机历史，首次网络尝试是正常主持，因此后续失败验证“历史不被清除”，不证明“首次尝试就是失败”的另一条新进程路径。真实loopback仍处于JOINING，没有WELCOME、不生成远端玩家；不声称验证了两游戏联机、合作握手或自动重连。公开方法/hook结果不证明实际observe调用被跳过；缺少可靠外部观测，因此没有为null/throw分支替换hook或添加产品计数器。结果明确把这些资格及性能资格设为false。
