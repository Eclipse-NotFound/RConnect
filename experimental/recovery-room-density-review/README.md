# 当前宿主下的固定双人密集对照入口

状态：只读准入已过，尚未运行；不构建驱动或产品、不改安装、不改旧 prepared/compile/result。根会话负责排队运行。

使用准确 `recovery-density-corridor-drivers-03`：manifest `5a8dbb9395c8dba8b6e980c49b112c6df3ae2e19e2f4950769d29756f8e1735c`，Driver `cfca757c22052f0efd29afca1f76fe717e79d436b03a264413add2e4c8c9150a`，Harness `d52ef4300c7d472ee05884d7b4709f4abf80b3e6ff935b695a9ed986db021086`。实际 files/inputs/originals 全量只读回核通过。

## 唯一适配

`run.py` 直接加载原 `tools/validation/run_motion_comparison.py`，只替换其读取**本次选中产品 prepared.json**时的内存视图。按真实来源核对全源码、构建输入、版本、二进制及编译记录后，把不同年代的元数据键映射给旧入口。磁盘上的原清单及结果不改写，原 wrapper 的所有其他读取、子进程、解析、阈值保持。最后原样调用 corridor-readyfix 的严格 audit，另存 admission.json / admission-after.json。

- `574d`：准确历史 `coop-bundle-04` / 574D…41AFE；当年的编译成功与产物 hash 在 prepared 中，没有独立 compile.json。核对历史部署审查中相同 prepared/产物绑定，不虚构现代编译回执。
- `aura1`：准确 `recovery-aura-offline-01` / DF0F…DC01E7；prepared 是构建前清单，实际成功在独立 compile.json。两个都核。
- `roomfix4`：准确 `recovery-room-production-04` / 34A17D…22B703；核 prepared、实际 compile 两条成功命令、完整输入及 v4 overlay 绑定。

实际运行组合现在固定为 **宿主 ABE2…A2602A、RV 0DBE、正式 RC DF0F**。核对 CS 的 `vertical-camera-band-deployment-20261023.json`（DF8FFE…DC8DD1）确为 verified 且 80CF→ABE2；其余 21 项须等于该回执基线。历史产品在 BEFC/80CF 等组合构建的记录原样保存，不要求它们冒充在 ABE2 编译。第一次只读检查在 CS 刚替换宿主后按旧 80CF 正确拒绝；收到明确新组合后修改了本新入口的运行环境绑定，没有动历史文件。

这条入口采用本次安装的发布默认设置，**不使用**旧 `recovery-density-profile-settings` 中关闭 RV 的两份玩家设置快照。同一对照两臂由原 wrapper 要求 22 项安装、游戏/资源/模组、驱动/Harness、原 runner 与占用检测器完全一致。队列、唯一存储、私有桌面、6 GiB 启动/512 MiB 运行保护、只清自有副本均由原 runner 执行。

## 固定负载与限制

原生生成种子 719355926；48×25 房间准备为同一固定走廊；清除多余自然敌人后，准确 80 身体（1 尸鬼、40 血翼、39 掠夺者），39 把武器（12 LMG、27 p308c）；固定玩家 X=161.8/Y=960、方向、镜头和对侧站位。双方全部身份/武器参数/原生显示准备完成并稳定 600 ms 才开始；audit 保留全部实际地形、人口、武器、站位和图形对象比较，不只看总人数。

仍是原七段，每段至少 8000 ms；原门槛不改：frames≥80、p95<200 ms、packets≥20、maxPacket<900 ms、瞄准推进、真实轨迹传输、可见且运动的弹丸、结束弹丸不新增隐藏姿态等。原错误与任何不一致均失败保留。

这是固定准备状态和同一刺激规则的**联网负载对照**，并非逐随机数/逐弹丸完全相同的录像回放：身体由原驱动 Timer 移动，瞄准使用墙钟正弦，12 枪按宿主帧数交错开火，快慢版本在固定时间内可能发出不同次数。不能把单次结果当全场景性能结论。它不测完整自然 AI 游玩、不测大地图加载，也不适用于 --solo（原驱动等待 rooms.ready 和对侧握手）。用户主要质疑联机倒退，本轮优先复用这条现成对照，不扩建单人框架。

## 根会话执行参数

先只读准入（已执行过，无子进程）：

```text
experimental/recovery-room-density-review/run.py --check
```

之后各轮用新输出目录，先旧后正式；第二轮严格引用第一轮。同一入口还接受 roomfix4，留待根确认。

```text
experimental/recovery-room-density-review/run.py --candidate 574d --output build/m52/recovery-current-density-574d-01 --registry-wait 900
experimental/recovery-room-density-review/run.py --candidate aura1 --output build/m52/recovery-current-density-aura1-01 --reference build/m52/recovery-current-density-574d-01 --registry-wait 900
```

调用原 wrapper 的成功结果仍需附原 corridor fixture-audit。未实际运行时不报告任何新版更快/更慢结论；Git 差异和这里的准入均不能替代实测。
