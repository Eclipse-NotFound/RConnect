# 普通墙沿：可实施的最小结构版本方案

2026-10-23。仅源码设计，没有编译、AIR、产品修改或性能结论。输入：准确22 `build/m52/recovery-22/src`，准确ACC `build/m52/recovery-wall-surfaces-host-01/import/fe/graph/Grafon.as`，精确Location导出 `build/m52/recovery-raster-dependencies-01/scripts/fe/loc/Location.as`。本文件替代上一份报告中的“先建立干净alpha支持”方向。

## 决定

**保留实际像素协议；增加同一计数器产生的结构版本sv；只延迟非权威的结构前景绘制，普通弹孔仍即时预测。** 不同步一套独立alpha历史，不重放原生随机decal，不新增消息类型、等待ACK轮次或整房扫描。结构改动后的完整cell由房间权威决定。A版分房时，权威可能是加入侧。

这里明确选择一个保守视觉规则：结构变化涉及的40×40 cell是一个整体重置范围，旧sv下迟到的墨迹不能覆盖它；其他cell不受影响。若旧房已经不可绘制，或之后发生原生结构重绘，该范围内原先确认的弹痕也可能被新底图清掉，包括剩余墙体上没有直接被破坏的旧痕迹。**这不是“所有旧痕迹完全保留”**；用该有界损失换掉逐像素因果历史，保留墙体、碰撞、伤害与范围外痕迹。活动房原位破坏完成时读取真实最终图，仍在图中的旧痕迹自然保留。

## 1. 数据只增加到已有cell与预测条目

权威cell沿用`x,y,v,d`，新增：

- `sv`：最后结构重置的版本，初始0；普通墨迹只增加v，结构事件令`sv=v=++revision`。v、sv都使用同一现有计数器。
- `full`：结构基线已经完整，d必须包含该cell所有有效像素，含0；以后普通墨迹修改这份完整表。sv=0的普通墨迹仍可用原来的累计稀疏表。
- `needsNative`：权威此刻没有该房前景，尚不能给出像素；此状态**没有可发送的颜色表**，仅随受保护的交接状态/回执传元数据，等待新权威的既有原生绘制。
- `rebase`：已有合法完整像素，当前可以发送，但一次后续**权威自然drawLoc**需要用新地形底图重置该cell。与needsNative不同，它不阻止当前绘制或正常传输。

现有`queued/pending`中的每个cell也带生成当时的sv。pending的已发送seq和wire保持不变；结构更新后仅令旧sv预测不再参与显示。新sv的queued不能被旧ACK清掉。

普通房`cell.values`在非权威端只保存已确认数据；本机预测保留在现有pending/queued，直接显示及重放时叠加。这样无需新增第二套全图或逐像素版本表，也能让所有权威包/ACK统一使用`v`防倒退：新权威数据先入cells，再叠加同sv的预测。不得继续因保护了一个预测像素就不推进整个cell的incoming版本。

`decode`按报告/权威包/交接数据分开校验：sv/v必须有限、非负、精确整数且不溢出现有int计数范围；v>=sv。高sv只可伴随完整基线或明确needsNative，不能带新sv与旧values冒充完整图。引入新sv时替换整个旧values字典；不能留下包中未出现的旧索引。普通房取消solid门槛，仍保留房间边界、像素索引、单cell3200词、MAX_CELLS/MAX_WIRE等验证；large保持原路径。

## 2. 已有弹孔不需要反推干净支持

普通墨迹实际来自原生decal前后变化，它携带生成时的sv。权威仅在报告sv等于当前sv且基线有效时接受；否则返回当前权威cell/交接待绘制状态。owner当前alpha即使已是0，也不是拒绝同sv普通墨迹的理由，因此第134反例中的“普通擦0→晚到新色”仍保留last-arrival。

需要从RConnect初始化起监听**事件式**ordinary drawLoc、结构绘制和已有结构cell上的后续decal，以免“先单人破墙再联机”没有结构版本。这不恢复每帧离线采集，也不复制干净alpha图；首次普通墨迹可以直接sv=0。对已有结构cell，离线后续实际墨迹需要更新它的最终色，避免发送过期完整块。

