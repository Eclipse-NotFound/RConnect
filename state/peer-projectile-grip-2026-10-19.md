# 队友投掷物念力抓取修正

任务：玩家无法用念力捡起队友扔出的手雷等物品。负责会话 RConnect (5)，`01a151ba-c524-70b1-b544-a5cf605efecb`。其它并行任务不由本会话修改；统一合并由原 RConnect 会话负责。

## 接续入口（合并版失败补记）

- **最新状态：主会话合并后的全模组回归未通过，不能凭下列独立候选128/0认定组合版合格。** 失败证据 `build/cooperation/fcee59d6c2`，准确候选 `build/m52/coop-bundle-04/RConnectMod.swf`，SHA `574d2b51490ae8b25a1396555600f56a301f8a20ae50104c0e35cf2796441afe`，驱动准备目录 `build/m52/coop-bundle-functional-03`（沿用test05来源）。主会话报告240秒总限结束；本会话只读回日志确认宿主50 PASS/8 FAIL、加入侧50 PASS/6 FAIL，双方各9条结果、均无done。
- 该组合冻结 `ProjectileGrip.as` 与本overlay仍是准确原字节 `1af840a99c2f080f13e5a10264fa80e0057934231ce596edf3bdbf4fe31aa700`。记录到的抓取者minMana保持10000，扣蓝断言失败，尚不能认定是产品机制缺陷还是全模组/夹具干扰。round6宿主投酸弹，加入侧仅持有1帧后收到ineligible/retired（join.log:178–188），源端ownerHeld=0、kicks=0（host.log:167–171）；其它多个场景持有/冲量成功。
- 后续由主会话统一定位；本会话不另行修复、不启动新AIR/编译、不改安装。测试窗口已交RV，本补记只保存现成结果。下列独立对照成功与所有历史失败均保持原判。

## 独立候选交付状态（12:08）

- **实现已保存，既定旧/新各十回合对照已完成：旧版复现，候选投掷物功能断言128 PASS / 0 FAIL；未部署。** 此结果不代表全游戏零异常：旧/新加入侧日志各有两条原生Trap构造#1063，详见下文。经测候选是 `build/m52/peer-projectile-grip-04/RConnectMod.swf`，SHA `ccf842e123cdb057e10a0e39a1e85430883a62e0f6cd3d9902269805cf141801`，版本 `0.2.22-peer-grenade-01`。overlay 类与冻结候选源 SHA 均为 `1af840a99c2f080f13e5a10264fa80e0057934231ce596edf3bdbf4fe31aa700`，实测前后匹配。
- 最终完整驱动是 `build/m52/peer-projectile-test-05/build/control` 和 `.../candidate`；二者二进制相同，固定此前失败的地图种子2056490076。旧版 `910f790151`、候选 `5a5e9441a4`，均完成十回合。本轮已按约定结束，不再追加探针；短测与旧失败记录全部保留，不改判。
- 每次用已有 `tools/run_coop_regression.py`：`--effects --land random_mane --seconds 150 --responsive --visible-windows --defer-visible`；旧版 candidate 为 `build/m52/a22-fixes-39/RConnectMod.swf`、expected-version `0.2.22-fix39-keybinds`；新版用上述候选与版本。各用对应 `--effects-driver`。独立AppID，真实存档只读，不启动额外编译/测试抢占已协调窗口。
- 回执统一用 `tools/validation/analyze_peer_projectile_checks.py build/cooperation/<run>`，包含新控制器的故障日志。旧版应复现缺口；候选若失败继续按具体日志修正，不降低原生移动/冲量/引信/唯一实体断言。
- 11:17 因内存不足暂停；主会话明确交回后，12:01实测可提交余量9,439,608,832字节，候选启动前7,732,498,432字节，均高于6 GiB启动门槛。两轮运行中最低分别5,613,654,016、5,534,969,856字节，未触发512 MiB压力停止。
- 全部自有AIR已退出：旧版83176/5800、候选61112/37516；复制目录host/join/frozen均已自动清理。约12:07已把窗口明确交回主会话，可继续RV最终性能。未触碰其它会话或用户进程，本工作没有写release/游戏SWF。
- 原 RConnect 会话统一合并、后续验证和部署；本会话使用独立命名记录，避免并行覆盖 MEMORY/journal。请主会话在统一记忆更新时保留此记录入口。

## 本轮完整对照结论

