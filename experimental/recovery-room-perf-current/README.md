# roomperf1：当前房间恢复的小范围候选

仅准备，未构建、未原生运行、未部署；不宣称达到单人加载时间。基底为准确 `production-05 / roomfix5 / 78C052…F4699`，本目录只保存 5 类覆盖：

- `NativeTileState`：直接复用 terrain-loop 的按调用生成坐标计划、槽类型与行标记向量。
- `TerrainSync`：直接复用 terrain-capture 的原生 Tile 本地伤害观察，只比较碰撞状态与 HP；宿主完整字段、协议、报告频率、预测及 ACK 不变。
- `GameBridge`：只删去 `reconcileObjs` 未读取的 byId 预扫描。
- `RoomTerrainView`：只减少 `unchanged` 每格临时数组；原 28 个字段（包括 shelf）、严格比较和刷新行为保留。
- `RConnectMod`：版本改为 `0.2.24-roomperf1`。

其余 76 类及基底全部工具逐字保持。没有提前加载架构、退休批处理、身份索引或 shelf 忽略规则；完整地形恢复和必要重绘仍执行。所有来源、相对 prod05 差分、5 类哈希及完整预期 81 类清单见 `source-manifest.json`、`source.diff`。

历史组件证据是 67/0、154/0、55/0，检查其真实结果、全部冻结输入及 SWF 指纹。154 项当时已经同时用了优化后的 NativeTileState。它们不等同当前完整游戏验证；55 项的 Tile 夹具也不是真实 RV/地图。当前组合仍须由主会话同场景对照，旧回执不改写。

从 `mods/RConnect` 执行文本准备或复核：

```text
python -B -X utf8 experimental/recovery-room-perf-current/prepare.py --prepare
python -B -X utf8 experimental/recovery-room-perf-current/prepare.py --check
```

主会话后续可调用：

```text
python -B -X utf8 experimental/recovery-room-perf-current/build.py build/m52/recovery-room-perf-current-01 --registry-wait 900
```

薄入口核完整本提案后，临时向原 `production-v5/build.py` 提供本目录与 prod05 的 BASE；原构建文件不复制、不改写。原两条 Java、384 MiB 堆、1 GiB 开始/512 MiB 停止保护、300 秒单命令时限、共享登记、自有进程回收、安装前后相同检查全保留。正式 RConnect 必须仍为基底 78C052 才能构建；其余实际安装按原构建器实时记录，不冒充历史环境。

新输出 prepared.json 的 recipe_sha256 指向实际执行的旧有界构建器；overlay_manifest_sha256 同时绑定本薄入口、准备脚本和来源证据。构建时才在新 build 输出生成完整源/工具副本，本目录不会复制完整树。无测试和部署入口。
