# 位置取样延后姿态：停在输入别名反例

**结论：暂不实现，不交付生产覆盖，不继续 ABBA。** 只跳过接收时未消费的姿态计算有真实 CPU 栈依据，但“已经公开的 state 继续完整更新”只能保护输出引用，不能保护仍由调用者持有的嵌套输入。现有接口没有可证明的不可变输入契约。为此增加复制或所有权状态会扩大本轮范围，且可能吞掉预期收益。

准确基线为 recovery21（`9ac7ede7…8b7e7ba`），完整源指纹见 `handoff.json`。本目录只有测试组件及其生成器，没有 `src` 生产覆盖，也不修改 GameBridge。`RemoteMotionAfter` 是**被否决方案的测试替身**：由完整真实类做限定变换，保留公开 state 保护、同游标补齐与原时钟，用于证明尚存的不等价，禁止合入。

## 已确定的机制与未发生的结论

- `RemoteMotion.as:133–134` 只浅拷贝入参。`weapons`、`visual.pose.blit` 等仍指向原输入。`:251–252` 的武器和身体插值在接收时已执行；`WeaponDisplay.interpolate:45–64` 与 `blendBodyPose:258–279` 在可插值分支复制对象并算出数值。这些已算值不会被之后的嵌套输入修改追溯改变。
- 延后到 `currentSample` 才计算时，同一 source cursor 也可能读到修改后的输入，显示结果因而不同。仅保存 `a.snap/b.snap` 身份不能解决嵌套内容修改。
- 另一分支又必须保留引用：身体停止、稳定姿态或动画标签不匹配时，原 `blendBodyPose` 直接返回 `a.pose`。后续输入修改在旧版中本就可见，统一深拷贝同样不是等价修正。
- 调用方确能持有这些对象：`GameBridge.applyEnemyMotion`/`applyUnitsSync` 是接收外部数组的 public 方法；`Session.as:504` 直接传递 `msg.enemyMotion`；`TcpLink.as:200` 同步派发原 `msg`；`NetMessageEvent.data` 是 public，构造和 clone 都不复制数据。因此后续消息监听器保有同一对象的路径存在。
- **尚无证据证明当前正常生产链已经在这段延后窗口主动修改 display/blit，也没有发现由此造成的既有游戏故障。** 已检查的 `ProjectileVisuals.receive` 读取事件，不改这两项姿态输入。`UnitPresentation.apply:378` 确会补写 `s.melee`，但现有 `tickFrozenAnims` 是完整 sample 在先、apply 在后；它不能作为本反例已经在实际运行触发的证据。这里是代码可达的 API 可变风险及未满足的等价要求，不是新的实机故障归因。

## 最小可运行反例

组件使用完整 recovery21 `RemoteMotion` 和受审的延后版本；只有名字不同。`TeleportVisuals.valid/split` 与 `WeaponDisplay.interpolate` 提取自准确21，函数正文不改。没有游戏/TCP/真实画面，也不计性能。反例步骤：两帧入队 → 旧版完整 sample / 试验版位置 sample → 对两组调用者持有的末帧嵌套输入做相同修改 → 两侧读取 currentSample。游标和位置仍相同，但武器/身体已算值不同。

准备及核对（均不调用编译器）：

```powershell
python -B -X utf8 experimental/recovery-position-sample/prepare.py
python -B -X utf8 experimental/recovery-position-sample/prepare.py --verify
```

父会话若需执行，通过原组件入口：

```powershell
python -B -X utf8 tools/validation/run_recovery_component.py --source experimental/recovery-position-sample/components --entry PositionAliasCounterexample.as --output build/m52/recovery-position-alias-component-01 --expected 8 --registry-wait 900
```

**预期红结果：8 项中 6 过、2 项语义等价断言失败。** 两个 FAIL 应分别是嵌套武器与 blit 输入修改；原始结果应保持失败，不以“预期失败”改写 runner 资格。另六项验证相同位置/时钟、旧值已冻结、新一次完整 sample 可重新取得相同值、停止姿态原引用语义，以及已公开输出 state 的保护。数值写进 `evidence` 供直接核对。

本交付只做源代码生成、反向逐字比对和 Python 语法检查；未编译或运行 AIR，尚没有实际 6/2 结果。不进一步补复制、不扩时钟或所有权状态机、不据 CPU 栈提出整体性能承诺。
