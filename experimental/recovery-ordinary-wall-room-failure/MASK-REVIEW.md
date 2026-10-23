# 普通墙原生蒙版拒绝：准确宿主资源复核

2026-10-23，只读复核；未编译、未运行 AIR、未改生产或既有冻结输入。

实际诊断 `618e7154ac` 首因是 `structure-prepare` 的 `Unreviewed ordinary material mask class`。旧格 `(5,19)` 为前景 `A`、`mat=1`；旧范围为 null，准备身份均正确。随后 `structure-before` 有 76×76 的破坏图范围，但不能补偿无效旧轮廓，因此按原规则锁住检查点。原运行已取消，不是通过。

## 精确来源与缺项

宿主 `build/m52/recovery-ordinary-wall-sv-host-05/pfe.swf`：`00c7c511ffa51745cb4932e820365091d2540978eedd6dfe726a5cfd7818aa48`。资源和所有引用指纹见同目录 `mask-resource-evidence.json`（SHA-256 `5d6412a1f9af99cb91b7061951e4921dfb63a1a866990c85da22083c42fee693`）。该证据直接读取实际宿主 `final.xml`，不是以最新源码替代运行输入。

实际 Grafon `checkLoaded` 第 4051–4059 行将无 `vid` 且 `ed != 2` 的 Material 放进 `arrFront`。按相同条件解析实际 XML 第 47121 行内嵌 AllData，共 27 个前景材质。它们实际选择 `TileMask` 和以下 11 类。当前 `ordinaryMaskBounds` 第 889 行仅认六个独立的大写类，遗漏全部这 11 类：

| 必须补齐的精确 Class | 资源 ID | 实际选择它的前景材质 |
|---|---:|---|
| `maskSimple` | 4918 | A、M、100 的 border |
| `maskBare` | 4964 | B、C、I、P、Q 的 main |
| `maskBorderBare` | 4961 | B、C、Q 的 border |
| `maskDamaged` | 4934 | D、E、F 的 main |
| `maskSkol` | 4915 | D、E 的 border |
| `maskStone` | 4907 | G 的 main |
| `maskStoneBorder` | 4902 | G 的 border |
| `maskDirt` | 4932 | H、L、N、R 的 main |
| `maskDirtBorder` | 4927 | H、L、N 的 border |
| `maskFloor` | 4923 | C、I、J、K、N、O、P、Q、R、S、T 的 floor |
| `maskMetalBorder` | 4921 | J、O、S、T 的 border |

`TileMask`（4975）仍保留；默认 main 和 ed=4 梁架也使用它。`maskCrack`、`maskCTiles` 只出现在背景材质，`maskBrick` 未被本次前景选择路径引用，不纳入修正。A 的 border 本身即要求 `maskSimple`，不是 `BorderMask` 的别名。由于旧轮廓按 3×3 邻格先后遍历，日志不能证明首个抛出点一定是 A 本格；但 A 在现有白名单下同样必然失败。

## 角帧和艺术范围

从实际 XML 的 SymbolClassTag、DefineSpriteTag 和 DefineShapeTag 共核对 49 个被引用资源，并保存各片段 SHA。11 个 root 均为 1 帧；`maskFloor` 有 c1、c2，其余各有 c1–c4。12 种角 sprite 均恰好 5 帧，只有 PlaceObject2 / RemoveObject2 / ShowFrame，未含 clip actions、clipDepth 或 color transform。引用终端均为静态 shape。

实际 `setMCT` 第 4635–4652 行逐角选择 contour+1；floor 第 4744–4745 行只选前两角。现有范围函数让各角依次走完 1–5 帧再合并，覆盖每个角的所有状态；由于这些角是独立静态形状，四角各选不同帧的可见范围也落在该并集中，不需要穷举 5⁴ 种组合。

按资源自身 shapeBounds 与实际放置矩阵计算的静态包围范围并非都等于 40×40：石材族 Y 可到 ±20.45 px，地板 X 可到 ±21.5 px。这是支持保留原生 `getBounds`、子对象变换、材质过滤器扩张及最终裁剪的证据，不能替换为固定格子或猜测 padding。该静态结果不是运行时像素相等证明。

## 最小修正与验证边界

只在 `ordinaryMaskBounds` 原精确 Class 白名单中追加上述 11 类；原六类保留。角帧、深度/子数上限、实际几何/过滤器、mat7/gwall 排除、准备身份、失败锁定和检查点规则全部不变。不要改为任意 MovieClip、按类名通配或失败时用空范围。

单方法构建需核最终方法精确引用这 11 个真实 QName，并保留其他方法、资源和类声明；原拒绝未知类仍须可达。随后由主会话复用原 BF6 RoomCooperation 双实例夹具和相同 seed `2103021770` 复验 A 破墙、检查点和分房重访，并保留原异常/交接断言。已有四轮弹痕像素比较仍需在新宿主重新验证。该修正只消除已证实的原生素材拒绝，不自行证明其他结构版本、旧 ACK 或全部材质最终像素同步已通过。
