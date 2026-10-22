# recovery18 弹痕快速增量：只读可行性审查

2026-10-22。只读准确18及既有14采样，没有修改生产、制作候选、启动 AIR/JVM 或改变验收条件。

**结论：直接把 updates 的累计 values 换成 queued/dirty values 不成立。** 它会破坏预测后的补修，还会改变大图延迟绘制的先后顺序。严格保持现有画面和修复时机的增量协议在原理上可行，但需要接收端独立保留权威累计基线，重建原完整 cell 后再走原 put；这已不是单函数微优化。现有采样也不能证明这种协议能节省总编码量，应先证明真实发送顺序存在足够的“仅快速发送”机会，否则停止这个方向，不能为了压低 updates 栈把工作挪到 snapshot。

## 当前实际职责

| 状态/路径 | 准确18用途 | 不可直接复用为快速发送脏表的原因 |
|---|---|---|
| `cells[k].values/v/wire` | 该房所有累计弹痕；wire是该版本完整格的缓存 | snapshot、checkpoint、重绘和重访都需要完整内容；不能用delta污染wire |
| `queued[k].values` | 自己实际产生、尚未放进请求的像素 | 参与预测保护；report会移出，不能随fast广播消费 |
| `pending` | 已发请求、尚未收到对应seq ACK的不可变批次 | 保护更早的预测像素；同期间queued还能保存新的覆盖色 |
| `receipts[peer]` | 房间权威方对请求去重、回放同seq ACK | 不是宿主累计广播的接收确认 |
| `incoming[k]` | 成功完整应用的权威格版本 | 有预测保护时故意不推进，允许同版本累计包之后补修 |
| `sent[k]` | 已交给TCP发送路径的快速累计格版本 | 不是对端已经接收、解码或完整应用的ACK |

`captureCell:253–275` 和大图 `surfaceChanges:56–78` 同时维护累计cells和本地queued。`settle:445–458` 接受加入侧真正改变的像素，合入宿主累计格后返回原请求中的已接受像素。ACK没有重新随机绘制原生弹痕；`acknowledge:460–466` 先观察新本地变化，再清旧pending，再应用receipt并保护新queued。上述顺序必须保持。

`updates:472–488` 挑选版本变化的格，调用完整 `packed`。`sentUpdates:492–500` 只在广播后且存在client时更新游标。`snapshot:505–520` 按原64格/48000字符限制轮转累计格；Session约200ms才有一次机会，某一格的修复延迟可以超过200ms。checkpoint保持完整。这里不能把“慢快照还在”当作快速包可以任意漏状态的理由。

## 两个确定反例

### 1. 版本推进会让漏掉的权威像素再也补不回来

假设该格完整接收游标为10，本地pending保护像素p：

1. 宿主累计v11含 `p=A`。加入侧跳过p，incoming仍10。
2. ACK到来，pending清除；本地p仍可能不是A。
3. 宿主v12只新改q。若快包现在只含q却仍走原put，当前没有保护，incoming被推进到12。
4. 慢snapshot的完整v12因 `v<=incoming` 被跳过。若本格不再变化，p永久不修。

只增加“完整游标/fastSeen”或base字段可以避免永久漏修，但仍不完全保留现有时机：旧累计fast v12会在第3步立即修p，只含q的delta则要等轮转慢snapshot。相同问题出现在新peer没有基线、部分批次被拒及重访/所有权改变之后。

### 2. 大图的等色写也是有效操作

`put:414–418` 对每个接受的权威像素更新paintOrder，即使ARGB没有改变。`surfaceChanges:66–70` 用它拒绝出生较早、却迟到才第一次画出的原生mark；`WallSurfaceBridge:70–74,81–113` 证明mark出生序和实际raster可分离。

反例：已知p旧paintOrder=10；本地mark在order50出生但尚未raster；宿主快包因q变化而再次带上累计p，旧实现把p的顺序更新到51以后，随后拒绝mark50对p的覆盖。只发q则没有这次屏障，mark50可以写p并产生新报告。ARGB当前相同不表示省略这次写入等价。

不能简单给本地整格所有索引加同一屏障：其中可能有宿主尚不知道的本地预测像素，原累计包根本不包含它们。只比较最终颜色也漏掉这个反例。普通frontBmp没有paintOrder支路，但仍有前述快速补修时机差异；把delta限定普通房只能避开第二个反例，不能消除第一个。

