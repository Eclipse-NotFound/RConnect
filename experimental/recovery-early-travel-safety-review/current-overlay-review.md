# 提前交付候选当前切片只读复核

2026-10-22。本次只读复核 `experimental/recovery-early-travel`，未启动 JVM/AIR，未修改作者源或组件。此记录补充原 `review.md`，不继承旧切片的运行资格。

准确输入：

- EarlyTravelGate `544d61b428ca0e3b3daf603eb0a8c8546fc01a64d22834c73f7d90d323f6a814`
- RoomSync `2b2f7c0723867f3c73898a2736398ad624e22a19f0eef1e3bc9e37e4f083af18`
- MapGeneration `b248567ae062d08ae66c7ff8ccff40553c86e978a916d048fbcfeab7ab8e9028`
- World `36d98b854969725cb0a934f7dbecfac3e122fda8a77af30da23499cf9e80cb4a`
- Game `f94005e6f343c5739385b8cc17b91cdf8b9872d4a71e2c38c671f329d424437a`

在本次核查的正常事务、拒绝回退、换 Game 和断开路径中，**未发现新的确定阻断点**。这不是原生性能或全组合冻结已经合格的结论。

## 已落实的关键边界

- Game 尾部 constructed 在原生 enterLand、出生定位、效果及触发器之后。World 在 exitStep 返回后再次查本事务 hold；同一帧不会因为外层已进入 `!onPause` 而继续 Land/脚本。无票据时仍保持 ACC 原分支，包括普通原生回调在已选中的帧内新设 onPause 的旧行为。
- 有效票据只允许 exit 倒计时和原本外层的 camera/GUI 等显示步骤；原生 t_exit 18/17 点击等待没有绕过。exit16 视觉变化保留，controlOn 由同票据完成路径补一次。无票据不会 refreshWorld、创建新票据或扫描视图，仍有少量桥函数调用成本，不能称零 CPU 开销。
- `nativeConstructed` 当前已在调用可能抛异常的 `gg.controlOff()` **之前**设置 `earlyControlHeld=true`。其抛异常后断开补偿用例已出现在 `EarlyTravelRoomChecks.cancellations`；原先的责任标记缺口已闭合。
- host seal 固定 anchor；host 收到匹配 ready 后才采一次共享 checkpoint/发送 grant 并允许绘图。join 等完整恢复与 anchor 定位结束才 `allowPaint`，没有调用会提前放开的旧 beginRestore。grant 重复由 paintAllowed 拒绝，重复 ready 不再次采样或结算。
- ACK 仍要求准确票据、下一 nativeFrame、`unpainted=false`、原生 t_exit 0 和 sceneViewReady；host 自己也满足相同条件并收到 peer ACK 才 activate。localReady 为真后仅核身份，不继续扫描 sceneViewReady。
- 取消在 grant/restore 前可回普通加载；paintAllowed 后、同一个仍存活的联机世界保持锁定，避免让一侧继续活动。断开释放自己保存的控制责任。World/Game/玩家任一替换、死亡或 comLoad/ng_wait 时不会把旧角色控制和旧 savedPause 写入新角色/Game。
- 外部时停许可绑定实际取得的载体对象、私有 owner、World、Game、id；释放不重新按名找对象。缺失载体、错误版本/contract、query null、非 idle 或 acquire false 都不能启用提前路径。release false 在同一身份仍保留持有，不假装成功；换身份可清除旧 RC 引用。
- 普通房、分房、未协商能力均不取得 EarlyTravelGate。尚未 grant 的拒绝回退可让旧 native/seed 交接继续；earlyId 非当前或退休的消息不会重新导入。

## 仍限于真实运行验证的边界

作者/根会话报告第二切片组件合计 217/0；本任务未执行这些组件，也不将模拟 carrier / GameBridge 或提取 World 方法当成全游戏资格。准确 CEC6 尚无 A 票据接口；其独立步进不能仅靠本 World 门闩挡住，当前真实组合必须回旧流程，等待授权后的真实接口。

World 保留的 `gui.step/pip.step/sats.step` 和其它模组回调、首次绘制时的 Tile 轮廓字段变化，仍需现有原生用例检查。入口许可排除了已打开的暂停/菜单/SATS，但“加载触发器或其它模组在持票后打开界面/更改 allStat”不由这份静态审查证明。不得据此宣称所有模组的逻辑计数均被冻结，或共同旅行已达到单人耗时。

源 checkpoint 冻结在首屏块生成之前且 join 完整恢复后才绘制，代码顺序支持重叠绘图方案；是否实际重叠、主侧 grant 的序列化是否反而占据长帧，必须由准确冻结组合的原生时序证明。本审查没有借此前 14/16/18 的性能样本替代新路径验证。
