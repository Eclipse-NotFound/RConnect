# 补充：最小结构通知是否可行

结论：**原生普通房路径可收窄到少量Grafon通知，但当前桥不能原样直接接用。** 最小需要覆盖tileDie、decal、drawLoc、gwall四个方法；不需要给碰撞格另建归属系统，也不应克隆整张前景。当前只判断可行性，没有实现或运行。准确ACC Grafon、22 RC与精确宿主Location导出指纹见structure-inputs.json；Spell/Box/Tile/World调用导航来自1.02公开参考，不冒称本轮单独二进制回读。

## 同一次实际擦除可以复用

Grafon.rconnectWallNotify:698–703已有kind、Grafon/Location、bitmap、sceneX/Y、affected、mark、token、clips，无监听即return，异常隔离。可复用这个载体加ordinary专用kind，以临时payload传实际实例/矩阵，不改网络包。当前WallSurfaceBridge.onNative:71硬拒绝sceneLarge非true，必须在原large逻辑前明确分流ordinary事件，不能直接删除身份或场景校验。

tileDie:4309–4393选的是Class；实际实例在decal:4633创建，4636选择原随机帧，4638才以this.m执行erase。故tileDie调用decal期间仅标记结构事务（保存旧值、try/finally恢复）；实际erase处同步提供已选帧的MovieClip与原矩阵数值/clone。监听只在回调内消费，不保留长期clip引用、不再调用dyrka/tileDie/decal、不再抽随机。

对既有稀疏支持块，用同一实例、帧、缩放/旋转/平移、smoothing=true在小块上执行原生erase规则，可更新结构alpha。范围必须取实际实例含filter边界后裁剪到bitmap，不能把固定2px或96px当结构清除真值。不能从front前后alpha比值反推结构清除：旧普通弹孔可能已把front擦为0。

普通decal的before边界也必需：首个受影响小块必须在普通墨迹/擦孔修改前取得支持alpha。只在tileDie首次读取当前front，仍会把旧弹孔误认结构空洞。无需每帧全房扫描，但必须明确记录起点。

## 必须覆盖的方法

| 方法 | 最窄职责 | 为什么不能省略 |
|---|---|---|
| tileDie | 仅在自身decal范围标记结构擦除，finally恢复 | Location破坏与RC接收侧paintDestruction均汇入；普通dyrka不是结构消失 |
| decal | ordinary before建立小块支持；实际eraser选帧后传同实例/矩阵及结构标记 | 避免随机重播，区分普通弹孔和结构消失 |
| drawLoc | ordinary成功生成原生前景后、RC墨迹重放前通知重建代际，刷新已有小块 | scenePrepare:444–456只在尺寸变化时换bitmap；同尺寸重绘复用旧对象 |
| gwall | 使用实际tileGwall实例和矩阵通知新增结构，或更新其影响小块 | Spell先设phis=3，再直接绘前景；没有drawLoc/新bitmap边界 |

drawLoc完成通知不能无条件放在catch之后：当前catch报错后仍继续末尾代码。必须只在成功完成前景的路径通知；异常不把部分底图标为可靠支持。共享Grafon的loc、bitmap、ordinary状态、代际都需匹配；清理仅针对自身缓存/监听。

sceneRestoreMarks:1208对ordinary立即return，末尾raster仅服务large，不能复用为ordinary重建完成通知。原large流程和late-mark次序保持不变。

## 其他结构入口核对

- 精确Location hitTile:2512/2562、dieTile:2583/2607：活跃房破坏走tileDie；非活跃不绘，之后激活走drawLoc。gwalls到期同样走dieTile。非致死伤害走dyrka，不应削减结构支持。
- RC22 TerrainSync.paintDestruction:246–257直接调用Grafon.tileDie，因此该通知覆盖接收侧原生碎裂。其余结构字段/checkpoint置dirty，GameBridge.tileRedrawIfDirty:3520先world.redrawLoc再_wall.redraw，是明确重建→墨迹重放顺序。
- Spell.gwall是必须额外通知的直接新增；其到期仍走dieTile。不必改Spell/Location。
- Box.initDoor/setDoor/die改变碰撞和对象vis；initDoor清Tile.front，没有直接写frontBmp。不能因为门的phis开关就清除前景支持。初始化后的前景由drawLoc建立。
- 出口hole和初始化只改tile逻辑、不直接写frontBmp，激活/重访由drawLoc绘制。灯光allon/alloff明确world.redrawLoc，同bitmap重绘通知覆盖。
- drawKusok的front绘制调用仅在drawLoc/sceneDrawSteps内；ordinary重建通知统一覆盖。paint只画backBmp，drawWater只画vodaBmp；SATS是缓存视图，不是结构修改入口。
- 1.02原生源码中的frontBmp写点集中Grafon，外部结构绘制调用限上述Location/Spell/World。没有由此审计全部外部模组的public bitmap写入；未知直接写应视为支持不明，不能重新拿当前alpha=0猜天然空。

## 限制与停止条件

1. 若在已经有弹孔的房间才启用监听，当前alpha不能恢复原结构支持。必须有已知drawLoc/before起点；否则安全回退/等待已有正常重绘，不能隐式全房重绘来隐藏额外加载成本。
2. 缓存属于现有房间/稀疏cell生命周期，只保存所需alpha及少量代际，不存逐发clip历史、不clone整图。极端覆盖全房仍有状态和计算成本，需要实测。
3. 同一结构eraser重复应用会继续降低半透明alpha；必须将一次原生绘制对应一次支持操作，拒绝旧代际和重复通知。这是局部绘制身份核验，不是新增网络ACK。
4. 必验反例：普通erase→晚到非零ink双方一致；真实tileDie后旧ink不复活结构；同bitmap重绘先刷新支持再重放；gwall新增/到期清除。实际可破坏木材或等离子擦孔仍需原生验证，现有不可破坏靶不足。

因此，尚无需要广泛修改原生对象类的依据；但只加tileDie回调不可靠。四个边界、普通before起点与未知支持回退缺一项，就应停止扩展，不以当前画面alpha猜结构状态。

本次没有修改候选、宿主或生产，没有编译/AIR。一次把参考输入读取与本目录报告写入放在同一命令的操作被本地护栏拒绝，未执行；随后缩小为仅RConnect自有源指纹与本目录报告写入，没有更改护栏或参考文件。