## 若继续研究，唯一建议保留的行为定义

发送端只压缩“自上次成功交给同一有序连接以来实际改变的像素”，接收端先恢复出**宿主当时的完整累计格**，再调用与18相同的put。这样保留预测跳过、ACK顺序、同版本补修、大图等色paintOrder和原生bitmap重涂，不把delta当完整状态。

所需最小协议责任如下，并非已实现或已通过的方案：

1. 独立的发送dirty表。累计cells及其wire保留；queued/pending/receipts完全不承担新职责。所有真实颜色修改路径，包括本地capture、大图surfaceChanges和宿主settle后的put，均须记录dirty。读取updates不消费；发送后仅清除该次选中版本，选择后出现新修改必须保留。透明ARGB=0是有效更新，不是删除。
2. 明确的full/delta标记和base版本。首个基线、房间/authority term变化、新peer等使用完整格；不能把旧客户端忽略的未知字段悄悄当能力支持。未协商双方能力时继续现有累计包。无需改WallCellCodec的像素格式或降低发送频率。
3. 接收端的**权威基线**独立于当前显示cells。即使本地保护拒绝显示p，权威基线仍记住宿主给出的p；之后delta只改q，也可重建包含p的原完整格。仅拿当前cells补齐会混入本地预测颜色，因此不是等价重建。完整接收游标仍按旧put规则推进，不能用“基线已更新”替代“像素已应用”。
4. base链断裂时不得猜缺项，也不能把较新的delta抬成完整版本。重复/倒序包不回滚基线；同版本full仍能在ACK后重试显示。TCP本身有序不等于跨epoch、peer重建、解码拒绝后永远有可用基线。完整snapshot/checkpoint持续保留，其频率和轮转不变。
5. 正常格也把重建后的完整words交给原put，大图亦然。不通过删除等色写、跳过像素比较、弱化paintOrder或延后补修换收益。若重建本身抵消了编码节省，应放弃。

这是额外的协议状态，不建议再加通用快照缓存、全房历史、每像素重传计时器或新的调度框架。接收权威基线的内存必须计入：当前cells是带本地预测的累计历史，不能无条件共享可变引用。每格最多1600像素，但房间累计格数并不受单包64格限制；checkpoint的1200项解码上限也不是运行时全房内存上限。若设缓存预算，不能静默驱逐基线后继续接受依赖它的delta，必须有明确的累计回退。这个代价是继续前需要证明的部分。

## 生命周期必须原样保留

- `discard:277` 在墙被毁后清cells/queued/incoming/sent；新dirty和权威基线也清，旧弹痕不能填回破墙。旧pending的语义仍按原solid检查和ACK处理，不顺便改请求生命周期。
- `finishReports:309` 依赖原pending已在有序TCP上，继续排出queued；不能因快速delta存在就少发这些末尾请求。RoomSync.report仍只接受同roomKey/epoch/term，旧房settle先于checkpoint。
- `restore:532` 是整个状态替换，`roleChanged:573` 清传输游标但保留累计marks，`reset:578` 清整场状态。新基线和dirty在对应位置失效；死亡/读档/新Location身份不能沿用旧版本链。
- 新peer不能共享“原peer已收到”的假设。现sent是房间级游标，不是per-peer ACK；已有正式双人范围下也需要在新握手/房间grant后明确完整基线。此提案不扩为稳定重连或多人支持。
- 普通前景重绘和大图chunk重建仍从累计cells恢复；first-raster pending继续拒绝读取空bitmap。不得为了生成delta提前绘图或读取scratch。
- 两侧同像素覆盖、pending与queued同时持有同索引时，ACK继续保护较新的queued；基线只记录权威颜色，不替玩家本地请求决定成功。

## 收益不能从当前调用栈直接推出

只读重算14原始 `a6a7e27789/host.log`：2318 CPU样本，WallCellCodec.pack包含499，packed包含500；packed中437来自updates、63来自snapshot。437分布于开火phase1/5/6为82/166/189；63全在phase0。inclusive updates总440另含选格工作，不能把440和437混同。

