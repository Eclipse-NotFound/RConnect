# 正式574D → offline1 → aura1 性能路径只读复核

2026-10-23。只读取实际冻结源码、SHA、部署回执和git；未编译、运行游戏、改生产或其它模组。结论不替代新组合性能测试。

## 先说准确结论

1. **两次正式更新都没修改房间协议、旅行和加载遮罩。** 长交接界面属于未完成的修复，不能描述成已交付房间优化后再次失效。房间不同步仍需对当前实际流程定位；本报告不因代码未变而否认新反馈。
2. **未找到能直接解释“无玩家念力抓取也普遍明显变慢”的新增大循环或重复网络调度。** offline1在任何联网尝试后恢复574D原采集路径；aura1的新增RENDER调用在未被队友抓取时立即返回。存在小量恒定开销，以及受抓期间的一人光晕重复检查/滤镜渲染开销，应实测后定量，不能直接当主因。
3. 当前根宿主实际 `80cfd8cf3138ee59cbf6eda0a1824a9ec960f413bd95e4b90d41dd0322b4fd3d`，最近部署/运行回执为BEFC。**这是测试组合不同的事实，不是80CF有错的证据。** 后续比较三RC版本必须锁同一实际宿主/其它模组配置，不能拿历史BEFC的耗时和现在80CF直接相减。

## 正式字节和git历史

| 版本 | 准确冻结目录 | SWF SHA256 | 字节 |
|---|---|---|---:|
| 0.2.23-coop-bundle2 | build/m52/coop-bundle-04 | 574d2b51490ae8b25a1396555600f56a301f8a20ae50104c0e35cf2796441afe | 186052 |
| 0.2.24-offline1 | build/m52/recovery-offline-production-01 | eb3653533cfb305bcca0b0cfe5e81bc306ea28fa400aae751ab7b5ae1cfa5fee | 186232 |
| 0.2.24-aura1 | build/m52/recovery-aura-offline-01 | df0fa0e2ca952e77e5132e75d71e73558dc919c7b8cdeba5da05fc9e94dc01e7 | 186738 |

实际 `release/RConnectMod.swf` 回读为DF0F。三个源树各78文件，无新增/删除类。

- git `edf8b7f`（2026-10-21 23:21）记录用户回退motion2到574D；原回执 `build/m52/motion2-user-rollback-20261021-215647/rollback.json` 为 `rolled-back-byte-verified`。同次提交里的recovery整合候选是未部署实验，不能当运行版本。
- git `7b36f19`（2026-10-23 09:01）记录offline1有限部署；实际回执 `build/m52/recovery-offline-deploy-01/deployment.json` 状态 `deployed-smoke-passed`，smoke `ae58b8049b`，安装22项仅RC改变；同目录备份实际SHA为574D。
- git `fc4b429`（2026-10-23 17:50）记录aura1有限部署；实际回执 `build/m52/recovery-aura-offline-deploy-02/deployment.json` 状态 `deployed-smoke-passed`，smoke `7d45932e01`，22项仅RC改变；备份实际SHA为EB365。
- git忽略 `build/` 和正式SWF，因此不能用 `git diff HEAD~1` 的9413行实验文件新增来代表运行时新增量，也不能把主 `src/` 最后一次提交直接当本次已编译源码。此次逐字比较准确冻结的三个src树，再与部署回执/实际SWF绑定。

## 574D → EB365 的真实新增

只改变3个文件：RConnectMod.as（版本和闭包接线）、Session.as、GameBridge.as；其余75文件逐字相同。准确补丁为 `build/m52/recovery-offline-production-01/proposal.patch`（其版本号随后由构建单独替换）。

- `Session.as:26–30`：`canSkipOfflinePresentation()` 仅当 `_networkAttempted==false && mode===OFFLINE` 才返回true。
- `:195,220`：startHost/startJoin在调用stop、启动socket之前就把 `_networkAttempted=true`；leave、失败、断开不会把它清回false。也就是说首次联网尝试以后，直到重启Session，采集行为保守地恢复574D。
- `GameBridge.as:59–67,262,354`：只在两个既有逐帧入口外包资格分支，跳过 `_presentation.observe*` 与 `_bodyEffects.observe`。没有新增计时器、RENDER事件、invalidate、世界逻辑或房间状态采集。
- 双人阶段新增量为每个既有ENTER_FRAME/RENDER一次布尔函数调用；false路径执行原采集代码。没有同时保留“新采集+旧采集”两份，也没有观察到能在连接后继续误用离线短路的源码分支。历史首次连接、生命周期和原生采集试验证明相应功能路径，不给本次性能净收益保证。

