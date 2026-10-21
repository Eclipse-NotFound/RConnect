# A 版高速运动连续性修正（motion2 已部署，密集性能仍未达标）

## 用户报告与本轮边界

2026-10-21 用户报告高速子弹/天角兽闪电、对侧念力物品、加入侧掉落物卡顿；随后补充角色高速移动与跳跃也卡顿。本轮沿安装 A 版处理，不恢复 B，不混入尚未合格的房间19或 motion1。

用户先选择“暂不退出，先保留候选和测试记录”；之后授权恢复实测，在获知密集性能仍未合格后明确“先部署现有版本”。准确motion2已安装，安装后双人冒烟通过。此例外不改变原性能失败记录，不覆盖其它候选。没有关闭用户进程或修改真实存档，维持双人6GiB、单人3GiB门槛。

## 准确基线与候选

- 旧基线：`build/m52/coop-bundle-04` / `0.2.23-coop-bundle2`，SWF SHA256 `574d2b51490ae8b25a1396555600f56a301f8a20ae50104c0e35cf2796441afe`，保留用于对照和回滚。
- 最初宿主为BEFC；期间CS更新的组合与各轮证据分别见后文。本次部署和安装后复验使用根 `pfe.swf` SHA256 `5432a3b9b6820a94ae15ac0a97b13c4edc534d3dc6dbed12063e0fe47677b71d`，本会话没有修改宿主。
- 稀疏源码：`experimental/motion-continuity/src`；仅 `RemoteMotion.as`、`ProjectileVisuals.as`。
- 冻结候选：`build/m52/motion-continuity-02` / `0.2.24-motion2`，SWF SHA256 **`6e03c9a719bcd23c029ee61bef6a8dc334abd44d28e6e4885578b00b00f98cef`**。
- `prepared.json` 保存基线、源码、工具、编译器输出和覆盖层指纹。初次编译时未安装，随后原生验证及部署结果见下文。02仅修正构建清单路径，使其可被现有原生对照工具读取；与01的所有生产源码和构建工具逐文件SHA相同，未将二进制哈希不同称为同字节复测。组件测的是该相同源码，不是完整SWF原生执行。01与其原清单保留。

## 已定位并修正

1. **普通时钟校准直接跳位。** `RemoteMotion.pushTimed` 在测得更低的传输延迟时立即增加显示进度，即使两个 `sample(now)` 时间完全相同也改变位置。800px/s 固定输入中，仅25ms校准就让玩家/念力物品跳20px。候选让普通小校准由已有平滑变速逻辑消化；保留原来大积压快速恢复分支。不增加固定播放延迟，不外推。
2. **新点重写已播放的曲线。** 三次曲线每次采样重新计算末端斜率。低延迟念力或首批掉落已经播到段中间时，后续点会让同一时刻的显示位置改变。固定回放分别产生10px、8.91px跳动。候选在一段开始播放时固定该段斜率；新点只参与后续段，保持接收端点范围。
3. **移动闪电被排除在位置插值之外。** 原生 `Bullet.step` 对天角兽闪电使用与普通弹体相同的世界坐标更新；它是移动的 spring=1 弹体。旧 `tickBeam` 按图像类名额外排除两种闪电。候选允许几何尺度一致的移动闪电在已收到点之间补位置，仍保留 spring>=2 光束、火焰及尺度变化的离散规则、原生结束时刻和禁止外推。

未改碰撞、伤害、AI、发包频率、实体归属、房间交接或其它模组。本轮没有证明这三处是所有实际卡顿的唯一原因。

## 验证证据

全部组件使用实际 AS3 生产类、固定时间输入、自有隐藏 AIR 桌面与独立 AppID，登记到共享测试表。没有加载游戏本体；原生武器/传送边界在夹具中明确抛错，不能用这些结果替代原生效果检查。

| 输出目录（build/m52 下） | 结果 | 含义 |
|---|---|---|
| motion2-clock-baseline-01 | 31通过 / 6失败 | 精确旧版复现玩家/物品20px校准跳动与念力/掉落9–10px曲线跳动；失败保留 |
| motion2-clock-candidate-01 | 37 / 0 | 相同新增用例通过；旧念力断流恢复、两组实际掉落流量回放、有限特效播放速度、敌人动画时钟检查均通过 |
| motion2-clock-legacy-01 | 18 / 0 | 原有2–16帧积压、抖动、暂停/迟到末点、旧无时间戳调用和大位移阈值检查通过 |
| motion2-projectile-baseline-01 | 13 / 2 | 两种闪电在15个显示间隔只移动3次；普通子弹、光束/火焰与结束边界通过 |
| motion2-projectile-candidate-01 | 15 / 0 | 两种闪电均15次连续移动，仍不超出最后点、按原结束时刻消失；光束/火焰边界保持 |

