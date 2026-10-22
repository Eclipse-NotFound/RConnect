# recovery20 镜像更新：限定只读复核

结论：没有找到可直接删除的重复原生动画循环，也没有证据支持“每个敌人每帧重建整棵显示树”。本次最有价值的发现是**旧 CPU 采样的时间范围不足以解释实际长帧**：最长同阶段帧间隔 897 ms，其中原采样覆盖的 ENTER→RENDER 入口仅 30 ms，其后到下一 ENTER 有 867 ms。应先定位这个范围，再决定函数级优化；本次不新增候选、编译或运行。

## 准确输入与职责

准确20为 [prepared.json](../../build/m52/recovery-20/prepared.json)，候选 SHA `0674019c4aeea22900aef3e2390a31aed4fafc7850e0f3a74bc5ebb2facce9f5`。以下回调的完整方法文本在14→20一致；UnitPresentation、MirrorMasks、ProjectileVisuals、PlayerBodyEffects、RemoteMotion 整类也一致。但20的通用属性探测已改，旧样本只证明调用路径，不能充当20耗时。

- [GameBridge:132](../../build/m52/recovery-20/src/rconnect/game/GameBridge.as:132) 在 ENTER 注册一次 onMirrorFrame；[340](../../build/m52/recovery-20/src/rconnect/game/GameBridge.as:340) 负责本地状态观察、队友姿态、弹体/传送效果、念力物体，以及加入侧的冻结敌人显示。加入侧不再执行这里的完整原生敌人观察。
- [tickFrozenAnims:6392](../../build/m52/recovery-20/src/rconnect/game/GameBridge.as:6392) 对当前房间的每个冻结本体处理伤害收集、一次运动采样、位置与身体动画、实际武器动画、命中代理和鼠标命中区。规模是本体数 U 加各本体实际武器槽总数 W，不是每帧重新运行敌人 AI/Weapon.step。夹具的 U=80；武器数量须读实际 roster，不能把12把开火武器当成所有动画武器。
- [onVisForceFrame:242](../../build/m52/recovery-20/src/rconnect/game/GameBridge.as:242) 是原生帧脚本之后的显示修正：玩家最终效果、弹体层重挂、容器/掉落物、逐本体视野与血条。它不正常重跑 tickFrozenAnims；只有共享暂停且收到新姿态的脏标记路径会补一次最终校正。不能拿两个遍历都涉及同一本体推断重复动画。

## 可疑项逐一核对

[UnitPresentation:399](../../build/m52/recovery-20/src/rconnect/game/UnitPresentation.as:399) 必须逐武器放置和推进显示；开火队列按事件启动原生 shoot。创建武器由 [apply:305](../../build/m52/recovery-20/src/rconnect/game/UnitPresentation.as:305) 的槽位/武器身份变化控制，并非每次 tick。旧样本 play→gotoAndPlay→constructChildren/FocusManager 表示原生时间轴创建子对象，不能仅凭构造栈认定 RConnect 重建整把武器。

[MirrorMasks:94](../../build/m52/recovery-20/src/rconnect/game/MirrorMasks.as:94) 会遍历本体和血条，但只有新遮罩待处理时才进入全显示树 maskReferences；旧样本该递归与 bitmapSignature 均0。身份不变也可能被RV改遮罩，不能凭空永久缓存。

[PlayerBodyEffects:200](../../build/m52/recovery-20/src/rconnect/game/PlayerBodyEffects.as:200) 对敌人主要处理色变与 inh；完整8条命名部件路径用于玩家，非80个敌人各递归整树。颜色/滤镜比较后才重建，不能推断每次 apply 都分配新滤镜。[ProjectileVisuals:142](../../build/m52/recovery-20/src/rconnect/game/ProjectileVisuals.as:142) 确实在 ENTER 与 RENDER 遍历活动弹体，但使用同一显示时钟，第二次还承担原生层替换后的重挂；createVisual 只在缺少显示对象时执行。原生帧/寿命/重挂语义尚无可安全删掉的重复证据。

