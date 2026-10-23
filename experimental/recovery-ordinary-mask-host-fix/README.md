# 普通材质名单单方法修正

本目录只准备候选，不部署。准确基底为 host05 `00c7c511…aa48`；实际安装仍要求 22 项清单及 EB365。修正仅在 `ordinaryMaskBounds` 的原六类名单后追加经真实 AllData、SymbolClass、角帧核对的十一类。原范围算法、循环、随机数、绘制与伤害顺序不改。

`build.py --prepare` 只冻结源和工具；`--build` 才在共享登记和 1 GiB 启动 / 512 MiB 运行保护下启动八次隐藏 Java。默认输出 `build/m52/recovery-ordinary-mask-host-01`，拒绝覆写。任何失败保留现场，`validated` 始终为 false，独立准入及原生测试另行执行。

同一基底整类编译只提供供体。`single_method.py` 保留原 ABC 的全部方法元数据、类/trait/script 表、非目标完整 body、所有旧常量前缀，只移入目标 body；三个私有方法按真实 trait 配对，两种已审核的词法 namespace-set 定向映射。任一操作数编码长度变化、未知 private 形状、帧/异常/activation 变化均拒绝。目标白名单按实际指令执行检查（十七类接受、未知类拒绝），构造后的几何尾段必须与原方法逐指令等价。序列化后和最终原资源拼回后各进行完整 ABC 审计。其他原生资源与第二 ABC 逐原始标签保留。

真实原 body 自检已经执行：六种原类全部接受、未知类拒绝，142 条几何尾段通过解析；三个私有 trait 和两种词法集合对原基底均恒等。此项只核检查器适用于真实原方法，不代表供体或游戏通过。

结果接口：`verify_result(out)` 返回实际 `build.json`（未构建时只返回 prepared/compiled 状态）。`method-audit.json` 包含 `passed`、精确 `target`、四个保存性质布尔值及 `targetProof`。其中 `geometryTailUnchanged` 为 Boolean true；`oldAndAddedMasks` 为 `{original:[六类], added:[十一类]}`；`privateMappings` 列出真实 trait 与集合映射。回读在 `after/scripts/fe/graph/Grafon.as` 和 `pcode/scripts/fe/graph/Grafon.pcode`。`build.artifacts` 使用输出目录内的相对路径与 SHA256，不包含后续独立准入回执。

资源证据沿用 `recovery-ordinary-wall-room-failure/mask-resource-evidence.json`，不重写其历史结论。本目录尚无编译、AIR、房间或性能通过结论。
