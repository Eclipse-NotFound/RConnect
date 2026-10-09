# R10：墙体命中外观同步（M50 合并项）

2026-10-09。用户反馈黑斑、灼烧和小缺口在两端不同步。用户在原「RConnect」会话最新答复允许所有 RConnect 开发会话互通进度；原会话 `01a086bb-378c-7f60-b8e1-50d90ffa0996` 唯一合并、构建、AIR、部署。R10 只编辑本交接及两个独立源码/测试文件，不修改共用入口、记忆、工具、版本或 release。

## 原生源码证据与范围

- 1.02 `Bullet.run` 调用 `Location.hitTile(tile,destroy,X,Y,tipDecal)`；普通枪 tip 1、激光 12、等离子 15/17 进入不同图案。
- `Location.hitTile` 即使耐久未减少（包括 indestruct），也能调用 `Grafon.dyrka`。后者随机旋转、缩放和挑选 MovieClip 帧，通过 `decal` 直接改 `Grafon.frontBmp` 的 RGB/alpha。贴图编号/耐久/碰撞保持不变；原 TerrainSync 无法表示这些改动。
- `Grafon.drawLoc` 在换房或 redraw 时清空再绘制同一前景位图。仅播一次痕迹事件不足以保留重返结果；Grafon 被多个房间共用，旧房 `inRoom` 结算不能写当前新房位图。
- **源码确认，尚待运行验证**：不把这些事实写成已完成双端复现。本模块负责仍是实体墙的局部外观；整块瓦片死亡、碰撞开放、水及碎片沿用 TerrainSync。未改游戏本体或反编译资料。

## 独立实现

`src/rconnect/game/WallImpactVisuals.as`：按真实 native Bullet/SmartBullet/PhisBullet 联系和爆炸邻域，比较 40×40 小块；只有当前房间持有一份完整前景影子，其余房间缓存稀疏像素。随机图案不在接收端重抽；接收只写 bitmap，不调用 native hitTile/die/dyrka/attack。

随机图案边界按真实原生素材所有帧/最大缩放计算（构造传 main），备用边距 96。图像压缩用已有 RoomCodec；单包最多 64 块、48000 个压缩字符，累计快照轮转；像素偏移/颜色/坐标/数量在写之前验证。只接受真实墙格；删除物理已移除格的旧痕迹，避免重画把墙填回。

客户端独立递增 seq、单批在途、ACK 和重复回执；权威侧按抵达顺序合并变化像素。不同位置保留双方痕迹，同一像素的最后抵达值由房间权威决定。源待 ACK 及后续队列中的像素免受旧慢快照覆盖。旧房无当前 grafon bitmap 时只更新该房缓存，交接后 restore 再画。

## 共用接线建议（由原会话完成）

