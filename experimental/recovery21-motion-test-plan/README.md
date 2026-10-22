# 准确21：复用原生运动回归的最小入口

只读计划，未编译、未启动 AIR，未改源码、旧驱动或结果。目标候选为 `build/m52/recovery-21`，版本 `0.2.24-recovery21`，SHA256 `9ac7ede757c253bbf61e0c44334870b4a95112f976c1b40f2f390822a8b7e7ba`。其正式 prepared 绑定 integration `0229437a15928638dbea2ef183bfdbf1e9320335127c753dcb4e9a5bf17062b9`。

**无需重编译三个驱动。** 现有通用 motion wrapper 会在新输出目录复制同字节的外部驱动，并把新 driver-input 绑定准确21，原冻结包不动。为与本轮密集测试的进程策略、实际玩家 RV 配置一致，直接调用已实跑的 `recovery-formal-policy-control/run_motion_comparison.py`；不要调用该目录的 `run.py`，后者固定为 density。

工作目录为 `mods/RConnect`，先定义共享参数，再由主会话按登记顺序分别执行三条命令。任一失败先保留结果、核查原因，不把后续通过抵消该失败。三个输出目录在本次检查时尚不存在。

```powershell
$motionPython = 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
$motionRunner = 'experimental/recovery-formal-policy-control/run_motion_comparison.py'
$motionCommon = @(
  '--candidate', 'build/m52/recovery-21',
  '--host-vision-config-template', 'experimental/recovery-formal-policy-control/configs/host-RealisticVision_config.txt',
  '--join-vision-config-template', 'experimental/recovery-formal-policy-control/configs/join-RealisticVision_config.txt',
  '--registry-wait', '900'
)

& $motionPython -B -X utf8 $motionRunner @motionCommon --drivers build/m52/motion2-native-input-drivers-04 --case fast-held --output build/m52/recovery21-fast-held-01

& $motionPython -B -X utf8 $motionRunner @motionCommon --drivers build/m52/motion2-continuity-drivers-01 --case continuity --output build/m52/recovery21-continuity-01

& $motionPython -B -X utf8 $motionRunner @motionCommon --drivers build/m52/motion2-native-input-drivers-04 --case native-jump --output build/m52/recovery21-native-jump-01
```

这三条沿用全模组、独立桌面、延后显示、等主侧世界、独占 AIR、共享登记、双实例6 GiB启动/512 MiB终止和只清自有实例。分别沿原地图/总时限：fast-held=`rbl`/360秒，continuity=`random_mane`/300秒，native-jump=`rbl`/300秒；没有改阶段时限。formal wrapper 自动传 `--responsive` 并验证两侧启动 mask 1/0；无需手工干预PID。

## 对应的历史实跑与冻结输入

| 用例 | 冻结包 / 入口 | 11版原结果（不可承接为21通过） |
|---|---|---|
| 真实念力物品 | `motion2-native-input-drivers-04/fast-held` / `FastHeldTestDoc` | `recovery11-fast-held-01` / `772d324f45`，主43/0、加42/0 |
| 容器掉落和SATS | `motion2-continuity-drivers-01/continuity` / `PresentationContinuityTestDoc` | `recovery11-continuity-01` / `600de57ebb`，主21/0、加31/0 |
| 原生跳跃和跑跳 | `motion2-native-input-drivers-04/native-jump` / `NativeJumpNetworkTestDoc` | `recovery11-native-jump-01` / `786e5e3c5b`，双方6/0 |

11版三轮用的是普通 wrapper `tools/validation/run_motion_comparison.py`（`5cdf1169…83f922b`）。这次保留同驱动断言，但显式采用本轮 formal 策略/RV模板，**不能将11轮作为跨策略 reference**。如另需准确20/21单变量对照，应在同一 formal wrapper 和模板下，为每种 case 新建20参考轮，再给相应21命令加 `--reference <该case的新20输出>`；此文不安排额外运行。

执行前及结果必须核对的指纹：

- native-input-drivers-04 的 prepared：`677fabc0191e7809d588d2ce3b64f02c8de119131e7db46b1624d314bfa22a5b`；continuity-drivers-01 的 prepared：`d51ae3e751e93d1ae9d57b836c57a36e0a6f2d0fbb8bfcd02549247ac6976f31`。本次非二进制清单逐项复核一致；实际 wrapper 启动前仍须校验全部文件，包括二进制。
- fast-held driver：`41b5a52bb850e424659666f82f21008d821310437196edf597541fd32a475cd3`；native-jump driver：`aa96464bd5e31a18e1d25d582e01bffd7b11f213db960d0228c7c271d6b1554c`；continuity driver：`ccdd8aa8a6586ff5d283e2884b58ddff25664b666c01be645f3b89b1e70b400b`。共同 harness：`d52ef4300c7d472ee05884d7b4709f4abf80b3e6ff935b695a9ed986db021086`。
- formal wrapper：`f593468414493251a8a6525e2371833fa1c6b797fc0b8527a8e2c341b0c74ff9`；其 handoff：`2056bddaef38c06fbaca0254cd158e872438f510c379c71e4726976c0ae56a40`；底层 runner：`7eca453b13480140da5f36bb33d2319739a927562ccafdbb61a8b20cdb5ae4d3`；AIR inventory helper：`3d4c6160cfb8ee766ad77463da9e5e7a67b10af30170b4ca5a876af1d4a9cd4c`。
- RV host=`24a0162f565dfa9a04e42bd64ca6fb688d556d50d99a528dbfa703d680eaba0c`；join=`f3c7dfe712a836188d712f70b7d30fd83b8bb70435de28757196b3f926bf23f8`。直接调用这个下层 wrapper 会核模板输入/输出不变，不负责 density 上层入口的“用户当前配置是否仍等于模板”检查；开始前必须与本轮密集输入再核一次，不能静默称为更新后的用户配置。
- 结果检查两侧真实 production=21、对应 driver/harness、完整 runtime/22安装前后不变、独占及内存证据、policy回执、COOP PASS/FAIL/DONE/version 和所有 module-logs。runner 已保留/扫描私有模组错误；不要仅检查 RConnect.log。保持 `performance_qualified=false/full_release_qualified=false`，这是专项回归。