不要把现有large的`rconnectWallBridge`永久设非null来实现这点：Grafon多处以它是否为null选择裁片工作。建议增加一个独立的ordinary回调引用，只承载同步通知，不在宿主保存房间历史；原large回调启停不变。网络leave只清传输游标/预测，当前世界的结构cell留到实际换图/换世界才释放。正常启动先加载RConnect、后生成游玩房间；热挂到已经生成且来源未知的图不具备本方案资格，不能把未知支持猜成已知。

## 3. 一条完整处理顺序

### 普通墨迹

原生before/after通知使用实际实例、矩阵和实际最终颜色，只比较有界区域；记录时立即固定sv。也可保留准确22的observe，但`receive/acknowledge`仍须在换sv之前先observe，不能把旧画面产生的差分在之后重新贴成新sv。

权威settle仅接受同sv的颜色，更新v，回执使用**权威当前累计cell**，不能继续原样回request.cells（现:448–461）。所有实际写入继续使用NativeWallColor.setter；不人为裁alpha、不创造非原生颜色。ACK的seq仍只用于退役旧pending；实际颜色统一按权威v/sv处理，旧ACK不得回退画面。

### 活动房结构破坏

1. 原生`tileDie:4309`选择资产并发出原有粒子。在它的`decal:4393`调用增加仅此次调用的结构标记；普通dyrka不标记。
2. **非权威普通实体墙**：保留物理/HP改变、粒子、地形报告；只跳过这次frontBmp的erase/draw/copyChannel。包括本地Bullet→Location.hitTile:2562的预测和TerrainSync.paintDestruction:246–257固定`tileDie(t,9)`的接收路径。普通decal不跳过。不要提前跳掉原有资产/随机帧选择而无意改动其它原生行为。
3. 权威仍执行一次原生结构绘制，结束后在有界cell集合取全部真实像素，置新sv/full/rebase并同步shadow。之后的observe不能把同一结构差分再次当普通预测上报。
4. 接收完整权威块时直接替换旧结构代数据，丢弃旧sv的视觉预测，保留新sv queued，按实际uint写图，不看接收侧alpha。地形仍由现有terrain路径处理；即使fast wall先到，迟到的接收tileDie也只生成原有粒子、不再用本机eraser破坏已确认像素。

**源/目的范围并集的答案**：本方案选择在目的端写入前拦住结构前景，因此目的端不同eraser的实际写入集合为空；不维护“先画错再修”的回滚表。若测试发现另一条未经过标记的本机结构写入，资格失败，不能用固定扩一圈遮盖。

## 4. 有限范围怎样取得

- 立即原位绘制范围：用`decal:4633–4673`实际选帧的eraser/color实例、原矩阵、filters和真实copyChannel目的矩形。复用`sceneDecalArtBounds:1079`、`sceneDecalTransformBounds:1108`、`sceneDecalAlphaBounds:1033`的边界规则；不要再new一个随机资产。向外取整并裁入bitmap后转40×40 cell。
- 以后自然重绘还会改变轮廓：`drawLoc:3740`调用`tileKontur`；Location:2399–2470只依赖8邻格，kont1..4的合法帧来自insKontur的0..4。故在破坏前，对目标及其8邻格，计算真实front material的textureMask/borderMask/floorMask合法轮廓帧范围、tileFront的vid/vid2、zForm偏移及material.F；取有界并集。这里“9格”来自明确依赖，**最后像素边界仍取实际资产，不能假设40像素或一格padding足够**。
- 可在Grafon增加一个无状态范围helper，访问internal arrFront（:136）；材质表在checkLoaded:3510从AllData构造，不读取另一房frontBmp。必须在`Tile.die:354`清front之前取旧信息。使用最大合法轮廓包围范围会多覆盖少量cell，代价是上述明确的旧痕迹丢弃范围可能扩大。
- 上述集合里的cell标rebase。权威下一次成功自然drawLoc，在重放RC痕迹前只读取这些cell的实际新底图，分配新sv/v，清rebase；其它cell照常重放。没有新的整图差分或全图扫描。
- 内层`drawKusok`错误catch:3807也会继续drawLoc；只有关键前景绘制全部成功才能基线化。未知/无界资产不得回退成整图扫描或假装成功，须使本候选资格失败。

## 5. inactive late-terrain与交接闭环

`GameBridge.inRoom:6158`只切world/land.loc，不切Grafon。旧房不可读时绝不能在当前别房bitmap结算。

