# 在现有联机更新开始时读取已到数据

这是隔离候选，不是部署版本。基础为冻结的 `recovery-ordinary-wall-rx-timing/src`，准确修改仅 Session 与 TcpLink，Config 和 WallImpactVisuals 原字节保留。根在作者工具恢复后停留于 pending_init 时终止其写入接续，完成最终冻结；实际 SHA 见 source-manifest.json，完整差异见 source.diff。没有把未完成的独立审查写成通过。

Session 原 50ms onTick 的第一项读取当前连接，之后仍按原函数重新读取会话与房间状态。宿主使用客户端数组快照，每次处理前核会话模式、服务器身份及成员资格；加入侧 JOINING 阶段也处理欢迎/交接消息。未增加 Timer 或改发送频率。

Socket 通知和主动读取共用一个解析器。仅当前连接有可读数据时读取一次；同一连接重入直接返回，finally 释放标记。长度头、JSON/AMF 选择、坏帧拒绝、半包保留和帧顺序沿原逻辑。处理器关闭或更换连接后停止处理旧缓冲；新连接使用独立缓冲。业务异常仍交给原 AIR 异常渠道，没有吞掉。配置、线协议和发送方法不变。

诊断沿用原有界行，只增加 rxEntryReason（socket-data/tick-poll）与每轮 rxPollCalls、rxPollReadCalls、rxPollReadBytes。实际非空读取才算覆盖；空轮询不能证明提前处理，组件中主动阻断通知也不能证明游戏本来存在晚通知。

## 真实 Socket 组件检查

使用原 run_recovery_component.py；准确 TcpLink 与原 Protocol/BinaryMessageCodec/NetMessageEvent/Log 原样复制，逐文件来源在各 checks 目录 sources.json。真实本机 Socket，优先级监听器仅在测试自身连接上暂阻正常通知，以验证主动读取路径。正常通知另有独立成功检查。

- checks-01：驱动在服务端接受后未等待客户端完成连接，首项失败；保留。
- checks-02：增加客户端完成门控，前面传输检查走完；故意处理器异常经 AIR 报告，驱动未接其全局渠道，超时；保留。
- checks-03：驱动仍过于限制 AIR 异常载体类型，异常观察失败；保留。
- checks-04：仅在预设阶段精确识别故意异常文字，21项全部通过，SWF `487aa3147f578a271a0afbc889c84db4c1ace55f8fb6908bdbffd0a3562df395`。覆盖空读、分段长度头、分段正文、多帧顺序、重入、迟到通知、原 JSON 协商、AMF 与坏 JSON、正常事件、处理器闭链、未协商二进制拒绝、业务异常渠道、自有资源清理。产品四次均未修改。

这只给传输正确性证据；未加载游戏，不授予性能、房间或全玩法资格。所有组件进程由原工具回收，安装文件保持。

## 实机候选

`build/m52/recovery-ordinary-receive-pump-01/RConnectMod.swf`，版本 `0.2.24-receivepump1`，SHA `ab61c7aaa70b6b6856f2bc2eddae969ae993c8d1c94c80e57f82afcded6b4114`。SWF38，使用原6616宿主41/namespace30。

## 真实游戏结论：不采用

2026-10-23，`recovery-ordinary-receive-pump-native-01` / `05fe881aee` 原四轮框架双侧各34/0，四轮最终像素53/50/1147/971且错漏多余均0；ACK与接收分段资格通过。主侧543、加入侧556次主动检查，非空读取次数、字节数及相关主动接收事件全部为0。主动读取覆盖失败，原总体passed=false保留。这是实际没有触发该路径，不是此前rx方向检查错误。

`recovery-ordinary-receive-pump-first-pair.json` 对照原36C5/a3ded11cae，36个画面阶段完整。主侧LMG延迟98→144ms，加入103→83ms；主侧等离子八阶段中位55→130.5ms、最大147→181ms；加入中位132→146ms、最大248→313ms。加入等离子ACK往返中位145→158.5ms，最大272→448ms。两次按顺序运行、各自随机碰撞图案、含采样开销，不能据此作净性能因果判断；也不能把零主动读取解释为有效优化。没有一致收益，本方向停止，代码不并入生产。

两自有游戏PID42920/29508均已回收，运行副本已清理，22项安装与冻结输入保持。组件成功只证明人为延迟通知下的传输正确性；本次游戏没有证明提前接收或解决卡顿。正式仍EB365/BEFC。
