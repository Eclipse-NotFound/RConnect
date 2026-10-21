# 房间导入成本：诊断提案，暂不修改恢复语义

2026-10-22。基线是冻结 **recovery06 `3f828464…81d1`**，Game host01，driver12 大图双人 `2ca638e617` / solo `8451331768`。详见[已补单人对照的时间轴](../recovery-native-travel-tests/large-scene-review.md)。本目录不是已实现、编译或通过验证的优化候选；未改 integrated、公共驱动或安装版，未启动 JVM/AIR。

## 判断

重复创建确实存在，但现有证据不足以把“复用本机已经生成的敌人”当作安全小改动。先拆分875/961 ms单位导入和随后长帧，确认构造占多少，再决定是否值得引入更完整的重用契约。不能把875/961 ms全部认作构造成本；消除这部分也不足以解释首次7292 ms的原生结束后尾段。

不提交臆造的旧新组件绿灯：本轮没有可确认等价的优化算法，也没有新旧运行结果。以下是确切调用链、安全反例及下一轮最小诊断插点。

## 已确认的重复链及边界

1. 原生 `Game.enterToCurLand → new Land → enterLand` 已生成本机原生单位并初始化显示。大图首次创建/进入累计主4071、加3878 ms；solo3874 ms。重访创建为0–1 ms，因此重复构造并不全来自随机地图重新生成。
2. `RoomSync.receive(grant) → restoreCheckpoint(..., foreign=true)` 先 `roomRole(false)` 清理镜像状态，再移除本地可替换单位并 `_units.clearRoom(loc)`。遍历快照时重新 `new cls → putLoc → addObj → restoreUnit → AnimationAccess.receive`。首次和重访日志都是 `foreign:true, retained:false`。
3. `applyUnitsSync`再次遍历权威快照，建立位移记录、冻结原生AI、创建 `MirrorHitUnit` 和遮罩别名。代理是额外命中对象，其数量不能冒充“重复敌人数”。
4. 随后 ENTER_FRAME 的 `tickFrozenAnims → UnitPresentation.apply`首次建立显示状态，再次收到姿态、炮塔状态；RENDER 的 `onVisForceFrame`还执行遮罩和显示树相关工作。首次2670 ms长帧发生在 grant 已完成以后，现有阶段计时覆盖不到它。
5. **不能声称武器必定被创建第三遍：** `NativeRoomState.restoreUnit`与 `UnitPresentation.apply`均会在武器 id/variant匹配时复用对象，仅不匹配时调用工厂。需要记录实际分支次数，不能按方法调用次数计武器重建。
6. `roomRole`先 reset显示，再令 `_lastLocRef=null`调用 `resetBaselinesIfWorldChanged`；后者重复清理部分容器。但第二次大多已空，只有静态重复证据，没有可观收益证据，不优先做这一微调。

## 为什么直接复用还不安全

| 源码事实 | 复用相较当前新建路径会留下什么 |
|---|---|
| `NativeRoomState.scalars`只保存数值、字符串、布尔和简单数组；非简单对象数组、对象/函数/XML引用不保存。`restore`只写快照中有的字段，不清除其余字段。 | 旧 `celUnit`、含 Effect 实例的 `effects`、脚本对象等可继续挂在旧实体上；新构造会重新初始化这些字段。 |
| `RConnectUnitAccess.capture`存储 `mapxml`字符串，但 `restore`不重设该XML。现路径把XML交给构造函数，并在 `putLoc`据它创建 `scrDie/scrAlarm`。 | 单靠 class/id/近邻位置匹配，不足以证明脚本和来源XML相同；移交房间后重新成为权威时可能触发旧脚本。 |
| `NativeRoomState.restoreUnit`按快照 gun槽位恢复，没有删除旧对象多出的非快照子对象；非简单 `childObjs`本身不由 scalars覆盖。 | 旧附属武器/效果引用不能靠标量恢复自动消除；同类同id也没有完整重置保证。 |
| `NativeRoomState`故意不恢复 `in_chain`、可视对象等；`Location.remObj`解除链表并移除显示。`restoreUnit`仅在 sost≥4时主动移除，不负责把旧离链对象重新加入。 | 把旧尸体/离链对象当成活体重用时，血量状态可能恢复却仍不在原生链或显示树；不能简单取消foreign清理。 |
| `ObjectIdentity.resolve`初配对允许同id/class内150像素最近邻；原房间key清空后并非原生出生唯一标识。 | 同种相邻敌人可互换对应关系；对于只恢复标量、保留私有对象状态的复用方案，这会放大错配影响。 |

上述是原生源码和RC恢复算法的可确认边界，不是声称已经运行过新的反例。保持当前完整恢复，死亡、破墙、容器、唯一掉落和分房规则不因此改变。

