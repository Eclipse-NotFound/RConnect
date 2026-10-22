# 普通房前景外缘：准确22单类隔离候选

依据 `../recovery-ordinary-wall-review/evidence.json`：run215270505b 的22个未同步点全部在碰撞空格 `(27,8)` 的真实前景墙沿，源最后变化后稳定7673ms、远端始终baseline。不是1级色差或采样尚未结束。原严格失败保留。

只覆盖准确 `build/m52/recovery-22/src/rconnect/game/WallImpactVisuals.as`，不合并23暂停改动、不改宿主/协议/伤害。`proposal.patch` 是完整生产差异。

规则：

- 普通房仅在既有真实接触/地形变化候选范围内执行原生 bitmap 比较，允许原生前景伸到碰撞空格中的部分进入现有 sparse cells。没有每帧全房 alpha 扫描，没有固定2px扩边。
- 普通房非实墙格最终 `put/replay` 只能写到当前真实 frontBmp alpha 非零处；透明擦除仍允许。逻辑/线包颜色、queued/pending、ACK和版本保持原值，最后写入继续使用22已有的 `NativeWallColor.setter`。原生毁墙/重建将支持遮罩清空后，收到的旧非零色及 checkpoint/replay 均不能制造新的不透明像素。
- 因而“天然碰撞空格里的美术”与“已经消失的前景”由**当前原生前景像素是否存在**区分，不按邻接距离猜归属。逻辑墨迹与当前可见结果允许不同；被遮罩跳过的非零逻辑值仍可留在 checkpoint，但每次回放都重新受真实遮罩约束。
- 在原 room state 里只缓存一个 `ordinary` 绘制类型字段。仅当共享 Grafon 的 loc 身份等于目标房时学习它；未知/非当前房只存逻辑数据，不能拿另一房的 alpha 或 sceneLarge 判断。没有新 ownership 状态机、长期待确认队列或新 ACK 类型。
- 大图的非实墙格外缘仍沿原 solid 过滤，本轮没有修复/验证这条路径。大图既有行为和原85个组件断言完整保留。

代价及上界：原生接触候选中的空碰撞格现在也要 compare，范围仍由原 `margin(tip)`、爆炸半径和房间 bitmap 边界裁剪。普通48×25房最多1200个cell，每cell最多1600个索引，墨迹覆写同索引，不追加每发历史；最大逻辑像素域为1920×1000。queued也合并同索引；pending仍单批64cell/48,000字符限制，解码单cell3200数字word和原整包检查均不改。**现有系统没有每房长期总字节淘汰阈值**；本候选会保守留下毁墙后不可见的稀疏值，且原生透明清除可能记录为零色。快路sent游标不重发未变版本，但200ms累计轮转可能继续携带它们。故不能宣称无成本；累计状态与接触区域compare的真实代价须由根会话密集对照判断。本轮不为剪枝引入第二套透明擦除/毁墙归属历史。

组件准备为132项：既有85逐字保留，追加47。包含准确22完整控制类复现丢22点、22实际ARGB逐点保持、源报告/接收/ACK/快路/累计/checkpoint、天然外缘重访、透明擦除与同包不支持像素、毁墙后旧包和restore不复活、共享Grafon旧房、未知房首次实际遮罩、连续预测与ACK、七像素下缘、局部接触不采远处变化、大图空格行为不扩大。旧85中的18旧类只用于原有5个透明转色反例；新丢边缘反例的 `WallControl` 是准确22仅重命名。

组件使用真实生产类和真实 BitmapData；`fe.weapon.Bullet` 仅为外部接触字段载体，Grafon等沿既有85项存根。**它不验证实际游戏子弹、网络发送、原生绘制耗时或最终性能。** 已有普通房原生驱动负责后续真实同场检验，不改它的严格uint门槛。

根会话运行（本次仅准备，未执行JVM/AIR）：

```powershell
python -B -X utf8 experimental/recovery-ordinary-wall-edge/prepare.py --verify
python -B -X utf8 experimental/recovery-ordinary-wall-edge/run_component.py --output build/m52/recovery-ordinary-wall-edge-component-01
```

薄入口调用原 `tools/validation/run_recovery_component.py`，沿用共享登记、60秒组件上限、安装/输入复核及原失败保留；不新增执行框架。只有根实际回执132/0后才考虑合并及同普通房/密集原生对照。
