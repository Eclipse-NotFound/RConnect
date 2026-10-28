# B field8 载入修复

用户报告安保终端在载入时抛出 `Security terminal stepped without an occupant`，主侧停在 Loading、加入侧已经显示部分地图。主侧真实日志记录了 `party-map-entered` 后紧接同一栈的 `session-failed` / `FATAL`。

原版 `Land.buildRandomLand` 对前景及背景房间调用 `Location.preStep`，后者运行 30 次 `stepInvis`。B 的物件钩子也覆盖这个阶段，此时两名玩家都尚未进入新房间。原实现先建立个人终端记录，再因没有玩家而抛错；原版 `World.step` 在错误界面可见后停止，因而无法走完 `t_exit`、关闭 Loading。

修复只改变 `SecurityTerminals.stepObject`：先找实际房间内的玩家；没有玩家时返回，让既有调用者执行原版物件步进。个人破解状态和待执行请求都在确认房内有人后处理。正常双人破解、共享模式、房间暂停、播放及网络协议不变。

`source-manifest.json` 固定 field8 父覆盖包及本次两份源码，`restore-source.py --output build/ab/b190-visual-motion-<name>-source` 可恢复准确完整源码。编译继续使用 `tools/host_authority/field_driver/compile.py`；不修改已验冻结构建。

验证采用独立后台双实例、端口、AIR 身份、既有复制存档；测试驱动只静音自己的 AIR 实例。新增 `BLoadingCases` 检查无人房原生 30 步、初始化后首次个人状态、基地往返及用户报错地图种子 1288542690；既有 security 场景检查实际破解和炮塔权限。`deploy.py` 只接受准确 field8 基线和本次两项实测，复用已有五文件备份、并发校验、回滚及安装字节 UI 复验流程。没有重新进行性能对比，不沿用旧版性能证据冒充新版实测。

完整结果与部署状态见 `state/b-loading-fix-2026-10-28.md`。第一次 loading-01 在测试布置时缺少房间显示服务而停止，保留失败，不能用于候选验证。
