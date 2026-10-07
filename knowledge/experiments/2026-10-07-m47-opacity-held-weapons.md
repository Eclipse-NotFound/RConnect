---
domain: rendering
type: experiments
game-version: ["1.02"]
confidence: medium
verified: true
discovered-by: RConnect
date-updated: 2026-10-07
evidence:
  - kind: decompiled-game-code
    symbol: "fe.weapon::Weapon.animate/actions/attack; fe.unit::UnitPlayer.setWeaponPos"
  - kind: runtime-experiment
    summary: "隔离原生 Q 搬运及原生 LMG attack/step 经真实 TCP 至最终显示；旧版负控、候选对照"
---

# M47 不透明度、快速搬运与原生武器姿态

已确认：当前已安装0.2.19-dev，SHA256 4008999b开头（125466B、52生产类）。最终冻结final-presentation-07的同生产字节16组1860 PASS/0 FAIL/DONE，正常无驱动双端启动ca43e3b445持续150秒通过；上一版18备份及回滚路径见[部署记录](../../state/deployment-m47-2026-10-07.md)。

观察到：有效旧版快速搬运8cf53db5a2在箱子 host→join、join→host、掉落物 host→join、join→host 分别350/370/340/350ms，4条延迟红，其他原版抓持/静止释放/下落前提绿。此前61213af520也见350/400/340/360ms，但持续快运动违反原来的释放前静止前提；保留原始失败，将末段固定在2800ms以后，未改变运动采样和160ms阈值。唯一改变高频通道的 e06ed29fb3 为130/130/110/120ms，原始曲线、时钟偏移、最小平方延迟拟合均留在日志。模拟和渲染均走原版；拟合只用于测量，不用于生产预测。

原因与实现：原来的盒子和掉落物在约200ms的场景更新上使用 RemoteMotion(200)，播放缓冲至少300ms。活跃物体如今随既有20Hz玩家消息传递，使用同类的100ms源时间缓冲；完整场景仍200ms。释放短时间重复，先收到的旧完整快照不能重置高频游标或复活抓持。原版碰撞/重量/耗魔/投掷、地面单份仲裁、敌人抢持和房间交接仍分别归其原路径。不外推为80敌人FPS改进。

武器原生事实：Weapon.animate 的非固定武器根据 weapon.X 与 owner.celX 决定 vis.scaleX 和 rot+180；固定武器又按 owner.storona 处理。它还含后坐力位置与角度；角色方向本身不等于枪的朝向。旧版把枪挂在角色的翻转父级，另以角色方向计算角度，漏掉原版武器位置和变换。d8de7e1749 的7角度×2角色，向右0度对照绿，其余12条方向红，原枪每例都有子弹/shoot帧。先前956cd12af7缺持续预热和Camera输入前提，没有有效原生开火，不能当作开火故障负控。

修复采集原枪在世界显示层的实际姿态，按玩家源时间游标插值位置/最短角度，反射符号保持离散，换枪/流身份不互插。接收时抵消角色父级变换；工厂创建同款及同变体。开火计数在相同样本播放本机剪辑，弹道保持原显示专用路径，无第二次攻击/伤害。7fdb7a5d4c 与最终50605d6f47的两端7角度、原生射击和远端 muzzle 均通过。

不透明度：设置页30–100%，默认100%，−/+每次10%；获得焦点的控件支持方向键/Home/End，分别保存到各AIR应用的SharedObject。暂停提示是独立显示对象，始终alpha1。AIR DisplayObject.alpha按1/256量化：真实独立探针 .9→.8984375、.3→.296875（build/m47/alpha-native-probe）；256bf95f2a的0.001容差红是夹具误判。只将alpha容差改为1/256，保留设定值、范围、键盘、保存与重建断言。最终HUD52601ca525绿，图片为实际原生渲染，模拟事件不等于真人鼠标/IME。

验证边界：本轮验证为1.02同机双人；外网、更多玩家、稳定重连和其他游戏版本不在本次范围。原生轻机枪七角度通过，不代表全部特殊武器及连续扫过翻转边界均已覆盖；真人鼠标和中文输入法仍需实测。原背景门失控与死敌重现、密集战斗卡顿仍保持原状态；本轮不借新功能绿宣称这些全部解决。

冻结/原始输入：build/m47/red-presentation-01..04；final-motion-probe-01；final-presentation-01（HUD精度红）；final-presentation-02（仅测试/审计修订，生产字节真实复用01，candidate-reuse.json证明）；各真实运行在build/cooperation下，未覆盖失败记录。

最终结果：build/m47/final-presentation-07，同生产字节16组1860/0/DONE、正常无驱动150秒ca43e3b445通过，已部署19。十五组相同输入保留（五组02/六组05/四组06），恢复组07新跑；全部失败保留。最终快速搬运分别箱140/130ms、掉落120/110ms。EnemyGrab前提修正和#1056夹具错误详见部署记录，原位移/阻力/时间要求未放宽。生产实际编译在01，后续冻结仅改独立测试或审计，复用同一SWF的来源已核对；当前以[部署记录](../../state/deployment-m47-2026-10-07.md)为准。
