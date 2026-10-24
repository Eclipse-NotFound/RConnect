# 普通房、明确不加载 ContinuousScene 的计时夹具

准确来源 `build/m52/recovery-room-current-driver-01`。Metrics 源逐字节保持原非诊断版，不引用 LoadingCounters 或 sampler。只编译 `RoomTravelTimingTestDoc`，不编 Scene 子类，不创建 CS 启用偏好。

Timing 仅三处 CS 专属适配，见 `source.diff`：启动时扫描并要求 `ContinuousSceneMod` 类不存在，不写其 nativeEnabled；每次到达同时要求类仍为空且实际未构造合并场景；加入侧结束时保留原 `session.leave()`，将“CS 偏好未改变”改成“CS 仍未加载”。所有其它三程、种子、房间尺寸、双方位置、恢复控制、暂停/遮罩观察、95 秒阶段期限及原 compare 断言均保留。不能加载 CS 再把它冒充禁用。

```text
prepare.py --check
prepare.py --output build/m52/recovery-room-reduced-driver-01 --build
```

不加 `--build` 只冻结输入；新输出不得存在。`verify(Path)` 回读来源、源码、产物、安装与实际编译回执。编译沿用共享登记、隐藏子进程、1 GiB 起步/512 MiB 运行保护、finally 回收；本目录不启动游戏或修改正式安装。

实际运行由主代理用原共享 runner 的 timing 场景与真实 aura1/roomfix4 产品接线，明确从隔离清单排除 LAD、RV、CS，并核对两端实际加载清单。该环境结果只代表普通房和这组关闭配置，不能替代 CS 大图/RV 开启的性能比较。原历史夹具与失败证据不改。
