# 密集场景夹具与已有两轮证据审阅

2026-10-22，只读审阅；没有启动 JVM/AIR，没有修改驱动、生产、原门槛或原始结果。

输入：`build/m52/motion-drivers-01`，实际入口 `ProjectileLoadTestDoc extends SustainedDensityTestDoc`，构造为 `super(true)`，所以 projectileLoad=true、profile=false。density SWF 直接来自冻结 `coop-bundle-drivers-04/density`。

两轮为回退574D `recovery-density-control-01 / 093598115f` 和候选11 `recovery11-density-01 / 7cf5adf2ec`。两轮都使用同一外部 SWF；原失败保留。

## 真正测试了什么

- 固定 random_mane 地图种子719355926，场景48×25格、1280×800、30fps目标、HIGH画质、缩放2/3。
- 前置实际测试尸鬼伤害、血翼姿态、五种炮塔感知/伤害。随后保留尸鬼和血翼，增加39血翼+39掠夺者，共80个夹具身体；12把真实LMG开火、其余27把p308c只用于显示/瞄准。
- 80个夹具单位都 disabled=true。原生 `Unit.step()` 在 disabled 时立即返回，因此这是身体/武器/同步/显示密集负载，不是80个正常AI同时作战。
- 宿主100ms Timer循环对夹具原生单位 setPos、改 dx/武器角度；进入开火阶段后每个宿主 ENTER_FRAME 对12把枪执行原生 step，按 frames%12轮流attack。射击请求率跟宿主帧率一起变化，不是恒定每秒投放量。
- 原七个约8秒阶段不变：phase0不启动这12把LMG；phase1—6启动。phase0仍包含80个身体和其同步。

## 两轮场景并不相同

| 计时前 DENSITY INPUTS | 574D对照 | 候选11 |
|---|---:|---:|
| 主侧单位 / 显示组 | 90 / 90 | 92 / 92 |
| 加入侧单位 / 显示组 | 177 / 90 | 181 / 92 |
| 加入侧 MirrorHitUnit | 87 | 89 |
| 宿主位置 | (161.8,960) | (161.8,960) |
| 加入侧位置 | (1443.6,320) | (161.8,960) |
| 环境炮塔 | 1 | 3 |
| 环境天角兽 | 2 | 0 |

两轮均有80个夹具单位，但额外随机敌人不同，加入侧所在位置也不同；RV视野和附近可见对象由此不能视作同一负载。177/181包含碰撞代理，不等于177/181个可见敌人；共享同一显示对象的代理没有增加显示组数量。固定地图种子没有固定所有环境敌人或双方入口位置。

因此旧对照主侧约9—10fps、加入侧约7fps与候选11约8fps不能直接解释为某项生产算法的纯增益或退化。尤其不能用总单位数误算双倍绘制。

## 额外测试开销

没有逐帧像素读取、截图/PNG、采样器或编解码微基准：profile=false，实际日志也无 PROJECTILE PROFILE / PACKET CODEC PROBE。

存在以下额外成本，但当前未分别计时：

1. 加入侧每次RENDER遍历整个 `grafon.visObjs[2]`，用类名筛弹体、遍历祖先可见性，并给每个符合对象分配 `{x,y}` 保存到弱引用Dictionary。只在phase>0执行，不读像素，也没有视口边界检查。
2. 每份unitsync到达后遍历 units/weapons/events/flight.frames，累计轨迹数、结束后点数与类别。netMs包含这段夹具监听成本。
3. 每帧记录一个时间间隔、一次目标查找与角度toFixed；宿主每帧的原生枪操作及每100ms的80单位驱动。
4. sceneInputs在计时前构造1200格、所有单位/显示组的大JSON并写日志；不直接计入阶段，但不能排除遗留分配影响后续GC。阶段末还有排序、摘要日志及计数重置；没有逐帧大JSON写盘。

phase0关闭LMG驱动和RENDER弹体扫描，574D仍仅53帧/约8秒、p95=203ms。这证明低帧率不需要这两项额外开销才能出现；不能反过来声称夹具开销为零。

## 指标边界

- frames/p95：驱动收到ENTER_FRAME的整周期间隔，涵盖模拟、显示、网络事件、运行时及系统调度；不是CPU自耗时。
- cpuMs：加入侧Stage ENTER_FRAME优先级+200000到−200000之间的墙钟耗时。原生MainMenu.mainStep也在Stage上，包含此段内的游戏和模组回调；不涵盖全部RENDER/EXIT_FRAME、Timer、socket解码或所有其它DisplayObject回调。不是进程CPU占用。
- netMs：TcpLink.MESSAGE优先级前后之间的墙钟耗时。TcpLink在dispatch前已经执行协议解码，因此不含JSON/二进制解码，也不含网络传输等待；含生产监听和本驱动监听。
- viewMs：GameBridge.onVisForceFrame内有计时边界的部分；前面的mask clean与部分早退不计。不是完整画面绘制耗时。
- motionMs：GameBridge.tickFrozenAnims内的镜像位置/动画更新。可能与Stage计时重叠，不能直接相加当总成本。
- cpuMs/netMs/viewMs/motionMs及其max均跨阶段累计，nextPhase不清零。对照每阶段差分：Stage范围约1.58—1.68秒，即29—31ms/ENTER；motion约10.6—12.3ms/调用；view约2.3—2.8ms/调用、每阶段约两次/帧。差分后也不能解释余下整周期时间去了哪里。
- packets/maxPacket只统计unitsync，不是全部worldstate/TCP到包。轨迹events和visible均可能多次统计同一弹体，不是唯一发射数。
- moving是“同一个显示实例两次RENDER之间x/y确实变化”的次数；只需大于0，不检查路径完整、首显延迟、停顿和原生寿命。

## 候选11三项moving=0不是已证实误报

按densityProbe从0计，phase2 / phase4 / phase6分别为 visible=442/398/408、moving=0。phase1/3/5也只记录moving=4/3/4；574D对应六段为307/382/322/275/311/353。

检测仍适配11：ProjectileVisuals.createVisual把实际弹体直接加入 `grafon.visObjs[2]`，a.vis在生命周期内保留，tickBeam直接写这个对象的x/y；没有改成父容器移动或每帧替换实例。故不能以身份/坐标口径变更把失败抹绿。

但源侧没有逐弹飞行样本摘要，接收侧也没有逐event→显示对象对应记录。574D普通NPC弹体使用本地时间的速度/端点推演，11普通弹体使用真实frames及原生结束时刻。旧版出现多次视觉位移，不能单独证明这些位移在原生源端也真实存在。当前只能判定11这三窗没有观察到同一显示实例的位移；不能区分源端即刻撞墙/只有一帧、有效轨迹晚到、接收显示跨过完整飞行段。原失败保留。

## 关键指纹

- motion-drivers-01/prepared.json：`fee33fab5ac5b87ae953545a88c1ccbe99c195f36544549cc57e8812925a54a4`
- density/EffectsDriver.swf：`c912242970d633970e924fde71f5279c04554bb2144408b9e2392e88e70144d9`
- tests/SustainedDensityTestDoc.as：`0da13f6b36b792ff1572802af2d8ad291f96bbe42f575f91f3cefb1b542ceb65`
- 574D result.json：`e226d847365412dae184fd52c95fd51bc49641ad6446ec106217637555b32230`
- 11 result.json：`3b56b74566ee340a556e3c2e80aa62bd5bd234132c8e97e86b656e3967d858b0`

下一步仅准备阶段的可比性修正与可关闭诊断，见相邻 `../recovery-density-fixture/PLAN.md`。上述两轮不重写、不补造资格。
