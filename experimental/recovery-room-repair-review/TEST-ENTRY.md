# 当前正式组合的最小房间加载对照

此入口只准备外部测试驱动，未运行游戏、未部署。父会话负责串行编译与实测。安装基线为 RConnect `0.2.24-aura1 / DF0FA0E2…01E7`、根游戏 `80CFD8CF…FD3D`、RealisticVision `6DBBAE60…8BA`、Sandevistan `CEC6A306…F942`，并逐项绑定完整 22 文件安装清单。

## 驱动的最小兼容修改

来源是 `build/m52/room-travel-driver-12`，其准备清单 SHA256 为 `3106b031b97743e2a0fda30e26ab735a387b201683339ab4335a998b0d25b784`。原版直接调用正式 aura1 不存在的 `rooms.prepareMap`，无法作为正式版基线；更早驱动也有两端 ContinuousScene 偏好不一致或旧加载器查找路径问题。因此采用四行明确变更，详见 `source.diff`：

- 仅当 `prepareMap` 存在时才保留原调用；加入侧继续调用真实原有种子函数，未人为替它灌入种子。
- 两端均设置相同的 ContinuousScene 原生偏好，避免把不同设置混入此次对照。
- 断开后仍检查加入侧保留该偏好。

三段地图切换、固定测试种子 `1380142925`、完整原生生成、同房/尺寸/种子/出生距离 80px/输入恢复断言，以及所有计时边界均未改。`RoomTravelSceneTestDoc.as`、`A22RoomMetrics.as` 原字节保留。没有宿主注入，没有安装新 hook。

## 父会话执行命令

以下均以 `mods/RConnect` 为当前目录，使用本机已确认的 Python；脚本不依赖 shell 字符串拼接。

```powershell
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/recovery-room-repair-review/prepare.py --output build/m52/recovery-room-current-driver-01 --build

& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/recovery-room-repair-review/run_native.py --drivers build/m52/recovery-room-current-driver-01 --product aura1 --mode dual --scenario scene --output build/m52/recovery-room-current-scene-dual-01

& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/recovery-room-repair-review/run_native.py --drivers build/m52/recovery-room-current-driver-01 --product aura1 --mode solo --scenario scene --output build/m52/recovery-room-current-scene-solo-01

& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/recovery-room-repair-review/run_native.py --drivers build/m52/recovery-room-current-driver-01 --product roomfix1 --mode dual --scenario scene --output build/m52/recovery-room-candidate-scene-dual-01
```

`roomfix1` 限定为 `build/m52/recovery-room-production-01/RConnectMod.swf`、SHA256 `4d9f1cbd69d8608df525477b81c9232631cbc0032c4018bc9846e6f3b9c40341`；独立检查其实际构建清单和源文件，不借用正式版资格。与基线共用同一外部驱动、当前宿主和其他安装模组。运行后仍要求 22 安装文件完全未变。

每轮由原生菜单流程进行 `rbl → random_mane → rbl → random_mane` 三段切换。`scene` 开启原生大场景；如需普通房地图对照，改为 `--scenario timing` 并使用新的输出目录，双方均关闭此偏好。相同模式的 dual 与 solo 才能直接并列。此处 solo 是完整同模组组合的离线单实例，不是卸载全部模组的原版游戏。

## 原框架与结果

直接调用原 `tools/run_coop_regression.py`，SHA256 `7eca453b13480140da5f36bb33d2319739a927562ccafdbb61a8b20cdb5ae4d3`，不复制或改写其执行代码。保持原私有桌面、独占游戏、登记、双实例 6GiB/单实例 3GiB 启动余量、512MiB 运行中余量、错误筛查与自有副本回收。私有配置仍由原框架生成；安装配置不改。输出保留原 `run.json`、`input.json`、角色日志、模组错误日志、内存采样、登记回执；新 `result.json` 只附精确输入/三段结果/安装不变检查。

驱动最长等待：准备阶段 240 秒，每段 95 秒；框架运行循环上限 600 秒，双实例启动另有最多 180 秒主侧等待，单实例为 15 秒。故单次运行保守按双实例约 13 分钟、单实例约 10 分 15 秒上限安排，另加登记排队和少量复制/收尾；达到上限仍失败，不转换为成功。实际耗时须以本轮日志为准。

三段 `TRAVEL RESULT` 记录进入切换至输入恢复总耗时、原生退出开始/结束、`entryPending` 累计时间、暂停累计时间以及最终房间和出生位置。原 `A22RoomMetrics` 另记录帧间隔与接收处理。输出默认 `performance_qualified=false`：单组功能通过不等于性能已经改善，须将同组合单人、双人和候选逐段比较。

此驱动覆盖整图切换，不自动授予普通门、背景隐藏房、独立分房、不同 ContinuousScene 偏好或密集战斗资格。原生遮罩的可见性核查可接父会话已有 `recovery-entry-observer-driver-01`；此入口没有修改其断言或假冒旧候选审计。
