# 恢复后首帧：重复失效只读审查

2026-10-22；依据已完成的 `build/cooperation/2e09dd2325` / `build/m52/recovery-room-restore-native-01`。没有新插桩、运行游戏、编译或修改生产。结果资格与完整时序见 [原诊断分析](../recovery-room-restore-diagnostics/runtime-review.md)。

**结论：首次 grant 的确会经 RConnect 触发一次完整地形重画；当前大地图宿主会因此清空已画分块，已安装的 WallBlend 同步丢弃材质缓存，后续帧重新构建。这条放大链可从准确源码确认；但尚不能证明首次重画“不必要”，也不能把第一帧的 1719ms 全归给 WallBlend。重访已经成功复用地形，却仍有后续长帧，所以仅阻止这次重画不能承诺达到单人耗时。**

## 准确输入

- 诊断候选 B944… 来自冻结 recovery-07/C9F649，当前 recovery-09 中 GameBridge、RoomTerrainView、TerrainSync、ExplorationSync 与 07 字节相同；涉及墙痕的判断专门回读 07，未拿 09 的后续墙痕改动解释旧运行。
- 原宿主 `BEFCF050…F9B82A`；测试宿主是只改 Game 的 E159 候选。使用 `build/m52/recovery-native-travel-host-01/after/scripts/fe/World.as` 和 `fe/graph/Grafon.as`；两文件与该构建 before 回读字节相同，SHA 分别为 `f9b5d270ad95a223ca37b0e339dcee1380856dff6254a5b1a0d9b12d997aaf16`、`09ff2387e744acb9716ae6760de2f8a1c49963da76ae97d072d1bcb759ab6ef3`。这是代表类回读依据，不是全部 ABC 语义审计。
- WB 安装及 `ContinuousScene/build/generated/wb-motion-source/WallBlendMod.swf` 均为 `14112DA0…C0920D`。使用该 generated 目录，部署来源见 `WallBlend/state/deployment-scene-v082-20261020.md` / CS `deployment-v082.json`。source-manifest 的 13 份源码哈希按 LF 文本生成，磁盘现在是 CRLF；逐文件将 CRLF 规范为 LF 后全部精确一致，原字节哈希并非一致。没有使用 WB 根 src/开发 HEAD。
- RV 安装和 `RealisticVision/build/regression-recovery-output/production-singlepass/RealisticVisionMod.swf` 均为 `7852F61E…BE86764`；该目录 manifest 中全部 6 份源码原字节哈希核对一致。
- 本次只读回查时实际安装的宿主、WB、RV 仍与上述指纹相同。

## 可以确认的触发链

1. `TerrainSync.restoreCheckpoint:35–45` 完整还原后置 `dirty=true`，即使最终像素输入相同；由外层 `GameBridge.restoreCheckpoint:6221–6309` 的 RoomTerrainView 决定能否省去栅格重画。
2. `RoomTerrainView:44–80` 只接受同一 room/renderer、尺寸合法、无 isRebuild/isRecalc、相同样式/背景物身份及全部地形绘图输入，且外层要求没有待处理/历史墙痕。HP/visi 不参与地形比较；因此纯生命或探索值变化已经可以复用，并非一律重画。
3. R0 的 viewCapture=49ms，viewCompare=4ms，无 terrainReused/viewRefresh；结合已记录的完整 restore 返回，走的是 `tileRedrawIfDirty → World.redrawLoc → Grafon.drawLoc`。现有记录没有比较失败理由，4ms 不能说明具体是哪格、哪字段或哪个标志失败。
4. 准确宿主 `World.redrawLoc:1102` 调 drawLoc。`Grafon.drawLoc:3576` 对 240×125 大地图进入 sceneOpen；`sceneOpen:692–721` 无条件 sceneClear；`sceneClear:485–506` 发 `continuousSceneBeforeRasterClear`，销毁全部 sceneChunks，并清空 warm/backdrop/culling 状态。随后 sceneTick:800 按视口再次 sceneEnsure。已加载分块即使内容相同，也不会按 Tile 相等自动留下。
5. 准确 WB `WallBlendMod:62–68` 监听该 clear 事件并清 sceneCache；`SceneBlendCache:43–65` 释放 passes/composite/overlays。下次 -100 ENTER_FRAME 的 update（Mod:205–218）对新 surface 建 passes/贴图。Cache:106–110 仅在同一 surface 且 revision/settings 相同才跳过；可视块不走离屏 6ms 延后分片。故全量地形重画可以把更多材质准备推到后续帧。
6. R2 viewCapture=59、compare=55、refresh=50ms，明确 terrainReused=true。refresh 只恢复轮廓、setLight、drawAllObjs、cam.setLoc/gui.setAll；没有 drawLoc/sceneClear/continuousScene 失效事件。不能把 R2 的长帧同样解释成 RC 清空分块。

