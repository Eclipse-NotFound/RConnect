# 已确认命中在射手离房后的时钟解绑

2026-10-22。独立有限补丁，准确基线 `build/m52/recovery-03` / `a98c6d00e85afad965ea2358c1bf4b8571a48f8e0c71ea244c68931e47a59cf1`。此目录没有改 integrated、冻结候选或安装文件。初次交付只做静态审查，**没有运行 JVM/AIR，红绿结果尚待主会话实际执行**。

## 已确认的代码缺口

`GameBridge.updateRemote` 看到队友离房时会销毁 ghost 并停止推进它的 RemoteMotion；`ProjectileVisuals.forget(owner)` 原本只移除飞行显示。已收到的 `ImpactEventQueue.pending` 仍引用这个 motion，若游标还没到命中时刻，它会等待到 15 秒后丢弃。

同一处 forget 也漏了 `EnergyImpactVisuals.active`：已确认的短命中光效仍持有相同旧 motion，可能不开始或卡在最后一帧，直到原有超时清除。这是相同调用链上的确定静态引用，不是据武器名称扩大范围。本补丁一并解绑这两个已经收到的有限命中特效。未取得新数据的其它武器、飞行弹寿命、敌人 AI、碰撞和伤害均不改。

这不是 40814ef14c 首轮 2.75 秒延迟的已证根因；那轮始终同房，仍须按 `../recovery-wall-impact/latency-review.md` 的独立观测方案检查。

## 四份生产覆盖

| 文件（`src/rconnect/game/`） | 有限改动 |
|---|---|
| ProjectileVisuals.as | 原有 forget(owner) 先把该 owner 的每个武器 channel 交给两类命中效果解绑；原 active 飞行显示移除及 seen 清理保留。只读一次 getTimer，给所有 channel 使用。 |
| ImpactEventQueue.as | 新 forget(channel,now) 仅解绑它的 clock。pending 暂存 channel 引用，确保 owner 映射删除后弱键不会先被 GC，让原有暂停恢复遍历仍能找到待播时钟；命中播放/丢弃后引用随 pending 消失。 |
| EnergyImpactVisuals.as | 新 forget(channel,now) 只遍历该 channel 的既有 records，解绑各有限效果的 clock；不重建素材、不改变 frames/end、恢复帧、去重或超时。 |
| ProjectileFrameStream.as | 新 detachClock：复用已有 receiveClock(null) 从**当前实际显示 cursor**建立本地 offset，绝不跳到最新收到的 sampleTime 或 impact.at。重复调用已无 motion 时不改锚点。 |

暂停中的解绑以 pauseAt 为有效 now。重新建立 fallback 时同时令 clockAt=有效 now，保证“暂停开始后才收到事件，再解绑”的路径在恢复时减去正确暂停区间，不能把接收时刻到暂停时刻的差误加进动画。没有修改 setPaused 的算法、事件 received/updated 或 15 秒期限。

pending 保留 channel 只限于原有有界队列（最多 512 项）和既有生命周期；并不保留 ghost。forget 后原 active records 仍由旧逻辑清理。待播清空/reset/异房丢弃后即可释放。Energy 的暂停恢复本来按 active 遍历，不依赖弱 channel 键，无须相同引用字段。

## 前后共用组件

`tests/DetachChecks.as` 在旧/新两版都只调用原有 `ProjectileVisuals.receive/forget/tick/setPaused/reset`，不调用新 helper，不使用条件分支让旧版跳过测试。实际编入以下生产类：ProjectileVisuals、ImpactEventQueue、ProjectileFrameStream、EnergyImpactVisuals、BallisticImpactVisuals、RemoteMotion。

替身边界：FixtureClock 给出受控但不再推进的射手 cursor；原生 Emitter 边界只计数；FixtureFlare 代替游戏原画；GameBridge.probe、念力和爆炸旁路是明确存根。**不是原生碰撞、真实素材、Session/TCP 或性能验证。** 实际 fallback 与队列代码没有替换。组件的 tick(now) 采用其现有公开参数测试精确边界；生产 forget 仍读取正常 getTimer，没有给生产加测试时钟参数。

覆盖：

- 同房观察者保留：射手 forget 前命中未到时刻；199 ms 不提前、201 ms 可播；重复包与后续 tick 一次性。
- 观察者换房：旧房命中立即丢弃，返回也不复现。
- 重复 forget、未知 owner；解绑后旧 motion 被外部改动也不得影响队列。
- 两名射手相同枪械/stream：只解绑指定 owner，另一方继续跟其真实 cursor。
- 原有 15 秒超时仍退役未到时刻的命中，不在很晚以后补发。
- 有限能量命中从已确认第一帧到末帧再退役；重复接收不多建素材；另一 owner/换房隔离。
- 活动飞行弹仍按原 forget 移除，不因命中保留而复活。
- 原本就是 null motion 的 fallback 保持不变。
- 暂停中解绑、暂停开始后过 60 ms 才收到并解绑、恢复后无额外提前。
- 先解绑再暂停，期间请求两次 GC，恢复后仍保留暂停减时。GC 请求不保证运行时一定收集；关键弱键生命周期同时由 pending 的直接引用静态保证，不把 GC 请求当“已证明发生收集”。

异步 Timer 只用来制造真实不同的暂停/接收 getTimer 时刻（总计不足一秒），不预热素材或改变测试首发。断言中的 `REGRESSION` 是旧版预期失败标签；结果仍按实际失败写入，旧版不会改绿。当前预期共 35 条正常路径断言；以实际 result.json 为准，不据静态数量声称通过。

## 由主会话执行

`prepare.py` 默认只冻结源与夹具；只有显式 `--compile` / `--run` 才启动进程。输出必须是 `build/m52` 的新直接子目录，拒绝覆盖既有目录。准确基线/覆盖指纹见 manifest.json；冻结全部输入并在编译/运行后复验。编译器与组件共用 game 登记，AIR 使用独立应用 ID/隐藏桌面，finally 只清理自身进程。资源空组件仍要求 1 GiB 可提交余量，没有降低双实例游戏的内存要求。

取得登记后、编译器启动前、编译结束和 AIR 启动前/结束后都复核原输入与冻结源码指纹；receipt 保存各阶段结果和 `Checks.swf` SHA-256。通过还要求 35 条实际断言非空，每条 `passed` 必须是真布尔值，逐条结果与 `total`、`passed_count`、`failed`、`passed` 汇总一致。空报告、提前结束、格式错误或汇总矛盾均不通过；原始 result.json 原样保留。

```powershell
$detachPython = 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
# 旧版应真实报告回归断言失败并返回 1，保留 result/receipt，不回写通过。
& $detachPython -B -X utf8 experimental/recovery-impact-detach/prepare.py build/m52/impact-detach-control-01 --variant control --run --registry-wait 900
# 同一夹具，候选应全部通过；不能以编译通过替代执行结果。
& $detachPython -B -X utf8 experimental/recovery-impact-detach/prepare.py build/m52/impact-detach-candidate-01 --variant candidate --run --registry-wait 900
```

组件通过后还需主会话整合并跑真实“射击后离房，观察者留原房”检查。这个补丁没有解决或验证首发迟到、整体性能、网络断线或复活行为。
