# 双向原生毒气投掷：未运行的外部驱动

直接派生已实际执行的 `recovery-acid-native-tests/native/AcidGroundNativeTestDoc.as`，准确SHA为 `aa02ac1760bca30ce0967093cf1c5ecaaafa276db87a40ba03e8a22e41510643`。沿用原生角色就绪、双方准备握手、隔离背包/favItem、原生 G 键、测试房间边界和结束恢复；`driver.patch` 列出完整增量。没有启动 JVM/AIR，没有改变生产、已冻结候选、共享运行器或用户存档。

本次收紧对应 `recovery-gas-native-review` 的四个实际假通过反例。它们现均须失败，结果保存在 `counterexamples-recheck.json`。即便未来本驱动通过，也只授予**已观察源轨迹、唯一对应、末姿态和终止包先后顺序**的有限资格；生产 `GameBridge._remotes` 是私有字段，没有公开的同一 RemoteMotion 游标访问口，因此 `cursorAlignmentQualified` 与 `fullLifecycleQualified` 始终为 false，精确“播放游标到达end时才移除”仍未知。没有另建模拟时钟或修改生产接口冒充这个证据。

四轮依次为宿主单颗、加入侧单颗、宿主双颗、加入侧双颗。双颗必须实际存在两枚同时存活的原生 PhisBullet；释放至少一帧 G 后再按住，等原生冷却放行，不改攻击计时、倒计时、伤害或子弹位置。不按配置补齐十二朵，不直接调用 explosion/explRun/Emitter、生产 capture/receive/tick，也不发造出的游戏状态。

`GasPulseProbe` 每个 RENDER 只读该房间对象链及五个显示层：源侧按原生 Part 身份、Emitter.gas.visClass 记录出现/寿命/移除；观察侧记录实际绘制的同类 MovieClip，同时断言原生 gas Part 和伤害弹体均为零。生产 TCP 只在现有 MESSAGE 事件中旁观，记录 `@room-gas` 的独立 stream/id、实际增量帧、终止标志及接收墙钟；不能使用额外调用 capture 取得数据，因为那会消费待发送游标。

每轮先按实际引用建立 Part→源显示映射，再要求全部源显示采样和 wire 帧按顺序逐一对应。外部 ENTER_FRAME 90001/89999 优先级只读时间戳，夹住准确候选 GameBridge 90000 优先级记录的源帧时刻；wire 帧必须落入对应源帧界限，wire.end 必须落入该真实 Part 移除的源帧界限。随后检查对侧每一个已观察姿态来自同一 wire 的非倒退序列，并且最后实际显示姿态等于真实源末姿态；低帧率可跳过部分源样本，覆盖数如实报告，不因此称为流畅。位置0.1px、旋转0.1°、比例0.001、透明度0.01、帧号、可见性及八项颜色字段均参与匹配。

两个关联阶段都必须只有一个候选，并构成一一对应；不能先排除已占用候选再贪心选第一个。多个一致历史、漏帧、不能证明唯一身份均失败/未知，不以数量相同或曾有一帧相似代替。显示移除必须晚于终止包实际接收，且不能绕过末姿态。两侧不同 getTimer 不相减冒充播放时间；实际源界限、接收墙钟、显示墙钟和终止包至移除耗时分别记录。这样拒绝审查中的提前1ms消失，但**不能排除“终止包已到、源末姿态已见，却比私有播放游标早几毫秒移除”**，该边界明确不签收。

证据有界：每侧每轮最多96个粒子身份、每粒最多128次观察，超过即失败；房间链最多20000节点。正常单粒60逻辑帧，但仍按实测移除结束，不用这个值制造终止。全部结束后继续观察至少500ms，窗口从最后移除/新气体包计算，记录移除后重现；不能用距最后出生的时间代替。一次最终舞台 with/without draw 在真实可见时进行，保留 drawMs；向量像素差、PNG编码和落盘在本侧动作采样和静默窗口完成后进行。每侧四轮各保留 proof.json、with.png、without.png，共24份证据。

适配器不再只数文件：保存的 proof.json 必须逐字段等于对应原生日志；pixel.visual/frame/sampleAt/pose 必须绑定唯一轨迹样本；两份 PNG 经 Pillow 实际解码、验证尺寸等于截图矩形、独立重新计算差异像素数，必须与日志完全相等且大于零。错误JSON、错误帧引用、相同PNG、篡改差分数均失败。每轮仍只证明一朵气体在一个实际时刻的像素，不能扩成全部粒子/整段动画像素一致。当前自检所用 Python 已能导入 Pillow，测试运行时也需同一依赖。

运行适配器仍使用 `experimental/recovery-tests/{prepare,run}.py`，继承共享登记、唯一后台测试实例、360秒、准确候选/驱动绑定、22个安装输入审计、内存门槛、finally清理及原始失败检测。根会话先编译含四类气体覆盖的生产候选，然后串行执行（下面路径占位须替换为准确新候选）：

```powershell
python -B -X utf8 experimental/recovery-gas-native-tests/check.py
python -B -X utf8 experimental/recovery-gas-native-tests/native_tool.py prepare --source build/m52/NEW-GAS-CANDIDATE/src --output build/m52/recovery-gas-driver-01 --build --registry-wait 900
python -B -X utf8 experimental/recovery-gas-native-tests/native_tool.py run --drivers build/m52/recovery-gas-driver-01 --output build/m52/recovery-gas-native-01 --registry-wait 900
```

`result.json` 是原框架原始结果；独立 `gas-verification.json` 的 passed 要同时满足原框架成功、唯一有序对应和文件/PNG核验。始终 `performance_qualified:false`、`cursorAlignmentQualified:false`、`fullLifecycleQualified:false`。缺轮、空证据、歧义、缺PNG、旧版失败均保留且不变绿。

边界：首轮只覆盖普通干地 gasgr 单颗和重叠双颗。粉色气雾、暂停、跨房气雾、没有接收者时消费游标、网络发送失败后的恢复仍未原生覆盖；源观察依赖帧采样，不是精确的 Emitter 执行回调。实际60帧长寿命气体比瞬时火花更易完整观察，但不得将配置数量当事实。当前只交源与静态/离线检查，不能声称编译或原生通过。
