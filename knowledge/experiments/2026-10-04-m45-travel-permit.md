---
domain: world-objects
type: experiments
game-version: ["1.02"]
confidence: high
verified: true
discovered-by: RConnect
date-updated: 2026-10-04
evidence:
  - kind: runtime-experiment
    summary: "旧候选受控17秒原生过渡回滚；修复后24项通过，含真实Encounter重定向及完成后许可不能复用。"
  - kind: decompiled-game-code
    symbol: "fe.World.exitLand/exitStep; fe.loc.Game.gotoLand/enterToCurLand"
---

# M45 慢换图许可调查

## 保留的最终候选失败

首次冻结的0.2.16-dev为110524字节，SHA256 `ff977e93b9fb16ecc16fd5a764eeb2569e72e9e09032e6a99ebfa0067d1405b0`。暂停专项`b82c882fb0`和完全同字节、同驱动复验`ee5790974c`均在开始阶段前失败，宿主出现房间交接超时。两端没有任何暂停专项断言，不能记为暂停通过。当时安装仍为M44。

两轮加入侧重复出现`travel begin -> random_mane`，显示世界已经是random_mane，但后续旅行又以begin为出发地；原生t_exit反复未结束。b82中加入侧Game init耗时9740ms、random_mane造图21805ms；此前有效5b2619f75c分别约1377ms、4055ms。其他模组和游戏输入指纹一致，进程策略均control=1/state=0。整体变慢有日志依据，尚未确定其系统层原因。

green5与首次最终候选解压后均235029字节，只有编译时间3字节与版本字符串1字节不同；不能把首次失败归因于新增未审查功能。两个暂停开关尚未启用，也未进入暂停测试动作。

## 需要验证的原因链

旧TravelGuard.allowTravel把宿主允许换图的期限设为墙钟15秒。RoomSync.observeHost在原生过渡中直接返回，不续许可。TravelGuard.guardTravel在期限届满而t_exit仍大于0时，会把game.curLandId等还原为先前travelState，并把t_exit清零。World.exitStep在t_exit为19时同步生成目的地图；一次造图超过15秒，下一帧就可能回滚已经获准的旅行。

因此日志吻合“许可过期→恢复begin→再次跟随宿主→45秒交接超时”，但早期日志未直接打印guard回滚。另一个静态可能是原版gotoLand因speedShtr拒绝旅行，不能仅从重复travel文字断言原因；受控慢过渡检查将区分它们。

## 确定性红验

`2244540c4e`用旧ff977字节和独立SlowTravelTestDoc：双方稳定进入begin后，宿主通过原版gotoLand发起去rbl的旅行；加入侧在真实t_exit下降到94时，借用自己拥有的onPause保持17秒。hold第14386ms记录目的地/倒计时回滚，随即再次出现begin→rbl，倒计时重启为100；17066ms时“整个保持期间目的地与倒计时不变”断言失败，宿主收到abort后结束。暂停开关始终关闭。

这是15秒许可失效的受控直接证据，不再仅凭造图耗时和重复travel文字推断。测试没有改生产字节，没有用直接设置t_exit或目标地图来代替原生旅行。

## 实现与接续

许可先匹配宿主指定的目的地图，再消费一次并锁定同一World的这一轮原生退出。退出倒计时递减或等待期间保持有效，允许Game.Encounter在第19帧合法重定向；退出结束、World替换、倒计时重新增大、匹配的房间grant或会话reset均撤销。后续退出不能复用。未延长45秒交接期限，不清除其他暂停来源。R2已只读复核，R3独占编译/AIR进行慢换图、原生重定向及授权收尾绿验。

绿验`45e14f265c`为24 PASS/0 FAIL（宿主9、加入15），候选`build/m45/travel-green/RConnectMod.swf`为110627字节，SHA256 `e83a9e03fc8c6053146ae37de3d45299ee6365ae6566fef9f7269675c6821695`。加入侧t_exit94保持17043ms未回滚，双方完成rbl交接；同目标重用及异目标退出均拒绝。随后宿主真实gotoLand(random_canter)，测试通过TCP转发宿主当时的公开世界信息以确保加入侧取得改道前的合法目标；两端由原版World.exitStep19→Game.Encounter转way，观测remaining19并完成交接，之后原random_canter许可也不能复用。未直接写生产授权字段或手工替换最终地图。

该绿验测试进程30492/56624已退出。红验为4 PASS/2 FAIL（加入侧真实回滚及宿主中止），汇总保留build/m45/slow-travel/evidence.json。首次冻结已归档到build/m45/final-superseded；原会话正在重新冻结全部源、测试和候选，做10组最终验证。本段不代表已经部署。

## 第二次冻结候选慢换图专项（后续已替代）

重新冻结的0.2.16-dev为110625字节，SHA256 `e9b626fdf2454d2b4869917a13cd245b82e47ec6912801e665bfb9a99f755f02`。`df56a27add`重复完整慢换图、真实Encounter与许可收回流程，宿主9、加入15，共24 PASS/0 FAIL，PID36756/56476由runner结束。源与测试冻结在build/m45/final-before-weapon-state；联合门禁和实际部署状态以`m45-validation-evidence.json`及部署记录为准。

## 实际部署字节的复验

后续光晕检查发现换枪时武器和光晕分属不同播放帧，已修复并重新冻结。上述e9b候选归档在build/m45/final-before-weapon-state，其通过数不冒充新产物结果。实际部署0.2.16-dev为110626字节，SHA256 `59a03d1eb3ca7d8467015c709301bc1fbe6d585342de5857e984344a33572790`。本专项在该原字节上重新完整执行：`b70c6adc2f`，24 PASS/0 FAIL。最终10组1003项及正常加载冒烟`c09279cc99`通过，完整证据见m45-validation-evidence.json和state/deployment-m45-2026-10-04.md。
