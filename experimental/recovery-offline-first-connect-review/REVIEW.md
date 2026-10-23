# 首次双侧连接夹具的边界审查

2026-10-23；只读准备审查，准确产品为 `recovery-offline-production-01` / EB365353…5FEE。新 AS 尚在编写，本报告不代表夹具编译或实测通过；未修改产品、他人 AS、运行器，也未启动游戏。

## 启动条件

共享 `tools/run_coop_regression.py:100` 的 `--connect-after-load` 必须同时给外部 effects driver、两份原生 `PFEgame0` SOL。运行器保留来源散列，将独立副本的内部名字改为 `PFEgame9`，放入双方唯一应用存储，源存档不改。

最终双方配置是 `autoRole='' / autoGame='1' / autoLoadSave='-9'`，生产会建立初始世界，但不自动读 slot9、不自动联网。外部 AS 必须自己发起原生读档，并确认读档完成、世界稳定后才建立后续身份断言。模板使 autoHeal=0；原默认 autoFollow=1、freezeAI=1 仍保留。host 若传 `--land`，还会留下 autoTravelLand；该行为位于 Session 的 HOSTING 分支，会在 startHost 后触发，不能误当离线加载的一部分。此专项宜让模板均已处于同一 rbl 房间，且不再指定不同的 host 目标地图。

`loadSaveTest()` 返回 true 只表示设置了 comLoad，不代表加载结束。读档确实重建 UnitPlayer/Invent（原生 World.as:1012）；所以先在稳定新角色上保存 gg/inventory/武器身份，再装备和离线开火，不能持有启动新游戏时的旧角色引用。

## 同枪与房间身份

- WELCOME → RoomSync.receivedWelcome/observeHost（191–230）可对不同地图或随机种子发起原生旅行；同地图同房则不会因此重建本地玩家。
- GameBridge.restoreCheckpoint（6199 起）重建场景敌人时明确跳过 `previous===gg`，不恢复玩家背包。原生 Land.ativateLoc → gg.inLoc 也复用玩家，仅更新 currentWeapon.loc 等房间归属。
- 因此“同一模板房间稳定后保存 gg/inventory/同枪，整个首次 startHost/startJoin → roomready 保持身份”是可实现的限定测试。首次握手本身没有必须换枪的设计。
- 身份应分层：本地 gg/inventory/gun 要保持；若发生原生换地图或额外读档，应作为准备前提变化记下，不能悄悄补装后继续宣称旧历史已经清理。远端 ghost/vis 则允许正常创建或因外观重建，应通过公开 getRemoteGhost(实际 peer id) 每帧重新获取，而非要求其从连接前到连接后是同一个对象。
- 需要同时确认双方 roomKey/roomEpoch 一致、rooms.ready、非 busy、非 isTransitioning。仅 landId/locId 相同不足以保证同一层或同一随机房间，产品 updateRemote 本来就会拒绝不同 roomKey/epoch 的化身。

## 旧弹道负例最容易误判的地方

准确 UnitPresentation.observeWeapon（120–157）在清表后仍可重新发现同枪的 `gun.b`。若它已经离链但 kol_shoot>0，仍可能生成一条事件；这与“采集表没清”不是同一个事实。必须保留枪、旧 bullet 和原生开火计数，等待真实离链；不能靠换枪、清 gun.b、readSnapshot 或另造事件来消除前提。

ProjectileVisuals.receive（84–87）以 **`flight.frames is Array`** 区分两条显示路径，不能只看 ended：

| 数据 | 准确消费者行为 | 静默窗判法 |
|---|---|---|
| frames 缺失／非 Array，ended=true | 立即 createVisual；tick 可运行到约 160 ms 后移除 | 仍是可播放旧事件，不能作为安全结束通知豁免 |
| frames=[] | beam 路径没有可画采样，不创建显示物；end 到时移除 | 可单独记为无图结束通知，不能据存在事件就认定重播 |
| frames 非空 | 按 sourceTime、end 和采样范围播放 | 保留完整事件及最终 RENDER 证据，不能用 ended 一刀切 |

尤其首个 Session 定时 capture(stamp=0) 若先于 observePlayer，普通 LMG 可能创建 recorded=false 的事件，落入第一行；如果 observePlayer 先执行，则可能是第二行。静默窗必须记录这两种情况，不能以抽样竞态改变失败判定。真实旧弹可见是运行问题；但只有在准确 574D 对照后，才能把它归因到这次离线优化，而不是既有接入问题。

## 实际远端画面取证

- 身体：公开 `GameBridge.getRemoteGhost(peerId)` 返回实际远端对象。确认它不是本地 gg、loc 是当前房间、vis 在真实 stage 上，再在最终 RENDER 读取 vis/osn 的颜色、滤镜及附件。源端原生状态 → 独立诊断消息 → 接收端显示比较，不应调用生产 apply/receive 或仅比较网络包。
- 武器：由同一 ghost.currentWeapon.vis 读取枪口／shoot 标签。接收者自身不射击，先证明静默窗不存在同类弹图，再读取 `world.grafon.visObjs[2]` 的实际 DisplayObject。按 class 扫描只是起点；应结合对方 main 武器的 stream/seq、单次射击、真实位置和可见时间，排除本地／NPC／上一阶段的同类残图。需要时用最终合成图的有无该对象差分证明它实际贡献像素。
- 旧 NativeFlight 的接口可参考，但不能整段照搬其清地形、禁用角色、手动 gun.step 或调低武器等级的夹具条件。此次无需给候选增加这些人为前提。
- PlayerBodyEffects.apply 保留队友标记：root alpha 为源端的 0.75 倍。不能从旧 BodyEffectsTestDoc 直接照搬源／远端 root alpha 全等要求；freezing 可比较 RGB 偏移与解除后的原始颜色，并确认接收端本地玩家未被染色。
- 静态 freezing 的出现／解除能验证身体状态 capture→TCP→apply 恢复，**不能单独证明 observe 的附件动画历史**。observe 主要累积 MovieClip 帧变化的 run 计数；若没有原生附件开启动画及远端连续帧证据，报告应保留此边界。

已通过协作工具直接向 `/root/early_loading_evidence` 说明上述启动／身份约束及 ended/frames 分类；对方反馈将保留原始事件计数并结合实际弹图、枪口与可播放消息判定。本文只是准备意见，不授予双人、身体动画完整性或性能资格。