## 原始14样本与计时范围

原始 [a6a7e27789/join.log](../../build/cooperation/a6a7e27789/join.log) 的 `PROJECTILE PROFILE`：1259个CPU样本、253行帧记录，其中24窗启用CPU采样。包含样本数不能相加，也不等于调用次数或可节省毫秒。

| 调用范围 | 包含CPU样本 |
|---|---:|
| onMirrorFrame | 295 |
| 其中 tickFrozenAnims | 278 |
| tick 内 UnitPresentation.tick / play | 111 / 71 |
| tick 内 RemoteMotion.sampleTimed | 72 |
| tick 内命中代理 syncMotion / 伤害收集 | 29 / 25 |
| onVisForceFrame | 91 |
| maskReferences / bitmapSignature | 0 / 0 |

tick 的278内有67个GC叶样本，不能把这些全部分配给某个附近临时对象。phase0没有开火时 play 样本为0，开火 phase1/5/6分别21/18/32；这支持原生射击时间轴确实有成本，不证明无事件重复构造。

普通计时末值为 motionCalls=253、motionMs=2507，viewCalls=504、viewMs=1476；七阶段实际帧数总和也是253。**这轮正常敌人推进没有两次/帧的计数证据**，但最终显示回调接近两次/帧。后者本身不足以删回调：数据没有每次 RENDER 的原生层/状态变化身份。

更关键的是原始逐窗时标：

| phase | 前帧ENTER | 该帧diagEnd入口 | 下帧ENTER | 帧间隔 | 记录窗内 | 窗后空档 |
|---|---:|---:|---:|---:|---:|---:|
| 0 | 79944 | 79974 | 80841 | 897 ms | 30 ms | 867 ms |
| 1 | 93348 | 93413 | 93856 | 508 ms | 65 ms | 443 ms |
| 5 | 125773 | 125821 | 126271 | 498 ms | 48 ms | 450 ms |
| 4 | 113130 | 113190 | 113626 | 496 ms | 60 ms | 436 ms |

仅比较相同phase相邻行；246对中113对间隔超过200 ms。24个有采样记录的窗为36–80 ms；全部253行的窗长最多114 ms。最长897 ms和498 ms对应前后均没有记录样本；按原夹具的抽样排期也未开启该窗采样，因而该次采样枚举不是它们的直接解释。仍不能排除之前诊断分配的后续影响。

驱动 [diagEnd:148](../../build/m52/recovery-density-corridor-drivers-02/tests/SustainedDensityTestDoc.as:148) 的 `end` 在 pause/getSamples/枚举之前读取，且第一次 RENDER 后清零 diagAt。因此这里叫“RENDER入口”，**不是屏幕提交完成，也不是CPU采样整理完成**。窗后空档可能含后续RENDER、实际栅格化、事件/Timer消息、GC、宿主调度等待与诊断整理；现证据不能从中指定TCP、GPU或某个模组为主因。旧 event-cost 的 netMax=79428 含准备阶段错误配对，不能拿来填补这段空档。

## 下一次最有判别力的观察

先使用根会话正在串行做的准确574D/20同夹具结果，读取已有每阶段 presentationTiming 的**差值**，不要把累计值当该阶段成本。若需一次补充诊断，优先沿既有 profile 入口与逐窗记录，针对最大的几次间隔做同样的 ENTER、RENDER入口、下一ENTER分账；保留原数量、射击、动画、寿命和全部门槛。当前仅准备纯读取脚本，不扩大任何采样范围。

若20仍表现为“动画窗几十毫秒、窗后数百毫秒”，最小新增观察应是有界地补齐**原diagEnd整理完成→下一ENTER**这段时间与该范围内现有 Session 消息处理的时标/总量，而不是在 tickFrozenAnims 再拆十几个微计时。必须单列诊断整理与无CPU样本的等待，不能将剩余时间直接标为网络。若空档主要落在窗口内，才用同一帧CPU栈区分原生 shoot 子对象、插值或视图成本。当前旧采样不能作这项判定，也不足以支持继续增加缓存候选。

