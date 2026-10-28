# B 加入侧卡顿、默认模组环境与马蹄铁经验开关

当前状态：**`B3-0.1-clientenv1` 已部署并完成安装字节双侧复验，事务 verified。** 原入口身份、存档和 A 保留。卡顿与镜头回摆仍有剩余异常，不宣称全部解决。当前接续见本文末尾及 B-MEMORY；前面的“未测试／未部署／待授权”保留为当时的历史记录。

## 当前要求

只开发 B。改善加入侧广泛卡顿；B 测试入口同步当前正式模组环境，ContinuousScene、RealisticVision、LightAndDarkness 默认关闭，其余用默认值；增加马蹄铁经验共享开关。后续须完成必要行为/性能验证后按持续授权统一部署，不以编译成功代替适配通过。

## 已完成的源码与候选

- 工作源：`build/ab/b190-visual-motion-clientenv-source`，从 loadfix 完整恢复。已有马蹄铁开关、PoseTween 弱索引缓存、FrameDelta 同包路径复用、细分计时、AddonsBridge、PI 桥及个人档案/保存/动作接点。
- 主体05编译 `build/ab/b-clientenv-bridge-05-build`：SWF `6b0c2874f803f82734599757c533fe3b6e3c5c9b1d9067e76e05d93007ee2cf6`；source `6fae8a02289c55216cf13a24a82576c42b7ef147057fc3957133ca3899f14193`。仅编译，未实机；后续最新07见下方接续。
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
4. B本轮源码、工具与记录已保存为本地提交 `86cadaa`（142文件，约1.7MB）；source-07恢复指纹一致。未上传。A和recovery内容未纳入，生成SWF/native导出/工具缓存保留本地未入Git；当前安装仍loadfix1。

本地 PreToolUse 于本轮拦截一次组合指令：复制两份AS观察器、写候选清单、执行环境assemble和prepare。原因 `binary-swf-use-release-pipeline`；实际只更新隔离测试副本，不动安装版。已发起只限本会话/10分钟/该精确调用的授权表维护请求，**截至此记录尚未收到答复**。不能擅自登记或换工具重试被拦动作。其它独立编译、已有环境测试继续完成。此前单次授权已过期，不沿用。

当前被拦的具体调用引用主体04及FA04，输出 `candidate-inputs-02.json`、`overlay-02`、`prepared-clientenv-04.json`；它们尚未生成。最新主体05比被拦调用更新，后续须明确选择并记录，不把04的回执写成05。


## 已获授权后的实际接续（2026-10-29）

此前“未答复”是历史停点，当前已获明确授权，精确护栏调用完成后授权立即撤销。原组合调用因新正式CS与旧锁不一致失败；没有强行复用旧锁，而是另建environment-lock-02/candidate-inputs-03/overlay-03。新增Sandy音乐、正式WallBlend更新均进入23文件清单。测试当前是prepared-clientenv-07；生产主体07/FA04。

- addiction-03：87/75通过真实服药；addiction-04：89/82通过两次真实服药及缓冲未呈现时退出，最后确认队列各消费一次，回到自己的旅程后库存/药物状态正确。
- attachments-01：107/86通过真实配件配置、战术模块、同身体复活重绑及各自保存。
- injury-02：生产原生伤害与按人计时检查已通过，但小数在AIR JSON内差约2e-14，被观察器严格字符串比较误判。新增观察器仅对非整数连续值归一至1e-9，种子/计数等整数仍精确比较；失败保留，injury-03正在等测试资源。
- same-environment ABAB性能比较已启动，双方8/80敌人各60秒；baseline仅撤回两个缓存，所有新适配保持一致。结果须由qualify-environment.py按原5%/重复1.2门槛检查。中途资源快照只见本测试两AIR；不能替代起止全程无干扰证明，保留此边界。
- 部署事务02仅已暂存，32个明确目标；原安装与存档未动。原五文件工具不适用，新的release.py保留备份、逐文件并发核对、失败回滚和安装字节复验。事务01因暂存包缺application.xml被官方启动器拒绝，未触碰安装版，已纠正新事务。

## 本轮验证与部署接续（2026-10-29）

主体07、FA04与 overlay-03 的23个环境文件已固定。实际启用 ModLoader、B、Sandevistan、MSW、TDFC、RandomRooms、LootEditor、PermanentInjury、AddictionSystem、FirearmAttachments、WallBlend；CS、RV、LAD和已被ModLoader替代的旧ModSettings关闭。同步默认Sandy音乐和RandomRooms编辑器模块，但未验证独立地图编辑器完整功能。

### 实际行为检查

所有以下检查使用同一主体07、overlay-03和真实双进程，仅外置观察器逐次修订；没有修改旧回执。测试在自有后台桌面、全新身份和复制存档中运行。

