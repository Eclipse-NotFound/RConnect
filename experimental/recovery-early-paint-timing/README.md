# 提前加载：原生 ensure-work 计时桥（仅诊断）

准确基线为 `build/m52/recovery-early-host-01/pfe.swf`，SHA256 `2d415dd373236fff3c7a691db4eff8327a6de97b91c23d8a818ec77082b3dd29`。使用该产物自身回读的 `after/scripts/fe/graph/Grafon.as`，原源 SHA `e6b4142462c1187388c4bb9c8151dd6c2605ce4e4b9fedd421cf4749c54bd7a0`，不是当前工作源或旧参考类。

只改变 Grafon 的 `sceneEnsure`，新增两个诊断静态字段；原 91 个方法中其余 90 个逐字不变。完整导入源在 `src/fe/graph/Grafon.as`，精确差异在 `Grafon.patch`。没有修改已有冻结候选、安装版或其它模组，也没有编译或运行游戏。

## 观察点与异常语义

原来的 `rconnectRasterWaiting()` 返回和“预载全部完成”的返回均在观测区之前，因此它们不产生记录。只在真正调用 `scenePreloadAll()` 或 `sceneEnsureUpcoming()` 前记录两种时钟，在原调用的 `finally` 中先取结束时钟，再分配记录并通知外部观察器。

名为 **ensure-work**，包含该绘图管线的分配、查块、预热等整体计算，不是单次像素绘制的纯 CPU 时间。尤其 upcoming 在已有块齐全时仍可能只做检查/预热调度；不能把每一条都称为产生像素的绘制，也不能用嵌套区间总和声称绘图重叠，应按实际区间并集统计。

- 原两个工作调用各一次，原分支和 return 保留。工作本体没有新增 catch；工作异常经过 finally 后应继续抛出。
- 开始采集和 finally 的整个观察路径分别独立 `catch(*)`，包含时钟、记录分配及回调。观察异常只增加诊断故障计数，不替换原工作异常。
- 回调发生在结束时间记录之后，不计入所报区间；记录开始之前的少量身份读取也不计入。这不是零诊断开销，不能用于正式性能门槛。
- 没有订阅者时没有显式 `new` 或对象字面量求值，但仍有新增局部变量/分支及 try/finally，不声称无任何开销。
- 新静态 `rconnectPaintTimingFaults:uint` 让丢失的观察记录可被判无效，不能将异常被隔离误作成功。

## 外部槽契约

`public static var rconnectPaintTimingBridge:Function = null;`

回调签名：`observer(renderer:Object, world:Object, game:Object, loc:Object, value:Object):void`。前三个身份与 loc 在该次工作开始时保存；renderer 是执行该方法的实例。回调不返回放行信息，任何返回值均不使用。订阅者必须只读、固定上限、旅行结束/失败时仅解除自己仍持有的槽。

`value` 全是标量：

| 字段 | 含义 |
|---|---|
| phase | 固定 `ensure-work` |
| preload / initial | 开始时的分支模式和原方法参数 |
| left / top / width / height | 原始视口参数，不改变它们 |
| started / finished | 同进程 getTimer 时钟，不直接跨进程相减 |
| startedWall / finishedWall | Date 墙钟；与本进程 tick 配对作跨进程区间对齐 |
| residentBefore / residentAfter | 工作前后已有块数量，不把它当绘制次数 |
| completed | 原工作正常返回才为 true，抛错时为 false |
| sameWorld / sameGame / sameLoc | 工作结束时的世界、Game 和 renderer.loc 是否保持对应开始身份 |
| worldRendererAtStart / worldRendererAtEnd | 两个边界 World.grafon 是否为实际执行的 renderer |
| worldLocAtStart / worldLocAtEnd | 两个边界 World.loc 是否为本次执行的 loc |

`PaintTimingBuffer.as` 是可参考的未编译外部缓冲器：每次 begin/finish 最多32行，调用33标 overflow 后脱订；保存相同世界/Game/renderer与位置序号，不序列化对象树；所有行结束后由原测试驱动一次输出。finish 带 `faults/nativeFaults/ownershipPreserved/overflow`，其中任一失败均不得视为有效诊断。正式外部驱动由 `recovery-early-paint-driver` 单独组装，需另外对齐真实首绘票据身份，不以本示例代替该绑定。

## 根会话执行入口

在 RConnect 目录使用既有 Python，加 `-B -X utf8`：

```text
experimental/recovery-early-paint-timing/check.py --output experimental/recovery-early-paint-timing/source-check.json
experimental/recovery-early-paint-timing/build_host.py build/m52/recovery-early-paint-host-01 --build --registry-wait 900
```

`build_host.py` 不加 `--build` 只准备新输出的源码、命令和清单；输出必须为新的 m52 直属目录。加 `--build` 才使用共享 game 登记串行启动 FFDec，每次启动要求1GiB可提交余量、运行低于512MiB只停止本脚本的编译进程。不会启动AIR或部署。安装22项、工具、源码、准确基线前后核对。

导入仅包含 Grafon；回读检查所有91个方法、类字段外壳、七个代表类、类清单、电影头与全部非代码tag，范围不冒称所有ABC语义已证明。严格源码回读不接受任意局部名替换或宽松异常表忽略；若编译器移动声明，保留实际失败后单独核对具体差异。

构建额外导出实际 `sceneEnsure` P-code：新 getTimer 必须直接解析为 `QName(PackageNamespace("flash.utils"),"getTimer")`；Date 必须为全局零参数构造；拒绝全局 flash 属性链。`check.py --before … --after … --pcode … --output …` 可在已有输出上只读复验，不运行JVM。

**异常控制流仍需在首个真实产物上核验。** 构建脚本有意保留 `validated=false` 和 `exception_semantics_review_required=true`：词法相等、找到catch表和一个throw不能证明原异常重抛正确。应沿 preload 正常 return、upcoming 正常结束、两者抛错三路核对实际finally分派与异常寄存器，确保观察器catch之后仍抛同一对象；将准确P-code指纹与窄证明另存，不改宽泛规则放行。源码/绑定检查完成不自动获得原生或性能资格。

## 本次已执行

- 准确源准备已完成，最终导入源 SHA `2d4471015916e38973ba63e75e15a86514be3236118528b5d58f98b2a6e73b0d`。
- 纯 Python 检查确认90个未改方法，并拒绝9种有害源变化，见 `source-check.json`。最初检查器把一侧CRLF与另一侧LF直接比较而失败；仅修正检查器的双方换行处理后通过，生产差异不变。
- 没有运行JVM/AIR，没有实际P-code结果；缓冲器也尚未AS编译。不能宣称绘制耗时、区间重叠或加载性能已测得。
