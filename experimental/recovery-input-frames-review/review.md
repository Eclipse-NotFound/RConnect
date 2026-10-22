# 398cddcf6b：加入侧首轮输入恢复窗口 CPU 审阅

2026-10-22，只读分析。没有修改生产、驱动、原记录，没有编译或启动 AIR。原加入侧输入基线超时和宿主等待超时保持 FAIL；没有完整三轮结果。本轮是诊断，不是加载耗时资格。

## 结论

最窄、证据最明确的候选是 **TerrainSync.capture 的真实 Tile 未变化判断**。两个有效完整窗口各有30/134、26/136个CPU样本落在这条调用链，全部不是 `[reap]` 叶节点：`Timer → Session.onTick → flushRoomReports → scanTileReports → report → capture`。地图为240×125，共30,000格；capture逐格比较13字段，但只有旧碰撞状态和耐久参与本地伤害请求。可只在capture对真实Tile比较`phis/hp`，保留hostPatch的13字段比较及动态替身原路径。

镜像呈现亦有实际成本，但当前证据不支持跳动画或再调时钟。`tickFrozenAnims`共79/345个包含式样本，其中34个叶为`[reap]`；RemoteMotion.sampleTimed占45个（其中24个reap叶）。应先处理可证明不改变结果的工作，不能把GC所停留的调用位置当作该函数制造全部垃圾的证据。

有效范围内`[reap]`叶共77/345（22.3%），显著但不是多数。失效首窗及窗间未取样时间仍未知，不能据此说整个首进耗时主要由GC或Terrain引起。

## 实际时间范围

所有时间均为加入侧getTimer，未把Sample.time微秒强行映射到此时钟。表内CPU是采样数，不是毫秒。

|窗/帧|实际起止|范围ms|CPU|结论|关闭/枚举成本ms|
|---|---:|---:|---:|---|---:|
|0/102|38806–41762|2956|0|no-cpu-samples，全部拒绝|1/0|
|1/103|44176–44459|283|0|endNative324600超过250000，未枚举|1/0|
|2/104|44658–44778|120|134|完整ENTER→RENDER|214/213|
|3/105|45027–45153|126|136|完整ENTER→RENDER|137/137|
|4/106|45662–45730|68|75|inputError触发的完整缓冲半窗；没有最终RENDER|80/79|

窗2/3/4栈均无尾部截断；总诊断仍因无效窗和半窗不具备完整六窗/完整覆盖资格。

- grant处理返回38761；首窗在38806开始。首窗结束状态从pause/cover/busy=true变为false，但该2956ms**没有可用调用栈**。
- 首窗关闭完成41763至下一ENTER44176之间2413ms没有采样。不能给它分配函数原因。
- 输入基线44406开始，实际driver帧标记44726、45101、45730，间隔320/375/629ms，总1324ms，超过原1000ms期限；尚未发KEY_DOWN。
- 对应ENTER间隔482/369/635ms。窗2关闭枚举214ms、窗3枚举137ms都落在这次输入基线内。窗4的80ms是在原超时决定以后，不能解释触发超时之前的629ms。
- 窗2关闭完成44992至下一ENTER45027仍有35ms；窗3关闭完成45290至下一ENTER45662仍有372ms未取样。因而即使计出枚举351ms，也**不能相减后宣布正常运行可在973ms通过**：采样改变调度/GC，而未取样段未知。
- 半窗4只含ENTER至driver失败点；其后Timer/RENDER未被采样。该窗Session样本为0不能证明本帧没有网络工作。

## 有效样本的具体内容

以下为包含该调用帧的样本数，彼此可能重叠，不可相加或换算FPS。括号为该集合中叶为`[reap]`的数量。

|调用链|窗2：134|窗3：136|半窗4：75|
|---|---:|---:|---:|
|Session.onTick|51(10)|51(8)|0|
|flushRoomReports|44(7)|42(3)|0|
|TerrainSync.capture|30(0)|26(0)|0|
|GameBridge.tickFrozenAnims|30(15)|25(10)|24(9)|
|RemoteMotion.sampleTimed|21(11)|11(5)|13(8)|
|RealisticVisionMod.onFrameInner|11(2)|12(2)|13(1)|
|Grafon.sceneAdvanceWarm|3|11|3|
|WallBlendMod.onFrame|0|2(1)|0|
|LAD调用链|9(2)|9(3)|15(4)|

同步：这是定时器主动采集/发送开销。有效样本没有`TcpLink.onData`/消息接收处理栈；TcpLink.send仅3、BinaryMessageCodec.pack仅1。不能据此指认“收包突发”或继续改二进制编码。准确13的Session.as:1000–1004以真实时间每200ms安排sceneDue，1177–1181调用地形、掉落、物体扫描；不是每个50ms传输tick都扫全地形。低帧率下本轮两个完整窗都碰到sceneDue。

Terrain：叶节点matchesTile28、capture23、tile5，共56；准确13 TerrainSync.as:136–159对observed每格遍历，尚无局部脏列表。**不要通过降低同步频率、省略离屏格或跳capture解决**，会改变尚未得到ACK的破坏收集。

