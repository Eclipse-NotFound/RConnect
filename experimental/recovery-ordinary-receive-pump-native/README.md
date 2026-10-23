# 接收主动读取候选：薄运行适配

新产品 `build/m52/recovery-ordinary-receive-pump-01` / `0.2.24-receivepump1`，overlay 为 `experimental/recovery-ordinary-receive-pump/src`。复用冻结 rx 入口展开后的原 ACK main；只精确替换产品、overlay、版本及新输出目录四处，私有 runner 只换候选路径一处。原接收标量检查只修正“各端各轮必须有墙接收事件”的过严条件，另外以原 proof 的 source 身份核每轮方向。旧 rx 失败回执及其独立补充资格都不改。

先在真实旧路径核 rx 构建与原 5771 构建，再独立核新实际候选。仍使用准确 6616 宿主 SWF41、namespace30、SWF38 模组与单项私有配置 wallAckTiming1，不带 socket 选项。原四轮驱动、全部像素和错误检查、600 秒、6 GiB/512 MiB、独占游戏、私有桌面、登记、22 安装文件及自有清理原样保留。

根在准确候选构建完成后执行：

```text
python -B -X utf8 experimental/recovery-ordinary-receive-pump-native/run_native.py --check
python -B -X utf8 experimental/recovery-ordinary-receive-pump-native/run_native.py --output build/m52/recovery-ordinary-receive-pump-native-01
```

新输出保存实际展开的 `pump-expanded-entry.py`、`pump-expanded-private-entry.py` 和 `pump-scalar-validator.py`，摘要记在 admission。原结果与 `ack-timing-result.json` 仍分开，functional_pass 不受新诊断放宽。原八份计时资格、完整接收标量、准确方向及主动读取覆盖必须同时成立；缺少任何新增记录不能算候选实际启用成功。进一步时延比较离线进行，不把单次功能或新路径覆盖当作性能资格。

新增覆盖核每份 `rxPollCalls/rxPollReadCalls/rxPollReadBytes` 均为非负整数，成功读取次数不超过调用次数；所有相关接收行的 `rxEntryReason` 必须是 `socket-data` 或 `tick-poll`。每个角色四轮合计都须有真实非空 poll 读取及至少一条相关 tick-poll 接收行。不要求每轮都有主动读取，因为正常 SOCKET_DATA 可能更早到达；不把接收行数与 poll 次数相等，开始标记所在同次读取可能发生在统计窗口之前。未覆盖只表示该候选路径未经验证，原游戏功能判断仍独立。

## 实际结果

`build/m52/recovery-ordinary-receive-pump-native-01` / `05fe881aee`：functional_pass、ack_timing_samples_ready、rx_samples_ready为true，pump_samples_ready及总体passed为false。1099次检查没有一次非空主动读取，新增覆盖没有通过；保留原始结果，不以功能通过替代它。

`compare.py` 使用冻结的原phase/trace解析函数，独立核旧rx补充资格与本次功能、接收证据，生成 `build/m52/recovery-ordinary-receive-pump-first-pair.json`。所有36阶段完整，没有遗漏或重复；比较限制与实际数字见相邻recovery-ordinary-receive-pump/README.md。没有可确认收益，不部署、不提高轮询频率继续盲试。
