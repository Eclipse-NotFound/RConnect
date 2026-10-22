# recovery18 剩余 opaque 墙痕色差：外部诊断

只定位原因，**不提供功能发布或性能资格**。基于准确 driver04、实际18与 ACC 宿主。18 原运行 `9927d091b8` 及全部原失败不改；这份驱动是独立诊断副本，不替换 driver04。

18 已观察的 round2 两个差异：index8911=`(655,4465)` 的 `FF2C2C28→FF2D2C28`；index9038=`(654,4466)` 的 `FF282825→FF292925`。都在世界 cell `(16,111)`、矩形 `(640,4440,40,40)`。实际 source 第一块 `(280,4120)` 是右侧 gutter，core 为 `(600,4120)`。当前无法确认首块的真实值，所以不修改 covered 算法。

## 观察边界

- 四轮选择器、武器准备、真实 `attack/step/tilehit`、1/1/8/8 刺激、10秒/480样本、所有原检查与原 PNG 证据完全保留。生成器剥去八处观察插入后须逐字符恢复 driver04。
- 只在 round2 开启。baseline、每次真实新 tilehit 所在帧，复制所选 cell 在所有已存在重叠 `nativeBuffers[0]` 的真实交集；保留遍历顺序、origin/core信息、revision、帧号及墙钟。只做小块 `copyPixels`，不设置任何游戏像素、缓存或生成状态。
- 通过现有 `TcpLink.MESSAGE` 的优先级 `100000 / -100000` 保存生产处理前后快照；正常 Session 收信监听优先级为默认0。两个观察器共享同一个真实事件对象，记录原始 `d/v/x/y`，处理后再次核对原消息未变。既不消费队列、不改原消息、不调用 report/capture/receive，也不截获发送函数。
- TcpLink 无公开发送事件。因此这里的 wire 是**已到达对侧、生产处理前的真实消息**，其颜色代表实际传输结果；不是源 socket 发出的准确时刻。Python 离线解码真实 `!W1:` 字节，不从 source 期望颜色反推。
- 如果同帧首次观察到多个 hit，保留该批所有 hit 并标 `sameFrameHitOrderUnknown`；Dictionary 的枚举顺序不冒充原生执行顺序。观察器不包裹 Grafon 回调，故真正逐块绘制的指令顺序仍未直接观察。
- 源快照位于原夹具的 ENTER_FRAME 后观察点（优先级 -6000）；它不是 Grafon callback 内部的截点。若该帧其他后处理已经写过图像，这些写入也会体现在真实快照中，不能据此自动排除它们。
- 最大96个相关消息、210次快照，每次最多4块40×40；超限明确记错，不能以截断数据通过。像素 getVector、JSON和解码在双方动作采样结束后执行。新观察本身会增加开销，不能用这轮延迟/FPS评价候选。
- 保存整个有限cell而非只保存两个已知点，防下次随机decals在同格别处出现差异。独立摘要最多展开16点时间线，包含原两点；更多差异明确标未展开，完整raw快照仍保留，不宣称覆盖其他cell。

## 读结果

原框架 `result.json` 和原 `wall-surface-result.json` 保持原字节，包括原 PNG 表示差异的失败。附加 `gutter-diagnostic-result.json` 只验证观测数据完整性，始终 `diagnostic_only=true`、`gameplay_qualified=false`、`performance_qualified=false`。

每个点可比较：源真实 hit 后的 core/gutter值 → 实际原包的 uint → 同一事件处理前/后各块值。若 wire 与某个 gutter 同值但与 core 不同，只是强关联证据；实际包生成时刻、多个hit合并或中途其他写入仍按记录分析，不由程序自动宣布根因。两点不再复现也如实标记，不预热、不补发、不篡改期望。

## 根会话命令

只准备外部驱动，沿原14声明/编译适配；运行时准确绑定18和已独立回读的 ACC。22输入、共享登记、独占AIR、600秒、后台桌面和原有清理流程全部沿既有 native_tool，不新建执行框架：

```powershell
& $py -B -X utf8 experimental/recovery-wall-gutter-diagnostic/native_tool.py prepare --source build/m52/recovery-14/src --output build/m52/recovery-wall-gutter-driver-01 --build
& $py -B -X utf8 experimental/recovery-wall-gutter-diagnostic/native_tool.py run --candidate build/m52/recovery-18 --drivers build/m52/recovery-wall-gutter-driver-01 --game-candidate build/m52/recovery-wall-surfaces-host-01 --output build/m52/recovery18-wall-gutter-native-01
```

第二条命令 exit0 只表示诊断证据完整，不表示产品正确。原完整框架结果和原严格墙痕失败保留，并在独立结果绑定哈希。实际JVM/AIR由根会话执行，本次交付只做文本生成和离线自检。
