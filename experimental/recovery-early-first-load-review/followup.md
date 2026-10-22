# 出生点与外部观察器的补充核查

本次仅追加独立审查材料。未编译、未运行 AIR/JVM、未修改旧驱动或生产文件。原 `evidence.json` 保持不变；early2 新轮完成情况由根会话核验，本文件不把旧 early1 时间用于 early2 性能资格。

## 同布局种子为什么仍有不同入口

准确宿主 `2D415D…DD29` 的 Game 与 Land 回读源码确认：

- 原 TimingDoc 在 round0 对单人和双人主侧均调用 `beginMission(target)`，它设 `crea=true` 再 `gotoLand`。`enterToCurLand` 因此执行 `new Land`，不是因为单人未 `prepareMap` 就重用缓存。round2 用 `gotoLand`，才允许沿用已有 Land；这两类流程不能混作一种负载。
- `rconnectSeedSource` 固定的是 Land 的布局随机流。`Land.buildRandomLand` 的模板／镜像等调用 `rndNext`，但 `setLocDif` 的敌群类别，以及部分物品、隐藏区域生成仍使用 `Math.random`。完整敌群和对象工作量并未被这一处 seed 固定。
- `Land.setGGToSpawnPoint` 先调用 `sceneNativeCall("spawn", [this])`。连续地图实际委托给 `NativeSceneAdapter.spawn`，从指定 region.spawn 中用 `Math.random` 选点；普通回退也用 `Math.random`。**两个真实入口随机选择都不消费布局 seed。**
- 双人主侧最终原生入口会被记录进 seal／grant，加入侧恢复后按主侧 anchor 放置。因此“双人彼此同入口”和“另一轮单人同入口”是不同要求。`prepareMap` 本身只发布局／等级／原生构造信息，不指定最终出生坐标。

CS 源没有借用当前 WIP 作为旧二进制证据：`build/large-map/ContinuousSceneMod.swf` 实读为 7F1F2961…6B51F，等于旧 run.json 两侧输入；其 `source-manifest.json` 的 `NativeSceneAdapter.as` 为 6541C722…7B90C3，`ContinuousSceneMod.as` 为 D97C6252…51C450，两者与当前所读源码完整 SHA 相同。部署回执也绑定 7F1F。

这条源码路径明确解释了“固定布局 seed 不固定入口”的机制，但旧记录没有当次 spawn 候选列表和选中下标，不能补写那两次具体抽到了第几个点。旧单位数组差异也不能全部归因于随机敌人：加入侧还有同步代理，需要按对象身份及类名分类。

## 可比工作量的最小只读记录

先不改变随机规则、构造步骤或旧断言。只在独立诊断驱动补以下记录：

1. `nativeAPI.prepare` 调用前：Land 是否为本轮新身份、act.id／visited／landStage／difficulty、原生格网范围、每个主层房间的模板 ID／镜像／尺寸／原始 spawn 列表。调用后只读返回 state 的 region 数、合并尺寸和已有身份；不主动再次调用 prepare。
2. `nativeAPI.spawn` 前后：Land／loc／region 身份、进入前 locX/Y/Z／prob、该 region 的候选坐标，调用返回值和真实玩家最终 X/Y；不调用 Math.random，也不替玩家选点。Game 的 `constructed` 回调后再记录最终入口和是否存在 currentCP，以识别随后入口修正。
3. 地形与实体的完整等价需要额外的一次性指纹，不能仅靠数量：按固定 X/Y 顺序记录实际 tile 物理与绘制字段；单位／对象按去重后的原生身份统计 class／id／初始坐标／装备，并单列玩家、MirrorHitUnit 和其他同步代理。只取已知公开标量，不枚举任意对象图。清晰记录读取阶段、覆盖数、上限和是否截断；截断就标输入等价未知。简短摘要用于发现差异，发生差异时保留定向完整列表，不能以弱摘要相等冒充严格相同输入。

第 1、2 项成本很小且足以验证入口来源；第 3 项属于诊断负载，可能改变旅行耗时，必须单独记观察耗时，不能让它的 FPS／耗时获得发布资格。不要把事后位置或 HP 与另一轮生成时状态比较；重访还要核对前序变更、Land 缓存身份与持久房间状态。

