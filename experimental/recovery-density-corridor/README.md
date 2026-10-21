# 密集开阔射击走廊：独立外部夹具

2026-10-22。状态：源码及纯 Python 静态检查完成；**未编译、未运行 AIR，不能称功能或性能通过**。这是新对照场景，不能用其结果抹掉旧 control03、candidate12 的七阶段流畅失败或上一轮六个 moving=0。旧审阅在 `../recovery-density-fixture-review/README.md`。

## 变更范围

准确祖先为冻结 `build/m52/recovery-density-fixed-drivers-03`，manifest `e0e9647f3fed9fa723518d8db6f1c67c2e44f8cfa55402be9d68d43755a10ebf`。`edits.json` 枚举 SustainedDensityTestDoc 仅六处准备/准备摘要插入；完整 frame 方法、原 RENDER 移动判据、原断言、45秒准备超时、七个8000ms阶段及其网络切换逻辑都保持。原尸鬼/五类炮塔用例仍先完成；之后才执行一次走廊准备。DensityFixture、可选累计观察器和普通/累计入口从冻结03逐字节复制。

新增 `CorridorFixture.as` 仅在计时前调用：

- 保留同一个原生 Location、1200个 Tile 对象和80个敌人；使用原生 Tile 构造默认值复制到原 Tile，原生 `mainFrame("A")` 建一格厚周边，内部46×23格完全无碰撞/水/门/陷阱/楼梯/平台。空区为世界坐标 x∈(40,1880)、y∈(40,960)，底部地板顶960仍支持原玩家出生点。
- 明确移除这间测试房的可选原生静态对象：容器/门/存档点/XP/loot/area/旧弹体粒子；使用公开 `loc.remObj`，同步清空对应拥有列表。不会调用死亡、掉落、拾取、激活、保存或发送伪伤害。存档点制造的 shelf 随全部地形恢复为明确定义；背景装饰和出口箭头为零，底图固定 `tBackWall`。
- 保留玩家、80个敌人及联机的 RemoteDamageUnit/MirrorHitUnit/PlayerMineGate。未知活动对象或额外碰撞单位使准备失败，不静默删除其它模组未知代理。原存在的未上链且 NaN 坐标的 UnitPet 保留，不破坏玩家持有的宠物引用。新发出的 Part 属于动态观测，仍由完整场景摘要记录，不能当静态对象身份。
- 原生 `world.redrawLoc()` 只调用一次，清除旧墙面和背景 bitmap；随后使用原固定位置/摄像机。两侧各自完成准备，通过至少600ms稳定期和原80-key握手才计时。任何旧快照重新创建静态对象、污染地形都会阻止开始，不逐帧重新清理或修改生产。
- 12把枪仍是原生 Weapon.create/attack/step，伤害/弹速/寿命/碰撞代码不改，原80本体+12枪+7阶段刺激保留。**新增准备中设 findCel=false**：原生 Weapon 默认 true，此时 actions 会追 owner.celX/celY，原驱动写 forceRot 实际不能控制朝向；false 使用原生 forceRot 分支，使既有逐帧写入的角度生效。再调用公开 owner.setWeaponPos、gun.animate/getBulXY 初始化实际枪口。这个准备差别必须由新旧版本同字节重跑，不是旧场景数值的延续。

走廊减少静态背景/交互对象，同时让弹体活跃得更久，因此改变了工作量；只回答固定80敌人与真实密集长飞行的同步/帧推进，不能代表所有原随机房性能。原测量中的 netAt 首次跨 prepare→load 的错误统计仍未修改；首个 netMs/max 无法用于 CPU 归因，见旧审阅。普通场景门槛不因此放宽。

## 原生多帧路径的静态证据

`geometry-proof.json` 保留公式、边界及参考源码指纹。原生 AllData 的 LMG speed=200；Weapon.shoot 无重力弹速乘随机[0.8,1.2)，每个 native step 位移上界240。NPC LMG recoilUp 为 int：recoil5 /2→2，再×0.2→0；其余实际前提在准备中逐枪核验，未满足立即失败，不替换值凑条件。

原刺激角度为 −π/3±0.2，加上已检查 mazil≤30、deviation=0、devMult≤1，角度包络为[−1.509,−0.585]弧度。在检查过的实际枪口 x240..460、y860..950 范围内，三步最大720位移的保守包络为 x240..1060.12、y141.37..950，完全落在空矩形内部；最早边缘接触距离保守下限821.57。Bullet.step 对高速位移分段调用原生 run，仍沿同一段线碰撞，不会把三步合成“瞬移至终点”。80敌人 disabled 会被原生 run 的单位碰撞过滤；双方玩家位于 x161.8，处于向右上枪口锥后方。

这证明有真实、无需延长寿命的多帧飞行空间。它不证明远端最终像素一定可见、所有回调都观察到出生、或 FPS 达标；原七阶段 moving/帧数断言仍需原生测试。源 `gun.b` 观察覆盖和三层数量无法逐弹对应，诊断 overflow 仍会标不完整。

## 构建与运行（由 ROOT 执行）

下面命令都从 RConnect 根目录执行；输出必须是新的 `build/m52` 直接子目录。普通和诊断分别冻结，失败目录不覆盖。

```powershell
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/recovery-density-corridor/check.py
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/recovery-density-corridor/prepare.py --output build/m52/recovery-density-corridor-drivers-01 --build
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/recovery-density-corridor/run.py --candidate build/m52/coop-bundle-04 --drivers build/m52/recovery-density-corridor-drivers-01 --output build/m52/recovery-density-corridor-control-01
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/recovery-density-corridor/run.py --candidate build/m52/recovery-12 --drivers build/m52/recovery-density-corridor-drivers-01 --output build/m52/recovery12-density-corridor-01 --reference build/m52/recovery-density-corridor-control-01
```

`prepare.py` 是原注册构建入口的薄适配，锁定旧 helper 指纹，复用其共享 game 登记、隐藏 JVM、1GiB 启动/512MiB终止、180秒限时、冻结前后指纹和注册退出后 inventory。只有 `--build` 才启动编译；本次未执行。`run.py` 委托原密集运行器，继续使用全模组/完整22输入、独立桌面、唯一AppID、defer-visible、wait-host-world、独占AIR与安装前后核验。通用工具未修改。

新增 `DENSITY CORRIDOR` 准备记录包含完整碰撞/静态tile、移除对象、实际枪口/武器参数与准备耗时；薄 audit 核验两侧真实地形hash和明确零静态对象，再与同字节新对照比较。原完整 fixture-audit 及其保守差异/失败不抹掉。静态共同输入与 Part 等动态剩余观测分开展示，不赋予整体性能资格。

- `--diagnostic`：原03的 DensityTotalsTestDoc，三层有界总量，默认关闭；原64点上限及 overflow/complete 行为保留。
- `--profile`：复用 `motion-drivers-01` 的原生 ProjectileProfileTestDoc（super(true,true)）和既有采样逻辑，不增加采样器。与 --diagnostic 互斥，记录 diagnostic_only=true；只做少量 CPU 归因，不能拿采样帧率代替普通门槛。

尚未编译的具体风险：新的准备调用是否适配当前全部22模组、静态对象是否被旧快照重建、原生枪口参数门槛是否满足、重绘后视觉是否与定义一致。必须先跑普通对照，不能从纯 Python 括号/几何检查推断 AS 已编译或游戏可用。