| 输入/结果 | 旧版 `910f790151` | 候选 `5a5e9441a4` |
|---|---|---|
| 冻结版本 | fix39-keybinds | peer-grenade-01（候选04） |
| 完成回合 | 双侧各10个结果，完整结束 | 双侧各10个结果，完整结束 |
| 宿主断言 | 30 PASS / 34 FAIL | 64 PASS / 0 FAIL |
| 加入侧断言 | 31 PASS / 33 FAIL | 64 PASS / 0 FAIL |
| 原物体受到远端念力控制 | 0帧，复现缺口 | 每次19–59帧 |
| 念力反向拉动真实物体 | 未发生 | 每次均有反向速度，最小dx约-3.72至-4.00 |
| E抛回 | 冲量0 | 每次1个释放消息，实测冲量17.36–17.59 |
| 原生单次爆炸、引信 | 保留 | 保留；酸弹按原生碰撞结束，不强加定时引信要求 |
| 接收侧多出伤害实体 | 无 | 无；只保留一个可抓取的无模拟Obj |
| 控制器异常/未结束 | 无控制器，完成 | 新控制器故障关键字0、完整结束 |
| 原生陷阱构造异常 | join.log:30–31各1条spikes/fspikes #1063 | join.log:29–30各1条spikes/fspikes #1063 |

场景：普通手雷按E、炸药按Q松手、`spgren`持有至引信结束、酸性炸弹按E、投出普通手雷后移除投掷快捷槽/切换武器再按E。每个场景交换宿主/加入侧身份各一次。候选同时验证原生Q选取、扣蓝、源端念力光晕、代理释放/到期清理；未直接写teleObj或调用私有抓取入口。

完整记录各位于 `build/cooperation/<run>/peer-projectile-summary.json`，并保留log、run/input清单、内存记录及配置。候选host日志SHA `1d132e9a778ed5c2ab61115509d511b77e2432199c1ecf5cd404dc3d1204eb6a`；join日志SHA `0ecceb6731d5d731017df904e8d59856b05c5bd336f084a66090ceef497dbe14`。

主会话复核提醒后，回读原日志确认：候选 `join.log:29–30` 和旧版 `join.log:30–31` 均记录 `obj spawn 'spikes'/'fspikes' failed: ArgumentError: Error #1063: Argument count mismatch on fe.loc::Trap(). Expected 2, got 6.`，随后该同步批次 `spawned=0 skipped=2`。这是两批均可观察到的陷阱构造失败，尚未在本工作修复；不能把它归为此次新增控制器错误，也不能将128项功能断言通过表述为全游戏无异常。当前专用analyzer的 `passed` 只覆盖列出的功能断言、新控制器故障、错误对话框及未捕获异常，不包含这种已捕获并记录的obj spawn异常。原日志不删改，本批不追加AIR测试；交由主会话与房间同步工作统一处理。

证据边界：这是原生游戏+生产RConnect通信的功能回归，没有加载全模组，不是最终合并版本的性能或发布验收；没有直接断言玩家/敌人的爆炸扣血数值。测试使用同一原生地图种子和同一房间key `random_mane//0,4,0`，夹具高度由角色初始位置选定，旧版baseY920、候选baseY320，因此不能称逐帧完全相同的几何回放；本次候选高度与早前失败候选的320一致。换房/断线中的持有清理尚未动态覆盖。本批成功不能抹掉此前 `c9dc07f45e` 的完整失败，尤其不能把其原因仅归于Q重试；此前输入时序/随机构造条件也不同。

交付接点：使用 `tools/validation/prepare_peer_projectile_grip.py` 中 `integrate` 的精确修改，把本overlay新类接入RConnectMod初始化和ProjectileVisuals的采集/显示/删除；不拷回整个冻结fix39覆盖其它修正。实现与测试源码已在提交 `5ab2866`；本报告追加完整对照结果。统一合并后由主会话沿用发布门禁，安装版仍由其操作。

## 过程与证据

