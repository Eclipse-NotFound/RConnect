# R14：跟随失败重试与传送后的武器偏移

2026-10-09，当前会话 `01a11c5f-d9ab-7f92-813a-f9efe0a353ad`。原「RConnect」`01a086bb-378c-7f60-b8e1-50d90ffa0996` 已明确授予本会话 RoomSync、TravelGuard、TeammateNavigation 及独立 helper/专项文件；它仍唯一构建、AIR、部署、提交和主记忆维护者。

**状态：源码与外部测试驱动已完成，自查/差异空白检查通过；尚未编译或运行专项，不是已部署修复。** 本会话未写 release、游戏 SWF、用户存档、共用构建/验证入口、GameBridge 或其他会话文件。当前安装仍为 0.2.21-dev。

## 修改范围

- `src/rconnect/core/RoomSync.as`：旧实现实际调用传送前无条件清掉 followPending，目标暂缺即丢失后续尝试。现在保留意图至到达并完成房间交接，暂缺/原生明确返回 false 时以 500→1000→1500→2000 ms 间隔重试，前三次记日志。最新快照更新目的地，目标改变重置旧等待；关闭跟随、无队友信息、快照超过 3 秒、地图/epoch 不一致或剧情挑战限制会取消旧意图。双方跟随仍仅由“从原共同房间出发”触发，防止互换房间。
- `src/rconnect/core/TravelGuard.as`：返回 Boolean；目标暂不可用返回 false。原生激活拒绝且房间未变时恢复坐标索引，返回 false；原生部分改变或未知异常仍走原有保护，避免在半完成交接中盲重入。验证 world/land/gg 的 Location 身份。已在目标房间时不再随机重置出生点。最后调用 TravelPlacement。
- `src/rconnect/core/TravelPlacement.as`：同时移动本地玩家、主武器、投掷槽和魔法槽的原生位置及显示。先更新身体显示再取枪/角的附着位置；不用 actions/step/setNull，不额外开火、消耗弹药或清零装填/攻击冷却。
- `src/rconnect/core/TeammateNavigation.as`：手动传到队友身边的最终落点也调用同一位置恢复入口。
- `tests/FollowRecoveryTestDoc.as`：独立外部驱动，未加入编译/回归白名单（这些入口由原会话维护）。

## 机制证据和边界

原版 1.02：Unit.setPos 仅修改 X/Y、包围盒和 setCel；setVisPos 仅人物显示。Unit.teleport 则额外 setWeaponPos/currentWeapon.setNull。Land.setGGToSpawnPoint 调 UnitPlayer.setLocPos，先把枪放在出生点。旧 TravelGuard.follow 随后只把人 setPos 到队友坐标。Weapon.actions 对浮动枪每帧仅补齐剩余位置差的 1/5；WeaponDisplay.capture 又会将当前枪与人的实际距离传给另一端。因此已有一条可以同时影响本机和对端的明确位置链。

本机正常存储 pfe、pfe2、pfe3 的 RConnect.log 已只读查询：没有匹配到 `RConnectRoom: ERROR`、`RConnectNavigation: failed`、handoff timed out 或 follow-result failed。不能据此确认用户那次失败的具体原因，日志本来不记录临时目标缺失。未知异常不会被新重试路径掩盖。

没有修改 GameBridge.followHostWorld 的旧初连/autoFollow 分支。其同房对齐和成功换房后 raw setPos 也可由原会话酌情改用 TravelPlacement；跨图 exit 刚开始的定位涉及另外的异步链，本轮不扩大。

## 统一验证接续

1. `tools/build_effects_driver.py` 的 `--entry` 白名单加 `FollowRecoveryTestDoc`。生产 helper 会由正常 src 扫描纳入，不需特殊 stub。
2. 专项必须用 `--land random_mane`，不能沿用 probe_m50 默认 rbl；需要三个普通前景房。正式候选和测试驱动照既有独立 ApplicationDomain 流程构建，不将测试代码并入生产。
3. 驱动共四轮：加入方重试、宿主重试、重试中队友改去第三房、取消后重新打开跟随不复活旧请求。暂时从 follower 的原生 Land.locs 表取走一个不活跃房间 2500 ms，接收真实 TCP 出房快照后恢复，检查不需要另一次出房即可成功；结束/异常恢复原表。
4. 原生 LMG 随本机同房瞬移至少 300 px，调用返回即检查武器显示、首份 outgoing pose 及冷却/装填/弹药。自动跟随在 RoomSync.before 后、原生常规步骤前的第一帧检查本机枪。汇合后实际采样另一端 ghost 显示。驱动不引用新 TravelPlacement 类，可对旧 21 作为负控；预期旧版至少同房武器/计时器和失败后不再跟随为红。负控结果仍须实际执行确认。
5. 追加既有 FollowNetworkTestDoc、TeammateNavigationTestDoc、HiddenRoomFollowTestDoc、RoomCooperationTestDoc 回归；剧情/挑战及全队换图的 TravelGuard 返回值改变也要核对。不能用本专项替代原背景门失控问题的独立验证。

通信情况：2026-10-09 本会话给原会话首轮认领和机制消息成功，并收到文件授权；后续两次发送专项就绪信息返回 Codex app tool request failed，回读未确认收到。此文件是持久接续入口，消息失败不表示测试通过或任务已部署。

文件指纹见相邻 `r14-follow-recovery-inputs.json`。原会话如需自查修订可直接接手这五个文件；请在最终冻结前核对，避免复制半写入快照。