## 已断言的内容与只记录的数据

**fast-held**：4轮为 box-host、box-join、loot-host、loot-join。通过原生 Ctr Q 键、真实抓取和松手后重力，不直接驱动接收对象位置；施法者位置固定，普通新建角色念力能力被夹具提高，指针轨迹按原生游戏步推进。断言实际举起、位移跨度>40、样本>12、接收端重复位置比例<0.5、单次位移<25、拟合横向延迟≤160ms（≥12有效匹配）、松手/落地以及箱子静止释放及时到达。`FAST HELD METRIC` 的 RMS 被记录，**没有RMS上限断言**；160ms是最小到包偏移估算下的轨迹拟合，不是校准过的纯网络延迟。当前4轮不包含敌人/队友抓投、E撞墙伤害或高速移动的施法者，也不能把文件中未选用的 merc/lifecycle 分支算作已运行。

**continuity**：先由加入侧、再由主侧实际 `box.inter.actOsn()` 打开原生容器，各产生一份有唯一数量标记的真实Loot；掉落权威源仍在主侧。断言源轨迹>10样本且下降跨度>20，接收可见对象下降≥8帧/跨度>20，原最长静止界85ms。随后1轮加入侧原生SATS开启共同暂停，使用真实入背包并装备的lmg；断言暂停端点/原生选中覆盖层误差≤1px、暂停归属、恢复跳变≤4px和恢复端点。默认 `timelineOnly=false/latePackets=false/betweenFrames=false`，**不运行**100ms端点收敛、原生身体相位像素比对、迟到包与帧间强制重绘等条件分支。该独立夹具固定原生地图种子2646199556，敌人为受控移动，清掉环境敌人；不代表密集AI战斗。

**native-jump**：双方真实空格、A/D、Shift输入，前半竖直跳、后半跑跳，记录18秒；断言原生来源未锁动画、≥3次跳跃/高度>40、最终RENDER≥60样本、生产快照≥25、对侧升降>40、身体至少2帧变化。`airborneRepeatedPositions`、逐帧dt和轨迹仅诊断记录，**没有最长停顿、帧率、延迟、轨迹误差门槛**。因此6/0不能证明高速跑跳“已经流畅”。两张阶段PNG每侧由runner保留，但没有图像内容/连续性自动断言；也不覆盖飞行药水和任意速度极值。

## 现有数据能否离线判断停顿与误差

不增加运行器、不改变既有断言。实跑后可先从以下现成日志做有界分析；它们测最终RENDER显示对象坐标，不等于逐帧最终像素可见性证明。

| 用例 | 已有可用数据 | 能直接算 | 不能严判的部分 / 最少缺失字段 |
|---|---|---|---|
| TK物品 | `FAST HELD METRIC` 的源 `reference[{at,x}]`、观察 `render[{at,x}]`、sourceOffset、lag/RMS；`TELE MOTION RESULT.trace` 有xy及相对输入时间 | 各角色采样间隔、横向重复位置持续时间、原160ms拟合复算、横向RMS；区分“有RENDER却重复坐标”和“观察没有RENDER样本” | 不能把坐标重复一律判卡顿（原生转向/停稳可能正常），也不能得出精确二维、同源时间误差；缺观察时实际display cursor/源stamp、同一时钟的源与显示xy；sourceOffset为最小单向到包差，非独立时钟校准。日志仅记录被采样持有段，不证明抓起首帧或释放全程连续性。 |
| 容器掉落 | `CONTINUITY DROP` 包含主源与接收最终RENDER的绝对本地t/xy/logicalY/stay/dx/dy，及到包received/sample/xy/stay | 双侧间隔、源弧线与接收弧线、原85ms判据精确复算；检查停顿前后原生是否仍下落、当时是否已有到包 | 两个getTimer时钟不同；可估到包偏移/分段拟合，但不能声称精确运输延迟或每帧权威误差。最少缺接收端显示cursor/所选源stamp及可靠时钟映射。坐标只在drop对象存在且vis挂stage时采集，缺缺席帧记录，长空档不能严格区分整帧没发生与对象暂缺。 |
| 玩家跑跳 | `NATIVE JUMP TRACE` 在最终RENDER采坐标，但t/dt取此前ENTER_FRAME记录的frameAt；含本机xy/stay/dy、peerX/Y、原生/远端身体帧。`NATIVE JUMP SOURCE` 有received相对时间、源sampleTime/xy | 游戏帧间隔、空中连续重复位置/按帧首时间估算的持续时间、上下跨度和动画重复；两侧各自原生跃动是否充分。不能把frameAt差冒称最终RENDER时刻差 | `airborneRepeatedPositions`只是次数，原检查没给停顿资格；对侧源sampleTime是另一时钟，TRACE缺moving开始时绝对getTimer、实际RENDER时刻和实际显示cursor。最少补这些标量及对侧身份/序号，才可把源实际轨迹和显示严格对时；也需确认对象可见性，不能从2张PNG推出全程可见。 |

现成数据足以报告具体停顿现象和原断言结果；不够时应明确“同源时刻误差未知”。不得为填补这些缺口给既有轨迹补造时间、改低门槛、改动画寿命或把重复位置诊断直接升级为流畅通过。若后续确需补字段，应另提最小只读采样差异，当前三入口及历史结果保持原字节。
