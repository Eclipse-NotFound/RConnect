# RConnect B — 主侧统一执行实验

实现依据：[A/B计划](../../design/host-authority-parallel-plan-2026-10-11.md)。当前：[完整游玩实施与验证](../../state/host-authority-playable-2026-10-11.md)。历史：[双房检查点](../../state/host-authority-rooms-2026-10-11.md)、[B1检查点](../../state/host-authority-2026-10-11.md)。

本目录独立于现有`src`。入口仍编译成`RConnectMod.swf`以适配原loader，但只允许`pfe-modsettings-rconnect-b-*`隔离AppID与显式实验配置；**不可复制到安装版release**。该前缀排除其他已安装模组的自动测试。A/B不互相连接，不热切换存档或正在运行的房间。

## 目前代码的职责

| 部分 | 负责什么 |
|---|---|
| `Commands` / `Link` | 身份与顺序核验、有界传输、短按保留、一次动作去重、失去输入后释放控制 |
| `WireCodec` / `FrameDelta` | AMF3编码与可靠差分；共享的不可变动画分支可分开更新，旧确认保留 |
| `NativeFields` | 保留全部可序列化公开字段；移动对象单次建表，静止对象复用不变记录，差量只认精确前份 |
| `NativeAccess` / `AuthorityPlayer` / `NativeScope` | 创建真的第二名玩家，使用自己的属性、背包、控制器和界面服务；每次调用恢复原引用 |
| `HostSession` / `RoomRuntime` | 接收输入、每房间步推进两个玩家一次、原生弹丸按所属玩家执行、受击按受击者执行、返回确认 |
| `OccupiedRooms` / `RoomTransfers` | 保留原生房间、按实际占用推进；原生出口请求在房间步之间提交，独立维护宿主显示 |
| `ClientReplica` / `ReplicaScene` / `PlaybackClock` | 在同一源时间显示确认的原生房间、玩家、敌人、物品和效果；不执行第二遍AI或伤害 |
| `NativeIntents` / `CharacterState` / `PersonalSaves` | 原生菜单动作可靠执行，各自资源和反馈、个人保存 |
| `HudModel` / `NetHud` / `SharedVision` | 紧凑连接界面、聊天/设置、透明度、可选探索共享 |
| `TacticsBridge` / `NativePerception` | 可选 TDFC 房间调度接口与两名玩家的原生索敌/暴露计算 |
| `GroundMotion` / `MovementPrediction` | 仅自己的平地移动作有界预演，按主侧确认重放未处理输入；战斗/地形变化撤销 |
| `SessionSound` / `SoundPlayback` | 主侧记录原生声效/停止/持续音效，按房间和个人界面归属播放，各自保留音量设置 |
| `SessionMusic` / `RoomMusic` | 每个占用房间推进原生战斗配乐，听者分别使用自己的音量 |
| `TerrainInk` | 记录原生弹孔、焦痕、魔法墙和血迹实际改动的64px小块；地形重画后恢复当前印记 |
| `TimeBridge` / `DeferredHits` / `TimeHistory` | 两人统一时停时钟、延后调用原生伤害、借用并恢复历史运动与原生显示，不二次耗弹 |
| `Probe` / `ContractChecks` | 仅测试配置启用，真实AIR中的协议、资源隔离与原生开火检查 |

当前B3已接入原生场景、统一显示时钟、原生菜单和各自保存；门箱/拾取/XP、念力、复活/旅行、SATS、跟随/宠物/共同挑战已有分项实测。MSW独立接口的双向武器、快速扫眼和个人保存已有专项通过。当前继续修复动画采样时机、补充友伤验证及密集场景性能；尚未形成同一冻结版本的完整回归结果，也未生成玩家候选包。

2026-10-13接续：当前B185使用原生019(b3-v12)、TDFC004、RV003、MSW011、Sandy001；精确指纹和接续以[state/MEMORY.md](../../state/MEMORY.md)为准。B182修复同尺寸窗口通知误开原生菜单，真实调整窗口和主动开菜单仍保留，退出联机恢复原监听器。原179未通过的六类均已在182通过；完整44组在第13组motion因第二只箱子未打开而停止，前12组通过。B183三轮自然诊断未复现，184受控实测证实掉落物可接收原点击，需要松开后重新按；185仅修改测试驱动的重新按键和失败详情，实际交互与动画断言保持。185整套待运行。用户确认共享时停及回放时结算伤害；默认原生/019＋独立接口未attach对照已有各34/0。密集场景仍慢，严格A/B性能对照、完整候选验收和普通无驱动启动尚未完成；B未交付。

