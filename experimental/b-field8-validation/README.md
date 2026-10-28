# B field8 验证接线候选

**后续状态（2026-10-28）：** 主会话已完成check03最终验证并部署，事务`build/ab/b-field-deploy-20261028-01`为verified；准确证据是prepared04、performance-result04、visual-review-final和installed-ui-01。下文“未运行”描述初次工具交付状态，不是当前安装状态。完整范围和密集欠帧/等待限制见`../../state/b-field8-merge-2026-10-28.md`。当前安装基线已变成field8；本工具固定field5起点，不可直接重复套用到后续部署。

本目录于2026-10-28完成源码和人工审阅，**未运行脚本、未编译、未启动游戏、未部署**。主任务负责登记和实际执行。工具不得替旧field5/field4结果改指纹。

上述为初次交付时的子代理执行边界。主任务后续已运行visual-01；其原始base断言失败保留，下一轮由主任务显式进入rbl，不改写旧结果。2026-10-28后续观察器增加父链可见性/颜色/遮罩、Grafon层、room/world.black、玩家位置、visLight与灯光像素、7×7屏幕采样；比较树时递归忽略实例name但保留原始数据。下一准备命令为 `prepare.py --preparation prepared-field8-01.json --out prepared-field8-02.json --refresh-driver`，是否执行及结果以主任务新回执为准。子代理未运行此命令。

## 准确起点

- 当前安装 `build/ab/b3-playable-190`，field5/scalar04，SWF `f9e542f6d64fef707c41563558365a3d90562dbc346f3be6cf84f968062b7c07`，source `22e2cdedf6e1c3c0aaf2e7c7821d8199f024ce6188dd01a56f82be18d0ac12f8`。
- native021 `eced04ad8dae6b74444ee6e5f5ec5ddf2e83528a9eecfef66f58985cb0c83063`，能力 `b3-v12`。
- 当前manual `4a85197620badfa03ec4eeac7769ed6106114178ee0d30678e01b8e71543cbf9`；20261027部署回执为verified。
- 功能副本 `build/ab/b-field2-runtime-01`；旧prepared-v19仍绑field22，必须新增field5绑定记录。
- 性能副本 `build/ab/b-field2-bench-20261025-01`、prepared-sustained-003可以继续复用；运行器分别核对不可变依赖，再替换候选/native/config。不复制整份game。

## 准备与源码接线

`prepare.py --out prepared-field8-01.json --refresh-driver` 从当前已冻结的prepared-v19出发，在同一副本编译新的独立观察器。保存旧祖先、旧manual备份、真实驱动源码/SWF、helper和复制存档指纹；仅换测试副本的产品/native/config/驱动。已存在的输出拒绝覆盖。无刷新时可只建立新绑定，不能让新helper冒用旧驱动SWF。

原 `run.py --refresh-driver` 固定读取最早prepared.json，因此本次不用它建立field5绑定；原scalar-cache/rebind_fixture.py固定field22及native变化，也不可直接复用。若第一次编译失败，保留失败目录，用新输出名重试。

主任务需要完成以下接线，本文没有改这些共享入口：

1. BFieldCases加入 `visualfield -> new BVisualFieldCases(...)`。
2. BStartupDriverMod.external()加入visualfield；该场景保持原base，不beginMission，不走毁地形lane；setup仅返回home/floorY，api增加picture。
3. run.py场景choices加入visualfield。suite.py可传场景串，但驱动仍需要前两项。

观察器实际位置：`tools/host_authority/field2_driver/BTextMotionCases.as`、`BVisualFieldCases.as`。前者只在取证时展开decor模板，保留已插值子树、不改产品记录、不放松原误差阈值；新增render间隔及socket待发缓冲诊断，不把待发缓冲说成累计发出字节。原motion场景依赖已经不存在的VisualMotionChecks，不能运行它冒充运动验收；普通移动复用textmotion的5阶段走动/射击。

## 最小运行顺序（由root执行）

以下路径均相对mods/RConnect，PY为已探测的Python；输出目录必须唯一。先冻结最终field8构建，不能在测试后换源或SWF。

