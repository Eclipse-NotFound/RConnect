# Stage ENTER 尾端：最小源增量

仅在已冻结 RENDER 边界版上增加两个 `Stage.ENTER_FRAME` 时间标记：优先级 -1 与最低优先级 -2147483648，随现有附加监听器一起登记和移除。不接 CPU 线程或其它事件。原 sampler 的开始、停止、枚举、清理，RENDER 记录方法和三个场景断言保持不变。

每目标 pending 窗分别最多产生一个 `stageEnterAfterDefault={t,wall,enter}` 和一个 `stageEnterTail={t,wall,enter}`，最多两个对象。事件早于目标 ensure 时不保存时间对象，对应的 `Unavailable` 字段为 `stage-boundary-before-target-ensure`；若窗口内后来实际收到合格回调才记录并清除此原因。无回调时对象仍为 null，不补时间。重复、身份或时钟异常标对应的 `Incomplete=true`，不会更改原采样判定。

两个标记只代表这个 Stage 上的优先级边界，不能归因到某个模组。相同优先级仍按登记顺序运行，不能代表其它 DisplayObject 的 ENTER 广播结束，更不能代表所有 AS 或渲染已结束。按 startReturned → afterDefault → tail → 首个 RENDER 的实际可用时钟比较可缩小范围，不提供性能资格。

本轮仍只有一个 `entry.py`，相对冻结边界入口仅改变两个 kind 值；`inputs.json` 记录新源与旧源指纹，完整 source patch 仍从 v3 生成。新 kind 为 `scene-native-input-enter-tail-driver` / `ensure-work-enter-tail-v1`。旧目录不变，未编译/AIR。

根从 RConnect 目录执行：

```text
python -B -X utf8 experimental/recovery-paint-enter-tail/entry.py check
python -B -X utf8 experimental/recovery-paint-enter-tail/entry.py prepare --output build/m52/recovery-paint-enter-tail-driver-01 --build --registry-wait 900
python -B -X utf8 experimental/recovery-paint-enter-tail/entry.py run --candidate build/m52/recovery-early-exit-compile-01 --drivers build/m52/recovery-paint-enter-tail-driver-01 --game-candidate build/m52/recovery-early-paint-host-03 --output build/m52/recovery-paint-enter-tail-solo-01 --scenario scene --solo --sand-mode bridge --registry-wait 900
```