## 引用指纹与边界

- 20 prepared SHA `842874fe563de894d56215bdba7538c9c1476ba82f99b43d5eeaa77e665c776f`；GameBridge SHA `260cebd0f89e348979d05d00338f7e444a1abf2c0bbe4d03350475b05e01142d`。
- 14原始join.log SHA `b4c465dea51c78218e1dadc64ab292b44a814aac4d76152e720e8362037326d6`。
- 已有 corridor driver02 SustainedDensityTestDoc SHA `a3203104a95bc8e0ecf96f1a3e3cc1ee5ff46ff0a8f0de2341d30add473dd471`；旧14采样实际来源及完整包含统计仍见 [frozen-animation evidence](../recovery-frozen-animation-review/evidence.json)。
- 不重做 [longframe-review](../recovery-longframe-review/review.md) 已否定的重复动画假说，不将14路径证据冒充20性能。此报告不是通过记录；安装仍由根会话管理。

最小复核入口 [analyze_profile.py](analyze_profile.py)，传已完成的日志目录，只向stdout打印有界标量摘要（默认最长8对，最多25对）；保留原数组0基索引与PROFILE行号，不输出调用栈或整条PROFILE，不写文件：

```powershell
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 mods/RConnect/experimental/recovery-mirror-cost-review/analyze_profile.py mods/RConnect/build/cooperation/a6a7e27789 --role join --top 8
```

新20日志完成后只替换run目录。`previous_has_samples/next_has_samples`严格表示原记录sample数是否大于0；脚本不将0自动解释为已验证关闭采样。没有DONE标记会明确保留空列表，调用者仍须选择已结束的轮次。

## 补充：正式双开与本轮隔离启动设置

仅核对本轮 `recovery-current-profile-sampler-20-01` / `043b72eaec`，没有修改进程设置、启动游戏或重跑测试。

**存在明确的启动策略差异，但尚无实际进程状态读回或因果证据。** [正式双开](../../tools/start_coop.ps1:21) 对两个新进程调用 [Start-RConnectWindow](../../tools/RConnect.Process.ps1:40)，继而 `KeepResponsive`：读取 PowerThrottling，令 `ControlMask |= 0x1`、`StateMask &= ~0x1`，写回并复读验证。只显式关闭 EXECUTION_SPEED 节流；其它位保留，不改优先级、亲和性或系统电源计划。写入失败时正式启动器只警告，不能因此保证任意正式窗口已成功应用。

[HiddenProcess](../../../ModLoader/tools/air_test_process.py:34) 使用 `CreateDesktopW` 与 `CreateProcessW`，不调用此电源接口。本轮[冻结runner](../../build/m52/recovery-current-profile-sampler-20-01/runner-source/run_coop_regression.py:348) **有现成 `--responsive`**，开启后会调用相同 helper，并生成两侧 `process-policy.json`、登记 helper 哈希；它不是因私有桌面而自动启用。本轮没有这些文件，`input.json` 两侧均无 `process_policy`，冻结 wrapper 的启动参数也未传该选项，所以只能确认“本轮没有主动应用正式入口的该设置”，不能说操作系统实际一定启用了节流。

| 项目 | 正式主窗口 | 正式第二窗口 | 本轮隔离双方 |
|---|---|---|---|
| AIR namespace | 30.0 | 30.0 | 30.0 |
| renderMode | direct | direct | direct |
| 描述符 frameRate | 未配置 | 未配置 | 未配置 |
| 初始 visible | true | true | false，原生初始化后显示 |
| 私有未切换桌面 | 启动器未指定 | 启动器未指定 | 是，各有独立桌面 |
| depthAndStencil | true | 未配置 | 未配置 |

