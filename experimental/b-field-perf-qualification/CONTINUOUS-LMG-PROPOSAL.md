# 独立持续射击基准提案

2026-10-25；仅代码核对与未应用的改动方案。没有改动 AB007、运行器、资格脚本、产品或安装文件，没有编译/启动游戏。field21 原四轮仍未合格，不能用本方案的新结果改写原结论。

## 结论

可以让每个阶段都从足量弹匣开始，减少原生装弹在慢帧下造成的负载断档。应由**主侧在每阶段准备时处理两个真实玩家已有的轻机枪**，加入侧只接收原有快照。无需每阶段重新装备，也不应在测量中补弹、清装弹/攻击计时或改输入。

有一个容量限制：原生 LMG 的 `rapid=2`、弹匣 90、装弹 60 步。沿用原基准每 3 秒射击 2.5 秒，在 30 帧/秒下，一分钟约发射 750 发。因此指定的 **600 发只足够当前较慢场景，不能静态保证一分钟不装弹**。本提案仍用 600；如果消耗完毕或发生装弹，整轮应判为这种工作负载无效，不能中途补填。若冻结前决定覆盖正常 30 帧/秒，应将同一常量改为至少 800，并对两组使用同一版本重新跑四轮；这里未代为更改容量决定。

## 已核实的准备时机与执行环境

- `ABBench.equip()` 在联机前由 `ABBProbe.prepare()` 对各自本机角色执行。加入角色随后在主侧通过 `NativeAccess.createPlayer()` 从个人资料重建。原生 `Invent.save()` 保存 `hold`，**不保存 `holder`**；只在最初 `equip()` 改容量不能保证主侧的远端玩家保持新容量。
- 宿主 `mod.host.actors[0/1]` 是两名真正被模拟的玩家。其 `context` 是普通对象，使用 `mod.access.scope.run(actor.context, operation)` 临时绑定对应 `World.gg/invent/pers/loc`，完成后原实现用 `finally` 恢复。不要另造 ActorContext 类或永久替换 World。
- `holder/hold` 是已有枪械的公开字段，单纯赋值自身没有全局访问；仍放在各自 context 内，避免后续准备逻辑误用另一人的背包。**不调用** `equip()`、`changeWeapon()`、`initReload()`、`reloadWeapon()`、`setLocPos()`、`setPers()` 或 GUI 刷新来“补满”。这些调用不必要，部分会重置生命周期或影响背包。
- 每阶段 `spawn()` 后、发 `phase` 消息前，只写一次容量与弹匣；原有 5 秒预热继续。两人的完整状态会经 `PlayerActor.snapshot.weapon.native` / `ClientReplica.NativeFields.apply` 正常传播，加入侧不写镜像弹匣。
- **每阶段都重新准备**，否则 80 敌人阶段会继承 8 敌人阶段的剩余弹匣，重新引入先后阶段依赖。备用弹药沿用已有值，不重设，开始计量时再记录真实总量。
- 预热结束只验证满弹匣与无装弹，不做第二次补填。原攻击计时保留。若上一阶段尾部仍在途的开火输入意外消耗了已准备弹匣，则明确失败；不悄悄修正再当合格。此时应先修订并重新冻结准备协议，不能筛选有利轮次。本最小方案不新增准备握手。

## 未应用的最小源码差异

基于 `build/ab/ab-driver-007/src/ABBench.as`，SHA256 `18a10ce2ec1d76eb500c3ec529033562e8cda3f56656e9b5974b9de79bdfff81`。以下仅供制作**新名字的新驱动副本**，不能应用回冻结 AB007。除这个文件外，`ABBProbe` / `ABPayloadB` 无需玩法改动。

在类字段处增加：

```as3
private static const MAGAZINE:int=600;
private static const SAMPLE_MS:int=750;
private var phaseReserve:Array=[];
```

在 `ammo()` 后增加两个小方法：

