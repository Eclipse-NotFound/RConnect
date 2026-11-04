# RConnect B 开发入口

## 2026-11-04 当前 B：fast1 已部署（本轮核心结论是「证伪」）

- **已安装 `B3-0.1-fast1`**：体 `9f60d9e6df1a053c5dea72127dc9eee87f815d2a043845cb3c9e5952449bad89`（251,953B），源 `7b682a0145a115ceb20c69467605614888e25597df87f6819b20c6bc3e3432b2`，候选 `build/ab/b-fast1-03`，源覆盖 `experimental/b-fast-prediction-20261104/source-01`（145 份）+ `source-manifest.json`。事务 `experimental/b-fast-prediction-20261104/deployment.json` verified；A 体仍 `8ab94c8b`，根/DLC witness 未变，`launch-b.cmd check` exit 0。双方需重启。
- **同字节功能回归通过**：`build/ab/b-fast1-test-textmotion-08` 主 **109/0**、加 **122/0**，complete、runtime unchanged、无 FATAL，计数与 entry1 基线完全相同；插值率 86/104。**未有 ABAB 性能证据**（本窗口被他会话长期占机）。
- **保留的三项改动**：①`MovementPrediction` 预测窗口 100ms/3 步 → 150ms/5 步（冻结阈值 150ms 不动）；②删 `SceneSnapshot` 层扫描里结果从未使用的 `getQualifiedClassName`；③HUD 固定标签改为仅 role 变化时赋值。
- **本轮证伪两条，不要重试**：
  - **播放头不能限速**。`PlaybackClock` 的 `position=max(position,target)` 是延迟最优解：探针 `lag=lastFrame.time-clock.position` 历史 90–218ms，改成「+25% 限速追赶」后恶化到 **456–597ms**，`queued` 到 8–11，`delay` 长期顶 250ms。**加入侧数值延迟就等于 `clock.delay`**，任何给播放头减速的做法都会等量加延迟。
  - **150ms 预测冻结是契约不是参数**。改 200ms 会让 `BPredictChecks` 双侧各 13 项失败。
- **下一步只剩一个真方向**：主侧发布耗时。80 敌 `host.publish` 32–34ms（`capture.units` 18ms / 每单位 282 字段 + 整棵姿态树；`capture.tiles` 3.4ms 全房 39 字段扫描；`delta` 2.8、`send` 2.5）+ `simulate` 16–17ms。把发布间隔压到 33ms 以内，65ms 基准缓冲才够用，延迟与卡顿才会同时下降。`FrameDelta.decode` 大包尖峰（41–49ms）次之，属协议层。
- 详细证据/复现/模型脚本：`experimental/b-fast-prediction-20261104/README.md`（§1 有 30+ 次运行的 PLAYBACK 对照表）、`simulate_clock.py`。

## 2026-11-01 前一版 B：entry1（已被 11-04 fast1 取代）

