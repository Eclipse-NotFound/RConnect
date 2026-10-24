# 普通房间三程加载对照入口

本目录只把已冻结的 `recovery-room-current-comparison/run.py` 接到现成普通房驱动，不新增 AS、不重新编译、不改生产或旧入口。

- 产品固定为 `build/m52/recovery-room-production-05`，SHA `78c052aea963f1689b705ae1e14d274916ae1a1f7e81933390caf8d1a88f4699`；实际宿主固定为 A796。运行时真实 22 项安装输入另行冻结，启动前及结束后必须完全一致。
- 驱动复用 `build/m52/recovery-room-current-driver-01/timing/EffectsDriver.swf`，SHA `2d0617be7c9ef315937116573881dc1625b31f32801fce0fecd32d51275ec1f6`。其 prepared、两个真实编译结果、全部源输入及产物逐项核验；历史编译安装环境只记为来源，不冒充当前安装。
- 私有 CS 偏好为 `nativeEnabled:false`，驱动本身也核对实际普通房模式。三程保持首次进入马哈顿、返回基地、重访马哈顿；固定种子 1380142925，实际房间为 48×25。原双方房间、种子、尺寸、出生距离、控制恢复、错误与超时判据不变。
- 借用旧目录的 `bridge_inputs.py`，仅执行无桥分支；本入口不接受宿主替换、Sand 桥或诊断驱动选项。旧 comparison/run.py 的准确指纹同时纳入输入。
- 原共享 runner 负责登记、私有桌面、独占 AIR、单人 3 GiB／双人 6 GiB 启动门槛、512 MiB 压力底线及回收。真实 telemetry 配置忠实复制；原始错误扫描与结果审计保留。

`source.diff` 是相对旧入口的完整文本差分。只读 `--check` 已通过，未编译、未启动 AIR；当前玩家实例仍在运行，实际测试交主会话安排。

## 命令

在游戏根目录执行，只读准入检查：

```powershell
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 'mods/RConnect/experimental/goal-ordinary-loading/run.py' --product 'build/m52/recovery-room-production-05' --check
```

主会话确认可以测试后，分别使用全新的输出目录：

```powershell
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 'mods/RConnect/experimental/goal-ordinary-loading/run.py' --product 'build/m52/recovery-room-production-05' --mode solo --output 'build/m52/goal-ordinary-loading-solo-01'
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 'mods/RConnect/experimental/goal-ordinary-loading/run.py' --product 'build/m52/recovery-room-production-05' --mode dual --output 'build/m52/goal-ordinary-loading-dual-01'
```

读取原 `TRAVEL RESULT` 的 elapsed、nativeControlsElapsed、seed、坐标、房间尺寸与单位数，并结合已有 A22 消息时长／长帧、RConnect prepare/seal/grant/ready 日志判断阻塞位置。不同进程的 getTimer 不能直接相减；共同种子也不等于完全相同生成内容或出生视口。入口始终保留 `performance_qualified:false`，三程通过本身不等于达到单人耗时。
