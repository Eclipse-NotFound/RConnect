# B 加入侧卡顿、默认模组环境与马蹄铁经验开关

状态：进行中，未部署。当前安装仍为 `B3-0.1-field8-loadfix1`，原入口、存档和 A 均未改动。

## 当前要求

只开发 B。改善加入侧广泛卡顿；B 测试入口同步当前正式模组环境，ContinuousScene、RealisticVision、LightAndDarkness 默认关闭，其余用默认值；增加马蹄铁经验共享开关。后续须完成必要行为/性能验证后按持续授权统一部署，不以编译成功代替适配通过。

## 已完成的源码与候选

- 工作源：`build/ab/b190-visual-motion-clientenv-source`，从 loadfix 完整恢复。已有马蹄铁开关、PoseTween 弱索引缓存、FrameDelta 同包路径复用、细分计时、AddonsBridge、PI 桥及个人档案/保存/动作接点。
- 最新主体编译 `build/ab/b-clientenv-bridge-05-build`：SWF `6b0c2874f803f82734599757c533fe3b6e3c5c9b1d9067e76e05d93007ee2cf6`；source `6fae8a02289c55216cf13a24a82576c42b7ef147057fc3957133ca3899f14193`。仅编译，未实机。
- 主体03是首个完整环境实测版本，SWF `296c27125d69bd6f5321d3837db4c347407a3c42a69006b3cd8cd08715e93832`。04修动作数组类型，05再修握手档案里的配件数组类型。原 `PlainData.copy` 为原生关联数组设计，会把真实列表变成 Object；新增模块的动作/档案改用有界 JSON 复制保留列表，原生角色保存仍用原方法。
- 马蹄铁：宿主控制/持久化，默认开，加入侧只显示确认。只影响地图马蹄铁的额外共享，不改变击杀、任务经验等规则。覆盖双方拾取、开关、最后一个点奖励、重复触发、偏好加载。
- FA 独立桥04：`build/ab/fa-b-bridge-04/FirearmAttachmentsMod.swf`，`75b8f76067bfe17fc2324469f067923332af1a50fac7447a7d09dcf5b247226c`。正式0.3.5源码冻结，未用未发布0.4.0；按人独立，加入输入不被其原生冻结挡住，原生友伤/时停路径保留，同身体复活保留武器基线避免配件再乘一次。
- Addiction 独立桥：`experimental/b-field-addiction-bridge/build/AddictionSystemMod.swf`，`b013282be0b61bd4995430297823e0426dd10034c5a3451f00c070f8461fa111`。每人 Engine/Pers/Invent，加入只呈现确认和提交操作；原 Engine/Catalog 规则未改。
- TDFC/Sandy/PI 独立接口编译与原生类隔离通过：`experimental/b-field-env-refresh/bridge-build-02/build.json`。TDFC `9ed11bcc…a699c85`、Sandy `87b8cbcc…328466`、PI `ff7a90d9…e766ac`。
- 新 PI 原生：`experimental/b-field-env-refresh/injury-native-sources-02/native-01/candidate/pfe.swf`，`3b1b77d3f6de08e5b31bb03883da6900b3656e497a4749305133019d0377ed83`。选择性移植26方法，保留5686无关方法和非代码资源，回读接点通过；B仍为 b3-v12。不要覆盖 native021。

## 实际测试及失败

- `b-clientenv-horseshoe-01`（旧依赖、缓存/开关候选）：主100/加57通过，其中含40项实际 AS 缓存一致性检查。
- `b-clientenv-full-horseshoe-01`（主体03、FA03、完整新环境）：主100/加57通过，无FATAL。实际11项加载日志包含外部驱动、未加载 CS/RV/LAD。仅证明开关/加载/连接，不证明全部新模块玩法。
- `b-clientenv-addiction-01`：失败保留。多数状态独立/不能客户端计时/保存隔离检查通过；真实服药因主体03的动作数组被改成Object而持续遭拒，已在04修。另观察器把解析前后JSON字符串的键顺序差异误判为状态不同，公共 `BAddictionCases.as` 已改为逐字段递归比较，未改生产 Engine。新观察器未编译/复测。
- `b-clientenv-injury-01`：驱动在跨 SWF 域查询 `PermanentInjuryMod` 时1065，尚未运行伤害断言。独立 `b-field-env-refresh/tests/BInjuryAddonCases.as` 已改为通过实际 B injury.snapshot 读取配置，并稳定比较字段；未复制入新驱动/复测。生产桥未因此修改。
- FA 实际改装、榴弹/瞄具/支架、复活和退出检查仍未运行。最新版独立驱动 `b-field-fa-bridge/BFAAddonCases.as` 已追加04复活重绑检查，未合入新外部驱动。

## 性能证据的边界

均为持续轻机枪、8/80敌人各30秒的诊断采样，启用了分项计时，不能冒充最终无插桩交替对照。

| 环境/候选 | 加入8敌人平均/P95毫秒 | 加入80敌人平均/P95毫秒 |
|---|---|---|
| 旧依赖，原算法细分计时 profile03 | 36.95 / 55 | 67.91 / 105 |
| 旧依赖，两项缓存 profile04 | 37.56 / 59 | 64.35 / 92 |
| 完整新环境，主体03 full-profile01 | 33.45 / 44 | 40.02 / 64 |

