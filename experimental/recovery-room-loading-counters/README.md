# 加载三个短窗函数计时（仅隔离诊断）

基线为准确 roomfix4 / `34A17DE6…22B703`，诊断版本 `0.2.24-roomtime1`。只给 GameBridge 四个显示/观察回调和 MirrorMasks 五个方法增加外层 try/finally 计时，并增加一个静态小计数器；原方法正文可反向恢复逐文本一致。保留所有原 return、throw、catch、finally 和调用顺序。新增代码不得合并正式版。

只允许独立加入侧测试 AppID 启用三个顺序窗口：首次 random_mane grant 处理，以及其后两个 Stage ENTER_FRAME 到 RENDER。maskReferences 仅计最外层调用耗时，另数递归节点。没有采样器、全帧日志、网络内容改动、频率改动或世界快照。

外部驱动完整复用 scene-driver02 的 Scene/Timing 源及所有原断言，仅替换 Metrics。ENTER 标记优先级为 1000000、1、-1、-99、-101、-8999、-9001、-9999、-10001、-1000000；RENDER 为 1000000、-9999、-10001、-1000000。每窗最多 16 个标记；标记超过上限或三个窗缺失都拒绝诊断资格。10 秒 Timer 仅是协作式退出，不能打断同步阻塞函数。

首次 grant 至第二 RENDER 另按消息 type 累计次数、总时长和最大时长，记录 grant 返回至首 ENTER 的空档，单列该空档内消息处理。使用原有 +200000/-200000 消息监听时间；不包含 TcpLink 解帧及外层 AMF/JSON 解码，但包含处理函数内 RoomCodec 解码。最多 32 种消息，无逐包文件写入。

`totalMs` 包含子调用，不能把各方法相加。Stage 两标记间包括该区间的全部监听器，不能当作 RConnect 独占。计数、消息聚合、标记本身有开销；本轮只做归因，始终 `performanceQualified:false`，不是性能对照。RENDER 回调结束也不等于 GPU 呈现完成。

使用 `prepare.py --check` 只读检查。准备/编译均用新目录，不覆盖旧结果：

```text
prepare.py --target product --output build/m52/recovery-room-loading-counter-product-01 --build
prepare.py --target driver --output build/m52/recovery-room-loading-counter-driver-01 --build
run.py --product build/m52/recovery-room-loading-counter-product-01 --drivers build/m52/recovery-room-loading-counter-driver-01 --check
run.py --product build/m52/recovery-room-loading-counter-product-01 --drivers build/m52/recovery-room-loading-counter-driver-01 --output build/m52/recovery-room-loading-counter-native-01
```

不加 `--build` 时只冻结输入。产品复制完整 roomfix4 src/tools，只替换两类、增加 helper 和版本；原编译器用与 room-production-v4 相同的登记/隐藏子进程/1 GiB 起步/512 MiB 运行保护和 finally 回收。运行复用原 native-v4 全部功能、错误、6 GiB/512 MiB 门槛及共享登记，保留原 Scene 私有偏好启动器。唯一源适配是产品名字与版本，另明确绑定本诊断产物和新驱动验证器；适配后的源及说明另存，旧入口不改。

准确运行环境由 `current_host_verifier.py` 核 22 文件：正式 RC 仍 aura1/DF0F，当前宿主 ABE2、RV 0DBE；历史 scene02 的 80CF/6DBA 与 roomfix4 编译的 80CF/0DBE 仍分别保留。不会把安装 RC 要求成未部署的 roomfix4。

加入侧私有 `room-loading-counters.json` 在夹具结束时一次落盘，复制到本次输出的 `join-room-loading-counters.json`。新 `counters-result.json` 单独报告原功能结果与诊断完整性；原 result 不改判，缺窗、fault、路径/身份不符均保留失败。此目录仅完成源码准备和静态核查，实际编译/运行由主代理统一执行。

产品 01 的原编译失败保留：编译器不能推导 bitmapSignature 的外层 try/finally 必然返回（1170）。新产品 02 仅在 finally 后增加不可达的空字符串返回；原 try 内的返回和异常行为不变，源码恢复检查精确剥离这一个哨兵。不得改写 01 的输入或结果。
