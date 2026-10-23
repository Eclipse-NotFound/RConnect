# roomfix3：常驻开销与交接生命周期复核

2026-10-23。只读检查实际编译输入；未构建、运行 AIR 或部署。本文件不替代根会话正在进行的原生计时和背景门回归。

## 输入

- 候选：`build/m52/recovery-room-production-03/RConnectMod.swf`，SHA-256 `43277b92dc5e556702d64754c6976dd10a032008719851b71bbeb566d3104011`。
- 基线：`build/m52/recovery-aura-offline-01/src`，正式 aura1 的冻结来源。
- 实际字节对比恰有 11 类变化：MapGeneration、RoomSync、GameBridge、NativeRoomState、NativeTileState、RoomTerrainView、TerrainSync、RoomCodec、RoomEntryView、RConnectMod、RConnectModDomains。其余类保持；Session、PeerGrip、TelekinesisVisuals、PlayerBodyEffects 未随加载改动变化。compile.json 实际记录 compiled、sources_unchanged、installation_unchanged 均为 true。
- 本次重点实际 RoomSync SHA `1c5ac8d9c761c40d0908a2c048062a7b09f604c6b9fa34272cae27e27c52a848`，RoomEntryView SHA `4cb479f39262f631b834c6290f78fcaec3b3cc102bb56f9886a71791a05efe0b`。

## 一项应在交付前处理的确定开销

**RoomCodec 的详细计时日志不限于房间交接，会进入普通枪击墙面的高频路径。**

实际候选 `src/rconnect/net/RoomCodec.as:12-29,34-48`：pack/unpack 每次建立 timing 对象、连续读时钟、序列化 timing，分别无条件调用两次 Log.d。aura1 没有这些日志。

实际且未改动的 `src/rconnect/game/WallImpactVisuals.as`：

- 236：每个发生变化的墙面格将像素 words 数组交给 RoomCodec.pack。
- 285：接收解码逐格调用 RoomCodec.unpack。
- 312：保护本机待确认墙痕时，再次解码 pending.cells 的数据。

`src/rconnect/core/Log.as:37-47` 每条日志都同步创建 FileStream，打开文件、追加、关闭。因此同一格的编码/解码至少新增两个主线程同步文件写入序列，pending 保护路径还可重复。数组不会进入 compact 的地形遍历，却仍执行完整诊断。墙痕缓存也不能消除每次内容改变后的日志。

这是静态可证的新增开销，**不是对用户卡顿的实测因果归因**。最小建议：生产版去掉详细 codec 计时，或明确只对真正房间 checkpoint 开启，数组路径连 timing 对象与时钟采样也跳过。若保留房间计时，不能仅在日志末端判断数组而保留全部高频分配。原冻结候选和计时证据保留。

## 其他常驻路径

- RoomSync 的两个 ENTER_FRAME、一个 RENDER 监听及联网每帧 invalidate 均继承 aura1，没有新监听或逐帧整房重建。
- before/after/present 的 refreshWorld 是查 World.w 与当前 gg/loc；不能把调用次数直接等同于敌人或地图扫描。新增 prepareCachedMap / advanceSharedTravelFade 在无旅行时早退。
- 新 sceneMode 接入 readWorldInfo。CS 类成功解析后缓存；实际 state(land) 为按 Land 查表，未见实体/地形遍历。CS 缺席时查找会重复枚举有限 loader 表，这是小的额外成本，尚无实测证据把它列为当前性能首因。
- NativeTileState、RoomTerrainView 的全地形循环位于 checkpoint/restore；TerrainSync 常驻更新没有新增全图循环频率。
- 加载画面仅 entryPending 时显示，复用 scene/SATS 两个克隆；本地化仅资源 marker 情况读取 Res，不调用 World.setLoadScreen，不修改原生加载文本。不新增持续计时器。

## hold / ACK 收尾

本次静态复核未发现新增无限持有或每帧重复 checkpoint 的确定路径：

- 不变房 owner 可 hold(false) 继续模拟；真正冻结首次保存 onPause，release 恢复并清 roomHold、pauseWorld、localEntry、fresh/held 引用。
- 主侧 commit 可提前 release，但 pending 保留到 ACK；45 秒 watchdog 同时覆盖 busy 或主侧 pending。ACK 清 pending、release 后同回调 check，已有新过门请求不会漏到下帧。
- READY 只消费相同房间、地图、坐标、stage 的请求；本地主侧已跨房或远端新目的地保留排队。新 sendReady 记录本次宣布的 nativeLand/nativeRoom，防止下一帧重报同房，剧情限制路径仍留给 check 返回。
- seal 绑定 barrierRoom/barrierLand。交错过门只能在旧 settled owner0 且记录有效时作 scoped commit；该路径显式禁止 nativeFresh、restore 和 roomRole，原生三指针恢复后再冻结新房。
- 加入侧旧房 unchanged grant 以 settledRoom/settledKey 验证；新房已发的 request 不重复补发，ACK 后新房保持冻结等待自己的事务。
- reset 恢复暂停、清房间/地图/事务/跟随/加载界面引用。错误路径故意保留暂停并提示断线恢复；不能把它当成功收尾，也未发现成功路径遗留 restoring。barrier 引用至下一事务/reset 最多保留一个，不是逐次累积。

结论：当前确定应处理的是共享 RoomCodec 的无条件诊断 I/O。其余所查常驻和生命周期变更未见新的确定阻断；这不授予整体性能、大图耗时或背景门资格，仍以根会话同源实测为准。
