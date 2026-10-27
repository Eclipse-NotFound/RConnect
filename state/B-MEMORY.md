# RConnect B 开发入口

## 1. 本会话职责

只负责 B：加入侧发送输入，主侧统一推进两名玩家和双方房间，加入侧重现确认状态。A 的源码、入口和开发目标由另一会话负责；不把 A 的最新源或未合格 B195 混入 B。A 状态见 MEMORY.md。

## 2. 用户约定与执行边界

普通房可分头，无人房暂停保留本次进度；整图旅行由主侧发起，剧情/挑战共同进入。保留先到先得掉落、共享奖励与各自存档。B 的 TDFC/MSW/RV/Sandevistan 接口依已有独立授权使用。所有 RConnect 会话允许协调；这不扩展为任意其他模组通信或写入。

测试共用登记，只有自有后台桌面和唯一AIR身份，双实例启动余量6GiB、运行512MiB保护；不关闭玩家程序、不写真实存档、不用未点名Ghost。复用隔离副本，保存失败和唯一证据。日常修复通过本机门禁即可部署，不重复询问。

## 3. 当前实际安装（2026-10-27）

- **B3-0.1-field5 / 准确scalar04，已部署并复验。** 原入口 `build/ab/b3-playable-190/Player-1.cmd`、`Player-2.cmd`；原存档ID、配置和其它模组文件保留。已有窗口需玩家保存后重开。
- 准确构建 `build/ab/b190-scalar04-build`，SWF `f9e542f6d64fef707c41563558365a3d90562dbc346f3be6cf84f968062b7c07`，source `22e2cdedf6e1c3c0aaf2e7c7821d8199f024ce6188dd01a56f82be18d0ac12f8`。
- 配套 native021 / `eced04ad8dae6b74444ee6e5f5ec5ddf2e83528a9eecfef66f58985cb0c83063`，保留原019字节审计通过。
- 部署回执 `build/ab/b-field-deploy-20261027-01/deployment.json` 为 **verified**；`before` 保存field4五文件回滚。实际安装字节复验 `b-scalar04-installed-ui-01` 主77/加36通过，无错误，运行文件不变。根游戏/A、原B启动器和存档未改。当前manual清单 `4a85197620badfa03ec4eeac7769ed6106114178ee0d30678e01b8e71543cbf9`。
- 前版 field4/field22（SWF `3706828f…`，source `76ab46b8…`）为本轮准确基线；field3/field9/native019是更早历史，不能称为当前安装。初始修复过程见 `state/b-field-repair-2026-10-25.md`。

## 4. 本轮完成与验证

修复换房缩放、加入开锁/破解进度、文字矩阵插值、Q瞬移本玩家视野、投掷物按所见身份抓取、地形四个真实边界；普通前景墙在完整像素证据下省重复整房重画。新增宿主设置的安保共享/分别破解，已获权限不因切换撤销。

本轮只加 `NativeFields.capture` 有类型字段数组及循环长度缓存，字段/动画/频率/时钟不变。完整产品补丁 `experimental/b-field-scalar-cache/candidate04.patch`；前三份缓存实验均未晋升，不能合入。

准确八项在 `build/ab/b-scalar04-final-01`，统一prepared-v19，全部通过；计数与范围见 `state/b-scalar-optimization-2026-10-27.md`。前轮固定失败种子及UI截图工具故障的证据仍在 `state/b-field22-validation-2026-10-26.md`。

四轮性能 `b-scalar04-baseline-01/candidate-01/baseline-02/candidate-02`，每轮8/80敌人各60秒，真实持续轻机枪及原5%/重复1.2门槛全过。8敌人平均主48.77→49.15ms、加36.69→36.60ms；80敌人主94.00→93.20ms、加69.05→67.34ms；P95主131→131、加102.5→105.5ms。只支持小幅平均减负，慢帧未改善。报告 `experimental/b-field-scalar-cache/performance-result04.json`。不同日期原始环境有差异，不拿本轮绝对值与10月26日直接归因。

