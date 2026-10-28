# B 环境同步候选

## 当前集成结果（2026-10-29）

以下原始制作记录中的“未运行／未安装”是早期停点。当前 `environment-lock-02.json` + `candidate-inputs-03.json` + `overlay-03`（23文件，含Sandy默认音乐）已随 `B3-0.1-clientenv1` 安装并完成双侧复验。模组正源未改；CS/RV/LAD在实际1.02入口默认关闭，其余11项启用默认配置。旧ModSettings明确关闭以免重扫重新启用。

真实伤残/计时/个人保存、配件/战术模块/复活、两人服药/退出、载入/分房、时停/SATS与基地显示通过；同环境性能和安装回执见 `../b-field-client-integration/`。这些不代表穷尽所有武器、自定义设置面板、医生和背景门组合。完整证据与限制见 `../../state/b-clientenv-progress-2026-10-29.md`，原失败不覆盖。

## 独立制作阶段记录

2026-10-29。独立源码、三个模组 SWF 与 PI 原生候选已编译；没有启动游戏或安装。负责窗口之外的性能与经验开关改动不在这里。

当前可用产物及准确源／工具指纹见 `bridge-build-02/build.json` 与 `injury-native-sources-02/native-01/build.json`：

| 候选 | 路径 | SHA256 |
|---|---|---|
| TDFC scene2 + B | `bridge-sources-02/TDFC/TDFCMod.swf` | `9ed11bcce00b4a8dd219cf7f5279b7eea76138bd0db44c8e39477aa94a699c85` |
| Sandy 改键 + B | `bridge-sources-02/Sandevistan/SandevistanMod.swf` | `87b8cbcc29965056ff20e973d31085f8f0a0002678892b47efccfcc867328466` |
| PI B 独立接口 | `injury-sources-01/PermanentInjuryMod.swf` | `ff7a90d95f1cdb0c919f882a9ad00192077888c022f7e376a18479ceb1e766ac` |
| native021 + PI | `injury-native-sources-02/native-01/candidate/pfe.swf` | `3b1b77d3f6de08e5b31bb03883da6900b3656e497a4749305133019d0377ed83` |

原生仅一个 DoABC 标签变化，5039 标签同序，5686 个无关方法体及全部非代码资源保留，26 个 PI 方法回读通过。`native-readback-review.json` 另外检查了 B 接点、E4X 助手、真实伤害与延后结算顺序、Pers 存档、新字段和双计时防护。它们是编译／静态证据，仍需完整环境运行验证。

失败证据保留：native-01 等待超时；native-02 FFDec 默认日志目录拒写（改为候选自己的 APPDATA）；native-03 Weapon 局部声明被021编译器上提导致严格锚点停止。`prepare_native_revision.py` 只重定该实际赋值锚点。bridge-build-01 将 Sandy 自有时钟同包类误判宿主存根，已准确放行唯一自有类 `fe.serv.SandyHighFpsClock`，仍禁止嵌入 `fe.serv.Gov60`。

## 已查明

- 现有 B190/field8 的模组副本早于正式环境，缺少 PermanentInjury、AddictionSystem、FirearmAttachments、ContinuousScene、LightAndDarkness。14 个当前模组已按启动器真实扫描冻结到 `environment-lock.json`。
- 测试默认仅关闭 ContinuousScene、RealisticVision、LightAndDarkness；其余 11 个开启，RConnect 使用 B 候选而不是根目录的 A 包。
- MSW 正式 `526a6f…` 有 B API 字符串并已发布闪光修复，可直接作为候选输入；工作树含未发布 Pointer 实验，不能直接编译它替代正式版本。
- TDFC 正式 `7acd45…` 和 Sandy 正式 `cec6a3…` **没有 B 接口载体**，不是把最新正式 SWF 覆盖进去就能联机。固定 git 对象的源码同时包含 B 接口与已发布的 scene2 优化／改键，已分别冻结到 `bridge-sources-01`。这只是源码/字符串核对，尚非本轮 B 实机认证。
- native021 的完整 XML 没有 `piPermanent/piEvent/piFactor/piShot`，永久伤残必须补宿主接点。不能用正式单人宿主整体覆盖 B 宿主。
- 正式 Sandy config 的 `diaglog=1` 偏离编译默认；`cooldown=0` 则与当前编译默认一致。测试用空注释 config 采用代码默认，使用新的 AIR 身份，不能复制玩家偏好。RModifier 无 active/map-pools 文件时采用默认，不构造不明格式的空配置。
- RV 关闭时需移除 B 配置中的 `rv` 项，已有代码会使用原生视野退路。不能把缺少已选择模块的 API 异常改成静默跳过。

