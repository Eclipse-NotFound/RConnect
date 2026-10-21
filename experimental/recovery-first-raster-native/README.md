# recovery13 / FD92 原生大图验证入口

状态：源码冻结，静态检查 58/0；本目录没有编译或启动 AIR。父会话统一登记、编译、实测。它只增加外部夹具与验收适配，不修改公共 runner、生产源码或安装文件。

准确输入：

- RC：`build/m52/recovery-13`，`1177eb1ae9b227bcf3c0eb39dedad92b63ac16dcb7ffb0b421ea0a2024bfddb1`。
- 宿主：`build/m52/recovery-first-raster-host-03/pfe.swf`，`fd92fbd5ae92b5c8d4cbf8151d11796a140810f34988b7031e258c747d86734e`。
- 宿主原 `prepared.json` 的回读失败保留；准入另核对 `build/m52/recovery-first-raster-host-recheck-03/receipt.json`。每次都重新检查原工具和源、5 次 FFDec 输出、代表类、非代码标签和 22 项安装指纹；不会把旧失败改成通过。
- 大图基于冻结 `room-travel-driver-12`；真实按键检查来自已执行的 `recovery-cold-travel-driver-03`。`scene-driver.patch` 列全部 AS 差异；`runner.patch` 列准入适配，运行命令及最终日志资格段逐字不变。

## 由父会话执行

以下工作目录为 `mods/RConnect`，输出必须是尚不存在的新目录。不能同时运行；沿公共测试登记、独占 AIR、双人 6 GiB / 单人 3 GiB 启动与运行中 512 MiB 门槛。

```powershell
$rasterPython = 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'

# 先只编译外部驱动；不启动游戏。
& $rasterPython -B -X utf8 experimental/recovery-first-raster-native/prepare_scene.py build/m52/recovery-first-raster-scene-driver-01 --require-seed-raster --compile --registry-wait 900

# 同驱动双人：首次马哈顿大图 → 基地 → 重返大图。
& $rasterPython -B -X utf8 experimental/recovery-first-raster-native/run_native.py --candidate build/m52/recovery-13 --game-candidate build/m52/recovery-first-raster-host-03 --drivers build/m52/recovery-first-raster-scene-driver-01 --scenario scene --output build/m52/recovery-first-raster-scene-dual-01 --registry-wait 900

# 同准确产物和同路线的单人对照。
& $rasterPython -B -X utf8 experimental/recovery-first-raster-native/run_native.py --candidate build/m52/recovery-13 --game-candidate build/m52/recovery-first-raster-host-03 --drivers build/m52/recovery-first-raster-scene-driver-01 --scenario scene --solo --output build/m52/recovery-first-raster-scene-solo-01 --registry-wait 900

# 普通分房沿用未改的 scene12 entry-room 驱动，不经过新大图输入夹具。
& $rasterPython -B -X utf8 experimental/recovery-first-raster-native/run_native.py --candidate build/m52/recovery-13 --game-candidate build/m52/recovery-first-raster-host-03 --drivers build/m52/room-travel-driver-12 --scenario entry-room --output build/m52/recovery-first-raster-entry-room-01 --registry-wait 900
```

适配器只接受准确 recovery13 与 FD92；不能省略宿主参数或自动退回安装版。大图必须使用已编译、要求 seed ticket 的新驱动；普通房只接受原冻结 scene12 驱动。`prepare_scene.py` 的 control 选项仅用于日后另行准备对照，本轮 `run_native.py` 不接受这种驱动。

## 观测与判定边界

保留 scene12 原有双人 39 / 单人 13 项对应的检查标签、固定种子 `1380142925`、路线、240 秒 boot / 95 秒单阶段超时、原生生成/恢复和全部模组日志判错。新增断言使实际总数增加，不用旧总数冒充新结果。

- 原 `elapsed` 仍是本侧收到旅行通知至原稳定条件满足，便于与旧结果对应；出生 x/y 在真实按键之前保存。原双方入口距离门槛仍是 80 px，**不是精确重合证明**。报告应保留实际距离。
- 新 `controlResponseElapsed` 从宿主发起的同机墙钟，到本侧真实 Stage KEY_DOWN 引起方向、速度、位移一致；先观察三帧无水平漂移，再按键，随后 KEY_UP 与下一原生帧释放确认。1000 ms 窗口、0.1 px 条件来自 cold03，不强设速度或控制字段。此数包含刻意的无输入基线等待，应同时列出原 `elapsed`、基线等待、按键响应时间，不能把夹具等待算成纯加载工作。
- 开场只对仍存活、空闲而 `animOff` 的已知原生开场状态调用 `anim()`，先记录原状态；死亡、非空闲等条件失败就终止，不复活人物绕过失败。
- 首次和重返随机大图：加入侧必须看到一个真实 production ticket，初值 waiting/unpainted 均真，最后自然释放且真实 painted。宿主、单人、基地必须无 ticket。包装回调恰好调用原函数一次；只观察 ticket，不主动调用 `sceneViewReady` 或取像素。
- 原 `entryPending` 累计继续保留。这里验证控制恢复与 production 首绘门控，不证明原版加载图像逐像素一致，也不证明每个 UI 控件无短暂遮挡。
- 功能 `passed` 不包含“耗时达到单人”门槛。须按三轮分别比较同机单人与双人 host/join 的时间，不能以旧大图 25/14 功能通过或首绘 ticket 通过声称用户性能目标达成。
- 普通分房命令沿用原外部覆盖；死亡、换档、同 World 换 Game、断开、失败、旧 grant、配置退回的身份释放仍以已过 RoomSync/Gate 组件为证据，本套三段旅程不声称覆盖其原生端到端结果。

静态重新检查（不编译、不运行游戏）：`check_native_sources.py`。输入和当前目录源清单见 `native-adapter-manifest.json`。生成器仅在未冻结修订时使用；任何后续修订应另建驱动输出并保留旧结果。