组件结果中的 `installation_unchanged`、`source_unchanged` 均为true。合计不是新功能数量，不代表游戏FPS或整合发布资格。

`motion2-baseline-fast-01` 尝试准确旧版实机对照时，运行器检测到已有AIR PID86656/89852并在启动前拒绝；无run ID、无新增游戏进程，不能计作运行失败或性能样本。之后只读核对剩余86656命令为根 `application.xml -nodebug`，确认为用户游戏。内存当时约7–8GiB可提交余量；实际原因是测试独占条件不满足，不能写成内存不足。用户明确暂不退出后停止该实测安排。

## 尚未完成与接续

### 10-21 恢复原生验证

- 初始可提交余量约4.6–5.3GiB，未强启双人，先做单原生游戏资源回放；之后恢复6GiB以上，启动准确旧版双人基线。资源不足与占用均由运行器启动前检查，未降低门槛。
- `motion2-native-assets-driver-01` 外部驱动只引用生产类，加载完整游戏真实 `visbullightning/visbullightning2` 资源，在实际SWF的ProjectileVisuals上回放固定轨迹。旧`14af030096`为12通过/2失败；新`9d7b71e0ab`为14通过/0失败。两种闪电分别从3/15移动变15/15；非透明像素、结束销毁与普通弹体/光束边界检查通过。**不是实际射击、TCP或帧率验收**。
- 这两轮的22项安装输入、驱动、运行器和包装脚本逐项相同；各自前后安装未变。输出分别为`motion2-native-assets-baseline-01`、`motion2-native-assets-candidate-01`，原红结果保留。
- 精确旧版高速TCP：`motion2-baseline-fast-02` / `b1bb4e4adf`，主3/加5功能项通过，完整独占监测、安装和运行器不变。主/加帧间隔平均79.109/80.677ms，p95为91/98ms；直线内部静止样本均0，速度偏差p95主看对方0.07454、加看对方0.07713、加看敌人0.03234px/ms。它是500px/s受控源运动，不能替代原生跳跃，且实际帧更新偏慢，不能称流畅达标。
- `motion2-candidate-fast-01`在取得登记后发现外部AIR48084，启动前拒绝，无run、无新增AIR；之后该PID已退出，身份未能补证，不推定为用户普通游戏。重试使用全新输出`motion2-candidate-fast-02`，不覆盖失败。
- 补充`NativeJumpNetworkTestDoc`通过真实键盘事件驱动原生跳跃/跑动，只有初始定位，测量期间不改任何接收端坐标或重力；环境敌人冻结，因此不用于密集性能。与已有`FastHeldTestDoc`一起冻结为`motion2-native-input-drivers-01`，两个外部驱动编译成功，原生运行待续。高速角色旧/新对照继续使用完全相同的`motion-drivers-01`。
- 排队中的另一光晕会话曾误读共享表把本轮b1bb4e4adf当成其control03；已按input/run/driver指纹核对，光晕实际为c481f352f8。没有UUID碰撞，本轮指纹及结果未混用；不修改公共runner来解决记录读取错误。
- 准确候选高速TCP：`motion2-candidate-fast-02` / `e6daeeff3f`，主3/加5功能项通过；与旧版的运行文件/驱动相同，独占监测通过。但主/加帧间隔平均98.691/100.588ms，p95为142/153ms，**比首轮旧版差，未取得性能资格**。主看对方速度偏差p95为0.07636、加看对方0.15822、加看敌人0.13431px/ms。未冻结原生所有随机实体/系统负载，不能凭这一对样本归因为候选，也不能宣称优化通过。
- 为区分版本与负载，重跑旧版`motion2-baseline-fast-03` / `97105327c1`；启动宿主后另一AIR89560出现，运行器只结束本轮自有实例，尚未启动加入端，无有效运动样本。登记证据显示89560属于RV设置组件`742815e7...`，当时使用offline占用，与game轮重叠；不是候选崩溃、不是内存压力停止。已与RV设置会话协调，后续AIR组件也共用game登记；保留双方历史。
- 原生跳跃`motion2-baseline-jump-01`启动前可提交余量不足6GiB，无AIR。保持原结果；包装器新增该启动前原因的明确分类，未改内存门槛、候选、驱动或公共runner。
- 收尾前40秒8次可提交余量为5.734、5.672、5.792、5.851、5.812、5.562、5.518、5.051GiB（`motion2-memory-resume-01.json`）；随后只读AIR库存为空、余量5.54GiB，RV另有live-02登记。不能持续满足双人6GiB，暂停新增双人启动，所有本轮自有实例已清理，保留重建副本之外的日志与指纹。没有降低门槛，没有部署。
- 下一轮先用同`motion-drivers-01`重新跑旧版fast-motion和候选（输出新目录），确认可重复的帧间隔；随后用`motion2-native-input-drivers-01`对照native-jump/fast-held，再做原容器连续性、暂停和密集场景。当前安装22项若变，重新建立完整旧/新基线，不跨组合算百分比。