一个真实体验边界：刚启动从未联网时有离线省耗；点过Host/Join后再单人继续会回到574D原开销。因此“刚启动单人”与“退联机后单人”的比较可能出现速度差，但这不证明其低于574D，更不解释新增房间同步失败。暂不把 `_networkAttempted` 改回可复位，避免丢历史采集/首连状态；那会扩大本轮修复范围。

## EB365 → DF0F 的真实新增

只改变RConnectMod版本和四个光晕类，其余73文件逐字相同。具体范围见 `build/m52/recovery-aura-offline-01/source.diff`。

- `PeerGrip.as:24,133–137` 新RENDER监听，但 `incoming==null` 第一句返回。它没有调用invalidate，因而没有凭自身制造额外RENDER事件。既有before/after和50ms发送Timer没有重复创建。
- `:124,174` 有效抓取中分别在after、RENDER及真实hold收包后调用 `presentAura()`。这里的独立 `aura` 容器只登记 `incoming.player`，不是扫描全房敌人/对象。一次显示最多处理一个本地受抓玩家。
- `:130` 开始一次outgoing时采集原生Glow/ColorTransform；`:79` 把同一style随既有50ms hold发送，未新建另一条消息或提高发送频率。接收端每包校验有限最多4个glow及8色通道。
- `GameBridge.as:283,1012,1692` 三处远端玩家渲染增加 `locallyHeld(ghost)` 参数。其 `PeerGrip.as:42` 先检查本机teleObj是否就是该ghost；未抓取通常不进入peer循环。敌人的bodyEffects调用没有新增locallyHeld检查。
- `PlayerBodyEffects.as:215` 仅当原生Q正在持有队友时跳过覆盖根tint；没有新增捕获或动画步骤。
- 共享 `TelekinesisVisuals.as:106–107` 对每个已有desired对象多判断是否本地玩家，让真正UnitPlayer无需in_chain也可显示；没有扩大objects/held集合。release中新RGB/alpha归属检查只在释放执行。

**剩下最具体、可证伪的开销假设**：玩家实际被抓取时，`presentAura`在after/RENDER/收包内重复创建desired Dictionary、读取filter副本与颜色数组；即使style不变，校验仍有分配。另外新增受抓者身体GlowFilter是真实新增渲染工作，若其它视觉代码在同帧改相同颜色/alpha，可能发生重复改色及位图缓存失效。当前只证实这些路径存在，没有计时证据证明它们足以造成用户感知的整体回退。无抓取时同样变慢会直接削弱这个假设。

## 房间与运动代码没有被这两次更新修改

逐字SHA核对以下文件三版完全相同：

- `RoomSync.as`：536f5870…36163；`RoomEntryView.as`：b3a287a0…b8401。
- `NativeRoomState.as`、`RoomCodec.as`、`TravelGuard.as`、`TravelPlacement.as`、`RConnectTravelAccess.as`、`RoomDiagnostics.as`、`NetHud.as`、`CoopPause.as`。
- `ProjectileVisuals.as`：7837f01e…cf7e；`RemoteMotion.as`：19f035bf…4aa。

当前 `RoomSync.as:79–85` 仍由旧entryPending决定显示“房间交接中”；`:104`原45000ms交接deadline仍在。不能把该最长超时当正常加载耗时，也不能只隐藏遮罩就宣称达到单人时间。此前early2、ordinary-wall、receive-pump、NoDelay等实验源均不在这三个正式产品diff里。

## 最小验证与修复建议

1. 固定当前宿主和全模组配置、同一存档/种子/房间与人口，以准确EB365和DF0F做有界同场景对照：先双方不抓取，再固定一人持续抓队友，最后释放。只看同一个渲染间隔分布与原有功能/房间到达断言；不要把地图生成差异或不同宿主混进均值。若需要574D，再作为第三个准确基线，不能由当前src重建冒充旧版。
2. 仅在“抓取时差异扩大”复现后，记录一次有界 `presentAura` 调用数/耗时和真正filter/色变写入次数。可验证的局部方向是让收包只更新期望样式，把最终绘制合并到既有最终RENDER；但原生逐帧可能覆写颜色，必须验证本机/对方/暂停及释放八图，不能先删最终RENDER来换速度。若无抓取也退化，停止光晕微调，转查相同版本与当前组合的实际长帧位置。
3. 房间同步和长遮罩应作为旧RoomSync流程的独立缺口修复，保持两人分房语义。当前字节对照不支持“撤掉光晕就能修房间”的推论；也不建议为性能回退先恢复其它模组或宿主。

本轮未定位普遍性能倒退的确定根因。以上给出的是精确新增路径、可排除的实验污染，以及一条有条件的最小假设；没有以代码审查替代实测，也没有给新版本性能合格结论。
