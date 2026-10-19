被测技能：diagnosing-bugs 2026-10-08.1（C:/Users/hello/.agents/skills/diagnosing-bugs/SKILL.md）；remains-runtime-debug / remains-auto-testing / remains-mod-build
技能归属：用户级（总控维护）；Remains 工作区
测试工作区：D:/Program Files/Steam/steamapps/common/Remains/mods/RConnect

# A 版房间载入初段的同步

## 用户现象与范围

用户明确：普通入口 A 版，载入房间前几秒两边布局、墙壁或门不同。不是 B，也不是只报告敌人插值。本轮仅修改 A 的进房显示与世界状态收发门控，不改地图生成算法、房间所有权协议或原生存档。RConnect 主会话统筹集成与部署；(4) 的准确 fix39 安装属于另一项已授权工作，不能声称带上本修复。

## 查证与实现

- 原生 `World.exitStep` 在 `t_exit==16` 时重新显示 `visual/vfon/vgui`，而 `RoomSync.check` 在 `isTransitioning()` 为真时直接返回。现有 `hold()` 只暂停运算，没有阻止尚未恢复检查点的本地房间先显示。
- 世界状态准入 `accepts` 原来只间接检查上次确认的房间键、epoch 和 term。原生房间先改变、交接尚未更新时，旧房间状态仍能通过。现在额外核对 `game.loc`、实际 `world.loc` 与已确认房间为同一对象，并核对当前 Land 身份。`acceptsReceipt` 保留原来的序号规则：主侧在 grant 前清算的最后玩家伤害仍可结算，不能因为角色已过门就丢弃。
- 04 把该规则提取为 `canSyncWorld`，同时用于三处发送路径：加入侧普通世界报告、主侧完整快照、主侧快速世界状态。原生帧之间已换房而 ready/busy 尚未更新时，不能把新房间数据带旧 stamp 发出。定向收尾的 `flushRoomReports(...,true)` 和 `flushGhostDamage` 保持原样，玩家/聊天/交接消息继续发送。该窗口由首轮原生日志中的 Timer 旅行→下一帧 seal 间隔和 Session 源码共同确认；没有把尚未观测到的错误包宣称已抓到。
- `RoomEntryView` 只维护自己的不透明加载层，放在场景上方、原生菜单及联机 HUD 下方；SATS 自带的场景副本单独覆盖。不改游戏/视觉模组的 visible、alpha、黑屏渐变。检查点应用完成并结束交接后撤下；失败继续等待，断线完整移除。
- 在帧末及最终 RENDER 再核对实际场景，覆盖“原生子对象稍后换房”和“网络回调位于帧之间”的时序。欢迎消息收到时立即采纳主侧已完成的地图参数并关闭未确认画面，不等下一个帧事件。
- native `t_exit` 仍照常推进，不能用提前设置 `onPause` 阻断原生加载计数。没有固定延迟后强行放行。

## 精确候选

- 生产基线：冻结 `build/m52/a22-fixes-39`，其 RoomSync 与已安装 fix15-keybinds 的冻结源相同，SHA256 均为 `e433962cf9bc868f104b1333b52bee5901828f087b6210db620e9bbd44dc5630`。
- 当前源入口：`experimental/a22-fixes/src/rconnect/core/RoomSync.as`、`Session.as`（欢迎消息与三处世界发送门控）、`rconnect/ui/RoomEntryView.as`（新增）。其余原生产覆盖源与 39 相同。
- 候选：`build/m52/a22-room-entry-04`，版本 `0.2.22-room-entry4-keybinds`，SWF SHA256 `1c451a56cc942e27a136614b5027928955614340f469e9cbb1aa5ac94b435f91`，完整编译通过。
- 实测包：`build/m52/a22-room-entry-testpack-05`，生产字节不变，仅将原生输入绑定到已安装根 `2a4662488ba3b690eb23acfe4b79aca3f0d9ae114e5e2dee7595af3cabffb3ea`；两条完整原生测试驱动已分别编译通过。
- 原始中间候选 `a22-room-entry-01/02/03`、全部红/绿回执保留，不能用其结果代替最新候选。03 将当前房间身份限制从所有回执缩到世界状态包；04 补齐发送侧同一身份门控。

## 已有证据

小型 AIR 组件直接编译未修改的生产 RoomSync/RoomCodec/Protocol，使用原生 AIR 显示树，以可识别颜色代替房间墙面；世界生成、检查点实体和网络端点是测试替身，不等于双人游戏实测。

| 运行 | 结果 | 意义 |
|---|---|---|
| `build/m52/room-entry-control-01` | 20 项，10 失败 | 旧版确实会先显示本地画面，切房后仍接收旧房间回执 |
| `build/m52/room-entry-candidate-01` | 20/0 | 同一初始反例变绿 |
| `build/m52/room-entry-candidate-02` | 31/0 | 加测菜单/SATS、过期 epoch/term、替换 Land、缩放、原有暂停和断线 |
| `build/m52/room-entry-candidate-03` | 32/0 | 中间源加测欢迎消息在帧间到达，全部通过 |
| `build/m52/room-entry-control-02` | 35 项，16 失败 | 更新后的同一夹具验证旧版；有序伤害回执保留，未确认场景/旧世界状态仍失败 |
| `build/m52/room-entry-candidate-04` | 35/0 | 中间03生产源全部通过，进门前最后伤害可结算，下一次grant后旧伤害被拒绝 |
| `build/m52/room-entry-control-03` | 40 项，18 失败 | 相同夹具旧源；发送门控回退为旧Session的ready/busy条件，新增两个换房/换Land反例为红 |
| `build/m52/room-entry-candidate-05` | 40/0 | 当前04生产源全部通过，含收发门控及最后玩家伤害 |

