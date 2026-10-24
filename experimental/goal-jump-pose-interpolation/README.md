# 正常跳跃身体姿态插值候选（尚未编译/实机）

仅以正式 `78C052…4699` / `recovery-room-production-05` 为底；不合入 motionv2、selfecho 或任何其他运动候选。改 GameBridge/RemoteMotion，新增小型 NativeJumpPose。原收发周期、位置/武器曲线、时钟、玩法速度和物理均不变。

## 确定的代码链与证据限制

- 正式 `GameBridge.as:708–712` 采集 bodyFrame/bodyPlaying；`1724–1760` 对停止播放的身体按样本帧 gotoAndStop。
- 正式 `RemoteMotion.as:37,179–206` 只插值位置/瞄准等，玩家 bodyFrame 保留选中的较早包；已有 bodyPose 插值仅覆盖敌人 blit。
- 原生参考 `game-reference/decompiled/1.02/src102/scripts/fe/unit/UnitPlayer.as:4521–4608`：正常 aJump>0 跳跃按 `clamp(round(16+dy),1,32)` 选择停止帧；aJump==0、飞行和悬浮不可套用。当前实际原生记录支持此动作但没有保存完整 bodyPlaying/资格字段，参考源码不冒充本轮宿主逐方法回读证明。
- `read_trace.py` 只读、核哈希后展示既有 c783ed51d1/74932502cf/e7f61547df 的位置变化而身体帧不变片段。例如 reduced 主观察方 age481/514ms 的两帧间隔28/33ms、位置分别上移16.55/8.85px、身体仍为4。
- **重复数不是缺陷数。** 原生 round、1/32 clamp、延迟阶段差异都可合法重复。原始记录缺内部cursor及两端bodyPlaying，不能据此逐帧重建期望姿态或把156/268叫错误数。组件使用明确两端数据：dy=-12/-8、body=4/8、原cursor=25ms时，原body保持4，候选按同cursor给6；位置与时钟严格对照原78C。

## 严格适用边界

发送方只在真实公开状态为正常跳跃时标段号：同玩家/房间/世界/身体子clip，aJump>0、animState与可见标签均jump，非落地、飞行、攀爬、游泳、念力、工作、死亡、animOff、传送蓄力、暂停或旅行；真实停止帧还必须吻合原生dy公式。`t_stay`是private，不猜其值。

沿现有每游戏帧 onMirrorFrame 观察，中间落地/不合格即断段，不能只靠两次发包观察。原生二段跳的 jumpNumb 变化也断段；普通顶点的 dy 变号不断段。roomHold/离线也断段。readSnapshot只是重复核资格，不因重复调用换段。接收方只有同段、同房/epoch/姿态，两端均合格才在原cursor插值一个临时dy，仅改显示bodyFrame，**不写state.dy，不模拟玩家**。传送仍先走原TeleportVisuals.split；资格失去时先恢复原选中包bodyFrame，防止前一次插值残留。

真实传输链：准确 Session 的 readSnapshot→PLAYERSTATE.snap→peer.snap→WORLDSTATE.players[].snap→updateRemote 直接保留整个对象；TcpLink 实际 JSON/AMF3 两路径都没有字段白名单。组件逐字复用准确 Protocol/BinaryMessageCodec，在两次编码解码后将真实结果交给候选 RemoteMotion，包含新增标记保留和旧客户端缺标记回退。Session/TcpLink 以准确源码指纹和直接传递锚点核验；此组件不声称实际 Socket/握手已运行。

普通运行/冲刺MovieClip播放、pinok/levit/工作/死亡、缺字段或旧客户端全部回原路径。合法夹紧与取整不变，不要求每次画面身体必须换帧。抓取物的110–120ms延迟和本机掉帧不属于此候选修复承诺。

## 根会话执行入口

本目录仅源码与静态检查，不提供新AIR运行器。`prepare_sources.py --prepare` 仅生成隔离文本；默认只核验。完整源差分在 `source.diff`。两个原类保留原行尾；纯组件用同一候选RemoteMotion/helper、准确原78C控制类及原TeleportVisuals的完整valid/split方法；武器几何未进入夹具，遇到会明确抛错。

组件入口 `components/JumpPoseChecks.as`，沿用 `tools/validation/run_recovery_component.py`，预期72项：资格22、原生段边界9、帧映射与回退20、原时钟及状态缓存11、传送2、真实双编码路径8。原跳跃/抓取实际驱动不改。组件尚未运行，源准备不授构建/原生/性能资格；先组件再真实画面验证仍由根安排。产品版本及真实构建接线由根确定，此处不改RConnectMod版本或安装。
