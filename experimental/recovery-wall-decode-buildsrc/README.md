# recovery21 完整源码快照

准确 recovery20（`0674019c…acce9f5`）只叠已通过 67 项组件的两个解码类，版本号改为 `0.2.24-recovery21`。完整 90 个 AS 文件；87 个逐字节不变，另三个为 `WallCellCodec.as`、`WallImpactVisuals.as` 和仅版本字符串变化的 `RConnectMod.as`。没有合入普通房两处最终 setter，也没有改房间、采集、发送或缓存容量。

沿用既有 `prepare_sources` 的哈希/清单方法，不新增编译或部署入口。`integration.json` 绑定准确基线、原交付、组件源、Checks 产物、回执及 67 条实际断言；其 `source` 可由原正式配方直接消费。

根会话编译命令（本次只组装源码，尚未执行）：

```powershell
python -B -X utf8 tools/validation/prepare_recovery.py build/m52/recovery-21 --source experimental/recovery-wall-decode-buildsrc --version 0.2.24-recovery21 --build
```

再次只读验证：`python -B experimental/recovery-wall-decode-buildsrc/prepare_sources.py --verify`。

## 已实际运行的局部结果

`build/m52/recovery-wall-decode-fast-component-01` 已由根会话编译并在 AIR 中运行，**67/0**；实际组件 SHA256 为 `c57507991c9d0258735b9df62bc101ed98445c408856f51ca881b9cc7be7909a`，退出码 0，源码和安装输入不变。它是实际生产类组件，没有加载完整游戏。

| 完整解码 ABBA，每块七类输入合计 ms | 原类四块 | 候选四块 |
|---|---|---|
| 仅 ASCII 表／两字节写入 | 850 / 864 / 869 / 867 | 733 / 727 / 751 / 732 |
| 仅 W1 重复验证去重 | 877 / 874 / 878 / 873 | 781 / 767 / 802 / 794 |
| 两项组合 | 880 / 870 / 845 / 833 | 634 / 665 / 648 / 631 |

计时含原 legacy 路径；每块负载和完整返回词校验一致。该结果支持进入一次整体对照，不等于实际帧率收益或发布资格：组件强制冷缓存，实机命中分布、网络处理之外的开销和绘制长帧尚需核对。旧的密集场景失败结果未修改。