1. TerrainSync.settle在原生hitTile/dieTile之前取得上述范围；实际地形结算照旧。相关cell推进sv，清掉其旧颜色，标needsNative/rebase。仅保存cell键、版本和标志，无临时整房图。它可随旧房已有checkpoint转交；无需旧主侧再回来。
2. 将`_wall.restore`拆成prepareRestore/finishRestore：**先安装导入元数据并禁止本机旧cells重放，再走已有terrain restore和自然drawLoc，最后完成wall**。准确22现:6317先tileRedrawIfDirty、:6319才wall.restore，必须改顺序，否则所谓新底图已经被旧记录污染。
3. 新权威在该房现有自然drawLoc成功后把needsNative/rebase cell基线化；读取实际新底图，旧结构代颜色不重放。同cell剩余墙上的合法旧痕可能因此消失，这是本方案声明的保守语义。非权威不能各自用本机底图解决同一needsNative。
4. 同房交接：RoomSync.commit:765 restore后、:790打包grant前，只把新完成的wall checkpoint回写到对应records.state.wallPaint；不重拍单位或全地形。否则follower会再次收到旧pending自行生成另一份图。
5. 分房交接：owner=true的接收端自行完成自然基线，之后按现有权威状态通道发送完整块；下一次已有own checkpoint回传给主机。owner=false收到未完成needsNative不能当成有效图放行。
6. pending结构房不能走fresh/retained/unchanged的“已经完全相同”捷径；它的地形确已改变，应走现有正常恢复路径，而非增加第二次重绘。普通房finish、large已有first-raster完成边界都必须先确保此房无needsNative再释放。角色、新旧roomKey/epoch/term验证沿用RoomSync:498/587–590/812。

恢复时保留导入的v/sv，提升本机revision至少到全部导入值最大值；不要沿用put把导入v重新递增的旧行为。换权威只清传输游标、预测和seen cursor，不能清结构代/完整基线；新term拒绝旧包。纯光照重绘不会新增结构标志；仅重放已有数据。

## 6. 可开始的实际代码子集与资格边界

先在隔离目录修改**完整生产WallImpactVisuals与WallSurfaceBridge**：真实cell字段、所有ordinary路径的solid过滤、真实settle/ACK/restore/预测数据分离、生产结构完成/待原生入口；复用现有BitmapData组件调用这些入口，不能另造一个玩具合并模型。随后接Grafon回调和TerrainSync/GameBridge/RoomSync的上述窄入口。大型场景的裁片/paintOrder协议不在本次改动内。

这次最小资格覆盖普通房普通实体墙的真实decal和tileDie，包括旧房迟到破坏与换权威。**加入侧gwall尚没有已有的权威建墙事务**：准确22搜索无gwall处理，TerrainSync.capture只报告原来p>0的损伤，不接受p=0→3；因此不能顺带禁用其本机画面并声称已同步。魔法墙mat=7/gwall先保持原路径且不把它的本机结构差分冒充普通ink；不授予本次墙沿修复的合格范围。若后续纳入它，需真实建墙动作的权威验证，这是独立玩法缺口，不是alpha算法能补齐的内容。

完整结构cell最多1600像素，现有累计snapshot/ACK可能使其后续每次墨迹携带整块；这是明确的候选成本，尚非实测性能回退。继续使用缓存packed结果和原MAX_WIRE/分包上限；不为省流把高sv基线截成不完整，也不在本轮扩增delta/ACK协议。必须测高破坏率持续开火，未过门槛不合入。

## 最小验收

已闭合设计：普通擦0→晚ink、结构后旧ink、不同接收eraser、旧ACK、导入版本、inactive交接、结构重绘、离线先破坏再联机。仍未实现/实测；魔法墙建造、其它模组直接写frontBmp、large裁片不在本子集资格内。

复用现有真实生产类组件检验：①第134普通擦除负例及真实22点；②不同sv旧ink/旧ACK不复活、同sv晚ink仍接受；③结构强制块含全部0且缺基线拒绝，新sv queued不被旧seq清除；④真实mat1..6及fake破坏，目的端粒子/伤害保留且前景无第二eraser；⑤同Bitmap重绘、leave/rehost、same-room grant和分房新owner，含needsNative/版本最大值/失败绘制；⑥短时火星仍单独走效果事件链，不将像素测试通过等同于火星已修复。先过组件和原生正确性，再比较高射速与破墙流量/帧时，最后才能谈部署。