| 场景及结果目录后缀（均在 build/ab/b-clientenv- 下） | 主侧 / 加入侧通过数 | 主要证据 |
|---|---|---|
| addiction-04 | 89 / 82 | 两次真实服药、两人库存隔离，第二次结果收到但仍在显示缓冲时离开，逐一应用后返回自己的角色 |
| injury-03 | 78 / 66 | 原生真实受伤、默认伤残概率、两人分别计时、加入不重复判定、个人保存往返 |
| attachments-01 | 107 / 86 | 双人真实配件和战术模块、弹匣120/72分别生效、原生弹丸归属、同身体复活不叠乘、个人保存 |
| loading-01 | 68 / 62 | 空房初始化、终端载入、换图与宿主退出 Loading |
| full-horseshoe-02 | 108 / 65 | 宿主开关与持久化、两人拾取、关闭仅拾取者奖励、开启共享、防重复发放 |
| textmotion-01 | 104 / 117 | 双方真实行走/开火，NPC文字和数字位置、确认后插值不改原生文字结构 |
| visualfield-01 | 80 / 73 | 基地背景、医疗箱、终端、原生NPC气泡出生及后续变焦 |
| timecontrol-01 | 50 / 50 | 真实快捷键、双方共享时停、回放结算、记录/回放中SATS衔接，不重复伤害或消耗 |

准确回执及准备文件在 `experimental/b-field-client-integration/functional-evidence.json`。PI第二次失败是连续小数 JSON 往返约2e-14差异被字符串判错，第三次只修观察器小数比较，整数种子与计数保持精确。没有改变伤残概率或随机种子来让测试通过。

### 性能和画面实查

`b-clientenv-comparison-01/qualification-01.json` 已通过。ABAB四轮、每轮8/80敌人各60秒持续轻机枪，无分项计时；只比较相同新环境下，撤回两项缓存的基线和完整07。45采样/5%平均及P95/1.2重复比/六段实际开火要求保持不变。

| 负载 | 主侧平均帧间隔（基线→07） | 加入侧平均帧间隔（基线→07） |
|---|---|---|
| 8敌人 | 38.499→39.041 ms | 33.445→33.390 ms |
| 80敌人 | 63.658→61.795 ms | 41.024→39.522 ms |

密集加入 P95 为65.5→64ms；播放目标两轮均值约163/164→159/157ms，但这不是按键到画面的端到端延迟测量。普通场景未证明稳定改善；普通主侧平均慢1.4%。运行间系统负载保留原样，中途快照仅见本轮两AIR，不能据此声称全程机器空闲。历史不同环境30秒数据不纳入算法收益。

亲自查看双方基地截图，并按确认号解析29组数据：63背景对象位置/树一致、58对医疗箱/终端素材及树一致、116次影子层序正确、10组同缩放7×7屏幕取样一致；16个气泡出生/宿主后续变焦观察通过，最大比例误差约3.22e-6。完整 `visual-motion-review.json` 保留 front/back 总位图摘要差异，不声称整图相同。

**剩余异常没有被通过数掩盖：** textmotion加入侧左右行走仍有反向样本，最大24/2px；这按可见文字粒子计数，不能当作独立抖动次数。两个开火阶段没有反向样本；加入静止阶段最大间隔299ms。补充无缓存诊断 baseline-02 的实际104/117断言通过且亦见1–2px回摆，但清单同时存在大小写不同的同一SWF路径，只更新其一导致运行文件核验失败，整次仍记失败，不晋升为合格对照。baseline-01在创建隔离身份时权限不足，未启动。随后补充准备JSON的写入被本地路径护栏拒绝，未越过护栏；必要部署验证沿已审查流程继续，补充对照不作为放行依据。

### 安装及最后复验

`build/ab/b-clientenv-deploy-20261029-03` 的32个目标已逐项备份、并发校验后安装；115项无关包文件及Player入口/AIR身份保留。仅备份并重置两B身份已偏离默认的Sandy与WallBlend设置。没有写角色存档、联机偏好或A/根宿主。

首轮安装字节 `installed-ui-01` 121/75通过但主侧一项失败，原始失败保留：真实开锁能开始、取消、重试，约70%时显示仍准确，最终不解锁。源码证据表明原外置测试只设置派生的lockPick/hacker值；新启用的成瘾模组每15步按原版重算属性会覆盖这些值。原计时200也对应技能已恢复后的120+80，而非临时高技能时的72+80。

只修外部 `BUiCases`：给复制角色真实20级lockpick/science技能及螺丝刀，通过原生setParameters计算；新增两次重算后仍具备确定成功条件的断言，测试物件使用180基础时长。真实按键、计时、成功判定、取消、进度条规则没有替换或放宽。产品字节保持07不变。

最终 `installed-ui-02` **主127/加84通过，0失败、0运行文件变化**；实际输入使两种锁分别完成，进度条、取消/重试、两侧独立换房与镜头比例检查通过。亲自查看加入侧进度截图可见目标、动作名和进度条。准备SHA `a2f0f881994a017cb526c86b40a40a3c256f41fc7e4581f7583cb8238bd7880b`；原失败未覆盖。

已 finalize，事务SHA `341cfcb21129d3a73fb0ee8d0c3f64d75db59e103ec3a1c31e16f28f0bfef4e0`，新安装 manual SHA `18ece1be58d84452c884663ea6ab9b5fff89bd45762b950560027deb8636c070`。精简回执 `experimental/b-field-client-integration/deployment-summary.json`，完整证据由安装目录的 playable-validation 指向；根/A六项见证前后一致。自有两个测试进程50936/60772均已结束，未关闭玩家进程。复用原测试目录，D盘余量约120.6GiB，不删除唯一源或失败证据。

玩家继续使用原 `Player-1.cmd` / `Player-2.cmd`，已开的窗口须保存后重启；浮窗设置中“马蹄铁经验共享”默认开，由宿主控制。下一次性能工作优先解释镜头回摆和密集供帧，不直接缩短播放缓冲，也不把未测的预测最终应用候选合入。
