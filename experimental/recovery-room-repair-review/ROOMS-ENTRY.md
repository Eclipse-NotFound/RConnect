# 当前宿主的 BF6 普通房回归

`run_rooms.py` 复用冻结的 `recovery-entry-observer-driver-01/entry-room`（BF6C9567…53BA），不编译、不改任何 AS 或原框架断言。调用原框架 `recovery-first-raster-native/run_native.py` 的公开 `audit` / `verify_driver` 边界：前者独立核准确 roomfix1 4D9F 与其构建/源清单，后者使用原 BF6 观察器的真实验证函数。原框架的可选 `game-candidate` 传空，实际采用当前安装宿主 80CF，不调用或冒用旧 FD92/6616 宿主审计。底层原 `run_coop_regression.py` 不变。

原框架的 600 秒、独占私有桌面、登记、6GiB/512MiB、全部错误与原断言保持。附加 `adapter-result.json` 再核当前 22 安装文件、实际输入、清理与内存，原 `result.json` 不改写。AST 与只读 `--check` 已通过；尚未启动游戏。

```powershell
# cwd: mods/RConnect；由父会话执行
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/recovery-room-repair-review/run_rooms.py --output build/m52/recovery-room-candidate-entry-01
```

该既有套件检查独立分房、汇合、房间权威交接、空房重访、敌人生命/护甲/武器状态、死亡不复活、破墙/容器/掉落不回滚或重复、抓取释放、静止宿主不受对方换房影响，以及未确认画面遮挡和旧房消息拒收。BF6 已区分宿主本机 commit 与对侧 ACK，未恢复旧错误观察前提。

范围限制：`A22RoomEntryTestDoc` 调用 `super("random_mane",false)`，本次不会执行下一层和挑战区域分支。源码的 `hidden` 炮塔标签表示炮塔构造状态，不是背景门隐藏房；本次通过不能授予背景门进出资格。原场景生成不固定种子，也未注入额外宿主功能。

三组整图计时复核见 `TIMING-REVIEW.json`，原正式版的出生错位失败保留。三组使用相同宿主、驱动、资源、模组，但单人与双人的实际对象数及原框架运行角色不同；只有本次逐段加载对照证据，不据此声明所有房间或密集战斗已经达到统一性能上限。
