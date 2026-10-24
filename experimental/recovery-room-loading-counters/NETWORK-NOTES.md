# 首次 grant 后的状态积压：只读结论

本轮依据 native-04 / `0c357d93b5`：grant 返回至首个 ENTER_FRAME 为 1105 ms，其中 14 次 unitsync 合计 520 ms、36 次 worldstate 合计 163 ms。它解释约 0.68 秒回调工作，不能解释整个首帧。当前暂不实现网络缓存，优先有证据的小改动；没有新运行或性能资格。

准确 roomfix4 中，RoomSync.commitHeld 发送 grant 后 release()，busy 清除但 pending 留待 ACK；canSyncWorld 不看 pending。Session 在宿主计时器中每约 200 ms 发 unitsync，在宿主计时器和每条 playerstate 后都调用 broadcastWorldState。TcpLink 单次 onData 循环解帧与 dispatch，因此加入侧处理 grant 后仍会连续应用已积压的包。

不可把这两种包整体“仅留最后一份”：units[].weapons 与 players[].snap.weapons 携带 events(stream/seq)、impacts、melee；玩家 port 也有短时事件。UnitPresentation.capture 会记录 endSentAt，结束后约 700 ms 退役部分弹丸历史；EnergyImpactVisuals 另有 1000 ms 保留窗口。tilePatch 最多 128 格轮转，wallPaint 也分批轮转，末包不是完整世界。完整 loots 的缺席本身是移除指令，objSpawn 和对象状态还有出生、门箱、销毁等语义。

若将来实施，最窄方案只在准确连接/barrier/epoch/key/term 的 grant→ACK 窗口、socket 写入前合并已证明为纯移动且非运动内容等价的状态。未知形状、事件、死亡/成员/装备变化等仍原样排队；先发旧缓存再发事件包，ACK 后发最新缓存并恢复原周期。伤害、掉落收据、地块 ACK、进度、抓取和时停协议保持原路。这个字段分类与顺序闭环本身有实现成本，目前收益不足以优先引入；不写候选、不取消可靠消息、不降低同步频率或画面内容。