### 收尾后安装组合变更（2026-10-21）

收到RV设置会话的部署回执后，使用本轮`installation()`与`motion2-baseline-fast-02/intent.json`逐项比较，直接确认22项中有两项变化：

- RealisticVision：`76314b819151fba6f67f6d740b21030a9eec8359af4c9c9ddeb83d4caf5c46b7` → `8d4a19634770acca0b66c8c684955855ef4725e80fbdff329451d69710c55bf1`。所有者记录为v0.33.0-vision-settings；其251断言等是他方回执，不计为RConnect运动验收。
- MoreSkills&Weapons：`b7a3c811d0a073f026a5e810386699c1059f99ef066012992cfde605ff96e402` → `526a6fd09297fb4f502236076b4252bf97bb50d2f77000b13763cf118546ab71`。本轮只确认文件变化，未推断具体改动或性能影响。

RConnect和pfe未变。原测试仍作为旧组合证据保留，不能与新组合混算；下一轮先重新跑安装574D基线，再以同驱动比较motion2。此次只核对与登记，没有运行新测试、修改他方文件或部署RC。

之后CS会话完成SATS宿主部署：本会话直接核对正式`pfe.swf`为`7d423bd7b7dd7d2b997e692bd1e22ef520879cd42387c14653c116c15385bcd4`，其回执`mods/ContinuousScene/state/sats-deployment-20261021.json`为verified，备份`mods/ContinuousScene/build/backups/sats-20261021-154054/pfe.swf`为旧BEFC。RC仍574D。CS所报199项发布前/60项安装后验证属于其自己的范围，不算RC联机验收。随后本会话只读发现AIR库存为空、可提交余量7946752000字节（约7.40GiB），按用户已有“可以开始测试”授权恢复原任务，新组合原生跳跃基线使用`motion2-baseline-jump-02`，不与旧组合混算。

### 新宿主原生跳跃检查与夹具修正

