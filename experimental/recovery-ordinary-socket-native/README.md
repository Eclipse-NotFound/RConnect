# 真实 Socket off/on 隔离对照入口

只准备入口；此目录不编译、不部署。根会先准备新宿主，再按 off/on 串行运行相同的原四轮驱动。产品为 `build/m52/recovery-ordinary-socket-nodelay-02`（3B6DF6…81B03，0.2.24-sockettrial1）；01 的构建失败保留。两组产品、宿主、驱动和所有原断言相同；仅 `socketNoDelayTrial` 为 off/on，运行编号、独立应用身份和随机空闲端口自然不同，结果逐项记录。

## 入口

在 RConnect 目录，以普通 Python（禁止 -O）运行：

```text
python -B -X utf8 experimental/recovery-ordinary-socket-native/prepare_host.py --prepare
python -B -X utf8 experimental/recovery-ordinary-socket-native/run_native.py --mode off --check
python -B -X utf8 experimental/recovery-ordinary-socket-native/run_native.py --mode off --output build/m52/recovery-ordinary-socket-off-native-01
python -B -X utf8 experimental/recovery-ordinary-socket-native/run_native.py --mode on --check
python -B -X utf8 experimental/recovery-ordinary-socket-native/run_native.py --mode on --output build/m52/recovery-ordinary-socket-on-native-01
```

宿主准备只读取准确 mask-host02（6616B1…289B）及其原准入，复制到全新 `build/m52/recovery-ordinary-socket-host-01`，只将 **FWS 未压缩头 offset3 的 41 改为 51**，其余字节、长度完全相等。单独 receipt 的 `header_proof_passed` 仅表示这个字节事实；`runtime_compatibility_verified=false`，不是借用旧宿主资格证明完整游戏在 SWF51 可运行。旧回执仍按原真实路径验证。

私有 runner 复用原 ACK wrapper 的路径与配置保护，在同一个生成配置写入点额外添加 `socketNoDelayTrial`，保留 `wallAckTiming=1`。模式由新 wrapper 自己消费 `--socket-mode`，原 runner 的参数解析、登记及 main 保持原样。实际私有 `coop.xml` 唯一文字变化是命名空间 `application/30.0` → `application/51.0`，`initialWindow/content=pfe.swf`；事后以原完整模板和 Windows 换行逐字节核验。安装版 application.xml 与配置完全不写。

## 证据与失败规则

先真实执行原 ACK preflight（原产品、原宿主、历史 binding 均不改），再独立校验新产品构建、覆盖源码及新宿主头证明。原四轮驱动不重编；原五锚点适配只额外指向本地 wrapper 并传 mode。既有 600 秒、6 GiB 启动/512 MiB 运行、独占 AIR、私有桌面、22 安装文件、所有错误检查、资源登记和自有清理完整保留。原 expected config 只精确增加两项；其余实际配置必须完整相等。

原 ACK collect 收到真实新候选和新宿主 SHA；原精确像素分析与八份计时 JSON 保持。结果仍为 `ack-timing-result.json`，可供原 analyze.py 使用；原框架 `result.json` 和像素结果不改。`functional_pass` 单独记录原业务结果。`diagnostic_samples_ready` 额外要求每端四轮的 socketNoDelayTrial：严格正确 off/on、布尔预期值、恰一个真实连接、正确 accept/connect 方向、实际 Socket 身份/连接/set/read 全成功、设置和每轮检查读回一致、跨轮连接身份一致、两端回环地址与端口成对。缺失、错误、额外连接、溢出、fault、abort 或原日志 OUTPUT FAILED 均不取得诊断资格。

同一文件记录真实模式、runID、端口、描述符差异证明、两个 SWF 指纹。只比较满足全部原功能与诊断规则的两组。计时分析独立沿用原 analyze.py；不把开启选项、静态头变化或单组成功宣称为性能改善或全面游玩资格。

## 未测边界

完整 SWF51、namespace51 与既有 SWF38 子层的实际兼容性需根本轮运行证明；现有 API 小测试不能替代。此入口不验证真实网络、多机、重连、多人或其它地图。头版本变化不代表重新编译 ABC 或升级其它加载资产。
