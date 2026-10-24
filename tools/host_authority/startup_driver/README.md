# B190 启动故障专项

产品修复只涉及 `RConnectMod.leaveSession` 的接口释放和 `PlainData.nativeCopy` 的本地保存预算。`prepare_fix.py` 将这两项精确补到冻结 B190，避免夹带后来性能候选。实际结果、输入和回滚见 `state/b190-startup-repair-2026-10-25.md`。

- `BStartupDriverMod.as`：独立驱动，通过 HUD 真实按钮和原生旧档流程验证，不向产品嵌入测试钩子。
- `run.py`：独立存档、共享测试登记、隐藏桌面、内存门槛、按角色保存原日志及运行组合指纹。每次结果目录必须新建。
- `prepare_pair2.py`：保留旧驱动后编译双方完成检查的协调修正；产品与 25 tick / frame 门槛不变。
- `deploy_fix.py`：仅更新原 B190 独立入口，有精确备份、指纹校验、部署后验证和回滚。其固定目录用于这次交付，不能盲目覆盖后来候选。
- `archive_runtime.py`：先保留独有输入及可恢复引用；删除动作由外部 PowerShell 在核实绝对路径和进程后执行。

本轮临时 game 已清理。原 `build/ab/startup-repair-20261025-01/cleanup.json` 能定位每项输入；源码、两份旧档、原日志和构建保留。恢复原验证环境后才可重跑已有命令；不要把清理后的不存在路径误判为游戏故障。
