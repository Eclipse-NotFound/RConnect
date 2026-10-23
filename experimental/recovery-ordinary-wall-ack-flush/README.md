# 普通墙面 ACK 后单次发送候选

仅源码草案，基于真实 C6A3 产品的完整三类。没有编译、AIR、部署或性能资格。`prepare.py` 核准确基底 SHA 后复制及定向修改，生成逐行 `source.diff` 和全部候选指纹；已有目录不覆盖。`--verify` 只读核对冻结内容。

## 真实调用链及改动

客户端消息先经 `RoomSync.handle`（这里只消费 type=room），terrain ACK 进入 `Session.handleMessage`。已有 `sameHostRoom` 在 CONNECTED 下使用 `RoomSync.accepts`，要求 ready、!busy、currentSettledRoom，以及非 authority、roomKey/epoch/term 一致。此门限保持。

`WallImpactVisuals.ordinaryAck` 原先只有匹配 pending.seq、解码有效且 cell 集合完整时，才清 pending 并合成预测/已确认像素。现在只把其结果明确返回 Boolean；所有原拒绝分支 false，执行原合成后 true。不修改接收颜色、sv、版本或 ACK 内容。large 原处理与返回路径均保留，额外返回 false，明确不触发此优化。

`GameBridge.acknowledgeTiles` 保留 terrain ACK 调用，向上返回普通墙面是否真正退休。Session 只对 true 调用一次 `flushWallAfterAck`：重核当前连接、实际 socket.connected、同房/epoch/term、ready/!busy、非 authority、非过渡，再读取已有墙面队列，通过原 terrain 协议发送至当前房间权威。不调用 `flushRoomReports`，不采集地雷、伤害、地形、容器或掉落；不新增 timer 或循环。

`try/finally` 的专用 guard 阻止同步重入并保证返回/异常后解除。无 queued 时 `scanWallReports` 返回 null，不发送。发送前生成新 pending，仍必须等其对应有效 ACK；没有本地伪确认。连接关闭/编码或 socket 失败沿原 `TcpLink.fail → Session.onLinkFailed → GameBridge.endSession` 清理；不在此新增重试或恢复发送。socket 已断开但 isOpen 尚未更新时在取队列前拒绝。发送后网络未获确认不能认作成功。

这只减少“有效 ACK 已到但 queued 仍等下个 50 ms Timer”的机会延迟。现有实测没有该阶段时间，不能承诺首发或总体延迟改善。

## 组件及原生验证计划

`components/WallAckChecks.as` 直接调用候选的真实 `WallImpactVisuals`，20 项拟验证：真实 pending/queued、有效/未来/重复/旧 seq、残缺或不同 cell、坏压缩数据、无 queued、不重复消费、新旧权威 v、换角色、异房及 reset 后旧 ACK。使用既有 BitmapData/Bullet 组件载体，不用另写 ACK 模型；`session_transport_tested=false` 明示它不验证 Session/socket。原 153 项 WallSurfaceChecks 也需以同一候选 WIV 重新跑，不能用 20 项替代旧覆盖。

完整构建后的隔离原生验证仍必须覆盖以下真实 Session 路径；当前没有把计划记成通过：

1. 有效 ACK 退休且 queued 非空：同次回调最多发送一个墙面批次，原 seq 单 pending 不变；无 queued 不发空包。
2. 重复/旧/未来 ACK、坏 cell：不触发快发，不误退役下一批。
3. ready=false、busy、真实门口切房、epoch/term 变化、authority=true、非 CONNECTED、连接关闭：不消费新房或当前房 queued。
4. send 引发同步 FAILED/清理或人为重入：guard 最终解除、不递归多发、不把未确认批次记成完成。需要实际事件/可观测发送，不能只按 guard 变量名判通过。
5. 普通房双方轻机枪/等离子全部原 uint 断言保持，追加已存在的完整阶段像素时差提取；large 路径仍按旧行为，无快发资格。保留相同配置、原功能门槛和性能门槛。

本候选不改 RoomSync、TcpLink、原分析器、测试阈值、游戏宿主或安装版。若完整 Session 验证发现发送门限或失败生命周期不闭合，应保留失败并停止；不能用组件通过替代。
