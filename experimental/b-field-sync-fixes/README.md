# B 原生破墙同步局部修正（待实机）

准确基线 `build/ab/b190-field9-build/src` / 当前field3。本目录只存增量覆盖源，不改冻结基线、A或安装文件；未编译、未运行AIR、未提交或部署，统一由root整合验证。

## 源码证据

- `native-hooks-019/verified/scripts/fe/loc/Location.as` 的hitTile/dieTile调用Tile.die后由Grafon.tileDie处理前景擦除，不调用drawLoc。Tile.die只清前景（phis不等于3）、碰撞、opac、vid/vid2及t_ghost；门/陷阱有单独副作用。
- 同版Grafon.tileDie调用decal；decal末尾已通过rconnectInk捕获前景擦除/贴花实际影响的块。主侧TerrainInk以64像素块复制最终原生像素，且FrameDelta维持确认对象不可变。
- 当前ReplicaScene对这些破墙字段变化一律drawLoc，再贴同一TerrainInk像素；drawLoc遍历全房、重画多份大位图和全部对象显示层。这是每次破坏都会走的冗余路径，而非尚未采到的CPU猜测。耗时改善仍必须实测。
- 当前PlaybackClock为整个房间保留65–250ms自适应缓冲，密集源帧可提高该值。导弹/破墙已到达后仍可能等待此缓冲；本候选没有调整延迟参数，不能声称它独立解决所有弹丸延迟。

## 改动

1. SceneSnapshot每瓦片只额外记录door/trap是否为空的前后证据；水/斜坡/平台/后景判断复用已运输的完整标量。`plainFront`标记只随变化瓦片发送。
2. 新TerrainPatch只接受普通phis=1→0、front空、opac/vid/vid2为0的原生死亡形态；除hp外任何其它标量变化都拒绝。门、陷阱、水、斜坡、平台、后景图形均回原drawLoc。
3. TerrainInk要求既有同一raster epoch，覆盖整块40像素瓦片的每个64像素前景块都是新的不可变确认对象，且尺寸完整。没有这种最终像素证据不走快路径。
4. 通过时仍写全部碰撞/地形字段、设lightDirty并贴完整原生改变块，只省重复drawLoc；混合同帧任何其它几何变化仍drawLoc。计数incrementalWalls仅在最终未整房重画时增长。
5. TerrainInk.apply在相同不可变state且没有重新构建位图时立即返回，避免反复遍历历史积累贴花块。state变动或drawLoc后仍遍历应用。

## root 整合与验证

覆盖SceneSnapshot、ReplicaScene、TerrainInk，新增TerrainPatch；TerrainPatchChecks只供外置测试入口调用，不必打包生产。源基于field9，root可三方合并其它UI/投掷物改动。

组件 `TerrainPatchChecks.run(check)`：普通墙允许；无前态/缺门陷阱证明拒绝；每个非死亡字段修改拒绝；不变的水/后景/斜坡也拒绝；部分块复用、缺块、短边、epoch变化和负坐标拒绝。该源尚未编译执行，不能算已通过。

实机重点：

- 双向真实导弹发射器/野火核弹，真实击破普通金属/砖墙；按同一源tick核对源/加入前景、后景RGBA，保留引信、爆炸、伤害及单实例弹丸寿命，不单用墙消失断言。
- 记录破坏前后terrainRedraws/incrementalWalls、replica.terrain与总帧间隔。期待普通前景墙不因该死亡重新drawLoc，完整视觉像素一致。
- 门、平台、斜坡、水体变化、背景墙、新房/ink epoch重置仍走原路径。混合帧的地形/水重新计算及光照不删减。
- 记录`lastFrame.time-clock.position`和clock.delay/queued，区分已收确认的缓冲时间与网络/重绘时间；两进程getTimer不可直接相减。
- 既有8/80敌人两轮交叉性能门槛和功能回归不降低；对场景中两额外引用读取的采集成本也作对照。

## 未解决与后续定位

RoomRuntime对每个活弹丸每帧会在对象step前后、玩家步后、房间步后和EXIT_FRAME重复完整采样；最终只有EXIT_FRAME姿态进入常规状态，但中间采样还承担出生/终结事件和已移除弹丸兜底。不能简单删除中间采样而丢终结显示。若实测显示simulate.projectileCapture占比明显，应将生命周期观察与完整最终姿态捕获明确分离并做同tick生灭/连锁爆炸对照；本候选没有贸然改动它。
