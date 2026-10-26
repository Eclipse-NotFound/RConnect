# External UI regression helper

2026-10-25。`BUiCases.as` 是测试驱动源码，未编译、未启动 AIR。使用相同源码测试精确旧版与候选；不要只在候选上调用新增产品自测方法。

## 接入 BStartupDriverMod

- 根驱动将本文件与 BStartupDriverMod 一同编译；配置 `scenario="ui"`，整体 timeout 建议至少 180 秒。
- phase 0 的探索条件改为明确括号：`role=="host" && (cfg.scenario=="boundary" || cfg.scenario=="ui" || cfg.scenario=="enemies")`。原表达式对 enemies 缺少角色限定，ui 接入时不要复制该歧义。
- `setup()` 的邻房选择分支从 `scenario=="boundary"` 扩为 boundary 或 ui。保留现有左右相邻、同 limY、非 sky/prob 条件，以及 ensure/lane；两人仍先在 home，follow=false。
- setup 末尾 ui 不调用 `startExit()`。双方 phase 4 构造 `new BUiCases(mod,root,domain,cfg,role,api)`；host 在 setup 后构造，join 可在自身 phase 3 等待完后构造。api 为 `{check:check,write:write,read:read,finish:uiFinish,log:log,home:home,nextRoom:nextRoom,floorY:floorY}`。后三项仅 host 使用，join 可以 null/NaN。
- `input` 在 helper 存在时调用 helper.input() 并 return；保持在高优先级帧事件中。`step` 已完成全局错误/超时检查后，在 helper 存在时调用 helper.step() 并 return；保留低优先级，必须晚于原生 GUI 更新。
- ui 不使用原驱动 `control.json` 和 hover/boundary 状态分支。
- 原驱动的 peer-finished 提前失败检查对已创建的 ui helper 跳过。helper 通过独立 `ui-control.json` 的 end 阶段收尾：join 写 end ack、leaveSession、finish；host 在 end ack 存在且 mod.role 为空后 finish。`uiFinish` 先令原驱动 `phase=90` 再调用原 finish。否则 host 容易把 join 正常先结束误判成失败。

## 原生路径与断言

1. 共 6 次真实走过普通左右出口：host 4 次（mode 1/2，含重访后使用最新选择），join 2 次（host保持mode 1）。只把角色放到出口附近，随后注入原生方向键；以真实 actor.roomEpoch 变化和房间引用证明发生换房，绝不直接调用 transfer/commit 完成被测试的换房。
2. 每次进入前、进入后和加入侧确认房间后，分别检查 isZoom、实际 World.visual 与 SATS 显示缩放。预期值由窗口尺寸/真实房间尺寸按原生公式独立计算，避免“被复制的两个字段互相相等”假阳性。
3. 在原生 Box+Interact 上分别走 lockTip=1（开锁）和 lockTip=2（破译）分支。fixture 把角色相关资格设为10、把锁设为1和原生计时延长；这只令尝试成功可重复，不设置 actionObj/t_action/锁成功结果。实际按住 E → 原生 UnitPlayer.actAction 建立动作 → 原生计时 → Interact 完成。每种操作均先中途释放取消，再真正完成一次。
4. join 在多个不同确认值上读取实际 GUI 的 `pr_bar`、其 `pr.scaleX` 与 `celObj`，检查能看见、进度与角色当前原生计数一致、包含目标和操作名。完成尝试必须被观察到超过70%，并在取消/完成后确认原生条与actionObj清空。baseline缺actionObj时将有实质失败，不以快照字段存在代替画面断言。
5. 同一外置代码调用目标版本 VisualPose：CENTER/RIGHT 24次不同宽度文字，确认导入与随后的motion坐标一致；真实 visualNumb/visReplic/visReplic2 各12次文字变化，比较原生源图、确认图、motion图像素。不改变产品频率。

文件只在每个阶段或观察完成时写小JSON，没有每帧写大文件。进度统计在内存中。helper 本身不截图、不退出进程、不写真实存档；根runner负责隔离和清理。

基线首轮已跑完所有分支：旧版host12个缩放失败、join4个进度条失败，均符合真实原生状态。检查发现取消后原生t_action保留正数，重试最初可能采到旧动作的剩余数字；helper现通过host观察到实际新actionObj时发布actionTick，join仅采已确认到该tick的画面。这个门控对旧版同样有效，不依赖候选新增action字段，不改变失败标准。

## 边界

- lockTip=2 使用真实原生 Interact 的破解计时/结果分支，但承载物仍为测试柜子；安保终端共享/个人解锁与实际终端菜单由安保子任务独立测试。
- 文本检查覆盖可疑布局顺序的纯渲染问题，不等于真实NPC剧情和移动镜头里的主观抖动已完全验收。
- 当前覆盖普通左右出口；背景门、resize、进度中换房/掉线仍需根会话补充场景。