- 用户反馈点击创建房间无反应，要求入口易找并继续优化卡顿。已部署 `B3-0.1-entry1`：体 `3b58198e6e11ef32cf12f6499b75d7a4497788cb668680aa637057b30311644c`，源 `1223ba92c2e514c21a15eb2a700529ac20ced9b189ff5689093fb752fb0d338d`，候选 `build/ab/b-entry-smooth-01`。游戏根 `RConnect-B.cmd` 可选单开/双开，另有两个直接入口；旧 Player 入口同样可用，存档身份保留，需重启旧窗口生效。
- 处理前轮审查的三个行为风险：移动物件有效字段插值、稀疏字段删除、尸体缓存失效；位置派生改为按需弱缓存，减少解码全扫分配与重复房间采集。开房/加入立即显示状态，未载入角色时等待/可取消，端口占用失败可重试。旧入口低权限标签属已确认风险，未证明是用户当时无反应的唯一原因。
- 同字节实机：ui 主136/加91，textmotion 109/122，enemies 内部124/117，均0失败/FATAL；另覆盖128帧稀疏增删/历史不可变及127次物件插值。四轮同环境60秒对照通过：80敌加入 mean 46.38→43.88ms（−5.4%）、P95 82→74ms（−9.8%）；主侧87.76→84.34ms。场景/依赖不变，CS/RV/LAD仍关，A未改。
- 部署回执 `build/ab/b-entry-deploy-20261101-01` verified；入口 .NET 校验兼容补丁 `b-entry-deploy-20261101-launcher-02` verified，助手 check 与根菜单 Q 退出均通过，不启动真实玩家测试。两个事务含逐项备份。完整145份父源+8文件覆盖归档于 `experimental/b-entry-smooth-20261101/`，已恢复并核对源身份；详细证据与复现入口见其中 README。
- **卡顿未消除**：密集播放等待约196–202ms；轻场景末尾仍有307ms、文字移动夹具静止首间隔536ms。未改预测/播放时钟；下一步针对供帧/缓冲与偶发长帧定位，不将平均帧间隔称为输入延迟。原审查记录保留于 `b-iteration-review-2026-11-01.md`；以下旧版本段落为历史证据。

## 职责和约定

只负责 B：加入侧发送输入，主侧执行两名玩家和双方房间，加入侧重现确认状态。A 由另一会话负责；不混入未合格B195或A源码。A入口见MEMORY.md。所有RConnect开发会话允许协调；其它模组只按已有独立接口授权工作。

普通房可分头，无人房暂停保留本次进度；整图由主侧发起，剧情/挑战共同进入。先到先得掉落、共享奖励、角色各自保存。TDFC/MSW/RV/Sandevistan用已授权B独立桥。已允许通过本机门禁后直接部署，不重复确认。

测试登记后在自有后台桌面、独立AIR身份和复制种子中运行；不碰真实存档、不关闭玩家程序、不调用未点名Ghost。双实例启动物理余量6GiB、单实例3GiB、运行512MiB，另有可提交内存保护。复用隔离目录，保留失败和唯一证据，不复制整套游戏耗费D盘。

## 2026-10-29 战斗卡顿调查（只读，未部署；用户要求不改模组本体/A）

