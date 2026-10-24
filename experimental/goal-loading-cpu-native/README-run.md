# 首次普通地图加载的调用栈诊断

复用已经实测通过的原生 UI 三程驱动，只增加首次 `t_exit=20` 的实际 RENDER 末尾至首个 `t_exit=19` RENDER 开头的采样。原 35 项旅行检查、双方各 11 项显示检查及采样外的旅行操作不变；宿主、RConnect 产品也不改。

`build.py` 负责唯一驱动编译，说明见 README-build.md。`run.py --check` 必须核到真实五份源码、成功编译回执、原生 UI 宿主准入及当前 22 项安装。缺产物时返回 not-ready，不创建运行目录。实际运行用：

```text
python -B -X utf8 experimental/goal-loading-cpu-native/run.py --output build/m52/goal-loading-cpu-native-01
```

运行完全沿用原生 UI 的共享登记、独占 AIR、6 GiB 启动余量、512 MiB 运行保护、600 秒限时、私有桌面、私有 CS 普通房设置、telemetry 复制及回收。启动前检查已知运行二进制没有其他显式采样 API，唯一新驱动包含采样器；这不是对任意外部探针或混淆代码的证明。

采样先暂停，下一次 ENTER_FRAME 整理并清空原始缓冲；只保留有界栈汇总。采样整理影响下一帧，因此这次三个行程的时间均不授净性能资格。完整结果 `observer/<role>/initial-loading-cpu.json` 在私有 AppData 清理前复制出来。原观察器的 JSON、终态截图及其断言照常保留。

`result.json` 的 `cpu_complete` 单独区分是否得到完整调用栈证据。零样本、边界错误、所有权或清理失败会拒绝诊断；截断会明确保留 `cpu_complete=false`，不能拿部分样本百分比当完整耗时分布。原生采样缓冲没有本探针能证明的内存上限，进程仍受原运行内存保护。

本入口没有安装动作，也不影响另一个正在等待精确文本记录授权的分房探针。
