# 首轮时钟欠账：最小只读诊断计划（未实施）

目标仅定位4733dbf4b4首轮“源出生→收包0–63ms，但收包→显示1069–2309ms、显示寿命约2/3”的初始欠账来源。此模式符合1.5倍追赶，但没有实际 private cursor/offset/debt 证据。gasgr不在 `ProjectileVisuals` 的有限火焰 retainRate 名单；不能用“手雷先锁速、结束解锁”解释。

先跑本目录普通v2四轮，不预热、不改期限；若继续出现欠账，再准备准确冻结候选的独立诊断副本。复用 `recovery-flight-timing08` 的默认 null sink、有界数字表、结束一次导出、去掉标记插桩后逐字节等于准确候选的核验方式。**只移植插点，不复制08的旧 RemoteMotion 算法覆盖13。**

## 必要插点

1. **`GameBridge.updateRemote` 首个 push 之前绑定 actor 与 motion**：准确13在810行调用push，794/807行可能新建时钟。记录对侧ID、World/loc/motion本地数字身份、房间epoch、snap.sampleTime、receiveAt、presentationTime、roomHold/coopPaused；只在首绑定、身份变化或门控变化记录。08旧方案是在收到飞行物时才 watches(motion)，那会遗漏真正的启动欠账来源，不能原样使用。若绑定时已存在轨迹，标“启动证据不完整”，不倒推补齐。
2. **同一 actor 的 `RemoteMotion.pushTimed` 前后与所有提前返回**：复用08 op1/op2，增加本轮确有的 calibrationDebt/calibrationRate/calibrating，记录输入stamp、offset、cursor、arrivedAt、sampledAt、latestStamp，以及 reset/重复/倒序/普通接纳的数字原因。reset/settle/clear也需标记，否则会把新时钟误接为旧时钟。只读最终分支结果，不重复push/sample或改比较顺序。
3. **该时钟 `sampleTimed` 更新前后**：记录实际now/elapsed/wanted/cursor/offset/debt/rate，记录实际执行rateHeld/actorCalibration分支的数字标志。借已有分支标记，不再遍历rateOwners做额外判断。继续人物/枪口/弹体共享同一时钟，不能另建“诊断播放时钟”。
4. **首朵气体接收/首显/终止三个事件**：复用 `ProjectileFrameStream.receiveClock` 关联 event与motion；EnergyImpactVisuals只在首个 gas 事件创建、首次显示、移除处记录stream/id、firstSourceStamp/end、同一motion sourceTime与本机时间。不要每云团每帧插点；普通v2已有完整源/收到/最终显示轨迹，可与该首事件对齐。

外部驱动继续记录原生G/Part与最终RENDER；只在绑定后记录每帧首/末ENTER和最终RENDER的数字边界，避免把“没有sample”“sample推进但没到出生”“已到出生但没显示”混在一起。无需CPU采样器、每tile诊断、payload、额外像素draw或逐帧日志。

## 有界与判断

沿用已有6MiB数字表上限；仅观察两名玩家对应的时钟，不观察所有敌人/掉落物；身份变化有上限，溢出/丢记录/插点异常即诊断不完整。绑定前不灌逐帧记录；首轮结束停止诊断采样，四轮原测试仍照常完成。退出后一次导出，记录插点累计/最大自身成本，诊断版不能用于性能验收。

证据应能回答：欠账是第一个接纳的旧snapshot形成、之后小校准累积、房间门控停采样、reset/settle切换，还是仍有其它阶段未观察。只有发现cursor已越过出生stamp而显示仍等待，才应转查显示/层挂接；只有确认初始化旧锚点遗留，才讨论修初始化。无此证据不改算法，不延长任何弹体寿命、不跳时、不把气体与actor拆成不同时间轴。