## 最小诊断插点（独立诊断构建，不用于性能验收）

仅对一次选定的 room key/epoch启用；在方法内累计整数，**不逐单位写文件、不写完整快照**，末尾统一一行。异常时记未完成阶段再原样抛出，不吞错误。保存原有 checkpoint/restore诊断。默认关闭；收集完首次、返回、重访三次即关闭。

| 插点（recovery06） | 需要的累计时间、计数 | 要区分的问题 |
|---|---|---|
| `GameBridge.restoreCheckpoint`开始→`RoomTerrainView`构建后→`roomRole`后 | `preTerrainViewMs, roleMs`；入场 `loc.units.length` | 当前role101/115 ms混有30000格地形预采样，不可全归镜像清理。 |
| foreign清理循环前后 | `removeMs, removed, keptPlayer, keptSceneHit, keptFriendly` | 实际移除了多少原生身体；清理/显示移除是否重。不要只记数组长度。 |
| 每条 `s.units`的 `_units.resolve`前后 | `resolveMs, resolved, missing, skippedSceneHit` | 是否构造占主导，还是初配对的重复扫描。原顺序、距离阈值和键绑定全部保留。 |
| `getDefinition`、XML创建/补tr、`new cls`、`putLoc`、`addObj`分别前后 | `classMs, xmlMs, constructorMs, putLocMs, addMs, created`；按类累计数量与时间，限原生类名总数 | 把构造含显示初始化与脚本/碰撞定位、显示挂接分开；不去调用第二次原生方法作测量。 |
| `NativeRoomState.restoreUnit`、`AnimationAccess.receive`/`TurretDisplay.receive`前后 | `restoreUnitMs, poseMs, bodyMs`；死亡/活体快照计数 | 标量、武器恢复、姿态是否比构造更重；记录三段时不要相互包含。 |
| `NativeRoomState.restoreUnit`武器分支 | `gunVisited, gunReused, gunCreated, gunRestoreMs` | 实际武器替换次数；读到的快照已有id和variant可直接计数，不新增probe。 |
| 后续多余单位清理、掉落移除/重建、`applyUnitsSync`各自前后 | `pruneMs, pruned, lootMs, mirrorInitMs` | 防止把875/961 ms、effects71/58 ms都错误归给敌人构造。 |
| `applyUnitsSync`中 `new MirrorHitUnit`、`_mirrorMasks.prepare/register` | `hitCreated, hitConstructorMs, maskInitMs` | 身体与伤害代理两套构造分别计数，保留碰撞/SATS行为。 |
| `UnitPresentation.apply`首次 `states[u]==null`及武器不匹配工厂分支 | 首次姿态数量、`presentationMs, presentationGunCreated` | 首帧是否又进行了有成本的显示初始化；不能仅凭apply调用推测造枪。 |
| grant完成后的前3个 ENTER_FRAME/RENDER | 同一epoch记录原生帧开始/结束；RC `onMirrorFrame`与`onVisForceFrame`自身时间；现有 `presentationTiming`各项增量 | 定位2670 ms长帧。在RC回调外的时间仍标“未归属”，再决定是否需要原生/外模组采样，不能倒算成CS。 |
| `RoomSync.commit`与grant解析 | checkpoint、RoomCodec.pack、RoomCodec.unpack、send各自包围计时 | 把主侧1000/865 ms和加入侧2237/2307 ms中的编码成本单独确认；原校验/协议/频率不变。 |

所有插点应以选定epoch关联现有 `TRAVEL CLOCK/RESULT`。只用 `getTimer`差记录本机函数，跨进程总恢复时间另由同一请求墙钟和原生按键响应测量；不相减两个进程的 getTimer。诊断开销会影响结果，该构建只定位，不与无诊断solo直接作性能门槛比较。

## 提交优化候选之前的必要证据

- 若主耗时是新单位构造，再评估**可证明干净且有原生唯一身份的初生单位**白名单重用；未知类、已有战斗/效果、重访及权威交接保持原路径。不能仅以class/id/距离或同地图种子放行。
- 若主耗时是快照恢复/显示，则按实测最大的单段选等价消重，不预先实施批量延后显示、分帧放行或跳过完整状态。
- 真实旧新回归需从同一原生保存/快照分别加载：活敌武器变化；已死蜘蛛地雷/炮塔；尸体；破墙与墙后敌人；开/关容器且有/无剩余掉落；双方先后离房、重访、权威交换；隐藏房；SATS。比较对象key/死亡/碰撞链/交互/唯一掉落和原生攻击结果，再验到操作响应的耗时。仅标量JSON相等不足以证明原生引用及显示等价。

本目录保存来源指纹于 `inputs.json`，便于之后按方法制作测量delta；未制造测试通过或节省时间估计。
