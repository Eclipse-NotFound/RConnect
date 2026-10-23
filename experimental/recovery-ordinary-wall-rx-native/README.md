# 接收阶段计时：薄运行适配

恢复准确原宿主 `6616B1…289B`（FWS41）、原 AIR namespace30、原配置 `wallAckTiming=1`，不带 socket 开关。产品独立使用 `build/m52/recovery-ordinary-wall-rx-timing-01` / `0.2.24-wallrxtime1`，不改原 5771 计时候选、已完成的 off/on 回执或原测试驱动。本目录只准备 Python 入口；根统一构建与运行。

## 明确复用边界

先读取固定 SHA 的原 ACK 入口并在其真实路径调用原 `preflight()`，核原 5771 产品的真实资格；随后另行检查新产品的 prepared/compile、实际 SWF、overlay 与全部源/工具指纹。不会把旧的 PRODUCT、CANDIDATE、历史绑定或审核函数指向新产品后宣称旧检查通过。

新入口只在内存中对固定原源做六处有次数断言的替换：产品路径、overlay 路径、版本、全新输出目录名；末尾复验失败撤销诊断资格；最终保存两份实际适配源码。其余 main、四轮 runner、collect、原像素分析及错误规则照旧。private runner 只替换一处候选路径，保留原 namespace、单项私有配置和共享 main。运行目录保存 `rx-adapted-entry.py`、`rx-adapted-private-entry.py`，admission 同时记录原产品回执与新实际源摘要，便于逐字审核。

原配置完整比较仍只允许 `wallAckTiming=1`，未增加新配置；头部明确核宿主41/产品38。原 600 秒、6 GiB 启动/512 MiB 运行、独占游戏、私有桌面、登记、22 安装输入、所有原错误和自有资源清理不变。结果仍为 `ack-timing-result.json`，原框架 `result.json` 与像素结果独立保留。`functional_pass` 只表示原业务检查；接收计时字段缺失或不一致仅撤销诊断资格，不能改原失败为成功。

八份原计时 JSON 都须含接收证据及 `rxProbeCalls/TotalMs/MaxMs`，零毫秒合法。只核 `rx-report/rx-ack/rx-paint` 原有行的新标量：回调→读取→提取→解码→原记录时刻的顺序、回调固定字段、帧序号从1递增、此前帧/字节及处理计数不倒退、当前帧位于真实缓冲范围。非墙消息没有观察行，帧序号允许跳号；`rxPriorDispatchCount` 允许小于此前完整帧数。只要任一份缺失或不成立，`rx_samples_ready` 与最终 `diagnostic_samples_ready` 为 false，原业务结果仍独立保留。助手测量开销字段不等于全部诊断侵入成本，不能从实际耗时中简单扣除。

## 执行

准确新产品构建完成后，由根在 RConnect 目录运行：

```text
python -B -X utf8 experimental/recovery-ordinary-wall-rx-native/run_native.py --check
python -B -X utf8 experimental/recovery-ordinary-wall-rx-native/run_native.py --output build/m52/recovery-ordinary-wall-rx-native-01
```

原 analyze.py 继续读取同名结果及八份计时 JSON；新增标量的进一步分解由根离线分析，不修改原像素资格。接收回调开始表示 AIR 已通知应用后的时刻，不是网卡收到首字节的时刻；已有缓存可能来自前一回调。新记录用于区分读取、提取、解码及此前消息处理耗时，不能单独归因网络延迟或证明性能改善。