```as3
private function prepareMagazines():void {
 if(!isB || !host)throw new Error("Sustained LMG preparation needs B host");
 phaseReserve=[];var records:Array=[];
 for each(var actor:Object in mod.host.actors) {
  mod.access.scope.run(actor.context,function():void {
   var g:Object=actor.unit,gun:Object=g.currentWeapon;
   if(gun==null || gun.id!="lmg" || gun.variant!=0 || gun.ammo!="p556" ||
      gun.rapid!=2 || gun.rashod!=1 || gun.kol!=1)
    throw new Error("Unexpected native LMG for sustained workload");
   var record:Object={player:actor.id,beforeCapacity:gun.holder,beforeHold:gun.hold,
      reload:gun.t_reload,attack:gun.t_attack,reserve:g.invent.items[gun.ammo].kol};
   gun.holder=MAGAZINE;gun.hold=MAGAZINE;
   phaseReserve.push(record.reserve);
   record.capacity=gun.holder;record.hold=gun.hold;records.push(record);
  });
 }
 log("magazine-prepared",{phase:phase,capacity:MAGAZINE,sampleMs:SAMPLE_MS,players:records});
}
private function checkMagazines(full:Boolean):void {
 if(!isB || !host)return;
 var members:Array=actors();
 if(members.length!=2 || phaseReserve.length!=2)throw new Error("Missing real actors");
 for(var i:int=0;i<members.length;i++) {
  var g:Object=members[i],gun:Object=g.currentWeapon;
  if(gun==null || gun.id!="lmg" || gun.holder!=MAGAZINE ||
     gun.hold<=0 || gun.hold>MAGAZINE || (full && gun.hold!=MAGAZINE) ||
     gun.t_reload!=0 || g.invent.items[gun.ammo].kol!=phaseReserve[i])
   throw new Error("Sustained magazine contract failed: phase "+phase+", player "+i);
 }
}
```

调用位置和两处观测变化：

```diff
- spawn(phaseCounts[phase]);preparedAt=now;
+ spawn(phaseCounts[phase]);prepareMagazines();preparedAt=now;

- if(started==0 && now-preparedAt>=5000){started=now;armed=true;
+ if(started==0 && now-preparedAt>=5000){checkMagazines(true);started=now;armed=true;

  if(started<=0)return;
+ checkMagazines(false);
  if(prev>0)intervals.push(now-prev);prev=now;

- if(now-lastSample>=1000){
+ if(now-lastSample>=SAMPLE_MS){

- v.weapons.push({hold:a.currentWeapon.hold,reserve:...
+ v.weapons.push({id:a.currentWeapon.id,capacity:a.currentWeapon.holder,
+                 hold:a.currentWeapon.hold,reserve:...
```

这些是所在长行的局部替换，`reserve:...` 表示保留原行其余字段，不是可直接编译的省略号源码。`checkMagazines(false)` 在已有逐帧观测中只读两把枪及备用弹药；没有写盘，出错才走原来的 fatal 归档。这样不会漏掉两个 750ms 样本之间发生的装弹。原 `profileBegin()` 的计时开始/清空仍仅发生一次，测量期间不再清计时。

AS3 闭包只在同步 `scope.run()` 内立刻执行，不保存循环变量供以后使用。现有 actors 数组按 id 0/1 固定；可在准备处再核验 `actor.id==records.length`，发现顺序意外变化应失败，不猜对应关系。

## 测量含义改变与不变项

