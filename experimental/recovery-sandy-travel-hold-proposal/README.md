# A版共同旅行：CEC6时停加载许可接口提案

2026-10-22。**只保存在RConnect内，未授权修改Sandevistan、未编译、未部署、未运行。** 提案基于正式单人CEC6，完全不混入当前root源的B接口。父会话先审阅此具体改动，再申请本次A接口的授权。

## 准确基线与已查明行为

- 冻结源：`mods/Sandevistan/build/out/keybind-20261015-006/frozen/src/SandevistanMod.as`，SHA256 `ad931f4f0cc374f9f084f61227d6b1fd1bf61e7a156cd69e2b0c79141584492d`。
- 产物/正式安装均实算 `cec6a3061cb90380579d8a95aa1254e0328bd0dae6e239fc4ca5205d6cccf942`，与该目录build-input.json及2026-10-15正式发布记录一致。
- CEC6没有公开active/replay/query，也没有SandyAuthority。普通玩家idle不调用loc/gg.step；活动/回放时会直接推进。普通分支中的敌人时停也会补步；玩家状态idle不等于全模组不写世界。
- 热键路径 `6818→6831→startSandy:3892` 只检查 `inGameplay:790`；后者不看onPause、t_exit或ggControl。因此hold开始时检查一次pause、或只controlOff都不能防止等待中另行启动。
- cfgProjHits在这个准确版本恒false，旧config键无效；不把已迁走的击落逻辑列成额外问题。

## 具体文件与契约

`entry-changes.patch` 是针对上述准确CEC6文件的统一diff。只给入口加一个引用、一个不可见载体和5个轻量入口判断。`SandyTravelHoldBridge.as` 是拟新增类。授权后应保留原CRLF并逐字比对，不可从当前含B源重建；本目录没有完整复制或写入对方源码。

载体挂到main，名称`SandevistanTravelHoldV1`。RConnect沿已有跨域显示树方式发现，检查`version==1`与`contract=="sandy-travel-hold/1"`；无需跨兄弟ApplicationDomain查类。

方法：

| 方法 | 作用与边界 |
|---|---|
| `query(world,game)` | 返回有限只读标量：阶段、活动/冷却帧数、回放索引、敌人开关和debugTest。无法确认身份时null；不能据null放行。 |
| `acquire(owner,world,game,earlyId)` | 同步、原子检查玩家idle及非自动驱动状态，再取得许可。已激活/回放拒绝，因此共同换图退回旧流程，不把旧房录像带到新图。同一owner/id/身份重入幂等，其它owner不能覆盖。 |
| `release(owner,earlyId)` | 只释放精确owner/id；不写onPause、玩家控制、Game、录像或计时器。正常激活/提前取消/断线都由同一RC票据执行。 |
| `isHeld()` | 无票据立刻false；持票检查World+Game，换Game自动清掉旧许可。读取失败暂时保持冻结，RC查询失败应执行自己的失败/取消流程。 |

真实准入谓词为：双方支持early协议，双方都找到这个准确契约、query身份成立、双方acquire成功，且原来的旅行身份/暂停/菜单条件成立。不能用“已安装Sandevistan但找不到接口”当作“无需冻结”。一侧取得许可而另一侧拒绝时，先释放自己精确许可，再按旧流程旅行；不能混入半早交付。

取得许可后，时停onFrame整段跳过：直接gg/loc步进、敌人补步、冷却、回放、弹药恢复钳制、残影计时均停在原值。退出后从原数值继续，不补欠帧、不重新start/end。当前共同旅行只允许idle进入；这比尝试跨图恢复活动录像更窄、更安全。入口中仍挡住startSandy是防御性保证，不依靠它被private就认为不会被本模组内部调用。

保持KEY_UP、MOUSE_UP和失焦的正常释放语义，防止持键卡住；hold期间新KEY_DOWN/MOUSE_DOWN不向时停功能积累攻击脉冲，也不能启动/结束时停。忽略按下后的UP不再误报IME缺DOWN。这个接口不吞全局事件、不管原生玩家控制，也不暂停音乐的异步完成回调；全局游玩输入、World原生模拟和原生加载画面仍由RC/宿主旅行票据负责。

无票据路径只增加始终false的空引用/owner判断，其后原函数文本和顺序不变。不可见载体是新增显示树对象，需要验证不影响已有子项遍历/设置发现；不能称整个SWF逐字节一致或零CPU指令差异。

## 生命周期与取消

票据必须在早交付逻辑进入冻结前取得；若准备生成时玩家正在活动/回放，返回旧旅行流程，不强行结束时停。取得后立即保护热键，不能等checkpoint发送后才acquire。

正常activate或未导入前回退，释放精确许可。完整/部分restore失败不应恢复游玩，但仍由RC失败界面持有明确责任；不得让许可无主滞留。World/Game变化会自动撤旧许可，不把旧pause/control状态写回新Game。载体不自行判断epoch/ACK，避免形成第二个旅行状态机；这些只由EarlyTravelGate负责。

如果mod载体晚到、替换或读取失败，当前旅行不得获得优化资格。正常已有票据不要因重找不到载体而丢失引用；仍需向实际取得许可的同一个对象release。测试取消要核对两边各自持有者，不用名字相同的新载体释放旧载体。

## 授权后必要验证（本次均未执行）

1. CEC6旧/新无票据逐次行为：普通idle、玩家活动、回放、敌人补步、冷却、菜单/热键/释放。比较调用与状态，不只查询值。
2. 真实票据期间：原生玩家/敌人step计数、冷却、回放索引、弹药钳制均不前进；按启动键不会激活，release后从相同值继续；KEY_UP/MOUSE_UP不会卡键。
3. 同owner重入、不同owner/不同id拒绝、World换掉/同World换Game、读取异常、取消/断线、无接口旧版本回退。载体不写任何旧World控制字段。
4. 全模组实际三段共同旅行：取得双方许可后才冻结并早交付；冻结对象不进展而原生t_exit和两侧首绘继续。原性能期限、出生、按键、单人及普通分房断言不变。

限制：没有把“跨图恢复正在播放的旧录像”纳入接口，本版通过原子idle准入明确回退；这不是暗中删去时停玩法。若后来要求活动期间也用早交付，需要独立跨图录像生命周期规则，不能把此接口扩大使用。

静态复核已完成：只读准确CEC6源，在Python内存中逐hunk核对上下文、旧/新行数和目标位置，7个hunk共新增22行，无删行；未写出修改后的Sandevistan源。按原CRLF生成的内存结果SHA256为`577679b9da303a2959e50512a51c5cd0e39f37dfc46416615f8fb15ecf0cd352`。补丁SHA256为`fd21e2bdf79e61b5b6f0bf8238ed476d88517e120c2f7a12f636b8c7b3e478c3`，helper为`5b195a60fedcd94b416a7f0f3fa82db5cc5423a843ec3d90ef6bcc78037a2890`。这是文本精确性检查，不是AS编译或运行通过。
