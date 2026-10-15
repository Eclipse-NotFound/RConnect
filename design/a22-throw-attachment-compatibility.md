# A 版念力抛掷与刺刀减速兼容修正提案

2026-10-15；用户已授权必要兼容修正、隔离测试、部署与按需协调，并明确要求“刺刀不应限制念力抛掷相关”。FA0.3.2已独立部署并本地提交f7705ed，候选/正式读回各399项全过；已向「改枪」和「改枪 (3)」返回最终报告并交回FA源码/构建/部署。RConnect动画候选仍未部署，最新全组合位图错误尚待调查。完整记录见state/a22-followup-2026-10-15.md末节与FA的knowledge/bayonet-telekinesis-2026-10-15.md。

## 已有证据

当前安装组合、Littlepip 29 复制档、真实 Q/E、原生掠夺者物理：隔离运行 `4705c7a928` 的 join-low-far 在第 788 帧中，原生 step 后 dx=27.237545、t_throw=44；帧末 dx 被改为 3.2，位置未变。之后数帧同样被限制。未发生伤害性撞墙。

FirearmAttachments 0.3.1 在 ENTER_FRAME 优先级 -100 执行刺刀接触和 slowStep；速度被覆盖发生在测试优先级 -1 与 -8001 之间。该次复制档装备含刺刀，FirearmAttachments.log 确实记录目标的 bayonet contact。slowStep 无条件限制 dx 到 maxSpeed × 0.8；该目标的上限结果正好是 3.2。TDFC 的缺少 t_throw 让行是另一个代码隐患，但该次 TDFC 日志只有 idle，不能把本次覆盖归因给它。

## 最小变更

位置：`mods/FirearmAttachments/src/fa/Runtime.as` 的 slowStep。

在原生念力控制期间（levit > 0）和抛掷飞行期间（t_throw > 0），继续让减速持续时间自然过去，但跳过速度限幅。原生抛掷力度、魔力消费、墙体伤害、碰撞动量、落地摩擦均不修改。控制结束且减速尚未到期时，恢复原有减速。

建议代码放在当前过期/离房检查后：

```as3
if (Number(u.levit) > 0 || Number(u.t_throw) > 0) continue;
```

## 验证与交付

先在 RConnect 自有隔离目录构建候选并保存完整指纹。验证带刺刀的近身与移远抓投、真实原生撞墙扣血、普通刺刀减速仍有效、抓取/自然挣脱、动画和共享 SATS。保留三项旧失败；不能把所有无墙伤的低抛判为同一原因，方向和自然落地仍须逐次核对。

在已获授权范围内修改 FirearmAttachments 源码；部署前核对安装指纹并备份。RConnect A 与 B 保持独立，不替换 B190，不修改玩家存档和配置。

## 未执行的调查

此前准备 TDFC 隔离补丁的复合命令被本地 PreToolUse 护栏以 binary-swf-use-release-pipeline 拒绝，没有执行。随后的日志将本次限速指向 FirearmAttachments，因此停止该 TDFC 补丁试验，不申请或绕过该拒绝，不修改护栏授权表。
