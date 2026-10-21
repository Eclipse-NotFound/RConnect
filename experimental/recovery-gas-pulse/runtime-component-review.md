# 实际组件结果与整合边界

2026-10-22，根会话串行共享登记执行。安装22项均未变；真实Part和游戏资源由明确替身提供，以下不属于原生游戏或性能资格。

- control-01：实际63项，35失败。candidate-01：编译失败，DisplayObject静态类型不公开constructor，没有启动AIR。
- 修正为Object(v).constructor；共用测试原短火花断言把同一显示时刻的两次调用误作两帧，改用明确下一显示时刻。control-02实际63项/34失败；candidate-02实际63项/1失败。
- 唯一剩余失败来自夹具移除：只清firstObj而未清原12个Part.in_chain。原生Location.remObj会清in_chain；修正夹具实际移除，原“稍后新粒子唯一且时间正确”的断言不变。
- control-03实际63项/34失败；candidate-03实际63项/0失败。同一63标签与完整组件输入经整合脚本复核。真实AMF编码的本组件包最大5327字节；只是这些构造载荷，不代表原生带宽。
- 组件回执：build/m52/recovery-gas-pulse-component-03/receipt.json，SHA256 `676d7fb9b2206621fcd41b97588b84d91dc2c5f52f9ea21a0aa7faec4b974ed5`。原始结果SHA256 `b4498a42eca3c564d71909535434fa5ccea49a43b57b94691106abb7b3ae0699`。

四类准确合入experimental/recovery-integrated，源版本推进0.2.24-recovery12，尚未编译和原生验证。未合入first-raster独立方案。原生单/双颗双向四轮由recovery-gas-native-tests准备；来源离房/末包缺失仍沿既有15秒边界，不能凭组件关闭这项限制。安装保持回退574D。
