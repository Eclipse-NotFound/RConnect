# 首轮加载恢复后的 CPU 采样夹具

仅独立诊断源码，准确祖先为 `build/m52/recovery-seed-gate-driver-01`：同字节 ON/OFF 驱动 `20e7deec…91aa`。生产 RConnect、FD92 宿主、其他模组均不修改；原始三轮、三帧、1000 ms、键盘及释放检查保持。`driver.patch` 只有带标签的插入，剥除插入后整个驱动与冻结祖先逐字节一致。

## 起点与边界

ON/OFF 失败证据见 `../recovery-seed-baseline-review/review.md`。OFF 在输入函数之前已有 `38839→41385` 的 2546 ms 长帧；如果只从 `baselineAt` 开始，会漏掉前一段真实工作。因此只在 **加入侧 round0、目标 random_mane 的首个 grant MESSAGE 分发前**启采样。优先级 200001 / -200001 围住原 room handler；不替换 handler、不调用 restore。

该起点覆盖 grant 恢复、解除加载后的工作、原输入基线及按键响应。它明确**不含本次 grant 的 TCP 外层解码**；后续 socket 解码在采样开启时仍能被采到。`markers` 仅保留至多64个阶段/驱动帧边界，并记录 `getSampleCount()` 序号；离线按序号切分 grant、baseline 等区间，无需假定 `Sample.time` 与 `getTimer()` 的时间原点相同。原始 Sample.time 只原样保存。

round0 成功释放按键后，或 `inputError()` 进入原错误日志之前暂停采样；异常 finish 也兜底暂停。整个原测试 finish 时才枚举剩余样本、序列化并写文件，避免输出工作延长原1000 ms窗口或影响后两次旅行。VM缓冲即将填满时会暂停并调用回调，回调只收集有界 CPU 样本然后清缓冲，**不读分配类型/对象/大小，不写日志**。[Adobe sampler API](https://help.adobe.com/en_US/FlashPlatform/reference/actionscript/3/flash/sampler/package.html) 定义这些暂停/缓冲接口；分类沿用已实际工作的密集场景采样器。

上限：CPU 12000、唯一栈512、栈深24、函数名192字符、标记64、一次原生缓冲扫描250000条；采样窗口15秒，在下次驱动帧观察到超时后暂停。阻塞回调中不能靠 AS3 定时器强行在15秒打断，有限缓冲由原生 callback 排空。触顶、空样本、缺失阶段均明确记录，不能声称完整采样。

CPU栈可能只有函数名而无线号，取决于实际编译/运行时信息。样本数不是方法执行毫秒，包含关系不能相加；原生等待/GC也可能没有可识别 AS3 栈。采样和满缓冲处理有额外开销，**本轮全部计时只用于归因，不作FPS或加载性能验收**。

## 文件与接入

- `RoomInputCpuProfile.as`：唯一新增采样类；`tests/` 为生成后的6个AS文件。
- `generate.py` / `check_sources.py`：纯离线生成、祖先恢复检查及报告反例；当前未编译/未运行。
- `prepare.py`：直接调用既有 `recovery-seed-raster-control/prepare_driver.py` 的注册编译入口，仅把测试源 HERE 指向本目录；没有另一套编译/二进制复制流程。
- runtime 仍直接使用既有 `recovery-seed-raster-control/native_runner.py`，共享测试登记、独立桌面、双侧6GiB/运行512MiB门槛、22项输入记录全部沿用。
- `collect.py`：运行结束后从本次精确 AppID 的只读存储复制 CPU JSON，到新的 `build/m52` 目录；保留原功能失败、三轮/ticket资格和原 registry 结果，不改原结果。

从 `mods/RConnect` 执行（Python 为当前运行时，下面命令只是交付，未执行编译/游戏）：

```powershell
python -B -X utf8 experimental/recovery-input-cpu-profile/prepare.py build/m52/recovery-input-cpu-driver-01 --compile --candidate build/m52/recovery-13 --gate-expect on
```

构建结果保存精确 `runtime-command.json`。根会话执行其中的参数列表即可；等价入口如下，不应改用原 `run_native.py` 的旧 first-frame 诊断解析器：

```powershell
python -B -X utf8 experimental/recovery-seed-raster-control/native_runner.py --candidate build/m52/recovery-13/RConnectMod.swf --effects --effects-driver build/m52/recovery-input-cpu-driver-01/scene --all-mods --land rbl --seconds 600 --expected-version 0.2.24-recovery13 --port 0 --private-desktop --defer-visible --wait-host-world --require-exclusive-air --registry-wait 900 --game-candidate build/m52/recovery-first-raster-host-03/pfe.swf
python -B -X utf8 experimental/recovery-input-cpu-profile/collect.py --run build/cooperation/实际十位运行ID --drivers build/m52/recovery-input-cpu-driver-01 --output build/m52/recovery-input-cpu-review-01
```

采集文件名为唯一测试存储中的 `room-input-cpu-profile.json`，不会改游戏目录。既有 runner 只自动复制 `.log`；所以运行后必须执行 collect，不能只看 `SCENE INPUT CPU FILE` 行便声称拿到了栈。JSON payload 不进入日志错误匹配器，避免函数名中的 Error 被误当运行错误。collector 不启动进程，也不改原日志/结果。

若改为 OFF，同一驱动源码和编译入口保持；仅 prepare 的 candidate/gate-expect 绑定不同。当前目标先定位准确13 ON，不能用采样版耗时替代无采样 ON/OFF 对照。
