# 实际毒气粒子同步：隔离候选

基线准确 `build/m52/recovery-11` / `cd721f0e56679302747ab2c9e687e20bd877a1ee8f520d6d589c7c43fa64ebb5`。只覆盖 UnitPresentation、EnergyImpactVisuals、ProjectileExplosionVisuals、DeathVisuals 四类；未改 GameBridge、协议入口、ImpactEventQueue、宿主、其它模组或安装版。**首轮旧版组件执行63项、35失败，候选因静态类型访问编译失败；当前文本修订尚未重新编译执行，原生功能、包大小和整机性能均未签收。**

原生证据沿用 `recovery-gas-pulse-review`：Bullet 的 explRun 后调用 explVis；gas/pinkgas 每次仅尝试创建一朵，而 Emitter.cast 可因 inactive 或共同12粒上限直接返回。AllData 的 gas/pinkgas 为 visualGas/visualPinkGas，静态随机帧、渐入渐出、60个原生逻辑帧寿命、随机朝向和移动、房间色调；Part.step 只负责画面和寿命，不结算伤害。因此不读取 expl_t，不推算固定12次，不匹配最近子弹或猜射手。

实现复用 UnitPresentation 已有的每房每帧对象链遍历（没有新增一次遍历）；按真实 Part 和显示类的缓存身份筛选，弱键按对象去重。每个观察到的气雾记录真实显示位置、帧、旋转、缩放、透明度、颜色及实际移除时间。它通过本机玩家的现有特效数组发送，明确标记 `roomParts:true` / `effectsOnly:true`、保留独立 `@room-gas` 房间流；玩家只是运输载体，不是粒子的推定射手。本机玩家实际投掷、当地权威NPC产生的粒子均可进入；镜像重放不能再次进入。分房时仍受既有玩家 roomKey/epoch、接收者房间和原房间所有权约束，不增加后台房间采集。

原来的独立 explosion 队列仍负责首次声音。新爆炸／死亡包的 `nativeGasParts` 明确禁止配方再次发气雾；接收气雾只建 MovieClip 显示对象，绝不进 Location.firstObj，不调用 Emitter、Part.step 或伤害。旧包仍按原生 cast 配方生成，但返回的 Part 进入弱键排除表，防止回传；四类一起合入才有这个完整防护。死亡配方也会生成 gas，不能漏合 DeathVisuals。

有界开销与生命周期：

- 源记录沿现有上限96，单粒历史最多64点，结束后保留1秒；原生正常气体共同活粒上限12。没有气体时只做已有链遍历中的类型缓存判断，不创建粒子样本。
- 房间通道只使用 delta，每包所有气体合计最多64点；未发送前缀留待下一包，结束标记必须等最后已观察点发出。不会每包重发整房完整历史。组件会用实际 AMF 编码记录字节，并检查构造的最坏64点包低于24 KiB；此检查尚未运行，不能写成实测带宽。正常30逻辑帧×12个活粒上限为360新点/秒，50ms发送约18点/包只是容量估算，不是当前机器性能测量。
- 接收复用 EnergyImpactVisuals 的房间切换清理、暂停、去重和来源时钟；气体按实际 end 结束，不采用短火花的补显示帧。现有接收上限256、无更新15秒退役仍在。若来源离房且最后终止状态未到，仍受这个既有15秒边界；本候选没有猜测剩余寿命，也不声称已解决跨房持续气体模拟。

`components/control` 与 `candidate` 用同一63项入口、边界替身和完整实际RC类，只有四类不同。检查真实对象数／零Part、重叠不同ID、无武器归属、绿／粉资源、实际姿态与颜色、重复包、增量、真实终止、暂停、离房、旧配方回环、死亡配方、有限时钟解绑、64点预算及延后终止、AMF字节、原能量击中回归。不包含真实 Part.step、原游戏资源像素、TCP 或FPS：Part及资源为明确标注的外部夹具，不能将此称为63个原生用例。

根会话串行登记运行（目录必须新建；旧失败保留）：