Session `1063→1066→1088` 在同一次onTick先broadcastWorldState，后检查200ms快照期限。旧fast已经构建 `cell.wire`，随后snapshot可直接复用。因此437来自updates不代表437都是慢快照之外的额外编码。长帧下每个发送tick都可能跨过200ms：简单delta会变成“压缩小delta，再压缩同版本全格”，反而增加一次工作。

现有profile仅含帧窗口、CPU栈和分配量，没有每格fast-only/同轮snapshot、累计/脏像素数以及复用次数。它能证明函数值得调查，不能证明18的delta收益。14样本也不是18的新采样资格。

若要进一步证伪，应复用当前原生密集驱动与已有采样入口，输出有界累计计数，不新造框架：每格版本的dirty/cumulative数量、fast-only编码、同轮慢快照复用/重编、基线重建数量/峰值内存。保留原7阶段、全部像素、真实开火和性能门槛。可研究在发送前已知慢快照到期时继续用旧累计fast，以保留同轮wire复用；但不能提前计算并固定原来在broadcast之后判断的期限，从而少发一次快照。跨过期限的同轮双编码仍须如实计入。

净收益要求包括发送端累计+delta全部编码、接收端完整格重建/put及内存，不能只展示updates自己的耗时下降。若真实工作负载几乎没有fast-only机会，或接收端重建/基线内存超过可接受成本，就停止，不进入又一轮局部微优化。

## 最小反例验收表（尚未执行）

| 场景 | 必须与18累计实现核对 |
|---|---|
| p受保护→v11到达→ACK→只改q的v12 | p在同一个快速包时机补回；不能仅等待慢snapshot最终一致 |
| pending色A、更新queued色B、旧ACK | ACK不盖B；权威基线及完整接收游标分别正确 |
| 两侧同/不同像素、多格达到64/48000限制 | 色值、顺序、批次原子性、轮转与未发送dirty保持 |
| 透明色0、uint高位、反复改回旧色 | 每个像素精确，未把0或等色当缺失 |
| late mark50、累计权威屏障51、q-only变化 | 大图paintOrder及最终实际chunk像素与18相同 |
| 旧/重复delta、同版本full、base缺失、非法批次 | 不回滚/不推进错误完整游标；无部分应用或伪ACK |
| 无peer、发送失败、读updates但未发送、选择后新写 | 不丢dirty，不把sent当接收ACK |
| 墙毁、死亡、重访、权威转移、新peer、读档换Game | 不复活旧痕迹，不沿用旧版本链，累计入口保持 |
| 快包和慢快照同一tick、期限在广播中跨过 | 不改频率；全部编码与重建成本纳入比较 |

## 输入指纹

全部位于 `build/m52/recovery-18/src/rconnect/`：

| 文件 | SHA256 |
|---|---|
| game/WallImpactVisuals.as | d8a88d98331aa8ab62b093ed36066f8ca5eb3d348a4f863474580e7fddb7d7bd |
| game/WallSurfaceBridge.as | b7f58ccb994f30f86041249c56730831345e95742127814e1afa77bd44d69ad1 |
| net/WallCellCodec.as | 4d0bb10dbe60227f167fad2d0c48fa3e6dd22b114f496084ba651ca84761dc8c |
| core/Session.as | e699b9c5a02799367bba8afd924d450d064cab3f0a5e9a36ea7d400b378b10ba |
| game/GameBridge.as | 3fe9bb83a16a57300e733806cddbe74ce55bcaf323bec15554814f4714eba967 |
| core/RoomSync.as | c2e68fe658a81be4b3ceb285daf453ca57b9d4a5895e80720dd629c374e3f85e |
| net/TcpLink.as | 93aafc0aad7a410107f2eea2cee288d9366c6cacce289c5b2552dc95140e350c |
| net/HostServer.as | fdb0407c39975b25d1591611e6db5cd9f3b349e2611568687c885e042424b748 |

14原始host日志指纹 `35d83e706a362c9d81eef9cbfc675276a215ac0cacc85fe6a480be2ab94fb3e7`；既有解析 `experimental/recovery13-density-review/profile-14-01.json` 的结果指纹为 `816e4c4cca8e5a4bad97457cf3337945ee70450ca0d2d61c0da9f53e4323ac32`（这是它所绑定result.json的SHA，不是profile文件自身SHA）。本次没有改原日志、原失败或冻结驱动。
