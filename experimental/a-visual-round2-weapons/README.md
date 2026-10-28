# A 敌人武器翻转与近战显示修正

基线为正式 F14A 对应 `build/m52/a-stutter-repair-02/src`，不是工作目录的旧 `src`。
本目录仅源码覆盖、窄 diff 与独立测试源码；未启动 JVM/AIR，未改安装版。

## 查明的缺口

- `Weapon.animate()` 的原生 `scaleX` 与 `rotation` 同时取决于 `owner.celX` / `owner.storona` / `krep`。逻辑 `rot` 不是完整显示变换。F14A 的敌人完整包将 `display` 固定设为 null，高频包完全不含显示变换；接收端再用本机的 aim 字段计算翻转，所以方向可以错误。玩家已有这项数据。
- 原生 `WClub.actions()` 每帧计算挥砍/突刺偏移，`WClub.animate()` 用 `scaleY` 翻转，含 `blumR` / `plX` / `plY` 等专用显示状态。已有 `MeleeVisuals` 确实记录这些原生帧，但 F14A 的 `captureMotion()` 漏掉 `melee`。在完整快照间隔内，接收端会反复采旧历史的最后一帧。
- 完整/高频姿态共用 `RemoteMotion`。`UnitPresentation.tick()` 已用当前游标插值后的武器坐标，却仍只从 `gun.snapshot` 取近战历史，忽略后继包内包含的中间帧。补齐发送后仍需要改这一处选择。
- F14A 没有 `_weaponClock` 字段。`gun.motion` 每次 apply 重建，但匹配 `RemoteMotion.currentSample` 时位置/角度会被它覆盖；未将其误记为已经实测的根因。

## 窄修正

运行 `prepare_patch.py` 只生成本目录的三份源覆盖及累计 `weapons.patch`、`source-manifest.json`。根会话应按 patch 段合并 UnitPresentation，避免覆盖其他子任务。已合入最初显示修正的候选03只需另用 `melee-suffix.patch` 加入下述高频历史缩减。

1. 敌人完整与高频包都使用现有 `WeaponDisplay.capture()`，带原生的完整旋转/反射。
2. 高频包携带上一发送窗口的末点锚定及新的原生近战帧，只对 WClub 有值；完整快照仍保留原来的最多32帧/800ms历史。新武器流的首个高频包完整。同源戳重复发送保持窗口起点，但每次从最新历史重建后缀，保留最终RENDER对同戳末点的修正。没有增加接收侧碰撞、攻击或奖励计算。
3. 敌人 tick 使用同一位置游标选出的武器显示与后继近战历史；源反射保持离散状态，不把 +/-1 缩放插值穿零。
4. 新 `WeaponDisplay.presentPose()` 把原生世界层矩阵换算到接收端武器的实际父层；世界层武器与身体子层都可正确显示。它不改根/子时间线。

原生 WClub 构造会停止武器根与 slash 根；部分激光近战武器由原生动作切根帧。现有 `MeleeVisuals.paint()` 只有根帧变化才 `gotoAndStop`，重复停根不重建子 MovieClip。此轮没有证据要求另造一个子动画时钟，故未修改它。真实子帧仍需在外部探针结果中检查。

## 独立探针

`WeaponPoseProbe.as` 是外部 Sprite 文档类，复用当前 EffectsHarness。编译由根执行，不依赖修改产品暴露私有游标。结果写各实例独立 `Local Store/stutter-result.json`，包括 `completed/error/audioVolume/checks/specs/rows/wire`，完成后延迟 250ms 退出供 done 消息发出。

双方原生复活/控制、房间就绪后才开始。主侧创建四个原生 UnitRaider：自由/固定安装 LMG、普通 WClub、带激光根帧的 WClub。后两者从当前原版 XML 按 tip/lasm 筛选并记入结果，不猜武器 ID。源只通过真实 `attack()` 和 `step()` 产生动作，每两秒换左右瞄准，连续上下转动与开火/挥砍约 12 秒。加入侧不驱动镜像动作。

每个最终 RENDER 独立读取显示矩阵（使用实际显示树的 concatenatedMatrix），以及根和两层子 MovieClip 的帧号/类名。接收包记录 display、近战历史及来源时间，不在消息循环 JSON 序列化。检查两种反射方向确实出现、每种武器有足量真实转角、加入侧高频消息含原生显示和近战帧。保留源/接收帧用于后续离线比对与截图判断；`completed` 仅表示夹具动作和基本通路，不等同所有视觉误差通过或密集性能达标。

注意额外近战历史的包体成本仅限 WClub；真实密集近战中需记录包量/帧耗时，不把局部显示修正称为总体性能提升。

候选03真实数据发现重复历史较多，因此提供了上面的后缀缩减。证据与等价边界见 `analysis/melee-suffix-review.md`；不能以两个敌人约0.5ms的均值差归因该开销。此次后缀缩减尚待根会话构建/实测，不冒充已部署。

## 实测前发现的夹具修正

595e591bb1 的源四对象存在且矩阵变化，但全部 `onStage=false`，不能用它授予源/远端视觉比较资格。原因是夹具在 spawn 后将 NPC disabled，再调用 `world.redrawLoc()`；原生 `Grafon.drawAllObjs()` 换掉显示层，`Unit.addVisual()` 因 disabled 跳过重挂，武器留在旧层。新版探针在重绘后暂时只打开原生 `addVisual()` 的显示资格，立即恢复 disabled/trigDis；不运行 AI 或攻击。显式核对 body/weapon 都已连接本次舞台，失败时直接结束夹具，且对后续原生重绘保留同样检查。旧失败记录原样保留。

`analyze_weapon_pose.py <run目录>` 只读两侧原始结果并打印分析。它从真实世界矩阵计算行列式正负、两方向转换、实际近战变帧/不变帧、最长重复，以及根/子 clip 的实际变化；忽略 `completed` 作为视觉通过条件。按真实源矩阵拟合公共延迟并报告误差和额外停帧，拟合时间不是访问了产品私有游标。`structural_visual_checks_passed` 仅证明姿态/历史通路；`overall_smoothness_qualified` 固定 false，避免将少量变化误当整体流畅。
