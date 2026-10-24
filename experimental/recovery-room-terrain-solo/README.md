# 单实例原生地形往返取证

只查首个地形画面不能复用的自然原因。准确诊断产品为 `9A128737` / `0.2.24-roomreason1`；不重新编译产品，不修改正式安装。A796 宿主和 78C052 正式 RC 固定，其余实际输入在 prepare 时真实冻结；运行时全部 22 项必须与该 prepared 完全一致。相对部署时的变化另列（准备期间已观察 RV 更新至 BF4A、ModLoader 更新至 2050）；历史产品编译环境另存，绝不冒充当前环境。

驱动从已有只读 littlepip 复测副本复制到私有槽 9。正常载入后去基地，以原生 beginMission 生成固定种子 1380142925 的大图，保存真实完整 checkpoint 并经真实 RoomCodec pack/unpack 隔离引用。随后只调用一次 loadSaveTest(9)，在新的 Game、玩家、Land、Location 中以相同原生参数重新生成，再仅调用一次 `restoreCheckpoint(payload,false,true,false)`。没有手造、删除或改写门与 tile，也不要求出现特定数量的对象注入。构造钩子记录真实 visited/stage/conf/difficulty/level；不把到达后的 visited 当作生成前参数。玩家绝对出生坐标只记录，不假定原生随机出生必须一致。

原共享运行器继续负责登记、3 GiB 启动与 512 MiB 运行保护、独占 AIR、私有桌面、错误扫描和自有进程/副本清理。薄入口仅借已有登记对象的 before_launch 写私有 CS 偏好并忠实复制当前 telemetry.json；child_stopped 在原运行器回收进程后、删副本前核对两个配置。补充证据独立保存，不重写原 input.json。telemetry 当前 enabled=true，不能拿本次结果与旧未复制配置的结果比较性能。

原始快照不截断，保存为 terrain-roundtrip-snapshot.txt；单实例结果、真实首拒因和原始输入/日志指纹分别保存。仅 mechanism_only；永远不授联机、房间同步或性能资格。准备阶段为了确认生产 autoLoadSave=9 已真正排队，仅每秒最多读一次本实例日志，并同时等待原生稳定状态。全程有 300 秒上限，每阶段 95 秒上限，原生错误框不隐藏、不清除。

在 mods/RConnect 下使用：

```text
python -B -X utf8 experimental/recovery-room-terrain-solo/prepare.py --check
python -B -X utf8 experimental/recovery-room-terrain-solo/prepare.py --output build/m52/recovery-room-terrain-solo-driver-01 --build --registry-wait 900
python -B -X utf8 experimental/recovery-room-terrain-solo/run.py --driver build/m52/recovery-room-terrain-solo-driver-01 --check
python -B -X utf8 experimental/recovery-room-terrain-solo/run.py --driver build/m52/recovery-room-terrain-solo-driver-01 --output build/m52/recovery-room-terrain-solo-native-01 --registry-wait 900
```

输出不得覆盖。prepare 默认仅准备；只有显式 --build 才编译外部驱动。所有实测由根会话执行。
