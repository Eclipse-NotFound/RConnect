# CEC6 A版 travel-hold：独立只读审查

2026-10-22。只读提案、准确 CEC6 冻结源、early 分支及根会话已经构建的 003。未修改来源、未编译、未启动 AIR。**最初发现的编译阻断已由根会话修正；003 来源符合预期，没有查到另一个足以阻止受控原生测试的确定运行时缺陷。** 这不是全模组冻结、无票据等价或旅行性能已经实测通过。

## 唯一阻断及其解决

原提案 `SandyTravelHoldBridge.as` 的 `query` / `acquire` 只有 try/catch 内返回，缺函数末显式返回。这与同工具链实际失败的 `build/m52/recovery-early-external-component-01/compile.log` 两方法、`recovery-wall-working-set-component-02/compile.log` outcome 同形，已在构建前报告。

根会话的 `mods/Sandevistan/build/out/a-travel-hold-20261022-003` 已补 `return null` / `return false`。独立比较证明 helper **仅多这两行**；entry仍是原提案7个hunk、只新增22行。003 receipt确认编译 exit 0，SWF实算 `3e220b595f54249c82fcad36e1b13364c0456c4e8b5f4e20f876c3964c7d331c`。本审查不重新执行构建，也不覆盖原失败。

## 实际契约和调用路径

- **身份与准入**：helper `query/acquire/isHeld` 验证当前静态 `fe.World.w` 与传入 World、该 World.game 的严格身份。`acquire` 同步重读身份及状态；仅 phase `idle`、debugTest不为true可新取票。active/replay拒绝，同owner/id/World/Game重入幂等，不同owner或id不能覆盖。readState闭包只读CEC6自身布尔/计数器，没有异步或执行游戏逻辑，因此query与acquire之间的二次检查成立。
- **持票保护**：entry在 `onFrame` 第一行返回，早于keybind.step、onFrameInner、stepSandy、stepReplay、cooldown、ammoLeash、敌人step及视图/残影更新。准确CEC6中所有已查到的手动gg/loc/敌人补步都由此帧链到达；无另一个Timer推进模拟。原SOUND_COMPLETE/加载错误仅处理音乐，不在冻结承诺内。即使有额外调用者直接尝试startSandy，它也有独立hold检查。
- **输入释放**：`onKey` / `onMouseDown` 在持票时直接返回，不调用start/end、press、自愈写Ctr或积累新mouseAtkPulse。`onKeyUp` 仍先releaseKey，再清keyDownSeen/keyPressTime，避免被忽略的DOWN造成IME计数；原 `onMouseUp` 仍清mouseAtkDown。失焦的releaseAll/clearAll原路径不变。**输入释放属于有意保留的状态清理，不应测试为“所有字段逐字不变”。** 该接口不吞全局事件；原生菜单/玩家控制由early的World票据负责。
- **取消与更换身份**：helper的release只认私有owner和id，允许在Game已更换后释放，不回写旧World暂停/玩家控制。isHeld发现World或Game更换即清旧票；读失败暂时保持持票，query失败返回null。MapGeneration保存实际acquire载体及owner/id，release不重新按名称发现另一个对象；helper已因换身份清票时，RC只在确认当前World/Game已经不同后退掉本地记录，当前World读不到不会假称成功。
- **RC时序**：`offerEarly/armEarly` 在early.arm之前acquire；能力缺失、查询不明、活动/回放拒绝时走旧旅行。`completeEarly` 在双方真实首绘/ACK之后先release确切外部许可，再恢复本票据的controlOn与暂停。`cancelEarly` 未paintAllowed可回退；已恢复且仍联网的失败故意保留锁，断开时再释放，不能把它当泄漏后擅自解锁。`fail` 不释放部分恢复状态。旧消息由earlyId/epoch/barrier及原生身份约束，不由helper另建状态机。
- **无票据路径**：isHeld在owner为空时立即false，不读World或readState；原entry各函数后续正文和先后顺序没有改动。新增不可见Sprite、空持票判断和函数调用仍有实际成本，不能称SWF或CPU指令完全一致。载体挂载及跨域发现仍需真实实例确认。

对应准确位置：CEC6 entry `onFrame:613`、`onFrameInner:623`、`startSandy:3892`、`stepEnemySandy:4778`、`onDeactivateClear:6642`、`onMouseDown/Up:6663/6668`、`onKeyUp:6673`、`onKey:6713`；early `MapGeneration:62–96`、`RoomSync:104–226/1021`。原CEC6敌人房间状态在stepEnemySandy检测loc改变后重建，因此此接口只是把这次原有处理延后到release，不能声称跨图保留原敌人时停录像。

## 准确003装配核验与剩余边界

003 `intent.sources` 与实际frozen **11 AS逐项一致**；CEC6原10文件中9个字节不变，唯一改动旧文件是entry，唯一新增文件是helper；没有B接口或当前Sandevistan root源混入。entry按原CRLF在内存逐hunk重建，SHA为 `577679b9…0cd352`，与003一致。编译配置source-path只指向003/frozen/src。完整指纹见 `evidence.json`。

真实测试仍必须区分：无票据正常活动/回放与旧CEC6行为；持票时独立补步与冷却确实不进展、释放后恢复；按住/松开/失焦；同World换Game、整World替换、query异常和失败断开。准确CEC6自身缓存world仅在null时重新发现，这个旧行为没有被接口修复；**本次只能确认许可会因整World替换自动清除，不能据此宣称原模组已支持整World替换后重新绑定。** 常规换档的同World新Game路径另行验证，不把两者混同。

未发现需要新增状态机、改变release所有权或扩大其它模组修改的确定理由。建议沿已准备的组件和受控原生入口继续，不先扩大实现。
