# 首次大图绘制延后：独立只读审阅

2026-10-22。审核当前 `experimental/recovery-first-raster`，准确祖先为 recovery-11 / E159。只读源码；没有编译、AIR、像素检查或性能资格。不修改提案目录或冻结产物。

## 具体发现与修订状态

1. **完成后重复扫描 chunk，确定的新持续开销。** 审阅版 `native/fe/graph/Grafon.as:704–709` 的 `rconnectRasterPainted()` 只检查 ticket 存在和 waiting=false，没有检查 unpainted；`sceneTick():842` 每帧调用它。`FirstRasterGate.complete():39` 只清 gate 自己的引用，Grafon 仍保留已完成的 ticket，因此完成以后仍逐帧执行 `sceneViewReady()` 的视口 chunk 循环（2331 起），直到另一个 sceneOpen 或小房 drawLoc 清票据。断线后同一大图也可能继续。不是确定帧率退化幅度，但这是首屏优化额外引入且无需保留的工作。建议在 helper 中先判断 `ticket.unpainted===true`。父会话已交作者修正并要求完成后不重复扫描的组件。

2. **不支持的 cull/preload 配置退回时必须取消旧票据。** 父会话转达作者发现：当前 RoomSync 的 `scenePreload!==true && sceneCullRender!==true` 分支直接 return null，未取消已存在 gate。独立核对这一返回确实在 `firstRaster.active` 身份核验之前。若同一目的地此前建立了票据，后续 sceneOpen 改走此分支，Grafon 会换成 null，但 gate 仍 active；grant 可以继续使用旧票据，随后无人清其 unpainted，等待不能完成。应先 cancel 旧票据，再按原路径绘制。该情形是配置/绘制重入边界，不是已实机复现；作者正在修正。

## 已核对的关键路径

- E159 `World.step():1256` 的 `!onPause` 仅包住模拟和 exitStep；`Camera.calc(gg)` 位于独立 `allStat>=1` 分支（1322–1324）。准确 Camera.calc 的 288 行调用 sceneTick。因此 grant 后 RoomSync hold 不阻断自然相机/绘制，不存在单由 onPause 引起的等待死锁。首个 sceneOpen 的新钩子自身也不 hold，原生退出计数可继续。
- grant 在完整恢复前解除 waiting；恢复后才应用 entryAnchor，记录 grantFrame，等待后续 Stage 帧和 RENDER。preload=true 的 sceneEnsure 实际执行全图 scenePreloadAll，不是先画错误出生视口再补画另一视口；preload=false 的首次 ensure 来自 anchor 后自然 Camera.calc。没有另加乱序 Camera.calc。
- gate 绑定 World、当时 Game、Land、Location、Grafon、travelId。World/Game 更换、死亡、断线和错误路径取消 waiting；不会伪造 unpainted=false。精确重复 grant 不重复恢复或奖励；ACK 在 ready 检查、补墙痕之后，仍核对 pending barrier/epoch。
- `_wall.front()` 对未绘缓冲返回 null，逻辑墙痕仍正常接收；restoreCheckpoint 禁止复用未绘 terrain 缓冲。finishFirstRaster 在 pending=false 后补逻辑墙痕。未发现新增路径主动把空 bitmap 作为已绘墙面采样。
- scope 保留加入侧、已采用 native travel、新 Land、merged 大图；host/offline/普通分房返回原路径。普通小房新增检查为常数级空票据判断；发现 1 的持续 chunk 扫描只发生在实际持有票据的大图。

## 证据边界

`nativeFrame` 是 Stage ENTER_FRAME 计数，不是实际 Camera.calc 的回执。正常 E159 顺序满足设计，但若外模组/异常跳过 World.step、Stage 仍运行，组件替身不能证明 anchor 后相机确实执行。此处未据此认定已有正常路径故障。

组件中的 renderer、chunk 实际绘制和 native对象有明确替身；即使通过，也不能证明真实 shelf/对象/墙痕像素等价。特别是墙痕在 chunk 缓冲中的最终可见性仍需原生验证；本次只确认未绘状态不会被当作已绘 front 读写。

此前 root room-component-01 对应 RoomSync `7e6323…25604`；正式 compile-01 对应下面 `355781…dbe76`（加入配置门槛）。组件 01 不能替代最新源码；修正后需要新 02 对应实际输入，不复用旧通过。

## 本次审阅输入

| 文件 | SHA256 |
|---|---|
| RoomSync | 3557818798087b84e6e7bef5d644a145273280ca6d3a15c7c5a965dfaebdbe76 |
| FirstRasterGate | c4db67de41dd3e21d6aa5949f4214cf6b8ef49521c784d85e1e95dc447745821 |
| MapGeneration | d1cf5413388382bf8517c95326fd5009c7b7510e0cde5dd409e988d4bcd1c774 |
| GameBridge | 26bb0f7cd4da7c74c83bd2657575823247196c41a861babf23bb40c17fc3cbf7 |
| WallImpactVisuals | 5629cb78bb4826d92c137c2d07ec264db716c6c80ad629369d10f87300086924 |
| native Grafon | 037a8e1e01e82221992635c22d3f7a2327c5649b85acf872ecdc0b2b1739a393 |

原生依赖读取 `build/m52/recovery-raster-dependencies-01/scripts` 的 Camera/GUI/Land/Location，其余 E159 来自 `build/m52/recovery-native-travel-host-01/after/scripts`。等待作者完成后只复核实际修正差异，不把尚未运行的组件记为通过。

## 修订复核

作者已完成上述两处最小修正，已只读复核实际源码：

- RoomSync `b1be43039e16634750ca104ebf92303a3b3757b0247df0fd0d0275bc36cf5a6f`：配置退回先 `firstRaster.cancel()` 再返回 null。
- Grafon `f335ba3257c253e480f4b4bd1992ff0d4c701cc2d2089229f3cd660b7ea5b15e`：helper 先检查 `ticket.unpainted===true`，已完成票据不再调用 viewReady。

各自只反向替换这一处源码，SHA256 精确回到上表 `355781…dbe76` / `037a8e…9a393`，没有夹带其它生产改动。新增组件明确检查 preload 与 nonpreload 完成后连续 sceneTick 不增加 readyScans，以及配置退回释放旧票据、保持 unpainted、普通完整恢复和 ACK。**这些新增组件尚未由本审阅运行；须以新 02 的真实输入/结果为准。** 两个已发现的源码问题均已消除，本轮未再发现确定阻断；上面的原生像素/真实 Camera 边界仍保留。
