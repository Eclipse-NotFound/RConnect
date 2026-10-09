---
domain: rendering
type: experiments
game-version: ["1.02"]
confidence: medium
verified: false
discovered-by: RConnect
evidence:
  - kind: decompiled-game-code
    game-version: "1.02"
    symbol: "fe.weapon::WClub.actions/weaponAttack/animate"
  - kind: mod-source-review
    summary: "Installed 0.2.21-dev WeaponDisplay/UnitPresentation replay shoot events but omit native WClub trail and stopped blade frames."
date-updated: 2026-10-09
---

# M50 近战攻击显示：调查与独立实现

被测技能：diagnosing-bugs｜2026-10-08.1｜C:/Users/hello/.agents/skills/diagnosing-bugs/SKILL.md｜SHA256 755c267af6dcb82d4749429476ed8b56cafc5f2e92d58f168e57b340f18c5a1d；remains-runtime-debug / remains-mod-memory / remains-auto-testing / remains-mod-build / remains-knowledge-contribution。
技能归属：diagnosing-bugs 为用户级、维护驻地 D:/活/总控；Remains 技能为本工作区级。
测试工作区：D:/Program Files/Steam/steamapps/common/Remains/mods/RConnect。

## 已确认

- 用户反馈近战类武器在对侧没有攻击动画。本会话 RConnect (5) 负责独立模块及专项；用户确认由原 RConnect 会话唯一合并、构建、AIR 验证与部署。共享 WeaponDisplay / UnitPresentation / GameBridge / 工具入口由原会话编辑，本会话不构建、不启动 AIR、不写 release、不提交共用工作树。
- 安装基线仍是 0.2.21-dev，SHA256 5c372cf5d970212f0fd4e95bea5c0acfaabfe321c3ca531c80ed7e299c2914bd。此记录创建时还没有本轮近战运行结果。
- 原生 WClub 复用构造时建立的碰撞 Bullet，weaponAttack 不累计 kol_shoot；其动作由 t_attack/rapid_act 驱动。actions 有挥击角度、刺击 plX/plY、快速切割和蓄力震动三条分支。不能用普通枪的子弹对象变化与 shoot 标签替代这些动作。
- WClub 的 internal visvzz 是独立世界层 MovieClip，原生 addVisual/remVisual 单独管理它。actions 在有效挥击窗口显示尾迹；lasM 武器用 vis.gotoAndStop(1/2/3) 表示休止、准备、命中。原生 animate 本身不计算上述攻击窗口或刺击位移。
- 21 的玩家矩阵通道能传部分武器位置/角度，但没有消费其 display.frame，且枪械事件播放无法产生上述尾迹/刀刃帧；冻结敌人的 w.animate 同样不能代替 WClub.actions。这里区分已确认的代码缺口与尚未实测的完整症状。

## 观察到

- 已写 src/fe/weapon/RConnectMeleeAccess.as 访问原生 internal 尾迹；src/rconnect/game/MeleeVisuals.as 记录实际武器与尾迹的显示矩阵、帧、可见性和 alpha，不执行远端攻击、碰撞、伤害、弹药或奖励。
- 同一模拟帧的最终 RENDER 可以替换 ENTER_FRAME 样本。历史最多 32 帧 / 800ms，完全相同的静止姿态压缩为时间锚点；位置/短角度插值，帧/可见性/反射保持离散。忘记武器时移除或归还尾迹。
- 角色子层的近战武器自然继承角色 alpha；世界层尾迹另外乘角色 alpha，避免对子层重复相乘。
- 已写 tests/MeleeAnimationTestDoc.as 与 tests/fe/weapon/MeleeTestAccess.as：9 个双向案例，刀两朝向、棒连续单次攻击、长矛和铲蓄力、能量剑、撕裂器、自动斧，以及真实尾迹显示期间换枪。源端走原生 factory/attack/step；独立采样实际显示对象，经 Session/TCP 检查对端姿态、尾迹、刀刃帧、松手与换枪清理。测试不调用生产 MeleeVisuals，可使用同一夹具做旧21负控。
- 四文件静态空白检查通过；尚无编译成功或运行通过声明。两层经验查询返回 partial，词汇无命中且有一个来源不可读；不能据此认定没有相关经验。本地 weapon-model、combat-pipeline 与 collision-motion 已提供近战路径的既有资料，继续对照原版源码。

