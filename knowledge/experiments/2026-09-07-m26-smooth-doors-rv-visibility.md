# 实验：M26 念力平滑 + 门复验 + RV 视距与联机的敌人隐藏——2026-09-07

- 用户报告（grilling 轮答）：①主图敌人在加入端不显示；②马哈顿的门宿主侧
  开、加入端无反应（用户确认非自动关门）；③念力搬运卡顿明显（选 a 修法）。

## 事实取证（用户真实双开日志 + RV 源码）

- 敌人管线健康：random_mane `unitsync matched 11/11`、注入零失败、
  镜像持续——"不显示"不是同步丢失，是**渲染层被藏**。
- **RV（RealisticVision，09-06 00:34 被并行会话更新）的视距机制**：
  `hideEnemies()` 对每个敌方单位做本地玩家视线判定（enemyState→
  bboxFovCount 射线），视线外 → `hideUnit()`：`u.vis.visible=false`。
  联机组合效应：宿主灯下看得见的敌人，在加入端按**加入端自己的视线**
  判定——加入方站门口看房间深处 = 敌人全在黑暗里 = "不显示"。
- 双实例采样实证（M26 诊断埋点 `unit vis sample`）：
  `merc2@d1062 v=1 p=1 s=0 m=0`——RV 隐藏实锤；
  `phoenix@d1026 v=1 p=0 s=1`——vis 未挂显示树（观察项，疑游戏自身
  对特定状态单位 remVisual）。
- 门机制复验通过：宿主 doorIcTest 开/关 'door1' → 加入方
  `ist apply open=1/open=0 tilePhis` 双向同步 ✓。random_mane 门清单
  （新诊断 `doors in room`）：door1/door1a 均 ac=0（可同步），
  window1 ac=?（**无 inter 的门形对象**——脚本门/窗，宿主侧开它走
  scrOpen 路径，我们的 inter 状态通道读不到，不同步）。
- rr_showroom（RandomRooms 生成图）#1010 崩溃：非确定性几何下宿主
  坐标落在加入方房外 → Unit.run() 读 space 越界。

## 实现（M26）

- **念力平滑**：joiner 上报扫描 1Hz→5Hz（限频 1s→200ms）；接收端
  trackBoxPos 改 tween 目标制（tickBoxTweens 每 50ms 逼近 25%），
  200ms 硬跳变渐进追赶；ist 稳定性门 3→6 次扫描（5Hz 下仍 ≈1.2s，
  循环门相位照滤）。
- **注入/镜像落点校验**（validLandPos）：40px 网格螺旋搜有效瓦片
  （±24 格），注入就近吸附、镜像拒写越界（保命优先于位置精度），
  修 rr_showroom #1010。
- **诊断埋点**：宿主每房 `doors in room`（id:ac,open）；joiner 每房
  `unit vis sample`（id@距离 v/p/s/m——v=有 vis，p=挂树，s=visible，
  m=被 RV 遮罩）。

## 验证（双实例 random_mane）

- 门：`doors in room: door1:ac=0 ... door1a:ac=0 ... window1:ac=?`；
  doorIcTest 开→`ist apply open=1 'door1' tilePhis=0`、关→open=0 ✓。
- 箱子：双向 pos synced / move applied ✓（tween 驱动无异常）。
- 采样：merc2 s=0（RV 隐藏）实证；零错误对话框、零扫描异常。

## 待用户拍板（第二轮 grilling）

- 敌人显示修法：A) RConnect 对"宿主快照里存活的镜像敌人"周期强制
  showUnit（联机语义=队友报点，绕过 RV 对同步单位的隐藏；RV 其余
  效果不动）B) RV 侧加联机豁免（他人模组，只报告）C) 保持现状。
- 门：window1 类无 inter 的脚本门是否要同步（需走 scrOpen 事件转发，
  中等工作量）——待用户确认是否就是其测试的门。

## 教训

- 联机模组与单机视觉模组的组合会发生"语义错位"：RV 按本地视线藏敌人
  在单机是特性，在联机里被感知为"同步坏了"。跨模组问题先看渲染层
  （vis.visible/parent/mask 三件套采样）再怀疑同步管线。
- 诊断埋点（门清单/可见性采样）一次部署，用户每轮实测自动留证。
