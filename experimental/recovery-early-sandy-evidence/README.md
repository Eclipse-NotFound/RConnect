# early1 + Sand003 原生加载证据复核

审查时间：2026-10-22。仅只读现有产物、源码和日志；本目录没有编译、启动游戏或修改生产／测试驱动。

**结论：当前双人候选不合格。** 首次进入和基地往返的操作恢复已得到真实控制器证据，但缓存地图重访超时；首两段也仍比同驱动单人慢。不能把已走早期交付路径、组件通过或票据存在说成“已达到单人耗时”或“已量化两侧同时绘制”。

## 准确输入

- RConnect：`10b249871b6d6189f4fab4705dd8d4dae4db619d9b3159972010e8e24791fae6`。
- 隔离宿主：`2d415dd373236fff3c7a691db4eff8327a6de97b91c23d8a818ec77082b3dd29`。
- A 旅行许可接口 Sand003：`3e220b595f54249c82fcad36e1b13364c0456c4e8b5f4e20f876c3964c7d331c`。
- 双人：`build/m52/recovery-early-sandy-scene-dual-02`，raw `3b3c31c5f5`。
- 单人：`build/m52/recovery-early-sandy-scene-solo-01`，raw `925d5f32df`。
- 旧 CEC6 回退对照：`build/m52/recovery-early-legacy-scene-dual-01`，raw `9435e4acd1`。

`audit.py` 逐行读取 raw 日志，并验证 `TRAVEL RESULT` 与原 wrapper 的 rows 完全相等、原日志 SHA 相同；不重写原结果。`dual02-solo01-audit-v2.json` 是带统一墙钟检查的最新本地分析，前两次分析保留。`legacy01-audit.json` 保留对照失败。

## 耗时、出生与控制

单位毫秒。每格为“本端就绪／包含原生输入验证的恢复操作”。输入恢复包含最多 1000 ms 的静止基线，以及原生 Stage 键盘事件后的响应。

| 流程 | 单人 | 双人主侧 | 双人加入侧 |
|---|---:|---:|---:|
| 首次随机大图 | 7178 / 7702 | 10366 / 11526 | 10508 / 11502 |
| 返回基地 | 2018 / 2357 | 2438 / 2647 | 2917 / 3235 |
| 重访同一大图 | 3290 / 3799 | 超时 | 未完成 |

首进操作恢复比单人慢 49.65% / 49.34%；基地慢 12.30% / 37.25%。这是一次准确双／单人对应流程的实测差异，不是稳定性能分布。

`elapsed` 从本端收到 `depart` 后起算，加入侧会漏掉命令传输和调度延迟。比如基地加入侧统一墙钟就绪耗时是 **3032 ms**，不是 2917 ms；首进为 10538 ms。比较端到端应优先用 `flagsReadyWall - requestedWall` 和 `controlResponseElapsed`，不要跨进程直接减 `getTimer()`。

完成的两段同房、种子和尺寸一致；首进双方位置相距 **1 px**，基地 **0 px**。原断言容差是 80 px，所以通过不等于精确逐像素同出生帧。记录位置的时点是本端就绪，未直接捕获原生 spawn 瞬间。

四次双人输入验证独立检查均通过：同一玩家和 Ctr 身份、释放态基线、末三帧水平静止、Stage KEY_DOWN 到达正确原生方向键、walk/速度/位移同向、KEY_UP 清除实际键值、下一原生帧 walk=0。没有把残余速度强制清零。首进主侧基线 **946 ms**，已接近原有 1000 ms 上限；成功与否不应通过加大窗口改变。这里使用的是原生 Stage 事件，不是物理操作系统键盘输入。

## 首绘与许可证据的边界

首进两侧都记录到初始 `waiting=true, unpainted=true` 的真实票据，且创建时 `earlyTravelPending=true`、Sand permit `held=true, phase=idle`。到本端稳定后，票据完成，许可释放。基地无票据、许可前后均未持有，符合当前预期。

但 `FirstRasterSceneProbe` 只在渲染回调返回时记录票据，并在后续测试帧轮询完成字段。它不记录实际 chunk 绘制开始和结束；两端首进 `firstReleased == firstPainted` 都是**同次轮询看到两个状态**，不能推导绘制耗时为零。主侧和加入侧“观察到已绘制”时间分别约为墙钟 `1792662986144`、`1792662987914`，不是精确完成时刻。

因此：已证明双方都进入早期交付、持有许可并完成首进；没有量化真实绘制区间的重叠。也没有连续断言许可期间其它模组绝不推进世界，未验证完整画面像素一致。

## 缓存重访失败的确定范围

1. round2 两侧均记录 `constructed ...:2`。
2. 主侧收到 ready，并执行 commit；该 handler 结束时 `ready=true, term=4, epoch=4, t_exit=19`。
3. 加入侧收到 grant，checkpoint restore 合计 **1642 ms**；handler 结束 `ready=true, term=4, t_exit=10`。
4. 之后没有加入侧 early ready，也没有任一侧 activated；主侧出现 handoff timeout，最后驱动 travel 超时。不能称它只是稍慢。
5. 本次未进入 `startInputCheck()`，因此失败流程没有 `rasterProbe.finish()` 结果。现有证据没有失败时票据 `unpainted`、renderer `sceneViewReady()`、最终许可及相关身份值，不能宣布已找到是哪一个门条件未满足，也不能凭完成流程的释放结果推断失败流程无许可泄漏。

源级审查（准确 early 构建源与实际宿主回读）已排除“checkpoint 的 drawLoc 必然替换票据”这一简单解释：

- `EarlyTravelGate.open()` 对相同 World / Land / Location / Grafon 返回同一个已有 raster 对象。
- `Grafon.sceneClear()` 清图块但不清 `rconnectRasterTicket`；`sceneOpen()` 会重新调用桥并赋返回值，因此只有桥确实返回 null／不同票据时才发生脱节。
- `World.step()` 在 loading hold 中仍推进原生 exitStep，并走 `cam.calc()`；准确 Camera 在 calc 中调用 `grafon.sceneTick()`。仅有 `onPause=true` 不能直接解释首绘永远不结束。
- `EarlyTravelGate.viewReady()` 另外还要求同一世界／玩家／位置身份、paintAllowed、至少后续一帧、原票据 `unpainted=false`、exit=0、无死亡／读档／新开档和 renderer 的当前视口完整。现有日志没有逐项终态。

下一次有界观察应只读保存：原票据 identity 与当前字段、每次 sceneOpen 返回票据是否同一个、当前 Grafon pending / sceneViewReady、World / Game / gg / Land / loc / Grafon 与创建时严格身份、exit / comLoad / t_die / ng_wait / allStat / permit，以及 RENDER 是否确实继续到来。卡住后和结束时保留一次快照即可；不改原验收阈值、不调用生产 acquire／receive、不写状态来促使完成。

## 旧 CEC6 对照

`9435e4acd1` 在加入侧首进已经 first raster ready 后，因原 1000 ms 无输入基线超时失败；主侧随后等待同伴超时。没有进入 round2，故它不是缓存重访成功的控制组，不能据此把问题限定为新 Sand 接口，也不能证明旧回退路径全流程合格。

本审查不赋予部署资格。普通分房中未旅行者的连续运行、时停 active/replay 的真实拒绝与后续完整旅行、失败取消／断线的释放还需各自准确证据。
