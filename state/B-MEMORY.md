# RConnect B 开发入口

## 1. 本会话职责

只负责 B：加入侧发送输入，主侧统一推进两名玩家和双方房间，加入侧重现确认状态。A 的源码、入口和开发目标由另一会话负责；不把 A 的最新源或未合格 B195 混入 B。A 状态见 MEMORY.md。

## 2. 用户约定与执行边界

普通房可分头，无人房暂停保留本次进度；整图旅行由主侧发起，剧情/挑战共同进入。保留先到先得掉落、共享奖励与各自存档。B 的 TDFC/MSW/RV/Sandevistan 接口依已有独立授权使用。所有 RConnect 会话允许协调；这不扩展为任意其他模组通信或写入。

测试共用登记，只有自有后台桌面和唯一AIR身份，双实例启动余量6GiB、运行512MiB保护；不关闭玩家程序、不写真实存档、不用未点名Ghost。复用隔离副本，保存失败和唯一证据。日常修复通过本机门禁即可部署，不重复询问。

## 3. 当前实际安装（2026-10-26）

- **B3-0.1-field4 / 准确field22，已部署并复验。** 原入口 `build/ab/b3-playable-190/Player-1.cmd`、`Player-2.cmd`；原存档ID、配置和其它模组文件保留。已有窗口需玩家保存后重开。
- 准确构建 `build/ab/b190-field22-build`，SWF `3706828fd10cf30c133826d17fd8cef939444f790a33a70d58c2a2b0779c90bf`，source `76ab46b821032f8b1fc63b629a9052b54514220826baead874866ed78dea1d9c`。
- 配套 native021 / `eced04ad8dae6b74444ee6e5f5ec5ddf2e83528a9eecfef66f58985cb0c83063`，保留原019字节审计通过。
- 部署回执 `build/ab/b-field-deploy-20261026-01/deployment.json` 为 **verified**；`before` 保存五个原文件。实际安装字节复验 `b-field22-installed-ui-01` 主77/加36通过，无错误，运行文件不变。根游戏/A、原B启动器和存档未改。
- 前版 field3/field9 与 native019 是回滚基线；不能再将其称为当前安装。初始修复过程见 `state/b-field-repair-2026-10-25.md`。

## 4. 本轮完成与验证

修复换房缩放、加入开锁/破解进度、文字矩阵插值、Q瞬移本玩家视野、投掷物按所见身份抓取、地形四个真实边界；普通前景墙在完整像素证据下省重复整房重画。新增宿主设置的安保共享/分别破解，已获权限不因切换撤销。

准确八项功能通过，除UI使用 `b-field22-final-02`/prepared-v15；UI用 `b-field22-ui-final-03`/prepared-v18。原失败seed2780491448同样通过。完整计数、截图原因、部署/回滚和范围见 `state/b-field22-validation-2026-10-26.md`。

四轮性能 `b-field22-sustained2-baseline-01/candidate-01/baseline-02/candidate-02`，每轮8/80敌人各60秒，真实射击及5%/重复1.2门槛全过。80敌人两轮中位平均帧耗时主82.69→82.73ms、加60.29→61.41ms；P95主122→120ms、加94.5→93.5ms。仅证明本负载无明显退步，非全玩法流畅。报告 `experimental/b-field-sustained-bench/field22-qualification-02.json`。

## 5. 已知遗留与不可复用的失败

- 密集战斗仍慢；火箭/破墙仍受播放缓冲影响，**没有改时钟，也没有宣称延迟全修**。真实rockets trace有效735配对，12弹丸事件帧入口→确认均值172.8ms、6地形变化帧236.3ms，非逐武器端到端延迟。
- 主侧单位快照约34ms/次、加入单位确认应用约19ms/次是旧profile已测热点；不能把未计时部分统称系统等待。下一步先拆分字段、姿态、武器等成本，再做有等价证据的局部优化，不能删动画/降低同步率换速度。
- motion18等价失败且更慢，时钟加快恢复存在新增欠帧，均未晋升。原AB007四轮失败因90发装弹跨窗口/重复不稳保留；不得重标成新负载通过。
- 新负载001两轮在第二阶段准备失败；003等待双方停止后更新输入实际消费，再准备下一阶段。测试1000发仅测量前设定，游戏枪械未改；测量中不补弹/清计时。来源和差异留独立目录。
- UI原失败被精确定位为测试截图PNG编码789ms、输入空档920ms，引起500ms超时。v18冻结同一画面后延迟编码；产品超时未改。两轮正式UI及部署UI通过；不把工具故障说成已修产品缺陷。
- B本轮未新增A的联机快捷键自定义；未要求的A功能不自动移植。

## 6. 构建、测试与下一步

从当前准确field22继续；合并配方 `tools/host_authority/field2_driver/assemble.py --security --grab-selection --terrain-bounds`，再用 `field_driver/compile.py` 编译到新唯一build目录。覆盖在 `experimental/b-field-*`，不要整文件覆盖相交补丁，也不改冻结构建。

功能副本 `build/ab/b-field2-runtime-01`，当前prepared-v18；性能副本 `build/ab/b-field2-bench-20261025-01`，当前prepared-sustained-003。性能驱动 `ab-sustained-003` source `1e4e640689e5269baab49b46e32c3592c568ac63550d18d4c9a83e587a7d3dc7`。继续用唯一结果目录和共享登记。不要再用安装前的manual清单直接冻结新测试：已部署的清单变了，旧证据对应备份，不能改旧报告指纹。

下一优先是密集采集/呈现开销和弹丸显示延迟；本轮功能和安装已完成。没有后台测试在继续，也没有新护栏授权存留。

## 7. 深入记录

- `state/b-field22-validation-2026-10-26.md`：本轮最终结果、限制、部署回执。
- `experimental/b-field-deployment/field22-input.json`：准确八项、性能、说明的部署输入；原事务工具可从五文件备份回滚。
- `state/b-field2-repair-2026-10-25.md`、journal.md：问题与历史；本次精简前快照保留在Git `fcba105:state/B-MEMORY.md`。
- `experimental/b-field-perf-qualification/PROFILE-FINDINGS.md`：CPU/阶段热点及解释边界；`b-field-clock-replay`：未晋升时钟方案和真实trace。
- 产品、驱动与证据首次提交 fcba105；收尾提交见git最新记录。字节指纹源的换行保留由 .gitattributes 限定在本轮B目录。
