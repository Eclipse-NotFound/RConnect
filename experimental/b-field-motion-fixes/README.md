# B 插值呈现轻量路径实验

2026-10-25。独立覆盖层，精确基线 `build/ab/b190-field9-build/src`。**实验已放弃，不进入产品，不继续追加护卫或修夹具。** 根会话motion18已编译并完成AIR微测，没有收益，角色与武器的末态等价检查也未通过。此目录仅保留失败证据与源码，不能作为可用覆盖层合入field候选。本子任务未运行AIR/JVM，根会话的产品覆盖层未修改。

## 结束决定与真实证据

实测目录：`build/ab/b-motion18-micro-01`；准确候选SHA256 `480f499e2cdf67ecfea29718f2ae3b628ebcbc34b74850f50a3ea159aa53151d`，来源指纹 `d86ccf90c6cefd4c9ab5aaf1971b72379c62e5dc8fb92b2331c71a7fc338d17a`。`result.json`显示主侧32项过、2项失败，加入侧8项过，无FATAL。两项失败是下表的body/weapon末态配方及像素合并判定。

| 真实对象 | 每轮次数×轮数 | 快速路径命中 | full总耗时 | guarded总耗时 | 每轮equal |
|---|---:|---:|---:|---:|---|
| visualPlayer身体 | 500×8 | 全0 | 995ms | 1062ms | 全false |
| vislmg轻机枪 | 500×8 | 全0 | 60ms | 93ms | 全false |
| 实际开火生成的visualBullet | 1000×8 | 每轮1000 | 27ms | 32ms | 全true |

逐轮证据为同目录 `motion-body.json`、`motion-weapon.json`、`motion-native-fired-bullet.json`，检查日志为 `host.BStartupDriver.log`。人工构造树、变色/滤镜/替换子节点及指定原生图元的基础检查通过，不能用这些通过掩盖真实身体和武器检查失败。

身体/武器的equal=false可能来自自动实例名或微测两副本的末帧比较，尚未定位；不能直接宣称产品显示损坏，也不能宣布等价通过。即便忽略该未解问题，身体和武器没有快速命中，弹丸虽然命中且相等也未测得省时。因此停止这条优化，不为它扩大复杂性或再占实机修夹具。总耗时是短批次毫秒计时，不能外推为整场游戏帧率差；目前没有任何性能准入资格。

历史编译失败保留：motion16因同文件测试辅助类失败，随后拆出 `MotionCheckClip.as`；motion17因Flex不承认try内return/finally的完整返回路径失败，随后将same/benchmark结果移至finally之后返回。motion18成功编译不改变上述放弃决定。

## 要验证的切点

ClientReplica 已区分插值与离散确认，对 NativeFields 使用 motion，但身体、武器及弹丸仍逐节点 VisualPose.apply。Scene 的普通实体已有 motion 路径。本实验只研究客户端这些显示的重复完整导入，不动源帧采集、物理、事件队列或播放时钟。

不能仅将 apply 换成 motion。完整 apply 每次会恢复颜色/滤镜、停止时间线、确认子节点及删除过期托管节点；本机显示可能在两次确认之间改变。此外 MovementPrediction.sample 基于最新确认，未必是屏幕当前左帧，虽然调用 applyPlayer(...,true)，其离散姿态仍可能与现有显示不同。

## 改动与保守边界

- VisualPose新增 `motionIfReady(display,pose)`；原 capture、apply、motion 均未改。该函数只接受已有完整apply记录的节点。
- 每次检查**当前本机值**：动画帧与是否仍播放、滤镜、颜色（alphaMultiplier由motion直接恢复）、混合模式、缓存位图开关、Bitmap采样选项、应存在的子节点及过期托管节点。无“上次相同所以本次也相同”的捷径。
- 条件通过时，在同一次递归中仅写矩阵、透明度和可见性，避免额外一次整树遍历。任一子节点失败时，外层立即用原完整apply处理整棵树；此前只改过几何，外部渲染不会看到中间结果。
- TextField、动态绘图配方、带像素配方的子树全部保守回原apply。无法读取MovieClip播放状态也回原路径。
- ClientReplica仅在插值、原显示已完整应用且仍在当前层时尝试。人物epoch/roomEpoch、武器id/epoch、首次创建及重新挂载不走快速路径。已有全部离散确认仍完整apply。
- `checkedMotionApplications/checkedMotionFallbacks`只计尝试结果。它们不是性能结论。

