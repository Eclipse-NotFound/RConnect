# 原生绘制区间外部驱动

仅供诊断，未编译、未 AIR、未部署，无性能资格。根会话最终同意后才构建。宿主计时契约来自独立 `recovery-early-paint-timing`，不修改任何冻结源或原测试断言。

基底为准确 `build/m52/recovery-early-sandy-scene-driver-01`。保留 RoomTravelTimingTestDoc、RoomTravelSceneTestDoc、A22RoomMetrics 的全部字节、场景、时钟、退出倒计时、原95秒期限和断言；FirstRasterSceneProbe 仅可逆地加入外部 helper 调用。其原 `finish()` 判据整段原文保留，原 `.passed` 含义不变，新增独立 `paintEvidence.passed` 不可用于覆盖旧失败。

新 helper 在每段 begin 时订阅真正可写的 `Grafon.rconnectPaintTimingBridge`，要求空槽；以 world/game/grafon 真实引用绑定该段，再由已有 rconnectRasterBridge 绑定真实 sceneOpen 的 loc。即使单人返回 null 票据也会绑定。每条记录来自宿主原等待/完整预载早退之后的 ensure 工作区间，保留开始/结束的 getTimer 与 Date、room序号和严格引用一致性。不会使用轮询间隔代替真实绘制计时。

所有已订阅回调聚合 `observedCalls / inclusiveTotalMs / maxMs / positiveMsCalls`。只保留 initial、resident 改变、正毫秒耗时、未完成或身份改变的区间；最多32条。0ms且resident不变、成功且身份一致的调用计入 `zeroMsStableResidentSkipped`，这是计时分辨率下的省略，**不是完全没有像素工作的证明**。第33条需保留的区间会标 overflow 并解除自己订阅；此后未观察调用数量未知，诊断无效，不放大上限转绿。异常或身份改变绝不被省略。

callback 内不写日志、不截图、不枚举地图或显示树；完成/失败处统一输出一行 `EARLY PAINT PROFILE`，正常完成还放在原 TRAVEL RESULT 的 `rasterEvidence.paintEvidence`。普通小房没有大场景绘图可保留零行。若绑定了真实大场景，则须至少有一条目标房间工作区间。原生 `rconnectPaintTimingFaults` 差值、外部 faults、owner冲突、溢出均使诊断无效。dispose 只清自己的诊断槽，不覆盖其他owner。

## 源码及准入

- `generate.py` 从准确原probe生成新probe及七处 `probe.patch`；反向替换可还原全部原文。
- `check.py` 包含43项纯源码／数据检查：完整原断言块保留、32条上限、错误不过滤、solo绑定、故障输出、原三驱动指纹、原生边界 world.grafon／world.loc 身份，以及8项 profile 审计正反例。不是 AIR 实测。
- `freeze.py` 冻结本目录及宿主代理的 `prepared.json` 和准确 Grafon 源。`inputs.json` 生成后不再修改；需要变化就新目录。
- `binding.py.verify_driver(path,meta,scenario)` 给根的独立 native runner 适配调用，仍沿用准确22项准入及已明确的RV7852→AB46安装差异。测试副本仍使用旧RV7852；这个模块不放宽宿主准入。
- 新 `prepared.kind` 为 `scene-native-input-early-paint-driver`，`diagnostic_kind` 为 `ensure-work`。`audit_profile.py.audit_log(path)` 只读核验完整三段 profile、原 TRAVEL RESULT 内嵌副本一致性、故障／身份／行数／聚合计数与时钟，返回统一墙钟的真实区间；合法也明确 performance_qualified=false。
- `prepare.py` 复用旧已编译的宿主声明、存根、harness和三份原断言驱动，只替换probe并添加helper。默认只准备；显式 `--build` 沿用共享game登记、1GiB编译准入、384MiB JVM、原内存监控，不启动 AIR。双实例准入仍由根的既有runner负责。

根确认后可用：

```text
python -B -X utf8 experimental/recovery-early-paint-driver/prepare.py --output build/m52/recovery-early-paint-driver-01 --build
```

当前没有自行建立可运行的 `run_native.py`：根需将这个准确driver与单独核验的诊断宿主绑定，不能把旧只接受2D415D宿主的准入改成任意宿主。正式候选 remains early2；诊断宿主及观察负载不能获得性能发布资格。

双人诊断完成后只读审查入口（单人追加 `--roles host`）：

```text
python -B -X utf8 experimental/recovery-early-paint-driver/audit_profile.py --run-dir build/cooperation/准确运行编号
```

## 有界缓冲器的可执行组件源

`tests/PaintTimingBufferChecks.as` 用真实buffer与假的回调载体检查25项：32边界／33溢出、1000个0ms调用聚合、故障及owner变化、原生故障计数、身份／时钟异常、普通房零调用、initial及resident变化0ms仍保留、World悄然换renderer。仅准备，未编译或运行；它验证观察器，不代替真实draw或单人/双人测试。

```text
python -B -X utf8 tools/validation/run_recovery_component.py --source experimental/recovery-early-paint-driver/tests --entry PaintTimingBufferChecks.as --expected 25 --output build/m52/recovery-early-paint-buffer-component-01
```

首轮没有重型场景指纹或出生改写。已知布局seed不覆盖出生／全部敌群随机，所以计时结论仍需保留输入工作量限制。
