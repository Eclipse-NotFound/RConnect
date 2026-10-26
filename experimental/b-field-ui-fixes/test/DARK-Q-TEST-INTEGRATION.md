# Dark Q external regression

2026-10-25。`BDarkTeleportCases.as` 未编译、未运行；不依赖候选新接口，因此可对精确旧版/候选运行同一测试。

## 接入

沿用 BUiCases 的 constructor/input/step/api 协定；api.home 与 floorY 来自根驱动 setup。建议独立 `scenario="darkteleport"`，先由 host beginMission(random_mane)，再让setup选择 limX>=1040 的普通房间，清出走道并把双方放入同一home；不需要 nextRoom。setup末尾不要startExit。根step跳过旧peer-finished检查，api.finish先phase=90；同UI helper的end协议结束。总timeout建议120秒。

每例真正按住join Q，host观察原生t_port>=35（原生portTime=25），join至少观察3个不同充能确认值的原生portCel后才松手。随后等待至少25个主侧模拟tick，并确认join收到了释放后的权威帧。正例必须抵达目标、只增加一次positionEpoch、扣魔法；负例保持位置和epoch且不扣魔法。没有直接调用teleport/actPort，没有修改产品命令或确认帧。

## 三个视野/碰撞场景

- `join-lit`：加入玩家在目标80px外，主侧在远端；房间黑暗，原生视距160/320。主侧tile.visi<.8，加入侧原生视野>=.8、checkPort=true、原生目标框frame=2。真实Q应成功。这对应“绿框却失败”。
- `host-lit-only`：交换玩家位置。主侧目标可见，加入侧看不到，原生checkPort=false、框frame=3；真实Q必须拒绝，防止修复后错误借用主侧视野。
- `solid-target`：加入侧靠近目标，光照正常，但目标格是透明坚固障碍，原生collisionUnit=true。用透明障碍隔离碰撞这一因素；光照依然由原生算法算，不直接赋true。必须拒绝并保留魔法。

夹具把room.black和retDark置true，暂关共享探索（结束恢复）；清空隔离测试房旧对象，保留两个玩家。每例把旧探索清零，调用原生lighting/lighting2逐步填亮，主侧的ActorSight私有光照缓存先dispose再update。join在确认收到夹具、站稳并处于黑暗房后也清零旧探索并调用原生lighting，以模拟首次进入暗室。没有设置visi/t_visi为1，也没有调用候选的withCursorLight来制造成功结果。

host记录真实主侧tile亮度和ActorSight.visible；join记录真正本机checkPort、tile亮度、collisionUnit与实际portCel帧。任一夹具条件未达标都会单独失败，不能将“测试未形成视野差异”当成产品通过。

## 限制与实测注意

- 测试中魔法属性沿准确field9 TeleportProbe设置（portPoss/spellsPoss=1，portTime=25，mana=10000，关闭回复）。这给出确定资格，不绕过原生许可、碰撞、计时和扣魔法逻辑。
- 该组专注同房双人视野差异；背景房/分房传送、SATS与时停原有矩阵另行回归。
- 若失败检查root日志中的phase/charge/held/view；不能为“使测试通过”直接把可见格标亮或提高主侧视距。
- 初轮基线已完成并复现绿框失败/红框误传。原生物理将测试摆放的floorY=879落地到Y=880，因此现于ready取得真实稳定g.Y作为释放后的expectedY；保持0.06精度，没有用大容差掩盖位置错误。目标格和checkPort的吸附坐标仍使用原生floorY规则。