1. GameBridge 初始化 `_wall = new WallImpactVisuals(main)`。原生 step 前 `before(loc)` 建影子；step 后 `observe(loc)` 观察真正生成的痕迹。使用源时间一致的游戏帧，不依赖网络 Timer 恰好采到子弹。
2. `readTilePatch` 的结果传 `observe(loc,list)`，覆盖没有 linked Bullet 的 native body/Area 伤墙。`scanTileReports` 的真实 tiles 也传入；只是在已有扫描基础上比较，未增加全地图逐帧像素扫描。
3. authority unitsync 增 `wallPaint: _wall.snapshot(loc)`，即便没有新 shot/tile HP 变化也发送累计痕迹。mirror 在 applyTilePatch 及必要 redraw 后 `receive(loc,msg.wallPaint,true)`。先物理、后画痕。
4. mirror terrain 数据附 `wall: _wall.report(loc)`；纯视觉时构造 `{tiles:[],wall:...}`，**不伪造 TerrainSync 的 epoch/seq**。GameBridge `applyTileReport` 仅对真正存在的 TerrainSync 批次调用原 settle；独立 `_wall.settle(loc,peer,request.wall)` 返回 `wallReceipt`，合并到同一 ACK。无真实 tile 批次时空 `tiles:[]` 回执足够。源 ACK 同时 `_wall.acknowledge(loc,msg.wallReceipt)`；纯视觉 ACK 不必通过 `_terrain.pending`。
5. close-room flush 调 `_wall.finishReports(loc)`，每个额外视觉批次仍走既有 terrain 消息、rooms.stamp 和旧房 `RoomSync.report` 白名单。已发 pending 不重发；后续痕迹在同一有序 TCP 上先于 ready/checkpoint。所有消息保留 roomKey/epoch/term/真实 peer 验证。
6. **避免新增宿主中心假痕**：TerrainSync.settle 对加入侧的非致死 `hitTile` 临时 `loc.active=false`，finally 恢复。HP/碰撞/水等仍由 native 决定；这个抑制不能只看该包有无 wall（旧视觉 ACK 在途时第二包 HP 可能没有 wall）。预计是否致死只用于绘制抑制，Tile.udar 的判断和所有实际伤害仍走原逻辑。致死/整块墙破坏保持旧流程，并继续已有 BeamTerrain 回归。
7. native `world.redrawLoc()` 之后 `_wall.redraw(loc)`；checkpoint 增 `wallPaint:_wall.checkpoint(loc)`，restore 在 `_terrain.restoreCheckpoint`/完整 redraw 后 `_wall.restore(loc,s.wallPaint)`。roleChanged 清传输游标、保留缓存；会话/地图重置 reset。**退出旧房 checkpoint 只取其缓存，不对当前新房作全图采样。**
8. `dirty` 表示接收使画面变化；GameBridge 需要把缓存 SATS 背景置 dirty，再清此标志，沿用 M49 的最后 RENDER 重拍机制。

## 专项测试

`tests/WallImpactTestDoc.as` 不导入新辅助类；同一驱动可针对已安装 21 做负控。Native Weapon.attack/step → Bullet.run 真正撞墙，在第一次原生命中 RENDER 冻结原始像素参照，避免把之后的宿主修正当成原生参照。

- 双向真实 LMG 木墙不可破坏小缺口、plam 可破坏石墙但不打穿的等离子缺口、prism 不可破坏墙的激光灼痕。
- 第七场双方同时在不同高度射击；合并两端真实变化像素。
- 要求每个原生变化像素在两端相同，额外随机中心痕为 0；原生及接收画面均有最终游戏像素贡献；phis 仍 1，HP 两端一致。
- 保留实际 terrain.wall / unitsync.wallPaint，交回原发送方按原方向重放，核对不加深、不再次伤墙。
- 真正 TravelGuard/RoomSync 去第二普通房再返回，核对图案、alpha 小缺口和物理状态保留。不是直接调用 helper.restore 代替房间交接。
- 前缀 `COOP PASS/FAIL wall-impact`、`WALL IMPACT METRIC`、`COOP EFFECTS DONE wall-impact`。建议 random_mane、双方原角色模板、禁自动战斗/移动/跟随/回血，全已安装模组，独立运行上限 300 秒。

## 截至交接

尚未构建、运行 AIR 或部署；静态自查不等于运行通过。请先原 21 字节负控，再接线候选绿测；推荐相关 BeamTerrain、ProjectileNetwork、GameplayNetwork、RoomCooperation、TargetLifecycle/CoopPause 回归。R10 完成发送后停写，后续测试失败由原会话协调需要的文件改动。没有本地提交或外部推送。

### 交接通信与最终停写

源文件初版准备/接口协调已收到正常发送回执；完成交接消息与一次补发均返回 `Codex app tool request failed`，是否送达不能确认。已核对原会话 journal/m50-coordination，同步服务也在它处不可用；这不是权限拒绝。没有继续重复发送或另开 AIR。最终静态复核修正了重复/在途保护快照的 SATS dirty：仅真正不同的 bitmap 像素触发刷新，缓存相同值不反复递增。两个 AS 文件分隔符静态检查通过，仍不等于 Flex 编译或原生运行。**此段保存后 R10 已停写全部三文件**；原会话可直接接管与测试，不需等待消息服务恢复。