以上组件进程退出，测试前后安装件指纹不变。当前 04 生产源的最终组件回执为40/0，不将前轮项数相加当独立覆盖。对应的 inputs/result/receipt/memory-timeline 均保留。早期负对照中的“所有旧回执应拒绝”过宽，更新负对照已保留有序最终伤害。

新增 `A22RoomEntryTestDoc` 和 `A22MapEntryTestDoc` 在原有分房/地图测试之外加最终 RENDER 探针，并保存等待/放行画面和本机等待时长。原有布局、碰撞、门箱、所有权、重访与随机种子断言保留。两个原测试的 finish 只由 private 改 protected 供子类收尾，不放宽原断言。

## 原生验证与观察点修正

03生产字节（F449…）已有原生分房通过；04生产字节尚未原生验证，整图入口尚未运行。保持候选未部署。

| 原生运行 | 生产/夹具 | 结果 |
|---|---|---|
| `67a718bc00`，testpack03 / entry-room-01 | 03 / 首版逐帧探针 | 主21通过1失败、加47通过2失败，退出1。原分房、墙门、伤害、重访断言通过；三红来自新增观察点，完整保留 |
| `2a05e89b61`，testpack04 / entry-room-02 | 同一03字节 / 帧间确认身份探针 | 主21/0、加47/0，共68项，双方done=true，退出0，安装132项未变 |

首轮探针把 `ready && !busy && !isTransitioning()` 当成“当前原生房间已确认”，遗漏无旅行倒计时的帧间激活；宿主在 Timer 中进入新房，加载层正确出现，却误报残留。加入侧的 grant 之后，测试 Timer 在下一次 RENDER 前立即尝试被禁止的跨图旅行，探针仍记着更早房间，误报当前已确认房间应该被覆盖并拒绝当前代次包。日志相邻的 travel/grant/seal 可核对这些顺序。修正为在实际 grant/ack 处理后记录确认的原生 room/Land，RENDER 再独立核对身份；没有删除覆盖、旧包拒绝或结束撤盖断言，也没有改生产字节来让该轮通过。

两轮各4张等待/放行PNG保留在对应cooperation目录。已目检2a05e89b61加入侧：加载提示完整可读、HUD/联机入口仍可见；放行后原生场景可见，无加载层残留。该轮等待计时包含真实原生造图/联机握手，不作为独占性能或加载加速证据。

04新探针另检查收到的世界数据与携带房间编号一致，并检查原生换房后的发送门控。已核对生产 `GameBridge.readSnapshot()` 实际包含 `readWorldInfo()` 的 `roomKey`，探针所读字段真实存在。测试窗口已交回主会话；不能自行按空进程插队。最终04两组由主会话另行明确交接。

2026-10-19 11:14 停点：主会话的安保重跑在启动前因可用提交内存低于6GiB而阻止，未启动游戏；明确恢复顺序为安保→Q→房间04→RC5完整，RV另看稳定窗口。随后本会话只读采样约6.08GiB，不构成稳定窗口或调度交接，未启动04原生测试。最终候选及两份生产修改源指纹仍与上文一致；安装仍为准确fix39。主会话负责合并共享MEMORY/journal与统一部署；本会话独立源码已提交6686801、9ae3914，没有未结束的自有游戏进程。

- 已冻结 `build/m52/a22-room-entry-runtime-02`，inputs SHA256 `d5ca9d9d9e26d2f73d23bcbf89082d454fabff9a1c31881b45e43429efd1c1a0`。132份文件中130份复用自有 runtime19，不链接安装文件；变化仅当前 loader-manifest 和准确 fix39 模组。
- `runtime-01` 在普通沙箱创建第一个硬链接时得到 WinError5，没有完成输入清单；不使用该未完成目录。02 用既有隔离测试权限执行同一冻结入口后成功，没有放宽指纹检查。
- 待运行：`run_a22_map_refresh.py candidate`，candidate=`build/m52/a22-room-entry-testpack-05`，bundle=`build/m52/a22-room-entry-runtime-02`，expected-version=`0.2.22-room-entry4-keybinds`；先 entry=`A22RoomEntryTestDoc` / land=`random_mane` / label=`entry-room-final-01`，后 entry=`A22MapEntryTestDoc` / land=`rbl` / label=`entry-map-final-01`。均使用新标签、原600秒上限及6GiB启动门槛，不能修改旧回执。

## 技能实战回流

本轮采用“用户确认现象 → 原生加载顺序与同步代码对照 → 可失败的实际生产类组件 → 修复 → 原生场景追加观察”。先验证真实调用链的等待/恢复时序，未用纯字符串检查宣称运行成功；内存不足期间继续组件工作，也未将模拟世界替身当原生游戏证据。全原生结果及真人反馈仍待补齐。未改技能规则。
