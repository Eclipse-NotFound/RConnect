---
domain: rendering
type: experiments
game-version: ["1.02"]
confidence: medium
verified: true
discovered-by: RConnect
date-updated: 2026-10-07
evidence:
  - kind: runtime-experiment
    summary: "相同04438276生产字节，固定原墙300HP后原setup减至60真实发送240破坏；只改为宿主发布layout则原23断言全绿。正式夹具已补三项前提检查，完整候选门禁尚在执行。"
  - kind: code-review
    symbol: "TerrainSync.capture/apply/settle; BeamTerrainTestDoc.setup/receive"
---

# Beam测试布置的原生伤害基线

> 2026-10-07后续核对：本实验之后，0.2.18-dev/04438276已完成14组1648/0、最终旧905负控与正常无驱动eb84c49f11并部署。最新状态见[state/deployment-m46-2026-10-07.md](../../state/deployment-m46-2026-10-07.md)。下文的未部署/待验证语句描述当时阶段，原失败和因果边界保留。


正式安装仍为紧凑UI17/a569。下列控制只运行独立测试副本，不改变ProjectileVisuals或TerrainSync，也不是新的游戏机制修复。

## 失败与缩小

同生产候选044382765a2340ce9babe6f3d01eb61197a438f7d1f9ea70262601535714f042（123147B、51类）原Beam `3118447fbe` 为19 PASS/4 FAIL：停火和死亡时总弹道数非零、双端碎片0。原生光束时长/暗隙与破墙状态同步通过。首复制观察准备01因误用final/tests路径失败，未编译或启动AIR；脚本和空目录保留，02改读verified-files。

- 只读观察02/`720170ce02`仍19/4，失败项变化：一次炮塔暗隙、死亡总弹道数和双端碎片。death-end图层没有测试光束，但总记录为2；随机敌人仍运行。wall-before已phis=0/hp=-180。
- 隔离无关敌人/旧弹丸03/`134de80749`为21/2，全部光束清理和时长绿，但墙在cooldown已经死亡。随机NPC枪计数全0，所以“无关敌人提前打碎墙”只是一开始的假设，不能作结论。
- 只读首发字段04/`f9d08238fa`原23项全绿，原生光束damage/destroy/damageExpl/explRadius都为0；这轮随机地点的墙直到真实测试射击才死亡，不倒推03或原轮因果。
- 收缩到固定条件05/`f327aa428e`：join先通过真实applyTilePatch建立原墙300HP，再执行原setup人工降到60，宿主实际收到terrain `{damage:240,destroy:false}`，墙hp=-180，原23项中的两条碎片检查失败。无关AI仍隔离，原时窗与全部断言不变。
- 同300HP条件正控06/`72a2d35b10`仅加入host布局发布/join真实接收。无240请求，wall-before仍60/phis1；真实1000射击后hp=-940。两端各6碎片，加入52可见帧/51移动，原23项全绿。05/06源码反向去除布局传递后完全相同。

每轮保留prepare/input/run-input/result、外部driver/harness和实际双端run.json/完整日志；进程独立核验退出，57保护保持。控制并非同一随机地图配对，固定300→60的红绿只证明这个具体夹具路径；原31184各失败的完整因果仍未逐条确定。

## 正式测试修正

只修改BeamTerrainTestDoc：测试开始时隔离无关敌人与旧弹丸，host发已构造的走廊布局，join先经真实applyTilePatch接受后再布置对象。保留固定旧300HP前提，并补join旧300/新60与host射击前墙仍完整三项断言；原23项、1600/1800/4500/6500ms和容差全部不变。普通石墙明确fake=false。所有BEAM DIAGNOSTIC/FLIGHT/TERRAIN REPORT只存在build复制目录，没有加入生产或正式测试。

TerrainSync将先前实体墙HP的减少识别为真实本地伤害，是合法破坏预测机制；不能为了测试忽略这类报告。布置应通过真实权威接收路径建立新观察基线。

新冻结final-after-ui-clock-02源52项和生产字节与01完全相同，验证146项。前四组通过的源/驱动/运行依赖未变，实际driver类表不含BeamTerrainTestDoc；carried-checks.json将它们明确标为保留同字节结果。改过的Beam必须新跑。完整14组、恢复旧905负控与正常无驱动加载仍须通过，不能由本实验宣布可部署。