- 用户重复反馈“加入侧相对主侧相当严重卡顿，战斗时两侧都卡”。本轮只调查/测试并给方案；**未改正式 release/可玩包 SWF/产品源，未部署，未改 A**（仅隔离 benchmark 副本按测试脚本常规流程替换为候选）。
- 既有受控证据（clean-05 四轮 60 s）**不支持“加入侧 Stage 帧率显著差于主侧”**：80 敌人主侧均值 63.70–75.52 ms、加入 41.48–47.63 ms；>100 ms 长帧主 11–55、加 1–13。但 8→80 两侧都显著退化（主 +59%～+91%、加 +24%～+39%），且加入侧有密集播放等待 162–168 ms、欠帧 22/60 s、起始静止 292 ms、镜头 1–2 px 回摆——体感问题不能由平均帧解释。
- 分项（smooth01 插桩 30 s）：主 `host.publish` 32–34 ms/帧（采集 21–23：单位 17–18.5，字段 8.5–9.3、姿态 9.9–12.1、瓦片 3.3–3.5；编码/发送 2.8+2.5）；加 `present` 17.4–18.8（render 13–14、tween 4.3–4.6）、每消息 decode 5.7–6.1（3.3–3.9/帧）、replica 应用 6.2–7.1（单位 5.9–6.7）。分项来自 smooth01，安装 smooth04 密集加入约快 5.4%，只作量级。
- 根因排序：R1 主侧逐单位全量采集 → tick/publish 率下降 → 播放缓冲放大；R2 加入侧每确认帧完整重放（未利用 FrameDelta 分支身份）；R3 每帧 tween/render/prune/pointer/SharedVision 全扫；R4 尸体/空 clip 爆炸辅助弹丸/未变单位仍采集重放；R5 同 tick 对象链最多 6 次遍历与每帧分配；R6 收包/AMF3/边界 flush 突发；R7 战斗破墙 `drawLoc` 风险（未测）。
- A 对照已纠偏（`a-inventory.md`）：用户点名的显示树/差异编码/接收游标/血条 compact/伤害数字模板/根 pose/显示房过滤**是 B field6/7 已有机制，不是 A 普通入口**；A 真正可借的是无显示记录退休、轨迹复用、地形栅格复用等。不要用 A 的记录泄漏直推 B 的 FPS。
- 早期 AIR 私有桌面确实失败（`0xC0000142`），后环境恢复；已取得 `b-perfdiag-run-06`（30s）与 `b-perfdiag-run-07`（60s，带包统计）两批逐帧数据，失败回执保留。
- 交付：`state/b-perf-optimization-plan-2026-10-29.md`（方案/阶段/验收/风险）；审计与证据表在 `experimental/b-perf-investigation-20261029/`。**未部署，未宣称卡顿已修复。**
- Stage 1 候选 v2 `build/ab/b-stage1-02/RConnectMod.swf` `77d4f837…f9a1`（源 `build/ab/b-stage1-source-01`，相对 smooth04 只改 5 文件+新增 `ClassNames`）：类名弱缓存、去 full 帧重复 `NativeFields.capture(room)`、replay 标志外提、空 clip 辅助弹丸结束事件不重放、不可见 label 去重。**未部署。**
- v1 `796ec224…` 含“玩家插值 motion”已实测失败（join FATAL `Interpolated pose has no confirmed native child`），撤销；v2 复测 textmotion 111/124、ui 134/91、rockets 57/57 通过，0 fatal、runtime unchanged。
- v2 ABAB（`b-stage1-clean-01`，30s×2×ABAB）无可分离稳定收益：8敌主约+4%、80敌主+1.7%、8敌加持平、80敌加约−2.3%但基线自身波动14.7%。**只有功能资格，不晋升、不部署。** 剩余 Stage 2 大项（采集分级/脏路径/突发预算）未做。
- 解码包级诊断 `b-perfdiag-run-07`（60s）：加 80 敌 mean decode 3.09ms/帧、wire 0.65ms，但长帧 decode 41–49ms（包 6.3–13.3KB、full=0、1–2 消息），AMF3 仅 1–3ms → **FrameDelta 分支克隆是主因**，与 282 字段/整 pose 树克隆规模相关；其次 ready=2（103ms）与 tween 50ms/GC。优先级改为 **H5 字段裁剪 + J11 decode/clone > J8 突发**；主侧长帧仍为 publish/capture/GC。
- J11 稀疏字段解码 **已部署（2026-10-31）**：`build/ab/b-j11-03/RConnectMod.swf` `6d540c20…f842`（源 `b-j11-source-01`，source `37a4d17a…dea5`），旧体备份 `b-j11-deploy-20261031-01/before`；功能与两轮 ABAB 见上，合并约 −12% 加入 mean。
- J12 未变字段跳过 **已部署（2026-10-31，覆盖 J11 安装体）**：`build/ab/b-j12-01/RConnectMod.swf` `7c2cc412…47a`（源 `b-j12-source-01`，source `03db4c49…bb1c`），装到 B 可玩包；J11 体 `6d540c20…` 备份在 `b-j12-deploy-20261031-01/before/`，A 体 `69060487…` 未动。安装后 manual `a3a0c301…c7b0`、README `96ab5a7c…ad8e`、validation `477d379a…c1c5`，README/validation 标注 +J11+J12。功能同字节 textmotion 104/117、rockets 50/50、terrainlive 178/123、enemies 50/50、loading 68/62、ui 127/84，均 0 failed。ABAB：J12 vs J11 两轮加入80 36.77/36.13 与 40.29/34.86 vs 42.49/39.58 与 38.62/38.98（合并约 −7% mean、−11% P95）；J12 vs smooth04 基线 `b-j12-total-01` 加入80 34.13/33.84 vs 39.79/39.18（约 −14% mean、−18% P95）；主侧基本持平/噪声内，轻负载持平。
- P1+P3 小幅优化 **已部署（2026-11-01，覆盖 J12 安装体）**：组合候选 `build/ab/b-p13-01/RConnectMod.swf` `014a7ad8…328`（源 `b-p13-source-01` = J12 + P1 稳定尸体跳过 + P3 未变姿态/血条/blit 跳过），部署事务 `b-p13-deploy-20261101-01`；旧 J12 体备份在同事务 `before/`，A 体未动。同字节 textmotion 104/117、rockets 50/50、terrainlive 178/123、enemies 50/50、loading 68/62、ui 127/84 全通过。ABAB vs J12：join80 41.34/41.81 vs 42.43/40.90（噪声内不可分离）；作为小幅优化按用户指示部署，不宣称独立 5% 收益。
- P0 B 专用渲染地形缓存 **已部署（2026-11-01，覆盖 P1/P3 安装体）**：源 `build/ab/b-p0-source-01`，安装体 `build/ab/b-p0-06/RConnectMod.swf` `a382e94f…8386`（source `ec5945be…58d7`），部署事务 `b-p0-deploy-20261101-01`；旧 P13 体 `014a7ad8…` 备份在同事务 `before/`，A 体 `69060487…` 未动。新增 `TerrainBitmapCache`（最多 2 个房间的 front/back/back2/voda/sats 渲染面 + 轮廓/边框变换缓存，背景 `VisualPose.recipeEqual` 结构比较）；`ReplicaScene` 换房先恢复缓存，未命中才 `drawLoc`；**只有房间切换写缓存**，同房重绘不承担克隆。功能：textmotion 104/117、rockets 50/50、terrainlive 178/123、enemies 50/50、loading 68/62、ui 127/84、boundary 61/52 全通过。性能：重复房间恢复 **8–13ms** vs 未命中 `drawLoc` **143–538ms**，首次克隆 **6–141ms**；P0 vs P13 两轮 60s ABAB 加入80 合并 mean **42.59 vs 43.04ms（约−2.9%）**、P95 **70.25 vs 74.5ms（约−5.7%）**，主侧/轻负载噪声内。内存：loading 配对采样 join 稳定私有内存 **1341MB vs 1306MB（约+35MB）**，两房间渲染面理论上限约 76MB。security host 原生失败与 baseline 相同；版本串仍 smooth1。
- 负向/未晋升切口（均有回执）：J13 姿态/血条记录跳过 join 仅约 −2.5%，不晋升；J14 隔帧瓦片扫描触发 `BTerrainBoundsChecks` 失败，撤销；J15 尸体采集缓存导致 enemies join 13 项失败，撤销；J16 多确认限流反而 join80 约 +2.9%，撤销；J17 插值记录跳过 join80 约 +0.5%，撤销；J18 动画帧缓存导致 enemies join 1 项视觉断言失败，撤销；J19 多确认帧跳过插值 join80 持平且尾部较好，但 enemies host 123/1 失败，撤销；S1/S2 字段裁剪均无稳定收益，不部署。
- 真实战斗/端到端近似验证：`enemies` 原生敌人场景 J12 50/50 通过；J12 vs J11 同驱动分项（非 ABAB）join present 9.48 vs 9.86、render 4.00 vs 4.27、replica.units 1.34 vs 1.47、decode 0.74 vs 0.69，host 基本持平；外部 UI 驱动增加 `wallLatencyMs`（控制发布→join 可见状态），J12 两轮 372/371、160/167ms，J11 对照 290/322、190/165ms；`BGrabCases` 增加 host 输入注入→join 可见弹丸墙钟延迟，J12 360/450/323ms、J11 348/295ms。样本少/地图不同，不能当收益结论，但链路已可观测且无异常停顿。完整输入→屏幕延迟夹具仍缺。
- S1 字段裁剪（J11 之上）候选 `build/ab/b-j11s1-01` `33ac70ea…ca8`（源 `b-j11s1-source-01`）：非玩家 scene unit 排除 40 个 host AI/物理/音效字段。textmotion 104/117、enemies 50/50、rockets 50/50 通过；terrainlive host 124/2（native 玩家启动死亡超时，join 123/0），loading/ui 未跑。ABAB 两次不一致：`b-j11s1-clean-01` 方向偏好 S1，`b-j11s1-confirm-02` 方向偏好 J11（host 80 67.96/65.02 vs 61.70/60.52），`b-j11s1-total-01` vs baseline 环境波动大；**未达到稳定的部署标准，不部署，不并入本轮**。字段键数约 −18–20%，保留探索切口；后续需低负载重复。

