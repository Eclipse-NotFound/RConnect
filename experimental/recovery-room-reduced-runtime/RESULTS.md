# 三项关闭后的普通房：单人／双人结果

2026-10-24，只读回核根会话完成的原生测试，没有新增测试或编译。单人 `15f9ba06c9`、双人 `a53ab258d9` 的 reduced-result、原 result、选择审计和共享登记均通过，原退出码均 0；`performance_qualified` 仍为 **false**。这是本样本普通房流程的通过，不是全模组组合的性能资格。

## 完整耗时

单位秒。elapsed 从各端 begin 开始，到原生切换结束、房间同步就绪、交接与暂停结束、黑幕消失及控制恢复为止，没有扣掉加载、同步等待或出生位置调整。加入侧在收到 depart 后开始本地计时，因此两端计时起点并非同一墙钟；“双侧较大值”只是两个完整本地耗时中的较大者。

| 程次 | 原生流程 | 单人 | 双人主侧 | 双人加入侧 | 主侧−单人 | 加入侧−单人 | 双侧较大值−单人 |
|---|---|---:|---:|---:|---:|---:|---:|
| 0 | rbl → 新探索 random_mane | 9.368 | 6.376 | 6.971 | −2.992 | −2.397 | −2.397 |
| 1 | random_mane → rbl | 4.034 | 1.118 | 1.256 | −2.916 | −2.778 | −2.778 |
| 2 | rbl → random_mane | 5.124 | 2.275 | 2.320 | −2.849 | −2.804 | −2.804 |

本轮三程双侧本地耗时都低于单人记录。**不能将它表述成完全相同负载下的加速比例或目标已经全部达成**：只有先单人后双人各一轮，而且单人用正式 aura1，双人用 roomfix4；随机房出生位置还有下述差异。

## 输入与实际加载

三端使用相同游戏宿主、资源、冻结 Driver/Harness 与实际启用模组，回读 run.json 的相应输入字典相等。唯一产品差别为：

- 单人：aura1，`df0fa0e2ca952e77e5132e75d71e73558dc919c7b8cdeba5da05fc9e94dc01e7`。
- 双人：roomfix4，`34a17de66e9a89165b4bde75d22ec1dd3d4295bb496b903124687af80422b703`。
- 游戏宿主：`abe2b65edf3d0e4e0fa8eca76a60e577d40e47f20b9acecebec7730849a2602a`。
- Driver：`80e56d6ed142a46bbe86972ea1349f0df9bd78d412c94e5fa34c2f379b8ad7f9`；Harness：`d52ef4300c7d472ee05884d7b4709f4abf80b3e6ff935b695a9ed986db021086`。

关闭项是 **LightAndDarknessMod、RealisticVisionMod、ContinuousSceneMod**。它们的物理文件保留，官方启动器只修改隔离副本的加载选择。实际启用 11 项为 AddictionSystemMod、FirearmAttachmentsMod、LootEditorMod、ModLoaderMod、MoreSkillsWeaponsMod、PermanentInjuryMod、RConnectMod、RandomRoomsMod、SandevistanMod、TDFCMod、WallBlendMod。

已经重新解码三端保存的真实 ModLoader.sol，而非只看配置：每端 `requested=ok=上述11项`，没有 err，没有三项关闭模组请求；boot/boot_start 及所有状态值属于同一次新 session。启动前不存在旧 SOL，session 时间均晚于本端启动前记录。原始 SOL、解码 JSON、选择回执、输入清单及最终结果的 SHA 绑定实际相符。

| 实例 | 实际 loader session |
|---|---|
| solo host | run_1792806845056_801752 |
| dual host | run_1792806938248_611778 |
| dual join | run_1792806973418_500917 |

## 三程正确性与比较边界

- 每端都有完整 round 0、1、2；random_mane 两程种子均 1380142925，rbl 为 0；对应 roomKey 一致，全部尺寸为 **48×25**，actualMerged/merged 均 false。没有使用历史 240×125 大图 solo 来比较小图。
- 单人 14 条、双人主侧 26 条／加入侧 15 条原通过记录；没有 COOP FAIL、扫描异常或运行错误；每程真实控制恢复断言均通过。双人三程同房、尺寸、种子和同入口断言全部通过，主侧记录双方入口距离均为 0。
- **跨模式入口不同**：random_mane 的 round 0、2，solo 出生 `(161.8,320)`，dual 双方出生 `(1161.8,800)`；rbl 三者均 `(961.8,800)`。这不违反本轮双人“双方同入口”的断言，但不能称跨模式同一出生负载。根会话仍在核查来源，此处不归因、不隐去。
- 记录的 `units` 是 `w.loc.units.length`，solo 为 8/28/8，dual host 为 9/29/9，dual join 为 15/38/15。**它不是敌人数**：生产 GameBridge 的队友实体会加入 loc.units，MirrorHitUnit 碰撞代理也保存在这个数组；FriendlyFire 亦会加入 PeerHitUnit。不能据这三个数组长度直接判定敌人重复、敌人数量相等或额外敌人生成；本轮没有逐实体清单来分解每项差值。
- `cover` 是 entryPending 在帧边界的累计，不是“旧文字界面可见了多久”。本轮没有截图证据，不能用该计数单独判断加载画面的外观。
- 两次独占 AIR、无其他 AIR 采样，登记 passed=true/cancelled=false，未因内存或占用中止；运行最低可提交余量约 solo 7.492 GiB、dual 5.746 GiB。自有 host/join/frozen 副本已清。正式 22 项输入和绑定源码均未改变。