## 可重建入口

`environment.py audit` 只读启动器 `--list --json` 和现有产物；`lock --output <新文件>` 固定字节。`assemble --lock environment-lock.json --inputs <候选输入JSON> --output <新目录>` 只输出本目录下的小覆盖包，不复制游戏资源、存档或 LocalStore，不修改运行入口。候选缺失、指纹变化、API 字符串缺失会失败，绝不偷偷关闭用户要求开启的模组。

`prepare_bridges.py --output <新目录>` 从固定 TDFC `533a27c960f272f2d8003a725512c88cca7e469b` 与 Sandy `3f4a59b75da912cd32d193d448ff8cec608f97ae` git 对象冻结源码。每项 `prepared.json.commands` 是待执行编译参数，使用优化构建；旧 TDFC B 构建原来是 debug=true/optimize=false。`sources` 与编译器字节已固定；执行前再核对，不修改已准备目录的源码。

`prepare_injury.py` 从 PI `ce39a10` 冻结正式源码，增加独立租约与确认状态显示，输出 `injury-sources-01`。其 `prepared.json.commands` 编译模组自身，不触碰原模组。

`native_recipe.py --sources injury-native-sources-02 --build --job <新目录>` 会加入共享登记、核对内存与全部输入、保留失败证据。`--prepare` 只准备命令，不启动工具。流程是从准确 native021 导出十类 → 严格源码锚点 → 编译供体 → 只移植 26 方法并添加 Bullet.piShot/Pers 两个方法 → 核验所有未编辑方法及非代码资源 → 回读。编译器若遇到未经映射的 newfunction/callstatic/newclass 会明确失败，不能删掉检查改为整类导入。

## PI 并入 B 的接点

`authority/InjuryBridge.as` 是独立覆盖文件。主侧每名真实玩家分别运行，加入侧不执行伤残随机、扣费或计时：

1. `NativeAccess` 增加可空 `injury:InjuryBridge`；RConnectMod 对 `config.injury` 创建与释放桥。
2. `PlayerActor.step` 在**真实 unit.step** 前，在 actor scope 内调用 `injury.beforePlayer(actor)`，用 finally 调用 `afterPlayer(actor)`；SATS 停步不计时。
3. `HostSession.capturePresentation` 开始调用 `injury.afterWorld(actors)`，把所有房间中刚发生的敌人／弹丸伤害结算，再保存或捕获状态。这一步不能省略，否则宿主受到的伤害要等下一玩家步才落账。
4. `frame.character.injury=injury.snapshot(actors[1])`；加入侧确认帧（非插值帧）应用 CharacterState 后 `injury.present(frame.character.injury)`。Pers.piPermanent 由原生 Pers.save/构造钩子保存和读取，不重抽旧伤。
5. 租约 detach 保留最后确认的 Pers 状态，释放缓存；连接失败也需 dispose。client 设置页明确提示由主侧调整伤残规则；医生原生医疗动作仍由已有原生菜单意图在主侧执行，不能直接本地扣费。

候选原生 World.tick/flush 在 `Land.rconnectRoomStep!=null` 时让位给上述调度；单人、未 attach 路径仍运行正式原逻辑。冻结的源与 generator 不会写其他模组目录。

## 环境组装输入格式

