# 击墙动画恢复增量（2026-10-21）

基线为 `build/m52/coop-bundle-04` / `0.2.23-coop-bundle2` / `574d2b51490ae8b25a1396555600f56a301f8a20ae50104c0e35cf2796441afe`。本目录只是给主会话整合的稀疏源码及外置测试；未编译、未启动 AIR、未部署。没有修改其它候选、安装文件或共用记忆。不能沿用旧候选的 32 项组件通过作为本目录通过。

## 核查结论与修正

- 安装基线缺少 `BallisticImpactVisuals`；`WallImpactVisuals` 仅保留墙痕，不能补上短暂火星。移入原候选实际原生粒子采集与独立命中队列。
- `Bullet.popadalo`（本体 `Bullet.as:324`）对材质 1/2/5/7 发出 `iskr_bul`，对材质 3/4/6 不应凭空造火星；非普通弹的 flare 仍以真实发出的 Part 为准。真实命中、位置、类型、新生时间同时符合才回放。
- `PhisBullet.popadalo`（`PhisBullet.as:187`）覆盖父实现，只结束或爆炸。现在明确从能量 flare 归属扫描排除，不因枪配置写有 flare 就误认邻近闪光。
- 旧候选的静止能量闪光没有新生检查、未对所有种类检查碰撞标记；旧已结束子弹还会持续尝试认领后来才出现的粒子。新版本对每颗结束子弹只检查一次，能量闪光一弹一 Part，排除旧闪光、寿命结束、后来相邻射击。喷火器火苗保留原生位置抖动容差。
- 粒子按 32 像素空间格分组，每次命中只查附近 9 格，不再逐命中遍历整张地图的同种粒子。静止闪光依然要求误差不超过 0.01 像素，移动火苗不超过 14 像素；不是放宽命中判断。
- 普通 NPC 慢弹现在按真正离开链表的时间计退役窗口，避免 700ms 出生期限吃掉晚到撞击。收到发送机会后按发送时间保留 700ms；尚未发送的普通弹仍按结束时间保留 700ms，避免把普通离线记录变为永久积累。已有 recorded 离线积累问题未在此修复。
- 弹体 `vis` 已销毁而撞击已被确认时，允许事件顶层 `impact` 继续承载确认事件；`ImpactEventQueue` 同时接受顶层和旧 `flight.impact`，仍按流/序号去重。
- 补全原生 `flare -> visualFlare` 映射。血粒子沿原生纯视觉 Emitter，短能量动画只创建显示对象；不调用 `Bullet.explosion` / 伤害 / 地形破坏。

## 主会话合并位置

生产文件共五个，完整哈希在 `integration.json`：

1. `src/rconnect/game/BallisticImpactVisuals.as`：新增类；独立粒子检测与纯视觉回放。
2. `src/rconnect/game/ImpactEventQueue.as`：新增类；独立于弹体生命周期的确认命中队列。
3. `src/rconnect/game/EnergyImpactVisuals.as`：替换原有类；扩展 flare，原生 Part 归属检查及空间索引。
4. `src/rconnect/game/UnitPresentation.as`：只合并 `observeWeapon` 的 impact 捕获、普通弹结束与退役；`capture` 的 impact/无 vis 传输及 endSentAt；`reset` 的 Ballistic reset。**不覆盖主会话新 `captureEffects` / `captureMotion` / 弹体增量类**。
5. `src/rconnect/game/ProjectileVisuals.as`：只是成员 `impactEvents`、`setPaused` / `receive` / `tick` / `reset` 的接线；与旧 wall-impact2 字节一致。**不覆盖主会话增量帧合并，不改 `tickBeam` 或 RemoteMotion**。

协议：正常 `shot.flight.impact={at,x,y,groups:[{kind,count,dx,dy}]}` 保持；只有 `flight==null` 才用 `shot.impact`。能量仍是 `gun.impacts` 数组。新的 50ms effects 路径若承载这些字段，须保留队列入口；不能只传 flight 帧而丢掉命中事件。独立命中队列允许较旧子弹晚于新序号撞墙。

