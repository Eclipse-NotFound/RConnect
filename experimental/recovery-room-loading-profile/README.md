# 加入侧首程加载 CPU 采样

仅外部测试驱动；产品和游戏宿主不改。准确复用 `recovery-room-scene-driver-02` 的 Scene/Timing 两份源、声明库与 Harness，只扩展已有 `A22RoomMetrics`。原三程旅行、出生、原生输入恢复、场景偏好和错误检查均保留。

仅隔离 join 实例、`curLandId` 与实际 Land 都为 `random_mane` 的第一次真实 `room/grant` 启动。现有 MESSAGE 的 +200000/-200000 监听夹住 grant 处理（已解码，不包含 Socket/AMF 解码）；随后两个 Stage ENTER_FRAME(+1000000) 到 RENDER(-1000000) 窗口各独立采样。各窗口仅请求一次 `invalidate()` 以取得 RENDER 通知，不合成输入或推进世界。RENDER 是通知边界，不等于 GPU 已显示。

沿用已成功的 `flash.sampler` 顺序：clear、internalAllocs(false)、start、pause、count/枚举、stop/clear。只保存堆栈文字、计数和分配类型/字节，不保留被采样对象。每窗 32768 样本、2048 个不同栈/分配类型、64 层栈，任何截断均明确无资格。10 秒 Timer 是协作超时，不能中断已经阻塞的原生同步方法；枚举仍有固定上限。三窗之外不采样。

结果在原 fixture finish 时一次写入独立私有 `Local Store/room-loading-profile.json`，不把堆栈写入 RConnect 日志。记录真实 getTimer/UTC 起止、start 返回、ENTER 尾部、采样总数/实际枚举数、CPU/删除/分配分类、采集耗时和故障。`complete` 要求三窗均完整、未截断、无故障且各有正 CPU 样本；零样本不归因于 GPU。写入失败将缺文件，外层必须拒绝采样资格。原异常不被诊断捕获；发生原 handler 抛错且缺 after 时，窗口由超时或 fixture finish 关闭为 incomplete。

采样器是本隔离进程共享设施；仅用于当前独占测试，不同时运行另一采样器。该观测本身会增加开销，原流程通过与 CPU 证据完整分别判断，始终 `performanceQualified:false`，不能把本轮总耗时直接当性能成绩。

从 RConnect 目录先运行 `python -B -X utf8 experimental/recovery-room-loading-profile/prepare.py --check`。根独占编译：`.../prepare.py --output build/m52/recovery-room-loading-profile-driver-01 --build`。沿用现有 game 登记、1 GiB 编译启动门槛、512 MiB 运行保护、隐藏 Java 和 finally 清理。当前尚未编译、未启动 AIR。

构建后的 `verify(Path)` 供薄运行入口复用；它核对当前准确 RV 0DBE 的 22 项安装和原 scene02 历史资格。运行仍需原 scene preconnection preference launcher、真实 roomfix3 与全部原扫描，不可调用旧 verifier 冒称它接受新 Metrics。结束后由根从唯一 run 对应的私有 AppData 复制 JSON，并核其 appId、首次 grant、三窗次序及完整性。

运行入口为 `run.py --drivers build/m52/recovery-room-loading-profile-driver-01 --output build/m52/recovery-room-loading-profile-dual-01`，可先加 `--check`。它只在新导入的原 scene-v3 模块提供显式新 driver verifier，仍复用原 native-v3、私有场景偏好 launcher 和共享 runner，固定 roomfix3/80CF/RV0DBE。完整来源与新产物分别锁定；旧 `result.json` 和 `scene-result.json` 原样保留，另写 `profile-result.json`，功能结果与三窗 CPU 资格分开。唯一 join 存储路径两边都 resolve 后严格相等，结束后复制为 `join-room-loading-profile.json`，不写用户实例。
