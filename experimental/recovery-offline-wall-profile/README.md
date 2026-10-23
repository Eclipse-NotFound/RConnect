# EB365 墙面采集开销诊断副本

状态：**只准备源码；未编译、未运行、未部署**。这是供 CS 既有 1200 帧奔跑、密集射击夹具使用的独立诊断覆盖层，不是性能修正候选，也不授予游玩或部署资格。

## 来源与构建边界

- 唯一基底：`mods/RConnect/build/m52/recovery-offline-production-01`。
- 基底 SWF：`eb3653533cfb305bcca0b0cfe5e81bc306ea28fa400aae751ab7b5ae1cfa5fee`，即已部署 offline1。
- 仅覆盖 `src/rconnect/game/GameBridge.as`、`src/rconnect/game/WallImpactVisuals.as`；其余 76 个 AS 源文件、入口、Session、配置、资源及宿主继续使用上述冻结基底。不要混入普通墙面结构版本、ACK flush 或其它候选。
- `manifest.json` 保存基底产物、两个原源、构建回执、全部 78 个 AS 源及诊断覆盖层的指纹；`profile.patch` 是完整差异。
- `prepare.py --verify` 只核对来源与输出，不启动构建。准备时已验证：按逆序去掉每一处诊断变换，能够逐字节还原两个准确原源。
- 由主任务沿现有隔离构建入口编译；这里只交付覆盖源，不修改正式配置、部署文件、CS 源码或旧冻结目录。诊断版保留原 `VERSION`，测试须核对实际 SWF 指纹及下述 `schema`，不能只凭版本文字认定输入。

## 这两个位置实际测到什么

1. 原 `GameBridge.as:380–391` 的 `onPerceptionFrame` 先记录 `_sampleAt`，可能因土地切换调用 `_wall.reset()`，随后在非 `roomHold` 时调用 `_wall.before(loc)`。计时只包围原 `before` 调用，不把 `_sampleAt`、土地探测、reset、其他感知工作算进去。底图或房间身份改变、或 shadow 不存在时，`before` 重放墙痕、克隆底图，并扫描全房格子保存 hp/phis；其余帧主要检查底图身份。
2. 原 `GameBridge.as:348–372` 的 `onMirrorFrame` 在 `roomHold` 早退之后调用 `_wall.observe(loc)`。计时只包围该调用，不包含 mirror mask 清理、投掷物、角色动画或其他晚帧工作。`observe` **内部先再次调用 `before`**，再遍历 `loc.firstObj`，挑出原生三种弹丸，合并上一帧已离链对象，按真实命中迹象比较相关墙格。
3. EB365 的 `skipOfflinePresentation()` 只控制角色/身体效果观察；上述墙面两个调用不在资格开关内，所以首次尝试联网前仍运行。本覆盖层不读写该资格钩子，不改变首次 host/join 永久撤销条件。
4. `readTilePatch`、`scanTileReports`、`finishTileReports` 及 Wall 的 `report`、`receive`、`acknowledge`、`snapshot`、`checkpoint` 等还可能触发 `observe`。两个 `frame*Ms` 计时**不包含这些其它入口**；内部累计计数则覆盖启用期间的所有 Wall 入口。重绘入口 `redraw` 也可能重放/克隆底图。

两项外层毫秒可以相加，得到**这两个特定帧调用**的计时总和；不能据此声称获得全部墙面同步耗时，更不能把 `beforeCalls` 当作独立时间再加一次。`observeCalls - frameObserveCalls` 可识别额外观察调用，但不提供其耗时。`beforeCalls` 同时包含早期帧、每个 observe 的嵌套检查和其它调用。

## 夹具接入

沿既有方式取得准确 `RConnectMod.instance`，使用其公开 `game`。不要为读诊断数据调用 `readSnapshot`、`readWallPaint`、手工 `before/observe` 等会主动采集的接口。

```actionscript
var game:Object=rc.game; // rc 是夹具已确认的本实例 RConnectMod.instance
game.wallProfileStart(); // 在已确定的采样起点，只清诊断计数
// 由既有夹具自然运行 1200 帧；不增加逐帧日志或额外采集。
var wallStats:Object=game.wallProfileStop();
// 夹具自己的最终 JSON 增加 wallStats；同时保留帧数、连续墙钟和运行输入。
```

- 默认关闭。`wallProfileStart()` 创建新的累计窗口，不调用墙面 reset，不清标记、弹丸、房间或 Session 历史。
- `wallProfileRead()` 只返回当前标量计数的副本；调用者修改返回对象不会修改运行中的统计。无需每帧读取。
- `wallProfileStop()` 关闭计数并返回最终副本；再次 stop 不移动已固定的结束时间。停用后 read 保留本次结果，再 start 才重开窗口。
- 结果 `schema` 必须等于 `rc-eb365-wall-profile-r1`，`started` 必须为 true，最终 `enabled` 必须为 false。
- `startedAtMs` / `stoppedAtMs` / `windowMs` 标记采样窗口；`sampledAtMs` 是读取时刻。统计期间 `reset` / `roleChanged` **不会清诊断窗口**，其发生次数另记。
- 冷启动采样与稳定房间采样需说明起点；不要为了凑零次 rebuild 预先强行执行墙面采集。夹具 1200 帧与这两个回调次数分别记录，不能因 hold、空房间或事件先后差一帧而静默重置计数。

