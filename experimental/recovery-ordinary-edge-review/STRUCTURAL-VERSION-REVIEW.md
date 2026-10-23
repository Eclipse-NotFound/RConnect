# 普通墙面结构版本方案：独立审查

2026-10-23。仅源码与协议设计审查，未修改产品、编译、启动游戏或部署。输入是准确 recovery-22 的 WallImpactVisuals / TerrainSync / GameBridge / Session / RoomSync，以及 ACC Grafon；完整输入指纹沿用同目录 `structure-inputs.json`。下文行号指这些冻结输入，不指后来实现。方案作者为 `early_overlap_review`；此次直接核对了其 `sv / needsNative / rebase` 草案，IMPLEMENTATION 尚待落盘。

## 判断

**可以继续收敛结构版本方向，但当前不能算实现通过。** 普通弹孔携带生成时已确认的结构版本 `sv`；当前房间权威仅接受同版本墨迹；实际结构变更推进版本并提供完整、包含透明像素的最终小块；接收端照权威结果写入，不再用本地 alpha 二次筛选。这能够区分“普通弹孔擦成透明”与“墙体结构已经变化”，避免此前第 134 项的相互矛盾。

这里的权威是当前房间执行方，分房时可能是加入侧。沿用现有 roomKey / epoch / term 和稀疏 cell，不必新增房间级像素历史或另一套传输状态机。Grafon 只提供同步绘制事实，网络裁定仍在 RC。

作者已同意下列闭环必须进入实现方案；这只是设计确认，不是运行证据。

## 必须写实的协议规则

1. **版本不混用。** `sv` 表示结构代，`v` 表示权威最终像素的修订。普通预测不能自己推进已确认的 `sv`。接收、ACK、恢复使用同一版本判断；导入 checkpoint 后，本地发号器必须至少大于已导入的所有 `v/sv`，不能恢复后从较小计数重新发号。旧 term 在现有 RoomSync 外层拒绝，不用 cell 版本代替房间身份。
2. **结构包必须完整。** 接受更高 `sv` 时不能把未出现的旧 `cell.values` 留下来。使用明确完整标志或严格验证有效 cell 范围的所有像素，零值也要在包中。未完成原生基线的 `needsNative` 不得借旧 values 伪装成新版本完整图，也不能把空 d 当透明图。
3. **ACK 只能回权威结果。** 现有 `settle:455–461` 是 put 后原样回请求，`acknowledge:469` 不检查版本；这两处不能保留。旧 ACK 可以结束对应旧 seq 的等待，但不能回滚已接收的新结构，也不能清掉新结构下生成的 queued。已发 pending wire 保持不可变；预测保护按当前 `sv` 筛选，不再无条件保护旧版本像素。
4. **快通道不依赖地形包先到。** `Session:1223` 可单独广播 wallPaint，`GameBridge:3483` 可单独上报普通痕迹。必须覆盖 wall 先到、terrain 先到、旧 ACK 最后到的次序。非权威只延迟 tileDie 的 frontBmp 写入时，也必须覆盖 `TerrainSync.paintDestruction:253` 固定调用 tileDie(t,9) 的路径；颗粒、伤害、碰撞预测不能随之被停掉。
5. **原生通知之后同步 shadow。** 结构完整像素落入 cell 后，更新对应 shadow；否则下一次 observe 可能把同一次结构差异再登记为普通墨迹。ordinary / large 需显式分支；现有 large 路径及 Location / Bitmap 身份检查不得顺手放松。

## 三个真实控制流反例

### 1. pending 导入晚于原生重画

`GameBridge.restoreCheckpoint:6317` 先 `tileRedrawIfDirty`；后者 `3523` 在 redrawLoc 后立刻 `_wall.redraw`。`6319` 才 `_wall.restore` 新 checkpoint。若仅给旧流程追加 needsNative 字段，首次自然底图已被本机旧 cells 重放污染，或者生成通知早于 needsNative 导入，导致待完成项永远没有获得正确底图。