结论仅覆盖这组三项关闭配置及三程普通房；不覆盖 LAD/RV/CS 全开、连续大地图、房间交错、真实长期战斗，不能借给后续大图计数实验。当前数据没有区分“三个模组分别贡献多少耗时”，也不证明 RConnect 热路径已完全消除。

## 回核文件

结果目录：`build/m52/recovery-room-reduced-solo-01`、`build/m52/recovery-room-reduced-dual-01`；原始运行目录：`build/cooperation/15f9ba06c9`、`build/cooperation/a53ab258d9`。以下路径相对各目录。

| 文件 | solo SHA256 | dual SHA256 |
|---|---|---|
| reduced-result.json | 3ab2f55549a13ec02070e347a369522ea9a8de3571867f10c8f4592d09992f38 | 1c733bda9cc5bc047b5f7d3baadd3992d049eab35b724cc9c77163250c85b4c8 |
| result.json | 14dbe99e292ad50b4ad0a88d08112b90c84e31832bda0f58294312add941874e | 89a0d5898adec1ce004b9cd7f694ec4403a48b63d849c40d1d104fb9508a0225 |
| 原始 run.json | e4a3b058343512eb7854e9154226179ab86042cfa16327ba6a729e0d87200eb4 | 7afeaf985b3ba06da5db82010b87b60755ee3280ab789c70812cedd0ccef19a7 |
| 原始 reduced-selection-result.json | a418e6d88ce913e6246c06059c5f5d2725a41c60a8c7ab71ca9c396bf03c1076 | f14ec8774c2b7f03ad67268d09a07900224869e14074c0c71f1a33ffb66be293 |

TRAVEL RESULT 原始行：solo host.log 16/24/33；dual host.log 51/77/106、join.log 50/68/89。计时定义见冻结 `recovery-room-reduced-driver-01/tests/RoomTravelTimingTestDoc.as` 的 begin/stable/result；数组口径见其中 result，以及生产 GameBridge.as 1506–1510、MirrorHitUnit.as 类注释、FriendlyFire.as 90–93。

## 出生点来源补核（追加，2026-10-24）

本节只补充上述跨模式入口差异的源码与日志核查，不改写原数据，也不解除性能配对限制。尚未发现把旧房坐标写入主侧的直接证据；目前更符合原生入场从多个出生点中独立抽取的解释，但本轮没有保存出生点列表和选中索引，不能将该解释记为已实测闭环。

- 既有宿主回读 `build/m52/recovery-native-travel-host-01/after/scripts/fe/loc/Land.as:133–137` 将固定种子交给本类 `_rndSeed`；`rndNext:185–188` 是独立递推随机数，没有替换 `Math.random()`。同文件 `setGGToSpawnPoint:1274–1291` 先询问场景扩展的 spawn 接口；未处理时，仍用 `Math.random()` 从 `loc.spawnPoints` 选择出生点。因此地图种子相同，不保证原生入场抽签相同。
- 原生坐标换算为 `(point.x+1)*40,(point.y+1)*40-1`，并设置 `gg.dx=3`。两组最终坐标分别符合格点 `(3,7)`、`(28,19)` 换算后继续原生移动与落地的数值；**这只是数值吻合，未证明这两个格点都在本轮同一房间的实际 spawnPoints 中**。原生 `Location.as:670–675` 从房间对象 XML 的 spawnpoint 条目创建该列表，并考虑房间镜像。
- roomfix4 冻结 `RoomSync.as:249–256` 的 prepare 不携带玩家 x/y；`GameBridge.startSharedTravel:6204–6217` 走原生 `gotoLand(target,null,true)`；初次共同入场的 `TravelPlacement.place` 位于加入侧处理 grant 的分支（`RoomSync.as:468–470`），采用主侧已经公布的当前位置。未发现该路径把旧房坐标写入主侧本人。
- 双人主侧 `host.log:38/45` 的 `161,320`、`161.8,320` 明确来自 `ghost #1 spawned`，是收到的远端玩家快照位置，**不是主侧 gg 的早期坐标**。不能据此断言主侧本人曾从 161.8 被搬到 1161.8。
- 测试辅助没有提供相反证据：`autoHeal` 只调用治疗；旧 autoFollow 路径属于加入侧，并受 independentRooms 等条件限制；roomRole(true) 在计时前重置 freezeAI。两侧日志没有记录 moveTest/travelTest 执行。角色显示标签 `die` 本身不足以证明发生原生死亡或复活定位。

若后续需要排除剩余歧义，最小观察点是在首次原生加载结束、发送 seal 之前，保存一次实际 `roomId`、`spawnPoints`、`gg.X/Y`、`curCoord` 和 `currentCP`，再对照现有最终坐标。这里仅登记观察点，没有增加探针、固定出生点、修改玩法、编译或运行游戏。当前结论仍是：双人双方同入口已通过；跨模式同一出生负载尚未证明，不能直接把位置不同归为联机故障。
