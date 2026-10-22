# 同一 Stage 的加载尾段定位

2026-10-23；诊断，不授予生产或性能资格。

- 实际 `build/cooperation/8f83135df8`，外层 `build/m52/recovery-paint-enter-tail-solo-01`。驱动 SHA256 `5b54c1238a0913402ef191e37f10f1bdc2e211571fecf5c012013d89d745cc2b`。
- 原三段场景 35/0，elapsed 9269/1851/4875 ms，control 9847/2023/5526 ms。原断言、其它三个观察源、18项编译输出及22项安装独立核对通过。自有实例和副本清理；安装 RConnect 仍574D。
- 准确输入 early2/D356、host03/29D3、Sand003、隔离 RV7852。未换成正式 RV83；没有同轮外部CPU观察。

|目标窗口|开始到 Stage -1|Stage -1到最低ENTER|最低ENTER到首次RENDER|RENDER标记跨度|末RENDER到下一ENTER|总尾段|
|---|---:|---:|---:|---:|---:|---:|
|首次进入|162|2656|2|2|16|2838|
|缓存重访|97|2423|1|4|17|2542|

单位毫秒。墙钟相应为161/2657/1/2/17及98/2423/1/3/18；读钟有1 ms差，顺序和总和一致。两个ENTER标记各只有一次，与四个RENDER标记同属startStage104/166，stopStage105/167。无缺失、fault、overflow或incomplete；基地窗口未触发，明确空值。Flash样本仍零。

93.6%和95.3%的尾段落在同一 Stage 的负优先级ENTER回调区间。此证据不能指定某一模组，更不能代表整个显示树或所有脚本边界。准确D356离线仍执行GameBridge.onMirrorFrame，但扫描成本尚未计量；其它模组同区间回调需一起核查。下一项采用同一窗口内有限优先级标记一次缩小区间，不改绘图、频率、画面或原生断言。

可复核分析：本目录 `analyze.py`；输出 `build/m52/recovery-paint-enter-tail-solo-01/enter-alignment.json`。两名只读子代理独立检查运行输入/时序和准确生产源。
