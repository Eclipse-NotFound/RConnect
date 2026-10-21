# 房间入口观察器：区分宿主本机提交与对侧 ACK

范围：只修外部 `RoomEntryProbe` 的观察语义。基线是冻结的 `build/m52/room-travel-driver-12`（manifest `3106b031…b784`），被测生产仍为 recovery13 `1177eb1a…ddb1` 与隔离宿主 FD92。没有修改生产、原驱动、安装版、共享运行器；没有启动 JVM/AIR。

## 实际失败和原因

原证据保留：`build/m52/recovery-first-raster-entry-room-01/result.json` 与 `build/cooperation/a542373a5f/{host,join}.log`。结果仍为 **exit 1 / passed false，主侧 25 PASS、2 FAIL；加入侧 53 PASS、0 FAIL**。精确指纹、七轮时间线见 [native-timeline.json](native-timeline.json)。

|宿主本机 getTimer|实际记录|
|---:|---|
|72,647 ms|READY 处理结束：term=1、epoch=1、ready=true、busy=false、cover=false、nativePause=false；前一行已有 `RConnectRoom: commit 1`|
|72,699 ms|观察器报 `unconfirmed native scene is covered at render`；其 confirmed=null|
|72,701 ms|观察器报 `new native room cannot publish before handoff`|
|73,202 ms|ACK 处理结束；旧观察器此时才承认本机房间|

根因有直接源码依据：recovery13 `RoomSync.receive` 收到合法 READY 后调用 `commit`；`commit` 写入本机 `settledRoom/settledKey/term/ready`，发送 grant，立即 `release()`，**pending 事务继续留待 ACK**。本机合法显示比对侧 ACK 早 555 ms。其余六轮 READY→ACK 间隔分别为 46、40、510、227、313、373 ms。

这里不能推导加载已足够快：原运行仍存在 19 秒首次等待和 1,840 ms 帧间隔；本修正不会缩短它们。旧两 FAIL 只证明旧观察器与生产提交时点不一致，不能把旧失败结果改成通过，也不能替代新原生运行。

## 精确变更

- [observer.patch](observer.patch)：仅替换观察确认与 `sameConfirmed` 来源；保留原来的 **全部 15 个 check/require 调用体**，含原遮挡、不能提前发包、旧房间拒收、释放帧身份、世界包身份及标量一致性检查。原 39/13 标签所在的原生套件整体按冻结文件复制，不删除或替换标签/刺激/阈值。`RoomCooperationTestDoc`、`A22RoomEntryTestDoc`、`RoomScalarParity` 等全部原 AS 文件保持字节相同（唯一既有文件例外是 Probe）。
- [tests/RoomEntryConfirmation.as](tests/RoomEntryConfirmation.as)：外部纯观察 helper。宿主收到 READY 后，必须实际 `ready && !busy && canSyncWorld && authority`，且 world/game/land/player 四处房间对象一致，当前 key、epoch、term 与提交 stamp 及消息一致，才记录本机提交。
- 对侧 ACK 单独记为 `peerAcknowledged`；它必须吻合已经确认的本机对象、Land、key、epoch、term 和 travelId，不能独立创造确认。连接变化清空两种记录。普通远端独立换房仍保留原地已经确认的本机显示，不添加任何全局暂停。
- 监听优先级显式设为最低，确保 Session 完成真实处理后取值；拒绝旧 socket 的消息。仅每个 READY/ACK/grant 输出一行 `ROOM ENTRY CONFIRM`，同时记录消息/实际 term、stamp、本机提交与 ACK 两种事实。
- 不把 READY 的 `info.roomKey` 强制等同宿主房间：双方合法分房时该字段描述加入侧，强制相同会制造新的误报。宿主自己的实际身份由当前 stamp 和 `canSyncWorld` 验证。
- 加入侧仍需真实已释放的 grant 才确认。此交付只构建/运行 **entry-room**；不宣称已解决整图 grant 后延迟首帧绘制的观察问题，也不拿旧 entry-map 二进制假称新观察器已验证。

## 检查和运行入口

[offline-result.json](offline-result.json)：**13/0 静态与旧证据核验**；Python 语法解析通过，没有编译或实际运行。组件直接使用与驱动相同的 helper 字节，43 个正常断言覆盖 READY 前、生产尚未释放、旧 term/epoch/key/对象/连接、合法本机 commit 但 ACK 未到、准确 ACK、重复 READY、远端分房保持可见、新房 ACK 不能继承旧确认、客户端 grant 与 travelId。组件只证明观察器状态规则，不是假装执行生产协议。

以下由主会话串行执行，输出目录必须不存在；原运行器的注册、内存、600 秒、22 项安装输入、全模组及所有原生断言门槛不变：

```powershell
$roomObserverPython = 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'

# 实际 AS 组件；43 项必须全部通过，通用框架保留非空/计数/汇总一致性检查。
& $roomObserverPython -B -X utf8 tools/validation/run_recovery_component.py --source experimental/recovery-room-entry-observer/component --entry RoomEntryObserverChecks.as --expected 43 --output build/m52/recovery-entry-observer-component-01

# 编译新的独立 entry-room 驱动；不启动游戏。
& $roomObserverPython -B -X utf8 experimental/recovery-room-entry-observer/prepare.py build/m52/recovery-entry-observer-driver-01 --compile

# 仍执行原 recovery13 + FD92 框架，只替换准确驱动输入审计。
& $roomObserverPython -B -X utf8 experimental/recovery-room-entry-observer/run_native.py --candidate build/m52/recovery-13 --drivers build/m52/recovery-entry-observer-driver-01 --game-candidate build/m52/recovery-first-raster-host-03 --scenario entry-room --output build/m52/recovery-first-raster-entry-room-02
```

`run_native.py` 是薄适配：仅覆盖原 `verify_driver`；候选/宿主审计、实际启动、结果解析和原始 `result.json` 都由原框架执行。编译前后和运行前后核对源、工具、声明 SWC、冻结测试及安装输入。即使新原生通过，也不构成密集场景或房间加载速度合格。
