# 普通房首绘灯具候选源码

用户已批准必要的 LAD 独立接口、协调、测试及合格后部署。本目录承接已双审冻结提案，只有源码与来源核验；没有构建、启动 AIR 或修改安装版。分房探针清单仍暂缓，本目录不接入它。

## 准确输入与交付

- `lad/src/` 是 8ADBA691 部署回执对应的完整 23 份 AS 源码副本；只有 `lad/LadRuntime.as` 应用已批准补丁，其余 22 份保持原始文件字节。没有从后续开发树挑选其它改动。
- `host/fe/graph/Grafon.as` 是完整、可供 donor 编译的候选类；`host.diff` 是其准确增量。来源为 A796 的真实 Grafon 导出，原文件 SHA `667D4295…12540`。
- 宿主实际 UI 候选是 `build/m52/goal-native-loading-host-03` 的 `2DB0B4EB…C2B82`。其原构建审计只允许十个 `fe.World` 方法变化，3275 个非目标方法及原构造器逐字节保留，所以 Grafon 与 A796 相同。**后续完整宿主应以 2DB0 为基底，只移植 Grafon.drawLoc 及两个新增私有 helper；不能用 A796 整份覆盖，不能丢掉既有 World/vwait 修正。**
- `restoration-proof.json` 和 `prepare.py --check` 核对前向应用得到准确候选、反向应用恢复整份原源码，并逐方法检查允许变化集合。它是源码恢复证明及既有 host03 审计的来源链接，绝不是尚未发生的新候选 ABC/SWF 保留证明。

原 LAD 构造器和其余 27 个方法不变，四个原方法为 attach、detach、onFrame、beforeSceneRaster；新增七个辅助方法、一个临时票据字段及 Dictionary import。原 Grafon 构造器及其余 85 个方法不变，只改 drawLoc 并新增两个 helper。

## 已批准行为边界

首次普通随机房绘图只在原 j=-2..3 背景层循环的三个 draw 判断排除候选灯具。bo.vis/light/erase 全程保持原引用，原同帧 World.step/land.step/脚本仍按原方式操作它们。LAD 不提前完整 attach、创建碰撞代理、挂 tick、写保存状态，也不触碰 WB。

原回调中 discover 成功、实际可转换对象集合完全匹配且 strip 成功后才消费票据。discover 失败或缺素材时，先临时摘下当前引用作为 BAKE 比较基底，再在 mutation 内恢复当前引用；finally 清理。若间隔内已完成整房重绘，则只丢弃优化，走原转换逻辑。普通门、复访、破坏后的重绘、剧情及大场景继续原路径。

精确逐行说明仍引用不可变的 `../goal-ordinary-lamp-first-raster-proposal/README.md`；其中“待授权”是提案产生时的历史状态，本目录不回写历史材料。

## 最短核验与后续构建要求

```text
python -B -X utf8 experimental/goal-ordinary-lamp-first-raster-candidate/prepare.py --check
```

此命令只读，缺文件或输入变化立即失败，不产生候选或构建回执。`prepare.verify()` 返回 `kind=ordinary-lamp-first-raster-source-v1` 的来源清单。

根会话负责后续有界构建：LAD 使用原入口 `LightAndDarknessDoc.as` 和原 native proxy/stub 编译链，换入本目录准确 Runtime；宿主复用已有保留式 donor/移植链，但重新审查 drawLoc 新 finally 的异常表、激活槽和两 helper 的私有 QName，最终回读确认仅这三个方法变化且原资源与 World 修正保留。这里没有提供未经验证的新构建器。

源码核验没有读取安装 SWF，也未把旧 LAD 部署回执的 protected 环境冒充当前环境。构建及原生测试必须重新记录当时真实 22 项安装输入、准确候选/宿主/驱动指纹，沿现有登记、内存、独占、回收与错误门槛。未编译的本目录不得被运行入口当作产品。

## 最小测试复用方案（未编写、未运行）

1. 小组件沿用 `tools/validation/run_recovery_component.py`，不修改其登记、内存、进程和结果合同。复制准确 `LadSceneBake` 与本次新增方法，使用最小四块 BitmapData/背景对象夹具，核正常集合、不可转换素材、discover 抛错、关闭请求、同帧完整 redraw、重复 complete；重点核恢复比较基底与新墙痕保留。只把私有可见性开放给夹具时须逐字记录来源；不能用重写的 Python 逻辑代替真实 AS3 方法。结果必须为 `assertions:[{label,passed}], failed:int, passed:Boolean`，固定断言数量在实际驱动冻结后确定，本目录不预填虚构通过数量。
2. 借用 LAD 原 `tests/LightAndDarknessTest.as` 已有普通房关开、坏灯/修灯、代理数及画面保留检查点；它有专用 applicationID/载入链，不能直接当现有 RConnect 驱动运行。最小接线仅在新的隔离驱动中复用必要检查，不改 LAD 测试文件，不引入整套第二框架。
3. 实机沿用 `experimental/goal-native-loading-native-v2/run.py` 所绑定的准确普通房原生驱动与原 35 项旅行、11 项显示检查；它当前只认可旧产物，所以须由根在新的薄接线中核新产品与 LAD 候选，不放宽旧验证器、不改冻结运行器。保持同图/同入口、首帧身份和原功能检查；另观察灯具层/erase/light 像素、代理数、BAKE 是否确实减少，普通门/背景门/复访不回滚。

错误注入及截图另设视觉轮，不污染净加载时间。约 0.9 秒来自旧 BAKE 耗时，尚无本候选收益证据；关闭、缺素材和失败分支正确也不能替代完整性能复测。对 BAKE 自身内存或绘图失败仍保留原错误边界，不以清空破坏像素作为兜底。

冻结后停止写入；所有后续改动需根明确重开。
