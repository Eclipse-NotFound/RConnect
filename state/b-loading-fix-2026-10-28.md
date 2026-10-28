# B 安保终端初始化与载入停滞修复

## 问题与原因

用户提供完整 `Security terminal stepped without an occupant` 堆栈，并补充主侧停在 Loading、加入侧已有地图的截图。真实主侧日志在 `party-map-entered`（地图 random_mane，种子 1288542690）后记录同一异常和 `session-failed` / `FATAL`。

原版 `Land.buildRandomLand` 对前景及背景房间调用 `preStep`；`Location.preStep` 用 30 次 `stepInvis` 完成初始化。B 的全局物件步进钩子同样接管此阶段。`SecurityTerminals.stepObject` 先创建个人状态，然后把新房内尚无玩家当成非法情况抛错。`Location.stepInvis` 把错误交给原生 `showError`；后续 `World.step` 在错误界面可见时直接返回，载入流程无法到达关闭 Loading 的 `t_exit == 16`。

本轮未发现另一个独立的 Loading 原因。`PartyTravel.context.transitionCooldown` 对应 `Land.loc_t`，不是原生换图 `World.t_exit`，没有修改它或强行清除错误界面。

## 修复范围与准确产物

- B3-0.1-field8-loadfix1，基于准确 field8/check03；仅修改 `SecurityTerminals.stepObject` 与版本号，BuildInfo 的变化仅为重新生成的源码指纹。
- 先查房间中实际玩家；无玩家时直接返回，由已有调用者执行原版物件初始化。此时不创建个人破解记录、不消费个人请求。正常有人房间的破解和权限处理保持原样。
- 构建：`build/ab/b190-field8-loadfix1-build`。
- SWF SHA256：`92ea5ec83aa1ab5a412581ba80ebbc49b16fb93a01c180df239b88a4f59b1af7`。
- source：`ac5e9d6e62c35e937deeb254f13c6371d8940f23a0f42f82e578b5006ea65d81`；build manifest：`4bc5983e3b7c61358fc7607e2561bedd607cd96ea351b6f1413f929a459dc47c`。
- native021、revision5、b3-v12 保持不变。没有调整网络、房间调度、播放缓冲或存档格式。
- 完整可恢复覆盖包：`experimental/b-field-loadfix/`。已实际运行 restore-source，重建 142 份源码，指纹与候选相同；不修改此前冻结源码。

## 验证

本轮使用独立后台双实例、独占回环端口、全新 AIR 身份、原有复制存档；默认静音自己的 AIR，未操作玩家窗口或真实存档。功能样本与其它程序并行运行，不作性能对照。

- 最终测试准备：`build/ab/b-field2-runtime-01/prepared-loadfix-03.json`，SHA256 `9a822144f5492a6be31b4d9103b5e73007911334d9198fdf3b011da3c47298d9`。
- `b-field-loadfix-loading-01`：失败保留。测试布置在未注册显示服务的空房里调用 NativeScope，尚未运行待验初始化。只修正外部测试工具，未改候选。
- `b-field-loadfix-loading-02`：主20、加14，通过；测试元件为原生安保终端，真实 preStep 的30次步进全部通过当前钩子，无错误；初始化后双方首次读取都得到更新后的 lockAtt=13，未提前保存旧状态。
- 基地→报错地图→基地的三次真实原生换图，均观察到 Loading 出现再关闭（t_exit=0）、原有双方实体保留、主侧控制和上下文恢复、加入侧收到一致目的地。报错地图种子1288542690在测试角色下生成3个安保终端并成功载入。主侧最终截图已人工查看，场景与HUD正常可见。
- `b-field-loadfix-security-01`：主89、加12通过；个人尝试次数、双人同时破解只步进一次、共享／分别权限、不同技能等级真实E键破解与炮塔感知／射击／双方最终血量均通过。未出现原生错误或运行文件变动。
- `b-field-loadfix-installed-ui-01`：直接从安装后的 B 文件取样，主77、加36通过，覆盖交互提示、真实破解进度、门及独立换房；运行字节未变，双方无FAIL/FATAL。其实际加载source/version与本轮候选一致。

## 部署与边界

已由 `experimental/b-field-loadfix/deploy.py` 写入原 B190 安装目录，事务 `build/ab/b-field-deploy-20261028-loadfix-01/deployment.json` 已 **verified**，before 保留准确 field8 五文件回退点。复验和最终回读通过，原启动入口、配置和存档身份保持不变，根/A见证未变。所有自有测试进程结束。已经卡住的两个窗口必须重启并重新读档，不能热修复其内存状态。

本轮没有重新测试性能，也不声称解决此前密集供帧、延迟与长帧问题。复现地图使用真实报错种子、隔离复制角色；没有复用玩家正在运行的内存会话。
