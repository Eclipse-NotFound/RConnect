# roomfix4 源码候选

本目录只完成源码准备，未编译、测试或部署。以准确 roomfix3（`build/m52/recovery-room-production-03`，43277B92…04011）为上一版；构建基座仍为正式 aura1 DF0F，沿用 v3 的 11 类 overlay。

相对 roomfix3 只有两处变化：

- `rconnect/net/RoomCodec.as`：采用 clean 覆盖 BD98187F…62570，移除 pack/unpack 全部计时与逐次日志。编解码算法、紧凑表和显式长度限制不改；完整边界说明见 `../recovery-room-production-clean/README.md`。
- `RConnectMod.as`：版本字符串改为 `0.2.24-roomfix4`。其余九类逐字节保持，特别是 RoomSync 和 RoomEntryView 不变。

`incremental.diff` 是相对 roomfix3 的全部差异；`source.diff` 是相对 aura1 的完整 11 类差异。`source-manifest.json` 记录准确来源、全部覆盖指纹和两处增量；SHA `ea42de4a3b7093bf83bc18d40fd9fdf80e898bab52bb9cc6ad1870c5d80e15eb`。

`prepare.py` 为只写新目录的准备 recipe；`build.py` 与 v3 字节完全相同（1889514C…142B9），保留其原安装和来源核验、共享登记、编译内存保护。由根会话调用构建，本文未执行该动作：

```text
experimental/recovery-room-production-v4/build.py build/m52/recovery-room-production-04
```

计划 211 项 codec 组件位于 `../recovery-room-production-clean/components/CodecCleanChecks.as`，可复用现成受监控入口 `../recovery-ordinary-wall-sv/component.py`，参数与通用组件入口相同。该入口 SHA C048C04D…499F57，编译和 AIR 均检查启动 1 GiB / 运行 512 MiB，保留原登记/回收/输入核验。没有创建新测试框架。当前尚无本候选的运行通过证据。