- `motion2-baseline-jump-02` / `4c01601d7f`（driver01）完成加载，但rbl没有满足360宽、220高且无场景物体的走廊，准备阶段0项有效运动检查。失败保留，不算模组运行故障。
- driver02改用已被既有念力夹具使用的原生地块搜索方式：320宽、160高净空，选择障碍最少的走廊；在两个隔离副本中按id/begX/begY去除4个场景障碍，未改任何地块或重力。实际位置为x160、y639，两个角色只做一次初始定位，此后键盘→原生物理→生产TCP→最终显示。
- `motion2-baseline-jump-03` / `b11a268ae1`：准确574D、新7D42宿主/RV8D4A/MSW526A，安装/驱动/独占检查保持。宿主4项通过；加入3项通过、1项失败（看到宿主body始终同一帧）。双方实际8/7次跳跃、各114px高度、357/328显示样本。**整轮失败，不作为动画或流畅度绿灯。**
- 失败前tick200起宿主本机已经是`localPose=die work=`，尚无对端；不能把此现象归因为对端同步。已有`knowledge/experiments/2026-10-03-m40-presentation.md`、`state/r13-body-effects-handoff.md`及`PeerVisualTestDoc`记录了自动旅行遗留开场animOff的同类夹具问题。原生UnitPlayer.animate在animOff时直接返回，公开`anim()`仅释放这一标志；本轮旧驱动未记录animOff，因此当前根因仍待新驱动确认，不声称已证实。
- 对b11的已留存位置轨迹做只读诊断（`position-analysis.json`）：主/加帧间隔平均50.57/55.07ms、p95为74/73ms；用收到的原生坐标线性拟合末端显示，最佳延迟约140/105ms，RMS约9.06/1.48px。时钟差以最小收包差估计，且整轮动画前提不合格，因此这些只作位置诊断，不能与旧组合高速直线样本比较或宣称优化。
- `motion2-candidate-jump-01`（同driver02）取得登记后不足6GiB，启动前拒绝，无run/无AIR；没有候选跳跃结果。
- 新NativeJump驱动在准备阶段记录animOff/生命/工作状态，仅对活体、无工作、无hardcore死亡的开场锁使用一次原生`g.anim()`，不设动画帧；测量全程另断言源动画持续推进且未再锁定，并保留两张实际场景PNG。此检查与解除动作均不进入生产代码。driver03因BitmapData.draw的Object类型编译失败，失败目录保留；补DisplayObject类型转换后，**motion2-native-input-drivers-04两个外部驱动编译成功**，清单SHA256 `677fabc0191e7809d588d2ce3b64f02c8de119131e7db46b1624d314bfa22a5b`，尚未原生运行，PNG也尚未生成。
- 最后空AIR条件下15秒4次可提交余量6104698880/6108790784/6110875648/6142369792字节（约5.69–5.72GiB，`motion2-memory-after-host-update-01.json`），仍低于6GiB。本会话无活动或排队测试，停止新增双人启动；原始失败、冻结驱动与日志已保存，正式RC不改。
- 接续优先用新driver04分别运行574D与motion2的`native-jump`，检查真实源动画前提及双方PNG，再继续fast-held/continuity/density。旧driver02的加入body失败不可改绿，也不能用解除夹具开场锁的代码冒充生产动画修复。

### 16:29后再次核对安装组合

收到LAD所有者部署回执后，直接将当前22项安装输入与`motion2-baseline-jump-03/intent.json`比较，确认两项变化：LAD由`e3233f78d7f9af8f0ac4f99aa78abb1f9fa0d4931b272d7d551b62c7c36e796e`变为`8adba6914df5aada4df12a646b6c22df4b95b9630a55dd05ca7f713621c7e3ef`；RV由8D4A变为`f2b8a973d9d2a374c9bd8f5da9d29040266954c8f139b8c85bfa0aaaa749a561`。pfe仍7D42、RC仍574D，其余输入相同。

LAD回执`mods/LightAndDarkness/state/brightness-deployment-2026-10-21.json`记录0.7.0于16:28:45安装，备份位于其`build/backups/brightness-20261021-162845-623837/LightAndDarknessMod.v0.6.0.swf`。其功能门禁属于他方验收；本会话只核对部署文件，不推断RV这次更新的具体内容，也不计为RC验收。本次没有新测试、没有修改他方文件或部署RC；下次从当前完整组合重新建立574D/候选对照，不跨组合比较。

- 候选已跑受控高速角色TCP，但尚无原生跳跃、真实念力物品、容器掉落与闪电连射通过结果；密集场景CPU/帧率未对比。不能称四类用户症状已解决。
- 微小收包校准修正不涵盖大积压寻址、源端帧本来缺失、网络批量迟到或原生整帧变慢。曲线缓存有少量额外对象，应在原生密集测试核对开销。
- 接续时重读安装22项、确认用户已退出和6GiB门槛，按共享登记串行跑相同驱动旧/新对照；使用新输出目录，禁止覆盖本轮红结果。检查渲染最后阶段的实际位置、移动样本/静止间隔和CPU，不只看收包数。
- `tools/validation/prepare_motion_continuity.py` 冻结/编译候选；`run_motion_continuity_checks.py` 执行组件；原生运动对照可复用 `run_motion_comparison.py` 的 fast-motion、continuity、pause-timing、density。角色跳跃、原生闪电和抓取应补对应实景，不把受控直线夹具当完整覆盖。
- 其它会话独立处理：`native-loading-ui`（基于房间19）、`peer-player-aura`（玩家被抓光晕）、`wall-impact-effects`（击墙火星/命中特效）。均已协调，本会话统一集成，禁止互相覆盖。ProjectileVisuals最终合并时将本轮tickBeam变更与命中特效receive/tick/reset增量分别核对。

### 10-21 傍晚恢复实测（部署前进行中）

