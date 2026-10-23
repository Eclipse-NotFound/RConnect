# 锚定旧房事务补丁的窄审查

只读对象：`anchored-crossing-follow-proposal.patch`，SHA256 `294656bb574094979b45b3c917f5679a7b2418b18d88c1d0b306f080110d6ee8`；对应 roomfix1 源。未编译或实测此补丁。

确定的冗余事务：宿主已有 seal/pending 时，收到 request 将 requested=true；随后同 TCP 的 READY 已包含该请求目的地，commit 成功但 requested 不清；ACK 清 pending 后 check 再次 begin，产生不必要的第二轮 barrier。应消费已被本次 READY 覆盖的远端请求，同时保留宿主实际已离开 barrierRoom 的本地待办。不能在 ACK 无条件清 requested。

`game.inRoom` 只保存/切换/恢复 `GameBridge.loc`、`world.loc`、`land.loc`，不会保存 gg.loc、Grafon.loc 或各跟踪缓存。当前锚定分支正常应只结算仍属本机的已确认旧房；不应执行 nativeFresh、roomRole 或 restoreCheckpoint。建议对此加显式拒绝条件，而非让带原生绘制、角色定位和全局缓存重置的恢复误进这个临时环境。普通 checkpoint 仍会进入单位/物品索引、切换 loot 缓存，release 还会调用 progress.prepare；不能把 inRoom 当作全状态回滚，但本次未找到这些动作单独造成具体错误的闭合链。

已分别核对宿主/加入侧在旧事务待确认时过门，以及过门已被 check 观察/尚未观察两种顺序：新 nativeRoom 与 crossingRequested 标志、ACK 后 check 的组合能够保留下一房请求，未发现确定的 pending 丢失。此结论不替代原生回归。

跟随暂停计时在解除阻塞时将 followBlockedAt 置 -1；同帧重复调用不会再补偿一次。新包在阻塞期间刷新 followSeenAt 时，max(blockedAt,seenAt) 避免给未来时间重复补偿。本份补丁仍仅 before 调用 followTeammate，after 未新增调用。
