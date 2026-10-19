被测技能：diagnosing-bugs 2026-10-08.1（C:/Users/hello/.agents/skills/diagnosing-bugs/SKILL.md）；remains-runtime-debug / remains-auto-testing / remains-mod-build
技能归属：用户级（总控维护）；Remains 工作区
测试工作区：D:/Program Files/Steam/steamapps/common/Remains/mods/RConnect

# A 版房间载入初段的同步

## 用户现象与范围

用户明确：普通入口 A 版，载入房间前几秒两边布局、墙壁或门不同。不是 B，也不是只报告敌人插值。本轮仅修改 A 的进房显示与消息准入，不改地图生成算法、房间所有权协议或原生存档。RConnect 主会话统筹集成与部署；(4) 的准确 fix39 安装属于另一项已授权工作，不能声称带上本修复。

## 查证与实现

- 原生 `World.exitStep` 在 `t_exit==16` 时重新显示 `visual/vfon/vgui`，而 `RoomSync.check` 在 `isTransitioning()` 为真时直接返回。现有 `hold()` 只暂停运算，没有阻止尚未恢复检查点的本地房间先显示。
- 世界状态准入 `accepts` 原来只间接检查上次确认的房间键、epoch 和 term。原生房间先改变、交接尚未更新时，旧房间状态仍能通过。现在额外核对 `game.loc`、实际 `world.loc` 与已确认房间为同一对象，并核对当前 Land 身份。`acceptsReceipt` 保留原来的序号规则：主侧在 grant 前清算的最后玩家伤害仍可结算，不能因为角色已过门就丢弃。
- `RoomEntryView` 只维护自己的不透明加载层，放在场景上方、原生菜单及联机 HUD 下方；SATS 自带的场景副本单独覆盖。不改游戏/视觉模组的 visible、alpha、黑屏渐变。检查点应用完成并结束交接后撤下；失败继续等待，断线完整移除。
- 在帧末及最终 RENDER 再核对实际场景，覆盖“原生子对象稍后换房”和“网络回调位于帧之间”的时序。欢迎消息收到时立即采纳主侧已完成的地图参数并关闭未确认画面，不等下一个帧事件。
- native `t_exit` 仍照常推进，不能用提前设置 `onPause` 阻断原生加载计数。没有固定延迟后强行放行。

## 精确候选

- 生产基线：冻结 `build/m52/a22-fixes-39`，其 RoomSync 与已安装 fix15-keybinds 的冻结源相同，SHA256 均为 `e433962cf9bc868f104b1333b52bee5901828f087b6210db620e9bbd44dc5630`。
- 当前源入口：`experimental/a22-fixes/src/rconnect/core/RoomSync.as`、`Session.as`（欢迎消息一行）、`rconnect/ui/RoomEntryView.as`（新增）。其余原生产覆盖源与 39 相同。
- 候选：`build/m52/a22-room-entry-03`，版本 `0.2.22-room-entry3-keybinds`，SWF SHA256 `f449cf85f5ec0b3cc85ae9543243f3fd9c30afaf2316600d275e40013ea98aa6`，完整编译通过。
- 实测包：`build/m52/a22-room-entry-testpack-03`，生产字节不变，仅将原生输入绑定到已安装根 `2a4662488ba3b690eb23acfe4b79aca3f0d9ae114e5e2dee7595af3cabffb3ea`；两条完整原生测试驱动已分别编译通过。
- 原始中间候选 `a22-room-entry-01/02`、全部红/绿回执保留，不能用其结果代替最新候选。03 将当前房间身份限制从所有回执缩到世界状态包，增加三条最终玩家伤害回执检查。

## 已有证据

小型 AIR 组件直接编译未修改的生产 RoomSync/RoomCodec/Protocol，使用原生 AIR 显示树，以可识别颜色代替房间墙面；世界生成、检查点实体和网络端点是测试替身，不等于双人游戏实测。

| 运行 | 结果 | 意义 |
|---|---|---|
| `build/m52/room-entry-control-01` | 20 项，10 失败 | 旧版确实会先显示本地画面，切房后仍接收旧房间回执 |
| `build/m52/room-entry-candidate-01` | 20/0 | 同一初始反例变绿 |
| `build/m52/room-entry-candidate-02` | 31/0 | 加测菜单/SATS、过期 epoch/term、替换 Land、缩放、原有暂停和断线 |
| `build/m52/room-entry-candidate-03` | 32/0 | 中间源加测欢迎消息在帧间到达，全部通过 |
| `build/m52/room-entry-control-02` | 35 项，16 失败 | 更新后的同一夹具验证旧版；有序伤害回执保留，未确认场景/旧世界状态仍失败 |
| `build/m52/room-entry-candidate-04` | 35/0 | 当前03生产源全部通过，进门前最后伤害可结算，下一次grant后旧伤害被拒绝 |

以上组件进程退出，测试前后安装件指纹不变。当前 03 生产源的最终组件回执为35/0，不将前轮项数相加当独立覆盖。对应的 inputs/result/receipt/memory-timeline 均保留。早期负对照中的“所有旧回执应拒绝”过宽，更新负对照已保留有序最终伤害。

新增 `A22RoomEntryTestDoc` 和 `A22MapEntryTestDoc` 在原有分房/地图测试之外加最终 RENDER 探针，并保存等待/放行画面和本机等待时长。原有布局、碰撞、门箱、所有权、重访与随机种子断言保留。两个原测试的 finish 只由 private 改 protected 供子类收尾，不放宽原断言。

## 原生验证接续

尚未得出双人原生通过结论。开始时提交内存余量只有约 1.3 GiB，组件验证完成后已恢复约 10.6 GiB。(4) 已完成准确 fix39 安装/短测并交回窗口；当前按主会话/RC3 的已约顺序排队，其他测试完成后再核对现场内存和安装组合。之后依次运行两条原生入口并核对退出、安装指纹和逐帧断言。本文件后续补记真实结果，未通过前不称该修复已部署。

## 技能实战回流

本轮采用“用户确认现象 → 原生加载顺序与同步代码对照 → 可失败的实际生产类组件 → 修复 → 原生场景追加观察”。先验证真实调用链的等待/恢复时序，未用纯字符串检查宣称运行成功；内存不足期间继续组件工作，也未将模拟世界替身当原生游戏证据。全原生结果及真人反馈仍待补齐。未改技能规则。
