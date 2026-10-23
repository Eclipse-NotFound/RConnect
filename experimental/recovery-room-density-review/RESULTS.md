# 574D 与 aura1：当前宿主下的固定双人密集对照

2026-10-24，只读回核根会话已完成的两次实测；没有新增运行、编译或部署。README 中“尚未运行”是准备阶段状态，本文件以实际回执为准。

**本轮 aura1 的加入侧七窗 P95 均低于旧 574D，没有重现新版整体更慢的方向；但两个版本均严重卡顿、原性能门槛均失败。** 新版窗口 3、6 的最长快照空档反而更大。一次固定负载对照不能否定用户实际游玩的倒退反馈，也不能称作已修好或性能合格。

## 输入与比较资格

| 项目 | 旧版 | 正式 aura1 |
|---|---|---|
| 原生运行 ID | c0657f7dd9 | 394edfb54d |
| 版本 | 0.2.23-coop-bundle2 | 0.2.24-aura1 |
| 产品 SHA256 | 574d2b51490ae8b25a1396555600f56a301f8a20ae50104c0e35cf2796441afe | df0fa0e2ca952e77e5132e75d71e73558dc919c7b8cdeba5da05fc9e94dc01e7 |
| 包装结果目录（build/m52 下） | recovery-current-density-574d-01 | recovery-current-density-aura1-01 |
| 退出码 / performance_qualified | 1 / false | 1 / false |

两轮 run.json 确认双侧分别加载上述产品，以下输入一致：

- 游戏宿主：abe2b65edf3d0e4e0fa8eca76a60e577d40e47f20b9acecebec7730849a2602a。
- RV：0dbe0d7a95b8e496fb393d7fcd75f88d60c34a1d0fabb33266b122e3fa04f2bf。
- 冻结 corridor drivers03：Driver cfca757c22052f0efd29afca1f76fe717e79d436b03a264413add2e4c8c9150a；Harness d52ef4300c7d472ee05884d7b4709f4abf80b3e6ff935b695a9ed986db021086。驱动未重编，门槛未改。
- 两份 result.runtime_signature 实际完全相等；使用本次安装默认组合，未采用历史关闭 RV 的设置。admission-after 均 inputs_unchanged=true、historical_manifests_unchanged=true、error=null；result 均确认安装、runner、占用检测器未变且 invalid_reason=null。

**成对资格来自 aura1 的 fixture-audit**：准确引用旧 result 的 SHA，input_comparable=true、attribution_allowed=true、same_driver=true、same_runtime=true，differences=[]、双方 raw_spawn_differences=[]、corridor_static_equal=true。旧版没有 reference，原回执是 baseline_only=true、两项资格字段 false，不改述成 true。两份审计均 original_failures_preserved=true、original_result_unchanged=true、performance_qualified=false、passed=false。

固定原生种子 719355926；48×25 固定走廊；80 身体（1 尸鬼、40 血翼、39 掠夺者），39 武器（12 LMG、27 p308c）；玩家 X=161.8/Y=960，固定方向、镜头和对侧位置。双方实际人口、武器参数、地形与显示对象稳定后才计时，审计不是仅比较人数。

## 加入侧七窗结果

单位 ms。每窗在至少 8000 ms 后结算；P95 是 ENTER_FRAME 回调间隔的第 95 百分位，越小越好，不是 GPU 帧耗时或录像帧率。窗口 0 不密集开火，1–6 开火。不得平均七个 P95 后称作整体 P95。

| 窗口 | 旧 P95 | aura1 P95 | 旧最大间隔 | aura1 最大间隔 | 旧 / 新回调数 | 旧 / 新最长快照空档 |
|---|---:|---:|---:|---:|---:|---:|
| 0 | 456 | 442 | 499 | 492 | 25 / 25 | 974 / 838 |
| 1 | 627 | 587 | 674 | 638 | 26 / 27 | 1360 / 885 |
| 2 | 1135 | 706 | 1135 | 706 | 20 / 21 | 1295 / 1289 |
| 3 | 860 | 533 | 860 | 835 | 20 / 23 | 1159 / 1506 |
| 4 | 936 | 512 | 936 | 525 | 20 / 28 | 1221 / 822 |
| 5 | 972 | 515 | 972 | 657 | 21 / 26 | 1482 / 947 |
| 6 | 513 | 465 | 609 | 525 | 27 / 28 | 936 / 1093 |

