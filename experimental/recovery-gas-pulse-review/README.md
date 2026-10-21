# gasgr 重复毒气：只读核查

2026-10-22。仅调查；未改生产、既有followup、冻结源或安装，未编译、未运行游戏。以下是源码事实与待验证方案，不是原生通过结论。

**可以复用包内访问桥只读 `expl_t`，但不能把它称为实际脉冲次数。最小的可靠视觉证据是新建的原生gas Part；若必须精确证明每次explRun调用，则当前原版字段不够。**

## 已核实事实

- `src/fe/weapon/RConnectProjectileAccess.as:4`已有同包类型化getter，`tools/stubs/fe/weapon/Bullet.as`已有internal字段声明；getter不推进子弹、不写倒计时、不结算伤害。该桥在当前根src中，**不在冻结07中**。不能整树搬回旧src，也不能把stub编进模组形成第二个Bullet类；须沿既有external SWC方式。现有桥代码及其它同包桥支持这种做法，但本次没有实际编译/运行此桥。
- 准确BEFC宿主既有导出 `recovery-native-travel-host-01/before/scripts/fe/weapon/Bullet.as:243–253`：step先减expl_t，再在 `>0 && %explPeriod==1` 时调用explRun。`:689–694`：首次explRun先执行，之后才把倒计时设为 `(explKol-1)*explPeriod`。`:709–723`：explRun先处理破坏/伤害，再调用explVis。因此计时器更新不等于整个函数成功完成，更不等于粒子成功创建。
- 原版AllData `:3376–3382`：gasgr设explKol=12、explTip=2、tipDamage=7；Bullet默认explPeriod=10。正常完整生命周期预期首次一次及后续11次，**这是配置预期，不能拿来补齐未观察到的事件**。
- `Emitter.cast:163–188`会因房间inactive或 `kols[maxkol]>=12` 返回而不建Part。AllData `:6928–6929` 的gas/pinkgas都是imp=1、maxkol=1，故不受普通imp0总量门槛，却共享12个粒子的组上限。两颗同时爆炸时，实际explRun次数与实际新Part数量可能不同。
- 当前根src `WeaponCapture.as:152–158`只观察倒计时恰好落在余数1且值不同，然后记录repeat。这比按墙钟推算保守，但仍是分支状态证据；跨过该值会漏，不可反推补发，无法证明Emitter成功。该代码不是07准确祖先，不作为直接合并方案。
- 冻结07只有单个shot.explosion；ImpactEventQueue按 `explosion:seq`去重。即便采到后续脉冲，仅改repeat布尔值仍会被当作同一次事件丢掉。后续实现必须给实际事件独立子序号，并保留一次性、暂停、离房和补包规则。

## 最小下一步

先做一颗真正gasgr的外部观察：正常装备/投掷输入，仅记录已有Bullet对象的 `remaining()`、isExpl、in_chain、房间、真实帧边界，同时观察每个**新对象身份**的gas Part和最终舞台像素。不调用explRun/explosion，不改expl_t，不按周期造包。先在没有其它毒气源的场景建立对应，再用两颗重叠、组上限、暂停、离房和故意漏采帧作反例；实际脉冲观察、实际Part数、远端播放数分别报告。

若要先做到“不伪造可见毒气”，可把gas Part首次出现作为视觉事件来源，复用UnitPresentation已有的每房每帧对象链遍历，增加只在存在待观察gasgr时启用的Part分类与弱键去重，不再为每颗弹/每把枪扫描一遍全图。应保存真实Part的出现位置与时间，不以期望的12次补齐。无明确来源归属的重叠Part不能硬算到最近子弹；需采用房间内粒子事件身份，或明确记为归属未证，不能冒充射手事件。

若严格要求“精确每次explRun且不漏采”，需在实际执行边界增加单调事件计数/有界事件记录，或在Emitter成功创建处记录真实Part；现有remaining getter做不到。那会涉及原生Bullet/Emitter观察接口，范围比复用RC桥更大；本轮不实施，也不建议为此提前打宿主补丁。先等当前MSW原生结果，再决定是否采用Part证据方案或扩大原生观察范围。

本目录只保存结论和来源哈希；没有候选代码，也没有把静态配置次数当作实测数量。