## 5. 已知遗留与不可复用的失败

- 密集战斗仍慢；火箭/破墙仍受播放缓冲影响，**没有改时钟，也没有宣称延迟全修**。本轮密集播放余量中位约220–232ms、较高样本250ms，不等于真实端到端延迟。前轮rockets trace 735配对和事件入口→确认统计见旧报告，不与新余量混用。
- 本轮拆分profile：80敌人主侧单位采集24.40ms/次，字段11.56、身体8.42、血条1.87、原生动画帧1.65；加入单位应用12.97ms/次，字段5.56。额外计时不当净性能。原始 `b-dense-profile01`、分析 `experimental/b-field-dense-profile/profile01-analysis.json`。
- 当前每次仍复制许多字段（真实UnitPlayer282项）。下一步审核哪些读取者需要哪些字段，或继续削减身体采集成本；不能盲删字段、删动画或降频。已弃弱后继标记、位图/类名、解码形状三种缓存，原因和原失败见scalar实验README。
- motion18等价失败且更慢，时钟加快恢复存在新增欠帧，均未晋升。原AB007四轮失败因90发装弹跨窗口/重复不稳保留；不得重标成新负载通过。
- 新负载001两轮在第二阶段准备失败；003等待双方停止后更新输入实际消费，再准备下一阶段。测试1000发仅测量前设定，游戏枪械未改；测量中不补弹/清计时。来源和差异留独立目录。
- UI原失败被精确定位为测试截图PNG编码789ms、输入空档920ms，引起500ms超时。v18冻结同一画面后延迟编码；产品超时未改。两轮正式UI及部署UI通过；不把工具故障说成已修产品缺陷。
- B本轮未新增A的联机快捷键自定义；未要求的A功能不自动移植。

## 6. 构建、测试与下一步

从当前准确scalar04继续。field22是功能基线；在其上加 `experimental/b-field-scalar-cache/candidate04.patch` 才是当前产品。用 `field_driver/compile.py` 编译到新唯一build目录。覆盖在 `experimental/b-field-*`，不要整文件覆盖相交补丁，也不改冻结构建。

功能副本 `build/ab/b-field2-runtime-01`，prepared-v19仍绑定部署前field22；性能副本 `build/ab/b-field2-bench-20261025-01`，当前prepared-sustained-003。性能驱动 `ab-sustained-003` source `1e4e640689e5269baab49b46e32c3592c568ac63550d18d4c9a83e587a7d3dc7`。继续用唯一结果目录和共享登记；新一轮资格需新建绑定field5的准备记录，不能改旧指纹。性能运行器另加可提交内存保护，物理内存原门槛保留。

下一优先仍是密集采集/呈现开销和弹丸显示延迟；本轮小幅优化与安装已完成。没有本会话后台测试或新护栏授权存留。本轮复用完整游戏副本，D盘收尾约125GiB余量。

## 7. 深入记录

- `state/b-scalar-optimization-2026-10-27.md`：本轮最终结果、限制、部署回执；`state/b-field22-validation-2026-10-26.md`是前轮功能修复。
- `experimental/b-field-scalar-cache/field5-input.json`：准确八项、性能、说明的部署输入；本次事务目录中的原脚本可从五文件备份回滚。其README记录尝试及撤回。
- `state/b-field2-repair-2026-10-25.md`、journal.md：问题与历史；本次精简前快照保留在Git `fcba105:state/B-MEMORY.md`。
- `experimental/b-field-perf-qualification/PROFILE-FINDINGS.md`：CPU/阶段热点及解释边界；`b-field-clock-replay`：未晋升时钟方案和真实trace。
- 产品、驱动与证据首次提交 fcba105；收尾提交见git最新记录。字节指纹源的换行保留由 .gitattributes 限定在本轮B目录。