重要API约束：`motionIfReady`返回false后，调用者必须在同一同步调用内执行 `VisualPose.apply(display,pose)`，不能把false当作“什么也没有改”。目前新增调用处均通过 `ClientReplica.applyPose`统一保证。

## 已核对的本机显示写入路径

1. `ClientReplica.applyPlayer`中的原生 `Unit.setVisPos`会改身体根x/y/scaleX，weapon/projectile调用也会先改根位置/角度；这些正是motion负责恢复的字段。
2. `MovementPrediction.sample`可提前采用最新确认的人物/武器视觉，之后正常呈现又回当前左帧。护卫检查真正的帧、颜色和子节点，不能用interpolated标记断言离散状态相同。
3. `CharacterState.apply`可建武器、updVariant/setAmmo，创建原生Effect；接着该确认帧完整apply。首次/换武器或显示引用改变也无法绕过完整导入。
4. 原生 `Sats.getUnits/offUnits`创建和移除SATS副本，鼠标事件修改副本滤镜；不能把这些副本写入误说成玩家身体本身变化。当前优化只接玩家/武器/弹丸；父显示层或SATS副本的变化不被此护卫擅自恢复。每次motion仍恢复原apply负责的根及子节点visible/alpha，不新增或取消mask处理。
5. 原生 `PipPageApp.close→gg.refreshVis`会跳角色osn时间线；客户端权威菜单接口可能拦截具体操作，不能据此假定显示永远不被碰。直接goto/play、更换子节点、滤镜/颜色改变都由测试注入覆盖。
6. `access.view.prepare()`在render开头执行，`access.weapons.present()`在离散render末尾执行。其接口属于独立模组，本实验没有改写接口或假定它们永不改显示；下一次尝试仍读取当前值。

## 正确性检查入口

仅在隔离测试程序中调用：

```as3
VisualMotionChecks.run(access, check);
```

测试源码须同时包含 `VisualMotionChecks.as` 与 `MotionCheckClip.as`。后者为独立公开辅助类，保持解析名 `authority::MotionCheckClip`；Flex 的 source-path 编译不接受两项外部可见定义放在同一源文件中，即便第二项声明为 internal。该拆分仅修正测试类组织，产品接线没有变化。

检查包括首次完整应用、连续位移/旋转/透明度、根与子节点颜色/滤镜、混合/缓存、更换或移除子节点、删除托管子节点，以及文本/动态绘图/像素保守回退。另用真实 `visualBullet/visualNumb/visReplic/visReplic2` 对比完整配方和最终像素，并检查本机重新play/goto后仍完整恢复。测试只改独立显示副本，不推进真实对象。

真实角色、武器和弹丸可在既有探针中传其**已观察到的**vis：

```as3
var result:Object=VisualMotionChecks.benchmark(nativeDisplay, access.visualClass, 250);
```

先预热，随后8轮交叉先后次序；每轮用16个预制位移配方分别完整apply与尝试motion。输出fullMs/guardedMs、快速命中次数、末态配方及像素相等。不能把一个全是fallback的样本当作优化成功。计时使用毫秒，样本太小全零时增加repetitions，但保持短批次和既有测试占用登记。

这些检查已由根会话在motion18执行，结果见顶部：基础检查通过，真实身体/武器末态等价失败。像素比较超过512×512有效区域会明确报错，不静默裁切。微测只看CPU导入成本，无法代替密集联机总帧间隔、GPU渲染、内存和暂停/换房/换武器回归。

## 收益判断与整合

护卫仍递归读取滤镜和ColorTransform，其getter会产生临时对象。原预期是省去原生重复setter、stop、逐父节点live字典等开销；motion18未观察到收益，因此已经放弃产品接线，不再进入密集双实例性能对照，也不扩大复杂度。

`experiment.patch`是相对field9的两文件变更。VisualPose的UI文字末尾矩阵修正、ClientReplica的进度条/投掷物代理均不在本覆盖层；如进入后续实验，必须三方合并，不能整文件覆盖较新field14。测试类不必打包生产。
