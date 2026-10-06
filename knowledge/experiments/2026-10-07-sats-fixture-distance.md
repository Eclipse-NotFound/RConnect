---
domain: ui-systems
type: experiments
game-version: ["1.02"]
confidence: medium
verified: true
discovered-by: RConnect
date-updated: 2026-10-07
evidence:
  - kind: runtime-experiment
    summary: "相同04438276生产字节、原24断言/时窗，固定远处fbfcbe72d9在原生look=0处失败；仅改为目标左侧90的7e8d7b27fc完整24/0。两轮body/proxy绑定、尺寸与目标资格均正确。"
  - kind: decompiled-game-code
    symbol: "fe.inter.Sats.getUnits; fe.unit.Unit.look/isMeet"
---

# SATS测试角色位置与原生视线前提

> 2026-10-07后续核对：本实验之后，0.2.18-dev/04438276已完成14组1648/0、最终旧905负控与正常无驱动eb84c49f11并部署。最新状态见[state/deployment-m46-2026-10-07.md](../../state/deployment-m46-2026-10-07.md)。下文的未部署/待验证语句描述当时阶段，原失败和因果边界保留。


正式安装仍为UI17/a569。此轮只修正测试布置，不改变MirrorHitUnit、原生锁定资格或视线判断。

正式SATS `6bdab59280` 为宿主2/0、加入2/2：原生World.step打开SATS成功，但targetEntry为空，随后驱动访问selected.v，堆栈为SatsTestDoc/tick。其实际完整视线和绑定字段未记录，不能把它认定为用户原fe.inter.Sats/getUnits #1009的重现。

只读复制驱动 `531a89e9cf` 原24项全绿：玩家与目标同高且相距90，proxy.body绑定正确，代理原生isMeet=true/look=20、可见瓦片和130×130本体均有效，只有一个原生SATS候选。此轮绿本身不解释正式红。

固定远处 `sats-debug-far-02 / fbfcbe72d9` 原24断言/时窗保持，玩家1531.8/960、目标331.8/960。代理绑定和本体尺寸/舞台/资格/瓦片均正确，isMeet=true，但原生look=0，SATS候选为空、原生错误窗口未出现；随后驱动自身selected.v空访问。宿主2/0、加入2/2。

近处 `sats-debug-near-03 / 7e8d7b27fc` 仅把偏移从±1200改为-90，原其他源码完全相同，玩家241.8/960、目标331.8/960。代理look=20，只有一个可绘制目标，原24项全绿（宿主3、加入21），包括原生开关/25次重开、真枪弹药与AP、伤害TCP收敛、宿主禁选、隐身/显形及退役清理。所有时窗与阈值保持，未手工注入SatsCel，也未绕过原生可见条件。

各轮保留冻结复制源码、driver/harness、真实双端输入和完整日志。生产候选均为044382765a2340ce9babe6f3d01eb61197a438f7d1f9ea70262601535714f042，其他57项保护保持。far的54220/69484及near的65264/34020已独立确认退出。

正式测试现在先把加入角色放在真实目标左侧90并更新原生眼睛坐标，再让原生视觉选择；补绑定/原生视线两项前提检查。目标为空时保留原失败断言后结束场景，避免第二个驱动空引用掩盖证据。原24项均保留，正式测试必须重新冻结和新跑。此证据只覆盖固定测试位置，不证明早期用户SATS故障和全部随机房间视线组合都已解决。
