# 普通墙结构版本：隔离宿主事件入口

2026-10-23。仅生成源码，**未编译、未运行 AIR、未部署，不具备完整墙沿修复或性能资格**。本目录不改变恢复22、ACC原源、正式游戏或其它模组。

`prepare.py` 核对两份准确输入后生成完整 `src/fe/graph/Grafon.as`、`src/fe/loc/Location.as`、可复核 patch 及 `prepared.json`。重复准备只接受相同内容，`--verify` 只读复核；没有构建/运行/部署入口。

- Grafon 输入：`build/m52/recovery-wall-surfaces-host-01/import/fe/graph/Grafon.as`，`625DB5C71C4319F4C942E581E039B7419DC070065DC3FB148E23003B715ABB04`。
- Location 输入：`build/m52/recovery-raster-dependencies-01/scripts/fe/loc/Location.as`，`9C7E679A4B5B8423355CB3CE07E496CAA13415BEB1FFDD630F0F2ED7B38C9CAB`。
- 调用：`python -B -X utf8 experimental/recovery-ordinary-wall-sv-host/prepare.py --verify`（从 RConnect 目录）。不使用当前更新后的参考源替换上述输入。

## 接口

新增独立 `Grafon.rconnectOrdinaryWallBridge:Function`，签名 `function(event:Object):Object`。原 `rconnectWallBridge` 字段与 large 裁片方法均未改；无 ordinary 订阅者时，`decal` 仍执行原方法体，Location 前置函数立即返回。

统一字段：`kind / grafon / loc / bitmap / bounds / token`。bounds 是房间坐标中向外取整、裁入合法 bitmap/房间后的真实艺术边界；不是 tile 数推算的矩形。结构事件额外带 `tile / prepared / ordinaryPhysical / valid / error`。

| 事件 | 位置与含义 | 返回与消费者责任 |
|---|---|---|
| `structure-prepare` | Location.hitTile、dieTile 的实际 `param1.die()` 紧前；旧 front、vid 尚在。包含旧9格可能重画范围 | 原生 die 尚未成功，不能推进 sv。回调返回对象原样成为 prepared；返回 null 则保存原 event。准备对象须保留 loc/tile/bounds/valid |
| `structure-before` | 原 tileDie 粒子已发；同次擦除、着色资产实际选帧后，首次 front 写入前 | `{allow:false,token:…}` 仅延迟本次结构的 front draw/copyChannel。普通 ink 无法通过 allow=false 被跳过。null 返回沿用原生允许 |
| `structure-after` | 本次实际前景写入成功，或被明确延迟 | token 使用 before 返回的 `reply.token`；`written` 区分实际写入与延迟。只有权威且 prepared.valid=true、当前 bitmap 匹配时可取完整最终 cell |
| `structure-pending` | 原 Tile.die 已成功，但 Location.active=false，原生本来不会调用 tileDie | bitmap 固定 null；只能保存 needsNative 元数据，绝不能读当前其它房间图 |
| `ink-before / ink-after` | ordinary 普通 decal 真实选择资产、写入前/后 | 只做有界前后差分；结构上下文不会进入 ink |
| `raster / raster-failed` | 自然 drawLoc 的原 sceneRestoreMarks 和 drawAllObjs 完成后，返回调用方之前 | ordinary 的 sceneRestoreMarks 原本直接返回，尚未重放 RC 墨迹。任何前景/背景 drawKusok 内层 catch、外层 catch 均使本轮失败；scenePrepare/tail 原异常通知后按原值重抛 |
| `ink-failed / structure-failed` | 原生前景写入抛错 | 不采合法基线，原始异常（含 null/undefined）在观察通知后重抛 |

`Grafon.rconnectOrdinaryWallErrors` 记录观察回调本身抛错次数，不能据此中止原伤害/绘图，也不能将这种候选判合格。消费端必须拒绝有该错误的资格；宿主不吞原生前景错误。RConnect 的所有权、sv、pending、恢复与 grant 行为由同轮另一隔离目录接线，本目录不代为判断。