引用：[正式主描述符](../../../../application.xml)、[第二窗口描述符](../../tools/second_player_descriptor.xml)、[本轮host.xml](../../build/cooperation/043b72eaec/descriptors/host.xml)、[join.xml](../../build/cooperation/043b72eaec/descriptors/join.xml)。正式主描述符另显式列出窗口大小调整等选项，不能将XML整体称为完全相同。

本轮两侧实际 phase0 均记录 `visible=true frameRate=30 quality=HIGH`，因此没有发现测试将目标帧率降低的证据。两侧游戏输入也均为正式安装本体的 `BEFCF050…F9B82A`；这里没有实时读取正式游玩窗口，不能保证其它模组/设置在某个正式窗口中未动态改变帧率。

已有只读接口是 `RConnectLauncher.NativePower.Read(Process)`，最终调用 `GetProcessInformation(handle,4,…,12)`；**不得用会写入的 keep_test_responsive.ps1 代替读回**。本轮 [runner.log](../../build/m52/recovery-current-profile-sampler-20-01/runner.log) 绑定 host PID57736、join PID90324。2026-10-22 02:44:13 UTC 对这两个PID尝试纯查询：CIM不可访问，`OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION=0x1000)` 两次均返回 Win32 error5/AccessDenied；没有获得句柄，没有调用任何 Set 接口。故实际 ControlMask/StateMask 本次**未知**。有读取权限的执行环境可先核对该唯一描述符和PID身份，再通过已有 Read 方法检查；当前报告不能填造0/0或1/0。

指纹：冻结runner `7eca453b13480140da5f36bb33d2319739a927562ccafdbb61a8b20cdb5ae4d3`；HiddenProcess `628ffed886db293abe0177fd42c61ac09482e04aee6aae358cf2e3d6deb0d1f9`；正式Process helper `b3fe91f9544a3a57f45b6f1c3a47fcde207f62524cedea846f45d3d4599be88d`。差异只是后续对照的输入边界，不是此次卡顿原因或性能收益证明。

## 20本轮完成后：同phase分账

仅调用上述已有纯读取函数，未再分析CPU调用栈。结果留在 [profile20-window-summary.json](profile20-window-summary.json)。`043b72eaec` 加入侧共有498行、491对同phase相邻记录，24行有采样记录、958个CPU样本；日志含完成标记。全部记录窗中位数27 ms、最大99 ms；24个有样本窗为27–91 ms。

| phase / 原数组索引 | 帧间隔 | 前帧ENTER→diagEnd入口 | 窗后→下一ENTER | 前/后有记录样本 |
|---|---:|---:|---:|---|
| 0 / 0→1 | 382 ms | 91 ms | 291 ms | 是 / 否 |
| 5 / 380→381 | 320 ms | 27 ms | 293 ms | 否 / 否 |
| 0 / 25→26 | 311 ms | 33 ms | 278 ms | 是 / 否 |
| 6 / 478→479 | 294 ms | 30 ms | 264 ms | 否 / 否 |
| 0 / 45→46 | 293 ms | 28 ms | 265 ms | 否 / 否 |

293 ms与264 ms窗后空档的相邻两帧都没有记录样本，不能用这两次自身的CPU采样枚举直接解释；382 ms那对则包含采样窗，其窗后时间仍可能含整理成本。这里只证明“已记录的镜像/帧内范围没有覆盖大部分间隔”，不把窗后时间指派给网络、GC、栅格化或操作系统，也不据14→20的帧数差宣称优化收益：本轮配置不同，性能对照由根会话按其完整输入判断。

原join.log SHA `e1a07d9379a9a0ade5f3ebde7467f84496235971be002ac60295c416ae233aa1`；本摘要 SHA `c70b50cf9d58e2d5538a314fb3bff8888414f995923cc4cf580b63288930e1f5`。摘要保留完整7阶段统计、最长8对索引、原PROFILE行号249和采样计数；所有时标仍为原值，未更改门槛或原结果。
