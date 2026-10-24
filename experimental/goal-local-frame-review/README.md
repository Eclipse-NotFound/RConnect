# 普通房跳跃：显示回调之后的 CPU 定位

仅诊断。基于实际 `goal-three-issues-native-jump-baseline-01` / `74932502cf`，产品保持 `78C052…`，宿主保持 `A796827…`。本目录没有修改生产、旧驱动或共享运行器，也不启动 JVM/AIR。

现有原始帧数据按同帧 ENTER/RENDER 和下一 ENTER 配对：

| 侧别 | 配对数 | ENTER→RENDER 平均 | RENDER→下次 ENTER 平均 |
|---|---:|---:|---:|
| 主侧 | 363 | 18.893 ms | 30.617 ms |
| 加入侧 | 330 | 18.636 ms | 35.809 ms |

加入侧最长 170 ms 周期由 12 ms 帧内、158 ms 帧间组成。帧间也收到了大部分消息回调：主侧 234/236 条 playerstate；加入侧 478/479 条 worldstate、75/75 条 unitsync。回调计数不是处理耗时，相关性不能证明网络是根因。原计时 view/motion 不覆盖完整帧，更不覆盖全部帧间。全部窗口都是私有桌面的 inactive 窗口，不能直接推广为玩家前台 FPS。

## 最小接入

- `NativeJumpNetworkTestDoc.as` 与已跑普通房驱动逐字相同：原生键盘、18 秒、6/6 检查、握手、场景/敌人冻结和截图禁用状态全部保留。
- 仅 `NativeMotionProbe.as` 增加外部诊断。从 `recovery-after-render-sampler/tests/SustainedDensityTestDoc.as` 复制 `diagBegin/diagEnd/diagClose` 三个采样方法及 `diagAfterFrame` 时刻观察器；只按根明确授权改变一处 selection 表达式，其余方法原文相同。没有移入旧密集场景。
- 私有诊断 phase 固定使用阶段 0：测量开始后达到 1、3.5、6、8.5、11、13.5 秒的首个可取 RENDER 各采一次，共六窗。在 stage RENDER -1000000 启动，下次 ENTER +1000000 首先暂停，随后枚举。原上限、重复 RENDER、结束和异常清理规则不改。
- 六窗分布在 18 秒动作窗口内，仍不代表完整时间的连续 CPU 记录。保留 `at/after/renderAt/startCallAt/start/stop/pauseReturned/collectMs` 和实际测量起止时刻，逐行核第一可取窗口；不把采样器自身整理时间算成该窗口 CPU。
- 原方法只保留 CPU 栈，不留分配对象。输出在测量和原双侧动作完成后写本人唯一 Local Store 的 `native-jump-cpu.json`；栈文本不进入普通日志，因此没有扩大错误白名单。普通日志/模块错误检查原样。
- 采样使之后帧受干扰，零样本的墙钟不解释为 GPU、休眠或等待。原 `b3d7b8558b` 实测曾得到 854/1614 个 CPU 样本；当前接口正控制 `recovery-paint-sampler-positive-01` 为 150 ms 算术获得 163 个 CPU 样本，只证明采样 API 可工作，不能替代本次游戏证据。

## 构建与运行边界

`build.py` 执行冻结普通房构建器，只有三种文本适配：只编 native-jump、单个编译命令数量由 CASES 决定、回执 kind 改为本诊断。完整展开文本为 `adapted-build.py.txt`。旧构建器 `inputs()` 仍真实执行，当前 22 项、telemetry、原产品/ABI/工具全部核对；另绑定本目录所有源。原 1 GiB 编译余量、共享登记、300 秒编译保护和自有子进程回收保留。

`run.py` 执行原 `goal-three-issues-native/run.py` 的原文本，只显式注入新驱动验证接口、限制 native-jump 和准确 78C。原 shared runner 未改；6 GiB 启动、512 MiB 运行、300 秒整轮上限、独占/私有桌面、普通房偏好 false、真实 telemetry、错误检查和清理不变。原 `result.json` 保留功能结论；新 `cpu-result.json` 另要求两侧各六个完整窗口、没有截断/错误、sampler 已停且真实 CPU 样本非零。缺采样会使新入口非零退出，不改旧功能回执为假通过。

以下命令由根会话从 `mods/RConnect` 串行执行；本准备未运行编译或游戏：

```powershell
$py = 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
& $py -B -X utf8 experimental/goal-local-frame-review/prepare.py --check
& $py -B -X utf8 experimental/goal-local-frame-review/build.py --check
& $py -B -X utf8 experimental/goal-local-frame-review/build.py --build --output build/m52/goal-local-frame-cpu-drivers-01 --registry-wait 900
& $py -B -X utf8 experimental/goal-local-frame-review/run.py --drivers build/m52/goal-local-frame-cpu-drivers-01 --product build/m52/recovery-room-production-05 --case native-jump --check
& $py -B -X utf8 experimental/goal-local-frame-review/run.py --drivers build/m52/goal-local-frame-cpu-drivers-01 --product build/m52/recovery-room-production-05 --case native-jump --output build/m52/goal-local-frame-cpu-native-01 --registry-wait 900
```

原始文件和两侧 `*-cpu-summary.json` 同时保存；叶栈定位当前执行函数，包含栈定位调用来源，计数不得当作独占毫秒相加。本候选不授流畅度、性能或部署资格。交付冻结后须根明确重新授权才能修改。
