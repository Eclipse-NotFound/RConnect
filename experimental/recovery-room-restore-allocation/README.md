# 房间恢复：减少已确认无用分配

状态：只准备源码和组件，未编译、未运行 AIR、未安装；不授予加载耗时或联机资格。

准确基底为 `build/m52/recovery-room-production-05`，SWF `78c052aea963f1689b705ae1e14d274916ae1a1f7e81933390caf8d1a88f4699`。完整 prepared、compile、两类源码和旧组件夹具指纹见 `prepare.py`；这是历史编译来源，不宣称它等于当前全部安装环境。

只有两处生产改动：

1. `GameBridge.reconcileObjs` 删除没有读取者的 `byId` 表及填充循环。保留 `consumed`、实际匹配、对象创建与恢复顺序；不改成索引桶。组件不编译整个 GameBridge，该项由完整方法静态检查及可逆差分证明范围。
2. `RoomTerrainView.unchanged` 的每格比较改为 `sameTile`，按原 28 项顺序用 `===` 短路比较，门仍只比较 `door != null`。构造时的快照、所有外层条件、刷新和失败路径保持原字节；后续比较不再生成 `tileInputs` 临时数组。真实 Tile 字段为普通存储字段；不为人为自定义 getter 保留旧数组构造的多余读取副作用。

`prepare.py --materialize` 仅首次写本目录文本并冻结清单；随后直接运行 `prepare.py` 检查。它检查两份源的反向替换能完全恢复原始字节；控制类是完整旧类只改类名/构造器名，新组件类与候选类逐字相同。不会复制 SWF、调用编译器或游戏。

组件复用 `recovery-terrain-observed-reuse` 的已声明字段 Tile 夹具。仅组件 `front` 放宽为 `*`，以验证严格类型反例；真实生产字段与存根不改。两端使用分别创建的完整显示/房间夹具，不共用 Tile、门或背景对象。55 项包括：正常等价 1、每字段失配 28、NaN 5、严格类型 4、数值边界 3、门存在性 5、无关 HP/视野/陷阱 3、提前返回 5，以及原刷新轮廓/光图像素/可见性/回调次序 1。每项还检查 `unchanged` 未写入 Tile 状态，并用可计数房间网格验证外层与首格短路。NaN 保留原来的“不相等”，不会为了提高复用率改变它。

主会话可沿用原组件运行器，无新增运行框架：

```text
python -B -X utf8 tools/validation/run_recovery_component.py --source experimental/recovery-room-restore-allocation/components --entry RoomRestoreAllocationChecks.as --expected 55 --output build/m52/recovery-room-restore-allocation-component-01 --registry-wait 900
```

从 `mods/RConnect` 执行；由主会话串行执行，先按原登记/资源门槛判断。原运行器负责独立存储、安装指纹、错误和子进程回收。本组件只证明本机夹具下的语义等价；不加载真实 RV 或原生地图，不能说明真实房间复用已发生，更不能说明多人加载已达到单人耗时。首拒因诊断仍独立推进。