`Grafon.tileDie` 仅新增可选第3参数 prepared，旧两参数调用保持可用。非权威接收侧 `TerrainSync.paintDestruction(t,9)` 没有旧 token 时，消费端可明确 allow=false，不创建结构代；**权威直接调用 tileDie 而无 pre-die token 是未覆盖路径，须拒绝资格，不能由旧 mat 猜 front**。

## 范围及顺序

- 结构前范围只访问目标与8邻格。它们是 `tileKontur` 的确切依赖，不表示艺术最多延伸一格。每格实际 material 的 textureMask、有效 border/floor mask、合法 kontur 0..4 对应帧1..5求并集；实际 zForm 缩放/坐标、tileFront vid/vid2及 rear 标志、材质 F、子对象变换和滤镜进入计算。不会修改现有 tile 的 kontur。
- 材质 mask 限实际原版六类 `TileMask / TileMaskDamaged / TileMaskBare / BorderMask / FloorMask / SkolMask`。其它类、无 material、未知帧、非有限范围均 valid=false，不回退整图。临时范围 bitmap 仅1×1，用于滤镜范围API，不读取/保存另一个房间图。
- 立即写入范围使用**同一次**原生实例和所选帧，复用实际矩阵以及最终 copyChannel 的目的矩形；不重新实例化随机 eraser，不调用现有带猜测 padding/整图兜底的 sceneDecalBounds。写入时保留原来的 erase→取 alpha→着色→还原 alpha 顺序，保留原生 source Rectangle 表达式。
- 为在任何前景写入前得到并集，着色实例及其帧选择提前到 eraser.draw 前；两个明确 `Math.random` 调用仍与原生同次序且各一次。原 tileDie 的 emitter、原 Location 的伤害/碰撞/掉落路径保持。**实际 SWF 资产/子时间轴构造、滤镜像素边缘和 RNG 等价仍须以准确产物验证，源码检查不等于它们已过**。
- 事件只携一个同步调用周期的临时实例/范围；Grafon 不保存房间历史。范围面积上限409600像素，递归32层/单节点256子项；超出就 invalid。RConnect 仍须执行自己的 cell 数、消息大小、房间/epoch/term及 bitmap 身份检查。
- 原生自然绘图失败即使调用方继续执行，也没有 `raster` 成功事件；不能用部分前景完成 needsNative。重新绘制时的版本推进与同 cell 旧痕迹保守丢弃按 IMPLEMENTATION 的既定规则实现。

## 明确缺口与后续门禁

1. 此次只完成宿主事件/范围候选，尚未核完整 RC 接线；mat7/gwall、门、其它模组直接写 frontBmp 不在普通实体墙资格内。mat7/门的 tileDie 设置排除上下文，执行原 decal，**不会误发 ink**；gwall 方法逐字未改。消费端不能用其它全图 observe 再把这些排除写入包装成普通 ink。
2. 同实例原生图像比较仍待执行：mat1..6/fake、不同 eraser、真实边缘像素、非权威前景不二次写但原粒子/RNG/伤害存在、旧房 pending、同 bitmap 重绘、失败 drawLoc。无 actual SWF / AIR 证据之前，不宣称这些通过。
3. 六种 mask 与 tileFront 的引用仅按已知原版类限定；实际宿主符号资源及所有相关时间轴须由根的准确资源/类绑定与运行检查补证。未知资产应失败，不临时放宽成任意类或固定扩圈。
4. 若编译器展开 catch 的实际异常流异常，拒绝该产物；不得只凭源码中存在 throw 即通过。当前所有新增保存/重抛用独立 Boolean 和原值，不使用 finally 状态选择器。
5. 尚无带宽/CPU/内存或完整联机资格；本目录不启动新测试，也不改变现有低内存保护。
