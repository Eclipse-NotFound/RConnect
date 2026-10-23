# 接收阶段离线分析

仅分析既有文件，不编译、不启动游戏、不修改原结果。`analyze.py` 固定复用原 ACK 分析器 `F95E2820…2C608` 的 `packet_key`、`transport_rows`、`ack_rows`；原 schema 为 `rounds[].transport`，不是顶层 `transport_matches`。

## 运行与边界检查

在 RConnect 目录运行（Python 不使用 `-O`）：

```text
python -B -X utf8 experimental/recovery-ordinary-wall-rx-analysis/analyze.py --self-test
python -B -X utf8 experimental/recovery-ordinary-wall-rx-analysis/analyze.py --input build/m52/recovery-ordinary-wall-rx-native-01 --supplemental build/m52/recovery-ordinary-wall-rx-supplemental-01/receipt.json
```

第二条只新建该 run 下的 `rx-stage-analysis.json`；已有输出拒绝覆盖。源结果、像素资格、八份 timing JSON、补充资格及其 validator 均绑定实际 SHA。补充回执其余历史准入依赖不在此重复验证；本工具验证自己使用的输入，补充审计的完整依赖保留在其原回执中。

11 项内存内边界检查实际通过：已知可加阶段、半包标记、负跨进程间隔保留、两种时钟残差、原 FIFO 配对及事件索引、重复键不覆盖、未匹配保留、缺字段/倒序/错误半包标记/被改原配对拒绝。该检查不是游戏或性能资格。

## 分段定义

- 完全复用原有键与 FIFO 配对，并保存原匹配行、两端事件索引和时间戳；不以“附近时间”或仅 `seq` 配对。若已有 `timing-analysis.json`，先逐项复算一致。原分析器未能通过其入口时，直接调用冻结的原函数，明确标记来源。
- `tx_flush_to_callback_entry_cross_process_ms` 使用两端 `Date`。它可能包含发送缓冲、传输、运行时通知调度等，不是纯网络耗时，`flush` 也不是底层真正发出时间。
- 回调内使用接收端 `getTimer`。`components` 可相加，依次含读前、读取、前序提取/解码/派发、当前提取/解码、解码后至原 rx、其它未分离跨度。`entry_to_read_done` 只是方便查阅的小计，不再次参与加总。
- 前序累计耗时是“当前消息前已有多少工作”，不能跨多条消息求和当 CPU 总量。Codec 含原有校验和 AMF/JSON 解析，不是仅 AMF。
- `rxCarriedFirstFrame` 表示本次回调进来前已有半包；本次回调入口不能当原消息首字节到达。跨进程负间隔和 `Date`/`getTimer` 残差保留、不校正。
- 键至多含三格元数据前缀。`metadata_prefix_only` 明示身份依据有限；不是完整包像素指纹。未匹配原事件完整列出。
- `rxProbeTotalMs` 仅含 active 窗内新增助手的内部工作，不含取时、分支等全部成本；不是净生产性能。未读取结尾大批量像素文件，未把其读回耗时混入本分段。

## 已有真实 rx01 结果

Run：`build/cooperation/a3ded11cae`；数据目录：`build/m52/recovery-ordinary-wall-rx-native-01`。

原 `ack-timing-result.json` 的 `passed=false` 和 `diagnostic_samples_ready=false` **原样保留**：其 host 第 0/2 轮只发送、没有墙面接收记录，被旧新增准入误判。原功能、框架、像素与 ACK 记录均通过。独立 `recovery-ordinary-wall-rx-supplemental-01/receipt.json` 按实际方向确认八份标量证据完整；本分析明确记录使用这份补充资格，不把原结果改绿。

199 对、0 未匹配、0 重复键、0 已标记半包首帧；80 对只有元数据前缀。全部 199 条回调内分段非重叠、可重构原跨度，时钟残差为 −1…1 ms。

| 发送方向/种类 | 对数 | flush→回调入口中位 / 最大 | 回调入口→原 rx 中位 / 最大 |
|---|---:|---:|---:|
| 主→加 paint | 181 | 50 / 315 ms | 3 / 17 ms |
| 加→主 report | 9 | 72 / 171 ms | 1 / 3 ms |
| 主→加 ACK | 9 | 60 / 125 ms | 8 / 14 ms |

整体回调前中位 51 ms、P95 180 ms；回调内中位 2 ms、P95 10 ms、最大 17 ms。当前消息解码中位 1 ms、最大 8 ms；前序派发中位 1 ms、最大 15 ms。36 条原跨度 ≥100 ms，其中 34 条在回调入口前就已 ≥100 ms。

本轮主要等待在接收回调入口之前；解码或同批前序处理不能解释这部分等待。尚不能由此区分本机发送缓冲、实际传输与运行时通知调度，更不能宣称已找到修复或有净性能收益。

冻结分析器 SHA：`109B9ABA4FB0DB9A7C17D12F439BB7A1278FAFAEFD2F4DE77D38A6DB82E6098B`。
实际输出 SHA：`CE2DCEF9DE3A72F633975A3F2428811C1A48127841AAA48E0D89BCEBC52C00C6`。