```powershell
python -B -X utf8 experimental/recovery-gas-pulse/check.py
python -B -X utf8 tools/validation/run_recovery_component.py --source experimental/recovery-gas-pulse/components/control --entry GasPulseChecks.as --expected 63 --output build/m52/recovery-gas-pulse-control-03 --registry-wait 900
python -B -X utf8 tools/validation/run_recovery_component.py --source experimental/recovery-gas-pulse/components/candidate --entry GasPulseChecks.as --expected 63 --output build/m52/recovery-gas-pulse-component-03 --registry-wait 900
```

首轮失败与文本修订：`control-01` 的35项失败不能全部当作新功能红项；其中原能量短火花结束断言误把同一个 `getTimer()` 内的第二次 tick 当成下一显示帧。准确11的 `EnergyImpactVisuals.tick` 在 `now<=shownAt` 时刻意保留已显示姿态，避免 ENTER_FRAME 与 RENDER 重复算帧。共用夹具现显式使用同一显示时刻及其后33ms，合并断言“同帧保留、下一显示帧退役”，仍是63项、旧新完全同源，没有改生产补帧政策。`component-01` 的编译错误为 `DisplayObject.constructor` 静态访问；改成 `Object(v).constructor`，仍读取实际对象的构造器身份。两个01目录完整保留；本代理没有启动 JVM/AIR。

采集到发送的只读审核（准确11）：唯一 `capture(gg,true)` 在 `GameBridge.readSnapshot:691`，生产调用者只有 `Session:1022` 和 `1211`。加入端1020先检查 CONNECTED/open，读取后1023立即发送；宿主1206只检查 server.bound，1211读取后1226广播，没有本地 checkpoint／缓存／重算专用读取。但 **宿主无客户端也会消费 delta**：定时1063和最后一个玩家离开315/683仍可调用；`HostServer.broadcast:76–82` 可没有任何实际发送。另 `TcpLink.send:63–68` 因socket断开直接返回且返回值是void，发送失败不会撤销delta游标。没有发现同房且连接正常时额外读取后主动丢弃的第三条路径；这不是送达确认接口。接收方 `GameBridge.updateRemote:748–759` 房间/epoch不合时会忽略整包，并在ghost创建失败时不进入812的特效接收，气体没有全量补偿；之后的新样本可重新建活粒，但已消费的最后end无法保证重送。未在本次编译错误修正中悄悄增加ACK或协议。

当前实际字段名是 `strictEnd`，不是 `packetStrictEnd`。`EnergyImpactVisuals:203` 对初始、后续、分预算前缀及终止delta均复制该字段；已有记录更新225–226从新包拷贝全部字段，因此**本候选产生的正常更新保留它**。它不是粘性接收属性：若同一id的新包省略 `strictEnd`，新对象会丢失该字段。旧版不会产生 `@room-gas` 通道，故没有正常新旧协议混发同一气体id的路径；仍应将“缺字段的人工/异常包会丢失”与“正常气体增量保留”区分，不把它描述为任意更新均保留。

后续原生入口复用 `experimental/recovery-acid-native-tests/native/AcidGroundNativeTestDoc.as` 已验证的 Invent.addWeapon/favItem、原生 G 键与双向握手准备，不复用其 acid Part 断言：改为 gasgr 后需同时记录源实际新Part ID/出现/移除时间、生产包 roomParts ID、远端显示对象及对应像素，PNG在动作采样后编码。最少双向单颗和双颗重叠、共享暂停、换房；按实际源Part数量比对，不要求恒12，不人工调用 explosion/explRun/接收器或改 expl_t。验证相邻源间隔／终止对齐、首次声音不重复、对端无新增native gas Part，以及气体静默后流量归零。原生驱动还未改写，本目录不另起运行框架；完成组件后由根判断是否推进。

03夹具修订：control-02实际63/34失败，candidate-02实际63/1失败；唯一失败为 noExpectedCount 仅清空链首但仍把12个Part的 in_chain 留作true。原生 Location.remObj（公共1.02源码2317行）会设false；采集器对保留引用继续采样是正确行为。现夹具模拟移除时也置false，不改生产，不放松“只有新粒子及其真实1500时间”的断言。此前01/02完整保留；03未运行。
