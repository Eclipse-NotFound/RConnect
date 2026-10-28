# RConnect B 开发入口

## 职责和约定

只负责 B：加入侧发送输入，主侧执行两名玩家和双方房间，加入侧重现确认状态。A 由另一会话负责；不混入未合格B195或A源码。A入口见MEMORY.md。所有RConnect开发会话允许协调；其它模组只按已有独立接口授权工作。

普通房可分头，无人房暂停保留本次进度；整图由主侧发起，剧情/挑战共同进入。先到先得掉落、共享奖励、角色各自保存。TDFC/MSW/RV/Sandevistan用已授权B独立桥。已允许通过本机门禁后直接部署，不重复确认。

测试登记后在自有后台桌面、独立AIR身份和复制种子中运行；不碰真实存档、不关闭玩家程序、不调用未点名Ghost。双实例启动物理余量6GiB、单实例3GiB、运行512MiB，另有可提交内存保护。复用隔离目录，保留失败和唯一证据，不复制整套游戏耗费D盘。

## 最新任务与安装状态（2026-10-28）

用户要求合并部署积累代码，修复移动卡顿、加入侧医疗箱/终端颜色异常、基地背景物件缺失错位、NPC文字过大。此明确部署请求取代前轮“仅源码、不做实验”。

**当前已安装 B3-0.1-field8 / check03，安装字节双侧UI复验通过，事务verified。**

- 原入口：`build/ab/b3-playable-190/Player-1.cmd`、`Player-2.cmd`。原存档身份、配置、启动器保留；两侧旧窗口需保存并重启才会加载新代码。
- 冻结构建：`build/ab/b190-field8-check03-build`。
- SWF：`d1a83ed5e38da1b80786b32e39e1375794586614420e1731ee5cbc9380813ed5`。
- source：`9c8588713f10d46e445c2ecc64f88a37a6b09242bb9266b84136686308f2a54a`；revision5，native能力b3-v12。
- native021不变：`eced04ad8dae6b74444ee6e5f5ec5ddf2e83528a9eecfef66f58985cb0c83063`。
- 事务：`build/ab/b-field-deploy-20261028-01/deployment.json`，已verified；before保存准确field5五文件。安装字节复验`build/ab/b-field8-installed-ui-01`主77/加36通过，运行字节未变，根宿主/A/原启动器/配置和存档保留。当前manual SHA：`ab7a72c103a5bfdc97f526bbac87f07b2239263fb1a9af64424b17a474571c5c`。
- 前版field5/scalar04：SWF `f9e542f6d64fef707c41563558365a3d90562dbc346f3be6cf84f968062b7c07`，source `22e2cdedf6e1c3c0aaf2e7c7821d8199f024ce6188dd01a56f82be18d0ac12f8`，旧verified事务20261027-01保留。

## 本轮实现和可续源码

完整累计覆盖源在 `experimental/b-field-visual-motion-final/`，20份差异AS（7新增），组装后142份源码与check03完全一致。`prepare.py`只组装新的`build/ab/b190-visual-motion*-source`，不编译/游戏/部署；完整patch、清单、assembly-verification已保存。继续开发应从此完整覆盖包或冻结check03恢复到新工作目录，不修改已验冻结源。

- 合入field6：场景目标索引、弹丸记录FIFO、显示树子记录复用、差异编码路径栈、接收缓冲未读游标，保持原条件与顺序。
- 合入field7：原生血条紧凑描述、准确原生伤害数字静态模板复用、根pose缓存、只发送加入显示房的弹丸副本；复杂结构回退，主侧原始弹丸/时停历史保留。
- 探索合并只在新增内容时分配，保持旧数据不可变。Python对照通过，不把它冒充AS3性能。
- SceneBackdrops补同步真实Location.backobjs，原生BackObj保留位置/图层/擦除/灯光；不重抽地图。
- Box影子归所属物件管理，保持原生先影子后本体。原发暗是影子作为松散效果最后盖在本体上，不是资源颜色错。
- SpeechScale和原生Emitter包装器记录NPC气泡出生相机比例，按加入侧自己的缩放换算；原生自定义比例/寿命保留。
- MovementPrediction只对确认超过150ms时保留该确认下已经显示的安全位置，不再继续推算，也不突然撤回到旧播放位置。新确认、暂停、房间/位置/地形身份变化、危险输入均取消缓存。停止/反向可暂时停留直到新确认，不能称输入即时生效。

