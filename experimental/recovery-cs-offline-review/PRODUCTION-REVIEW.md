# 离线采集生产形态提案审核

2026-10-23。只读核对 CS 新提案，并给出最小验证入口。本审核未编译、未启动 AIR、未修改候选或 CS 文件。源码通过不等于运行、合并或部署通过。

## 来源与差异

提案目录：`mods/ContinuousScene/build/generated/rc-offline-production-proposal-20261023-r1/`。

- `production.patch`：`D17C2E92271CEBDD57527B4DC4273DCF620D22D72E25074648939FADB2A06F23`。
- `source-provenance.json`：`EC95927AA31E0517B17850EAED2150B93530C1C59EC4DA420B3C445F572DD045`。
- `diagnostic-to-production.patch`：`87C56F1263F683B1AD39CA79AA3D5C220368BCDB74E40F6F0125D63AE99BA4AC`。
- 来源仍为正式574D的准确78源：prepared `4D0743…112B1`，诊断来源仍88CC、proof `0BE07E…EC81C`。独立重算78份 before/after，与准确清单一致；3类改变、75类不变。按保存的精确替换逆向恢复78份原始字节全部相同，派生脚本指纹相同。
- 审核首轮用 `read_text()` 反向比较，自动换行规范化造成19个假失配；改用 `read_bytes().decode()` 后78份全过。不是候选改变换行。未执行派生脚本。

与88CC相比，全部测试载体、NativeApplication/MovieClip新增导入、开关、getter、计数器、snapshot API均已移除。78源中未发现 `offlineProbe` 或 `RConnectOfflineProbeCarrier` 残留。新增仅：Session生命周期标志及资格函数、入口注入资格闭包、GameBridge容错资格函数与原两组观察调用的条件包围。版本号保留原值，后续由根集成时决定，不能靠同版本日志辨识此候选。

## 行为判断

`Session.canSkipOfflinePresentation()` 现在默认为 `!_networkAttempted && mode===OFFLINE`。这相当于诊断B臂的省略规则自动用于从未尝试联网的本次Session；它不是可随时开关的产品功能。

`startHost`、`startJoin` 第一条语句先设 `_networkAttempted=true`，早于 stop、关闭旧连接和开启新网络。整个源码只有初始false及这两处true；退出、失败、断开、自动重连都不复位。RConnectMod只有一处Session创建，在它之后、autoStart之前绑定闭包。因此标准路径上任何一次网络尝试都永久恢复该Session的原采集，包括无人宿主、失败后离线、离开后继续单人。真正重新启动产生新的Session才再次获得纯离线资格。

`GameBridge.offlinePresentationEligibility` 默认为null；函数未绑定、返回非严格true或抛异常都执行原观察。原被包围的六次调用与88CC完全相同；墙痕、传送、invalidate、onPerceptionFrame、本地念力、实际显示/AI/物理均未改。消费者审核沿用本目录README，因为对应75个实现文件不变。正常stop仍清观察历史，未见离线历史被带进新联网的标准源码路径。

没有发现阻止这一限定候选进入隔离验证的新增源码回归。但从诊断切换改为默认生效是实际产品行为变化，不能继承88CC的运行资格；真正产品版还要按以下入口验证。

## 真Session最小生命周期验证

优先使用现有单实例原生驱动方式，**不复制或伪造Session状态机，不写私有标志，不构造第二Session遗留重复Timer**。可参考 `experimental/recovery-sandy-hold-native-cooldown/tests/SandyHoldNativeTestDoc.as:14,93` 的 `MOD_CLASS=RConnectMod` / `RConnectMod.instance` 引用、稳定游戏准备和超时日志；替换场景测试主体，不继承其中early2/Sand构建身份。实际使用新候选的真实 `mod.session`、`mod.game` 和未修改的网络类。

