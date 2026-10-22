# RENDER 边界：仅源补丁

冻结基线为 `recovery-early-paint-tail-sampler-v3/src/PaintTailSampler.as`，SHA `1d35215b6a24a1dae4e6d5071ab168b1777c9789d96340931417177448b81c61`。新源 SHA `7a16d1870ae2188d4cc943612b42d0a08c6627fa815e1d0a361da8c37a32a8aa`；仅改这一类，差异见 `render-boundary.patch`。未构建、未运行，旧源、runner、宿主和场景驱动均未修改。

在原 Stage 的 ENTER_FRAME 订阅成功之后，加两个 RENDER 订阅，优先级为 int 最大/最小值。原 `observe/close/collect/cleanup/onEnter` 逐字不变；没有增删 sampler API 调用，也没有主动 invalidate、隐藏显示对象或改变原三段及断言。接入时只将新类替换到新的隔离 driver 源；原 FirstRasterSceneProbe 会随 `EARLY PAINT TAIL` 的整行 JSON 输出新增字段，不需新 runner。

每段新增 `renderBoundary`：采样窗口 pending 期间最多保存 16 条 high/low 标记，含 getTimer、UTC 墙钟、全局标记序号、ENTER 序号；第 17 条起计数并标 `incomplete=true`。额外只保存 begin 前最近一个标记、stop 后第一个标记，不积累窗口外历史。异常/时钟回拨只影响这份边界证据，原采样资格不改。监听器在 dispose 中移除；订阅、卸载问题另见 `dispose()` 返回的 `renderObserverFaults/renderObserverAttached`，原精简 SUMMARY 暂不打印这两个新增字段，根可直接检查对象或源，不将原 SUMMARY 当新增卸载证明。

解释边界：

- [官方 Stage.invalidate 说明](https://airsdk.dev/reference/actionscript/3.0/flash/display/Stage.html#invalidate())：须已有 invalidate 请求，运行时才在绘制前广播 RENDER；安全域也影响接收。本补丁不主动请求。准确 early2 已有 `GameBridge.as:173/349`、`ExplorationSync.as:285` 和 `RoomSync.as:292/404/880/886/989` 调用，但静态存在不能保证每个目标窗口实际收到事件。因此无标记只能记 unavailable，不能判断没有渲染。
- high→low 仅限制同一 Stage 上的回调顺序；同优先级按登记先后，其他显示对象的广播回调不在这个范围。两个标记都在原生像素绘制之前，low→下一 ENTER 仍可能包含其他广播回调、原生工作和其他线程。不能据此直接归因为 GPU、主线程或某个原生函数。
- `available` 只表示窗口内实际收到标记；`incomplete` 只报告订阅/时钟/缓冲完整性，不保证每帧有事件或 high/low 成对。afterStop 可能因原 finish 先发生而为空。新增观测的运行不提供性能资格。

源级检查：5 处精确替换反向还原原 v3 全文，所有 sampler API 文本调用数保持一致；原开始/暂停/枚举/清理方法未改。真实事件触发、编译和运行待根审查后决定。

## 唯一接入口

新增 `entry.py` 和 `inputs.json`，没有复制旧迭代链。沿准确 RV83v2 安装准入（隔离运行仍 RV7852）、host03、D356、Sand003；本轮不再接外部 CPU 观察器。运行时只借用原三段原生 runner。新 kind 为 `scene-native-input-render-boundary-driver`，诊断种类为 `ensure-work-render-boundary-v1`，不冒用 E6B3 资格。旧 31 项组件证明只用于原 v3 和真实 sampler API 来源，新类只有源差异审查，运行资格仍为 false。

根从 RConnect 目录执行：

```text
python -B -X utf8 experimental/recovery-paint-render-boundary/entry.py check
python -B -X utf8 experimental/recovery-paint-render-boundary/entry.py prepare --output build/m52/recovery-paint-render-driver-01 --build --registry-wait 900
python -B -X utf8 experimental/recovery-paint-render-boundary/entry.py run --candidate build/m52/recovery-early-exit-compile-01 --drivers build/m52/recovery-paint-render-driver-01 --game-candidate build/m52/recovery-early-paint-host-03 --output build/m52/recovery-paint-render-solo-01 --scenario scene --solo --sand-mode bridge --registry-wait 900
```

`check` 不编译、不启动 AIR；`prepare` 不带 `--build` 仅准备文件。所有输出要求新目录，不能原地重写旧证据。准备与编译复用旧配方和参数；3 个旧观测 AS、原场景和断言逐字核对，仅新 PaintTailSampler 来自本目录。新 prepared.json 记录实际新 driver/源码 SHA；原 driver 共通审计、22 项安装核验及排队后重核、独占登记、内存门槛与清理继续生效。