## 验证证据

最终prepared04：`build/ab/b-field2-runtime-01/prepared-field8-04.json`，SHA `9290ec219392d300848af421cdc23e338b20353260ccafebec56dd66cf02fd10`。三个check03准确场景：UI主77/加36；textmotion主56/加69（含两侧各31个真实候选类边界检查）；visualfield主32/加25。全部通过，原始运行字节未变。

四个移动阶段双方确实行走，没有记录到镜头反转；文字误差≤0.05px、缺失0。视觉28组确认中63个基地背景对象匹配、56对Box/112次影子层序正确、8个同缩放像素块一致；NPC出生8次与宿主变焦后8次全部通过。阶段截图可能早于新气泡生成，所以字号判断使用带身份的ack。最终视觉复核`experimental/b-field8-validation/visual-review-final.json`，保留整图底图摘要仍异的限制。

性能正确交替：baseline04→check03-perf01→baseline05→check03-perf03；报告`experimental/b-field8-validation/performance-result04.json`，原5%平均/P95、重复1.2门槛未改。8敌人主均55.81→51.34ms、加41.03→39.59；80敌人主98.86→94.80、加74.38→72.85。平均改善2.1%–8.0%，P95改善3.0%–13.2%。实际负载是持续轻机枪、8/80敌人各60秒、1000发测试弹匣，不更改玩家枪械。

## 遗留和验收边界

**密集供帧/等待仍未解决，不能把正式平均/P95资格解释为全面无退化。** 密集加入欠帧净增基线0/0、候选86/8；播放目标均239.60→249.54ms，候选140/153观察顶到250ms。静止阶段加入仍有575ms长帧，持续场景也有387ms主侧长帧。CPU峰值和内存环境留原样，不据此抹掉候选异常。未测真实输入到画面的端到端延迟；不盲改播放缓冲或降低同步频率。

- 底图摘要差异未解释；结构/物件局部像素一致不代表整图逐像素等价。其它模组自行创建的文字、每种Box生命周期并未穷尽实测。
- check02曾出现17px预测超时回跳，不部署；其四轮性能/视觉/敌人/火箭证据保留，不能改成check03指纹。
- performance-result03顺序错误被判输入不合格，报告保留；result04是补齐交替后的新结果。check03-perf02保留但不计入正确交替组。
- 首轮内存守卫停止后用户释放了内存；只清理自有实例。早期视觉驱动误用begin房、NPC过早变焦及截图编码等失败均保留。
- 旧motion18、快速播放追赶和缓存实验未晋升。A的新快捷键功能未自动移植。

## 工具与历史

- 本轮完整报告：`state/b-field8-merge-2026-10-28.md`。工具和最终性能/视觉摘要：`experimental/b-field8-validation/`。
- 构建：`tools/host_authority/field_driver/compile.py`；功能：`field2_driver/run.py`（实际双侧行走用textmotion，旧motion入口不可用）；性能：`field2_driver/bench_sustained.py`。复用runtime01与bench-20261025-01，不覆盖旧结果目录。
- 部署：`experimental/b-field8-validation/deploy.py`，准确五文件CAS/备份/回滚；当前版本后续部署需更新基线绑定，不能把field5约束直接套到field8安装。
- 旧field6/7源码阶段历史：`experimental/b-field-pipeline/`、`experimental/b-field-local-display/`，本轮已合入并验证；它们README中的“未测试”只代表当时状态。
- 旧field5详细验证：`state/b-scalar-optimization-2026-10-27.md`；功能修复历史：`state/b-field22-validation-2026-10-26.md`、`state/b-field-repair-2026-10-25.md`。旧“未来不运行”不再是当前任务限制。
