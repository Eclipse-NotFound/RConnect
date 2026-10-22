# 提前交付期间保留原生退出许可

基于准确 early1 `10B249…1FAE6`，版本 `0.2.24-early-travel2`。原生退出还在 19/10/1 时收到 grant，仅表示状态已恢复、可以绘制。此时旧 `endTravel()` 会让下一次真实 `TravelGuard.guardTravel()` 撤销尚未结束的原生退出，并写回上一地图。

生产改动只有两处：early grant 暂不结束退出许可；`completeEarly()` 已验证逻辑/显示就绪、成功释放外部许可后再结束。普通 grant 的原调用保留，取消/断线/失败逻辑没有额外改动；尤其构建前优化回退仍要保留许可走旧加载。90 个 AS 中 88 个字节不变，另两个是 RoomSync 和版本。精准差异见 `RoomSync.patch`。

## 源与组件

`prepare.py` 已执行一次，只组装源码，不复制游戏二进制。`integration.json` 可供正式完整编译；原 early1、旧失败、旧实验目录均不改。`check.py` 核对来源、两处精准差异和旧断言。

`components/room|gate|native|external|tile` 保留旧 217 项对应的六个入口，断言逐字相同，仅 room 的真实 RoomSync 换成 early2。旧 room 使用空 TravelGuard，所以另增 `guard-fixed` 和 `guard-baseline`：两组共用同一新夹具，唯一差别为真实 RoomSync 新/旧字节，均使用完整未改的真实 TravelGuard 与真实 Gate。仅 native world、网络和未测试的页面点击入口为显式替身。

新增夹具覆盖：首次/已访问准备 × grant 到达 19/10/1；真实 before→guardTravel 调用链逐步递减到零；重复 grant/activate；绘制完成不跳过原生退出；完整激活后不能复用许可擅自换图；构建前取消保留旧加载许可；恢复后取消保持关闭；断线 reset 清理。基线预计重现提前撤许可失败，修正版成功路径预计 79 条；必须以实际 AIR 结果为准，不删失败或修改旧断言。

根会话使用既有 Python（`-B -X utf8`）：

```text
experimental/recovery-early-exit-authorization/check.py
tools/validation/run_recovery_component.py --source experimental/recovery-early-exit-authorization/components/guard-baseline --entry EarlyExitAuthorizationChecks.as --output build/m52/recovery-early-exit-baseline-component-01
tools/validation/run_recovery_component.py --source experimental/recovery-early-exit-authorization/components/guard-fixed --entry EarlyExitAuthorizationChecks.as --output build/m52/recovery-early-exit-fixed-component-01
tools/validation/prepare_recovery.py build/m52/recovery-early-compile-02 --source experimental/recovery-early-exit-authorization --version 0.2.24-early-travel2 --build --registry-wait 900
```

旧六组件入口沿原 README，仅 source 改本目录 `components/` 并用全新输出。没有编译或 AIR 资格；旧 217 通过不自动继承到新完整候选。实际生成/绘制/Sand/重访耗时仍须根在准确新组合复测。