## 测试入口与待验证

原有 43 个原生用例保留：

- `WallBallisticTestDoc`：14 例，lmg/autor/shotgun 双向、NPC lmg、改枪速的长飞行夹具、双方 12 发连射、双方到期未命中、双方肉体命中。
- `WallEnergyTestDoc`：15 例，nova/plam/prism/blaster 双向、plamg 双向 12 发连射、NPC alilight、cflamer 双向、plamg 到期。
- `WallMagicTestDoc`：14 例，telebul/mbul/ice/lightning/mray/dray/skybolt 双向。
- 新 `RecoveryWallMaterialsTestDoc`：14 例，lmg 对材质 1—7 各双向。实际 Bullet.tilehit 必须出现；3/4/6 要求源端和远端都没有火星，防止“没有真打到墙”假通过。

共同 `tests/EnergyImpactTestDoc.as` 已修正全模组夹具：本机玩家使用 `Invent.addWeapon` + `changeWeapon`，并断言装备对象确为背包对象；NPC仍用原生 Weapon.create。避免复现上一轮 FA 的“测试枪不在背包，after 快照为空”。保存/恢复原 magicWeapon/throwWeapon，避免连续换枪留下测试引用。

现有旧候选运行入口（仅用于阅读/复现旧 43 例，不构成本目录验证）：

```
python -B -X utf8 tools/validation/run_wall_impact.py build/m52/wall-impact-02 --suite WallBallisticTestDoc --label <新标签> [--control] [--all-mods] --registry-wait 900
```

能量/魔法替换 `--suite`。主会话新集成产物应冻结本目录 `tests/`，而非重新使用旧版未拥有测试枪驱动。旧 `prepare_wall_impact.py` 硬编码旧 overlay，旧 `run_wall_impact.py` 只允许前三 suite；主会话的集成构建入口须显式纳入第四 suite，不能误跑旧字节。

组件 `components/ImpactQueueChecks.as` + `ImpactCaptureChecks.as` 包含原 32 项及新增 9 项（共 41 项静态计数，尚未执行）：无 vis 的终末命中及重复包、同位置新鲜闪光+到期弹、旧静止闪光、旧弹认领稍后粒子、PhisBullet 假 flare、同位置双弹双 Part、普通旧弹稍后认领。组件 Part/Bullet 是明确的边界替身，不代表游戏碰撞或渲染验证。空间索引的收益尚未实测，不能报性能改善比例。

剩余验证必须保留：

- 以上 57 个原生场景，实际像素目检、双方全模组错误日志、重复事件与清理；新源码还须编译及组件执行。
- 12 发高射速之外的持续密集负载；对照准确 574D，确认 added native Parts 不造成性能退步。
- 换枪、换房、暂停时的收尾；普通 NPC 慢弹超过 700ms 的原生用例不能被省略。
- 爆炸/投掷物仍沿基线 `ProjectileExplosionVisuals`（真实 isExpl），没有修改。需复跑既有 `ExplosiveVisualTestDoc` / `MagicExplosionTestDoc` / `HeavyProjectileTestDoc` 的酸性炸弹、燃烧、冰冻、EMP、火箭/榴弹等；旧驱动也存在未入背包的 Weapon.create 夹具，正式全模组运行前需同样改成原生背包装备。不能用 43 个非爆炸命中场景代替这些。
- 水中子弹的 `kap` / `steam` 是入水事件，不是本次击墙修正；未新增同步。自定义模组新增且不在原生映射中的 flare 也不能宣称覆盖。软墙本身碎屑/破坏另属现有地形同步，不在本次普通火星队列中造替代动画。

当前仅完成源码核查、差异检查和 AS3 分隔符静态检查；没有原生或性能合格结论。主会话统一整合、串行测试及部署，本分工不再启动独立测试窗口。
