# 墙痕 Base64 输出：单文件隔离候选

准确底为 `build/m52/recovery-18`，正式回执 SHA `11b795d0…8fe4d3`。仅覆盖 `rconnect/net/WallCellCodec.as`；没有修改 WallImpactVisuals、解码、缓存、发送频率、格式、容量或任何安装文件。

原 pack 在每 3 个压缩字节上生成 4 个小字符串，拼成字符串后存 Array，最后 join。候选使用一个私有 64 项 ASCII 表，每组将 4 个 ASCII 字节合成 uint，写入预分配 ByteArray，最后一次 readUTFBytes。仍保留 `!W1:`、相同字母表及 `=` 填充。索引验证、排序、颜色 Number 转换、数值界限、序列化和 zlib 调用全部是原方法字节；完整 unpack 没改。输出缓冲受原 10,000 压缩字节上限限制，最大 13,336 字节，没有共享可变编码缓冲。

`a6a7e27789` 主侧真实 CPU 栈确认 pack 包含 499 个样本，其中 186 个涉及下方垃圾回收（直接 pack 的 updates/snapshot 各 126/25，join 下另有 31/4）。这些是包含关系，不是新增调用次数，也不能推算会节省相同比例 CPU。候选只针对临时分配，实际净收益尚未知。

组件保留两份完整准确18 WallImpactVisuals，只改类名、增加私有访问包装，并将 Before 绑定完整原 WallCellCodec。其余实际 RoomCodec、WallSurfaceBridge、NativeWallColor 直接复制准确18；GameBridge.probe、Log、Bullet 接触标记是明确替身。没有加载游戏或生成真实子弹。

- 复用原 82 份自然墙痕、1,276 次记录顺序及 49 项完整墙痕语义检查：真实 BitmapData、旧格式读取、缓存、预测/ACK、旧版本、整批拒绝、破墙、重访、70 格轮转、64 格和 48k 限额。它们现在比较两份准确18完整类，不能继承以前的通过结果。
- 新增 14 项：82 份字符串/完整外壳逐字符一致、反向解码、乱序属性、128 份确定性空/稀疏/满格数据、原生压缩长度三种余数、每种 padding、全部 256 输入字节值、精确长度/ASCII、索引/颜色错误类型及信息、旧 Number 转换和输入不变。
- **63 项 AS 待根会话执行**。只有纯 Python 14 项静态/独立位布局检查通过，其中 83,552 个分组探针和自然数据验证不替代 AIR 压缩、编译或速度实测。
- 微基准显式运行 **ABBA 六组、24 块、每块 82×3 次**，相同自然数据，强制清除各 cell.wire。计时包含完整生产 packed 的校验、排序、原生压缩、Base64 和外壳；输入构造、文件和缓存重置在计时外。两个路径均等预热，无强制 GC，不设“新一定更快”的断言。各块 ms/调用数/字符数/校验和全部保留，附相同全路径冷解码数据。数据来自历史 decode miss，不能当本轮密集分布或实际每秒发送量。

从 `mods/RConnect`，根会话使用现有登记组件入口（输出目录必须新建）：

```text
python -B -X utf8 experimental/recovery-wall-base64/run_component.py --source experimental/recovery-wall-base64/components --entry WallBase64Checks.as --expected 63 --output build/m52/recovery-wall-base64-component-01
```

薄适配器仅将自然 JSON 纳入原 runner 的冻结/回查，原内存门槛、执行超时、22 项安装指纹不变。`prepare.py` 和 `check_offline.py` 已执行，仅生成本目录源码与静态回执；未启动 JVM/AIR。若完整路径耗时仍属噪声或退化，就搁置，不扩大为协议或缓存改造。
