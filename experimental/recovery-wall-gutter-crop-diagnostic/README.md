# 完整128×128 crop的独立墙色诊断

只判因，不提供功能或性能资格。保持原 driver04 的四个刺激、武器条件、真实原生命中、原像素检查、10秒/480样本和PNG证据；沿同一 runner。准确候选18、独立回读通过的ACC宿主。没有生产改动，没有编译或启动游戏。

## 为什么需要这一版

旧诊断7855df2737已完整观察cell16,111，9组源快照、42个实际消息均正确；实际唯一错点却在cell16,110的`(651,4431)`。源该点一直为baseline `FF878881`，对侧额外出现`FF868881`。这并未证明首采gutter；详见相邻 `recovery-wall-gutter-review`。

新 helper 改为完整覆盖原验证crop `(target.x-64,target.y-64,128,128)`，没有只取“固体格”的依赖，也不排除未变化的源像素。仍只有round2启用，原两旧错点和任何新错点都在同一份有限crop证据中。

## 观察和精确性

- 与旧诊断相同的8处纯观察插入。`generate.py`逆向剥除后逐字符恢复driver04，原检查不变。`NativeWallSurfaceProbe.as`和原 `verify_results.py`逐字节相同。
- baseline、每次实际新hit帧、每个相关真实消息处理前/后，对已存在的所有重叠buffer只做`copyPixels`。保留实际枚举位置、core/gutter原点、尺寸、revision及时间。没有设置游戏像素或缓存，没有人工命中，没有调用生产capture/report/receive。
- 原128crop最多相交25个40×40 wire格。`x/y/v/d`原样保留；同一个事件对象处理后再次取原字段严格比较。重复格是错误，合法多格消息不视为歧义。
- `getVector`只在双方动作采样结束后的export执行。每个uint用 `ByteArray.writeUnsignedInt` 显式大端写入、zlib压缩再base64；**不用PNG编码保存精确颜色**。记录wordCount/rawBytes/compressedBytes；Python逐项核对几何、原始字数、压缩字节长度、base64、解压上限及无尾随数据，再原样还原uint。
- 解析器逐快照证明原crop每个像素都恰好具有一个真实core；多个gutter允许且分别保留。新错点时间线按其实际世界格选择原包，没有最近颜色/时间的猜配。最多展开16点，更多错点明确标未展开，但完整crop原始证据仍在。
- 帧观察不是Grafon内部绘制断点；同帧多个hit仍标顺序未知。wire时刻是对侧真实收包前观察，源socket发送时刻仍未采集。不会自动宣布采集、写入或后处理是根因。

## 容量与峰值

原**96相关消息、210快照、每快照4块、32MiB单证据文件**限制不变。扩大空间范围不增加时间采样或快照数量。

- 新增快照BitmapData最坏 `210×4×128×128×4 = 52.5MiB`，实际交集更小；本固定crop最坏四块合计43264像素、每快照169KiB，210份约34.7MiB。它是额外诊断内存，不能拿该轮评性能。原动作采样本身的图像内存另计。
- export一次只保留一块最多64KiB的uint向量及字节缓冲，编码后立即dispose对应暂存bitmap。没有转换十进制像素数组。
- 每块最多65536原始字节、70000压缩字节、93336个base64字符。所有块编码字符合计最多6MiB；实际原包d字符合计最多1,280,640（保留旧96×13340的原始总上界），前/后原字段副本合计不到2.45MiB。超限明确失败，绝不截断后通过。
- 原runner仍拒绝超过32MiB的最终proof文件；并未提高门槛。旧7855的完整proof约主5.74MiB、加10.03MiB，含旧未压缩诊断。新压缩预算为这次完整crop诊断额外留有限空间，不保证任意数据都压得下；超限保留失败。

## 结果与根会话命令

原 `result.json` 与原 `wall-surface-result.json` 不改字节，包括旧PNG表示误拒；独立`gutter-diagnostic-result.json`只验证观察完整性。原 uint 功能判定后续由既有独立 `verify_evidence.py` 在新输出文件中复核。所有诊断结果始终 `diagnostic_only=true`、`gameplay_qualified=false`、`performance_qualified=false`。

```powershell
& $py -B -X utf8 experimental/recovery-wall-gutter-crop-diagnostic/native_tool.py prepare --source build/m52/recovery-14/src --output build/m52/recovery-wall-gutter-crop-driver-01 --build
& $py -B -X utf8 experimental/recovery-wall-gutter-crop-diagnostic/native_tool.py run --candidate build/m52/recovery-18 --drivers build/m52/recovery-wall-gutter-crop-driver-01 --game-candidate build/m52/recovery-wall-surfaces-host-01 --output build/m52/recovery18-wall-gutter-crop-native-01
```

沿既有22输入、共享登记、独占AIR、600秒、后台桌面及清理，不另加执行框架。离线检查验证精确原驱动、全crop覆盖、原失败点、颜色无损编解码、合法多格、同事件前后绑定和截断/越界/容量负例；并非游戏实测。
