# RConnect — 开发记忆入口

## 1. 当前任务

A 为普通入口的双人联机；B 独立架构本轮不碰。根会话 `01a086bb-378c-7f60-b8e1-50d90ffa0996` 统一整合、编译、AIR测试及部署。
用户最新重点：删除“房间交接中”定制界面，双方加载达到相应原单人流程耗时，解决新房间不同步，并按git核对性能倒退。**10月24日用户明确要求先部署再继续，roomfix5已实际安装；大场景性能目标尚未完成。**
之前的高速弹丸/念力/掉落/击墙动画也尚未全修；不要用局部通过声称全部完成。本轮优先房间，不扩回B或无关视觉任务。

## 2. 玩法、授权和执行约束

- 普通房可分头；无人房暂停保留本次进度；剧情/挑战共同进入；宿主发起整图旅行，同入口。未换房者不应被另一个人的加载暂停。
- 掉落一份先到先得，经验共享，存档点共享解锁各存角色；安保破解共享/分别可选，切换保留已有权限。
- 跟随、共享菜单/SATS暂停、被队友念力抓、抛掷伤害、友伤默认关；WASD挣脱默认开。
- 所有RConnect会话可协调，根唯一部署。指定FA/RV/WB修正、LAD/CS测试协调已有授权；不能扩展成任意其他模组写入。A独立Sand加载兼容已授权；B的其他接口授权仍限B。WB首次初始化删除refreshView提案仍待答，不改WB、不以此阻止RC工作。
- 共享ModLoader game登记，JVM/AIR串行；子代理只做独立目录源码/审查。无实质新证据不跨会话发状态消息，不逐个要求停测。普通授权不重复确认。
- 唯一AIR ID、私有后台桌面、只读复制Littlepip29至测试槽9；不写真实存档、不关闭用户程序、不调用未点名Ghost。AIR写独立AppData需require_escalated；已授权测试范围内执行，不维护新护栏授权表。
- 启动余量：双6GiB/单3GiB/组件编译1GiB，运行512MiB保护，不降低。用户已答释放内存后继续，不重复提问。测试时读取当前余量，旧内存状态不是现在的结论。
- 10月24日上午用户允许测试前关闭 LAD、RV、CS：仅用官方启动器改隔离副本，正式选择不变。普通房必须重测同组合solo，不借历史大图基准。用户答会保存退出；其普通实例随后确实退出，不需再问。
- 省D盘，清自有可再建副本；保留失败、唯一证据及旧版。10月24日用户明确“先部署，再继续”，已依此提前安装roomfix5，不把未完成测试说成通过，也未降低后续性能目标。公网/多人/重连/其他版本不在本轮。

## 3. 实际安装与候选

正式RC：`0.2.24-roomfix5`，`release/RConnectMod.swf` SHA `78c052aea963f1689b705ae1e14d274916ae1a1f7e81933390caf8d1a88f4699`，195147B。
用户要求先部署后继续；回执`build/m52/recovery-room-user-deploy-01/deployment.json` SHA16EF10BA，22项仅RC变化；同目录备份DF0F/aura1。执行脚本原字节冻结deploy-executed.py（639166DB），随后维护源失败路径已加固但未重跑。安装后单实例smoke ed2fa23d99已通过：78C准确字节、14模组初始化、tick200及日志检查；installed-smoke.json SHA BCAD4048，独立副本已清理，仅启动资格。性能资格仍false。准确产品源/编译在recovery-room-production-05，不是历史src/dev版本。
此前aura1回执recovery-aura-offline-deploy-02，smoke7d45932e01及EB365备份保留；上一层574D见recovery-offline-deploy-01。房间修正本次首次交付，高速运动等尚未全交付。

12:39正式ModLoader另行更新为2050E023，启动smoke实际用了该新字节；旧性能证据仍是BD71不重标。新测试需另记telemetry.json存在/内容/隔离复制。post_deploy.py先前预检通过，但现在正确拒绝这项额外变化，不继续叠历史适配。

当前宿主A796：`a796827173af7d6fab9885fb66ecc62182ab5335918a30c7cce4c44914a238b7`，CS于10月24日上午从ABE2独立更新Grafon两处颜色方法，回执`mods/ContinuousScene/state/scene-tint-deployment-20261024.json`已verified。前一ABE2来自Camera.calc修正，旧回执`vertical-camera-band-deployment-20261023.json`。RV于15:17左右独立部署为BF4AC9CD (`bf4ac9cd87272b03fae7ec22ee67d045f037362f412ee801cad3f9ba9fe3afef`)，其会话回执effect-load-v3-output/deployment；此前0DBE为历史组合，其余CS7F1F/SandCEC6/WB14112等未变。旧80CF/ABE2/6DBA的历史不改写、不与新宿主耗时混算。

