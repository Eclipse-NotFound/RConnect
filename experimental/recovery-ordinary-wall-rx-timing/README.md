# 普通墙接收阶段计时：仅源码候选

基底严格为 `experimental/recovery-ordinary-wall-ack-timing/src` 的四个完整类，对应实际 `57713116a7f4c70e47bed655d9ed80490fb32ecb75f14e7bf964e75db0122c06`。仅 TcpLink 改动；Config、Session、WallImpactVisuals 逐字节相同，全部保留原 LF/CRLF。根拟构建 `0.2.24-wallrxtime1`。本目录没有编译、AIR 或部署；准确来源/输出 SHA 在 `source-manifest.json`，全部差异在 `source.diff`。

沿用既有 wallAckTiming=1 与私有 appID/autoRole 校验。返回原 6616 宿主 SWF41、namespace30；无 tcpNoDelay、51 上下文、OutputProgress 监听或新配置。send、flush、wire、报文顺序、ACK 处理、房间/墙逻辑及频率均不改。

## 记录位置

`onData` 入口创建一个仅回调内存活的诊断上下文，先记入口；原 socket.readBytes 前后直接取时。每个完整协议帧的提取/codec 调用前后直接取时，助手更新放在 codec 结束后，因此助手对象操作不包含在当前 codec 测量里。每次原 dispatchEvent 以 try/finally 累计耗时；没有 catch 原 handler 异常，异常继续传播。只在隔离计时启用时走此分支。助手自身异常只记原 timingFault，不触发 transport.fail、不改变原接收缓冲和返回路径。

JSON 分支将原内联 readUTFBytes→Protocol.decode 分成同序两句，以区分字符提取与解析；临时字符串在记录后置空，不保留 payload。二进制分支仍使用原 ByteArray 及 BinaryMessageCodec.unpack，没有再次解码。codecMs 对二进制表示原 plain-data 校验＋AMF readObject 的合计，不能称纯 AMF 耗时；它覆盖整份消息，不只墙字段。

不新增逐消息行。全部完整消息（包括非墙消息）仅累加当前回调的提取/codec/dispatch 计数与耗时；只有原 rx-report / rx-ack / rx-paint 事件附加下列标量。回调上下文永不写入记录，结束后续更新不会改写旧行。原 256 行容量、fault/overflow、采样结束落盘和全部原功能断言保持。

## rx 标量 schema

- `rxCallbackId`：进程内从 1 递增，跨轮不重置；仅标识接收回调。
- `rxCallbackEntryAt`、`rxCallbackEntryWall`：回调最早诊断入口的 getTimer / Date.time。不是系统收包或首字节到达时间。
- `rxCarriedBytes`：回调开始前 `_rbuf.length`；`rxBufferAfterRead`：原 socket.readBytes 后缓冲总长。两者差为本次读入字节数。
- `rxReadStartAt`、`rxReadDoneAt`：原 readBytes 调用前后。
- `rxFrameIndex`：该回调内完整协议帧序号，从 1 开始。`rxPayloadBytes` 不含 4 字节长度头；`rxBinary` 为实际帧类型。
- `rxCarriedFirstFrame = (rxFrameIndex == 1 && rxCarriedBytes > 0)`。为 true 时该帧带前一次回调的未完成前缀；本次入口尤其不能视作首字节到达。
- `rxExtractStartAt`、`rxCodecStartAt`、`rxCodecDoneAt`：提取原 payload/UTF 字符串开始、调用原 codec 前、调用正常返回后。取时都在助手处理之外。
- `rxPriorFrames = rxFrameIndex - 1`；`rxPriorBytes` 是本回调已解析的前序完整帧总长，每帧含 4 字节头，跨回调的既有前缀包含在其完整帧长度内，不另加一次。
- `rxPriorExtractMs`、`rxPriorCodecMs`：前序完整帧的提取/codec 区间总和。
- `rxPriorDispatchCount`、`rxPriorDispatchMs`：到本帧开始前已执行的原消息派发次数与区间总和，包含事件构造及处理程序，不包含接收诊断元数据组装。

正式时序：`EntryAt <= ReadStartAt <= ReadDoneAt <= ExtractStartAt <= CodecStartAt <= CodecDoneAt <= 原事件 at`。同回调固定入口/读入信息相同；只有墙消息出行，故观察到的 frameIndex 可以跳号，不能把中间未记录的非墙帧当丢日志。`PriorDispatchCount <= PriorFrames`，解析结果为 null 的旧 JSON 分支不派发。

## 开销与判断边界

每轮根对象新增 `rxProbeCalls`、`rxProbeTotalMs`、`rxProbeMaxMs`，计入 GO 到 dump 之间新增 start/read/frame/dispatch 助手的自身处理。入口助手若发生在 GO 前、analyze 后的 finally、直接 getTimer 调用及分支开销不在这个统计里；标量 extras 组装仍包含在原 probeTotalMs。两个总量不能冒充全部仪器成本，毫秒分辨率下 0ms 也不证明零开销。无额外事件监听、磁盘写入或全图扫描。

同进程可以直接拆分 readBytes、当前 codec、前序派发，以及回调入口至原 rx 记录的时间。如果这些都短而 tx-after-flush→回调入口仍长，只能把主要间隔定位在该回调进入前，仍不能区分本机输出缓冲、OS 传输、接收运行时调度或等待剩余字节。flush 不是实际发包时刻；Date.time 只作跨进程辅助配对，不替代同进程 getTimer。此诊断不修改生产、不能单独授予性能改善资格。