## 字段含义

| 字段 | 精确含义 |
| --- | --- |
| `frameBeforeCalls/Ms/MaxMs` | 早期帧的原 `_wall.before` 调用次数、累计/最大毫秒，异常退出也由 finally 计入 |
| `frameObserveCalls/Ms/MaxMs` | 晚期帧的原 `_wall.observe` 调用次数、累计/最大毫秒，包含其内部 before |
| `beforeCalls` / `beforeNoFront` | 所有 before 调用数 / 因无合法本房底图直接返回的次数 |
| `beforeRebuildAttempts/Completed` | 真正进入身份改变或 shadow 缺失重建分支 / 完成重放、克隆和 tileState 初始化的次数；不是原生 Grafon.drawLoc 次数 |
| `tileSnapshotCells` | 成功 before 重建中原有两层格子循环的访问总数；从循环最终 x/y 计算，无新增遍历 |
| `cloneAttempts/Succeeded/Failed` | before 或 redraw 调用 copyFront 的尝试、成功、原捕获异常次数；原日志与重新抛错保留 |
| `clonePixels` | 成功克隆位图的宽×高累计值，不是新增或常驻内存实测值 |
| `observeCalls/Active` | 所有 observe 调用 / 通过原有 active、shadow、front 守卫后进入采集的次数 |
| `objectChainVisited` | 原 firstObj 链遍历实际检查的对象总数，包含非弹丸；复用原 guard，单次最多 10000 |
| `objectChainLimitHits` | 原 10000 节点限制触发次数；诊断不改变限制 |
| `projectileObjects` | 上述链中三种原生 Bullet/SmartBullet/PhisBullet 的总数量，非唯一身份数 |
| `candidatesAvailable` / `carriedCandidates` | 原 candidates 数组长度总和 / 上一帧已离链而补入的数量；是待遍历集合大小，不声称每项都产生弹孔 |
| `tilesSupplied` | 有效 observe 收到的 tiles 数组长度总和，包含后续可能跳过的无效项 |
| `workCellsVisited` / `nonSolidWorkCells` | 原 work 集合访问总数 / 其中走非实体墙 discard 路径的次数 |
| `cellCompareCalls` / `changedCells` | 实际执行 scratchA.compare 次数 / 返回差异位图的次数，不新增逐像素计数 |
| `redrawCalls/roleChangedCalls/resetCalls` | 三个原入口的调用次数；包括原守卫可能早退的 redraw |

`objectChainVisited`、`projectileObjects` 与 candidates 是每次扫描累计，不能解释为场景里有这么多个不同对象。若链遍历自身抛出异常，该次尚未完成的遍历不会加入其后累计；应按原错误门槛判失败，不能从部分计数推出成功样本。

## 测量侵入及不改变的部分

- 每次被计时的帧调用增加两次 `getTimer()`、一个 try/finally 和少量计数；`getTimer` 是毫秒墙钟，短调用可能为 0，长调用可能包含系统调度/GC。它不是独占 CPU 采样，不据单个短调用定性。
- 起点在原调用前，终点在进入 `profileFrameEnd` 前。内部工作量计数成本包含在测得时间内，终点后的累计/max 更新不包含；整个诊断版帧开销仍包含两者。未启用时也多了状态检查，所以关闭统计的诊断 SWF 仍不能冒充字节不变基线。
- 对象链计数复用原 guard/数组长度，没有新增对象链遍历或按对象的计数写入；差异格子循环增加每格少量计数，重建/克隆增加几个标量统计。没有每像素统计、逐帧 JSON、文件日志、采样数组、额外位图或额外游戏对象。
- 默认不开启统计；开启后只持有一个固定字段对象。只有主动 read/stop 才复制结果对象；测试应在窗口外持久化。
- 原有 roomHold、active/front 身份守卫、dirty、房间字典、pending/ACK、随机选择、bitmap replay/compare、捕获错误日志及 throw 次序保持。计时 finally 不吞异常、不补偿错误、不重试。
- 因为测量本身有成本，后续用同一夹具、相同组合的原 EB365 对照总帧时序；本轮未测侵入量，不能声称“零开销”或把所有被测毫秒都视为可节省时间。

## 本次核对边界

已核原调用链、两文件完整差异、全部原源指纹、诊断可逆还原和准备脚本语法；没有编译器/AIR 证据。未改变/验证 CS 夹具、没有运行 1200 帧、没有输出性能结论，也未把普通墙面候选的既有测试资格移给此诊断包。后续编译、隔离运行、最终证据由主任务统一接续。
