# aura1 实际 Unit.run 错误与跟随失效的只读核查

2026-10-23。只读源码与既有用户日志，未编译、未启动游戏、未修改产品。本文不宣称首错根因已完全确定。

## 实际错误发生顺序

加入侧日志 `C:/Users/hello/AppData/Roaming/pfe-modsettings-rconnect-player2/Local Store/RConnect.log`：

- 33140–33145：从 rbl 前往 random_mane，采纳 seed 4095208676 后，在 `Land.buildRandomLand → Location.preStep → stepInvis → Unit.step → Unit.run` 出现 #1010。
- 33147：`t_exit=19`、错误框可见。33151 才出现该房间的 grant（term 2）。因此首错发生在本轮新地图构造阶段，早于本轮房间检查点恢复。
- 33216–33218：取得新房间 `1,4,0` 的 authority/term 4 后，又在日常 `Location.step → Unit.step → Unit.run` 出现 #1010，错误单位是“鼹鼠”。
- 原生 `Location.stepInvis/step` 对每个单位调用分别捕获异常，`World.showError` 只显示错误框，循环仍可继续。所以之后收到 grant 或继续运行，不证明此前的单位初始化成功。
- RC `GameBridge` 5324 把错误文本截为 400 字符。首个长调用栈因此缺失尾部单位名，当前日志也没有坏坐标；无法从这条日志恢复具体越界列。

## 已缩小的源码路径

1. 参考 `Unit.as:2029–2474` 的 `run` 中，鼹鼠不会走玩家专属爬沿分支。大量直接访问为 `loc.space[Math.floor(X1 / 40)][y]`、`loc.space[Math.floor(X2 / 40)][y]`，以及横向碰撞范围内的 `loc.space[x][y]`。
2. `collisionTile`（2568）首先拒绝空 tile。因此仅缺第二层 tile 通常返回 0；第一层列为 undefined，或无效横向坐标/尺寸产生不存在列，是更吻合 #1010 的候选。正常水平移动会夹紧中心并更新 X1/X2，但 `isLaz`、斜坡早返、错误几何/数值等路径仍需现场数据区别。当前没有准确的异常字节码位置，不能直接认定某个分支。
3. 鼹鼠是 `UnitMonstrik`，没有覆盖 `run`。其速度、AI 等仍使用 `Math.random`。BEFC 系列 Land 源中的 rconnect seed 控制局部 `rndNext`，并非全局替换 `Math.random`；所以相同 seed 不能证明单位、预步进与全部随机内容相同。
4. aura1 `TerrainSync.restoreCheckpoint` 只改现有 tile 的字段，不替换 `space` 列。`tickFrozenAnims` 调用采样、setPos、setVisPos，不调用原生 `Unit.run`；镜像通常由 disabled 跳过物理。
5. 需要另查的移交边界：`NativeRoomState.restoreUnit` 直接恢复包括坐标、碰撞框、尺寸、速度在内的有限数值，最后只 `setVisPos`；`roomRole(authority=true)` 解除镜像 disabled。该边界依赖快照本来一致，没有重新以 setPos 计算碰撞框。它可能放大已坏状态，但不能解释本轮 grant 前已经出现的首错。

当前不应以通用夹紧、吞异常、删掉原生预步进或跳过检查点作为修复。若现有复现仍不足，最小首错记录需来自实际出错对象：class/id、对象 loc 身份与网格宽度/limX、X/X1/X2/scX、Y/Y1/Y2、dx/osndx、isLaz/diagon、实际列索引；不要拿 World 当前房间代替正在预步进的房间。此处只提出取证边界，没有新增探针。

## 跟随请求的确定丢失机制

准确 aura1 `RoomSync.followTeammate` 第 270 行先执行 `now-followSeenAt>3000 → cancelFollow`，第 272 行才检查 busy、pending、原生 transition 等。`observeTeammate` 只在队友从共同房间离开这一边沿创建新请求。

因此，如果长加载或消息回调排队造成最近一次队友状态距今超过 3 秒，请求会先被删除；此时 `teammate` 已经记住目标房间，之后相同目标的新状态不再产生离房边沿，跟随可能一直不发生。代码可确认这一条件性失效，不足以证明这次用户一定走过该分支：现有日志没有跟随取消原因或时间记录。

busy 本身并不停止所有玩家状态发送；Session 仍发送玩家状态/worldstate。因此不能把“交接超过 3 秒”直接等同于“必定超时”。

最小修正方向是保留加载/暂停期间的有效跟随意图，并在重新具备行动条件后等待同地图、同 epoch 的新鲜队友状态再行动；断线、关闭选项、地图/epoch 改变仍取消。不要只把 3 秒改成更大的常数，也不要仅移后判断后立即沿过期坐标传送。该改动可与已有 RoomCooperation 原生驱动的静止同伴、分房/合房和权威移交断言一起验证。

## 来源与限制

实际生产源为 `build/m52/recovery-aura-offline-01/src`。Unit 使用指定的 1.02 参考源，未另行反编译最新 80CF 宿主；根任务已确认该宿主继承 BEFC 的 Unit 路径，最新改动为 lighting。本文不以参考源冒充新的精确导出。

- RoomSync SHA256：`536f587088965ee6f38147d11f2a07723e4c78c48062ad618814cd1f40b36163`
- NativeRoomState：`4690d896500c473cb2fce1e9be0b58ace1ef687664fb88d63bb1a8f77211898a`
- 参考 Unit：`3a6c2db7cca18045c6c6d753f15e2ae96fea6da1c97223ecd8f7f35b9756d66c`
- 既有 native-export Land：`34433cb2c248bfbb58513c29b7d958627f35b493ec7dc1fa96f5ae8c8888f40f`

加载、原生 UI、现有精确驱动和 early2 性能限制见同目录 `LOADING-REVIEW.md`；本次没有更新那些历史结果。
