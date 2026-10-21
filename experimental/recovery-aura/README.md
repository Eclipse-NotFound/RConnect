# 玩家被队友抓起时的光晕恢复增量

基线仅为 `build/m52/coop-bundle-04`，生产 SWF SHA-256 `574d2b51490ae8b25a1396555600f56a301f8a20ae50104c0e35cf2796441afe`。本目录是稀疏源码与测试增量，**没有编译、没有启动游戏、没有部署**。不得把此前组件通过或旧候选单人通过记成此目录整合版双人通过。

## 为什么用户仍然看不到

旧 `peer-player-aura` 四文件补丁实际一直未合入安装版。旧版原生双人 `c481f352f8` 已完成双向 12 回合：主/加各 99 项通过、10 项光晕/染色失败。后续候选先被随机走廊夹具阻断，固定夹具后又被内存门槛阻断；只有组件与单人冒烟证据。motion2 仅包含运动修正，未包含玩家光晕修正。

## 行为与源码证据

- 原版 `game-reference/decompiled/1.02/src102/scripts/fe/unit/UnitPlayer.as:1817`：Q 成功后，将施法者 `teleFilter` 与 `teleTransform` 直接写到目标的根 `vis`。`dropTeleObj`（约 1904 行）清滤镜并恢复目标 `cTransform`。不是另造一个椭圆、护盾或粒子。
- `PeerGrip.as`：原有 hold 包只发鼠标和能力输入，不发光晕。增量采集原生 Q 已产生的 GlowFilter 八参数与 ColorTransform 八通道，随已有 hold 包传送。被抓者在原生更新后及最终 RENDER 重现；释放、挣脱、撤回许可、抛掷、会话/房间失效均通过 `endIncoming → aura.reset` 清理。原有 token、连接身份、房间 epoch/term 校验不变。
- `TelekinesisVisuals.as`：本地玩家在 `Location.gg` 而不在普通对象链。仅对 `loc.gg === target && target.player === true` 放行，不按一个伪造 player 标志放行。清理仍检查房间、死亡和显示对象替换，释放只恢复仍由本覆盖持有的字段；后来的本地效果不被擦除。外来滤镜限定为有限、有限数量的原生发光参数。
- `PlayerBodyEffects.as`：抓取施法端看的是远端化身，普通身体快照此前会重新写根颜色/透明度，冲掉刚设置的原生 Q 染色。仅在当前确实本地持有该队友时让出根颜色/透明度；护盾等子效果、未被抓队友的 0.75 标记、普通敌人的染色仍按原机制处理。
- `GameBridge.as`：只在三个远端玩家调用处传入真实 `peerGrip.locallyHeld(ghost)`。与旧独立候选相比，撤掉了普通敌人 `_unitView` 循环中的无用持有检查；该循环的快照明确排除玩家与 `rconnect_ghost`，无需为每个敌人每次渲染增加调用。这是范围收紧，不据静态代码声称 FPS 提升。

## 合并边界

四个生产文件：`rconnect/core/PeerGrip.as`、`rconnect/game/TelekinesisVisuals.as`、`rconnect/game/PlayerBodyEffects.as`、`rconnect/game/GameBridge.as`。

其中后三个文件和 PeerGrip 沿用此前独立修正，唯一额外生产差异是取消 GameBridge 敌人循环中的无效检查。`increment.patch` 是相对准确 574D 源的差异；`manifest.json` 保存基线、旧增量和本增量逐文件指纹。

**GameBridge 必须按补丁片段合并，不能用本目录整份文件覆盖房间或墙体效果增量。** 三个调用点分别为最终 RENDER 中的 `rec.ghost`、初次建立/绘制 `ghost`、`driveGhost`。与 RoomCoordinator/NativeLoading/ProjectileVisuals/RemoteMotion 没有直接生产文件重叠；若其它增量改 GameBridge 同一行，应保留三处第四参数并核对 `PlayerBodyEffects.apply` 签名。版本号由主会话统一决定。

## 原生驱动强化

将 `tests/` 三个 AS 文件叠加到独立测试源码副本，以整合版生产声明作 external library，编译 `PeerGripTestDoc` 与 `PeerThrowDamageTestDoc`。不要使用旧 driver-03 SWF 代替本驱动。

`PeerGripTestDoc` 现在包含 16 回合，施法者主/加互换：禁抓、允许且不挣脱、WASD 挣脱、撤销许可、E 抛出、共享暂停、显式重置、被抓者原生换房后返回。

- 仍由原生 Q/E、真实玩家运动、TCP 和原版房间切换执行；测试选择普通房使用既有 `TravelGuard.follow`，不把 `roomHold=true` 当换房。
- 维持历史成功夹具的种子 1192051184，只修改独立测试副本；生产地图随机逻辑不动。保留组合模组周期重算 Pers 的诊断与预设维护。
- 每个成功抓取阶段在最终 RENDER 比较实际 GlowFilter、RGB **及 alpha**，并在真实舞台上截取目标区域：同一帧临时仅移除根 GlowFilter，再恢复，比较有/无滤镜的最终像素。必须实际改变超过 4 个可见像素，不能仅对象有 filter 就通过。没有 stage、被遮住或完全透明导致无像素贡献均失败。
- 双向“不挣脱”回合额外保存 `presentation-peer-aura-<round>-raster-with.png / raster-without.png`，以及完整 held/released 图。主会话必须目检两侧两种施法方向；颜色、位置、形状和边缘发光与原生 Q 源图核对。
- 释放检查双方身体没有残留光晕、本机 RGB 回到抓取前；换房额外检查旧显示对象（包括已脱离显示树的旧身体）清理，并返回原房再继续另一方向。
- 像素探针只在每回合执行一次，但会产生栅格化开销，因此此驱动仅验功能和画面，不用于性能结论。PNG 仍在全部断言完成后编码。
- `PeerThrowDamageTestDoc` 保留原 20 个双向 Q/E/原生碰墙情景，验证伤害开关与清理；本次未改其伤害逻辑或断言。
- `component/PlayerAuraChecks.as` 保留原组件像素/清理检查，增加普通敌人染色不被玩家持有分支改变的检查。它不是原生双人验收替代品。

## 主会话串行验证入口

旧 `tools/validation/peer_player_aura.py` 的 `OVERLAY` 固定指向旧目录，且 `frozen` 固定旧候选类型；直接运行它会测错增量。统一冻结器应使用本目录 `src/` 与 `tests/`，记录其 manifest 指纹，然后使用已有 `run_coop_regression.py --effects --effects-driver <新驱动> --candidate <整合候选> --all-mods --land random_mane --seconds 420 --private-desktop --defer-visible --wait-host-world --registry-wait 900`。端口、版本、输入清单与内存门槛按现有主会话包装器提供。

先对 574D 负对照、再对同驱动同组合的新候选运行；正常完成必须包含两方向的像素通过、清理通过、20 回合抛掷回归及全模组无异常。旧 c481f352f8 是既有问题复现，不能替代本次组合的资格。若新驱动因走廊/回房/原生输入前提失败，保留原失败并修夹具，不放宽画面断言。

本次静态核查只证明差异范围、源代码调用关系及新增探针实现；编译、原生执行和截图结论仍由主会话填写。