| 内容 | 本方案含义 |
|---|---|
| 8 / 80 真实 AI、双玩家、房间、位置、视野、镜头、命中/弹丸/壳/动画 | 沿用同一冻结场景，不替换为假对象、不隐藏画面 |
| 开火输入 | 原每 3 秒按住 2.5 秒、松开 0.5 秒，不改为一直按住；“持续”指各观察窗口都有真实射击 |
| 弹匣容量与满弹匣 | 从原 90 改 600，每阶段准备一次；这是新的合成负载，不能冒称原生完整换弹体验 |
| 射速、弹种、伤害、弹丸数量、瞄准、开火/命中路径 | 不改；准备时核验原 LMG 的 `rapid=2/rashod=1/kol=1` |
| 卡壳 | 原基准已每帧 `jammedMult=0`；容量参与原生卡壳概率的分母，但在本基准中概率原已为零 |
| HUD | 弹药数字必然改变；“画面不变”指场景和渲染路径不改，不能声称 HUD 像素完全相同 |
| 采样 | 从 1000ms 改 750ms；仍基于真实 ENTER_FRAME，不补造错过的样本。增加约三分之一低频日志/回声，基线和候选完全相同 |
| 不测的行为 | 原生 90 发弹匣耗尽后的装弹耗时、动画、自动换弹及备用弹药转移；这些应留在功能回归 |
| 不证明的事项 | 端到端延迟、GPU呈现耗时、所有武器性能、完整玩法稳定性；本对照仍是指定场景 Stage 帧间隔 |

## 新冻结与验收边界

1. 建立新的驱动目录/构建清单/源指纹；原 AB007 文件不写。现有 `field2_driver/bench.py` 固定指向 AB007，故未来执行需要一个**另存的新运行器**只改驱动路径和登记说明，不覆写旧运行器；当前未实现。旧运行器 SHA256 `5c1252fe305ecb86d81a0f0e13c480f216ec967051532fc61e5273e48ded7648`。
2. field22及准确native编译完成后，冻结新的对照计划：field9/native019 → field22/准确native → field9/native019 → field22/准确native，四个全新结果。驱动、运行器、工具和配置均显式hash核对。当前 field21-plan / field21-qualification 原样保留。
3. 不放宽：每阶段 60 秒、至少45个实际样本、6个十秒窗口各有至少8秒样本跨度、每窗口两人都真实射击、实际敌人数与 attached 为8/80、实际耗弹与生成弹丸数差逐段相等、平均/P95退步不超过5%、两轮重复比例不超过1.2。750ms不保证慢帧下必有足够覆盖，证据不足仍失败。
4. 新增工作负载限定：每个阶段宿主的两把枪都被记录为600满弹匣；进入测量前无装弹；测量全程没有容量变化、空弹匣、装弹或备用弹药变化。新资格工具将核对准备日志、样本 capacity/hold/reserve 和无 fatal，原资格脚本不改。不得把 profile 诊断轮当净性能资格。
5. 先进行短的驱动资格核验，确认两角色容量由宿主设置并被加入侧确认、预热无额外开火、旧计时未清、两个阶段分别准备；随后完整四轮统一执行。不因某轮失败而只替换其中一轮或筛选好结果。

## 源码依据

- `game-reference/decompiled/1.02/src102/scripts/fe/AllData.as:2718`：LMG 原参数。
- `game-reference/decompiled/1.02/src102/scripts/fe/weapon/Weapon.as:1180`：原生发射与攻击步计时；`1310`：缺弹触发装弹；`1429`：容量影响卡壳概率；`1583`：实际扣弹；`1709` 附近：装弹访问 `World.w.invent`。
- `game-reference/decompiled/1.02/src102/scripts/fe/unit/Invent.as:1796`：武器个人存档字段不含容量。
- `mods/RConnect/build/ab/b190-field9-build/src/RConnectMod.as:144`、`authority/NativeAccess.as:50`：先prepare、后在主侧重建加入角色。
- 同构建 `authority/NativeScope.as:29`、`PlayerActor.as:89`、`ClientReplica.as:201`：执行环境恢复及武器公开字段同步路径。
- `mods/RConnect/build/ab/ab-driver-007/src/ABBench.as`：原phase准备、5秒预热、输入节奏、每秒样本与真实弹药/发射计数。

所有结论是静态代码审查；没有宣称本新工作负载已编译或实机通过。