- 用户明确继续测试和部署；开始时空 AIR、空共享占用，可提交余量 8.06 GiB。22项安装输入仍为7D42 / RC574D / RVF2B8 / LAD8ADB / MSW526A。所有运行保持整组登记、独立桌面与存储、6 GiB启动门槛，无外部AIR混跑。
- 新驱动04原生跳跃：基线 `motion2-baseline-jump-04 / 04d638b82a`、候选 `motion2-candidate-jump-02 / 7ca9da12c6` 均主6/加6通过。宿主准备日志明确记录活体 `animOff=true, pose=die`，原生 `anim()` 后测量全程无锁、源/对侧身体均推进，确认前轮夹具问题。双方各7次起跳、114px高度。平均帧间隔旧57.01/57.34ms，新54.81/56.69ms；p95旧67/72、新64/71ms。各轮双方第2张实际PNG已目检，角色正常呈现。只有一轮受控走廊，非密集性能结论。
- 双向高速念力真实输入：基线 `motion2-baseline-held-01 / 462690af35`、候选 `motion2-candidate-held-01 / 1f957add4c` 均主43/加42通过。原生箱子/掉落物，Q抓取、快速指针路径、Q释放、原生重力落地，4轮全过。接收端轨迹最佳拟合延迟旧100–110ms、新100–130ms，均不超过原160ms门槛；不声称延迟普遍降低。
- 第一套连续性基线 `motion2-baseline-continuity-01 / 44b47aebcd` 与候选 `motion2-candidate-continuity-01 / d989c21e75` 均为主21/加30行为项通过，但FA日志多次 `fa::Runtime/after #1009`，**整轮失败**。测试直接把未放入Invent的NativeTestGun挂为当前枪；FA按背包建立快照，after读取当前枪快照时为空。仅修正本模组测试：改用原生Invent.addWeapon + UnitPlayer.changeWeapon，并新增背包/装备同一实体断言；未改FA及生产候选、未删错误检查。新 `motion2-continuity-drivers-01` 编译成功，须旧/新均用此驱动重新验证，原红记录保留。

- 修正驱动后的连续性：`motion2-baseline-continuity-02 / 7d8abca53b` 与 `motion2-candidate-continuity-02 / 3375f5b90d` 均主21/加31通过，模块日志无错误；两轮原生容器掉落、SATS暂停终点/覆盖层与恢复位置通过。证据确认未登记到背包的测试枪是前轮FA空快照触发条件；本轮只改测试，不宣称修复了FA生产问题。
- 密集旧/新 `motion2-baseline-density-01 / 266aa2bb76`、`motion2-candidate-density-01 / de08d91f47`：各主25/加43功能通过，但加入侧7个8秒阶段全部未满足80帧/慢帧门槛，**两轮性能失败**。总显示帧旧368、新411；加入运动处理平均旧11.440、新11.474ms/帧，视图单次旧2.526、新2.612ms。宿主七阶段总帧旧536、新528（约1.5%差异）。控制12把LMG相同，但原生环境单位旧88/新87，并非整个世界逐项相同；不据此宣称性能提升百分比。密集低帧率仍为已知问题。
- 高速对照旧 `motion2-baseline-fast-04 / e5beeef33a` 与新 `motion2-candidate-fast-03 / 97fc004b24` 均主3/加5行为通过，无直线段停帧。主/加平均帧间隔旧78.48/79.23、新83.52/86.62ms，p95旧96/98、新98/108ms。尚不足判断版本开销，已启动紧邻旧版复测 `motion2-baseline-fast-05`；不得忽略此差异直接宣称无性能回退。
- CS告知其5432A3B9宿主候选即将部署；已协调保留7D42至紧邻旧版复测结束，结束后放行其窗口。此刻正式RC仍574D、motion2未部署。新宿主若安装，不能把旧7D42运行记录写作新组合实测。
- 紧邻旧版复测 `motion2-baseline-fast-05 / 96563f5195` 8项过，主/加均值82.21/84.52ms、p95 96/107ms。与前一旧版78.48/79.23ms存在波动；候选83.52/86.62ms接近这次旧版，但尚不足断言性能改进。结束后已通知CS释放保留窗口。
- CS安装完成后直接核对，仅pfe由7D42变为 **5432a3b9b6820a94ae15ac0a97b13c4edc534d3dc6dbed12063e0fe47677b71d**。其impact-deployment-20261021.json为verified，7D42备份为mods/ContinuousScene/build/backups/impact-20261021-175427/pfe.swf。其403+136项属于他方范围，不计入RC验收。
- 新5432实际组合：`motion2-candidate-continuity-03 / 97ec653e01` 主21/加31通过；`motion2-baseline-fast-06 / 55b6869dfd`、`motion2-candidate-fast-04 / 1aec44a7a7` 各主3/加5通过。高速平均帧间隔旧80.51/80.79ms、新84.25/85.51ms；p95旧95/94ms、新97/104ms。无直线停帧，仍不能宣称整体更流畅；5432组合未重做密集压力轮，不把7D42失败改成通过。
- 用户已收到一次明确选择：接受密集性能未达标、先部署限定运动候选，或继续优化到全部达标。**截至本轮记录仍未收到答复，因此没有安装。** 这不重复索取通常部署权限，仅针对发布技能失败门禁的已知性能限制；不能以既往另一候选的例外或等待时间代替本次决定。
- `tools/validation/release_motion_candidate.py`限定准确6E03候选及5432/RC574D安装组合；核源码/产物/实测清单、保留密集红结果，接受限制后才备份/原子替换本模组并启动安装后正常loader双人冒烟，失败自动回滚。未接受例外时拒绝且未写release/输出目录的负向检查已过，正式部署分支尚未执行。`motion2-release-01`是初版审计；补组件源指纹与实际资源证据后最终审计为 **build/m52/motion2-release-02/audit.json**，语法和只读审计通过，full_performance_qualified=false。安装文件仍574D，不触碰真实存档/配置，不覆盖新宿主。

