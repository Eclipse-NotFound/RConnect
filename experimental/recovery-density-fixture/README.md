# 固定密集场景外部夹具

2026-10-22。仅修改外部准备与只读摘要；本次修订没有生产改动、JVM或AIR启动。准确祖先为冻结 `build/m52/motion-drivers-01/tests/SustainedDensityTestDoc.as`，原密集失败结果保持原样。[先前证据](../recovery-density-review/README.md)、[最初方案](PLAN.md)。

## 实现边界

保留尸鬼伤害、血翼姿态、五种炮塔感知/伤害前置用例。它们完成后才准备密集场景：

- 双方玩家统一到 `(161.8,960)`、朝右、零速度；只在准备时调用原生定位及 Camera.setLoc/setZoom(2)/calc，后续不逐帧钉住玩家/摄像机。
- 保留既有尸鬼和血翼，新增39血翼、39掠夺者，恰好80个原生敌人。12把LMG、27把p308c仍按原生factory/create/addVisual装备；原开火循环/参数不变。准备时统一敌人血量2000和朝向，避免前置伤害残留成为密集场景输入差别。
- 原生产快照省略不保证从加入侧对象链卸载旧本体，因此双方各自做一次外部清理。加入侧必须先通过80个宿主明确key找到80个不同本体，才移除名单外的原生敌人。判断结合真实Unit类型、原生fe.unit类、player/npc标志及阵营；不按阵营单项删除第三方代理，不调用死亡/奖励，不伪造生产包。玩家、宠物、镜像受击代理和其它模组对象保留并记录。
- prepare/ready/commit是外部测试握手。计时前检查80个实际key、类型/武器/方向/坐标、己方与队友实际位置、真实大写Camera.X/Y及显示变换；保持600ms稳定，双方一致才开phase0。45秒未准备好即失败，不静默开测。
- 七个8000ms阶段、完整 `frame()` 方法、原计数和流畅/网络/弹体移动/结束断言保持原文本。最终RENDER检查只多一个默认关闭的诊断调用，原判断原样保留。

`DENSITY INPUTS`仍保存实际原始格子/单位/背景。新增 `DENSITY FIXTURE`记录进入游戏时原始spawn、计时前位置/相机、原生80个敌人和武器详细属性、其它对象和背景。格子摘要用UTF16规范JSON的Adler32；离线审核重新读取完整格子并计算SHA256。摄像机字段已纠正为原生大写X/Y。

原始spawn或被清理的随机敌人可以不同，但必须留证；**计时前实际格子、角色、武器、背景、其它对象或相机有差别，则 `attribution_allowed=false`**。无法从“同种子”推断同场景。旧的两次未固定场景结果不允许作为新比较基准。

## 构建与运行入口

只创建一个新包，供旧版和候选使用相同外部SWF。复用旧驱动实际使用的公开声明SWC与stubs，生产类全部external；不把任何候选生产类嵌入驱动。

```powershell
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/recovery-density-fixture/check.py

# ROOT负责执行。仅--build会登记game资源并启动编译器；1GiB启动、512MiB终止，失败换新目录。
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/recovery-density-fixture/prepare.py --output build/m52/recovery-density-fixed-drivers-01 --build

& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/recovery-density-fixture/run.py --candidate build/m52/coop-bundle-04 --drivers build/m52/recovery-density-fixed-drivers-01 --output build/m52/recovery-density-fixed-control-01

& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/recovery-density-fixture/run.py --candidate build/m52/recovery-11 --drivers build/m52/recovery-density-fixed-drivers-01 --output build/m52/recovery-density-fixed-native-01 --reference build/m52/recovery-density-fixed-control-01
```

薄run入口直接调用既有 `tools/validation/run_motion_comparison.py --case density`，保留全模组、共享登记、独立桌面、唯一AppID、defer-visible、wait-host-world、独占AIR、原内存门槛和完整安装指纹。结束后新增 `fixture-audit.json`，不会改写原 `result.json`、COOP失败或性能门槛；另核全部模组错误日志与实际场景输入。安装/运行输入/驱动变动、诊断模式、阶段缺失或场景不同均不允许性能归因；原生检查失败仍失败。即使场景一致，也不授予整体性能或发布资格。

## 可选累计诊断

另用新输出目录加 `--diagnostic` 编译 `DensityTotalsTestDoc`。普通入口还是 `super(true)`，不创建观察器；诊断入口才使用第三个参数。没有生产回调、像素读回、采样器、逐帧JSON/文件写入或额外网络诊断消息。

每阶段最多1024个源本地引用、1024个显示实例、1024条接收流，每条流最多64个不同时间点；超限记录不完整。源只读12把枪gun.b并继续保留已观察弹体，累计真实位置/可见显示多帧、首次已接触、结束/开区间；接收合并owner/stream/seq和同时间点修订；显示复用既有RENDER循环。阶段末只写三层总量与寿命分桶。

不能观察同一帧中被gun.b覆盖的所有出生、不能关联源bullet与远端DisplayObject的私有wire身份、不能确定逐弹漏播。结果明确 `perProjectileCorrelation=unknown`，阶段边界会截断寿命。它能判断是否存在“源多数只见单个位置/收包拥有多个真实位置/显示总体不移动”这三类总量差别，不能凭数量巧合认定同一颗弹体。诊断结果不用于FPS对比。

## 当前验证

父会话已编译冻结 driver01，但首轮 `318bb41e51` 在准备阶段的 `arenaIdentity` 直接读取 `UnitBat.tr` 时抛出 ReferenceError #1069，未进入七阶段计时。原生 `UnitBat.as:10` 将 `tr` 声明为 internal，外部包不可访问，不能据此判定游戏本体没有该字段。父会话取消该轮并保留失败，不覆盖 driver01。

本次修订只把该读取改为 `GameBridge.probe`，不可公开读取时摘要明确保留 null；不猜测变体值。新增外层消息异常捕获，记 COOP FAIL、尽力通知另一侧 done、结束本侧，避免回调异常后静默空转。核查准备代码的其它直接读取：Unit/Pt/Obj 的身份、位置、血量、武器、链表字段，以及 Location、Camera、Ctr 所用字段均为公开字段；其余可选摘要字段已经通过 probe 读取。只读摘要中的 null 不能证明内部变体相同，这仍是证据边界。

父会话后续冻结 driver02，`2127b0febb` 已正常失败并清理：双方80个actor identity、己方位置和camera相同，宿主准备ok=true，但加入侧peer=null。准备代码查找 `[1,2]` 漏掉了实际宿主编号0。新修订在加入侧查宿主0，宿主侧按 `session.peers` 的真实连接id查找；排除自身 `myId`，按实际对象身份去重，仍严格要求恰好一个对侧。45秒准备超时及七个8000ms阶段、原门槛不变。必须用新的 driver03 和运行目录，不覆盖 02 失败。

已准备纯Python静态核查：原断言/七阶段条件/完整frame/原RENDER判断保持，安全读取与失败收尾存在，实际对侧id包含宿主0/排除自身/对象去重/恰好一人和45秒超时保留，Python语法、AS括号、准确声明与stubs指纹、地图hash口径和差异拒绝逻辑。**本次修订尚未编译，尚未证明握手在两版原生环境能完成。** 真实剩余环境差异会阻止归因，不能通过删除摘要或放宽阈值使比较成立。后续须使用新 driver03/新运行目录，README 上面的 01 命令仅为最初配方，不能覆盖其失败记录。
