# 准确14：加入侧每帧动画成本只读审查

2026-10-22。只读准确 `build/m52/recovery-14/src` 和两份现有原生采样；仅新增本目录分析器、证据和报告。没有修改生产、冻结记录、驱动、门槛，没有启动 JVM/AIR。17的实机对照由主会话负责。

## 结论

**有一处可收窄到纯数据计算的结构性重复：`RemoteMotion.blendWeapons` 对没有独立 `display` 姿态的武器匹配两次，并建立一个马上丢弃的中间数组。** 敌人的正常 capture/captureMotion 正好走这条路径。可以把这两个循环合成一次匹配、一次输出遍历，每帧仍产生原来的最终姿态；保持全部动画调用、源时钟、射击、碰撞和视野处理不变。无需跨帧缓存或重用前一帧可变对象。

这不是15版已尝试的“先算本机武器位置，随后又用源时钟位置覆盖”的算术优化。它消除的是两层辅助函数间的中间容器和重复匹配。不过，当前样本只证明它是一处**局部**成本，不能据此承诺解决整帧停顿。除这一处外，没有找到可直接删除且确定等价的整树遍历。

## 证据范围

`analyze.py` 从 a6a7e27789 的完整 PROJECTILE PROFILE 逐栈重新计数；不是只读旧报告的前若干热点。partial398cddcf6b只取 `usable_cpu=true` 的窗2/3/4（134/136/75），首两个失效窗口不参与推断。`evidence.json` 保存原输入和7份准确源码的 SHA；这些类在partial使用的13与准确14逐字节相同。

|包含式 CPU 样本（不是调用次数/毫秒）|14密集：1259|partial有效：345|
|---|---:|---:|
|tickFrozenAnims|278（reap叶67）|79（reap叶34）|
|RemoteMotion.sampleTimed|72（reap叶19）|45（reap叶24）|
|RemoteMotion.blendWeapons|18（reap叶8）|9（reap叶3）|
|其中 WeaponDisplay.interpolate|11（reap叶7）|4（reap叶0）|
|RemoteMotion.blendBodyPose|14（reap叶4）|2（reap叶0）|
|UnitPresentation.tick|111|9|
|UnitPresentation.play|71|0|
|MirrorMasks 全路径|42|7|
|MirrorMasks.maskReferences|0|0|
|MirrorHitUnit.syncMotion|29|10|

包含式行互相重叠，不相加、不换算预期FPS。GC在某函数栈上暂停，不证明该函数制造了全部被回收对象；14的分配统计没有分配调用栈。partial的两个完整窗口取样后还产生214/137ms枚举成本，半窗范围又不完整，不能拿其节奏作为正常运行基准。

## 重复发生在哪里

1. `GameBridge.as:6389–6427` 每个冻结敌人调用一次 motion.sample/settle，随后身体、武器和命中代理都使用该帧状态。`UnitPresentation.tick:407` 与 `animateBody:461` 读取的是 `currentSample`，不会各自再次推进这个时钟。
2. `RemoteMotion.as:251–253` 每次带两侧weapons数组的 sampleTimed 都调用 blendWeapons，然后调用 blendBodyPose。
3. `RemoteMotion.as:280–295` 的 blendWeapons 先调用 `WeaponDisplay.interpolate(first,last,t)`，得到中间数组blended；再创建out并遍历blended。没有display的条目再次扫描last，按slot/id/variant/stream寻找第一项匹配。
4. `WeaponDisplay.as:45–64` 本身已经为first的每个条目完整扫描last；它是在**匹配之后**才检查pose是否null。pose为null时，匹配结果未被使用，只把原a放进中间数组。
5. `UnitPresentation.as:215` 捕获display只在playerDisplay=true时进行；普通敌人capture返回display:null。`captureMotion:291–303` 的敌人高频包也没有display字段。因此这不是仅存在于不受支持输入的死分支。

对每个单位每帧，现有工作是：所有武器匹配一次 + 所有无display武器再匹配一次 + 两个数组。若每单位W个无display武器且last也是W项，最坏无匹配为2W²次条目比对；同顺序一一匹配为W(W+1)次。合并后分别是W²和W(W+1)/2，并只建一个结果数组。当前密集场的“80敌人、12把测试枪”不代表每个敌人都有12把枪；多数单枪情况下只是每敌人每帧少一次匹配和一个数组。**这是静态操作数量，不是已实测时间收益。**

## 最窄实现建议与必须保留的语义