## 排除与保留未知

- 相同普通 tilePatch 并非每次都重画：TerrainSync.apply:201–237 比较 before/after；HP-only 不 dirty，完全相同值不 dirty，真实破墙优先原生 tileDie。`applySceneState:3121–3135` 也仅在门实际开闭状态不同时 setDoor/置 isRebuild。没有发现“每个积压快照无条件清掉地形”的路径。
- 已安装 RV `onFrameInner:920–925` 只按 loc 身份变更 resetRoom，没有监听 continuousSceneBeforeRasterClear。`scenePrepareOcclusionFast:1449` 比实际遮光/拓扑；`RVWallSurface:99–129` 按 loc/视口范围及逐格形状失效，没有按 native Bitmap 身份直接清全部 FOV。RC 的重画会造成新的地形像素、灯光或摄像机状态供 RV 读取，但不能直接等同“同一个房间被 RV 再 reset 一遍”。
- RC ExplorationSync.context:115 对宽/高大于 200 返回 null，本轮宽 240 的地图不走共享探索 API capture/merge；因此不能把这里的全图 RV 重算归到共享探索反复 merge。这个尺寸范围是否符合产品目标属于另一个已存在的问题，本次未扩改。
- R0 首完整帧总间隔 3407ms，其中 priority0 范围 1378ms、priority0 后至 RC mask 前 1719ms；WB -100 位于后一范围，但其中还可能有其它监听器。没有逐模组 CPU/调用计数，不能把范围值当 WB 的净耗时。
- R2 第二帧 Stage 仅70ms，render.bottom→下一 ENTER_FRAME 仍1354ms，并无该帧 applyUnitsSync；已有复用仍未消除调度/渲染等长间隔。R0/R2 恢复后还有已确认的镜像积压，见原报告；不与这里嵌套计时相加。

## 一个明确但有限的 RC 重复工作

07 的 `GameBridge.tileRedrawIfDirty:3512` 完整重画后会 `_wall.redraw(loc)`；同一 `restoreCheckpoint` 结尾又 `_wall.restore(loc,s.wallPaint)`。`WallImpactVisuals.restore:480–485` 最终再次 redraw；`redraw:505–509` 在 active===loc 时两次都 replay 并重新 clone shadow。两调用之间没有退出到下一帧；最终墙痕恢复覆盖前一次传输状态。这是源码上可复核的重复墙痕回放/影子图复制，但不是第二次 Grafon.drawLoc，也没有证据表明它解释 3.4 秒首帧。

最小后续优化方向只考虑在**完整 checkpoint 已校验的路径**把最终墙痕回放/影子图复制合并为一次，普通 tilePatch/redraw 路径保持原样；验证无墙痕/有墙痕、旧房回放、错误 checkpoint 和 active 切换后像素与异常顺序一致，再量 replay/clone 次数及耗时。本报告不实现，也不保证收益。对首次整图 sceneClear，先需要准确的复用失败原因，不能直接绕过当前保守条件或删除 isRebuild 检查。
