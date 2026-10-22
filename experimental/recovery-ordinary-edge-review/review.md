# ordinary-wall-edge 独立只读审查

审查冻结 `inputs.json` **7a14b2a2…7b98**、生产 `WallImpactVisuals.as` **4af3569a…7205**；准确22基线，仅一生产类。26项输入、13份组件源、overlay与handoff逐项哈希相同。声明132项是85项旧组件+47项新增，**本审查没有编译或运行它们**。详细指纹在 `evidence.json`。

## 阻塞：同像素先擦除、后确认新色，会确认成功却不画

候选 `put:438–446` 先更新 `cell.values`，然后用**已受墙痕修改的当前Bitmap alpha**判断能否写入非solid格。alpha为0时拒绝后来的非零色，却在 `settle:478–480` 将整个cell放入ACK；`receive`还会推进incoming版本。逻辑值已是新色，但真实像素仍是0。

最小反例可复用现有 `edgeRoom/hitEdge`，不改uint比较或消息顺序：

```actionscript
// owner/client 均有天然前景边缘 (38,0)=0x7e39392f，phis==0。
// client 先在自己的未擦除底图上发生真实新命中并生成pending请求。
hitEdge(clientWall, clientRoom, 0x7e14140e);
var request:Object = clientWall.report(clientRoom, false);
// owner 此时已经接受一次同像素透明擦除；这也是合法当前协议状态。
ownerWall.receive(ownerRoom,
    [{x:0,y:0,v:100,d:RoomCodec.pack([38,0])}], false);
// request 是对侧较早绘制、稍后到达的命中；保留现有最后到达合并规则。
var receipt:Object = ownerWall.settle(ownerRoom, "client", request);
clientWall.acknowledge(clientRoom, receipt);
// 现候选：owner实际=0，client实际=0x7e14140e；
// owner checkpoint 的逻辑38也已经是0x7e14140e，ACK未拒绝它。
// 应增加“同像素最终实际值相同且与已确认逻辑一致”的断言。
```

这是根据真实完整类路径可推出的**合法输入/合并契约反例**，尚未执行AIR，也不是这次22点丢失的已观测根因。`settle:474–477`仍写着同像素最后到达决定结果；候选新条件改变这一语义。之后如果真正重建地形底图，replay可能重新显示新色，但这不能消除此前已确认而双方显示不同的窗口。

当前116/117擦除index38、涂色index39，验证的是不同像素；122–124仅非零颜色互换；128仅拒绝旧版本。它们均没有覆盖此反例。README明确允许logical/visible不同，只在**天然或毁墙后确实不存在的前景**可合理成立；不能将**先前同步墙痕自己的擦除**也当成天然不存在。

最小修复边界是区分这两种“0”的来源，并新增同像素反例；本审查没有设计新的ownership系统，不建议改ACK契约或放宽严格uint。

## 原生可达性：copyChannel保存的是擦除后的alpha

准确ACC宿主 `Grafon.as`：

- `dyrka:4427–4429` 材质2/4/6且tip2/3的随机分支提供 `bullet_dyr`；`:4480` 木材tip1–3提供它；`:4555/4568/4581` tip15–17且非param5分支提供 `plasma_dyr`。
- `decal:4638` **先**用param1执行 `draw(...,"erase")`；`:4669`才保存现有alpha；`:4670`画param2颜色；`:4673`恢复保存的alpha。
- 因此“copyChannel保留alpha”不等于“保留进入decal前alpha”。擦除层能降低alpha；在擦除资源有全不透明覆盖的像素处可将原非零alpha变0，后续涂色不会把它补回。两侧分别绘制后的跨网络先后顺序可以与本地时间顺序不同。
- **实测边界：**本次普通房215270505b四例(lmg/plamg双向)所有源baseline→final均未出现alpha下降，数据见evidence。这些不可破坏靶用例不能证明这里的擦除支路真实运行过；此审查也没有读取bullet_dyr/plasma_dyr资源的逐像素alpha。因此“具体原生武器这次已擦出0”仍未实测。合法输入契约缺口不因本轮靶未触发而消失。

## 其余范围核对

- 原22点负例：取消ordinary观察中的solid过滤，可使真实邻格前景进入原captureCell；源色仍来自copyPixels/getVector差异，最终仍NativeWallColor.setter，没有随机重播、协议转换或容差。
- 非solid alpha支持：能阻止完全空底图被旧非零墨迹制造opacity，透明写0可继续保留；但目前支持依据被墨迹修改过，导致上述阻塞。毁墙后还保留全体逻辑稀疏值，仅抑制可见输出；没有原本discard释放，不能声称销毁后状态清理完全同旧版。
- 队列：queued/pending/sequence/protectedPixels算法、decode限额、预测跳过优先于写入、旧版本过滤位置未改。新retainedCell将ordinary合法空碰撞格纳入报告/ACK/checkpoint；这本来是补边缘必要变更。阻塞来自ACK承诺与最终输出不一致，而不是消息包改写。
- 共享Grafon：新增ordinary学习受`g.loc===loc`约束；front仍验证当前房身份与pending首绘，旧房不会直接绘入外来bitmap。未知旧房暂存逻辑，回到该房才解析实际ordinary/large；这一点比拿共享外来sceneLarge直接分类更稳妥。未知最终large的非solid数据由既有large replay/捕获solid规则过滤，未扩large外缘支持；仍需保留真实分房/重访回归。
- 大图：surfaceChanges和WallSurfaceBridge.replay仍检查solid，surface paint/缓存类字节未变；已知large的retainedCell等价原solid。新增ordinary类型标量由restore重建、reset整体释放，没有额外全图shadow。

## 增加的成本与上界

没有扩大`region`矩形，也没有每帧新增全房alpha扫描，但原候选区域里的空碰撞格由一次shadow.copyPixels变成完整captureCell：两scratch清零、两次copyPixels、compare，存在差异时再分配difference位图/Vector并存稀疏索引。不能称为零开销。

普通48×25房间最多1200个cell，每cell1600索引；墨迹/queued覆盖同索引而非追加每发历史，所以单room逻辑像素域最多1,920,000。相对旧版，天然空格边缘与毁墙后零色/不可见逻辑会继续占用这套域；没有长期字节淘汰，200ms累计仍可能反复带这些cells。pending单批64cell/48,000字符及word缓存128条/131072words/524288chars均未放宽。普通一个shadow仍约7.68MB；未新增全图副本。真实增加多少空cell扫描与累计状态尚未实测，不能据组件说明整体性能。

## 交付状态

先不合并当前源；上述同像素反例已发根与实现代理。只写本独立review目录，未修改候选、冻结结果、生产或公共工具，未编译/AIR。一次含只读reference搜索的组合命令被本地hook拒绝为read-only-reference，未执行；随后仅对RConnect自己的JSON完成alpha统计，未修改护栏或参考文件。
