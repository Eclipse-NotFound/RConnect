# 普通墙分房交接失败：首因取证

实际失败：`recovery-ordinary-wall-sv-rooms-01` / `2e1db25ddc`。准确 C6A3 + host05（00C7…AA48），原 BF6 房间驱动。原始回执 exit 1，主侧 3 项、加入侧 9 项通过，双方未完成；安装未变。完整指纹见 `failure-inputs.json`，仅抽取有限时间线，不复制 7 MB 重复日志。

确定链路：加入侧已在 `random_mane//0,0,0` 获得 term 2 权威并完成 setup 原生破墙；主侧 merge 发 seal 3 后，加入侧 `sendReady → inRoom(settledRoom) → checkpoint → ordinaryList` 抛错，主侧最终超时保持暂停。`inRoom` 此时仍是加入侧当前的权威房间，未发现取错目标房间的证据。

准确 C6A3 `WallImpactVisuals.as:783` 的这条异常只来自 `ordinaryFault / nativeFailure / rasterFailure` 三个闭锁；不是 cell.needsNative、空快照、SV 解码或 ready 包丢失。`RoomSync.as:726` 在 own checkpoint 抛出后不能发 ready，因此两侧暂停是后果。host05 `Grafon.rconnectOrdinaryPrepare` 将轮廓异常放进 event.error，C6A3 却只留下 prepared.valid；到 structure-before 才把 nativeFailure 置真，原错误丢失。原日志没有 observer 异常，也没有 nativeFailure 的首因，不能断言具体艺术范围、首次恢复或其他写入是哪一项。

旧夹具 `mainFrame("A")` 确实改变 front/mat 并用原生 Bullet 破坏；材料、相邻轮廓、蒙版帧和真实 artwork 范围需以首条现场数据判断。不得通过删掉 checkpoint、清闭锁、允许缺失准备 token 或放宽范围检查让测试通过。最小安全下一步是记录首个失败事件；证实具体边界后只修该边界，再运行原序列。

诊断覆盖只增加两个完整类的观察信息，不改原条件、墙数据、网络消息、操作频率或错误传播。只记录首条失败：种类、event.error、旧 front/vid/mat、实际范围、prepare 的有效性和 loc/state/tile 身份。checkpoint 原判据保留，错误文字增加三个闭锁当前值。准备事件的错误临时保存在弱键表，未写进状态快照。观察器自身抛错仍原样重抛。

`src/` 和 `diagnostic.patch` 是首次版本，构建 02 已因编译器将限定名称 `rconnect.core.Log` 当作未定义标识失败，原文件和失败保留。`diagnostic-v2/src/` 只给 WallSurfaceBridge 增加显式 import 并改用 Log.d；WIV 逐字不变。`diagnostic-v2/inputs.json` 和 `compiler-import.patch` 记录这一个编译适配。根会话构建 03，本入口不构建。

新 `run_native.py` 直接复用既有房间 wrapper 的准入与原框架公开回调。唯一运行组合是经 `recovery-isolated-overlay/build.py.verify` 核实的 diagnostic-03（编译回执缺失即拒绝）、host05、BF6 原驱动、当前真实 EB365 的 22 项安装。没有修改历史安装回调、旧框架、测试源或断言。

从 RConnect 目录执行（仅根会话实际运行）：

```text
python -B -X utf8 experimental/recovery-ordinary-wall-room-failure/run_native.py --check
python -B -X utf8 experimental/recovery-ordinary-wall-room-failure/run_native.py --run --output build/m52/recovery-ordinary-wall-room-diagnostic-01 --registry-wait 900
```

出现首条 `RConnectWall FIRST FAILURE` 后，可在 runner.log 实际打印的 `QUEUED_OUTPUT` 路径写 `cancel-request.json`（可含 reason）。沿用原 runner 每轮取消检查、自有进程清理、cancel-result/registry-result 与退出码 130；不杀 wrapper 或任意 PID。本入口不自行取消，追加回执记录取消及首条故障，永不把故障或取消算通过。

原 result.json 的 diagnostic_only 只描述未改的原驱动，保持原样；新 diagnostic-result.json 明确 `product_diagnostic_only=true / driver_diagnostic_only=false / diagnostic_only=true`，`passed / gameplay_qualified / performance_qualified` 始终 false。即使原框架功能通过也不授予诊断产物发布资格。

复验先保留相同 entry-room 的物理破坏、HP 精确一次结算、权威交接、双方离开后重访和全部异常检查；随后仍需原四轮 LMG/plamg 逐 uint 留痕回归。当前房间驱动不验证结构像素、SV 旧 ACK 顺序或密集场景性能，不能替代相应检查。
