# recovery14 完整隔离构建输入

准确从冻结 `build/m52/recovery-13`（`1177eb1a…ddb1`）复制全部 87 个 AS 文件，再叠已通过 49/0 组件的两类墙痕编码覆盖。版本为 **0.2.24-recovery14**，总共 88 个 AS。

静态复核结果：85 个原文件逐字节未变；既有文件只改变 `WallImpactVisuals.as` 和入口的一处版本字符串，新增 `WallCellCodec.as`。两个类均与已测试覆盖逐字节相同；RoomCodec、Session、房间/动画/其他逻辑保持准确13。见 [static-checks.json](static-checks.json)、[wall-encode.patch](wall-encode.patch)、[version.patch](version.patch)。

[integration.json](integration.json) 是现有 `prepare_recovery.py --source` 可直接读取的完整输入清单，记录所有源指纹、准确13二进制/manifest、覆盖交付指纹及实际组件证据。`ancestor-integration.json` 是准确13祖先记录的原字节副本。未编译、未运行游戏、未修改活动源码或安装文件。

实际组件 `recovery-wall-encode-component-01` 为 49/0，安装和输入未变；原 SWF 指纹 `8a653323…568`。ABBA 两轮在历史82份相同自然数据上：旧编码每246次为 740/739/771/773 ms，新为475/499/510/517 ms；均值下降约 **33.8%**。冷解码旧314/312/318/304 ms，新290/280/277/282 ms，均值下降约 **9.5%**。逐块原始值、字符量、拆包结果见 [component-review.json](component-review.json)。

这些数字仅说明独立完整类的编码/读取成本值得进入原生对照。历史数据不是当前走廊的实际载荷分布；强制未缓存的次数不是游戏发生频率；相同码路径回放也没有包含网络、其他模组、敌人模拟和显示负载。不能按这两个百分比推算 FPS，也不能把准确13仍失败的密集或房间加载目标改记合格。

主会话编译命令（输出目录必须不存在）：

```powershell
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 tools/validation/prepare_recovery.py build/m52/recovery-14 --source experimental/recovery-wall-encode-buildsrc --version 0.2.24-recovery14 --build
```

纯只读复核：`python -B -X utf8 experimental/recovery-wall-encode-buildsrc/prepare_sources.py --verify`。不要重新运行无参数的复制步骤覆盖现有快照。