## 19:00后按用户决定部署

- 用户明确“先部署现有版本”，接受本候选保留密集性能未达标的限制；没有再次请求部署许可。先核对22项安装与release-02审计完全一致、AIR和登记占用为空、可提交余量约14.3GiB，并向获授权的CS会话通知时段。
- 首次`motion2-release-02`安装后冒烟误带`--defer-visible`。该参数仅用于effects驱动，正常loader模式在启动AIR前即被断言拒绝；脚本自动回滚到574D。原部署回执、日志、备份`build/backup/motion2-20261021-190025-9c243e`保留，不能将本次失败改成通过。
- 部署脚本只去掉不适用的参数，保留正常loader、独立桌面、独立AppID、全部已安装模组、共享登记、内存与独占保护；不改候选生产字节。重建审计`build/m52/motion2-release-03/audit.json`，SHA256 `93aa824c9362c94bd536ff6e1ba4b21ef2231f078b986e29c1ed72af63f54afa`。
- **已部署0.2.24-motion2 / 6E03**，回执`build/m52/motion2-release-03/deployment.json`为`deployed-smoke-passed`。实际release启动的正常loader双人冒烟`da4c8dc25f`通过：两侧版本/持续心跳、加入握手、16/16敌人同步及全模组错误扫描正常；没有驱动/测试文档替换生产入口。它是安装可用性复验，不是新的视觉或FPS验收。
- 运行最低可提交内存10.98GiB，无压力停止、无外部AIR重叠；测试结束AIR/活动登记均为空，自有host/join/frozen重建副本均已清理。部署前后22项中只有RConnect SWF改变，宿主及其它模组/配置不变。
- 回滚文件：`build/backup/motion2-20261021-190201-05c148/RConnectMod.before.swf`，直接回读SHA为574D。恢复时仅原子替换本模组release/RConnectMod.swf，核对旧SHA并重启；不要以此备份覆盖宿主或其它模组。真实存档未修改。
- 用户需重启普通游戏和双开实例加载新版。`density_gate_passed=false`、`full_performance_qualified=false`继续保留；高速/念力/掉落的已定位跳动修正不等于所有实际卡顿已解决。房间19、B及其它独立增量未混入。

## 可复现入口

```text
tools/validation/prepare_motion_continuity.py build/m52/<新候选目录> --version <新版本> --build --registry-wait 300
tools/validation/run_motion_continuity_checks.py --source build/m52/motion-continuity-02/src --output build/m52/<新组件目录> [--entry RemoteMotionClockTestDoc|ProjectileContinuityChecks]
```

独立桌面运行需按当前工具权限执行；不因默认沙箱拒绝而退回前台。编译/组件会登记game占用以免干扰其他性能测试。组件的替代边界与实际复制源码清单均保存在每轮inputs.json。
