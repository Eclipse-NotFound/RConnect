# A 时停接口真实生命周期（仅功能）

准确 early1 `10B249…1FAE6` + 宿主 `2D415D…DD29` + Sand A 桥 `3E220B…D331C`，通过已冻结 `recovery-early-sandy-native/native_inputs.py` 和底层 runner 复用全部产物准入、安装 22 项指纹、登记、独立存储、原生资源和清理保护。本目录没有修改那些冻结文件。

单个实际 AIR 游戏实例，在原生基地和真实角色上运行以下步骤。不是 Sand 模拟对象，也不直接调用其私有启动／回放函数：

1. Stage 实际 `KEY_DOWN/KEY_UP`（读取固定配置的反斜杠键 220）启动时停，等待 8 个 ENTER 回调，确认实际剩余帧数下降。
2. 在实际 `active` 阶段，分别调用真实载体 `acquire` 和 RConnect 的 `MapGeneration.acquireEarly`；必须都拒绝，且同步查询的计数和控制状态不变。
3. 再按真实热键进入回放，立即确认 `replay` 并重复拒绝检查。等待实际回放自然结束。
4. 由真实 MapGeneration 取得空闲许可。检查相同票据幂等、错误票据不能释放；持有 12 个 ENTER 回调，在第 2／5 回调发热键 DOWN，第 7 回调发 UP。每次查询必须仍为 idle+held，公开计数和控制标志不变。
5. 正常 release 后同一热键必须重新启动时停，实际剩余帧数再次下降；再次按键进入回放并等其结束，最后无许可泄漏且控制恢复。

成功路径为 41 项运行断言，包含 12 条逐回调持有检查。输出 `SANDY HOLD RESULT` 保留有界的阶段／键事件／真实查询记录。错误路径只清自己的许可和释放测试键，不恢复旧 World 标志、不伪造游戏状态；不会复活死亡角色。

## 执行入口

根会话在 `mods/RConnect` 使用现有 Python，均带 `-B -X utf8`：

```text
experimental/recovery-sandy-hold-native-lifecycle/check.py
experimental/recovery-sandy-hold-native-lifecycle/prepare.py --output build/m52/recovery-sandy-hold-native-driver-01 --build --registry-wait 900
experimental/recovery-sandy-hold-native-lifecycle/run.py --drivers build/m52/recovery-sandy-hold-native-driver-01 --output build/m52/recovery-sandy-hold-native-01 --registry-wait 900
```

仅编译一个外部 AS 文档，使用现有声明／存根／harness。编译仍有 1 GiB 入口和自有进程内存监测；原生调用复用原 runner 的 solo 3 GiB 启动、512 MiB 运行保护、隐藏桌面、独占 AIR 与登记。若用户选择保留其游戏，也不能悄悄去掉独占检查；由根另作明确功能准入决定。

## 资格边界

- 这是**真实单实例接口生命周期**，不给双人加载耗时或性能资格；完整三段双人／单人测试在另一个冻结目录。
- 此接口自己只暂停 Sand 的独立回调，不改变原生 World 的暂停／控制。这里不假称“全游戏冻结”，不新增生产 observer。
- 配置实际 `cooldown=0`、`esandyenabled=0`：因此观察到公开计数保持，不能证明非零冷却或敌人补步的冻结；结果显式不授予这两项资格。
- 真实 active/replay 拒绝不等于完整旅行中途回退。后一项及死亡、换 Game、断开、外部拥有者竞争已有组件但仍缺原生资格。
- 计数是驱动实际 ENTER 回调数，不冒充原生 World 逻辑帧或稳定 FPS。

当前只有源码和纯检查，尚未编译／启动 AIR。正式源码、安装版、既有失败结果均未修改。