镜像：准确13 GameBridge.as:6389–6427仍完成位置、身体、武器、命中代理和光标更新。UnitPresentation.tick包含9个样本，TelekinesisVisuals.paint/glows链6个，其中4个是在`DisplayObject.filters`读取处reap。最窄后续假设是同次paint避免先构造嵌套glow数组再比较；仍须每次读真实filters，保留原生/其它模组改滤镜的语义，不能仅凭旧s.aura对象身份跳过。当前量不足以把它升为主修方向。RemoteMotion.curve/sampleTimed的reap不证明曲线运算本身在分配；不据此降低插值或删除追赶策略。

CS：明确出现在准确FD92宿主内的`Grafon.sceneEnsureUpcoming → sceneAdvanceWarm → drawKusok`；sceneAdvanceWarm共17，drawKusok共12。宿主Grafon.as:2387–2447区分可见块强制准备与后台warm；3189起保存/恢复材质状态并逐步画块。它有真实成本，但没有块身份/force参数证据证明这17个样本是重复或无用绘制。最窄方向限在同一次warm保存/恢复中避免冗余遍历，不能删掉首屏块、暂停预绘或拿更低warm预算当等价优化。另sceneNativeEnvironment共8、叶6，已有同region立即返回；不能仅看名称就再加缓存。

RV：36个样本，其中updateWallSurface17、RVWallSurface.updateContour13、copyForeground8；sceneRefreshWallFieldFast8（叶6）、scenePrepareOcclusionFast4。已有宿主分块表面及光照变化语义，当前栈不含可证明“相同输入重复”的证据；保持频率和视觉结果，不能禁用遮挡/轮廓。WB只有2个样本，其中一个log链reap，不足以要求新的WB优化。LAD共33，部分为灯具gotoAndStop/显示子对象构造和apertureSignature的join/reap；仅报告当前实际成本，不外推其整轮占比。

## capture两字段方案的安全审阅

准确13/14/15 TerrainSync同字节。`observed`是private，capture只消费旧记录的x/y/p/h；其余引用位于enter/restoreCheckpoint/apply。apply在改字段前采fresh before，写入observed后只比较刚写入的新值，不消费此前缓存的其它字段。hostPatch读`base`（enter时与observed共享初始对象，但之后只替换observed引用、不原地改对象）；checkpoint直接采当前真实tile。故只变front/back/灯光等时不刷新observed的其它字段，不影响任何对外输出。

允许的最窄变化：capture分支中`t as Tile`非空时，以`old.p===native.phis && old.h===native.hp`判断无变化；否则仍调用原matchesTile。不要修改共用matchesTile，不新增跨帧缓存，不改queued/pending/receipts。真实Tile的phis/hp是public int；严格等号仍保留，动态替身/getter/NaN路径完整照旧。

必须以真实旧新完整类比较：只变其它11字段再hostPatch、视觉变更后再掉HP/破坏、door/indestruct先切换后受击、NaN动态字段及getter顺序、pending期间二次伤害、ACK预测保护、finishReports、checkpoint/恢复、base独立性、换房reset。30,000真实Tile同输入ABBA只计函数执行，不含构造/断言/序列化；独立组件成本不等于整轮加载改善。

## 冻结身份

- 运行398cddcf6b；生产13：1177eb1ae9b227bcf3c0eb39dedad92b63ac16dcb7ffb0b421ea0a2024bfddb1；宿主FD92：fd92fbd5ae92b5c8d4cbf8151d11796a140810f34988b7031e258c747d86734e。
- 驱动c8d1f7d9ef375316e75f2087ddec3d5aec4f97d3a14365ded9cfb6548941c456；harness d52ef4300c7d472ee05884d7b4709f4abf80b3e6ff935b695a9ed986db021086。
- prepared.json（recovery-input-cpu-frames-partial-driver-01）：5be59c0f380d56c103552a4907108e5c15afb8e1a127b596bb627143424bebd9。
- input.json：742e9de7dcae87c867275be9ba7eeefeb674980c8fcf1d7688092984ceb75b38；run.json：abc8976f7f713a542eaca34d57c99cb1863883de4fbfbc97164faf187e229fa4。
- 原始CPU JSON：f824bd2bf8ec01b2aa463382830bbf18b771ed0443f2776184149641276b762f；collector review.json：f782eaeec777d4d3044b971f27e797df5c031d63739b3f65ca0de41f658918e9。
- join.log：37e396acc85f91b994e308d70f3e2751aa9bb5928e3ca4dcb152ed68b3455abe；host.log：00dd313b773bd6a340cf12c229923a2d15571b359dde91bcc916f2a5a150929e。
- CS7f1f2961…d6b51f、RV7852f61e…e86764、WB14112da0…c0920d、LAD8adba691…c7e3ef；完整22项见冻结input/prepared，collector确认安装未变。
- TerrainSync.as（14与15）：317c9658b0632f3bb8333c11cd302c68ef45e7a9f2f54ed6b6c631b6c1b92b44。