## 外部动态包装：能做与不能做

准确 Grafon 是 `public class Grafon`。`sceneEnsure`、`scenePreloadAll`、`sceneRegionDrawPass`、`sceneDrawRegionChunk` 是 private 方法；`sceneTick`、`drawLoc` 是声明方法。RConnect 的 `checkpoint`、`restoreCheckpoint`、`TcpLink.send` 也都是声明方法。它们不是可写 Function 字段，不能照搬 JavaScript 的实例赋函数／改 prototype。旧公共互操作知识也明确不支持游戏类原型 hook；同包 helper 对 internal 的授权不等于可以改 private 方法。

可复用的实际入口为：

| 入口 | 可观测内容 | 重要限制 |
|---|---|---|
| `ContinuousSceneCarrier.nativeAPI.prepare/spawn` | 原生合并准备耗时、随机出生前后结果 | nativeAPI 是 Object 字段，真实调用为 action.apply(null,args)，可以严格转发；不能把 prepare 当像素绘制 |
| `Game.rconnectTravelBridge` | adopt／announce／constructed／loadingHold 等既有边界 | 可写 Function 槽；constructed 在原生进入、出生和触发之后；没有真实 draw-start |
| `Grafon.rconnectRasterBridge` | 真实票据创建及同票据复用 | 已有探针实际用过；回调发生于 sceneOpen 早期，不是绘制开始 |
| `Grafon.rconnectWallBridge` 的 `raster` | 每个 drawLoc 的较晚尾标与回放工作 | 位于 sceneRestoreMarks 尾部，之后仍有绘制对象／记时收尾；没有起始 marker，不能冒称完整 draw 时间 |
| Socket DATA 和 TcpLink MESSAGE 高低优先级事件 | 收包调度中的读取／解码／处理区间 | 已有 SocketBatchProbe，绝不读走 socket 字节；仍不是纯网络传输时间 |

特别是 wallBridge：离线时生产可能为 null。不能为了得到尾标而给 null 装空函数，因为宿主多处 `rconnectWallBridge != null` 决定是否计算裁剪等，安装就会改变单人路径。生产 `networkActive=false` 又按原 listener 身份清理，外层 wrapper 会破坏这个相等判断。**因此本轮最小方案不包装 wallBridge。**若以后单独做它，必须先验证生命周期和已有非空 owner，不能靠“返回相同”宣称完全透明。

## 不改生产的下一步及其证据上限

最小安全方向是复用既有票据／Game Function 槽和 socket 事件，另在 CS Object 的 prepare／spawn 两个函数槽做有界记录。前后记录使用 getTimer + Date，内存缓冲，旅行完成／失败后输出，每段每侧最多 32 行；不截图、逐帧打印或扩展报文。dispose 只在槽仍等于本 wrapper 时恢复自己的原函数，遇到 owner 变化报诊断失效，不覆盖新 owner。

所有函数包装都必须满足：原函数准确调用一次，原参数对象和顺序不变，原接收者与调用现场一致；用 `return original.apply(receiver,args)` 保留包括 undefined/null/对象身份的真实返回；用 `finally` 做受保护的结束记录，不 catch/重建原异常、不在 finally return；观察器自己的错误不能替换业务异常。实际部署前组件要验证对象／原始值／undefined 返回、抛 Error 与任意值、参数／this、嵌套调用、记录器失败、只恢复自有槽。此处只完成源码可行性核对，**未伪称新 wrapper 已编译或运行通过。**

这些外部点仍无法提供 private `sceneEnsure` 到最终像素复制完毕的精确开始／结束。既有 `sceneDrawMs` 会被多个分支覆写，属于最后一次或局部工作值；下一帧采到它不能还原总绘图窗口。若必须准确证明双侧真实绘制重叠，只有在另一个明确诊断用宿主中加入真实入口／退出 marker，或使用带采样误差声明的现有 CPU 采样；前者需要独立源／字节审计，后者不能冒称精确边界。本轮没有新增该宿主补丁。
