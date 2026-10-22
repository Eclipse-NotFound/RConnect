# 同一 Stage 的负优先级分段标记

基于冻结的 `recovery-paint-enter-tail`，保留 -1、最低优先级与 RENDER 标记，增加 ENTER_FRAME 的 -7001、-8001、-8501、-8701、-9001、-10001、-12001、-20001 八个标记。仅新目录有改动；不接 CPU 线程、不增加其它事件、不改变 sampler 起止、生产逻辑、原三个场景及断言。

每段 `stageEnterBands.priorities` 固定为上述顺序，`marks` 最多 8 条，每个 priority 最多一条 `{index,priority,t,wall,enter}`。位掩码防止重复，数组上限防止增长；每次核对同一个 Stage、原 startStage、world/game/renderer/room 身份，时间不得早于采样开始或上一个标记。仅目标 ensure 后 pending 窗保存时间。提前收到事件只更新对应 `unavailable[index]` 原因，不记录伪造时间。

`unavailable` 始终保留 8 项，成功记录的位置为空串；缺失为 `not-observed-after-sampler-start`、`stage-boundary-before-target-ensure` 或 `invalid-frame-identity-or-clock`。只有全部八项成功才 `completeCoverage=true`，判断证据还须同时满足 `incomplete=false`、faults/duplicates/overflow 都为 0。这些诊断字段不改变原采样或场景判定。

相邻标记只限定同一 dispatcher 的优先级区间，不直接归因某个模组；其它显示对象广播、同优先级登记次序和标记自身开销仍须考虑。不提供性能资格，卸载实证沿此前限制：新增观察器清理字段没有进入旧精简 SUMMARY，不能据其推断所有新监听器实际已卸载。

仍只有一个 entry.py，相对上一版只改两个 kind；其余 3 观测 AS 和原断言从冻结来源复制及逐字核验。新身份为 `scene-native-input-enter-bands-driver` / `ensure-work-enter-bands-v1`；inputs 记录新旧源指纹，完整补丁从 v3 生成。未编译或启动 AIR。

根从 RConnect 目录执行：

```text
python -B -X utf8 experimental/recovery-paint-enter-bands/entry.py check
python -B -X utf8 experimental/recovery-paint-enter-bands/entry.py prepare --output build/m52/recovery-paint-enter-bands-driver-01 --build --registry-wait 900
python -B -X utf8 experimental/recovery-paint-enter-bands/entry.py run --candidate build/m52/recovery-early-exit-compile-01 --drivers build/m52/recovery-paint-enter-bands-driver-01 --game-candidate build/m52/recovery-early-paint-host-03 --output build/m52/recovery-paint-enter-bands-solo-01 --scenario scene --solo --sand-mode bridge --registry-wait 900
```