新环境主侧8/80平均39.68/66.24毫秒；加入80时 present16.688、decode5.035、tween4.589、units9.6、players1.93毫秒。新旧环境不同，因此第三行不能当作算法单独收益。缓存未证明普通场景改善。

性能工具在 `experimental/b-field-client-integration/bench-environment.py`，可同环境 ABAB。已准备 `build/ab/b-field2-bench-20261025-01/prepared-environment-001.json`，环境 `429f7292ad64e3e0f002113994e5788e3b1f0cbd1461e5598ffd2f3208b71872`，仍FA03/overlay01；准备前小文件备份和原native引用留存，没有复制整套游戏。最后一次实测已结束，自有测试进程清理。

另有预测最终应用去重研究在 `experimental/b-field-prediction-final-apply`，尚未合入。旧 motion18 曾失败，不能重做简单“运动只改坐标”。新方案也必须保留缺省 children/vector 的隐藏残留语义、SATS/暂停/对象重建回退；未有实测收益不得宣称完成。

## 下一步与当前护栏

### 继续完成的代码审查与源码保存

- 最新主体是 `build/ab/b-clientenv-bridge-07-build`：SWF `c953c0684ca716b2641c88f13e514275d5f2cc8e3387d9ade50d7ab8bd1fc5a0`；source `5854ef397c1e96cf24d8b637f32cdc24589502d91fe86cce892a3189b75041dd`，仅编译。06/07补齐正常退出前消费已解码但仍在播放缓冲的完整确认，避免旧库存/药物状态带回；复用正常present路径保留原生保存依赖的武器、前次护甲和宠物对象，不逐项重造保存逻辑。退出可能执行一次最终确认的提示和声音；异常render失败后的退出恢复尚未验证。
- 07将FA本身的输入校验交给 Commands 在接受数据前调用，不重复维护FA设置规则；未知字段或错误类型直接拒绝，避免到玩家步进才抛错。已写外部 `BAddonInputChecks.as`，尚未运行。此非当前合法默认配置卡顿的证据。
- `experimental/b-field-client-integration/source-07/` 是最新完整可恢复覆盖，18差异、144总源；`restore-source.py`已在纯源码目录恢复并比对一致。05快照保留。旧 `integrate.py` 只是过程，不能替代最新覆盖。预测去重未合入。
- 三路只读复核未发现其它确定的跨角色扣物资、服药状态串档、FA复活参数累乘问题；这不替代运行验证。新增退出检查至少覆盖缓冲中服药/换枪/宠物受伤、队列一次消费；还未写入和执行这组退出驱动。
- 默认环境静态复核发现缺失 `mods/Sandevistan/release/sandy_theme.mp3`（10,212,353字节，SHA `8e542315f880fdd3bd904733fe64414ee547cf966c6d2eeb96e6acee5ca26531`）。只更新environment.py的未来inventory辅助清单，未修改任何旧lock/overlay；下一完整环境需新锁和资源回执，不能称overlay01已齐全。
- 现有两个B个人身份：Sandy diaglog=1、WallBlend mode=second偏离当前默认，其它MSW72项均已默认；PI/FA/RR个人配置当前不存在。部署只备份/重置相关模组设置，不能清整个Local Store。原Player入口、AIR身份、PFE存档、config.sol、RConnectBPreferences/Hud和键位保留。名单由包内loader-manifest及#selection控制，个人ModLoader.sol不会重新启用禁用模组。
- 测试运行器只补收集自有测试身份中全部模块日志和相应指纹，Python语法检查通过；尚未用新运行器启动游戏。旧运行日志保持原样。

1. 当前功能副本是 `prepared-clientenv-03.json` / overlay01，准确来源在其回执。待更新到修复主体与FA04，重编新观察器，再依次复测 addiction/injury/attachments、受影响换房/加载/退出路径。
2. 更新后的性能环境另建回执，用正确主体做必要同环境对照；复用匹配证据，不重复全仓矩阵。
3. 最终是多文件环境更新，旧五文件部署工具不可直接套用；需备份/CAS整个变动清单、保留启动身份和个人存档，再部署同一份合格产物并复验加载链。
4. 尚无本轮提交。只提交B本轮文件，保留A和recovery未提交变化；生成SWF、native导出、工具缓存不得入Git。最终冻结可恢复源码，不只保留build工作目录。

本地 PreToolUse 于本轮拦截一次组合指令：复制两份AS观察器、写候选清单、执行环境assemble和prepare。原因 `binary-swf-use-release-pipeline`；实际只更新隔离测试副本，不动安装版。已发起只限本会话/10分钟/该精确调用的授权表维护请求，**截至此记录尚未收到答复**。不能擅自登记或换工具重试被拦动作。其它独立编译、已有环境测试继续完成。此前单次授权已过期，不沿用。

当前被拦的具体调用引用主体04及FA04，输出 `candidate-inputs-02.json`、`overlay-02`、`prepared-clientenv-04.json`；它们尚未生成。最新主体05比被拦调用更新，后续须明确选择并记录，不把04的回执写成05。