最小修正是明确 prepare / finish 的边界：在既有 redraw 前安装此次 checkpoint 的 wall 元数据并阻止旧房 cells 重放；原生前景真正成功后，由权威完成待基线化小块；再完成恢复及放行。不要为修这个顺序额外绘制一次整房。retained / fresh / unchanged 快路不能默认一定会走 drawLoc。

### 2. 权威完成了像素，但 grant 仍发送旧 pending

`RoomSync.commit:765` 恢复 `mine.state` 后，没有回写该 state；`790` 随后直接打包 `theirs.state`。双方进入同房时，这两者可能是同一个 records 项。即使权威的 WallImpactVisuals 已在 drawLoc 中完成 needsNative，grant 仍可能携带原 pending。若接收侧据此自行取底图完成，就变成两方各自裁定最终像素。

最小修正是在恢复完成、grant 打包前，仅更新对应 room record 的 wall checkpoint。非权威不得自行解决 needsNative。未完成项不能通过既有免重画路径放行；它随房间 checkpoint 保存，直到有合法权威和真实原生底图，而非被序列化时丢弃。

### 3. 旧房的真实图像不存在，且重画会影响邻格

`GameBridge.inRoom:6160–6162` 只暂换逻辑 Location，不切 Grafon；`WallImpactVisuals.front` 对不匹配的 Grafon.loc 正确返回 null。`RoomSync.report:813–825` 允许离房前发送的最后一批报告在这个上下文结算。inactive 的 `Location.hitTile:2560` 不执行 tileDie；不能为了凑全色读取当前新房 frontBmp。

旧 `front` 必须在 hitTile / dieTile 前取得：`Tile.die:354` 已清掉它。还不能只考虑死亡 tile 本身：`Grafon.drawLoc:3740` 会调用 `Location.tileKontur:2399`，后者依据八邻格更新轮廓。作者已撤回早先“rebuild 只算水，因此没有邻格变化”的推断。

草案选择保存有界 needsNative / rebase 元数据，在既有自然 drawLoc 完成时基线化。若新增范围 helper，必须包含真实材质 mask、轮廓帧、zForm、tileFront/vid/vid2、material.F 以及坐标变换；不能把猜测的一圈 padding 包装成正确范围。以九格的合法轮廓帧求保守上界属于有证据的候选，但尚未验证。drawLoc 内还有材质绘制异常后继续执行的 catch（3807、3819）；部分绘制失败不能被当成正常基线的资格证据。

## 明确的视觉与成本取舍

- **整 cell 的 sv 会丢弃同 cell 内仍合法、但持旧 sv 的晚到弹孔。** 即便弹孔位于本次结构实际未覆盖的位置，整块版本也会拒绝它。这是保守取舍，不是“完全保留原有弹痕”。
- 作者拟区分 `needsNative`（尚无合法像素，禁止广播）与 `rebase`（已有合法像素可发送，下次权威自然重画需重新基线化）。若 rebase 用整个 cell 的原生底图替换原值，结构未实际触及的已确认痕迹也可能被抹掉；九格全部合法轮廓帧的最大范围会扩大受影响范围。必须明写此行为，不能在 helper 内默默决定；本审查没有将其报成实测故障，也未认可“原有痕迹完全保留”的表述。
- 结构后的 cell 若长期保存 1600 个像素，现有 `updates / snapshot / packed` 会让此 cell 后续一次普通命中也累计打包整块。MAX_CELLS / MAX_WIRE 仍须生效，不能新版本缺基线，也不能绕限制。持续破墙、高射速条件下的带宽、编码时间、队列延迟和内存属于新增成本验证，当前没有“已回退”或“性能无损”的实测结论。

## 最小验证集合

