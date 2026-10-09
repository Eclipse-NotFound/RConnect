# M50 / R11：Q 传送动画交接

2026-10-09。负责会话「RConnect (11)」01a11c56-a5a8-7d41-9996-13e882a11ce6。
原「RConnect」01a086bb-378c-7f60-b8e1-50d90ffa0996 唯一统一接线、构建、AIR、门禁、部署与提交。用户在原会话的 01a11c54-f561-7c52-90c7-0f9cfedc29e7 回答中明确授权当前及后续全部 RConnect 会话协调；已回读真实人类回答。

## 当前交付状态

独立实现与专项驱动已完成静态核对，**未编译、未运行、未部署**。线上仍 0.2.21-dev / 5c372cf5。后续只读核对接线后补了独立文件内的去重清理接口与重建专项，下面为最新指纹；早先35c885de/3c533e05副本不覆盖这些新边界。R11 已再次停写源码/测试，原会话可复制为诊断或最终候选；若需修改先协调，避免冻结后变化。

- src/rconnect/game/TeleportVisuals.as：SHA256 ec323ce52b1926e6cb1c98e722c78544cd396fa5b3661ba257111b4b703c272c（260行）。
- tests/TeleportVisualTestDoc.as：SHA256 2958e0d91ee078c76a7bbeab539cfa2f2f3be0f6a7ee8dcbd6cbe49cc9554e3d（342行）。
- 诊断/实战记录：knowledge/experiments/2026-10-09-m50-teleport.md。
- 只检查了括号配对、无行末空白、原生调用路径与公开成员；不把这些写成 Flex 编译通过。

### 01:08 只读复核已接线的 live（共享修改仍由原会话处理）

已看到原会话接入 before/observe/capture/receive/split 和测试入口，接口吻合。两处需冻结前修正：

- GameBridge 两个 `_ports.tick(loc,presentationTime())` 尚未传新增的 key/epoch，请按上文4参接线，以覆盖复用 Location 的新 epoch 清理。
- `_ports.removePeer(id)` 现在放在通用 `despawnGhost`。该函数还用于“化身 lost from world 后 respawn”。初稿会一并删高水位，造成旧Q重播；独立小修现已完成：`removePeer(id,forget=false)` 默认只清粒子，保留去重；`clearPeerEffects(id)` 显式只清粒子。真正新 source stream 在 receive 内部自动重建水位，endSession 的 reset 全清。通用 despawn 现在无需改签名即可安全清粒子，勿在重建中传 forget=true。
- off-room 早退分支没有调用 receive，若1500ms内汇合，新化身可能回放离房期间的旧Q。新增 `discard(id,snap.port)`：只清特效并消费该快照的事件号，不调度播放。请在 updateRemote 的房间/地图/epoch 不匹配早退前调用（不要求 ghost 已存在）；然后普通 despawn 可以照常清粒子并保留水位。

原18案例已加入 run_final_regressions 的240s上限；现在增加双向真实化身离链重建，共20例，推荐维持足够300s上限以容纳原生25帧×20例和启动。上限只约束整体完成，不放宽行为检查。尚未见本专项原始运行/编译结果。最后两条工具协调消息均返回 Codex app tool request failed，记录已经留在此文件，未声称消息送达。

## 原生证据

UnitPlayer.control 松开 Q 时，在 t_port 达到 pers.portTime、技能许可且 loc.portOn 时调用 actPort；actPort 还检查魔力、格子可见性及 collisionUnit。只有成功分支调用 Unit.teleport(x,y,1)。

Unit.teleport 的顺序：旧脚底坐标 emit("tele",中心Y,rx=scX,ry=scY,kol=30) → setPos/武器位置更新/清 levit → 新脚底坐标 emit("teleport",中心Y)。AllData 的 tele 为 sprBSpark 位图粒子，teleport 为 visualTele / 12 原生帧 / imp=1。Unit.run 在控制后还可产生少量正常位移。

因此本模块用 Q 释放候选帧前后新生的实际 visualTele 确认成功，不用按键或距离判断成功；也支持 world.alicorn+keyPunch 的原生同类传送（该分支当前没有实际运行专项）。未成功、普通 setPos、门/地图旅行没有此事件。

## 共享接线（原会话修改）

GameBridge 独立实例 `_ports:TeleportVisuals = new TeleportVisuals()`，不要通过 Session 另开伤害/传送动作。

