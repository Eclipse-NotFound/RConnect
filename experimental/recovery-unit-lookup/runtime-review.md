# 单次单位查找组件实测：功能通过，收益不足，搁置

2026-10-22。只读核对主会话已运行的 `build/m52/recovery-unit-lookup-component-01`；本次只新增本记录，未重跑、未改源或原始结果。

- [receipt.json](../../build/m52/recovery-unit-lookup-component-01/receipt.json)：编译及AIR退出均0，实际84条断言通过、0失败，18组场景；安装及冻结输入不变。
- [component-result.json](../../build/m52/recovery-unit-lookup-component-01/component-result.json)：SHA-256 `99a3359954fe59357d9bc4bd40dc15af994cc1ad2a42647235ba3e1fe4a255f7`；组件SWF `7d2e43af69e07d12153c400779108785ffe4c31811dc3e599abcddbd242819ca`。
- 136单位、267项数组、40次全量查询：实际原生 `indexOf` 调用5440→0；既有默认路径和失效索引回退断言通过。
- 无计数插桩计时，含新版每次建索引的成本；每组200次全量查询，交替先后顺序。旧/新毫秒依次为 **34/36、35/28、36/40、38/36、37/28、37/28**。中位数旧36.5ms、新32ms，差4.5ms；按200次均摊约 **0.0225ms/次全量查询**。这是中位数差的折算，不是单次游戏调用实测。六组中两组新版更慢，不能将调用数归零等同明显CPU改善。

主会话决定：**整套候选暂不合入，也不另起候选单独合微小消重。** 理由是当前收益尺度及波动不足以支持扩展ObjectIdentity接口、增加每次字典分配和维护成本；这是性价比判断，**不是功能测试失败**。

验证边界：组件执行真实完整旧新ObjectIdentity，GameBridge.probe为明确替身；没有原生GameBridge.applyUnitsSync、有效位置复用、新建命中代理、游戏加载或帧率实测。结果中的 `native_game`、`gamebridge_native_methods_tested`、`performance_qualified` 均为false。源码/patch留作证据，不继续扩展此优化方向。