## 当前版本与接续（2026-10-29）

**最新已安装：B3-0.1-smooth1 + J11 + J12 + P1/P3 + P0 渲染地形缓存，原B190入口不变，双方重启后生效。** 安装体 `a382e94f66fa22e008c1a056871a6634bdf4915e1e84a9b2b9a3de0347818386`，source `ec5945be3f642135994b95873ff511c46b6d5e7f675385188d6655dcfe4558d7`，候选 `build/ab/b-p0-06`，源 `build/ab/b-p0-source-01`；部署回执 `build/ab/b-p0-deploy-20261101-01/deployment.json`。旧 P13 体 `014a7ad8…` 备份在同事务 `before/`，A 体 `69060487…` 未动。**版本串仍是 smooth1（未 bump）；安装字节与测试字节完全一致。** P0 主收益是重复房间地形恢复（8–13ms vs 143–538ms）；80 敌 ABAB mean 约−2.9%、P95约−5.7%，内存配对实测 join 约+35MB。

- 准确04字节功能：textmotion02主111/加124，ui02主134/加91，rockets02主57/加57，共574个外置断言通过；火箭/核弹双方实际发射与伤害、4阶段2030个显示样本无缺失/姿态/像素错。统一准备 `prepared-smooth-06.json` / `06d5414eeac2ec9a6c965b7f32b1e0fc209102dc3fe4d9c55c519a133412749e`；亲自检查进度条截图可见。
- `b-smooth-clean-05/qualification-01.json`：同环境无插桩ABAB、8/80敌人各60秒、原5%平均/P95与重复1.2门槛通过。密集加入44.321→41.921ms（约5.4%），主66.580→65.579ms（约1.5%）；轻负载主慢约1.5%，加入基本不变。03的收益不代替04；详细机器/缓冲记录保留。
- **卡顿仍未完全解决**：加入静止阶段首个间隔292ms，左右步行仍有1–2px镜头回摆；密集播放等待均值仍约162–168ms。轻负载欠帧计数候选6/10、基线5/5，候选有1个空缓冲样本。性能门槛通过不等于所有输入延迟消失；未修改预测与播放时钟。
- 部署事务 `build/ab/b-smooth-deploy-20261029-01` verified，仅主体及3个说明/清单文件，139个其它包文件/入口及根/A见证保留，旧4文件备份在before。沿用同字节功能证据并回读部署，未重复启动安装实例。无配置/存档/宿主写入，默认环境和马蹄铁开关沿用clientenv1；全部自有测试已结束。
- 新manual SHA `eaaf54bb5ca21463673d8a503642e5b176f336b9ed0b6606cb514fce6d39ab8f`；事务SHA `8731fd181756feb25e1e1a06823f09b1bc483be63eb4c8ca61be86fad1d24996`。后续晋升必须绑定这个新基线，不能原样重用本轮固定clientenv1的release.py。方案、失败、证据和回退入口见 `experimental/b-smooth-20261029/README.md`。

