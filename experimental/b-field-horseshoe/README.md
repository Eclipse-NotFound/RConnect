# B 马蹄铁经验共享开关

基线：`build/ab/b190-field8-loadfix1-build`，source `ac5e9d6e62c35e937deeb254f13c6371d8940f23a0f42f82e578b5006ea65d81`。这里只保存源码候选和外部测试帮助；**尚未编译或运行**，不代表已通过行为验证。

## 行为

- 设置页增加“马蹄铁经验共享”，默认开，保持原有玩法。宿主决定本次全队规则，加入侧显示确认值且按钮只读；离线可保存自己下次主持时的预设。
- 开：地图经验马蹄铁由任意一人拾取，双方都获得该次奖励。关：原生 `Bonus.take` 仍给实际拾取者奖励，B 不再额外补发给队友。房间最后一个马蹄铁的额外经验与潜行尾奖仍由原版计算，开时照旧共享、关时留给拾取者。
- 不改击杀、任务或直接 `Pers.expa` 奖励路径，不改变单份地图物件、检查点或回血物件规则。切换只影响未来拾取，不能重新发放已消耗物件。
- `WorldClaims.step` 增加可选参数；同一个调用只在马蹄铁状态变成已消耗且房间计数确实减少时补发经验，避免过期/清理误报。宿主规则放在 `RoomRuntime` 实例，避免静态规则跨会话泄漏；重新连接时原有 `lastPolicy` 重置流程会重新应用持久化值。
- 新规则进入确认帧 `horseshoeShared`；旧协议仍按本轮最终 SOURCE 严格匹配，未自行修改版本号或协议版本。

## 合并

`src/` 包含7份完整覆盖。`horseshoe.patch` 是相对准确基线的7文件窄补丁；`source-manifest.json` 固定原文件和覆盖文件指纹。若主代理已改性能代码，按hunk合并 `RConnectMod`、`HostSession`、`RoomRuntime`，不要整文件覆盖。

## 外部验证帮助

`BHorseshoeChecks.as` 只允许独立 `pfe-modsettings-rconnect-b-startup-*` AIR 身份。调用 `run(mod, api.check)` 需要两名已初始化的真实玩家位于同一测试房；它从真实 `Location.rconnectObjectStep` 进入候选逻辑，覆盖：双方分别拾取 × 开/关 × 普通/最后一个带潜行尾奖，共8种；再次步进与切换规则不重发；过期点不奖励；直接原生经验不受开关影响；重新创建 Preferences 能读到保存值；原生玩家上下文恢复。保留并恢复测试角色位置、经验阈值、计数和原规则；不用于玩家实例。

`BHorseshoeCases.as` 是同现有 BFieldCases 构造/input/step API 的外部场景：先执行上述原生检查，再通过实际确认帧验证三轮关→开→关、双方设置页可见、加入侧不能改宿主规则。接入方式：复制两个帮助源码到新冻结driver来源；在 BFieldCases 添加 `horseshoe` 分支、BStartupDriverMod.external 列表及 run.py scenario choices 增加该场景。不要把工具列入模组产物。

没有测试真正断线重连、前台人工键盘操作或所有语言字号；这些不是当前帮助源码可以声称通过的内容。窗口外框高度没有增加，新内容通过现有设置页滚动访问。
