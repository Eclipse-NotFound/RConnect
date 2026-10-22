# recovery20 墙痕接收成本：有限只读复核

准确来源是 `recovery-20 / 0674019C…CCE9F5`，采样 run `b3d7b8558b`。没有改生产、编译或启动测试。结论：**存在解包后重复验证新格式像素的确定冗余，可准备一个小候选；没有证据把多数解包成本归因为同版本重复包。** 原七项性能失败保持，采样不提供发布资格。原文件哈希、完整栈引用和紧凑指标见 [evidence.json](evidence.json)。

## 先看最长完整采样窗

加入侧 24 个完整采样窗，共 1614 CPU 样本。下列是 RENDER 到下一次 ENTER 的实际窗，不含随后已暂停采样器的收集耗时。包含关系的样本不能相加，也不能当精确毫秒。

| phase/frame | 窗长 ms | CPU样本 | TcpLink/onData | handleMessage | 墙痕receive | decodeWords | WallCellCodec.unpack | 随后收集 ms |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 6/11 | 182 | 198 | 144 | 104 | 43 | 29 | 20 | 111 |
| 5/21 | 162 | 156 | 122 | 95 | 22 | 17 | 14 | 217 |
| 6/21 | 157 | 151 | 121 | 86 | 31 | 23 | 16 | 102 |
| 1/21 | 142 | 130 | 101 | 74 | 22 | 20 | 14 | 67 |
| 5/1 | 131 | 109 | 76 | 57 | 24 | 15 | 13 | 156 |

最长窗精确范围 126665–126847，frame 11 / phase 6；该窗 43 个墙痕 receive 包含样本中，29 个在 decodeWords，20 个还包含 WallCellCodec.unpack。实际栈包括 ByteArray.uncompress → WallCellCodec.unpack → decodeWords → decode → receive → applyWallPaint → handleMessage → TcpLink.onData。全窗总量分别为 onData 811、handleMessage 585、receive 178、decode 143、decodeWords 141、unpack 110。采样确实覆盖网络接收与解码；没有细化到每个墙块的版本、payload、缓存命中或丢弃次数。

## 当前接收顺序及重复边界

1. 来源由注册到宿主连接的 onLinkMessage 进入客户端 handleMessage（Session.as:382–388）。unitsync 在 :417 先经 RoomSync.accepts，再核地图/房间字符串；worldstate 的 wallPaint 在 :506 先经 sameHostRoom。RoomSync.as:561–590 检查当前 settled 实例、ready/非busy、非权威侧、roomKey/epoch/term。上述检查均在墙痕解码前。
2. GameBridge.as:3508–3509 先按需重绘，再 receive，再处理脏标志。WallImpactVisuals.as:437–443 保留先 observe 本机真实命中，再 decode **整包**，全部有效才 put。decode :318–339 在解码前查数目、坐标、重复cell、累计48k文本限额。
3. **单cell版本是在解码后**，put :403 先处理已毁墙，:404 才判 incoming 版本。若本地预测像素受保护，:428–430 不推进该cell incoming；同版本后续包在ACK后仍必须可用。不能简单把版本过滤搬到 decode 前：整包中“旧版本但坏payload + 新有效cell”本应整包拒绝；未解码即跳过旧cell会改变结果。
4. 相同 d 在现有有界 wordCache 命中时（:343–347）不再调用解压器，但仍 concat 独立数组，然后才在 put 检查版本。缓存按 payload 内容而不是版本键控；仅按 v 不能证明内容相同。128项/131072词/524288字符的 FIFO 缓存可能淘汰旧内容，但本轮没有逐包记录证明淘汰后反复解压的比例，**不建议据此扩缓存**。
5. 同内容重复送达有可达生产路径：Session 同一计时回调先 :1063 发快速 worldstate，再在 :1088/:1111 发200ms累计 unitsync；snapshot :505–520 继续轮转未变化cell，故可与快速更新重复。现有缓存已覆盖驻留的完全相同 d。不能把可达路径等同本轮每个 unpack 样本都来自重复。
6. settle :447–451 在decode前拒绝旧请求或返回同seq旧receipt；acknowledge :462–466 在decode前核pending seq。它们没有证据显示为本轮接收热点。

## 唯一建议候选：只去掉 !W1 的二次标量验证

WallCellCodec.as:48–76 已拒绝非法base64、超限/解压失败、错误原始长度、重复/降序/越界index；它以 readUnsignedShort/readUnsignedInt 读取并显式 Number 转换，每项天然是范围内整数。随后 WallImpactVisuals.decodeWords :349–359 又对相同数组逐项 Number、isFinite、int、Math.floor 和类型检查，重复验证了这些已保证的性质。当前20发送 packed :284 使用这个格式；实际采样有 unpack 110，decodeWords 叶21，以及其下 Math.floor 2 / isFinite 3，证明这条检查路径有执行成本，但21个叶样本不能全部归给循环。

最小候选只在 **成功的 !W1 分支** 直接进入现有缓存保存/返回，保留现有空值/数组长度检查；旧 RoomCodec 分支完整保留原循环和宽容的 Number 转换。不改报文、频率、版本检查位置、observe、protectedPixels、颜色、ACK、整包先校验后落笔或缓存容量与独立数组约定。没有实现，收益未测，不能承诺能解决长帧。尤其 unpack 内的 base64/ByteArray 循环是110个包含样本的主要路径，这个候选不消除它。

若推进，完整类反例必须继续拒绝新格式坏padding/截断zlib/错误count/重复与越界index、保留legacy可转换值及非法值行为，并验证“坏旧cell + 好新cell”整包不写、预测像素ACK前后、同版本同/不同payload与独立返回数组。只有精确像素和现有接收组件一致后才值得原生对照；不提出第二个缓存或时序改造。

