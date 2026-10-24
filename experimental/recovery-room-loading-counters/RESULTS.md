# 首次大图交接与随后两帧：实测结果

2026-10-24，根会话运行 `build/m52/recovery-room-loading-counter-native-04`，原运行 `0c357d93b5`。原三程功能检查和三个有界观察窗口均通过；这是诊断版本，**没有生产性能资格，不部署**。产品 `1F268236…72AB` 基于准确 roomfix4，宿主 ABE2、RV 0DBE，原全组合和 240×125 场景，未关闭三个模组。

此前 native-01 是内存不足；02 在启动前发现用户游戏；03 在主侧启动后出现外来 AIR，因此没有启动加入侧。本次 04 才是完整有效计数。失败记录保留，不能把缺少 join.log 或 CS 初始化记录归咎于模组。

准备历史也保留：product-01 因 AS 编译器对 try/finally 的返回分析失败；product-02 只补不可达返回，剥离探针仍与原正文相同。实际产品完整 SHA `1f268236eae5b363fe057c9b01a3b6d7821e9be46443cddac4deb08297ca72ab`，原外部 driver-01 `77d5eca08be0d7dc35acd6b5b7591c75e179ea4e948d667af5e82dcf6dcf81a5`。旧 native-01 的 30 秒内存记录仍保存在原目录，不改判。

## 实测分段

| 加入侧阶段 | 耗时 | 证据与限制 |
|---|---:|---|
| 首次 grant 回调 | 2262 ms | 包括解码、状态恢复和回调；恢复内部累计 total 为 2047 ms |
| grant 返回到首个 ENTER_FRAME | 1105 ms | 其中 unitsync 14 次合计 520 ms，worldstate 36 次 163 ms，暂停等另外约 2 ms；其余不能全部归网络 |
| 首个 ENTER_FRAME 到 RENDER 结束 | 3236 ms | priority 1→−1 为 1312 ms，−99→−101 为 1674 ms；这两个区间是监听器区间而非精确函数归因 |
| 第二个 ENTER_FRAME 到 RENDER 结束 | 234 ms | 同区间分别 168 ms、2 ms |

首次 grant 中，MirrorMasks.restore 18 次合计 159 ms；maskReferences 的最外层调用 5 次、遍历 80,920 个节点、合计 158 ms。首帧的 MirrorMasks.capture 为 29 ms，maskReferences 为 22 ms，bitmapSignature 为 4 ms；**不能把首帧 3.24 秒主要归因于遮罩签名扫描**。

首帧 RConnect.onMirrorFrame 为 150 ms，onVisForceFrame 为 47 ms；第二帧分别 12 ms、3 ms。函数计时包含内部调用，不能相加后再叠上阶段区间。TcpLink 外层解帧/AMF 不包含在网络回调累计里。

当前源码中 WallBlend 注册在 −100，RV 与原主循环等注册在 0；这只是下一步定位线索，不能把整个区间都当成某一模组函数的独占耗时。没有据此修改其他模组。

三程诊断完整耗时，主侧 10.499/6.537/5.241 秒、加入侧 16.757/7.166/8.372 秒。它含计数探针；不用于替代无探针生产候选的资格测试。普通房关闭三项的另组结果见 `../recovery-room-reduced-runtime/RESULTS.md`，不与这里混算。

## 后续选择

- 已证实 grant→ACK 窗口仍积压状态，但两个消息夹带短期攻击/特效事件和分批地块。直接只留最后一包会漏内容，暂不这样修改。
- 返程 rbl 的 restore role 累计为 2519/2643 ms。角色切换会退休旧代理，可能重复扫描大图显示树；尚不能把整段全部归它。先验证一个严格等价的小改动：当 nativeMask 已脱离，或显示对象仍持有自己的 nativeMask 时，不执行不会被读取的首次引用扫描。退休遮罩的剩余引用检查保留。
- 连续大场景仍未达到相应原单人耗时。普通房通过、组件通过及遮罩替换外观均不能替代这一目标。

完整原始证据：上述 native-04 目录中的 `counters-result.json`、`join-room-loading-counters.json`、`result.json`；原 run 目录的输入清单、日志、内存与登记回执。正式 22 项及绑定源码均未改变，自有运行副本已清理。

