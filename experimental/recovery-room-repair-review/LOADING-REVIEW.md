# 正式房间加载与最小移植复核

2026-10-23，只读审查。未编译、未启动游戏、未改产品或安装文件。实际比较的正式来源是 `build/m52/recovery-aura-offline-01/src`（0.2.24-aura1），不是实验恢复整包。以下结构原因由准确源确认；本次用户所见的具体“房间不同步”尚无新一轮原生复现，不能把所有风险都宣布为实测根因。

## 当前确定问题

|正式源位置|确定行为及影响|
|---|---|
|`GameBridge.readWorldInfo:1957`；`RoomSync.observeHost:199`|worldReady 必须原生 isTransitioning 为假；observeHost 明确拒绝 worldReady=false。正式 MapGeneration 只有已完成种子入口，无提前目的地协议。加入侧通常等宿主原生加载完成才开始跟随，不能靠换加载图案消除这段串行。|
|`RoomSync.check:146`、`begin:181`、`handle:340`|切房时先等本机原生过渡结束，再 seal→ready→grant→ack。seal 到达加入侧，亦要等其原生过渡完成才能 sendReady。|
|`RoomSync.hold:95–108`、`entryPending:76–79`、`present:84`|busy 同时代表全局交接事务和本机待加载；hold 无条件设置 roomHold/world.onPause，present 只要 busy 就画“房间交接中”。因此未换房的玩家也暂停/盖屏，源码可直接解释。|
|`RoomSync.commit:403–408`|新房先 checkpoint，随后因 !ready/settledRoom 变化把刚采的同一原生状态 restore 回自己。`GameBridge.restoreCheckpoint:6199` 包含对象、地形、单位、掉落重建及显示整理，不是便宜的确认标记。|
|`RoomSync.sendReady:377–386`|共同进入同房时加入侧仍 capture/pack 一份 fresh；宿主已有该房 records 时不用这份 fresh。已存在的 sameCapture 优化只消除同侧第二次 capture，没消掉此类无用新房快照。|
|`RoomSync.commit:426`、`handle:335`|主侧提交自身权威状态并发 grant 后仍等对侧完整 restore 与 ACK 才 release。这段等候不是主侧自身原生加载所需。|
|`GameBridge.followHostWorld:1999/2035/2064`；`RoomSync.handle grant:349–358`|有 8 秒跟随冷却；跨图后立即 setPos，但原生入场尚可能重放出生；同房仅距离超过 300px 才一次对齐；正式 grant 完成后无本次旅行固定出生锚点。因此现实现不保证双侧最终同出生。|

`roomKey:6141` 已包含地图 ID、landProb 和 xyz，不能把背景房的差异简单归因为漏掉 landProb。实际 seed/epoch 还必须一起匹配。正式 grant 只核 barrier/epoch/key，没有在消息入口绑定原 World/Game；同一个 World 换档重建 Game、迟到 grant 先于下一帧检查时存在把旧状态写入新角色环境的风险。该风险可由代码推导，不是本次已复现证据。

## 最小移植顺序

1. **先修普通房本机状态与遮罩边界。** 以正式 aura1 为祖先，逐方法取 room19 的 `localEntry/restoring/currentSettledRoom`、`hold(freeze)`、begin 的本机变化判据，以及 sendReady 的 keepOwner 与 commit 的 unchanged。未换房且仍持有该房权威的一侧不冻结；需要交接权威、进入未确认房或失败仍保持保护。`busy/pending` 保留为事务控制，不能直接删除。room19 的 canSyncWorld 仍有 !busy：仅恢复本地显示不等于屏障期间继续发送世界状态，不能扩大该结论。
2. **消除已证明的重复恢复并固定入口。** 取 `commit nativeFresh→roomRole(true)`；同目的地不发送未用 fresh；只在“同对象、一直冻结、完全相同已验证 wire”时使用 retained。后者依赖 GameBridge 的窄 retained 还原接口，不能直接传当前正式版不存在的第四参数。共同旅行 seal 固定锚点，grant 完整恢复后通过 TravelPlacement 放置，不能跟随宿主后来移动的 worldstate，也不能强制普通分头探索一直同房。保留死亡、唯一掉落、门箱、地雷和地形全部状态。
3. **统一显示原生加载素材。** 可复用 room19 的 RoomEntryView：使用原生 vwait 同类素材、文本/图案/剧情状态，删除自定义交接文字；不调用 World.setLoadScreen（它还改输入和游戏可见状态）。这只是等待期间的显示替换，不冒充原生流程本体，也不能宣称等待已消失。未换房的一侧不生成该等待视图。
4. **整图并行单独接入。** 若要突破正式版“宿主 worldReady 后加入侧才开始”的依赖，需要 NativeTravelPlan/种子 prepare 与精确 Game 原生桥，并处理冷固定图、缓存、同 ID 新探索、Encounter、旧事务和 World/Game 替换。大场景进一步采用 early2 的 constructed/first-raster 票据时，还必须有 World 退出流程桥及准确 Sand003 旅行暂停接口；不能只把 RoomSync 提前设 ready。保留 early2 的关键修正：TravelGuard.endTravel 延至真正 completeEarly，而非 grant 时撤掉尚在执行的原生退出许可。该分支不应夹带恢复22的武器、墙面、运动等未逐项验收改动。

room19/early2 的完整 GameBridge、Session 不可覆盖正式源：正式源还含已独立部署的离线采集与光晕修正。提议只取上述方法/必要字段，另冻结候选，依实际新输入重做准入。

