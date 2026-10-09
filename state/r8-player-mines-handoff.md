# R8 玩家布设地雷交接 — 2026-10-09

状态：独立实现及专项夹具已写，静态自审完成；**未编译、未运行 AIR、未部署、未提交**。原始「RConnect」会话唯一负责 M50 共享接线、构建、负控/候选验证和部署。本记录不替代主 MEMORY/journal；完成合并时请把最终证据写回主入口。

## 原问题与源码证据

- 玩家地雷不走 Bullet。原版 `fe/weapon/WThrow.as:140` 的 throwTip=1 分支创建 `Mine(id)`，进入 units/firstObj，并设玩家阵营 100；武器原生扣一次弹药，地雷伤害、半径、准备时间含技能修正。
- `GameBridge.readUnitsSnapshot/reconcileWorld` 排除 fraction>=100，通用房间 checkpoint 同样缺失玩家地雷。
- `Unit.explosion → Bullet.explBlast/explBullet` 的实际冲击 Bullet.owner 是 Mine，`MirrorHitUnit.damage` 只允许 owner===loc.gg，因此加入侧自算地雷爆炸不构成有效镜像命中。
- 原生 `Location.step` 先 gg.step，再遍历 firstObj。逐帧末捕获尚有同帧被其他子弹引爆的漏洞，故使用独立 PlayerMineGate 首链对象，在这个原生边界先接管新雷。

## 本会话独占文件

- `src/rconnect/core/PlayerMines.as`
- `src/rconnect/game/PlayerMineGate.as`
- `tests/MineSyncTestDoc.as`
- `tests/MineRoomTestDoc.as`

没有修改 Session/GameBridge/RConnectMod、工具、版本、release、主记忆、其他模组或游戏文件；未修改任何已冻结 probe。

## 共享接线（交原会话）

1. RConnectMod：Session 初始化之后创建 `public var playerMines:PlayerMines`，`playerMines=new PlayerMines(this)`，并设 `game.playerMines=playerMines`。
2. GameBridge：对应 public 引用；`checkpoint()` 返回加入 `mines:playerMines==null?[]:playerMines.checkpoint()`；`restoreCheckpoint()` 末尾在所有本体状态恢复后调用 `playerMines.restore(s.mines as Array,authority,foreign)`，均加 null 防护。
3. `Session.flushRoomReports` 入口调用 `mod.playerMines.flush()`，使离房封口前的最后布设先进入同一有序 TCP 流；`Session.stop` 和断线清理调用 `reset()`。模块也会在帧入口自行检测断连。
4. 不修改通用 units 的阵营筛选，不放宽 MirrorHitUnit 的伤害来源检查。
5. 构建入口注册 `MineSyncTestDoc`、`MineRoomTestDoc`；后者使用 random_mane 普通房地图，前者建议 random_mane，分别留约 240 / 300 秒上限。PlayerMineGate 只继承已有 Unit 存根并 override step，无新原生存根。

## 运行规则

- 房间负责端维护唯一真实 Mine。非负责端原生 WThrow 的临时 Mine 在 Gate 处先 disabled、移出 firstObj，保留原生库存消耗，发送带 roomKey/epoch/term 和唯一 M:owner:serial 身份的布设请求。接收复制原生已经算好的伤害/半径/质量/准备进度，不再乘一次技能。
- 非负责端只保留 disabled 的原生外观对象，留 units 供原生 x37 遥控器枚举，绝不进 firstObj。直接挂显示片段，避免 Unit.addVisual 对 disabled 的早退；不调用原生爆炸/掉落。
- x37 的原生 detonator 激活信号转交权威，所有同房 x37 语义沿用原版。来源 owner 单独记录，`ownerOf(unit)` 可供将来策略使用；本轮没有扩大友伤规则。
- 完整本体标量、私有 AI 进度和交互标量进 mines checkpoint；空房重访/换负责端据此恢复。死亡和拆除记录保留，旧布设包不复活地雷。
- 重复/错期消息不重复布雷、引爆或播爆炸；爆炸只调用 DeathVisuals.play 的粒子/声音配方。首次重访死亡状态不重播历史爆炸。
- 断开清理镜像、未确认预览、Gate 和监听，已在本机权威结算的真实地雷保留原版离线行为。拒绝/15 秒仍未知的预览被清理；未知结果不自动返还弹药，也不偷偷恢复本机活雷，迟到的有效权威状态仍可确认该次布设。

## 验证入口与未验证边界

- MineSyncTestDoc：真实 WThrow 布雷/扣弹；宿主破片、加入侧破片/等离子/遥控雷；两侧显示对象真实上台、权威恰好一个在运行、加入侧没有运行副本；原生尸鬼实际 HP 损失；原包重放不重复实体/伤害，爆炸后移除。
- MineRoomTestDoc：真实 x37 布设；宿主离房让加入侧取得原生权威；双方离房暂停后重访，再汇合；伤害参数和已经结束的准备时间保留；原生拆雷后两次交接/空房重访不复活。
- 所有断言尚未运行，不能称通过；实际爆炸像素、长时间大量地雷/网络拥塞、异常断线后的库存结果仍需测量。
- 当前镜像是显示/遥控接收体，不提供加入侧对镜像地雷的拾取拆除、枪击引爆或念力抓取。这些原本未跨端同步的操作没有假装接通；如本轮要求保持加入侧刚布雷后的这些本机操作，应继续增加权威交互请求与专项，不能单靠放开 disabled。
- 新技能 diagnosing-bugs 的使用事实可并入 M50 总实验记录：用户症状 → 源码机制与两条可证伪假设 → 先写真实 native/TCP 夹具 → 独立实现。尚没有业务运行证据，不登记为实测通过。