结果 SHA：`counters-result.json` 为 `de183c21e81047a31f6a35f963c423a1b8b913b800566eeca34dc188025bb5f9`；原计数为 `0e7e25c00e81341ac9156cd102e36fc110c26512e6a6f00fad16ee2e0d44e841`。


## 首次恢复触发重绘的代码补核（2026-10-24，独立只读）

核对准确 `build/m52/recovery-room-production-04/src`。`GameBridge.restoreCheckpoint` 在对象协调前尝试保存 `RoomTerrainView`，完整恢复后仅在视图检查仍相同才清除 terrain dirty；否则 `tileRedrawIfDirty → world.redrawLoc → Grafon.drawLoc → sceneOpen → sceneClear`。大场景的 `sceneClear` 会退休原有分块、替换 `sceneChunks`，随后创建新表面。准确 WallBlend 14112 的 `SceneBlendCache.update` 以这些 surface 对象身份建立缓存，因此旧对象消失、新对象出现会使相应层重新建立。这里证明调用与失效链，不把 −100 的整段 1674 ms 当成 WallBlend 独占耗时。

原 0c357d93b5 加入侧日志第 45–49 行记录五次对象注入：doorboss B151、doorprob B207/B341/B490、exit B469；第 56 行首次 random_mane restore 没有 `terrainReused`，重访第 119 行则为 true。五次注入不能证明 30,000 格都改变，也不能仅凭缺少 terrainReused 就判定 `unchanged()` 的具体失败分支：视图可能在入口条件处未创建、构造时无效，或者比较时不相同。

门的可确定影响如下：

- `GameBridge.as:3029–3030` 构造缺失 Box 后，在 `door>0` 时调用 `initDoor`。原生 Box 构造器遇到门定义也会调用一次该方法。`Box.initDoor` 按实际占用格改写 `front/phis/opac/door/mat/hp/thre`，本方法不设置 `loc.isRebuild/isRecalc`。因此，注入若把某格的 `tile.door` 从 null 改为对象，`RoomTerrainView.tileInputs` 的最后一项 `door!=null` 会不同；若原来就有另一个门引用，则这一布尔项可能仍相同，不能以换了对象直接断言失败。
- 完整 `NativeTileState.restore` 只写原生标量字段及 `setZForm`，不会把 `tile.door` 对象引用恢复为空；门初始化造成的引用存在性差异可保留至检查。但前景、碰撞、材质等标量随后可能被完整地形快照覆盖，不能只看初始化的暂时写入就认定最终不同。
- `GameBridge.applySceneState:3133–3142` 仅在存活、无 inter、门类型大于零且实际开关不同的条件下调用 `setDoor`，随后明确设置 `isRelight=true; isRebuild=true`，打开和关闭皆如此。原生 `Box.setDoor` 自己只在打开时设置这两个标志。只要此标志留到比较处，`RoomTerrainView.unchanged` 就在入口拒绝保留；该门路径没有直接设置 `isRecalc`。死亡对象另走原生 `die`，属于单独情况。
- `_objects.clearRoom` 只重置编号映射，不删除房间对象或直接改地形；`roomRole/resetBaselinesIfWorldChanged` 本身没有完整重绘调用。当前 roomfix4 的单位接收是 `GameBridge.applyUnitsSync`，没有独立 WorldUnitSync 类；不可把别的候选类名套到本次。

准确宿主 ABE2 的实际 XML 已核 `Box.initDoor` 方法 1114 与 `Box.setDoor` 方法 1115 的字段引用，分别无重建标志、仅含 isRelight/isRebuild，与原生阅读源码吻合。方法 code SHA 分别为 `aa7b8c984df95b8b646b914d29e71e00aa21d316319892264b240cabf21fdb36`、`41ae7fd3d331f2e3734edae0cc062c61a7b594c08d8ff810c84033151d26d0d2`。阅读位置为 `game-reference/decompiled/1.02/src102/scripts/fe/loc/Box.as:653`，生产调用位置如上。现有日志没有五个对象的 door/inter/open 值、比较前标志或首个失配格，故**尚未证明本次首先失败的是门存在性、重建标志，还是其他地形/背景输入**。

