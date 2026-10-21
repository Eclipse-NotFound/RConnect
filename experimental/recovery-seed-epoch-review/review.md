# seed on/off 组件02：唯一旧 epoch 失败的只读审查

结论：**这首先是我改写共同夹具时改变了检查阶段；同时暴露出既有空 travelId 协议在“交接全部完成后遭重放”时缺少拒旧保护。不是两个替身修复造成，不是新增首绘开关的差异。** 当前两轮各108通过、1失败，不能称109/0；旧结果不改。

## 实际结果

| 结果 | SWF SHA256 | 真正检查结果 |
|---|---|---|
| `build/m52/recovery-seed-gate-on-component-02` | `35f5cfab6db50a849390b420997ee594dc1be7b5b86929bf10ecbb6dd6c3e4d2` | 109项中唯一失败：`old epoch stays rejected after successful restore` |
| `build/m52/recovery-seed-gate-off-component-02` | `f3b9193765acc28dad0292945787e897c1d687ef239d887c627d869b3ad78602` | 同一项失败 |

两边 `normal-complete` 最终都记录 `epoch=1, term=2, restores=3, readyMessages=2, acks=2`。额外注入前，检查已确认 `epoch=2`、恢复次数为2、ACK为1。`component-result.json` SHA分别为 `51afec925db598f415eb6f35cc00c17d19dc6788548fffedf30bfc9c56389836`、`2c9b26a757b5d2acc281b676cfdbe25712b627fee779a274139a14ab0690651f`。两轮源和安装指纹均未变化。

已另外直接解析两份原始JSON并作精确结构比较：**全部109个断言的标签/布尔结果完全相同，7组最终状态也逐字段完全相同**，包括 normal-complete、wrong-constructed-seed、death、replacement-game、disconnect、configuration-fallback、failed-restore。这只说明单变量两侧在这套输入下行为一致，不把两份 `passed:false` 变成通过。核对时重新验证了两份SWF SHA及冻结AS与intent指纹；on/off原回执SHA分别为 `84bfa101f787fcecee934f17ebebf4259d4a0a3fed70b6f32055a93646050bd9`、`eafe94284b34c0943f107bd66da5bdb10f7114c9ca4a0e56393890d2b45b1e71`。

## 检查转换改变了什么

原实际109/0的 `recovery-seed-first-raster-room-01/src/NativeTravelRoomChecks.as` 最后一项流程是：

1. 新地图 grant 已完成完整恢复。
2. **没有把 ticket 标成已画，没有 frame/render 完成首绘，也没有发ACK。**
3. 注入旧 epoch seal/grant，要求仍被拒绝且ACK为0。原标签明确是 `old epoch cannot replace waiting restored destination`。

新共同文档第190–200行则先执行 `finishSeed(t)`、确认ACK为1、再 `render()`，最后才注入旧包。检查的实质已经变成“成功完成后仍记住旧 epoch 并拒绝重放”。数量仍为109不代表原检查语义全部保留；原等待阶段的拒旧不能被当成完成阶段的既有保证。

## 准确13的实际路径

- `RoomSync.finishFirstRaster` 437–440行：发ACK，然后 `seedRaster.clear()`、`pending=0`。off在 grant 正常完成分支698–703行执行相同清理。
- `SeedRasterEntry.acceptSeal` 31–33行在 active 期间拒绝 `msg.epoch<=fromEpoch`；`clear` 会清除 token、fromEpoch、sealedBarrier/epoch和anchor。
- 完成后 `NativeTravelPlan.accepts` 对空ID返回true。`RoomSync.handle` 620–635行不再进入 seed active 校验，普通seal直接走 `applySeal`。
- `applySeal` 489–490行只比较是否不同，没有要求新epoch递增；因此把2赋回1，并发ready。随后注入的 grant 正好匹配重新设置的 pending/epoch，完成第三次 `restoreCheckpoint` 和第二次ACK。
- `TravelGuard.follow` 在这个例子根本不需跨房；`TravelPlacement` 不决定epoch或pending。计数改变发生于真实 RoomSync。恢复函数是计数替身，所以证明的是**真实分支再次调用恢复**，不是已经证明原生游戏发生了具体回滚或掉落重复。

旧574D `RoomSync.as` 340–357行已有同样的普通seal直接赋epoch、grant清pending路径。它也是对空ID普通交接的既有容错边界；不能归因于13首绘开关的新退化。

## 是否已证明正常联机可达

没有。此夹具直接调用 `RoomSync.handle`，并在已ACK后主动构造额外的旧包。更具体地，`seedSeal(1)` 的外层 `epoch=1`，而 `seedInfo()` 仍带当前目的地的 `roomEpoch=2`；`grant(2,1,"")` 临时打包的是**当前夹具**的checkpoint，不是先前宿主真实发出的旧checkpoint。这是拒旧反例输入，不是抓到的网络重放记录。

实际 `Session.handleMessage` 390行直接交给 RoomSync；JSON和AMF解码只校验数据结构，未校验这两个epoch的业务一致性，故若这样的消息被交付，生产确实会走上述路径。但 `TcpLink.onData` 171–201行按同一TCP字节流逐帧同步分发；宿主seal只在 `begin` 245–248行随递增serial产生，grant与ACK后没有发现旧seal重发器。当前证据不足以声称正常同连接会在新交接完成后收到此前旧seal。重连、主动重放或多来源乱序另属边界，本次未验证，也不扩展实现。

## 建议的下一步边界

保留这两次真实失败。未来夹具若继续修订，应把“尚在等待首绘时的原拒旧保证”和“全部完成后的额外重放容错”分开，明确后者是新发现的既有缺口，不能静默删断言或把失败改绿。on/off性能对照应比较同一有效宿主流程；本失败不能替代原生加载、出生与按键目标，也不应成为给宿主加回全局等待的理由。

本次只读源码与现有结果，未修改冻结 control/control-fix、生产或结果，未运行JVM/AIR。

根会话决定继续同字节驱动的单变量原生加载**诊断**，明确带着这个共享边界缺口；旧seal完成后防重放另列待核，不在gate耗时对照中加入第二项生产改动，也不凭此发布。probe微优化按根会话决定搁置，不继续投入；已有实际主侧热点另在 WallImpactVisuals.packed，不能由本组件推断收益。