前一轮改善加入侧卡顿、同步 B 默认模组环境（CS/RV/LAD 关、其余默认）、增加马蹄铁经验共享开关。**`B3-0.1-clientenv1` 已安装并验收**，原 B190 两个 Player 入口保留；事务 `build/ab/b-clientenv-deploy-20261029-03` 为 verified。已有持续部署授权，无待用户批准事项；该轮自有测试已结束。

- 准确主体 `build/ab/b-clientenv-bridge-07-build`：SWF `c953c0684ca716b2641c88f13e514275d5f2cc8e3387d9ade50d7ab8bd1fc5a0`；source `5854ef397c1e96cf24d8b637f32cdc24589502d91fe86cce892a3189b75041dd`。完整可恢复源 `experimental/b-field-client-integration/source-07`，144份总源/18份覆盖。不要从陈旧顶层 src 继续，旧 integrate.py 不能代替 source-07。
- 新原生 PI `3b1b77d3f6de08e5b31bb03883da6900b3656e497a4749305133019d0377ed83`；FA04、Addiction、TDFC/Sandy/PI 独立桥及默认资源均由 overlay-03 的23文件清单固定。启用11项，CS/RV/LAD和旧ModSettings关闭。原生26方法移植回读通过，无关5686方法保留。
- 马蹄铁共享默认开，由宿主在设置中控制，仅影响之后地图马蹄铁的额外共享。关时只有拾取者获得，不改变击杀/任务奖励。双方服药、伤势、武器配件独立；退出前完整应用已确认但仍在播放缓冲中的结果，避免旧库存带回。
- 同环境 ABAB 通过原5%平均/P95、重复1.2门槛：8/80敌人各60秒，持续轻机枪，无分项插桩。仅两缓存差异的密集加入平均41.024→39.522ms，主侧63.658→61.795ms；普通加入基本不变、普通主侧慢约1.4%。资格 `build/ab/b-clientenv-comparison-01/qualification-01.json`；不能把早期跨环境差异当缓存收益。
- 实机通过：addiction-04 89/82、injury-03 78/66、attachments-01 107/86、loading-01 68/62、full-horseshoe-02 108/65、textmotion-01 104/117、visualfield-01 80/73、timecontrol-01 50/50（主/加）。准备06/07/08各自冻结，完整索引 `experimental/b-field-client-integration/functional-evidence.json`。
- 视觉复核：29组确认，63背景对象逐组对应，58对医疗箱/终端显示树与素材一致，116次影子层序正确、10同缩放屏幕取样一致；16次气泡出生/变焦比例通过。已亲自看双方截图；front/back整体位图摘要仍不同，不称整图逐像素一致。
- **卡顿和镜头跳动尚未完全解决。** textmotion加入侧向右/左移动出现反向样本，最大24/2px；开火两阶段未出现反向。静止期最大299ms。两缓存不改变预测算法，补充无缓存诊断也见1–2px回摆，但其准备清单大小写重复键导致运行文件核验未通过，不能冒充合格对照。下一步应分开确认供帧、预测校正和镜头，保留这些异常，不能用通过断言覆盖。
- 安装32目标逐项备份/CAS，115个不相关包文件和原入口身份保留；只重置两个 B 身份已偏离默认的 Sandy/WB 设置，不清存档和联机偏好。before 保存 loadfix1 精确回滚内容；根/A前后见证完全一致。安装字节 `installed-ui-02` 主127/加84通过，真实门/独立换房/镜头缩放/开锁及破解进度复验，已 finalize。
- `installed-ui-01` 的一项失败已查明是测试临时派生开锁属性被成瘾模组每15步的原生重算覆盖。仅修外置角色布置为真实技能20及螺丝刀，保留真实按键/计时/成功判定，补充重算后资格稳定断言；未改产品或放宽结果。准确安装准备 `prepared-clientenv-installed-02.json` SHA `a2f0f881994a017cb526c86b40a40a3c256f41fc7e4581f7583cb8238bd7880b`。
- 新安装 manual SHA `18ece1be58d84452c884663ea6ab9b5fff89bd45762b950560027deb8636c070`；事务SHA `341cfcb21129d3a73fb0ee8d0c3f64d75db59e103ec3a1c31e16f28f0bfef4e0`。后续改版须绑定新基线，不原样重用本次固定loadfix1事务入口。精简回执 `experimental/b-field-client-integration/deployment-summary.json`。

