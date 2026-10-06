---
domain: world-objects
type: experiments
game-version:
  - "1.02"
confidence: medium
verified: false
discovered-by: RConnect
evidence:
  - kind: runtime-experiment
    summary: "同字节联合候选与真实角色复制档；记录退出前后原生Q指针、显示样式及首次松手前后状态。"
  - kind: decompiled-game-code
    game-version: "1.02"
    symbol: "fe.unit::UnitPlayer.damage; fe.unit::Unit.udarBullet"
date-updated: 2026-10-06
---

# M46 联合候选、原生松手与光晕显示诊断

> 2026-10-07后续核对：本实验之后，0.2.18-dev/04438276已完成14组1648/0、最终旧905负控与正常无驱动eb84c49f11并部署。最新状态见[state/deployment-m46-2026-10-07.md](../../state/deployment-m46-2026-10-07.md)。下文的未部署/待验证语句描述当时阶段，原失败和因果边界保留。


## 已确认

R2 C13与R3闪电/锁定资格交付的重叠已逐项核对；联合候选版本0.2.17-dev、112519字节、49生产类，SHA256 `0f86141b7d51bfc34bf261e6abcd338de78c2b67798cc1b92b7df11d803d1280`。无游戏存根或测试类链接。`build/m46/final`保存最初50源与131验证输入；final-3/4/5只更换测试输入，复制完全相同的生产字节。final-2在运行前发现诊断字段地址错误，未编译或启动AIR，原样留在build中。

两端角色复制档分别为9c5b3eea…、e17dda51…，不写原件。runner在任一端启动前备齐全部输入，保留实际配置、描述符和input.json。首轮审计57项安装保护指纹未变化，已安装仍为M45。

原生1.02的`UnitPlayer.damage`在父类HP免疫前累积pinok，超过60时放下teleObj；`Unit.udarBullet`只有在`transp && (vulner<=0 || invulner)`时才提前拒绝弹丸。单独设置invulner不能保证原生玩家免于这条松手副作用。

## 观察到

| 固定生产字节的执行 | 结果 | 证据范围 |
| --- | --- | --- |
| 初次联合Motion d8ea183f0c | 179 PASS / 2 FAIL | 同步leave保持真实Q/levit/Glow/CT，56ms后的第一帧清除，离线3秒保持两项失败；没有pinok与控制前帧记录。 |
| 仅补原生字段 bbf1d71e7d | 181 PASS / 0 FAIL | 三秒保持通过，首次清除为测试主动Q，pinok为负、控制开启；不说明旧失败原因。 |
| 同一已编译驱动重复5a5564292a | 181 PASS / 0 FAIL | 同样保持至主动Q。 |
| 同驱动重复d88300c9bc | 178 PASS / 3 FAIL | box-host在2077ms提前清除，原生pinok21.537→65.234、KEY=false/资格法力控制不变；计划释放时已经落地，两侧fall=0，镜像一次跳步28.30px。该轮离线保持通过。 |
| final-4 57e3f54387 | 186 PASS / 0 FAIL | 原181项全部保留并通过；新增5项原生damage对照，pinok0→90，Q/levit/Glow/CT即时清除并原生落地。 |
| M45同final-4夹具0967e8a9df | 142 PASS / 44 FAIL | 同测试源码、角色复制档和原运动断言；声明索引按M45冻结源编译，驱动二进制不宣称相同。5项原生damage对照全部通过，已有网络持物与释放问题仍红。 |
| final-4重复94364eb1ad | 186 PASS / 0 FAIL | 同一已编译驱动再次通过所有原断言及原生松手对照。 |
| final-4重复f6b92f575b | 186 PASS / 0 FAIL | 第三轮同186项通过；不相加为558项独立覆盖。 |

各执行两端DONE。首次诊断由`build/m46/motion-diagnostic-audit.json`核对；final-4初轮、M45对照及两次重复由`motion-control-audit.json`核对。final-3串行复现遇d883红即停，当时第三轮未启动；final-4三轮已全部结束。没有用后续绿覆盖原始失败。

