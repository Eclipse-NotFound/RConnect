# 首次实绘后的外部 CPU 采样组件

仅源代码和注入式组件；**未编译、未执行 AS3 组件、未运行 AIR、未接入驱动、无性能或发布资格**。不修改 host03、现有 aggregate 源、三段旅行流程或任何门槛。后续是否接入由根在无采样轮结束后决定。

- `src/PaintTailSampler.as`：状态机。真实采样操作全部通过注入适配器；只监听舞台下一次 `ENTER_FRAME +1000000`。没有世界枚举、游戏写入、日志或新的原生观察槽。
- `src/FlashPaintTailSampler.as`：唯一使用 `flash.sampler` 的正式适配器。默认不获准采样；构造参数必须由已核对的运行入口明确提供。
- `tests/PaintTailSamplerChecks.as`：纯替代采样器组件，`run()` 返回断言结果。可在根后续单独编译的组件入口中调用；它没有游戏、真实采样器或密集场景刺激。
- `tests/PaintTailSamplerComponentDoc.as` 与 `component/`：既有 `run_recovery_component` 可直接使用的最小AIR入口及四份精确副本。只强引用正式适配器验证编译，不实例化或调用它；结果写入隔离 appStorage 的 result.json 并退出。
- `check.py`：可立即执行的只读源码结构/预算/依赖检查，不冒充 AS3 编译或组件执行。

## 待接入契约

单实例内新建一次 helper，将真实适配器与“当前原生槽仍严格等于 aggregate 自己的 Function”检查闭包注入。先 `attach(mod.stage)`；各段原 begin 调用 helper.begin(world)，真实 raster bind 调用 helper.bind(world, loc, renderer)。在 aggregate 的原 receive 校验与记录之后，调用 helper.observe(renderer, world, game, loc, metadata)。**不要用它替换或二次包装原生观察槽。** helper.finish() 与 dispose() 只返回数据，由外层在结束时统一输出并单列输出耗时。

只认目标房间、成功完成且 resident 从0变正数的第一条回调；`initial=false` 也可触发。后续回调不重启。每段最多一次，总计三段；没有对应事件时记录 not-triggered。begin 会取消上一未结束窗；取消清理失败则阻止新段。未获得采样器租约不 clear/pause/stop；失去租约不触碰新持有者。stop 或 clear 失败时保留租约并标 cleanupBlocked，后续不得继续采样；这需要结束该隔离诊断实例，不能强行解锁。

Flash 适配器静态令牌只保护本组件的多个实例，**不能发现或阻挡其他 SWF/外部分析器的采样调用**。后续运行入口必须另行冻结/核对唯一采样入口；不能与旧 after-render sampler 驱动同时加载，也不能以 getSampleCount()==0 代替所有权证明。claim 的约定是原子成功/失败，正式适配器在赋予令牌后没有可抛操作。

`sampleInternalAllocs(false)` 确实修改当前进程共享的采样设置，因此只允许在独占、用毕退出的隔离诊断进程执行；不能描述为完全不改采样设置。它不改用户或外部分析器配置。

## 数据解释与上限

`complete` 只表示窗口以正确下一舞台回调、身份、时钟和清理结束；`samplingComplete` 还要求没有任何截断；`cpuEvidenceAvailable` 仅表示保留了CPU样本；**只有 cpuEvidenceComplete 才表示有完整窗口的CPU样本证据**。零CPU样本不能证明等待或GPU耗时。所有这些字段都不提供产品性能资格。

每窗至多32768条枚举样本、1024个不同栈、64层栈深、每帧文字512字符、总栈文字262144字符；最多三窗。分配/删除样本只计跳过数量，不留被采样对象。所有裁切和预算丢弃都有独立计数，均使 samplingComplete/cpuEvidenceComplete 为false；未达枚举上限时，总数与实际枚举数不一致也拒绝。枚举上限限制整理，不承诺 flash.sampler 的原生缓冲也有固定内存上限。

时刻包含：原ensure起止、观察进入、准备起止、start调用前/返回、下一stage入口、pause返回、整理起止与清理起止，均带单调时钟与墙钟。先pause再枚举、拼接字符串、清理；collectMs包含清理，cleanupMs是其中的子区间，**二者不能相加**。外部输出耗时尚未包含，也不能改写stop时间。舞台优先级只规定同一舞台监听器的次序，不证明早于其他DisplayObject的广播。真正开窗在原生ensure回调内，其原调用栈尚未返回，不等于屏幕像素提交完成。

整理会推迟下一帧与原旅行/输入统计，故本轮只能作归因，不能减掉collectMs后当作无诊断性能。普通异常、提前结束、身份/槽替换、时钟回退、采样器异常都保留失败记录；不放宽流程或强凑三条完成窗口。

## 已提供的组件反例

失败ensure、已有resident、错误房间不启动；initial=false启动且重复回调不重启；同舞台高优先级先pause；取消与无触发；三段上限；已有/被夺走的租约；world与观察槽替换；start/pause/枚举/stop异常；取消清理失败不进入新段；时钟回退；样本、唯一栈、深度、单帧文字、总文字预算；零样本不产生完整CPU证据。

静态检查命令（从 RConnect 目录运行）：

```powershell
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/recovery-early-paint-tail-sampler/check.py
```

组件预期 **31条断言**。`prepare_component.py` 只更新本目录内的四份精确源副本与指纹，不启动编译器；check.py 会逐字核对副本。根在独占登记、1GiB门槛满足后可执行以下既有runner命令；本交付没有执行它：

```powershell
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 tools/validation/run_recovery_component.py --source experimental/recovery-early-paint-tail-sampler/component --entry PaintTailSamplerComponentDoc.as --output build/m52/recovery-early-paint-tail-component-01 --expected 31 --registry-wait 900
```

组件通过也只验证替代采样器状态机，不证明真实flash.sampler可用、AIR的全局广播次序或游戏性能改善。
