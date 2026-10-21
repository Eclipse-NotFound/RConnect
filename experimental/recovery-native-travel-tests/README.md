# 冷固定图旅行外部测试（文本候选）

本目录只新增外部测试和编译配方。作者未调用 JVM、AIR 或本目录脚本；尚无编译、原生行为或性能通过结论。没有修改共享入口、冻结源码、安装文件或真实存档。

## 地图选择有原生依据

选择 `raiders`，不选择凭名称推测的地图。

- `game-reference/decompiled/1.02/src102/scripts/fe/GameData.as:230`：`id='raiders'`、`file='rooms_raiders'`、`locx='0' locy='1'`、`tip='story'`，没有 `rnd`。
- 同文件 `:644` 的 `stable_pi` 明确有 `rnd='1'`，所以不能充当固定图对照。
- `LandAct.as` 只有存在 `@rnd` 才把 `rnd` 设为 true；`Rooms/rooms_raiders.xml` 有实际固定房间资料。
- 运行时再次读取实际加载的 `fe.GameData.d` 和 `Game.lands.raiders`，核验文件、入口、固定标记；未满足即失败，不用参考源码猜当前宿主内容。
- `Game.Encounter` 没有 raiders 分支。返回地 `rbl` 是原生基地，本轮不触发遭遇重定向。

“冷”是全新隔离角色在本次进程尚未构造/访问目标 Land；不表示操作系统磁盘缓存或 Rooms XML 字节缓存已清空。不得为制造冷缓存删除系统缓存或真实存档。

## 三段真实旅行

双方由既有 runner 自动开新角色并在 `rbl` 连上；solo 在 `begin` 稳定后自行走原生 `gotoLand(rbl)` 完成同样准备。

1. 双方确认 `raiders.land == null && !raiders.visited`，宿主调用真实 `beginMission('raiders')`。
2. 双方恢复操作后，宿主调用真实 `gotoLand('rbl')`。
3. 再调用真实 `gotoLand('raiders')`，检查是第一次构造的同一个 Land。

没有更换种子函数、调用 `prepareMap`、给加入侧发测试旅行命令、写 `curLandId/crea`、手动删缓存、设出生坐标或恢复 checkpoint。测试自己的 `arm` 消息只令加入侧开始记时；提前加载必须由生产桥发出并实际 adopt。编译配方必须显式选择桥资格：`--require-bridge` 是候选模式；`--baseline-no-bridge` 是单独标记的 574D 无桥对照。没有默认跳过选项，两旗不能同时传入。

候选模式在本机准备、对侧 ready 握手、每次到达和双侧结果比较中均要求桥存在；首轮加入侧必须真实 adopt，不能因任一桥丢失而跳过断言。574D 模式反而要求双方桥不存在，并将 adopt 标记为 `not-applicable-574D-no-bridge-control`。solo 仍要求所选模式的本机桥状态，adopt 单独标记 `not-applicable-solo`，因为单人没有对侧计划。模式由 prepare 生成、冻结并哈希记录的 `ColdTravelBuildConfig.as` 编译常量决定，不按运行时探测结果自动降级。

全程不移动或删除敌人/地块，不禁用 AI，不强写暂停/退出计数/控制字段。测试角色仅 invulner；旅行前原生 healAll/关闭菜单是既有前置。原开场脚本可能留下活体 animOff，测量前仅对空闲活体调用一次原生 anim() 解除该已知测试准备状态，不在旅途中修改动画。

## 时钟及结果

`COLD NATIVE TRAVEL` 同时记录 `new Date().time` 和本进程 `getTimer()`：本机双进程使用墙钟比较，不能拿两端 getTimer 直接相减。

- `native-exit-first-frame`：帧观察到 `t_exit > 0` 的时间，是真实退出已开始的上界。
- `native-enter-call`：可用时包装生产 Game 桥的 adopt 回调，精确记录该回调开始；生产回调原样调用一次。
- `native-before-constructor-call`：同样记录 announce，位于 `new Land` 前；不等于整个加载开始。
- `production-plan-adopted`：加入侧生产回调真实返回计划；仅有 prepare 包或 UI 变化不能通过此断言。
- `land-visible-to-frame-observer`：后续帧首次看见 Land 对象变化；**不是精确构造结束**。
- `control-flags-ready-frame`：目标 `curLandId`、`land.act.id`、网络房间状态、原生控制、菜单、淡出与加载图均就绪的首次观察。
- 随后只读记录无输入的 `Ctr.keyLeft/keyRight`、原生 `walk`、坐标和 `dx/dy`；允许残余速度在 1000ms 内自然消散，但必须观察到连续三个真实帧水平方向静止（速度及位移均 ≤0.1）。所有早期漂移样本保留，不能算成按键响应；不归零速度、位置或控制字段。
- 再向 Stage 派发 A/D 的真实 `KEY_DOWN`，要求原生对应键为真、反向键为假；后续原生帧必须同时看到正确键、`walk` 方向、速度方向与超过 0.1 的对应位移。记录首次满足时的 `controlResponseWall`；仅外力造成位移不能满足整组条件。按键响应仍限原来的 1000ms，没有放宽为旅行的 95 秒保护。
- 经 Stage 派发 `KEY_UP` 后立即检查真实双键均清除；下一原生帧再次要求双键为假、`walk==0` 才输出 `TRAVEL RESULT`。松键后的原生惯性只记录，不要求瞬间速度归零。全程核对角色和 Ctr 身份，异常附上 `COLD TRAVEL INPUT` 的全部证据。

