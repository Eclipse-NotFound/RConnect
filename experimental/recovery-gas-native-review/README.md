# 四轮原生毒气投掷驱动：独立只读审阅

2026-10-22。审阅 `experimental/recovery-gas-native-tests` 稳定交付，未修改作者文件、未编译、未启动 JVM/AIR。准确四个输入 SHA 及纯 Python 反例见 [counterexamples.json](counterexamples.json)。气体组件 63/0 是父会话提供的实际结果，不等于本原生驱动已通过。

结论：背包和原生投掷路径成立，主要字段没有发现内部权限错误；但**现有分析器不能授予“每朵气体从源到远端、全部动作帧和真实终末一致”的资格**。它可作四轮出现/不创建伤害实体的初步证据，下面两项验收缺口应补强后再用于完整原生验收。

## 需要补强的确定缺口

1. **身份关联只有总数和任意一帧相符，无法证明同一源 Part。** `verify_results.py:46–64` 仅比较 source/wire/display 数量，对每个远端显示找任意一个相符姿态，然后取 `candidates[0]`。没有使用源 Part 的 `visual` 映射关联源显示样本；多个候选时也不拒绝歧义。原生源码确实分别记录真实 Part 引用、真实 wire stream:id 和真实显示引用，但这三个本地身份并不自动等同。纯 Python 反例证明：把源 Part 和源显示坐标改到完全不同位置，仍通过；两个 wire 的姿态历史相同，分析器仍贪心认定对应。

   最小方向：先用已有 nativeRows.visual 建源 Part→源显示，再用完整有序姿态序列建立明确唯一的源→wire→显示关系；存在歧义或缺失就标无法证明，不按首个候选当真。对每个已观察的显示姿态检查是否来自同一 wire 的合法有序样本，而不是只要曾有一帧相符。无需要求低帧率环境显示每一个网络样本。

2. **终止只证明“移除过”，不证明移除时刻/最终帧正确。** `GasPulseProbe:80–85` 用脱链/脱离舞台记录 end；`validate:25–43` 只要求显示 end>born、wire.end>0、strictEnd=true。`compare` 仅把二者结束时间写入报告，没有比较。把远端显示改成出生后 1ms 消失、源和 wire 仍到 3000ms，验证依然通过；保留首个匹配姿态，追加任意错误坐标和 MovieClip 帧号，也依然通过。四个反例均为 accepted=true，不是推测。

   生产 `EnergyImpactVisuals.tick():246–258` 的真实规则是 **共享显示游标 sourceTime 到达 source end 才移除 strictEnd 粒子**。只检查布尔字段存在不能验证执行该规则。最小方向是只读记录对应远端 motion.sourceTime 和末端显示样本，在正确源时钟下检查提前移除/末端/结束；无法取得准确同一时钟时明确终末对齐未知，不能用两侧不同 getTimer 直接相减。`tick():246` 的结束条件使用“距最后出生>=500ms”，不是“消失后继续观察500ms”；目前完成便停止采样，不能证明结束后不重现或静默流量归零。

## 已核对成立的部分

- `GasPulseNativeTestDoc:130–156` 用隔离复制的 Invent.weapons/fav/favIds，原生 addWeapon(gasgr) 和 favItem(id,29) 配置 quick throw，并断言不在 currentWeapon/childObjs。`before:175` 写 ctr.keyGrenad，进入原生 `UnitPlayer.as:2186–2203` 的 throwWeapon.attack 分支；未直接调用 explosion/explRun/Emitter、生产捕获或接收。准确称为原生 G 动作分支，不是操作系统键盘事件测试。
- 四轮为 host单颗、join单颗、host双颗、join双颗。通过实际 gun.b 引用计投掷、PhisBullet/type7断言，双颗检测第二枚出现时第一枚仍在链。释放至少一帧后由原生冷却决定再次投掷，没有改攻击计时或人工制造气雾。
- `Part.vClass/mliv/liv`、Pt.vis/in_chain/nobj、Bullet.weap/isExpl/explRadius/tipDamage、Unit.trigDis、Invent三数组均为对应原生公开字段，未重现此前 UnitBat.tr 的 internal 访问错误。可选魔法/换武器分支不在当前 CASES 中。
- 源侧 Part Dictionary 和显示 Dictionary 都按实际引用，wire 按 stream:id 去重；旁观现有 TcpLink.MESSAGE，不额外调用生产 capture 消费游标。当前双人同房、每轮单一来源范围内，wire key 使用成立；尚不能扩成多来源身份保证。
- 接收侧同时扫描实际对象链，要求没有新增 native gas Part 或 gasgr 伤害弹体，可防止普通“视觉重放再生成伤害实体”的回环。数量以真实记录为准，不固定成12/24。上限超出会失败，不静默截断。

## 像素与运行编排边界

`capturePixels():118–128` 在同一次 RENDER 中对同一 root/bounds 做 with/without 两次 draw，临时隐藏目标后 finally 恢复；记录视觉id、frame、at、drawMs。两张截图在该时刻已取得，只把 getVector/PNG编码/落盘推到停止动作采样之后，时序描述准确。每轮只证明某一朵气体在某一时刻确有像素，不是全部粒子/整段动画像素一致。

离线工具目前只检查日志的 pixels>0、readbackAt>=captureAt，以及24个PNG/JSON文件存在并记录SHA；没有将 proof.json 与同轮日志逐字段核对，也没有从实际PNG重新算像素差。pixel.visual/frame 未与对应轨迹样本绑定。这不说明截图已错误，但独立证据校验仍不足以保证“日志报告的那个时刻/对象就是这对PNG”。可在现有薄适配器内补文件对账，无需新增框架。

适配器继续使用现有 prepare/run 的候选绑定、22输入、唯一隔离实例、登记/内存/清理。原生失败不会被返回码抹绿（最终要求 code==0），但 gas-verification.json 的 passed 是独立分析结果，native_runner_passed 另列；读结果必须同时核对。普通/粉色气雾、暂停、跨房、发包失败恢复和结束后静默流量仍不在这四轮原生资格内。

本审阅仅在独立目录保存报告和四个小型分析器反例，原生成器、驱动、manifest、失败结果均未改。