```text
PY experimental/b-field8-validation/prepare.py --out prepared-field8-01.json --refresh-driver
PY tools/host_authority/field2_driver/run.py --workspace build/ab/b-field2-runtime-01 --preparation prepared-field8-01.json --scenario visualfield --candidate build/ab/<final-build>/RConnectMod.swf --native build/ab/native-hooks-021/pfe.swf --result build/ab/<visual-result>
PY tools/host_authority/field2_driver/suite.py --workspace build/ab/b-field2-runtime-01 --preparation prepared-field8-01.json --candidate build/ab/<final-build>/RConnectMod.swf --native build/ab/native-hooks-021/pfe.swf --output build/ab/<functional-result> --scenarios ui,darkteleport,controls,security,terrainlive,rockets,enemies,textmotion
```

既有八项可按实际改动选取；本轮新增行为最低覆盖ui、textmotion、visualfield，核心同步/传输改动通常仍需要八项。visualfield取证有原始基地、backobjs清单、public frontBmp、public visBack/visBack2中的Bitmap、medbox/term native符号树、两zoom×Emitter.scale 0.5/1.5。原生backBmp是internal，不动态访问。它以presentation配对，有界树和像素采样只诊断；实际差异须逐条判读，不能把采样PASS当视觉等价。

```text
PY experimental/b-field8-validation/qualify.py freeze --candidate-build build/ab/<final-build> --out experimental/b-field8-validation/performance-plan.json
PY tools/host_authority/field2_driver/bench_sustained.py --workspace build/ab/b-field2-bench-20261025-01 --candidate build/ab/b190-scalar04-build --native build/ab/native-hooks-021/pfe.swf --result build/ab/<baseline-01> --seconds 60
PY tools/host_authority/field2_driver/bench_sustained.py --workspace build/ab/b-field2-bench-20261025-01 --candidate build/ab/<final-build> --native build/ab/native-hooks-021/pfe.swf --result build/ab/<candidate-01> --seconds 60
# 同环境再baseline-02、candidate-02；不profile、不diagnostic。
PY experimental/b-field8-validation/qualify.py evaluate --plan experimental/b-field8-validation/performance-plan.json --baseline build/ab/<baseline-01> build/ab/<baseline-02> --candidate build/ab/<candidate-01> build/ab/<candidate-02> --out experimental/b-field8-validation/performance-result.json
```

沿用8/80敌人各60秒、平均/P95不超过1.05、重复1.2门槛。新qualifier只换准确field5基线，冻结本包装器和原判定器指纹。旧scalar-cache qualifier仍固定field22，不得用于这次对照。

## 部署工具

`deploy.py check/install` 要求显式candidate、每个选定场景的test/preparation、performance、notes、visual-review。candidate最终标签为 `B3-0.1-field8`、协议revision5，SOURCE与完整源清单可重建；若最终版本名不同，先修改该明确约束再冻结工具。三项最低必需场景为ui/textmotion/visualfield，其余八项可补。重复场景、错字节、旧准备、不同依赖、未结束/失败日志均拒绝。

visual-review是主任务实际读完诊断后的JSON，字段：candidate_sha256、source_id、result_sha256、accepted、findings数组、limitations数组、evidence字典。evidence键为该结果目录内的相对文件名，值为真实SHA256，至少包含visualfield-join-final.json和visualfield-host-rows.json。它不是新用户批准流；accepted只表示主任务对准确结果的技术判断，不能预填或自动生成全通过。

`transaction.py`为旧 `experimental/b-field-deployment/deploy.py` 的独立源码快照，仅改验证说明里硬编码的“八项”数量为实际场景清单。五文件备份、并发hash复核、原子替换、失败回滚及安装字节smoke/finalize沿用；不动旧工具，避免破坏旧证据。根A、启动器、AIR身份、存档和配置均保留；不关闭玩家游戏，完成后提示保存并重启。

```text
PY experimental/b-field8-validation/deploy.py check --candidate build/ab/<final-build> --test ui=<result.json> --preparation ui=<prepared.json> ... --performance <performance-result.json> --notes <notes.txt> --visual-review <visual-review.json>
# check通过后同参数install，额外 --transaction build/ab/b-field-deploy-<unique>
# 安装字节隔离ui：candidate必须指build/ab/b3-playable-190/game/mods/RConnect/release/RConnectMod.swf，native必须指该game/pfe.swf。
PY experimental/b-field8-validation/deploy.py finalize --transaction build/ab/b-field-deploy-<unique> --smoke <installed-ui/result.json> --smoke-preparation <prepared-field8-01.json>
```

安装smoke复用部署前field5准备是明确允许的：run.py在启动前从实际安装路径换入两份新二进制；finalize使用事务保存的部署前manual核对祖先，其它依赖不变。不重跑完整矩阵。
