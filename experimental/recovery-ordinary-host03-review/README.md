# host03 独立静态审查：保持失败

审查日期：2026-10-23。只读核查既有源码与 pcode；没有编译、启动 AIR、修改候选或安装文件。

## 结论

`build/m52/recovery-ordinary-wall-sv-host-03` **不能通过，也不能用于游玩资格验证**。原构建记录的 `validated=false` 保留。虽然最先触发审计停止的 `allAct` 差异只是两个多余的布尔转换外壳，但独立回读确认 `createObj` 存在真正的 E4X 编译错误；不能通过全局文本归一化或只豁免 `allAct` 放行整个宿主。

## 已确认的阻塞：createObj 丢失 XML 属性读取

以下行号均相对于该构建目录：

- `before/scripts/fe/loc/Location.as:2002` 和冻结 `import/fe/loc/Location.as:2002` 为 `AllData.d.obj.(@id == id).@size`。
- `after/scripts/fe/loc/Location.as:2002` 变成 `AllData.d.obj.(id == id).@size`。
- 这不是反编译外观差异：`pcode/scripts/fe/loc/Location.pcode:7527` 将本地 `id:String` 定义为 activation slot 9；在 XML `pushwith` 后，7637–7641 连续读取同一个 scope 的 slot 9 两次，再执行 `equals`。这里没有读取 XML 属性 `id` 的 `MultinameA` 指令。
- 因此筛选恒为真，不再按传入物件编号选择定义；7658 随后读取整个筛选结果的 `@size`。这改变了后续箱、门、陷阱、检查点等创建时使用的尺寸/位置计算。具体游玩症状未实测，不推断为某一种固定结果。

后续路线应保留 ACC 基底原有 Location 其它方法，只移入本任务的 `hitTile`、`dieTile` 两个目标方法。此结论不是对新候选的自动批准；移植后仍须回读真实方法及异常表，并确认未改方法保留。

## allAct 的具体差异

两处 `Boolean(_loc4_ != param1)` 在回读源码中省掉外层 `Boolean`，没有更改分组或参数。实际 pcode 12119–12130、12229–12240 保留 `equals → not → convert_b → dup → convert_b → iffalse` 和后续 `inter` 访问。对象分支仍调用 `command(param2,"13")`（12155–12158），单位分支仍调用 `command(param2)`（12267）。原 areas 条件亦未改变。

这仅解释这两处表达式，不能作为全类 Boolean/E4X 差异的泛化豁免规则。

## 新增和目标改动方法已核范围

将冻结 import、实际 after 与实际 pcode 对照，检查 Grafon 的 `drawLoc`、`tileDie`、`decal` 和 Location 的 `hitTile`、`dieTile`，以及新增 ordinary 系列方法。本次窄审未发现这些目标方法的确定性字段绑定或异常吞噬阻塞：

- `ordinaryMaskBounds` 的六种实际遮罩类、`tileFront` 均绑定到全局原类；`arrFront` 保留 `fe.graph` 内部命名空间，`BitmapFilter` 保留正确类型。证据：Grafon pcode 3827、3889–3928、4260、4420、4500。
- `drawLoc` 的 `ordinaryRaster` 调用绑定到 Grafon 的私有方法，并未误取同名局部布尔变量；原生绘制和收尾异常通知后仍抛出，内部绘制失败亦不能被标成成功。证据：21485–21511、23101–23147、23185–23189。
- Location 在 `Tile.die()` 前取得原材质范围 token，之后按真实活动房间调用 `tileDie(...,token)` 或 `rconnectOrdinaryPending(this,tile,token)`；没有增加一次额外死亡/伤害结算。证据：10766–10832、10958–10981。
- `tileDie` 临时结构上下文在正常返回及异常路径均恢复，异常仍重抛。证据：25212–25259。
- `ordinaryStructureBounds` 使用独立失败标志保存实际异常值，释放临时 bitmap 后重抛；`ordinaryDecal` 失败时发送无效结果后重抛原异常。证据：4620–4658、5495–5525、5581–5624。
- `ordinaryNotify` 的桥回调异常计数并返回 null；prepare 的范围异常保持 `valid=false`。这是既定桥协议，不能单凭宿主静态检查认定接收方已正确阻断。证据：1126–1173、1424–1465。

已核目标中的其它回读差异为声明提升、括号/键引号、循环重建等；以上只覆盖本次明确列出的调用和控制流，没有授予整体源码等价、实际图像、性能、联网或发布资格。实际资产范围、滤镜、跨房恢复仍依赖后续隔离原生验证。后续新候选必须再次核其真实命名空间与异常表，不能只复用此报告中的源代码判断。

## 输入指纹（SHA-256）

| 文件（host03 内） | SHA-256 |
|---|---|
| `before/scripts/fe/loc/Location.as` | `9c7e679a4b5b8423355cb3ce07e496caa13415beb1ffdd630f0f2ed7b38c9cab` |
| `import/fe/loc/Location.as` | `0ecce22f33a215d13f9a29ca1fc62d6a6ef5225981d9e4badb7609812f200267` |
| `import/fe/graph/Grafon.as` | `dd6299fbe5db88b7741c43722f5fbb18b45e36fa9aadb9134b128b464515a085` |
| `after/scripts/fe/loc/Location.as` | `b9bfaf174aab935bc26c885d7dccf25c458dce5e1112991d1a1d5a96995283cc` |
| `after/scripts/fe/graph/Grafon.as` | `66fd57b458d957476a19c3f7173bf564db9d1dd47cf34ae609a05d0b6dcefcb0` |
| `pcode/scripts/fe/loc/Location.pcode` | `a4aaa6de9ff52749b96df86e2073c5aef338b84246675b56d64f46d125ea575f` |
| `pcode/scripts/fe/graph/Grafon.pcode` | `f131fe0e0b3853dd65bcccd7be1f4335eedda146a669f525e739141184d0710b` |

本报告没有生成 `validated=true` 回执，也没有更改原 `build.json` 或任何失败证据。