旧版51项的[验收映射](../../design/host-authority-regression-map.json)保留缺口，清单存在不代表通过。`run_probe.py --jitter-ms 0,20,80,10,40`用于隔离回环抖动，保持真实字节与顺序；`--scenario stress --stress-seconds 120`可延长压力记录。串行运行器在执行期间不能改动。

## 复现步骤

工具位于`tools/host_authority`，所有参数从RConnect目录解析。输出必须是`build/ab`下的新目录，已有结果不会覆盖。

1. `freeze.py --runtime build/m51/map-runtime-63 --output build/ab/<新基线>`固定完整实物。已有`baseline-001`可核验后继续使用。
2. `patch_native.py --baseline build/ab/baseline-001 --output build/ab/<新原生副本>`仅修改复制品。可选接口类的精确清单见本次native-input.json；回读核对loader、类表、资源与XML查询，运行等价另验。
3. `build.py --output build/ab/<新构建> --optimized`冻结源码与外链存根、编译并记录工具及产物SHA。存根不包含进SWF。
4. 与其他RConnect测试会话错开AIR时段后，`run_probe.py --baseline build/ab/baseline-001 --candidate build/ab/<新构建> --native build/ab/<匹配的原生副本> --output build/ab/<新运行>`。
5. 核对`run.json`和双方日志中的PASS/FAIL/FATAL/DONE，之后在实际宿主核对自有PID已退出。编译、断言通过或双端DONE均不单独等于完整功能通过。

磁盘控制：常规单项也使用`run_suite.py --scenarios <单项> --archive --stop-on-failure`，其余冻结输入参数同下层运行器。抖动等专用参数需单跑`run_probe.py`时，在自有PID退出及输入校验后立即执行`archive_evidence.py --runs <运行目录>`。不得删除唯一日志、截图、源码、基线或归档存储；仅删除已核验可恢复的重复运行实物。

测试使用新的AIR存储名，不读用户角色。B1开枪夹具生成各自弹药不同的测试角色与固定原生受击单位；不模拟假HP变化。所有失败和原始日志保留。已结束运行的重复实物可按runtime-archive.json无损归档；archive_evidence.py可恢复新物理副本，审计仍校验原字节。

## 原生改动为什么存在

原游戏默认只有一名玩家，因此控制器会自动听本机键盘，伤害和武器也会读取全局当前玩家。B提供可关闭键盘监听的构造参数，以及房间、物体步和玩家受击的可选入口。未启用B时入口为空，代码继续原生分支；运行等价必须通过独立检查，不能只凭这段设计说明认定。

独立属性还不等于全部隔离完成。跨帧回调、显示与音效、其他模组的全局状态、完整死亡保存流程需要后续逐项验证。B1只证明狭窄路径，结果不能推广到所有武器和地图。

## TDFC 配套与当前冻结组

当前冻结组见上文185；具体完成情况以实施记录及各run.json为准。历史136的14阶段敌人、四轮SATS、投掷与地形，143五轮新地图/共享奖励，147分房时钟和隐藏房路线均有分项通过；这些不能合并成当前185全部通过。性能数值另列，不因功能断言通过而称流畅。

- `build_tdfc.py --output build/ab/<新TDFC构建>`复制 TDFC 完整 src/tests 后编译，始终不写安装目录。
- `run_tdfc_logic.py --baseline build/ab/baseline-001 --candidate build/ab/<TDFC构建> --output build/ab/<新逻辑运行>`执行真实 AIR 逻辑检查。
- 双人运行增加 `--tdfc build/ab/<TDFC构建> --scenario ownership --enemy tdfc`；增加 `--swap` 交换两人的资料。`--enemy native` 改用原生炮塔。
- `--scenario split-rooms --enemy native` 检查实际前景/隐藏房双房、炮塔与保留；`--enemy tdfc` 使用原生掠夺者并延长自然反应观察窗。两者还通过原生 WThrow/WMagic API 检查地雷与基础魔法的房间、资料归属，不代表这些武器的完整联机呈现已完成。
- `check_native_default.py --baseline build/ab/baseline-001 --tdfc build/ab/<TDFC构建> --output build/ab/<默认检查>`仅单人原生路径，完全不接入 B；可再传 `--native build/ab/native-hooks-003` 检查空回调。它是独立验证驱动，不是第三套生产架构。

双玩家上下文还保存负重待处理标记、各自战斗门禁，以及房间对应的绘图器、镜头和 Land 引用。无人房保留原对象，不调用 reactivate/resetUnits；弹丸历史按房间分开。TDFC 默认决策正文与新入口共用。当前实机证据支持双房执行内核，尚不能推断新架构已经可玩或比 A 更流畅。