```json
{
  "kind": "b-environment-candidate-inputs",
  "base_native_sha256": "eced04ad8dae6b74444ee6e5f5ec5ddf2e83528a9eecfef66f58985cb0c83063",
  "native": {"path": "绝对候选pfe路径", "sha256": "准确指纹", "capabilities": ["b3-v12", "permanent-injury-v1"]},
  "modules": {
    "RConnectMod": {"path": "绝对B候选路径", "sha256": "准确指纹"},
    "TDFCMod": {"path": "绝对独立桥路径", "sha256": "准确指纹", "authority_api": 1},
    "SandevistanMod": {"path": "绝对独立桥路径", "sha256": "准确指纹", "authority_api": 1},
    "PermanentInjuryMod": {"path": "绝对独立桥路径", "sha256": "准确指纹", "authority_api": 1},
    "FirearmAttachmentsMod": {"path": "绝对独立桥路径", "sha256": "准确指纹", "authority_api": 1},
    "AddictionSystemMod": {"path": "绝对独立桥路径", "sha256": "准确指纹", "authority_api": 1}
  }
}
```

FA 与 Addiction 由主会话／另一代理实现，载体暂约定 FAAuthorityAPI / AddictionAuthorityAPI，若交付名称不同须显式对齐环境脚本。组装后 `assembly.json` 给出目标启动器的真实 `--only` 参数与测试根需要清除的旧配置。不要直接把这个小覆盖目录当完整游戏启动。

## 尚需验证

- 现有三桥 attach/detach、失败后重试与联机新功能；TDFC scene2 空房/双房/威胁扫描，Sandy 双人回放伤害，MSW 闪光全角色和远距状态。
- PI 无伤时每人只计时一次；双方分别受伤、药物和医生收费、永久层与存档、死亡/复活/分房、时停/暂停；加入侧不能重复抽样。PI原生锚点对native021尚未实际跑。
- FA 配件/战术模块每玩家状态，Addiction 每玩家 Pers/Invent、药物与game.triggers保存隔离由对应独立桥验证。
- WallBlend 默认开启且现有正式包会维护本机墙遮罩，仍需双侧场景、背景门与快移显示回归；ModLoader 的最新设置页不等于 B NativeMenus 已完整镜像所有自定义面板。环境同步不能冒称这些组合已合格。
- 比较性能时，先固定准确环境和编译器参数。不能把新增模组计算成本与本轮加入侧渲染修复混成一个数字。

`tests/BInjuryAddonCases.as` 供主会话外部驱动选择 `injury` 场景；构造与 BFieldCases 一致，检查两人真实计时、无伤不变、真实原生受伤与各自永久层、加入确认且不二次抽伤、Pers 保存 JSON 与原生构造回读。它不修改 PI 默认配置，不是冷重启整档测试。没有修改公共驱动或自行启动游戏。

本轮已执行启动器只读清单、SWF字符串、git冻结、Python语法、三模组编译与类隔离、原生26方法选择移植及保存回读和静态语义审查。未运行 AIR，安装指纹未变。后续由主会话统一合并验证与部署。

2026-10-29 部署审查补充：旧 B 包与 overlay-01 都缺 Sandy 默认音乐。`inventory()` 已将 `mods/Sandevistan/release/sandy_theme.mp3` 纳入后续新锁的辅助资源：10,212,353 字节，SHA256 `8e542315f880fdd3bd904733fe64414ee547cf966c6d2eeb96e6acee5ca26531`。未修改旧 lock/receipt/overlay；下一轮须另立 lock02 与完整资源 receipt，不改变尚待授权旧调用的输入语义。两人的既有 AIR 身份和 `PFE*.sol` 必须保留；只备份并重置 B 的模组偏好以落实默认值，不整删 Local Store。名单须写入有效行及 `# selection` 意向，关闭 CS/RV/LAD 与旧 ModSettings；候选配置需同步六桥指纹和 environment，不能沿用旧四桥配置。现有五文件部署器的固定范围不足以覆盖本轮环境，需扩展为逐文件回滚事务。
