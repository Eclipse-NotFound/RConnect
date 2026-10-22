# recovery21 完整源组装独立核验

结论：未发现组装范围或证据绑定的阻断项。只读核对 `experimental/recovery-wall-decode-buildsrc` 与准确 `build/m52/recovery-20`，没有运行构建、AIR 或修改任一输入。

- 两边均为 90 个 AS 文件，基线实际文件逐项符合 recovery20 的 `prepared.json/source`；21 实际文件逐项符合其 `integration.json/source`。**87 个逐字节相同**，仅 `WallCellCodec.as`、`WallImpactVisuals.as` 和 `RConnectMod.as` 不同。入口仅把一次版本字符串 `0.2.24-recovery20` 改成 `0.2.24-recovery21`。
- 两个解码类与已测 `recovery-wall-decode-fast/src` 逐字节相同。组件冻结 `src` 的完整 14 个输入与原 intent、交付 components 清单一致；新 codec 与生产类字节相同。新旧 Wall 类除声明重命名和明确的 `DECODE_COMPONENT_ACCESS` 测试入口外，与实际新旧生产类全文一致，旧 codec 也仅重命名。没有只拿等价算法替身代替被测完整类。
- `recovery-wall-decode-fast-component-01/receipt.json` 记录已编译、实际启动 AIR、退出 0、67/0、安装及源未变；`component-result.json` 有 67 条通过断言，`stdout.log` 独立有 67 条 PASS、0 条 FAIL。组装中的 component-review 与 integration.component 全等，并绑定真实 receipt、result、intent 指纹。它仍是组件结果，不能证明实机帧率或发布合格。
- `ancestor-integration.json` 与准确20的 integration 字节相同，基线 prepared/ancestor 哈希正确。integration 所列 **117 个非二进制输入**、三份 patch 均逐项复核一致，static_errors 为空。两份二进制标识采用已有运行/构建回执（20=`0674019c…facce9f5`，Checks=`c5750799…be7909a`），本次没有重新读取 SWF。
- `WallImpactVisuals` 仍保留普通房的 `b.setPixel32(x,y,color)` 与 `b.setPixel32(x,y,uint(c.values[key]))` 原调用，未合入待测 setter 修正。未新增 `EarlyTravelGate`；房间、MapGeneration、Session、GameBridge 等其余87类全部保持20字节，未混入 early 分支。

此次固定的 integration SHA256：`0229437a15928638dbea2ef183bfdbf1e9320335127c753dcb4e9a5bf17062b9`。

组件 receipt SHA256：`440e6b8dae02e08488007ef8394735662a833147de1660356e57ceb18f6c4890`；原始 result SHA256：`fb123ee9ff6024fe3d8dc105bdeaf402b77ce56392fd51458bfadc8cf150604e`。

本次只核组装与实际组件来源，没有重复既有算法审查，也没有把局部解码 ABBA 成本推广到整机收益。
