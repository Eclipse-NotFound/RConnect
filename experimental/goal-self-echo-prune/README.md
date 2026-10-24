# 单一加入端不接收自己的快照

生产基底是准确 `recovery-room-production-05` 的 `78C052AE…4699`。只有 `Session.as` 和版本 `0.2.24-selfecho1` 两份覆盖源，其余 79 类保持基底字节。没有合入 Motion v2、探索 no-op 或旧传输候选的调度改动。

`broadcastWorldState()` 仍在原来的每个时机完整采集并发送。仅当 peer 表和 client 表都只有一项、唯一连接开放、已分配正 ID、peer 的连接对象和 ID 都精确对应时，待发送名单条目改为 `{id,name,snap:null}`。原 `peer.snap` 不修改，宿主条目、名单顺序、敌人、掉落、墙痕、房间戳及所有调用顺序保留。未认证、关闭、多连接、残留或身份不匹配时沿原路径。

消费依据：原 `applyWorldState()` 在记录 `seen[id]` 后，对 `id==myId` 立即 `continue`；不读取本人 snap，也不把本人放进 remotes。握手通过同一 TCP 流先交付 WELCOME，再交付 WORLDSTATE。念力、友伤、地雷、安保、暂停监听器只接各自类型消息；队友地图和 HUD 使用原 peers/remotes。这里不删任何消息，不把同 sampleTime 的整包视为重复，不改变原广播或插值时钟。

组件复制真实旧/新 `broadcastWorldState()` 和原 `applyWorldState()` 的完整方法体，仅把 private 改为 public；`prepare.py --check` 逐字核对抽取来源。组件的 HostServer、TcpLink、BinaryMessageCodec、Protocol、NetMessageEvent、Log 均是 78C 原字节。CaptureLink 只替代 socket 末端，实际执行原广播类和两种编解码。GameBridge/RoomSync 边界只返回固定数据并记录调用，**不是真实游戏、真实 socket、握手执行或性能测量**。

预期 100 项检查：16 种边界中的采集/确认调用、发送次数、存储快照引用和内容不变、编解码后的完整包等价、本人消费与旧成员清理等价。覆盖正常单连接、死亡、分房、新 ID、null 快照、未分配/零 ID、无 peer、无 client、多 client、多 peer、外来链接、ID 不符、关闭、未监听及无 server；四个有实际载荷的裁剪场景还检查编码字节减少。不新增性能阈值，也没有声明 FPS 收益。

结果文件遵循共享运行器合同：`assertions:[{label:String,passed:Boolean}]`、`failed:int`、`passed:Boolean`；运行器独立核对失败数、总状态和 `--expected 100`。本次接口修正只改变报告字段名，不改变任一判定或计数。

根会话已实际完成 `build/m52/goal-self-echo-prune-component-01`：100/100 通过、退出码 0，组件 SHA `A475776527ABA4CC0AA9EE2245FECAA25C045C538C778E9C96C25F7BAA917719`，源码和安装未变。这只证明组件范围，不能当作原生性能结果。

此次只重开构建配方与元数据。原清单 `1FDD8C00…F2FE4` 按原字节保存在 `provenance/source-manifest-before-build.json`；新清单核对原 candidate_source/component_source 完全相同，所有生产和组件 AS 未修改。100 项实际回执、intent、原始结果与组件字节只读引用，未改写旧证据。

源码核验与根会话后续最短产品编译入口（本次子代理未启动编译或 AIR）：

```text
python -B -X utf8 experimental/goal-self-echo-prune/prepare.py --check
python -B -X utf8 experimental/goal-self-echo-prune/build.py build/m52/goal-self-echo-prune-product-01
```

`build.py` 按现有探索候选模式接入未改动的 `recovery-room-production-v5/build.py`，沿用共享登记、两条 Java 指令、1 GiB 启动余量、运行中内存保护及自有进程回收。输入是 production-05 的 81 类及原 tools，加这两类覆盖；工具仍使用该有界构建器指定的 Java 和 Flex SDK。新输出必须不存在且位于 `build/m52`。`build.verify(output)` 必须看到真实成功的两条编译回执、准确源码/工具/产物哈希及安装前后不变，不能把准备目录当成产品。

构建启动时读取当时真实的 22 项安装指纹并写入新回执；source-manifest 的历史基底及组件回执不能代替当前安装环境。当前 RV 是 638E，配方没有复制旧 BF4A 环境。**此处没有原生运行器，也不赋予历史原生测试新候选资格。** 后续由根会话将实际编译产物与当前 22 项环境绑定，再复用 drivers-02 的 native-jump 和 fast-held，保留原 6/6、43/42 和 160 ms 门槛。

冻结交付后仅报告审查意见；未经根会话明确重开，不再编辑此目录。
