# 有界加载计数：已编译，实际双人计数待内存恢复

2026-10-24。安装未改，当前宿主 ABE2 / RV 0DBE / RC DF0F。

- 产品 01 编译失败（bitmapSignature 外层 try/finally 缺编译器要求的显式返回），原 prepared/compile/log 保留。只在 finally 后补不可达空字符串返回，剥离诊断后原方法正文逐字相同。
- 产品 02 编译成功：`build/m52/recovery-room-loading-counter-product-02`，SWF `1f268236eae5b363fe057c9b01a3b6d7821e9be46443cddac4deb08297ca72ab`；prepared `5e8f4913429ed7a92a99a9310dccc2760ca84e920a8fa76fbb3c2dedcfe16041`。
- 外部驱动 01 编译成功：`build/m52/recovery-room-loading-counter-driver-01`，SWF `77d5eca08be0d7dc35acd6b5b7591c75e179ea4e948d667af5e82dcf6dcf81a5`；prepared `08c81be098ced5daf93942756336104f45257f50bee4e9a12cecbf53fa2db66c`。原 Timing/Scene 断言源码不变。
- `recovery-room-loading-counter-native-01` / `19e66eb57c` 在 AIR 启动前因可提交余量 4,036,927,488 字节（约 3.76 GiB）被原 6 GiB 门槛拒绝。无真实计数结果，不给功能/性能资格。
- 随后在 solo 结束后记录 30 秒七点：3.99/4.01/4.01/3.99/4.00/4.00/4.03 GiB，见上述 native-01/memory-followup.json。不降低门槛、不停止其他程序。

下一次仍用已编产品 02 与驱动 01，以新 native-02 目录运行。AIR 需要在唯一应用的私有 AppData 中写测试配置；已授权测试范围内使用 require_escalated，不改用户真实存档。原登记/私有后台桌面/6 GiB 起步/512 MiB 运行/600 秒及全部断言保持。

仅得到编译资格。三个窗口完整计数通过以后，才根据实际耗时选择优化；不凭重复循环的存在认定主因，不部署诊断版本。