1. 复用真实 WallImpactVisuals：普通 erase→同 sv 晚到 ink，最终 bitmap / cells / ACK / 再广播同 uint；不能让测试 helper 替产品判断合法像素。
2. 结构变更→旧 sv ink；全透明和部分透明；所有交错次序均不恢复旧结构。
3. 新结构已接收后旧 ACK 到达；新 sv queued 保留；旧 pending 结束；随后普通报告正常推进。
4. authority checkpoint 携高 v/sv 导入低计数实例，换房/换权威后新值仍单调；旧 room / epoch / term 拒绝。
5. 真实 `TerrainSync.settle` 触发 inactive 旧房变更：新房 bitmap 不变；pending 经过 checkpoint、真正 drawLoc、grant 后才成为完整像素，非权威没有自行基线化。
6. 同 Bitmap 自然重画、retained 快路、gwall 新增/到期：声明的弹痕保留取舍与实际一致，无空 d 清屏、无旧值复活。
7. 原生不同 tileDie 变体的最终区域一致，包含 eraser / color / copyChannel 的真实写入范围；恢复原先漏掉的 22 个墙沿像素且不凭碰撞空格清掉它们。
8. 结构小块持续累计后执行原火力与帧间隔检查，记录包大小/积压；组件通过不能替代该项。

当前停止点：方案作者准备将这些规则写入 IMPLEMENTATION；本审查不授予候选、双人运行或部署资格。安装版和各冻结测试输入均未改动。

## IMPLEMENTATION 定稿复审

已只读复审 `IMPLEMENTATION.md`，SHA-256 `5FEC05FC443E1082860DA0BE0C65F3BA2A7B546C374D232AF9AE4B9257ACBC37`。它已收敛 restore/grant、版本、完整块、预测分离与保守丢弃语义；可以开始隔离的生产类组件实现。准确22没有 gwall 的权威建造事务，因此此版将 mat7/gwall 保留原路并排除资格，不能把视觉补丁变成建墙玩法重构。此收窄不影响普通实体墙的审查。

仍有三处具体接线要求，已直接反馈作者；无需为它们新增消息类型或重做整个协议：

1. **所有原生破坏的旧 front 采集入口尚缺。** 文档 §5.1 的 TerrainSync.settle 前置采集只覆盖报告结算。本机权威子弹、爆炸、敌方攻击可直接走 Location.hitTile/dieTile；到 Grafon.tileDie 时旧 front 已被清除。须在准确宿主 Location 的两处 `param1.die()` 前接同一只读范围通知，或提供经证据确认覆盖所有这些路径的等效入口。作者确认接入清单必须包含 Location，不能事后按 mat 猜旧材质。
2. **累计 ACK 可能比合法报告大很多。** 多个稀疏 cell 的报告原本小于 48000 字符，但返回 owner 的完整累计 cell 后可超过接收 decode 的 MAX_WIRE，造成整个 ACK 被拒、pending 不再前进。必须明确实际有界策略。现有 WallCellCodec.MAX_TEXT=13340；不新增 ACK 分片的一种保守办法是按累计返回最坏长度限制每批，此上界下 3 个 cell 为 40020 字符。若用有界 ACK 子集+既有权威补发，则也必须实现缺席 cell 的预测退役/重画语义。不能只写“保持 MAX_WIRE”而无代码路径。
3. **丢弃旧版本 ACK 后仍要重画退役预测。** 例如更新 v=2 已写 confirmed cells，但画面仍叠着同 sv 的旧 pending；随后 ACK(v=1) 被正确拒绝，同时该 seq 结束。如果只删除 pending、不按最新 confirmed cells + 剩余 queued 重合成触及 cell，画面仍残留已退役的旧预测。此重画只需覆盖该批 cell，不需全图操作。

最小产品文件：`WallImpactVisuals.as`、`WallSurfaceBridge.as`、`TerrainSync.as`、`GameBridge.as`、`RoomSync.as`，以及准确宿主 `Grafon.as` 与 `Location.as`；Session / WallCellCodec 原则上可不改。若实际接线必须修改其它类，应给出具体消费者原因，不能预先扩展。

隔离实现至少保留：第134普通erase→晚ink失败断言、真实22点；旧sv/旧ACK不复活；完整0及缺基线拒绝；高版本恢复；inactive旧房不写新图；同房grant不传未完成状态；累计ACK最坏包大小；旧ACK退役后最终bitmap与confirmed+queued一致。它们必须调用实际生产入口，不能由测试helper先做合并/分片/范围裁定再称产品通过。原生 mat1..6/fake、真实跨房及性能仍待根后续验证。