只在RemoteMotion私有blendWeapons里合并现有两段逻辑；保持公共WeaponDisplay.interpolate及其它调用者不动。按first原顺序逐项寻找last中的**第一项**匹配，匹配比较仍是原来的四个 `==`，不要引入字符串拼接键或Dictionary替代。

- a.display为null/undefined：仍新建一个顶层copy，浅拷贝全部属性；有匹配才按原公式算ox/oy/rot。即使没有匹配，也须返回新copy，不能直接返回a。melee仍来自a。
- a.display非null且b/display有效：仍新建顶层copy及display副本；copy.melee必须取b.melee（即使undefined也保留这次属性赋值），仅插值display.x/y/r，翻转scale、原生frame等其余字段来自a。ox/oy/rot保持a的值；不能顺手也插值它们。
- a.display非null但没有匹配或b.display缺失：仍把原a引用放进结果；不能“统一拷贝所有武器”。
- events/impacts/aura等嵌套字段保留浅引用关系；结果数组是新的，两个输入数组和原条目不能被修改。重复slot/id/variant/stream项的先后语义、未知字段、空数组都保持。
- 不把bodyPose或weapon对象改成可变复用缓存。`UnitPresentation.apply:379` 可能补写选中快照的melee，`animateBody`也保留previous pose判断动画重启；值看似相同并不等于可以随意改变别名/生命周期。

上述等价范围是当前生产生成并经网络解码的普通数据Object。循环融合会改变人为带getter对象的读取顺序，不能把“任意带副作用getter也严格等价”当成已证明。RemoteMotion私有路径实际读入的是浅拷贝后的包，weapon元素由上面两个literal捕获方法创建，未发现生产getter条目。若实现要求保留任意动态替身的getter行为，应保留它们原路径，不能用本报告替代这项证明。

时钟的offset/cursor/debt/rateHeld/settle、传送判断、曲线、bodyPose、原生w.animate/play/flash/queue、hit.syncMotion及所有RV/WB调用完全不在拟改范围。这样节省发生于同帧最终姿态的构造，不靠跳帧或降低同步频率。

## 树遍历与不能删除的工作

- 普通ENTER只有一次tickFrozenAnims，重入有守卫。RENDER只有共同暂停且有新姿态时才补一次；不能把这项当成普通重复动画删掉。
- `RConnectAnimationAccess.tick:86–115` 已按动画id/整数帧/visData门控blit；它只检查一个osn/arm，没有每单位递归扫描显示树。bodyPose复制虽有分配，但当前没有证明可以在保留previous pose的同时直接复用同一对象。
- 真实枪口gotoAndPlay的71个密集样本包含原生子对象构造和FocusManager遍历。当前flash冷却与原生一致，同标签连续射击也需要重新播放；无法把这些构造等同无效重复。
- `MirrorMasks.capture:91–126` 只有新mask形成pending才遍历root找mask引用，并在同次capture缓存候选Shape签名。两份采样都未命中maskReferences；零命中不是从不执行，但不足以认定每个敌人每帧都扫全树。
- 本体/命中代理共享vis导致RV重复遮罩的机制仍存在，前次审核已记录。但移除代理、伪造npc/player或暂借vis会影响命中/SATS/视野；本次不借这个问题扩大改动。

## 可验证步骤（尚未执行）

沿现有完整RemoteMotion旧新组件及 `run_recovery_component.py` 即可，不新增诊断框架。建议先把武器构造的最终值与引用关系逐项对照，再ABBA计纯sample时间：0/1/多武器、无display/全display/混合、无匹配/错四身份/重复身份、undefined属性、±π角度跨界、t=0/1/中间、unknown嵌套字段和alias、不修改输入。混合项必须包含b.melee与a.melee不同的反例。

沿原生产sample/push/settle顺序比较sourceTime、选中snapshot、位置、bodyPose和weapons；保留既有时钟回归中的重复包/倒序包、同毫秒多sample、SATS settle后新包、传送、held/drop及有限效果锁速。计时不能含断言、序列化或日志，不以组件成本宣布实机合格。

如果组件没有稳定收益就停止；有收益后才用同字节密集driver02和原门槛复测。正常比较不启CPU采样，保持安装输入/静态场景摘要一致。需要函数归因时复用现有密集profile入口，只看相同有效窗口内blendWeapons/WeaponDisplay.interpolate，不把减少失败数或受采样影响的FPS作为性能提升证据。