**房间对照候选roomfix4**：`build/m52/recovery-room-production-04`，SWF `34a17de66e9a89165b4bde75d22ec1dd3d4295bb496b903124687af80422b703`，195145B；prepared093916CF，compile3CDE928E。编译时80CF/0DBE，已完成实测ABE2/0DBE须分清。源配方`experimental/recovery-room-production-v4`。roomfix5为78C052，已按用户要求部署，真实遮罩/性能仍待验证。
来自准确aura1的11类房间修正：并行生成，未换房者不停，当前原房不自恢复，实际入口放置，绑定原生Land/Room交接与连续过门请求，READY观察标记去重、暂停时不耗跟随期限，原生加载素材与文本，地块完整标量表/准确绘制缓存。v4仅比v3删除RoomCodec每次同步文件诊断（候选误留，正式版无此日志）及改版本。房间生成/字段/伤害不删减。

诊断专用roomtime1：`recovery-room-loading-counter-product-02`和`recovery-room-loading-counter-driver-01`已编；来源`experimental/recovery-room-loading-counters`。只测首次grant及随后2帧9函数、14阶段标记、消息累计；原场景/断言不变，不能部署也不给净性能资格。product01因AS try/finally返回分析编译失败，原失败保留。

## 4. 最新实测与卡点

- **已安装版**78C/roomfix5 的当前全14组合三程双人7cadcc8267与单人fc4111c750均通过；双侧房间/入口/控制一致，但加入大图首入15.068、重访8.208秒，单人6.642/3.101，未达目标。原生“加载中”素材取代自定义交接UI；本轮没有再部署相同字节。
- **新首绘桥已完成并实跑**：6D/roomload1 + FBA27宿主 + Sand003（3E220）。原驱动384e92463c双41项通过，主10.152/2.545/5.588秒、加10.153/2.423/5.772；两次真实constructed/activated同票据，三程入口差1/0/1px。首入/重访总耗时明显减少，但主侧自身慢了，仍未达到单人速度，未部署。
- **单人退化风险仍在**：原基线三组6.642/1.732/3.101、7.448/2.103/3.021、7.028/1.901/3.154；新组合两组9.223/2.176/3.659、8.086/1.836/3.396秒。旧大图落点161.8,4320，新1161.8,4800，原生人口也不同；三组旧/两组新规律原因尚未解释，不能声称无回退或全是随机。RC离线未启early/改偏好/搬位，但新旧还含不同Sand，非单变量。详细回执见NATIVE.md。
- **真实四节点诊断通过**：02/cd917646ad为41原检查+20附加检查。授权前及完整恢复内没有地形绘制，绘制后才恢复控制，四块抽样身份保留；非全图仅一次、GPU或逐像素证明。01/9d81因观察器缓存roomKey取旧房失败，原失败保留，唯一修正roomKey(refs.loc)。driver02=4FC274，来源已冻。
- **2.4秒首次绘制长帧仍是主线**：cd917加入grant-after37483→first-raster-ready39881为2398ms，ready仅再1ms；当时exit0/fadingfalse，排除固定退出动画和ACK延迟。期间图块0→24/regionPass35→40；不能把全部CPU归Grafon，仍包括同帧视觉模组。World.step→cam→Grafon.sceneTick/sceneEnsure/sceneEnsureUpcoming/sceneFirstWindow为优先读点。busy会挡unitsync/地形等新包，玩家worldstate仍可处理，不能照搬旧14次unitsync归因。
- **两类循环候选也已测，不部署**：roomload2/FBFB8389，product loop-product-01，200069B；仅版本及NativeTileState/TerrainSync，79类不变，实际双Java编译通过。7852f0beae双41检查通过，主10.358/2.464/5.984、加10.414/2.301/5.979，整体未改善。terrain段省79/91ms，但grant→ready多683/719ms；落点/人口不同。52冻结及22正式输入未变，私有副本/PID已清。之前290e8bf987仅5.714GiB启动余量不足，无AIR，失败不改写。
- **资源状态以当下为准**：7852启动7.845、最低3.073GiB，69采样无压力/重叠停止。根本轮AIR/JVM均已结束；不要继续沿用17:48内存阻塞。编译/测试排队使用共享登记，不发无意义跨会话催促。
- **冻结协作已收紧**：配方编译后审查方擅改三文件触发预检拒绝；根保留unapplied-loop-builder-review.patch，再按原SHA恢复，SWF/源/编译回执没改。之后7852按准确冻结配方运行。冻结后只报告意见，根明确重开写范围前任何agent不得续改。

