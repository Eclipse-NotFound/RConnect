# 仅 RConnect 的原生双人运动对照

只在隔离副本中用官方 RemainsModLauncher `--only RConnectMod --no-ui` 选择。其他 13 项包括 ModLoaderMod、TDFC、LAD、CS、RV、WB 全部不加载；14 个物理 SWF 保留，正式 22 项输入前后逐项核对。官方选择器工具不是 ModLoaderMod 运行时。每端必须从宿主 MainFE 自己写出的新 ModLoader.sol 证明 requested/ok 恰好只有 RConnectMod、无 err，不能用配置选择代替实际加载。

复用 goal-three-issues-native-drivers-02 的原跳跃 9EE16FA6、抓取 FEF72AB4、D52 harness，不新增或重编 AS。跳跃双侧 6/6、18 秒原动作窗；抓取 43/42、原四窗和 <=160ms 检查不改。入口超时原 300/360 秒；登记、独占、私有桌面、6GiB/512MiB、错误检查和自有进程回收均沿共享运行器。没有同步截图。NativeMotionProbe 自行记录 ENTER_FRAME/RENDER、焦点、生产消息与计时恢复，不依赖 ModLoader FrameRecorder。

单人模式不支持：原跳跃/抓取需双端 ready/setup/round 握手，不能仅加 --solo 获得同动作基准。这里记录双实例内各自的本机帧率，以及对侧表现；不伪造单人结果，也不删远端断言。

驱动历史构建组合 BF4A 和当前实际 638E 组合沿 goal-self-echo-native 原环境验证明确分开；仅复用 goal-jump-pose-held-regression 的真实产品验证接口，接受准确正式 78C 或已编 52D。支持 52D 仅代表可选输入，不代表有性能资格。正式宿主仍 A796，不叠加载 UI/LAD/运动时钟候选。关闭其他模组后仍保留宿主既有内嵌补丁，不声称还原纯原版宿主。

在 mods/RConnect 中，仅根执行运行；先以正式 78C 基线：

```text
python -B experimental/goal-rconnect-only-motion/run.py --prepare
python -B experimental/goal-rconnect-only-motion/run.py --source-check
python -B experimental/goal-rconnect-only-motion/run.py --drivers build/m52/goal-three-issues-native-drivers-02 --product build/m52/recovery-room-production-05 --case native-jump --check
python -B experimental/goal-rconnect-only-motion/run.py --drivers build/m52/goal-three-issues-native-drivers-02 --product build/m52/recovery-room-production-05 --case fast-held --check
python -B experimental/goal-rconnect-only-motion/run.py --drivers build/m52/goal-three-issues-native-drivers-02 --product build/m52/recovery-room-production-05 --case native-jump --output build/m52/goal-rconnect-only-motion-jump-baseline-01
```

抓取换 `--case fast-held` 和新的输出名；候选显式换 `--product build/m52/goal-jump-pose-product-01`。`--prepare` 仅首次写本目录文本清单，已有文件不覆盖；检查不创建测试输出。未运行前无性能/流畅/部署资格。功能 PASS 也不自动授性能资格。