两次串行新鲜隔离启动足够覆盖主要入口，避免同时开两个完整游戏。各自唯一AIR ID、独立配置/存储、测试登记和原内存门槛不变。

1. **初始离线→无人宿主→leave→再host**：启动前私有配置autoRole空、各自动游戏操作关闭，加载稳定原生场景。先断言mode=offline且资格true；调用真正 `session.startHost()` 后立即断言资格false，随后确认 `server.bound===true`、`server.clients.length===0`、peers空。在原生若干ENTER/RENDER内持续确认false；`session.leave()` 后mode=offline但资格仍false；再次startHost、leave保持false。端口使用本轮独占的空闲测试端口；不要占用用户正式端口。
2. **首次join失败→自动retry→leave→手动retry**：另一个新AIR ID，启动前私有配置autoRole=join、hostIp=127.0.0.1、独立无人监听端口。真正 `autoStart→startJoin` 后资格应false；等实际FAILED和对应日志确认失败，不伪发NetMessageEvent。约2秒后的真实自动重试应产生新link/日志且资格持续false。随后leave停止用户主动退出后的重试，再调用startJoin覆盖手动retry。每阶段检查是否出现非预期游戏错误；退出只清本轮实例/socket。

注意 `_autoRole` 在Session构造时缓存，事后 `config.setValue('autoRole','join')` 不会启用自动重连。第二轮必须在启动前准备私有配置。若只测manual retry，应明确不声称覆盖auto retry。

可选加一项真实host绑定失败：用测试自有socket占住目标端口，startHost后断言 `server.bound===false`、错误已记录且资格false，随后释放自有socket。**不要要求最终mode必为offline**：准确574D的同步FAILED处理曾设offline，但startHost随后无条件写HOSTING；这项既有行为未被提案修改。

两轮应记录真实类名、候选SWF哈希、Session对象身份、每阶段mode/资格、真实网络事件和首个采集结果。`canSkipOfflinePresentation()==false` 只证明资格，不独自证明两组观察确实运行；需与下项分支行为检查、短联网可见效果回归共同使用。

## null／throw资格的最小分支验证

不要把私有 `skipOfflinePresentation()` 抽抄成独立函数后宣称产品覆盖。它是私有方法，但注入字段和自然Stage回调均公开可用。

最小可行组件使用**完整真实GameBridge类**及准确依赖，构造 `new GameBridge({stage:stage})`（无loaderInfo时refreshWorld的既有catch使world=null）；之后用公开 `loc/gg` 放入受控只读对象。room无grafon/firstObj，避免墙面工作；空远端、空已应用效果。受控actor提供 `childObjs/currentWeapon/throwWeapon/magicWeapon/loc`，武器提供带计数getter的 `kol_shoot`、owner/loc及空bullet；actor的vis getter可单独计数body观察。房间units可放一个sost=3的受控actor，既避免真实Unit转换需要，又允许武器观察。不要在完整运行游戏中替换真实gg。

在真实Stage ENTER_FRAME与RENDER回调分别清零、读取getter计数，依次设置资格：严格true、false、null、抛异常、返回1/字符串。true应不触及目标观察getter；false/null/异常/非true应与原始执行组有相同观察调用。仅检查资格函数调用次数不足以证明fallback实际执行。RENDER前先让原路径建立hostShots，再检查observeFinal；否则空表会造成假通过。组件每次结束保持无未捕获异常，并检查preserved路径仍被调用。此夹具方案尚未实现或运行，若构建闭包太大则使用已有真实GameBridge组件入口扩一项，不能改生产类可见性来偷测私有方法。

组件只覆盖分支和依赖，不替代原生画面。正式接受还需准确候选的离线本地枪械/能量/爆炸/近战/护盾/念力、首次联网后的对侧角色/武器/身体效果与原有房间流程；性能对照必须是真正574D对产品形态，不只用88CC内部A/B。已有诊断收益与计时限制见TIMING-REVIEW，不能给双人密集场景授予资格。