用户此前精确护栏授权已执行并撤销。后续补充对照准备的 JSON 写入被本地二进制路径规则拒绝，未重新登记授权、未换工具绕过；只读分析和已通过的部署流程不受影响。原失败和旧事务均保留。源码已有86cadaa/2ec068e，本轮工具、环境锁和结果另行本地提交；不纳入其他 A/recovery 文件。详情 `state/b-clientenv-progress-2026-10-29.md`。

## 前一安装历史（2026-10-28，载入修复）

用户报告安保终端 `Security terminal stepped without an occupant`，主侧停留 Loading、加入侧已有地图。已确认原生 `Location.preStep` 在无玩家的新房运行30步，被B误判；错误界面使后续World步进停止。只调整 SecurityTerminals 在无房内玩家时先返回原版步进，延后个人状态建档，不改破解规则、调度或协议。

**前一版 B3-0.1-field8-loadfix1，安装字节双人复验通过，事务 verified；当前版本以上方为准。**

- 新构建：`build/ab/b190-field8-loadfix1-build`；SWF `92ea5ec83aa1ab5a412581ba80ebbc49b16fb93a01c180df239b88a4f59b1af7`；source `ac5e9d6e62c35e937deeb254f13c6371d8940f23a0f42f82e578b5006ea65d81`。native021、revision5不变。
- 事务：`build/ab/b-field-deploy-20261028-loadfix-01/deployment.json`，before保留准确field8五文件。原B190启动入口、AIR身份、配置和存档保留。已经卡住的双方需重启并重新读档。
- 来源：`experimental/b-field-loadfix/` 两份源码覆盖+固定父包；restore-source已重建完整142份且指纹一致。不要从旧工作src继续，不改冻结产物。
- 测试准备 `prepared-loadfix-03.json`：SHA `9a822144f5492a6be31b4d9103b5e73007911334d9198fdf3b011da3c47298d9`。loading-02主20/加14通过：无人房30步、首次状态、3次地图往返、报错种子1288542690的3个终端、宿主Loading关闭及控制恢复、加入确认。security-01主89/加12通过：真实破解、个人权限与炮塔伤害。准确目录均为 `build/ab/b-field-loadfix-*`。
- loading-01因测试布置缺少空房显示服务停止，失败保留；只修外部工具。测试默认静音，不影响玩家窗口。没有新增性能实测或改善承诺。
- 安装字节复验 `build/ab/b-field-loadfix-installed-ui-01` 主77/加36通过，包含交互进度、门与独立换房；运行文件未变，事务已 finalize。原安装5文件及根/A见证通过，所有自有测试进程结束。
- 当前安装manual SHA：`cccc90f4cf31bf97ec229467d62050a4d180f2a12d37dbbd3b432d17118a6581`。后续prepare/deploy需绑定此新基线；本轮脚本固定旧field8用于本事务，不能原样再次晋升。
- 详细记录：`state/b-loading-fix-2026-10-28.md`。后续仍需处理field8密集供帧与延迟；本次仅修加载故障。

## 父版本 field8 合并与安装历史（2026-10-28）

用户要求合并部署积累代码，修复移动卡顿、加入侧医疗箱/终端颜色异常、基地背景物件缺失错位、NPC文字过大。此明确部署请求取代前轮“仅源码、不做实验”。

**此前安装 B3-0.1-field8 / check03，安装字节双侧UI复验通过，事务verified；当前版本以上方载入修复为准。**

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
