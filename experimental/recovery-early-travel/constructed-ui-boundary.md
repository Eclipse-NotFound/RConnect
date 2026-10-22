# 构造完成时自动开界面的窄核查

2026-10-22，只读源码核查，没有运行游戏，也未因推测扩大早交付分支。

**普通随机图的已查原生调用链，尚无“constructed 前打开 Pip/Stand”可达证据。** 因此保持已测 AS，不把人为注入 `allStat=2` 当自然流程已经复现。早交付的完整组合资格仍须覆盖此边界。

- 准确 ACC `Game.enterToCurLand:351–453`：构造 Land、`ativateLand`、`enterLand`、移除飞行效果、HUD 提示及标记更新，末尾才 constructed。没有直接运行脚本或打开菜单。
- 准确 ACC `Land.enterLand:1199–1245`：设置目的地、激活 Location、出生放置或恢复检查点。`Land.ativateLoc:1294–1340` 是 inLoc/reactivate/World.ativateLoc/lightAll。
- 准确 ACC `World.ativateLoc:1071–1101` 的 `gui.setAll()`，对应准确 GUI:1521，更新武器/物品/属性栏；`gui.dialText()` 无参数进入 GUI:1757 的 `id==null` 分支，关闭 dial/inform，不是打开对话。`controlOn` 解锁角色但不打开 Pip。
- 准确 ACC `Land.step:1633–1661` 才推进 running scripts。新 early 分支在 exitStep 返回后的同一帧再次检查，阻止这条推进。
- 准确 ACC `Location.active:97` 默认 false；构造中的 preStep 调 stepInvis。公共原版 1.02 参考 `Area.step:285–291` 首先拒绝 `!loc.active`；`Script` 构造只解析、登记，`start()` 才实际执行 `com()`。这些最后两类未在本轮 ACC 中独立导出，不能据此声称全部二进制及模组已证等价。
- 随机起点 `Location.createCheck(true)` 调 `CheckPoint.activate(true)`；公共原版参考该分支不发首次激活经验，只设检查点、视觉状态、信息并保存。不是 Pip/Stand 入口。

已知风险条件仍真实存在：如外部回调在 `constructed` 前把 `allStat` 改为 2 或开启 Pip/Stand/SATS/guiPause，原生 `World.step` 的 `allStat==1` 条件将停止 exit 倒计时。仅有本候选的 onPause 例外不能解决它，也不能以强改 allStat=1 强行跨过菜单。准确 Grafon 的 `sceneNativeCall` 可调用 CS `prepare/spawn`；本页未核对当前 CS 载体的完整执行闭包。其它独立事件回调也未全量证明。

原生必验：记录 `constructed` 前后的 allStat/Pip/Stand/SATS/guiPause、t_exit 与原生脚本阶段；若实际触发此状态，应在尚未固定 grant/restore 时撤销优化、恢复既有加载路径。若异常发生在 grant 已固定之后，则按现有失败隔离处理，不能普通取消解锁部分状态。当前没有生产修改，原 217 项组件资格不扩展成这条实机结论。