### Aura联合回归与真实画面

| 执行 | 结果 | 证据范围 |
| --- | --- | --- |
| final-4 Aura 18a43bd475，begin | 加入侧5 FAIL，其余检查绿，两端DONE | join武器、备用武器及round0/3/4物品像素失败；颜色/CT/抓持正常。这轮无截图导出。 |
| 同候选同已编译驱动 b37e2b7e3a，random_mane | 95 PASS / 8 FAIL，两端DONE | 换地图后武器像素通过，round0/3箱子像素仍红；地图原有L#1/L#2咖啡，宿主新建持L#3，而加入側随后抓L#1；双方检查非同一物品导致6项Loot失败。 |
| final-5只补取证9404d939d7，random_mane | 92 PASS / 11 FAIL，两端DONE | 16张真正PNG与逐轮显示链留档。join round0箱子bounds(1138.65,219.35,24,20)，Stage1280×800，全部祖先visible/alpha1、无mask/scrollRect，正确Glow/CT；画面白色矩形覆盖箱子区域。round3源端NPC持箱已丢，Box levit0/Y320/真实NPC指针false，4项持续持有/颜色/CT/像素失败。6项咖啡身份失败仍在。 |
| 同诊断源码C13对照1ed5b50412，random_mane | 93 PASS / 10 FAIL，两端DONE | join round0持箱场景像素通过，对应PNG无白块；NPC提前失持4项、咖啡身份6项仍红。驱动按C13冻结声明编译，不宣称与联合驱动二进制相同。 |

所有失败候选、驱动、运行输入、日志及已导出的16张/轮PNG保持原件。每轮任一端启动前备齐双方输入；其他模组为当前安装字节，旧R2轮的配置文件没有留档，不能宣称与那些旧轮全部配置相同。

源码已核对：RV按单位对象分别缓存遮罩，`applyMask`会写共享`u.vis.mask`；R3真实资格修正后，本体与MirrorHitUnit都可进入该处理，二者借用同一vis。此差异与白块符合，但尚未用受控单变量开关确认具体白块所有者，不记为已完成修复。

## 推测

d883的阈值跨越与原生damage松手分支吻合，说明当前测试场中的无关攻击能破坏“持续持物至计划Q松手”前提。它不能反向证明d8的退出松手或C13 Style4的提前松手也出自同一攻击；这两轮缺对应前帧。

final-4只为测试角色增加原生transp弹丸免疫，与已有invulner一起在udarBullet入口隔离无关子弹；原有Q/E、敌人重量/抵抗、实际物理、运动/下落/落地断言和时间窗口保持。生命周期末尾新增真实damage跨越60、清除Q/Glow/CT并返回地板的负向对照，证明隔离不会替生产层屏蔽合法原生松手。生产候选未因此修改。

NPC失持在C13与联合候选均出现，不能只归因R3合并。R2只读指出：迟到的旧q=true续报经force trackBoxPos会调用releaseEnemyCaster，现有保护只覆盖q=false；需记录moved.q/sampleTime、首次清除与t_tele变化，区别旧续报和真正新抓取后再修，不屏蔽玩家合法抢箱。

## 尚未验证

- final-4三轮完整动作/生命周期186项已通过，原生合法受击松手5项在M46与M45都通过；这不代表Aura或整轮门禁通过。
- 最初d8退出松手缺少pinok等字段，具体调用路径尚未认定；没有宣称新增生产修复。
- Aura仍红；其余10组联合回归、发布门禁和安装冒烟停止，未部署。当前仅测试诊断新增，未为白块或NPC失持修改生产。
- 先绑定测试咖啡的唯一身份；追踪双遮罩实际对象并做受控对照；抓取NPC第一处清除前的报文/原生字段。修正后重冻新的源与验证输入，保留final至final-5，不覆盖失败结果。
- UI本轮只交付设计与HTML预览；密集战斗帧率、红外特有分支、全部首领/第三方状态及背景房报告的根因均不由本轮验证。