## 推测及判别

- 首要假设是专用近战显示状态没有跨端重放。预期旧21缺真实尾迹/刀刃帧，而新通道使用同一夹具可看到它们；仅启动成功不能证明修复。
- 玩家插值若仍只采用前一包的 melee 历史，其末帧时间会落后于显示游标，动作可能退化成20Hz阶梯。已告知原会话，在同一武器/stream 的两包间使用后一包覆盖的原生历史，再按现有游标选帧；直接显示未来姿态不符合该方案。
- 既有普通枪械、武器翻转及身体 punch/kick 动作不由这个 WClub 模块替代，应通过相应回归与原生输入分别确认。

## 尚未验证

构建、旧21负控、新候选双端专项、敌人持近战武器的低频世界通道、全回归与部署均由原会话串行执行，此记录不冒充完成结果。无本场 FPS 对照，不宣称整体性能改善；无人为穷尽全部第三方武器。

## 本次产物与处置

以上四个独立代码/测试文件及本记录为本轮新增。原版代码缺口留在模组实验中，不升级公共库事实。交接及用户授权有应用跨会话消息记录；本记录是摘要，不是逐字推理。

同一任务后续实际红/绿日志与候选版本应追加到本记录，保留旧失败样本。技能实战状态待维护核对；台账待登记，未在沙箱外写入全局台账。部署与总记忆以原会话的 M50 记录为准。

## 后续修订：原生隐身与生命周期

以上“角色子层继承 alpha”和9案例描述记录的是初始实现。后续只读复核 UnitPlayer.setFilters（4129–4138）及 Effect.setEff：真实 stealth 物品把 pony.vis.alpha 设为 .5，并不一起修改世界层 WClub 的 weapon.vis。若远端武器留在 body 内，用局部 alpha 补偿会需要大于1，Flash会钳值。因此最新实现将 WClub 武器与原生尾迹恢复为 body.parent 世界层，分别复制原始 ColorTransform / alpha，并乘既有队友 .75 标记；forget 归还原 parent。不能用角色 alpha 再乘尾迹的10/rapid透明度。

专项现为11个双向案例，新增真实 stealth 物品使用的刀与能量剑，独立断言源 body=.5、远端 body=.375，weapon/trail各自的原生透明度×.75。冻结本机物理前检查活体、animOff及die/res工作阶段。仍未重放攻击/碰撞逻辑。已随 probe-peer-02 编译的47b60925仅含前一版四文件；最新世界层修订尚未编译、未运行，不将另一组PeerVisual结果算作近战证据。

只读生命周期审查另发现：GameBridge.updateRemote 的不同房分支直接 despawnGhost；despawnGhost 没有调用 removeWeaponVis。syncRemoteWeapon 新建武器只设 currentWeapon，没有把它登记进 ghost.childObjs；原生 Unit.remVisual 只清除 childObjs，因此独立世界层武器/尾迹需要明确清理。removeRemote 又在 removeWeaponVis 前 delete _remotes[id]，forget取不到旧weapon。精确分支与建议已加入 state/coordination-m50-melee.md，由统一负责人改共享GameBridge。本会话没有编辑该文件。

R13 PlayerBodyEffects 的root alpha设置与含alphaMultiplier的ColorTransform赋值顺序也需统一复核；真实隐身断言会覆盖这个集成问题。跨会话读/写工具多次返回MCP -32000，这轮世界层和生命周期消息尚未成功送达，已保存书面交接。没有独立构建、AIR、release或提交动作。

01:07左右只读检查原会话新probe-peer-03：其inputs.json的MeleeVisuals已为6a54f60a世界层版，production编译成功，实际SWF 0ce470db / 150378字节。本会话代码与该生产文件hash一致。该probe的近战夹具8715ce7c仍早于当前e7902619活体工作阶段门控；没有近战专项结果文件。此为构建证据追加，仍未证明对侧攻击动画修复，未覆盖release。四文件冻结hash已保存在state/coordination-m50-melee.md。