原判定保留：

- frames>=80 且 p95<200：两版均 7/7 窗失败，实际每窗仅 20–28 次加入侧回调。
- packets>=20 且 maxPacket<900：旧版 7/7 失败；aura1 4/7 失败（窗口 2、3、5、6）。两版各窗包数都足够，失败来自空档。
- 独立瞄准样本数大于包数：两版均 7/7 失败。
- 原始 COOP FAIL：旧版加入侧 21 条、新版 18 条，主侧均 0 条。双方均完成 COOP EFFECTS DONE；两份审计 module_errors=[]。完成运行、没有模组错误都不代表性能合格。
- 两版开火的六窗均通过真实轨迹传输、弹丸可见且运动、结束弹丸新增隐藏姿态为 0；只能证明活动存在，不能证明流畅。

主侧没有 P95，只记录回调数 / 实际窗口 ms：旧版 94/14481、36/7996、28/9302、27/8743、24/6711、30/8689、38/7727；新版 89/13960、40/8211、30/8347、31/8006、41/8285、39/8316、38/7691。窗口 0 含较长等待、各窗长度不同，不宣称主侧每项均改善。

## 限制

1. 只有旧→新一对，没有重复或 ABBA 顺序抵消。计时前 baseline-state 也不同（旧 P95 103、新 73 ms），系统时序影响未排除。
2. 固定准备状态与刺激规则，不是逐弹丸相同回放。身体由 Timer 移动，枪角依绝对 getTimer() 正弦变化，12 枪按主侧帧数交错开火。六窗实际轨迹事件数旧 70,71,69,63,70,92，新 93,77,83,105,107,98，不能宣称逐事件输入相同。
3. 双轮独占 AIR、私有桌面，采样无其他 AIR，未因内存或占用中止，登记 cancelled=false。启动可提交余量约 11.760 / 8.973 GiB；运行最低约 5.698 / 4.559 GiB，高于原 512 MiB 运行线。资源余量不相同，也没有证明 CPU/GPU 无外部负载。
4. 固定走廊、限定敌人驱动不覆盖全部自然 AI、加载/切房、后台房间和长期游玩；不覆盖 roomfix4，后者不可借用结果。
5. 当前组合为 ABE2/RV0DBE，不能代替用户更早组合或否定回退要求。结果支持两版均有严重共同瓶颈，不能单独归因 RConnect、RV、CS 或某显示方法。

## 原始证据

以下均相对 RConnect 根目录；核查只抽取 JSON 字段与短指标行，没有输出或复制巨大 DENSITY INPUTS 行。

| 文件 | SHA256 |
|---|---|
| build/m52/recovery-current-density-574d-01/result.json | fafd9bb93300f17ec0ddf0682c35c34440c0dc99975c83bba18bb0722454542f |
| build/m52/recovery-current-density-aura1-01/result.json | fa75ea76b2fb395eeadacb089d100691e3307023d7c93247cb46a07fb003b088 |
| build/m52/recovery-current-density-574d-01/fixture-audit.json | 42b676a59fdb531ca01820b011c0eb024d4ad0a1025cf6585ef7f2996e4edab2 |
| build/m52/recovery-current-density-aura1-01/fixture-audit.json | a7eb9bd71b54e8d717db2e1be949779f209cbc9286295f72e1fa13515a0d88d6 |
| build/cooperation/c0657f7dd9/join.log | a79d43964ac432059222ea308fb933475eab1fcd937f07c81052aae79a6d407a |
| build/cooperation/394edfb54d/join.log | f8e6f37aaf428ec2e289f35975fb6063fa073149b759c300975a6e7dfc35f220 |

旧七窗日志行号 166、175、187、200、212、224、236；新七窗 164、175、188、200、212、225、237。

冻结驱动：build/m52/recovery-density-corridor-drivers-03/tests/SustainedDensityTestDoc.as。原判定 547–549 行，刺激 539、581–582 行，回调取样 592 行。ProjectileLoadTestDoc 原样调用 super(true)。