`flagsReadyWall` 仍是第一次控制/载入标志就绪的观察，`controlResponseWall` 包含新增无输入基线的三个帧及实际按键响应等待；两者不能混用。`inputEvidence` 单独记录基线、发键、响应、松键及后续帧；`inputReleaseVerifiedWall` 是验证结束时刻。输入探测不是纯加载内部 CPU 时间；新驱动的响应时间不得直接与旧驱动较少检查的响应时间比较，solo/574D/候选须使用本轮对应模式、同检查逻辑的新驱动。

`Ctr.active` **不作为就绪条件**：原生 `Ctr.as:558–560` 在首次鼠标按下时把它置真，`World` 在进入世界时清为假；原生键盘处理和玩家移动均不要求该字段为真。旧冻结 driver02 在 solo `begin` 等待此字段，形成“还没输入便等待输入激活”的测试自锁，`81e947a65b` 已由父会话取消并保留失败，不能据此归因旅行桥。新文本候选仅记录 `ctrActiveObservedOnly`，不强置它、不额外点鼠标唤醒它，真实 KEY_DOWN/移动/KEY_UP 断言原样保留。boot/travel/rest 每 10 秒记录一次 `COLD TRAVEL GATE`，列出所有实际等待字段，避免无证据空转；不扩大超时。

`TRAVEL RESULT` 保留现有 wrapper 的三行结果接口；`COLD TRAVEL COMPARISON` 记录双方各段时间和较晚一端恢复操作的总耗时。出生坐标取按键前的首次稳定位置，要求差距 ≤1 像素；若实际自然落地采样导致差异，要核对原生入口/生产锚点证据，不能无依据放宽。

候选冷进入时要求加入侧实际 adopt，且构造前回调早于宿主恢复控制。这只能证明加入侧没有等宿主全部完成后才开始；**不能证明两个构造函数的精确执行区间重叠，更不能单独证明双人已经达到单人耗时**。

## 加载显示检查

外部 RENDER 观察器只读查看原生 `vwait` 和 `rconnect-room-entry`/SATS 视图。若有网络等待视图，它只能含一个与原生加载画面相同类的素材，且文本、图案、剧情可见状态与原生一致，不能附加“房间交接中”文字。每段必须实际观察到原生加载帧，恢复操作还必须没有原生/网络等待状态。

不强求网络等待尾段必须出现，优化到没有尾段应合法。没有截图或像素读取，避免把绘图采样开销混进主要耗时；这是显示树检查，不替代另轮截图目检。若主侧长时间被同步计算阻塞而没有渲染帧，观察器不能证明阻塞期间实际画面更新。

## 父会话编译/运行接法

只冻输入（不编译）或加 `--compile` 显式编译；输出必须为新的直接 `build/m52` 子目录，不覆盖已有目录。配方默认只冻结输入，`--compile` 会按共享 `game` 登记串行运行编译器并跟踪/等待退出自有 JVM，不启动 AIR。

```powershell
python -B -X utf8 experimental/recovery-native-travel-tests/prepare.py build/m52/recovery-cold-travel-drivers-02 --require-bridge --compile
python -B -X utf8 experimental/recovery-native-travel-tests/prepare.py build/m52/recovery-cold-travel-control-drivers-01 --baseline-no-bridge --compile
```

配方只从冻结 `room-travel-driver-12` 取哈希核验过的外部声明与 Harness，取 `coop-bundle-04` 的外部游戏声明；只把本目录两份测试 AS 和生成的模式常量编入 EffectsDriver，生产代码保持 external。`inputs.json` 与 `prepared.json` 均记录 `driver_config.requireBridge/bridgeMode`；生成常量也在冻结输入哈希内。记录引用地图、原生 Ctr/UnitPlayer、实时输入、安装组合的哈希，编译前后不得变化。

父会话可使用现有 `tools/validation/run_room_travel_timing.py` 的 `--scenario timing`，其 `--land rbl` 正好对应准备位置；`--drivers` 指向所选模式编译完成的目录，`--candidate` 指向待测冻结 RC，`--game-candidate` 指向已经审计的隔离旅行桥宿主。候选 03 必须使用 `--require-bridge` 产物，574D 使用另一份无桥对照产物。solo 仅追加现有 `--solo`，走所选模式、同一原生路线。不得把未编译目录交给 runner。桥候选若仍没冻结，先完成父会话统一冻结和审计。

既有 wrapper 会把异常、COOP FAIL、超时、缺三段结果或安装变动判为失败。旧版自定义交接 UI 的预期失败必须保留，不能为了取得旧版时间把 UI 检查改绿；其有效旅行计时可另列为带功能失败的对照。驱动自身始终写 `performancePass:false`，避免把功能通过误当性能通过。

最终性能资格需同一宿主/模组组合的 solo、574D、桥候选按串行登记取得有效同路径数据并核对实际角色等级、地图尺寸、场景模式。不要并跑、关闭其他会话进程、放宽原超时或从单次变化给改善百分比。当前源采用既有 boot 240 秒/每段 95 秒失败保护；这些只是防挂死，不是加载性能验收门槛。

## 本目录没有覆盖

三段整图旅行不证明普通分房、隐藏背景房、缓存房杀敌/破墙/唯一掉落进度。继续复用现有 `entry-room` 测试，不复制其实现。

还未覆盖：不同角色等级的 autoLevel、显式入口/存档点、Encounter 重定向、加载中加入/断开/读档/死亡/取消、重复与迟到包、剧情挑战协同、恢复入口后的长时间稳定性。现有纯状态机和 RoomSync 组件分别补逻辑边界，不能代替原生试验。本次未给这些情况通过结论。
