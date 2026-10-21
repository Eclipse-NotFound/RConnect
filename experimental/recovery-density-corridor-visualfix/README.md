# 走廊准备：原生显示层修正候选02

2026-10-22。只有外部夹具改动，未启动 JVM/AIR，未改生产、安装版或冻结01。根因与其它审计限制见 `../recovery-density-corridor-review/README.md`。

准确来源为已经编译的 `build/m52/recovery-density-corridor-drivers-01`，manifest `4aea5b4182948f6687e89160b52711d569d9a9e46a8b21ef75ba61b2f81832cf`。它的编译产物和原始记录保留，但因宿主原生重绘会跳过disabled角色重新挂载，尚不应用作密集绘制基线。

只在 CorridorFixture 准备阶段增加原生挂载：

- `world.redrawLoc()`后，按原native对象链顺序对80本体与RemoteDamageUnit调用`addVisual`，最后本机玩家。调用期间只临时把disabled设false，finally恢复原值；不执行step、不改伤害/姿态/visible/alpha。原生Unit.addVisual负责其childObjs武器和血条。若原生调用改变trigDis则准备失败，不能偷偷改变触发资格。
- MirrorHitUnit借用真正本体的vis，不能再挂一次；PlayerMineGate故意无图像，保持原状。对侧武器原本挂在visualPlayer之下，检查其祖先关系，不将它误当独立原生层武器。
- 准备status必须看到80本体、39把实际演员武器、1本机玩家及1远端玩家。检查实际stage与**当前**visObjs父层，身体Bitmap/主动画、枪体、可见祖先及正尺寸；已有血条要求正确挂载，但不要求原本隐藏的血条显示。新检查失败进入原45秒准备失败路径，不能靠改摘要通过。
- `DENSITY CORRIDOR.visuals`保存实际逐项结果；运行后audit要求它非空、计数准确、全部真实检查通过。没有新逐帧扫描/PNG/计时窗内维护。遮罩或角色彼此重叠的最终像素覆盖不由这些显示树检查证明，仍不宣称逐像素可见性资格。

主驱动及其它AS源相对冻结01逐字节相同。80/12枪、七段>8000ms、原frame/RENDER实现与全部原断言不变。`prepare.py`仍复用准确锁定的固定场景构建器和共同测试登记；增加本次源差异白名单、01清单及全部源指纹。输出必须是全新目录。

```powershell
# RConnect根目录；只有root在共享登记下执行后两步。
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/recovery-density-corridor-visualfix/check.py
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/recovery-density-corridor-visualfix/prepare.py --output build/m52/recovery-density-corridor-drivers-02 --build
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/recovery-density-corridor-visualfix/run.py --candidate build/m52/coop-bundle-04 --drivers build/m52/recovery-density-corridor-drivers-02 --output build/m52/recovery-density-corridor-control-02
# 对照完成后，以完全相同drivers-02及同安装输入跑目标候选，传--reference上面的结果。
```

已完成纯Python源码等价、括号检查、原阈值保持、九条显示挂载静态契约核对。AS尚未编译，原生准备未验；不能称显示或性能已过。最终根会话须看真实双方visuals及七段原门槛。

本次不扩改已审查的继承限制：arenaLocalReady稳定期锁存、重置地形造成持久128格terrain轮转流量、首次netAt诊断错误、profile日志诊断标志遗漏、终场静态复验缺席。先只提供普通入口；若以后使用profile必须坚持诊断资格，不能把现audit的attribution_allowed当普通性能通过。新走廊不是原随机房，不能抹除旧两轮失败。
