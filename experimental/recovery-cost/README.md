# 两处采集消重（基线 recovery-02）

仅准备独立稀疏覆盖和组件；未编译、未运行 AIR、未改安装版。`inputs.json` 记录 6 份覆盖与冻结基线的实际字节 SHA；`proposal.patch` 可逐方法合并，不要覆盖主会话后续整合整文件。

| 文件 | 仅需合并的部分 |
|---|---|
| `ProjectileFrameStream.as` | 新增 `afterWithRevision`，保留原 `after/merge/samePoint` |
| `UnitPresentation.as` | `captureEffects` 中选新点／修订点的两遍扫描改用新方法 |
| `EnergyImpactVisuals.as` | `captureDelta` 的同类两遍扫描改用新方法 |
| `WallImpactVisuals.as` | `snapshot` 增加 `observeNow=true`，未知调用默认仍观察 |
| `GameBridge.as` | `scanTileReports` 紧邻 observe 后用 `report(loc,false)`；`readWallPaint(observeNow=true)` 透传 |
| `Session.as` | 唯一 `readTilePatch → readWallPaint` 连续位置改传 false |

新点仍按输入顺序保留；只把第一个“同 stamp 且值变了”的点前插，不排序、不额外去重。方法分别接收新点阈值和修订阈值，连原版 `fastAt=null` 时“新点阈值为 -Infinity、修订阈值为 0”的边缘行为也保持。没有改 50/200 ms 频率、完整历史、64 点限制、结束保留、死亡时钟、序号或补发规则；没有引入 probe 候选。玩家 50 ms 携带完整历史仅留作后续调查，本覆盖不改协议。

## 组件与证据边界

`prepare.py` 只生成自己的覆盖/夹具，不启动 Java/AIR。组件入口为 `components/RecoveryCostChecks.as`，以 `components` 为 source-path 编译；产物应由主会话按共享登记放入**新的** `build/m52` 目录，唯一 AIR ID、隐藏桌面、独立存储。结果在该 ID 的 `Local Store/result.json`。

- 前后 `captureEffects/captureDelta/samePoint/after` 都从真实源码逐字提取；新 helper 也提取自覆盖。只插入循环体访问计数，原条件不改。原生武器发现、`captureFlight` 与地形报告生产者为明确替身；不声称完整游戏或 TCP 验证。
- 前后墙痕类保留实际 `WallImpactVisuals` 与 `RoomCodec`，只改测试类名并增加 observe 计数。调用者来自真实 GameBridge 方法和 Session 的连续代码片段。夹具提供 160×80 位图、8 块地形及确认接触对象；比较整个载荷、持久状态与每个像素。
- 对照包含重复/乱序 stamp、无新点终末、仅修订、混合修订与新点、首个修订、null/undefined 游标、色彩数组、NaN/负零、无 clip/独立 impact、64 点无变化，并检查输出所有字段及状态所有字段。
- 计数有明确等式：64 点弹体及能量效果各一条，原两遍共 256 次历史访问，新一遍共 128 次；两条墙痕配对各由 2 次 observe 降至 1 次。未知 snapshot/readWallPaint/report 调用仍为 1 次，已有显式快速 report 仍为 0 次。计数不是 CPU 提升百分比。
- `check_static.py` 核对基线未动、未改方法、基本结构及有限输入顺序模型；模型结果不能替代 AS 组件。当前所有 AS 运行断言仍待主会话编译执行，不报通过。

执行准备：在 `mods/RConnect` 下用已知 Python 运行 `experimental/recovery-cost/prepare.py`，再运行 `experimental/recovery-cost/check_static.py`（建议 `-B -X utf8`）。实机仍需核对重复射击、墙痕 ACK/预测保护、终态与暂停；组件通过也不能直接称性能合格。
