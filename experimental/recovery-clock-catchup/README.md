# recovery09：累计时钟校准的连续追赶候选

本目录只有一份生产覆盖：`src/rconnect/game/RemoteMotion.as`。基线为冻结09，SWF `1507686cd0811f6e6697a663ceed08ed7f85c8562399d50ccc79a891f8503acf`；该类与08字节相同，原SHA `cd58b1286bc913149ac02ad60713e82c251b8e574043444b4f3ccfd6e4a2ebc5`。不修改 integrated、冻结包、安装版、协议或任何原生飞行断言。**尚未编译/执行AS组件或AIR，不能合格；以下收益仅为标量模型预演。**

## 算法和预期行为变化

普通actor收到更新时，只把 `previousOffset-offset` 累加为待追回的校准时间。每次真正推进显示前，以当前实际落后量封顶；真正超过 `max(100ms,interval×2)` 才启用追赶。没有校准欠账、单次小修正、一般丢包造成的缓冲变化都沿原公式。

追赶速度上限1.5倍；每毫秒最多变化0.003。由之前的普通播放速度起步，按前后速度平均值积分，追回后平滑返回普通速度。实际比1倍多走的部分偿还欠账；重复或倒退的sample时间不推进、不加速。最终仍截在最新收到的源时间，绝不外推。

**预期改变包括旧普通actor单次>100ms校准的cursor直接跳跃**：现在也只记账并连续追回。旧的>250ms偏移重置、断流/时间大跨越和真实大位移重置仍是原重置规则，不伪装成平滑校准。

保留边界：

- `held()/enemy()/startImmediately drop` 不进入新分支；保留它们的旧缓冲、恢复及大校准规则。组件逐次比较完整输出。
- `retainRate` 优先固定1倍，即便新的大校准在有限时长效果播放期间到达；多owner、重复释放、动态开始/结束均覆盖。不会给弹体单独的时钟，真实 `ProjectileFrameStream.sourceTime` 仍读取actor游标。
- `settle`、旧时间重置、旧无时间戳checkpoint、roomKey/epoch边界和原生teleport事件清除旧校准账。暂停期间不留下恢复加速。
- 不改任何位置插值、武器/身体姿态插值、弹体原生结束或寿命门槛。加速可能改变尚未retain的普通动画经过各帧的时刻，这是追赶本身的取舍，仍须原八轮实测核验；不以模型替代尾段/像素断言。

## 真实记录与模型结果

输入来自诊断 `dae70df14b/join.log`，SHA `14b891469c6ad35a94d5c8d242c0ff9e424c497d53e638ef3a1c47209ac752f0`。case0 owner motion id2的180条push前、push后及sample后记录全部按原次序保留。首条只有一个历史点，从原记录的stamp/arrival/sample时间通过public push/sample重建初始状态，没有修改类的private字段。

记录没有导出完整玩家快照。因此这是**真实调用时间/源时间的重放**，采用当时静止坐标220/720，额外aim/weapon字段为明确夹具；不声称原游戏视觉轨迹完整回放。`trace.json` 与 `ClockTrace.as` 保留原180条数字和证据hash；组件记录每步old/new游标及差值，结束一次性写结果，无热路径文件写。

旧标量模型复现全部记录的最大游标误差为0。首个弹体样本84385能够进入播放的时刻：

|参数|旧可播时刻|新可播时刻|提前|有效包后仍等待|
|---|---:|---:|---:|---:|
|最高1.25x，变化0.003/ms|46159|46067|92ms|305ms|
|**选用1.5x，变化0.003/ms**|46159|45956|203ms|194ms|
|最高1.5x，变化0.002/ms|46159|45956|203ms|194ms|

这些时刻对应原采样调用处，**不是新SWF实测首次出图**。实际原首次写显示46163另有函数/渲染开销。没有给改善百分比或性能通过。

## 可执行组件：40条，尚待运行

入口 `components/ClockCatchupChecks.as`，通过原生AIR组件小框架启动。Before/After各是实际完整生产类，仅类名不同；不提取一个简化时钟来冒充AS实现。Teleport的valid/split和WeaponDisplay.interpolate从同09原方法逐字提取，ProjectileFrameStream全类复制，仅替换测试类名。生产覆盖没有诊断hook。

40条断言覆盖：旧AS逐条复现真实数字；180条输入完整和不变；新非reset push不跳时；正常/只有缓冲变化网络逐次完全等价；held/drop/enemy在真实时序下逐次完整等价；单次小/大及累计校准；从0.9倍普通速度连续启动；限速与变速率；100次同时间调用；乱序/重复；不外推；还清后恢复旧输出；SATS settle及新push；超时/大偏移/legacy重置；房间/epoch/teleport清理；有限效果多owner动态retain/release、大校准期间1倍、200ms原生时长；actor/弹体同钟及死亡detach锚点。

仅旧运行日志数字往返允许4个ULP（相邻双精度数的间距）；结构、字段、输入次序、Boolean严格。stable及受保护策略的旧新输出使用严格逐字段相等。加速度边界的1e-9仅用于新数学断言浮点累积，不涉及原飞行/寿命测试。

当前已执行纯Python静态自检和模型：源码派生与原类边界、公共接口、AS单类/保留字、真实旧模型0误差、选定模型203ms、稳定流等价、速度及加速度、同时间调用和恢复后等价。**不是AS编译或组件通过。** 无新进程，目录小于1MiB。

主会话可按现有登记串行执行：

```powershell
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/recovery-clock-catchup/prepare.py --verify
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 tools/validation/run_recovery_component.py --source experimental/recovery-clock-catchup/components --entry ClockCatchupChecks.as --output build/m52/recovery-clock-catchup-component-01 --expected 40 --registry-wait 900
```

复用小组件既有共享game登记、唯一AppID、HiddenProcess、1GiB启动/512MiB终止、60s AIR上限、自有进程清理、安装22输入前后和逐条断言审核。只在最后写一次result.json。失败包不得覆盖。组件通过后仍须真实八轮及暂停/抓持/有限效果原断言；本目录不自动整合部署。
