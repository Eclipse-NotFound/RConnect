# 快速包接收：准确 20 / 21 的只读收窄

本次核对的 `Session/GameBridge/RemoteMotion/WeaponDisplay/ObjectIdentity/ProjectileVisuals/ProjectileFrameStream` 在 20、21 中逐字节相同。21 实际候选为 `9ac7ede7…8b7e7ba`。未改生产、未编译、未启动测试。**有确定的接收期姿态计算和一个很小的重复数组分配；现有证据不能证明它们解释了那次 100 ms，也不足以直接改变接收/绘制顺序。**

1. `e53cb3730a` 加入侧最长批次为 phase 1 / frame 3 / id 636：117 ms，5 条消息，其中三个 worldstate 分别处理 3 / 2 / **100 ms**，各含 80 个敌人条目、墙块和墙文本均为 0，tick 1292 / 1293 / 1294，源时间 125262 / 125351 / 125432。三包不是同一个源时间的重投，且单个 fast 已占 100 ms，不能用“多个 full 堆在一起”或墙像素解码解释此样本。该统计没有敌人实际接受数、effects/loot 内容量或回调内部 CPU 栈；也不能认定三个包的完整工作量相同。

2. 独立的 `b3d7b8558b` after-render 采样提供了具体链：`handleMessage → applyEnemyMotion → queueUnitMotion → RemoteMotion.sample/sampleTimed → blendWeapons/blendBodyPose`。24 窗 1,614 CPU 样本中，**仅筛选含 applyEnemyMotion 的栈**，有 116 个，其中 queue 79、sampleTimed 52、blendWeapons 24（叶 20）、blendBodyPose 10（叶 10）、pushTimed 15、validLandPos 13、projectile receive 3、GC reap 11。它们存在包含关系，不能相加或换算毫秒。最长 182 ms 窗 phase 6 / frame 11 的相应数量为 fast 21、queue 14、sampleTimed 10、武器 4、身体 4。该采样与上面的 100 ms 是不同运行，不能拼成同一次因果证据。

3. 源码确认接收承担了部分显示计算。`GameBridge.as:5523–5534` 先做对象/房间/生命/坐标/旧时间检查，再写运动与抓取字段、保留本地抓取、入运动队列，最后接收独立 effects；对象键查询是现有字典，不是每敌人扫描全房。`:5897–5907` 每个接受样本创建运动包装对象，`RemoteMotion.pushTimed:133–169` 又浅拷贝它；新时间再建 frame 记录。随后 `queueUnitMotion` 调完整 `sample`，直接只消费 x/y，却连同武器和身体姿态一起计算。`:6392–6423` 原生帧又 sample、setPos/setVisPos、apply/animate/tick。`sampleTimed:182–254` 没有“本时刻姿态已求值”返回口，即使 elapsed=0，尾部插值仍可重新分配。**重复求值可达，不代表任意一次接收结果都未被使用**；时钟推进、暂停 settle、弹体 sourceTime、碰撞位置和同戳修订仍有必要责任，不能直接跳过 queue/sample 或只保留最后一包。后续 full 也可能带同戳，`pushTimed` 会换 snap 并返回而不是重启时钟，但外层仍会 sample。

4. 唯一能够不改变时钟策略就直接证明的窄冗余：`RemoteMotion.as:280–295` 的 `blendWeapons` 先取得 `WeaponDisplay.interpolate` 新建的结果数组，再建立 `out=[]`，逐项把同一引用放进第二个数组。唯一调用点 `RemoteMotion.as:251–252` 已确认两端均为 Array，因此 `WeaponDisplay.as:45–64` 不会走返回输入数组的 null 分支。带 display 的项直接复用同一对象；无 display 的兼容项仍需原样浅拷贝、转角及位置插值。第二个**结果数组**与其逐项 push 是可消除的重复容器，不能因此省掉兼容项复制、插值或每帧动画。采样证明此方法实际执行，但未区分创建 out 的成本；不承诺这一小改动能消除长帧。本次只记录，没有实现候选。

5. 其余链没有足够证据列作本轮优化目标。`Session.as:1234–1267` 每包整理玩家列表并 `updateRemote`；后者 `GameBridge.as:730–828` 即时维护生命/抓取政策、驱动化身、接收弹体/传送/换装，原生帧 `:355` 再驱动显示，不能把整段当无效重播。采样中 applyWorldState/updateRemote 各含 18，driveGhost 8，远少于敌人链。`applyLootSync:3817–3943` 的 fast 模式只更新轨迹而不删除缺席物；full 仍负责存在性，并在 fast 轨迹活跃 500 ms 内避免慢包重置。新键才认领/构造，已知键复用；真正呈现由 `tickLootMotion:3657` 执行。本轮采样 **0 个 applyLootSync 栈**，只能说未捕获，不能证明免费，也不能把认领全链扫描或物品创建归为此 100 ms 的原因。GC 的 11 个 fast 内样本同样不能追溯到某一种数组。

边界：无需新协议、缓存扩容或丢包策略即可继续核验小容器冗余；更大的“接收只入队、绘制再完整求值”属于显示/时钟责任调整，目前证据只指出成本，未证明安全等价。21 前两段的真实性能失败仍保留，不因后五段通过或本报告而改变资格。输入指纹、精确筛选计数和代表栈见 `evidence.json`。