若后续需要一次定向取证，只应记录首次未保留的原因：入口是否允许创建视图（dirty、incoming/existing wallPaint、retained）、构造有效性和 room/renderer 身份、恢复前后 isRebuild/isRecalc；比较阶段记录首个失配类别及其坐标/字段/前后值（style、backdrop、tile），不输出全图。尤其应区分 `door!=null` 与 phis/front 等标量。当前没有新增此探针或修改判断。

## 现有宿主增量接口的覆盖边界

当前 ABE2 的实际 `pfe.xml` SHA 为 `ee33ce0282c1dfba7bf7ae03d1e7646383dccf79ea1252f9792a57344e1208cf`，已逐项核 Grafon 的公开方法。BEFC→80CF 的严格审核只允许 `Location.lighting`，80CF→ABE2 只允许 `Camera.calc`，均没有新增类成员，因此 Grafon 的相关逻辑仍可对照 `build/m52/recovery-native-travel-host-01/after/scripts/fe/graph/Grafon.as`。

`drawWater/decal/gwall/paint` 在 `sceneLarge && !sceneRasterizing` 时进入私有 `sceneApply`（阅读源码第 1053 行）：只在相交的现存块上写原 `nativeBuffers`、递增 revision，保留 surface 身份。但它们是特定绘画/水面动作；decal/paint/gwall 还带操作历史，decal 会用随机值，tileDie 又含粒子等副作用。它们不是从完整恢复后的任意 Tile 状态重建墙体、背景、轮廓和材料的接口，不能拿恢复后的快照逐格重放这些动作来代替 redraw。

`sceneTick`（第 800 行）只补齐视口所需块，私有 `sceneRender`（第 724 行）遇已有 key 直接返回；`sceneSurfaces`（第 394 行）只返回现有对象引用。`drawKusok/drawBackWall` 依赖内部绘制上下文，没有独立的块失效与重建契约。准确 CS 7F1F 的 `ContinuousSceneMod.as:39` 动态 nativeAPI 也只有地图、出生、奖励、活动等入口，没有通用分块重绘口；本次读取源码 SHA 分别为 ContinuousSceneMod `d97c62521892dbf46dbac9d38bfe6cb721fb49d0f8fea5cfea4b5e796851c450`、NativeSceneAdapter `6541c722618dec9bb637ba6082a950cc4a01029b1eb01b65d992516d1d7b90c3`，与 7F1F 清单相符。

结论：有保留身份的特定增量画法，**没有供 RConnect 在完整恢复后按任意实际地形差异调用的通用公开增量重绘接口**。当前可以继续依赖严格相同检查保留已有画面；一般差异仍须完整重绘，不能按相同 seed 或五个注入对象猜测可跳过。若要真正重建变化块，需要另行定义宿主接口与完整覆盖验证。本补核未修改 RConnect/宿主/其他模组源码，未编译或启动游戏；只追加本报告，既有实测数据未改写。


## 门重建标志是否导致第二次全图重绘（2026-10-24，窄链补核）

已排除这条重复重绘因果。准确 ABE2 实际 XML 中，World.redrawLoc（方法163）只调用 Grafon.drawLoc、cam.setLoc、gui.setAll，不清 isRebuild/isRecalc；Location.step（258）/stepInvis（257）见 isRebuild 后调用 rebuild（236），其正文仅 recalcWater（237）成功返回后清 isRebuild，没有再次 drawLoc/redrawLoc。

recalcWater 开始时换掉待处理列表并清 isRecalc，水体传播过程中可能再次置 true、局部调用 drawWater；末尾检查物体落脚。step 后续独立 if(isRecalc) 可能继续处理下一批水。活动房间还会先因 isRelight/isRebuild 执行照明，再清 isRelight。因此不能因 grant 中已画过一次就手工清这些标志，否则会跳过原生水体、落脚与照明副作用。本条没有可采纳的同语义整图消重修法，也没有据此改生产或添加探针。阅读源码为 game-reference/decompiled/1.02/src102/scripts/fe/loc/Location.as:2601、:3330、:3394，实际宿主方法引用顺序已独立核对。