## 5. 已知问题和不能省略的语义

- Git已查：574D→EB365→DF0F房间/旅行/遮罩源码相同，旧加载修正当时没有交付；不是“已修又坏”。不能用局部候选或函数等价否认用户性能退化。准确报告见PERFORMANCE-REVIEW.md。
- 正式roomfix5首改共同旅行/普通分房/同入口/原生加载图，历史普通分房与背景门实际通过；新6D/FBA组合仍需普通分房、背景门和持续游玩最终回归。当前大图速度证据不授密集场景资格。
- shelf实变使原视图不可复用；WB14112也依赖该字段，不能忽略。首绘桥在完整checkpoint恢复后才允许真正绘制，避免重复栅格化。不能手工清isRebuild/isRecalc省必要水体/照明处理。
- NativeRoomState单位段含原生外来实体退休/重建，不是纯镜像创建；mapxml、脚本、武器、掉落引用不能凭U序号或150px位置复用。不能删字段/动画/伤害/完整状态换速度。
- 不整体丢弃worldstate/unitsync只留最新，里面包含冲击、武器、轮转地块等一次性事件。预采集最多可重叠约416ms，但READY前可靠地图奖励包仍会改世界，暂不新增复杂失效缓存。
- 小循环roomperf1没有真实整段收益；roomload2也没改善。MirrorMasks.capture实测29ms不是3秒主因，不做复杂全局索引。已部署单行mask优化仍待当前准确输入的8轮原生遮罩补测。
- A Sand003仅候选：允许共享加载冻结，缺桥或活动/回放走现有路径。正式CEC6不变；WB首次初始化删除refreshView提案无答复不动它。
- 高速弹丸、击墙、念力、掉落及持续性能目标仍未完全完成。真实用户Unit.run #1010在隔离Littlepip29未复现，不称已修。

## 6. 下一步入口

1. 正式仍78C/A796/CEC6，不重复部署或把未达标首绘桥替换安装。加载主线是首次可见区域生成/同帧视觉工作；只读审查正在确认最终入口确定前是否画了旧视口，以及同次drawLoc六层backobjs重复扫描。没有证据前不改渲染行为。
2. 准确首绘产物：build/m52/recovery-room-first-raster-product-01（6D）、recovery-room-first-raster-host-current-03（FBA27）、Sandevistan/build/out/a-travel-hold-20261022-003（3E220）。循环候选loop-product-01（FBFB）已经原驱动验证但无整体收益，勿盲目重跑。两组新solo也已完成，不能当作仍在跑。
3. 实机复用experimental/recovery-room-current-comparison/run.py，显式--product/--raster-host/--sandy-bridge/--mode；默认原scene-driver02与原run_coop_regression.py（7ECA）不改门槛。--diagnostic-driver只取阶段证据。每次新输出目录，原失败保留，当前输入变化必须准确记录。
4. 根唯一JVM/AIR；当前无根测试。最终候选须按当前实际组合取得大图/普通分房/背景门/密集证据再部署。用户允许隔离关LAD/RV/CS，但不同组合必须单独配原生solo，不混基准。

## 7. 详细记录

- 首绘实测总表与最新失败/收益边界：`experimental/recovery-room-first-raster-current/NATIVE.md`；当前桥源码与组件见同目录COMPONENTS/independent-review。循环配方目录冻结不可顺手维护，结果记NATIVE/state。
- 当前此前详细快照：`state/recovery-evidence-through-first-raster-2026-10-24.md`（归档中“正在进行”均按本快照为准）。
- 近期完整取证归档：`state/recovery-evidence-through-roomfix4-2026-10-24.md`；更早`state/recovery-evidence-through-offline-collector-2026-10-23.md`。
- 房间源/配方/测试准确绑定：`experimental/recovery-room-production-v4`、`experimental/recovery-room-repair-review`；旧检查器锁80CF，新`current_host_verifier.py`分别绑定旧构建和当前ABE2，不改历史回执。
- 现有正式候选发布：`experimental/recovery-room-production-v5/RELEASE.md`；旧aura发布说明保留。历史过程在journal顶部及各experimental/RESULTS；日志只追加，失败不改判。
