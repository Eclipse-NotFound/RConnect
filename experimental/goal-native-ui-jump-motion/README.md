# nativeui2 的现成 onlyRC 运动回归

仅复用 `goal-rconnect-only-motion` 的完整 main、展开运行体与官方隔离选择器，不重编或改写运动驱动。整合产品由 `goal-native-ui-jump-loading/run.py:candidate_bundle()` 验证真实 5325 编译产物及 2DB0 宿主；若新 loading driver 缺真实编译回执，返回 not-ready，不创建运行输出。

源码只有三处 main 替换、三处运行体替换和一处 selector 判据替换：选择新 bundle；传入 `--game-candidate`；私有副本在 AIR 启动前核 pfe.swf 实际 SHA 并纳入原前后 assets 校验；最终 run.json 核新宿主。原 selector 的无候选宿主约束改为只接收准确 2DB0 路径及 SHA，空参数、当前 A796、其它同名路径均拒绝，四项只读参数检查不启动游戏。旧运动 driver 的历史 `build.HOST_SHA`、来源、ABI 与产物证明仍原样核验，并未拿新宿主改写历史构建。

原 300/360 秒、双侧 6/6 与 43/42、四窗口与 160ms 动作/观察判据、测量与错误扫描、22 项正式输入前后、私有 CS=false/telemetry、官方选择仅 RC/SOL 证据、6GiB 启动/512MiB 运行保护、共享登记和收尾全部保留。只读文字检查不授予性能或流畅资格；不编辑旧入口，不启动 Java/AIR，不部署。

在 RConnect 目录执行：

```text
python -B -X utf8 experimental/goal-native-ui-jump-motion/run.py --prepare
python -B -X utf8 experimental/goal-native-ui-jump-motion/run.py --source-check
python -B -X utf8 experimental/goal-native-ui-jump-motion/run.py --drivers build/m52/goal-three-issues-native-drivers-02 --product build/m52/goal-native-ui-jump-product-01 --case native-jump --check
python -B -X utf8 experimental/goal-native-ui-jump-motion/run.py --drivers build/m52/goal-three-issues-native-drivers-02 --product build/m52/goal-native-ui-jump-product-01 --case fast-held --check
```

真实运行由根统一安排，仅在上面准入通过后去掉 `--check`，新增未存在的 `--output build/m52/goal-rconnect-only-motion-nativeui2-{jump,held}-01 --registry-wait 900`。两个 case 独立运行；驱动路径已对照实际 onlyRC 基准 intent。此目录保留精确适配文本及可逆差分，没有新 AS 或运行框架。