- 从准确冻结 fix39 独立构建，源码位于 `experimental/peer-projectile-grip/src`。不使用根 `src` 或正在修改的 a22 overlay 作为完整基线。
- 准备脚本：`tools/validation/prepare_peer_projectile_grip.py`。集成接点只有 RConnectMod 初始化、ProjectileVisuals 采集/显示/移除，新控制器 ProjectileGrip；不修改 Session、GameBridge 或其它模组。
- 已编译；以下过程保留最初未完成/失败状态，12:08的完整回归结论见上，不替代全模组合并验收；未部署。
- 构建 01 因冻结版 TelekinesisVisuals 缺少根源码中的 validated API 失败，已改为本类局部校验。保留构建日志。02/03 为编译迭代，04 补空闲时避免每帧重复分配清理容器。
- 测试驱动 `experimental/peer-projectile-grip/tests/PeerProjectileGripTestDoc.as`，准备脚本 `tools/validation/prepare_projectile_grip_tests.py`。同一驱动用于旧 fix39 缺陷复现和候选测试，不修改生产源码、不直接调用抓取控制器。
- 第一轮旧版测试 `build/cooperation/826c49a717` 无效：测试夹具冻结敌人时遗漏 `u!==g`，也冻结本地玩家，G 未产生手雷，45 秒超时。已修正驱动并保留原始 FAIL；不计作用户缺陷复现。自有 AIR 15968/54740 已退出，RV 实测期间交回测试资源。
- 有效旧版对照 `build/cooperation/66bfa6bcfb`：同一驱动03跑完10回合，双向原生G产生物理投掷物且远端可见，但Q持有帧数、源端 levit 帧数和可抓代理数全为0；各自仅有1次原生爆炸，接收侧无额外物理弹。明确复现本次用户问题。自有 AIR 62380/7304 均已退出。用户10:18要求继续后恢复；候选尚未运行，已重新协调测试资源，不能沿用中断前的槽位。
- 候选04回归 `build/cooperation/c9dc07f45e` 完成10回合但 **FAIL**：两侧都有且只有1个无伤害代理，原生单次爆炸、引信、清理通过；Q仍0持有，需追查选取/输入衔接。没有部署，不能宣称已修复。自有AIR69280/79944退出，资源交回A41。背景有用户AIR及CS81184，本轮只作功能验证，不作独占性能判断。
- 两回合短probe `build/m52/peer-projectile-probe-01` 已编译（候选04未改），等待 A41→RC4 Q→安保→RC2 后的明确交接。诊断含按键前后鼠标/目标/代理/视线/ack，并让未命中的Q键在每次重试前释放。后续源中增加原生visSel日志以及真实运动反转/抛出冲量断言，尚未重新编译；不要把源与probe-01的冻结输入混同。RC4确认Q会被武器选择器先消费，且必须有释放帧；未给运行结论。无私有teleReady写入或直接actTele调用。
- 短probe `build/cooperation/10766bd618` **24 PASS / 0 FAIL**，固定两回合，生产仍候选04 `ccf842e123cdb057e10a0e39a1e85430883a62e0f6cd3d9902269805cf141801`。本次两侧第一下Q均成功；源物体持有14/17帧，上移约66/47px，E冲量各一次、引信/单次原生爆炸和代理清理通过。没有绕过原生选取逻辑。此前完整失败未改判，不能仅凭换成Q脉冲的本次成功断言全部失败原因；随机房间与时序也不同。待统一冻结完整驱动后完成新旧对照及所有投掷物场景。AIR71588/80188均退出，已交主会话统一接RV（本轮RC2与主会话交接消息曾交叉，已按实际启动边界澄清）。
- 完整驱动04 `build/m52/peer-projectile-test-04` 已编译，driver SHA `7303519fee9072c5ed15cf8ea8f39f8216029b78b1959ea5d09b7781df6318d3`。控制与候选用同一驱动、同一原生地图测试种子4140117634（仅独立进程的原生构造回调，结束恢复；不改生产或玩家存档），并加入选取条件日志、反向鼠标运动和真实E冲量断言。候选仍04。已登记安保/Q/RC2之后固定1旧1新两批各10回合；等待明确交接。
- 准备回放时注意到不能只选短测成功的地图：完整驱动05改用此前候选全失败的种子2056490076，其余行为/门槛未改。冻结目录 `build/m52/peer-projectile-test-05`，driver SHA `7a487bb5e5c3336702921be12256b5ac46fb0eb3cfd5479b22be6e4c08c84786`。这是后续固定1旧1新的最终输入，04未运行，不追加批次。必须证明旧失败地图在相同原生输入下可抓取，不能以成功地图替代。

## 已核实原因与实现边界

原生 `UnitPlayer.actTele` 从 `Location.firstObj` 选择可抓取 `Obj`。现有 ProjectileVisuals 只在显示层创建动画，不创建物体链条中的目标，所以另一侧可看到飞行中的手雷，却无法用原生 Q 抓取。

接收侧为已显示的原生 PhisBullet 建立一个无模拟的原生 Obj，复用同一显示对象，仅加入 firstObj；不放入 grenades、units、objs。原生 Q/E 负责选取、魔法消耗、投掷方向及力度。抓取者通过带房间代次和递增令牌的 TCP 消息发送鼠标目标和真实释放冲量。投出手雷的一侧保留唯一 PhisBullet，继续执行原生碰撞、引信与伤害。

范围是原生 PhisBullet 投掷物（普通手雷、炸药及同类特殊炸弹）；既有玩家布设地雷、敌人抓取、玩家抓取、掉落物背包拾取不重写。只增加当下房间中有效队友来源的目标。拒绝过期令牌、不同房间、已经爆炸、超距及不满足原生抓取条件的请求；有期限的持有状态在失联后清理。爆炸后的代理清理已通过本轮验证；关闭游戏/断线/换房过程中的持有清理尚未动态覆盖。

## 计划验证与证据边界

两侧分别作为投掷者，原生 G 创建手雷，另一侧移动鼠标并按 Q，分别测试 E 抛回、Q 松手、持有到原生引信结束和投出后切换武器。观察真实源物体 levit/位置、魔法消耗、源端光晕、接收侧无额外 PhisBullet、单次原生爆炸及过期代理清理。测试使用独立 AppID、新角色、隔离房间夹具；不写真实存档。

本轮固定两批已完成，AIR窗口已交回主会话；未获新交回前不启动实例。本记录不替代总体性能、发布门禁或其它任务记录。
