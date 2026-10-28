# A 第二轮：原生话语与抛掷反馈

最终状态：已由根任务整合到EB6D/animfix3并部署。真实双人结果 `02364cdc46` 的12项通过、1项输入证据不足详见本目录analysis；没有完整E键输入或最后t_throw=1输入的独立记录。准确全源和发布边界见 `state/a-visual-feedback-repair-2026-10-28.md`。下述子任务未编译描述是交接当时状态。

基线：`build/m52/a-stutter-repair-02/src` / F14A。子任务仅提交本目录源码与集成片段；没有编译、AIR 实测或部署。根会话统一集成。

## 机制与修正

- 原版 `Unit.replic`（1.02 Unit.as:4813）调用 `Emitter.emit("replic")`，生成独立 Part，不属于角色姿态。加入侧 AI 冻结，旧协议没有这条 Part 路径。新 `NativeTextEmitter` 委托原生 cast 后观察实际返回的 Part，不另选随机台词；加入侧用原生 replic/replic2 emitter 播放，保留原生样式、文本颜色、位置、寿命及运动。源 Part 提前消失会发结束消息；消息修订号与 tombstone 防重复/重放；房间代际改变清理。
- `EnemyGrip` 获准 release 给宿主真实敌人冲量与 t_throw=45；稍后原生 `damageWall` 在伤害前清零 t_throw，再用单位自己的 numbEmit 显示准确数字。旧代码只同步血量，加入侧没有对应数字来源。
- 新桥只临时观察该被抛目标的原生 numbEmit。普通飞行中枪弹命中（t_throw>0）不会被该回调发送。碰撞输出使用真实 Part 的文本、frame、颜色和比例；聚合模式读取真实 hitPart 变化，不用血量差生成数字。收到的消息只显示，不调用 damage、damageWall、replic 或奖励逻辑。
- **补齐最后1帧的独立原生信号**：全1.02 fe源码只有3处 `Emitter.emit("bum")`。`Unit.damageWall:4026` 是唯一 options=null 调用，在原生 damage 之后、弹开之前发生；另外两处是单位互撞，均传 `{scale:...}`。现在仅在此原生调用、房间/抛掷记录/t_throw清零/准确碰撞边缘坐标全部匹配时接纳反馈；不再用 t_throw>1 猜碰撞，因此 `t_throw=1` 的聚合更新同样覆盖。普通命中或自然倒计时没有这个调用，不归属给抛掷。
- 最小安全边界：只处理原生 `damageWall(1..4)`，这正是 `Unit.run` 的四个实际墙面/地板/顶棚碰撞路径。直接调用 `damageWall(0)`、外来模组改写 bum 语义或两个已结束抛掷目标在同一精确位置产生歧义时不伪造归属。暂不改宿主、伤害结算或判断逻辑。

## 集成

1. overlay 的 `src` 增加3个类：NativeTextEmitter、NativeTextVisuals、fe.unit.RConnectTextAccess。
2. `integration.patch` 为精确锚点片段（不是带行号的可直接 git apply 补丁）：RConnectMod 在 EnemyGrip 完成绑定后构造 NativeTextVisuals；EnemyGrip 接受 release 并赋冲量后调用 watchThrow。
3. 编译用外置声明新增本目录 `stubs/fe/graph/Emitter.as`、`Part.as`；现有 Unit 声明先 `import fe.graph.Emitter;`，再追加 `internal var numbEmit:Emitter;`。Part 同样先 `import fe.Pt;` 再 `extends Pt`，不使用在旧声明环境会解析失败的全限定写法。继续沿基线现有 Location/Pt 声明。不部署 stub，不能把原生 Emitter/Part/Unit 编入模组。Emitter 的必需定义：构造参数XML、静态arr:Array、public id:String、cast(Location,Number,Number,Object=null):Part。在隔离副本更新完整旧声明库再编译，不能把含两个不同Unit定义的SWC同时塞进编译路径碰运气。
4. tap 委托原生 emitter，native emitter 每次cast的字段/随机行为仍归原对象；归还 numbEmit 时先核对仍是自己的 tap，避免覆盖外来变化。
5. 只有实际联机且房间就绪时安装全局 speech/impact tap；离线、断开、等待队友或过渡时按身份归还自己仍持有的入口，不覆盖其他所有者。空房间标记使连续未就绪帧直接跳过已完成的清理，不重复分配 received/sources。所有建状态入口（包括可能先于首帧的 watchThrow）先建立房间标记，仍在房间代际变化时完整清理。

## 外部探针

`FeedbackProbe.as` 可作为现有现代双人 runner 的外部入口；输出 Local Store/stutter-result.json，静音状态、完成/错误、真实显示 Part 逐样本、网络数据都保留。覆盖真实 native replic emitter、提前取消、同条消息重复、真实 Unit.damageWall 的普通/聚合数字，第二次聚合特意使用 t_throw=1；**它没有执行玩家 E 按键，不能冒充完整念力输入回归。** 根须按 packets/rows 核对源与加入端文本/颜色/frame、取消后不残留、重复fixture不生双份；不能只凭 completed 字段授功能资格。探针经 ApplicationDomain 查产品类，不直接import该新类，避免旧声明库缺类导致产品代码嵌入外部驱动；启动资格明确 ggControl、work空、t_die=0、onPause=false。

审查重点：不存在本机数字再次转发（receiver复现使用source emitter绕开tap）；正常伤害、耗蓝、命中与背包不改；暂停时原生Part自然暂停，没有wallclock强行赶时间。

## 回归分析

`analyze_feedback.py <run目录> [--output <本目录内JSON>]` 只读 `logs/{host,join}/stutter-result.json`，逐项比较真实显示Part及网络消息；退出码0为全部证据齐全，1为明确矛盾，2为证据不足。输出记录输入SHA、双方采样覆盖、话语文字/颜色、取消、重复包显示、数字文字/颜色/frame及聚合修订。不会把completed直接视为功能通过。

根运行 `02364cdc46`（综合候选03、外部driver01）的实际分析保存在 `analysis/02364cdc46.json`：12项通过、1项证据不足，无明确失败。主/加各16条原生话语样本，颜色16763904；普通数字67、聚合65→127的双方真实文本/颜色16749070/frame1一致，聚合id3修订1→2。重复fixture收到2包、7个可见样本最多一份；真实话语提前取消后收到id1修订2结束消息，2300ms后双方无残留。**driver01没有记录碰撞输入t_throw=1，故严格最后1帧项仍标证据不足；不新增AIR整轮，也不声称完整E键输入已验。** 已以只在内存中改变本次样本的方式核查分析器能发现错误颜色、重复可见对象及缺少最终数字状态；未修改原始运行日志。
