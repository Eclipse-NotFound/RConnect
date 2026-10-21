# 加入侧首次栅格绘制：只读审阅

2026-10-22。准确基线：宿主 E159（`recovery-native-travel-host-01`，SHA `e159fe0f0a1cbb34596d18b9979f439e80823fbeda369be7b2220a42e8e5d30c`）；RConnect `recovery-11/src`。未改生产、未编译或启动测试。Location、Camera、GUI 的未导出方法只以 1.02 参考源码判断；不能据此声称已验证所有外模组回调。

## 判断

有值得验证的窄方向：**只对 RoomSync 已确认正在执行共同换图、等待宿主房间状态的加入侧，延后大地图地形栅格；保留原生房间激活、显示容器、光照缓冲、相机和 GUI 初始化。** 不建议直接跳过整个 `World.ativateLoc` 或 `Grafon.drawLoc`，也不建议本轮推广到权限未定的普通分房。

“在首次绘制前导入已经收到的完整 checkpoint”不是当前正常时序可用的捷径：`RoomSync.sendReady:614` 等 `!game.isTransitioning()`，host `commit` 收到 ready 后才产生 grant；首绘发生在 `World.exitStep:1153 → Game.enterToCurLand:347 → Land.ativateLoc:1294 → World.ativateLoc:1071`，当时 `t_exit` 尚未结束。`seal/prepare` 也不是可导入的完整 grant。不要把旧房间、旧 barrier 的包提前用于新房间。

## 最小钩子建议（尚未实现）

1. `World.ativateLoc` 已先执行旧房 `out()`、替换 `world.loc`。**在它调用 `grafon.drawLoc` 前询问 RoomSync**，把是否允许延后绑定到同一 World、Game、Land、Location 和 native travel 身份；无回调、不支持、host、offline、未匹配时一律原路径。不要仅依据 `CONNECTED`。
2. E159 大地图实际走 `Grafon.drawLoc:3569 → sceneOpen:692`。保留 `sceneClear`、`loc/grafon` 绑定、`sceneLarge`、borders、`scenePrepare`、lightBmp 初始化、backdrop 索引和 `drawAllObjs`；延后 `sceneEnsure` 的地形生成。小房间路径是另一段完整绘制循环，不在这份最小提案内拆分。
3. 只跳过 `sceneOpen` 内一次 `sceneEnsure` 不够。`sceneTick:800` 还能进入 `sceneEnsure:786 → scenePreloadAll/sceneEnsureUpcoming`；延后期间这些入口必须遵守同一 Location 的 pending 状态，`sceneViewReady:2298` 必须返回 false。`sceneClear` 已清理上个场景的 warm job，不能让后台预绘绕过等待。
4. 接受 grant 后仍完整执行原 `restoreCheckpoint`，不省单位、物件、地形、掉落或墙痕。延后房不能走 `RoomTerrainView.unchanged → refresh` 的“已有图可复用”分支；它根本还没有有效地形。沿 `GameBridge.restoreCheckpoint:6305 → tileRedrawIfDirty:3509` 对恢复后的状态完成一次正常绘制，随后保留墙痕恢复顺序。完成时解除延后条件必须明确，不能因 `restoring/busy` 再次把同一次重绘延后。
5. `fresh owner` 快捷、retained/unchanged、空状态等合法 grant 分支也须有完成出口；更简单的首版范围是只给确定等待宿主共同目的地状态的 native travel 建立 pending。出生 anchor 安置后、实际 viewport 已就绪才结束加载并完成 ACK/放行；非 preload 模式 `sceneOpen` 本身不会生成首屏，不能把“drawLoc 返回”当成像素已准备好。如何接在现有帧末检查需实现时验证，不应直接多调一次 `Camera.calc` 改变副作用顺序。

## 为什么不能整段跳过

| 部分 | 是否必须先有完整地形像素 | 必须保留的工作 / 边界 |
|---|---|---|
| 原生单位与物件构造 | 正常原生顺序中本来就在首绘之前，未发现依赖完整地形像素的硬前提 | 构造顺序、随机调用和 `reactivate` 不动。`Location.addObj → Pt.addVisual` 使用 `World.grafon.visObjs`，显示层必须有效。 |
| `loc.grafon` / lighting | 不要求地形已画好，但要求正确 renderer 和合适尺寸的 `lightBmp` | `Land.ativateLoc` 返回前调用 `loc.lightAll`，`setGGToSpawnPoint` 又调用 lighting；留旧 renderer 绑定或旧尺寸不安全。 |
| `drawAllObjs:3916` | 不依赖地形像素 | 会移除并重建各 visObjs 层、重新 addVisual；不是可随便删掉的纯绘制。保留原有调用与显示事件，别借此同时做单位初始化优化。 |
| Camera / GUI | 参考源码中 `Camera.setLoc`、`GUI.setAll` 不读完整地形像素 | 相机需要新房边界；GUI、音乐、对话、背包质量与控制恢复仍按原顺序。Camera 的 CS 绘制入口必须受 pending 保护；本次宿主导出没有 Camera/GUI 全类，需后续准确回读补核。 |
| 物件恢复 / 破墙 | 核心 tile table 恢复不读像素；个别物件恢复会触发图形副作用 | 必须已有正确缓冲、显示层；保留 `die/setAct` 等原生调用，不能把它们当作纯字段赋值。 |
| 墙痕采集 | 会读 frontBmp | `WallImpactVisuals.before/checkpoint` 假定 drawLoc 已完成，不能把空 scratch 或上一房像素当当前房基线。pending 期间应保留逻辑墙痕，不做无效栅格采样；完成原生绘制后再按原顺序恢复/建立基线。 |

另一个明确陷阱：`World.step:1256` 的 `onPause` 同时挡住 `exitStep`，而 `isTransitioning` 又依据 `t_exit`。在首绘钩子直接 `hold()` 会造成等待死锁。应保留原生换图计数推进及现有 RoomSync 就绪判定，不能用 `onPause=true` 等待 grant；原生过渡期间 `Land.step` 仍可能运行，所以缓冲/显示层不能是无效对象。`RoomEntryView` 已提供等待期间的原生加载素材，不应再次调用有额外副作用的 `setLoadScreen`。

## 验证边界

首轮只验证大图、加入侧、确定共同目的地；host/offline/普通房全部应走字节等价的旧路径。需查：preload 开/关均只生成恢复后的首屏；`shelf`、破墙、门箱、掉落、墙痕与原候选相同；无灯光越界/旧图采样；出生 anchor 一致；World 同而 Game 替换、死亡、断开、失败/超时不会留下永久 pending；未换房者不进入加载。普通独立房的 owner/fresh/retained 由 RoomSync 决定，不提前偷用旧 records。

这能消除的是“先画本地、随即销毁重画宿主状态”的栅格工作。136 单位构造、原生生成、完整恢复及网络等待仍在；未实测，不能承诺总耗时已经等于单人。
