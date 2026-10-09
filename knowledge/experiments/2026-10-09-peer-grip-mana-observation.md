---
domain: knowledge-validation
type: experiments
game-version:
  - "1.02"
confidence: medium
verified: false
discovered-by: RConnect
evidence:
  - kind: decompiled-game-code
    game-version: "1.02"
    symbol: "fe.unit::UnitPlayer，teleObj持有时的dmana扣费及松手后的recMana逐帧累加"
  - kind: runtime-experiment
    summary: "0eee4c639f末态余额红；162a8db8a2同时记录持有期最低法力与末态，确认扣费后会恢复"
date-updated: 2026-10-09
---

# 抓取法力测试应观察实际持有期间

## 已确认

PeerGripTestDoc在动作后1100ms撤销许可，在4300ms才作末态检查。旧`g.mana < initialMana`把松手约3.2秒后的余额当作曾经扣费的证明。原版持有teleObj时令dmana为负；松手后dmana逐帧增加recMana，再累加到mana，最后夹紧maxmana。RConnect PeerGrip读取法力判断权限，不替代这套原生扣费/恢复。

正式28 / 0eee4c639f仅host round3 revoke的末态余额失败；所有其它个人权限、真实抬升、挣脱、撤销、投掷、暂停和释放断言通过。原失败保留，不改为成功。

## 观察到

隔离诊断162a8db8a2使用同一32602e77候选、同一十二场景与原时间窗，保留旧余额断言，另在真实g.teleObj仍指向目标的帧中记录最低法力。双端全部检查完成，新增持有期扣费检查通过。host revoke实际10000→9907.6→9962.875，42持有帧/108总样本，松手后66帧；记录的持有dmana=-2.2、recMana=0.025。`10000-42*2.2+0.025*66*67/2=9962.875`与实测吻合。

本次其它非拒绝场景同样记录到法力下降，拒绝场景没有真实持有、法力保持满值。后续正式夹具仍要求真实抬升20px/至少3持有帧，再单独检查持有期最低法力低于初值；没有改法力池、扣费、恢复、动作时间窗或其它断言。

## 推测

原失败记录45持有帧/136总样本，即松手后91帧。按同一原生流程与诊断费率，扣费99、恢复104.65，足以回满10000，符合旧断言失败。但原失败本身没有逐帧法力数据，不能声称直接观测到了这次回满过程。

## 尚未验证

正式29重新冻结该夹具并重跑，不承接诊断绿。25组不受影响且编译/运行输入完全一致的成功严格保留，剩余13组及旧21对照尚待完成。生产字节没有变化，不能把测试观察修正写成游戏法力机制修复。
