# Socket 低延迟选项：隔离源码候选

准确基底为 `experimental/recovery-ordinary-wall-ack-timing/src` 的四个完整类，对应已编译诊断产品 `57713116a7f4c70e47bed655d9ed80490fb32ecb75f14e7bf964e75db0122c06`。此处只新增源码；没有编译、启动 AIR、修改安装文件或改变原冻结计时目录。根拟构建为 `0.2.24-sockettrial1`。逐文件来源及候选 SHA 见 `source-manifest.json`，完整精确文本差异见 `source.diff`。WallImpactVisuals 逐字节不变。

## 启用与真实连接

默认 `socketNoDelayTrial=""`，不启用、不设置 Socket 属性。仅在既有 `wallAckTiming="1"` 已通过 `pfe-modsettings-rconnect-coop-(host|join)-十位十六进制串` 私有应用身份及 autoRole 校验后，接受严格字符串 `off` 或 `on`；其它非空值记为诊断故障，不修改网络选项。正式 `pfe` 上下文不能启用。

加入侧 `Session.startJoin → TcpLink.connect → Socket.CONNECT → onConnect`；主侧 `ServerSocket.CONNECT → HostServer.onAccept → new TcpLink(sock) → attach`。设置点都在原 CONNECTED 派发前；主侧没有等待不会再触发的 Socket.CONNECT。核对实际事件/参数 Socket 与本 link.socket 相同、已经连接、角色与方向相符，再明确设置 false（off）或 true（on），随后动态读取并要求严格 Boolean 相等。没有“属性不存在则通过”的 guard。

API 不可见、setter/getter 抛错、值不符、重复 Socket、额外连接或采样后断开均不能获得诊断资格。相关错误只进入原 timingFault，不调用 fail、不抛给原网络流程、不停止原消息分发。原网络/握手本身的异常处理未改。每端预期一个连接；最多保留八条设置记录，超限记故障，绝非重连或多人测试。

## 输出和验收字段

沿用原 `applicationStorageDirectory/wall-ack-timing/round-N.json`（N=0..3）；不新增逐包事件、协议字段、发送动作或文件。根对象新增 `socketNoDelayTrial`：

- `requested`、`mode`：准确 off/on；`enabled=true`；`expected=false/true`。
- `qualified=true`、`connectionCount=1`、`connections` 恰有一项。缺字段、false、null 均不算成功。
- 每连接保存 `connection=1`、`role`、`direction`（host=accept / join=connect）、`linkIdAtSet`、`at/wall`、实际四个 local/remote 地址端口，以及 `sameSocket`、`connectedAtSet`、`setSucceeded`、`readSucceeded`、`readback`、`success`。设置发生在握手分配 peer ID 前，故 `linkIdAtSet=-1` 可能正常；以实际端点及 connection 编号识别连接。
- 每轮 sampled 结束后、timingDump 生成结果前，只读复查同一个真实 Socket：`checkedAt/checkedWall`、`connectedAtCheck`、`readSucceededAtCheck`、`readbackAtCheck`、`qualified`。两次 readback 必须严格匹配 expected，所有成功/身份/连接布尔值须为 true。
- 失败保留 `error` 或 `checkError`（有界文本），使原 `faultCount>0` 与 `complete=false`。原四轮像素/原错误/无 overflow 等验收继续执行；不能用选项读回取代它们。

设置只在连接发生时一次；复查只在采样结束后一次/轮，二者不计入既有逐包 probeTotalMs。send、onData、wireEvents、close/fail、全部 ACK 时序和 WallImpactVisuals 未改。静态函数对照记录于 manifest；这不是运行通过。

## 未验证边界

旧 socket-api-05 只证明 51 主层＋51 子层、namespace51 下未连接 Socket 的属性读写；未证明完整游戏、旧版本子层、真实已连接端的兼容性或时延收益。此次根将另准备同一 SWF51/namespace51 上下文的 off/on 两组，保留游戏 ABC 和资源；本源码不修改 SWF 头、描述符、系统网络设置或任何存档。只在真实连接读回和原测试通过后，才可比较两组的发送后→接收后与画面阶段时序，不能预称已定位 Nagle 或已改善流畅度。