1. onPerceptionFrame 更新 `_sampleAt` 后、原生步骤前：`_ports.beforeNativeStep(gg,world,_sampleAt,roomKey(),roomEpoch)`。测试按 100000 优先级注入 Q，GameBridge 的 90000 在其后。暂停/非 allStat=1 不扫描链。
2. onMirrorFrame 原生步骤后、所有远端粒子 tick 前：`_ports.observe(gg,_sampleAt,roomKey(),roomEpoch)`。before 与 observe 必须同帧同 stamp，避免把远端回放的粒子归属本机。
3. readSnapshot：`s.port=_ports.capture(gg)`。数据为 `{stream,sampleTime,events:[{seq,at,fromX,fromY,toX,toY,postX,postY,scX,scY,roomKey,roomEpoch}]}`；已发生事件保留 1500ms / 最多16条。
4. 同房/同 epoch 的 upsertRemote 中 push motion 后：`_ports.receive(id,snap.port,loc,main,rec.motion,roomKey(),roomEpoch)`。id 是稳定网络玩家 id，勿使用外观重建后的 ghost 作为去重身份。
5. onMirrorFrame 与最终 RENDER：`_ports.tick(loc,presentationTime(),roomKey(),roomEpoch)`；第二次 tick 不重播。要传 roomKey/epoch，以清掉复用同一个 Location 但 epoch 改变的待播/存活特效。
6. setCoopPaused：`_ports.setPaused(value)`；removeRemote/despawn：`_ports.removePeer(id)`（默认保留高水位）；endSession：`_ports.reset()`。重建/重新穿甲不能 reset 或 removePeer(id,true)，否则可能重播旧事件。
7. 房间不匹配早退前：`_ports.discard(id,snap.port)` 消费事件号并清旧房粒子，不播放；tick 也检查 loc/key/epoch。不要在每次房间快照读取时 reset，串行观察应跨相邻帧保留。

RemoteMotion 使用 `TeleportVisuals.split(a.snap,b.snap,cursor)`：null 表示普通区间；非空返回 `{x,y,after,at,snapshot}`，snapshot 为只读的 a/b 原引用。保留 sourceTime/cursor/delay，位置直接用 split.x/y，其他姿态/武器选 split.snapshot；不要跨位移区间继续 cubic/WeaponDisplay.interpolate。split 仍在传送前后的正常小段做线性插值，可含同一网络区间内多次施法，不改历史数组。

现有 >600px reset 必须对确认的该区间传送豁免，否则远距离 Q 会先跳角色、100ms 后才出粒子：可用 `TeleportVisuals.split(last.snap,snap,last.at)!=null` 判断区间。长断流/时钟/首次进入/房间 reset 保留。事件正好在 b.at 时，sourceTime 到该时刻应同时跳身体和播粒子，不能先播放未来武器。

## 专项驱动

建议旧21负控与新候选用**相同 TeleportVisualTestDoc 输入**，`random_mane` 或确认 limX≥1000 / limY≥320 的同房；时间上限 300s。对源/对端同帧实际对象作观察，不调用 TeleportVisuals、不 emit、不调用 Unit.teleport、不手动移动接收化身。

20个双向案例：160px短距、640px远距、反向160px、挡住的落点、魔力不足、Q短按、单纯 setPos、冷却阻止蓄力、Q后实际共享 SATS暂停/恢复、接收化身从链/units 移除后实际重建。固定原生25帧蓄力；源必须真实位移、扣魔、生成 visualTele + sprBSpark。对端必须只产生一次落点、出发粒子、至少2动画帧、可见像素、坐标高度正确；化身不从两点间滑过，身体/特效同帧（采样量≥12，时差≤50ms），暂停至少3帧且零跳变，重建后仍只有一次特效，粒子在下一轮前全部离链。两个方向各保留成功场景最终画面PNG。

通过 COOP PASS/FAIL 与 COOP EFFECTS DONE teleport-visual host/join 纳入统一流程；新类型消息 type=teleport-visual-test。默认只在唯一隔离 `rconnect-coop-` app id 启用，真实用户实例不启动夹具。prepare 使用私有格子走廊、原生 LMG 保证 SATS 可用；状态/输入/武器/格子/单位标志在 finish 恢复。不能改变旧失败阈值来追绿；夹具前提问题与生产失败区分、保留原运行。

尚缺实际隔离退出/同 Location 新 epoch 的集成验证；上面的原生分房回归可以补，不能只根据源码声明已经通过。本轮没有借传送显示重做稳定重连、跨地图独立行动、多人或真实网络。
