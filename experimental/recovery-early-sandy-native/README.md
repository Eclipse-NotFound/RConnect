# early1 + A 时停接口的三段原生测试入口

只作隔离验证。准确 RConnect `10B249…1FAE6`、宿主 `2D415D…DD29`（原导入验收失败保留，独立精确回读已通过），A 时停桥 `3E220B…D331C`。完整来源和本目录文件指纹见 `inputs.json`。不安装，不修改用户配置。

## 最小改动

- 外部加载驱动沿用已跑过的首次随机大图 → 基地 → 同图重访三段。时间、固定种子、出生距离 80 px、3 帧无输入基线、1000 ms 基线／按键门槛、KEY_UP 后下一帧释放及所有原断言原文保留。
- 仅改票据期望：新接口的共同大图旅行主／加双方都应观察到真实早期票据和已持有的时停许可，恢复后必须都释放；单人和基地不应产生票据。旧 CEC6 无接口对照仍要求加入侧的旧 seed 首绘票据，主侧没有票据。观察器不调用生产 acquire/receive，不改票据。
- `native_runner.py` 是正式底层的完整独立副本，仅增加准确时停产物注入口、目录重定位。`*.patch` 给出逐行增量；正式工具未改。所有启动／登记／6 GiB 双人、3 GiB 单人、512 MiB 运行保护、安装 22 项指纹、原生资源、独立存储及清理原样保留。
- `prepare_scene.py` 沿用旧独立 scene 编译入口，只编译这一个外部驱动；增加现有 runtime_memory 的 1 GiB 编译入口和自有进程保护，隐藏窗口。没有编译或运行。

## 根会话调用（工作目录 mods/RConnect）

用已配置的 Python 执行，始终带 `-B -X utf8`：

```text
experimental/recovery-early-sandy-native/check.py
experimental/recovery-early-sandy-native/prepare_scene.py build/m52/recovery-early-sandy-scene-driver-01 --sand-mode bridge --compile --registry-wait 900
experimental/recovery-early-sandy-native/run_native.py --candidate build/m52/recovery-early-compile-01 --game-candidate build/m52/recovery-early-host-01 --drivers build/m52/recovery-early-sandy-scene-driver-01 --output build/m52/recovery-early-sandy-scene-dual-01 --sand-mode bridge --registry-wait 900
experimental/recovery-early-sandy-native/run_native.py --candidate build/m52/recovery-early-compile-01 --game-candidate build/m52/recovery-early-host-01 --drivers build/m52/recovery-early-sandy-scene-driver-01 --output build/m52/recovery-early-sandy-scene-solo-01 --sand-mode bridge --solo --registry-wait 900
```

无接口旧版回退使用同一时序代码，单独编译只有显式期望常量不同的驱动；实际注入仍是安装的准确 CEC6：

```text
experimental/recovery-early-sandy-native/prepare_scene.py build/m52/recovery-early-legacy-scene-driver-01 --sand-mode legacy --compile --registry-wait 900
experimental/recovery-early-sandy-native/run_native.py --candidate build/m52/recovery-early-compile-01 --game-candidate build/m52/recovery-early-host-01 --drivers build/m52/recovery-early-legacy-scene-driver-01 --output build/m52/recovery-early-legacy-scene-dual-01 --sand-mode legacy --registry-wait 900
```

旧版回退有三段功能／出生／真实按键判据，但不是 early 提速合格证。三段功能通过也不自动满足“单人相应耗时”：`elapsed` 与包含原生输入恢复的 `controlResponseElapsed` 须分别与同驱动 solo 对照；输出显式 `early_performance_qualified=false`。

## 普通分房与仍未覆盖的边界

已有非旅行者入口可直接运行，不重编、不断言降级：

```text
experimental/recovery-early-sandy-native/run_native.py --candidate build/m52/recovery-early-compile-01 --game-candidate build/m52/recovery-early-host-01 --drivers build/m52/room-travel-driver-12 --output build/m52/recovery-early-sandy-entry-room-01 --scenario entry-room --sand-mode bridge --registry-wait 900
```

该入口保留原失败。旧运行 `a542373a5f` 主侧有两个“收到对端 ACK 才算本地确认”的旧前提失败，原夹具不会因本适配变绿；它仍可提供后续分房操作证据，不能把这两个失败当全局暂停的实现要求。它没有对时停许可或每个非旅行者帧作新断言。

active／replay 拒绝专项暂不混入本驱动。先启动时停再旅行会被 onPause 阻住，可能直至 idle 才到 acquire，不能据此声称覆盖真实拒绝路径。真实按键进入相应阶段后，外部调用准确 MapGeneration.acquireEarly 的拒绝检查可另做，但只证明接口边界；整次旅行中途回退、取消、外部模组冻结仍需真实专项。此前217项组件及新桥76项只给组件资格，不能替代这些原生结果。

当前交付仅源码／静态校核，无编译、AIR、性能或发布资格。旧失败、安装和冻结证据均未修改。
