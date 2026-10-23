# 普通墙传输计时：隔离诊断覆盖

基底为 `build/m52/recovery-ordinary-wall-sv-production-01/src`（实际产品 C6A3B113…3496D）。仅四个既有类的副本：Config、Session、TcpLink、WallImpactVisuals；原目录、普通墙四轮驱动及宿主均不改。候选由主会话另构建为 `0.2.24-wallacktime1`，此目录不执行编译或游戏。

目的仅为区分发送节奏、ACK 往返及确认后的等待。记录成功 socket.flush、解码后 dispatch 前的墙报告/ACK/wallPaint，Session ACK 调用区间，以及 WIV 真正释放 pending 的时刻。保留所有原消息内容、发送频率、返回类型、确认规则与异常行为，不据此宣布性能改善。元数据取证先记时再复制，并记录单次/累计/最大耗时；该统计包含 ACK 释放时钟采集，不包含窗口标记管理和结束后落盘。

`wallAckTiming` 默认 `0`。测试私有配置须显式设为字符串 `1`；只接受本轮原运行器生成的 `pfe-modsettings-rconnect-coop-(host|join)-十位十六进制串` applicationID，且角色与 autoRole 相同。正常 `pfe` 实例不能启用。没有读像素、调用快照/报告收集器或额外房间遍历。

复用原 `large-wall-test` 标记：host 发出 go / join 收到 go 开始；双方分别发送/收到 sampled；host 发出 analyze / join 收到 analyze 才结束。正常输出必须严格 round 0–3 递增且已见双方 sampled。每轮缓冲最多 256 条，溢出显式计数、诊断不合格。每端一次写 `applicationStorageDirectory/wall-ack-timing/round-N.json`；断开或停止时保全未完成窗口，标记 `complete=false`。逐包不写日志；输出和摘要仅在采样结束后或失败收尾发生。

事件只复制最多前三格元数据和总格数。超过三格的累计 wallPaint 明确 `metadataPrefixOnly=true`，不把前缀当完整图案。report/ACK 应为最多三格。WIV 在真正 pending=null 后只取 releaseAt/releaseWall；原 ingest 与 compose 正常返回后才写 pending-released，另含 completedAt/completedWall 和此时 queuedFirst，避免把 ingest 可能删除的旧队列误认作 ACK 处理完仍有积压。queuedFirst 只检查队列遇到的首键；valid 仅指 q/c 对象存在，eligible 仅复现普通队列原本的 `c != null && !c.needsNative && q.sv == c.sv` 条件，不能代替包解码资格。首键不合格不等于后续没有可发送格；found=false 才表示当时空队列。

`getTimer` 是同一进程中的主时钟，Date.time 只用于跨进程辅助对齐；paint 使用原 msg.tick，报告与 ACK 分别使用 wall.seq / wallReceipt.seq，加房间 key/epoch/term 配对。诊断记录自身异常与耗时；自身错误不进入原 transport 失败分支，也不吞原生 ACK 处理异常。

`probeTotalMs` 在本稿已计入 ReleaseStart 的内部取时路径，但不覆盖 marker 管理、结束后输出和最外层调用进入开销，不能当作全部诊断开销。

准入仍需主会话核对四端轮次文件完整、无 overflow/fault、原四轮逐 uint 像素与原错误检查通过。异常/截断时保留证据，不放宽旧断言、不改测试门槛。此准备不构成运行或性能通过。
