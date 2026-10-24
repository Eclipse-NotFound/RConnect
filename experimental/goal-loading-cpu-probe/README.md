# 普通首次加载：单窗 CPU 取证源码

这里只准备源码，未编译或启动 AIR。用途是定位首次 exit20→19 长段；不授性能资格，不改原地图生成、随机源、旅行流程或产品。

准确基底为已编译 `build/m52/goal-native-loading-probe-driver-01`（prepared 562BB57F、compile 02F8EFA0、driver 877B05DA）。原 `A22RoomMetrics.as` 和 `NativeLoadingProbe.as` 逐字保留；`RoomTravelTimingTestDoc.as` 仅新增字段、在原显示观察器创建后创建 CPU 对象、原 begin 后 begin、原 finish 后 finish 四个接点。原三程、35 个业务检查、11 个显示检查、DONE、截图、时长及种子都不删改。

新增 `LoadingCpuProbe` 只认 round0 的 random_mane。最终 RENDER 中，原显示观察器优先级 -2147483000，新开窗回调为 -2147483001；首次实际 t_exit20 才启动。另一个高优先级 RENDER 回调在第一次退出20时先暂停采样，不先枚举、拼字符串或生成 JSON。只有实际到19、同一 World/Game、采样及清理均正常才算完整；Location/Land 正常替换不要求身份相同。重复20不重启，跳过19、世界替换、早退或没有20均不冒充完成。

暂停后的原始缓冲只保留到下一次 ENTER_FRAME，届时枚举、stop/clear/release，避免将大量原始记录留到三程结束。只有有界文字聚合保留至原 fixture finish，写本人私有 `Local Store/initial-loading-cpu.json`（单个完整 JSON 对象）。成功关闭文件后输出一条 `LOADING CPU PROBE RESULT <JSON>` 小型资格/文件索引摘要，再输出 `LOADING CPU PROBE DONE <role>`；完整堆栈不塞入普通日志。输出失败写 `LOADING CPU PROBE OUTPUT FAILED`，不能因原 DONE 存在视为采样通过。原 NativeLoadingProbe 的终态 JSON/PNG 仍按原顺序在后续 RENDER 生成。

真正采样 API 适配器使用 v3 的 `FlashPaintTailSampler.as` 原字节 F0706D7F。collector 直接沿用 v3 `PaintTailSampler.collect` 原文：32768 条样本、1024 个栈、64 层、单帧文字512字符、总栈文字262144字符；分配/删除只计数，不保留对象。任何 sample/stack/depth/text 截断或枚举总数不符均无完整 CPU 资格；零 CPU 样本不能证明 GPU、网络或休眠耗时。`collectMs` 包含 cleanup，`cleanupMs` 是其子区间，不能相加。

`sampleInternalAllocs(false)` 改变本次隔离进程采样设置，不关闭所有 AS 对象记录。上述预算限制的是后处理，不保证原生采样缓冲内存有界。采样会扰动执行，下一次整理帧和后两程只保留功能检查，不能当净性能数据；不从加载耗时机械扣除整理耗时。

唯一采样输入是后续运行入口的强制合同：只加载本目录编译出的这一诊断 driver，不得同时加载旧跳跃、tail 或其他 profiler；正常模组也不能启用另一 flash.sampler。驱动传入的 true 是入口确认声明，不是运行中检测结果，适配器静态令牌仅防本适配器内部竞争。构造器另要求独立 `pfe-modsettings-rconnect-coop-` AppID；普通玩家实例不会取得许可。当前源码准备不等于已完成这一运行准入。

`prepare.py` 首次运行只生成本目录的 AS 副本、差分和文本清单；`--check` / `verify()` 只读核全部来源、四处反向还原、两旧类和适配器字节完全相等、collector 原文及源指纹。入口仍 `tests/RoomTravelTimingTestDoc.as`，继续复用现有 ABI 和有界编译/普通三程运行器；此处不新建编译器或运行框架。
