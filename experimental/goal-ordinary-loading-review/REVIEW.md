# 普通房加载与原生等待画面：只读核查

2026-10-25。仅据已冻结源码与既有实测；未修改产品、宿主或测试入口，未启动编译/游戏。根继续分析下一次普通双人结果。

## 准确对象

- 正式 RConnect：`build/m52/recovery-room-production-05`，SWF `78C052AEA963F1689B705AE1E14D274916AE1A1F7E81933390CAF8D1A88F4699`。
- 正式宿主 A796：`A796827173AF7D6FAB9885FB66ECC62182AB5335918A30C7CCE4C44914A238B7`；本次核 World 的准确回读为 `build/m52/recovery-room-first-raster-current-source-02/source/scripts/fe/World.as`。
- 普通 all14 单人 `92ec33a932`：三程 10.431 / 5.551 / 6.897 秒；首次 exit20→19 的原生生成长帧 6.587 秒。减少 LAD/RV/CS 的单人 `7ad109f075`：8.616 / 3.968 / 4.941 秒。两次出生点、自然人口不同，不能把差值当三个模组的净开销。

## 下一双人结果怎样判断串行段

1. 按 round、map seed、room key、barrier/epoch 对齐 `RConnectTravel: prepare`、`begin`、`A22 FRAME GAP`、`A22 ROOM RECEIVE`、checkpoint/restore timing 和 `TRAVEL RESULT`。每进程 getTimer 起点不同，不直接相减两端计时。
2. 当前新地图 prepare 在原生 Land 构造选择种子时发送：早于该 Land 的生成，但晚于主侧 exit20 的原生 Loading、enterToCurLand 的保存旧物体及 Encounter。缓存地图另有 t_exit>20 的 prepareCachedMap。不能把两种路径混为同一个时间点。
3. 如果加入侧在自己 exit21/20、尚未发生20→19生成长帧时已处理 seal，可确定该次主侧已经结束其原生过渡，而加入侧尚未开始生成。反之，seal 处理晚于加入侧生成不能独自证明重叠，因为消息可能排队到稍后才处理。
4. `seal.ms` 可包含加入侧采集/编码；`ready.ms` 可包含主侧 commit、采集、编码及发送；`grant.ms` 包含解码、完整恢复、位置处理及发 ACK。`restore.total` 是其内部部分，不是整段网络时间。主侧 commit 发 grant 后已经 release，后续 `resumed` 是 ACK 到达，不代表主侧一直暂停到该时刻。
5. 对共同新目的房，检查 ready 的 freshNull/实际 capture 次数、同房同 barrier 是否重复 seal，以及各 restore 累计点的相邻差值。当前已有一次采集复用、原房不自恢复、精确 wire 复用和 READY 去重；不能再把这些已完成项列为新优化。
6. `A22.cover` 实际是 `RoomSync.entryPending` 逻辑值，不是显示树观测。普通单人不走 connected 分支的快淡入淡出；其总时长含不同原生装饰性倒数，不直接当纯计算基线。

首入已有数秒原生构造开销，减少一个 UI 层不会消除它。仍可在 RC 内优化的候选必须由上述数据证实：多余同房事务、重复采集/编码，或恢复中不必要的实际重复工作。没有证据允许删快照字段、跳地形恢复，或凭同 seed 复用画面。提前发送完整地图参数还受 Encounter 改目的地/参数的原生顺序约束，本次未证明可无条件前移。

## 现在并非只剩原版加载界面

`RoomEntryView.as:16–24,27–67,112–124` 仍建立两个 Sprite、全黑矩形和 `new visualWait()` 素材副本，再复制原素材的帧和文字；只去掉了交接文案。`RoomSync.as:87–96,133–167` 以 entryPending 在帧前后及 RENDER 维持它。stationary settled owner 的 `hold(false)` 本身不置 localEntry，因此不应因同伴过门自动盖屏。

