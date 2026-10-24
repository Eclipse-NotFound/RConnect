# 当前普通房原生运动测量入口

本目录只增加测量，不修改生产源码。当前准备态绑定已安装 `78C052…` / `0.2.24-roomfix5`、宿主 `A796827…`、environment.json 的 22 项字节及当前 telemetry。运行须显式选择该基线或已编译 RemoteMotion 候选 `89F1B923…` / `0.2.24-motionclock1`，后者调用其原 build.py.verify，仍用完全相同驱动与 ABI。旧视觉驱动和历史回执不变。尚未编译或运行，不具有流畅度、性能或部署资格。

## 准确来源和动作范围

- `motion2-native-input-drivers-04`（prepared `677FABC0…`）：原 `native-jump`、`fast-held`；外部声明 `598D3985…`、原生存根 `8AA240ED…`、Harness `D52EF430…` 均与原驱动相同。
- 跑跳仍走真实键盘事件 → 原生角色物理 → TCP → 最终显示；保留 18 秒、原 6 项检查和原生起点放置。测量版只停止调用两次同步 PNG 截图，原 `picture()` 实现和旧视觉 SWF 保留。
- 念力仍为箱子主抓、箱子加抓、掉落物主抓、掉落物加抓四轮，保留原 Q 输入、鼠标目标轨迹、放手、重力、地板和延迟等所有检查。施法者仍按原驱动固定位置，因此不能证明移动施法者表现；窗口包含抓起到原生释放前，原 500–3100ms 轨迹仍由原日志保留。
- 原生动作和握手完全保留。两套均需要对端，**不支持单人模式**；单人对照需要另行对齐握手与动作时间，不可直接给此入口加 `--solo`。
- 本轮原生基地普通房 `rbl`；两侧私有 ContinuousScene.preferences 均在首个 AIR 前写 `nativeEnabled=false`。不改真实 AppData。背景 AI 按原驱动冻结，不能据此证明密集 AI 或普通战斗性能。

## 测量与边界

`NativeMotionProbe` 记录本机 ENTER_FRAME、最终 RENDER 各自的绝对 `getTimer()`、帧编号、NativeWindow.active、角色实际与显示坐标、身体帧、远端与念力对象显示坐标。真实生产消息单独记录本机回调时刻、源 sampleTime、消息身份和对象 key；此回调位于既有生产监听器之后，不能称为 socket 抵达时间。保留原始记录，离线分别计算前台/后台帧率、间隔 p95/p99/最大值、超过 50/100/200ms 的停顿以及重复显示位置。

双方进程时钟未校准，因而不能直接认定完整网络延迟或源画面同一时刻的位移误差。原 fast-held 的拟合延迟检查和 RMS 原样保留，也受其原最小到达偏移估计限制。重复坐标包含正常静止，不能单独称卡顿。没有最终 RENDER 的本机帧另列，不由位置检查 PASS 掩盖。

仅测量窗口启用 `GameBridge.presentationTiming`，分别记录 view/motion 的总耗时、次数和每两次观测之间的增量。增量最大值是该段多次调用之和，不冒称单次函数峰值；也不等于全部 CPU。测量结束恢复原对象引用，检查接管和恢复结果。新测量不截图；新增 JSON 序列化和日志输出延至原双侧 fixture 全部结束后。原驱动既有日志仍保留，其开销应结合原轨迹检查。

测量代码自身有采样开销，因此此入口是定位工具，不替代无观测生产版最终性能轮。所有 summary 和 result 均保留 `smoothnessQualified=false` / `performanceQualified=false`。

## 根会话命令

以下在 `mods/RConnect` 为工作目录。新输出必须不存在；不要覆盖历史失败或已冻结输出。编译仍通过共享 `game` 登记，两个 JVM 顺序执行；此子代理没有运行 JVM/AIR。

```powershell
$py = 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
& $py -B -X utf8 experimental/goal-three-issues-native/build.py --check
& $py -B -X utf8 experimental/goal-three-issues-native/build.py --build --output build/m52/goal-three-issues-native-drivers-01
& $py -B -X utf8 experimental/goal-three-issues-native/run.py --drivers build/m52/goal-three-issues-native-drivers-01 --product build/m52/recovery-room-production-05 --case native-jump --check
& $py -B -X utf8 experimental/goal-three-issues-native/run.py --drivers build/m52/goal-three-issues-native-drivers-01 --product build/m52/recovery-room-production-05 --case native-jump --output build/m52/goal-three-issues-native-jump-baseline-01
& $py -B -X utf8 experimental/goal-three-issues-native/run.py --drivers build/m52/goal-three-issues-native-drivers-01 --product build/m52/recovery-room-production-05 --case fast-held --output build/m52/goal-three-issues-native-held-baseline-01
& $py -B -X utf8 experimental/goal-three-issues-native/run.py --drivers build/m52/goal-three-issues-native-drivers-01 --product build/m52/goal-remote-motion-current-product-01 --case native-jump --output build/m52/goal-three-issues-native-jump-candidate-01
& $py -B -X utf8 experimental/goal-three-issues-native/run.py --drivers build/m52/goal-three-issues-native-drivers-01 --product build/m52/goal-remote-motion-current-product-01 --case fast-held --output build/m52/goal-three-issues-native-held-candidate-01
```

`run.py` 只接入原 `run_coop_regression.py` (`7ECA453B…`)；原内存、独占、断言、错误检测和 finally 回收路径不变。双人启动 6 GiB、运行 512 MiB，编译启动 1 GiB，均未放宽。每轮验证原断言数量（跑跳 6/6、念力 43/42）、正常测量终点、原生消息和显示数据非空、无记录溢出、计时引用恢复。运行失败保留原失败，JSON 汇总通过也不授性能资格。

正式 22 项、当前 telemetry、配方源码、原驱动、ABI 和工具输入均核对；两端当前配置和私有普通房设置在 AIR 前与回收前记录。新结果只能与这个准确普通房组合比较，不能沿用此前 240×125 大图加载成绩或历史 574D/9AC7 的流畅度结论。
