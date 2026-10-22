# driver02 准备弹匣差异

2026-10-22，只读结论。冻结输入 `build/m52/recovery-density-corridor-drivers-02/tests`；不修改原结果或放宽比较。

实际准备快照：宿主两轮均为12把LMG、27把p308c，全部 `hold=10000`。加入侧18为12把LMG/hold0、24把p308c/hold0、3把p308c/hold12；19为12/18/9。严格比较里的70–75是按整个行内容排序后的六个槽位，不是六个稳定单位ID，不能据此指认同一六名单位发生0→12变化。

证据链：

1. `SustainedDensityTestDoc.as:332` 只给宿主新武器显式设置hold10000、damage1、destroy0、damageExpl0、precision0、deviation0、critCh0。加入侧只做移位、清除额外对象和重挂显示（369–383），没有相同数值准备。
2. 准确18/19 `GameBridge.spawnUnitPuppet:6087–6118` 用不含weap的placement XML原生构造。1.02参考 `UnitRaider:164–196` 因而走 `getXmlWeapon` 随机选择，再将 `currentWeapon.hold=currentWeapon.holder`。`Unit.getXmlWeapon:1450` 有随机ch分支。
3. 准确18/19 `UnitPresentation.receive:354–367`：若原生枪的id/variant正好相同，沿用它；不符才 `Weapon.create` 替换。1.02 `Weapon:88` 默认hold0；`Weapon:575` 只为recharg武器初始化充能。p308c原生满弹为本轮实际看到的12。receive/tick只同步姿态/装填动画，不写hold，不调用枪step/attack。故“随机原生同型号满弹被保留”与“替换同型号空弹”两条路径可以完整解释0/12分布；这不是host传来的弹匣值。
4. `arenaIdentity:365` 只取武器id；600ms稳定及ready→commit均用此简化行，实际正式 `DensityFixture.actor:32` 却还记录hold等参数。二者验证范围不一致。
5. `CorridorFixture.restoreVisuals` 暂时解除disabled只调用addVisual再恢复；原生Weapon.addVisual不写hold。`logArena:425` 在beginDensity之前；宿主仅在 `frame:576` 且 `densityProbe>0` 发射12把LMG。出现差异的27把p308c从未进入loadGuns。因此可排除“宿主已开始正式开火消耗了这些弹匣”。

观测边界：本次没有逐武器出生/替换历史或调用栈，不能声称逐一实测到了那9次原生构造分支；原生构造说明引用只读1.02参考，不冒充重新导出BEFC。已证实实际数值分布、准确RC分支、无hold同步和夹具校验遗漏。无需用新采样框架处理此准备缺口。

最小修正：仅准备期、全部80个真实镜像及正确39把武器已到达后，先只读记录原始武器参数和owner/childObjs身份；在既有枪对象上一次设置与宿主相同的七项fixture常量。不给替身建枪、不调用receive/attack、不每帧补值。ready→commit采用完整现有武器字段行（含hold、class/id/variant），并在本进程核对枪对象仍是准备时同一个、owner与childObjs仍正确；发生替换/漂移则拒绝ready，不静默重置。七段刺激、计时、发枪数量及全部门槛保持原样。

这属于性能夹具输入准备，不是产品弹匣/伤害同步修复。保存原生值后才修正夹具，并明确标记测试不验证这些参数能否由RConnect自动同步；真实生产源不动。新夹具须给同id异hold拒绝、补正可ready、只读核对不修改值、对象被替换拒绝等反例，再用相同新驱动分别重跑18/19。

关键指纹：

- SustainedDensityTestDoc `a3203104a95bc8e0ecf96f1a3e3cc1ee5ff46ff0a8f0de2341d30add473dd471`
- CorridorFixture `a49af20d77b5a17976c4bf0fb4c3c296618e59037a8b3427309db15489afdf50`
- DensityFixture `9291ef603230e0ae98df0283a5c73a43abaee53e829052e8abeae86555ffb062`
- 18/19 GameBridge字节相同 `3fe9bb83a16a57300e733806cddbe74ce55bcaf323bec15554814f4714eba967`
- 18/19 UnitPresentation字节相同 `d67dbcbed8d3ef67771eb10e41516102dabb34aad3a7065ab71ec7822ff53178`
