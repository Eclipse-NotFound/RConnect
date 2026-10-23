# scene-v2：已通过功能，但大图重复交接仍未达到单人耗时

只读既有实测，不改产品、不新增探针、不启动游戏。双人 `ea261fcc5c`（roomfix2 C26B…8CC0）与单人 `d46d5c0ada`（正式 aura1 DF0F…01E7），两份 `scene-result.json` 均通过真实偏好预置、实际读取及末尾未变检查，原业务回执也通过。独立字段摘录和指纹在 `SCENE-V2-COMPARISON.json`，SHA `eaf21857667e52469319db95732ecb89f12bb4801657e5e4495d7f2961071bc2`。

## 真实对照

|流程|双人主侧 ms|双人加入 ms|正式单人 ms|加入 grant 次数|加入最后 grant 返回→可操作结果 ms|
|---|---:|---:|---:|---:|---:|
|首次大图|9267|19891|7105|2|2465|
|基地|2557|3057|1797|1|56|
|大图重访|4149|12161|3557|2|1561|

宿主80CF、外部驱动、harness、全部资源与模块指纹相同，RC production 字节和单双人配置不同。两次均为240×125、seed1380142925；但双人实际入口161.8,4320，solo1161.8,4800，单位推进及角色数也不同。它是当前正式单人体验参考，不是“同一roomfix2字节的solo”或严格等工作量微基准；不做百分比净收益结论。

现有可操作判据没有降低：目标地图/房间、原生退出结束、room ready且不busy、无entryPending、world非暂停、allStat=1、黑幕结束，并核本地控制恢复。双人双方房间、尺寸、种子和出生位置一致。主侧先报告可操作后发生的再次交接不会回写其首个耗时，因此仅看主侧9267/4149会漏掉后续重复事务。

## 已证实且应最先削减的 RC 重复工作

首程实际 **seal2→grant2→ACK2→seal3→grant3**，两次都是同一地图/epoch2/roomKey。重访同样 **seal5→grant5→ACK5→seal6→grant6**，同epoch4同房。中间无新 TRAVEL CLOCK 或原生退出。

- host日志50–63：READY2于81746结束；迟到REQUEST于81748进入；ACK2处理84088–84106期间立即发seal3。第二次host再capture403ms、pack434ms，READY3整个处理866ms。
- join日志59–89：grant2处理2038ms（restore1851ms）；下一次seal3将busy/onPause重新设true，完整grant3再处理2963ms（restore2769ms），其中角色切换前置本身1072ms。两个grant的解包后快照分别约2.244MB、2.246MB。
- host日志163–183：READY5于102179结束；REQUEST102181；ACK5中发seal6。第二次再capture322ms、pack340ms、整个READY6处理691ms。
- join日志132–157：grant5处理2067ms（restore1781ms），grant6再2742ms（restore2550ms），再次完整重建单位/掉落/地形状态。

这是确切的重复事务与序列化/恢复，不是由单位总数推测。取消额外事务可消除其新增工作，但不能把全部grant后延迟都当作可节省值：正常第一份状态仍须恢复，后续本地帧也仍须执行。

首程第一份grant返回41697到最终结果50530共8833ms，里面含第二次seal等待、grant2963ms和最后尾段2465ms。重访对应6095ms，里面含第二次grant2742ms和尾段1561ms。原来的“grant后长帧”此轮已能部分归到第二次交接，而不是全部归网络或未知绘制。最后尾段的函数级归因仍未有证据。

## 真实触发链

准确 `build/m52/recovery-room-production-02/src/rconnect/core/RoomSync.as`：

1. `handle(seal)` 可直接调用 `sendReady()`，早于下一次帧里的 `check()`。
2. `sendReady()` 已读取、冻结并向主侧声明当前原生房间，却不更新 `nativeLand/nativeRoom` 这两个“已观察原生激活”的标记。
3. 后续 `check()` 看到新Land/新loc，仍将它当成未声明的切换，发送REQUEST。TCP顺序于是是READY在前、REQUEST在后。
4. v2只在处理READY时清理已经收到且被READY覆盖的requested，不能消费后来才到的REQUEST。
5. ACK将pending清0后立即 `check()`；requested仍true，于是再begin。同房join本来无权威，不能走unchanged owner路径，因此又获得完整检查点并执行foreign restore。

## 最小安全修正建议（尚未实现/实测）

优先让**发送READY也记录它确实已宣布的原生激活**，不要在宿主按相同roomKey吞掉REQUEST。范围限定 `sendReady` 当前同步采集对象仍然是当前 `game.loc/world.land`、原生非过渡、其info与实际key相符，并且不属于下述尚未处理的剧情入口。

在发送READY之前记录 `nativeLand=game.world.land; nativeRoom=game.loc`。这只更新“该原生房间已被宣布”的标记；不改ready、term、settledRoom、不提前撤罩或恢复模拟。放在send前，失败若触发Session reset可正常清空，不在send返回后把已reset状态写回。

**必须保留check现有的剧情限制**：`ready && TravelGuard.restricted(game.loc) && game.roomKey()!=String(hostInfo.roomKey)` 为真时，不能用新标记跳过既有returnTo。最小做法是在这类尚未确认的独行剧情/挑战房不记录标记，仍让原check执行限制；或先执行完全相同的限制处理再采集合法READY。不要把普通房提速扩成放行挑战房。

真实连续跨房/返回的区分依靠原生对象身份，而不是像素位置：

- READY宣布A后实际进入B，loc对象变了，check继续发送B请求。
- B已被check观察后返回A，nativeRoom曾是B，仍会发送A请求；不以“曾去过A”去重。
- 同key新探索产生新Land/loc对象，仍可识别；不同epoch/seed/阶段沿现有地图流程，不吞其请求。
- 玩家仅在同一loc里改变x/y、武器状态不代表房间切换，不应再创建交接。
- 如果同一个房间对象被原生或其它模组重新初始化且引用未变，当前协议本来就没有激活revision可供比较；这次修改不新造能够识别它的保证。

不建议只用当前 `sameRequest` 或额外term/坐标布尔比较在host丢弃后到REQUEST：现有REQUEST没有唯一激活revision；同key不证明同次激活，A→B→A也可能复用term。若另走宿主去重方案，应先有明确激活编号及READY所覆盖编号，成本显著高于修正这条发送侧观察标记。

## 最小复核要求

保留原scene-v2和BF6驱动。复测普通真实跨房/返回与大场景三程，要求单次大图进入不再有无新原生激活的第二次seal/grant；真正跨房、旧房状态和静止队友断言仍通过。记录所有原handler/restore时长与最后可操作时间，不以只剩一次grant自动授单人耗时资格。不要删除已有scene01/scene-v2重复事务记录。