准确 A796 的真实 `world.vwait` 在 `World.as:428–438` 显示树最底层，位于 visual/vscene/vblack/Pip/SATS/HUD 之下。仅把它 visible=true 无法盖住已经恢复的世界；删副本后不补生命周期也会短暂暴露未确认房间。

## 最小安全实现边界（设计建议，未实现）

- `World.setLoadScreen:1513–1548` **不直接 resetInput**；它会隐藏 vgui/vfon/visual/vscene、清 catPause、重置故事点击、设置文案，并在普通加载分支消耗一次 Math.random 选插图。输入清理实际在 `UnitPlayer.controlOff`，由 `World.exitLand:1116` 调用。因此不得每帧补调 setLoadScreen；也不能在故事/SATS期间把其副作用当无害绘图。
- 跨地图的原生顺序是 exit20 显示、19 生成、18/17 等故事点击、16 `offLoadScreen` 并恢复画面/声音/控制、1 打开 HUD。把 t_exit 停在16或直接设 onPause 会卡住 `RoomSync.check:171` / sendReady 的 `isTransitioning` 条件，形成互等；不是一行 UI 修复。
- 若坚持真实原生实例，建议一个由宿主 World 负责的**本次加载显示持有接口**，不要搬旧 first-raster 协议。它应令 native setLoadScreen 只运行原有的一次；在原生退出准备收起画面时记住待完成动作，让原 t_exit 继续归零；RC 仅在当前本机 entryPending 完成后要求宿主结束同一 token。这样无需把“尚在显示 Loading”误报成“原生房间仍在构造”。准确 A796 目前没有此公开接口。
- 不能只延后 `offLoadScreen`：它后面的 vgui/vfon/visual=true、vblack.alpha/cam.dblack、Mouse/Snd、gg.controlOn/pip.noAct，以及 t_exit1 的 HUD 操作都须明确由哪个阶段执行一次。否则会出现图在下层、能在看不见时操作、菜单覆盖加载或解锁两次。延后原生结束动作时需保留 native 控制语义，不用一堆 RC 保存/强写字段模拟它。
- 持有必须绑定当前 World、玩家、加载序号/目标房；只对实际换房者生效。完成、取消、断线、死亡/读档、更换 World、错误和超时须分别解除自有持有；旧 token 不得把新剧情/新读取的画面或角色重新打开。超时仍保留原错误及断开入口，不用无限隐藏掩盖失败。
- `setLoadScreen`/`offLoadScreen` 会触及 loadScreen、clickReq、story/skill/progres/lmb、cacheAsBitmap；`showScene` 又拥有 catPause/vscene。不得无条件恢复一份旧 catPause/visible 快照覆盖后发剧情；也不得跳过 clickReq==1 的原生确认。故事路径最好先明确不接管，仅普通加载接入。
- SATS 不是一张可随意隐藏的图：`Sats.onoff(-1)` 还处理 grafon.onSats、单位高亮、MOUSE_MOVE、控制队列及 HUD。当前 `forceCloseOverlays` 直接 active=false 的行为是既有代码，本次不能把它当作已证明完整的 SATS 退出。新显示接口应要求/核实原生覆盖层已正确关闭，不能临时把 vsats 藏起再恢复过期目标；也不应恢复一份旧 allStat/onPause 覆盖现有共享暂停。
- 普通横向/背景门 `Land.gotoLoc→World.ativateLoc` 直接 drawLoc，没有 setLoadScreen/exitStep，因此没有一个可简单“延长”的原生 Loading。覆盖这条路径需要单独的本机原生实例显示租约或进一步本机激活接口；不能凭跨地图持有接口宣布普通分房已处理。此边界应先保留，不能为了去掉 Sprite 冒险改故事或整套 transition 判定。

**结论：**可以删掉独立黑底与素材副本，但仅删 UI 类不能保证安全；可靠的原生显示持有需要一处明确的宿主生命周期接入，以及 ordinary-room 无原生 Loading 的单独处理。它不应改变恢复内容、等待门槛或让未换房者暂停。本轮只确认边界，不主张立刻修改 World/RoomSync 以换取外观上的“无交接”。