## 现有可复用验证入口

- **普通分房/旧房进度/静止同伴：** `build/m52/recovery-entry-observer-driver-01/entry-room/EffectsDriver.swf`，SHA `bf6c9567010d93dd20b334df3da7ed069e168583a2f45868a8d4352bc0e553ba`；prepared SHA `ae5c4035054e4474baa94a1003b0d9a32261bc8df82be0edd09255bdc69abc55`。准确源码 `tests/RoomCooperationTestDoc.as` 108–110 已检查 stationary host 的 entryPending/roomHold；其后覆盖分房、合房、权威更换、HP/武器弹药/死亡、墙体物理、容器掉落、新层和挑战回返。复用 `experimental/recovery-room-entry-observer/run_native.py` 的 driver 验证与 `recovery-first-raster-native/run_native.py --scenario entry-room` 原框架；现有 `recovery-ordinary-wall-sv-rooms/run_native.py` 提供明确覆写产品/宿主的薄接线例子。**其 C6A3/host05/EB365 准入不是当前 aura1 资格，须独立新绑定，不能伪装历史安装。** 此驱动不单独证明背景门全状态或单人加载耗时。
- **同一大场景首进→基地→重访、真实操作与出生：** `build/m52/recovery-early-sandy-scene-driver-01/scene/EffectsDriver.swf`，SHA `dc9232de71ae17a89b0d0e4972430ee5fdccf8c1787481c988cc1ce69b003680`；prepared SHA `71b52bc512526ca714038e594d32b729ebaa4216164d70bf75197c7125a0079a`。已有 `experimental/recovery-early-exit-native/run_native.py --scenario scene [--solo]` 支持同字节驱动双人/单人，保留 1000ms 无输入基线/真实 KEY_DOWN、KEY_UP、身份和 95 秒防挂死，不把防挂死期限当性能目标。入口固定 D356/2D/Sand003/RV7852，不能直接用于新候选而跳过实际输入准入。
- **首次非随机整图：** `experimental/recovery-native-travel-tests` 已有 raiders→rbl→raiders 的原生 beginMission/gotoLand 驱动与同出生/计划真实 adopt 检查。其 manifest/compiled 资格应选现有实际产物，不因 README 有命令就认为所有模式已运行。

无需为此复制另一套大框架。优先跑现成普通房套件，再同一准确组合的场景双人/solo；新准入只调整确实改变的产品/宿主与安装指纹，所有原断言及错误检查保留。

## 现有并行候选的真实性能边界

已复核实际 `recovery-early-exit-scene-dual-01`（6b322acc0f，主47/0、加36/0）与 `...scene-solo-01`（981583ffbc，35/0），二者使用相同上述 scene driver 和 D356/2D/Sand003/RV7852。就绪 elapsed：

|流程|主侧 ms|加入侧 ms|solo ms|
|---|---:|---:|---:|
|首次大图|11659|11934|7051|
|基地|2223|2469|1968|
|缓存重访|6922|6861|3370|

这些是各轮实际值，不是改善百分比：solo 与双人入口/单位工作量并非完全相同（solo 约161.8,4320；双人约1160,4800），不能授单人耗时合格。双人出生差约1px并有真实操作，证明该样本未卡死，不证明所有旅行正确。

更早独立拆账 `recovery-early-first-load-review` 已指出主 checkpoint425ms、加入 restore1634ms，其中 terrain531/units719ms；二者含在 handler 内不能重复相加。实际宿主绘制与加入 grant/restore已有重叠，不能把两个 ensure 区间不重叠称为整个加载串行。旧负优先级约2秒尾段还有外部模组工作，不能全归网络；本次不扩外部模组优化或采样。

## 准确输入指纹

- aura1 SWF：`df0fa0e2ca952e77e5132e75d71e73558dc919c7b8cdeba5da05fc9e94dc01e7`。
- aura1 RoomSync：`536f587088965ee6f38147d11f2a07723e4c78c48062ad618814cd1f40b36163`。
- aura1 GameBridge：`df23182fdd362fba529b962220329bd60499efca0ee7c8ea8f2033372e84e192`。
- room19 实际移植来源为 `build/m52/room-entry-fast-19`，SWF：`051240012891ab8e6e41d30d8fb13ab16d120f41c5d9578a84a9146906257fea`；RoomSync：`2424076a73d5b563f15d71690c182b5db0cccb90ea8d132b3e9ec08863847a70`。先前此处误列另一份 `build/m52/recovery-19` 的 B9CD…EA5，不能用它表示实际供体；准确信息以本轮 `experimental/recovery-room-production/prepare.py` 的 ROOM 路径与硬校验为准。
- early2 SWF：`d356483f927c608b5973982558127ce4feb0873a36676909ed3b3d6ac8b7acb3`；RoomSync：`b2b6a3785cd60f9cb08fb48d52e3cce3a757d474dde35d4f0903d47fe7bac51e`。
- 上述 early2 实测宿主：`2d415dd373236fff3c7a691db4eff8327a6de97b91c23d8a818ec77082b3dd29`；Sand003：`3e220b595f54249c82fcad36e1b13364c0456c4e8b5f4e20f876c3964c7d331c`；实际注入 RV：`7852f61e083993e69431d5d8ca2fdf3c07d4068715946d04b3e796cecbe86764`。这些是历史运行输入，不代表当前安装已相同。
