# RConnect B 开发入口

本会话按用户最新指令只负责 B。A 的当前状态见同目录 MEMORY.md；不要用 A 的最新源码或未获资格的 B195 替换 B 的冻结基线。

## 正在推进：第二轮实测反馈（2026-10-25，尚未部署）

### 2026-10-26 持续射击交接修订（晚于20:29）

- plan01 的 baseline01/candidate01 都在第二阶段准备超时；baseline02/candidate02未启动。准确诊断 `b-field22-sustained-readiness-01` 证明旧工具只查按钮松开，未等待输入保留的按下边沿被消费，下一阶段远端弹匣变为999。不是修改枪械逻辑来绕过失败。
- 新 `ab-sustained-003` source `1e4e640689e5269baab49b46e32c3592c568ac63550d18d4c9a83e587a7d3dc7` 等待双方停止开火时的序号之后有更新指令已执行；记录 `neutral-before-phase`，测量前检查，原测量不变。30项离线检查过，准确新计划 `experimental/b-field-sustained-bench/field22-plan-02.json`。
- 第一正式轮 `b-field22-sustained2-baseline-01` 正在运行，已实际通过阶段交接，不能提前称性能通过。复用 `b-field2-bench-20261025-01`，最新准备文件 `prepared-sustained-003.json`；001/002及旧失败保留。八项功能证据及field22产品没有变化，安装仍field3。

### 2026-10-26 20:29 最新进展

- **准确field22八组功能均通过，尚未部署**。除UI外使用`b-field22-final-02`/prepared-v15；UI改用`b-field22-ui-final-03`/prepared-v18，主77/加36通过。敌人内置实际124/117、文字20/34、地形130/75，旧失败种子也已通过。完整表和指纹见`state/b-field22-validation-2026-10-26.md`。
- 开锁取消已找到直接因果：`b-field22-ui-clock-02`完整时序显示测试工具绘图81ms、PNG压缩789ms，造成920ms回调空档及输入超时。v18只把同一帧图片编码移至场景结束；游戏500ms超时、原生交互、验收断言未改。不再把该测试干扰当作待修产品故障。
- 新持续射击工具25项离线检查通过。显式field22计划已冻结为`experimental/b-field-sustained-bench/field22-plan-01.json`；四轮`b-field22-sustained-baseline-01/candidate-01/baseline-02/candidate-02`正在按序执行，每阶段60秒，旧AB007失败保留。运行器复用既有副本，不增大包。
- 部署工具新增明确区分AB007/独立持续射击两类证据，5%/1.2/每10秒开火门槛不变，12项故障检查通过，仍未执行安装。须等待四轮真实资格后决定；导弹缓冲延迟和密集卡顿不能因功能通过而称全修。

### 2026-10-26 20:05 最新停点（以下旧轮记录保留作历史）

- 最新准确候选为 `build/ab/b190-field22-build`，source `76ab46b821032f8b1fc63b629a9052b54514220826baead874866ed78dea1d9c`，SWF `3706828fd10cf30c133826d17fd8cef939444f790a33a70d58c2a2b0779c90bf`；仍配native021。只在field21之上追加地形phX1/phX2/phY1/phY2，覆盖源/证据在`experimental/b-field-terrain-bounds-fix`；重建assemble参数加`--terrain-bounds`。
- 固定原失败seed2780491448复测`b-field22-terrain-seed-01`主130/加75全过。此前949像素差异来自格(28,23)Y1主930/加920；四边界补齐后开火前和真实破墙后PNG精确一致，17项原生组件检查每侧均过。不是只用另一随机图掩盖旧失败。
- `b-field22-final-01/ui`因外置read的exists/open之间遇到文件替换3003而失败。prepared-v15捕获此短暂缺失并将cases.input纳入原有异常归档；失败保留。`final-02`正在跑完整8场景，目前Q瞬移39/8、投掷物46/35、安保89/12、地形及rockets均过，敌人/文字待收尾。
- `final-02/ui`主76/1错、加34/0：实际按住E期间，主侧输入间隔537ms超过Commands固定500ms，计时动作被提前取消；目标仍锁定、剩余132/152，非完成。未放宽断言或改产品超时。已准备独立UI时序观察入口`field2_driver/ui_trace_run.py`，待套件结束后编译prepared-v16再诊断；当前源码新observer不等于已编译v15。
- rockets时序`experimental/b-field-clock-replay/field22-rockets-trace-01.json`有效配对735帧；包含弹丸事件12帧的收到至显示均值172.8ms，地形变化6帧236.3ms。非逐武器端到端延迟；没有改播放算法。此前field21仅tick0的10秒结果无效解释仍撤回。
- 独立持续射击工具`experimental/b-field-sustained-bench`及`bench_sustained.py`已编译ab-sustained-001，22项离线反例检查过，双10秒资格smoke通过。1000发测试弹匣每阶段一次准备，测量期间不补弹/清计时；原5%/重复1.2和每10秒实际射击门槛保留。未冻结/运行正式四轮，不代表性能通过。复用旧bench副本，另存prepared-sustained-001.json；重跑旧AB007前需准确恢复外置驱动。
- 用户两次明确授权本轮三源码精确护栏登记；自动审批先拒绝待授权记录，明确补充授权后放行。首执行因GBK读UTF8失败，修正编码后成功；两条短时授权均在finally撤销，未改护栏。共享测试旧PID复用阻塞已由拥有方核对释放，没有停系统进程。所有安装文件仍field3，A不动。

用户要求修复换房缩放、导弹/核弹及破墙延迟、NPC/伤害字抖动、开锁/破解进度条、绿框但Q瞬移失败、战斗/破墙卡顿，并补安保终端共享/分别破解与抓回队友投掷物。详见 `state/b-field2-repair-2026-10-25.md`。开发与测试从下述field9准确基线推进，安装版仍field3。

- 独立覆盖：`experimental/b-field-controls`、`b-field-ui-fixes`、`b-field-sync-fixes`、`b-field-security`。按同一field9三方差异合并，不能整文件互相覆盖。
- 当前合并候选 `build/ab/b190-field21-build`（field4）已编译；SWF `f4426b1a067611c89296a38b722c8ef65c86ff2e61cf2869fa48ca046460d581`，source `f8a63b52187efb3a9ec5a5e7d90a6455b9862839adefb09e6fa59d848c3b5ee1`。含安保接口，必须配准确 `build/ab/native-hooks-021/pfe.swf`。原生021完整字节保留审计通过，未晋升。field14后增加上一屏投掷物选择校验和两行文字矩阵插值修正；field21再修正原生Box的非整数指向优先级，不能将field20证据重标为21。准确合并用assemble.py --security --grab-selection。
- 新外置驱动 `tools/host_authority/field2_driver`，一个重复使用的隔离运行副本 `build/ab/b-field2-runtime-01`，准备版本随测试变化；精确runner/preparation记录在每次result中。
- 基准已复现：`b-field2-ui-baseline-01` host65过/12错（缩放），join32过/4错（进度条），6次真实走门与两种计时交互均完成。文字8项双侧全过，尚不能证明抖动根因。
- `b-field2-rockets-baseline-02` 基准双侧导弹/野火核弹原生像素及战斗检查通过（内置主78/加82）；正确性不等于无延迟。
- 候选 `b-field2-ui-fixed14-01` 主77/加36全过：6次实际走门缩放保持、两类进度条取消/完成均通过。`b-field2-fixed14-01/darkteleport` 主39/加8全过：自己视野允许才可Q传送，只有主侧看得到时拒绝，实体阻挡仍生效。旧版对照确实复现两向错误。候选rockets双侧通过。
- 首轮controls因驱动写private teleReady失败，已删除该赋值；首轮terrain误将弹孔探针的默认lmg/plam/prism换为mlau/bel，已恢复，失败保留。不是将这两轮认作产品通过。
- `b-field2-fixed14-02/terrain` 原弹孔/烧痕/耐久回归主93/加105全过；真正墙死增量路径仍待live验收。
- **文字根因已复现并修正**：TextField.x/y与matrix.tx/ty有差别，PoseTween错误用前者覆盖后者。旧版实际资产5项最大偏差3.9/3/6px；field20 `b-field2-fixed20-01/textmotion` 主20/加34全过，5项插值最大误差0，446帧最终RENDER采样无屏幕反跳、文字位置误差<0.05px。
- field20 controls主36过1错/加25过2错：加入侧酸弹真实抓取成功，普通手雷首次准备未互等（未出现pick记录），hover采样时序不对；正在修订外置夹具，不能判全过。security真实前两组双向终端/240tick炮塔战斗已过，但测试阶段消息先发后补字段导致join1010；terrainlive未开火即遇驱动moveTo3012。所有失败保留；工具已修3012重试及单次完整阶段发布，待prepared-v10。
- motion18已单独编译实测，主32过2错/加8过；身体/武器等价未过且实际更慢，真实visualBullet等价过但27ms→32ms。**已放弃，不进产品**。时钟恢复离线试验也未进产品，真实时序采样待继续。
- 仍需真实破墙增量/耗时、实际文字抖动及密集性能对照。未完成验收前不能部署。

### 22:55 接续（field21未部署）

- field20 controls-02主38/加27全过：普通/酸弹双向实际抓回、扔回、到期和原归属通过。
- field21-final-01使用prepared-v11：security主89/加12全过，四组原生终端解锁/激活及240tick炮塔战斗；darkteleport主39/加8全过。
- 同套terrainlive真射击/爆破和双方碰撞一致、普通墙死避免整房重画均通过，但10项区域像素对照失败，开火前即差异。已加四张有界裁图及周边格信息，待新准备版本定位；不降低断言。
- 同套ui只有host的tip1取消观测时机失败，join无失败；需区分测试时序和产品，不宣称全过。套件在darkteleport后明确停止，已让出其它会话测试窗口。controls/rockets/enemies/textmotion最终21尚未执行。
- 原定四轮性能在进行：baseline02有效，candidate21-01加入密集均值/P95分别约+13.46%/+19.28%；baseline03运行器完成但持续射击资格失败（某10秒窗口0发）。candidate21-02按原计划运行，不能筛选有利轮或降低门槛。正式安装仍field3。
- 无产品时钟优化：离线恢复改法出现新增下溢负例，已拒绝。下一轮rockets只读真实包到达/确认/呈现时序再分析。

### 23:25 接续（产品仍field21，未部署）

- `b-field21-final-02`（prepared-v12）controls主46/加35通过，新增真实容器/门/终端非整数优先级也通过；rockets原生主83/加87和外置双10通过。套件在rockets后显式停止，让性能诊断及其它会话使用登记占用。enemies/textmotion仍待最终21验证。
- terrainlive新轮主109/加54通过，四张小范围PNG两侧精确相同；但随机种子1963887932不同于原失败2780491448，不能关闭旧失败。原失败固定seed回放提案已接入外置源、待prepared-v13编译；新增diagnostic_only参数，仍按完整区域精确对照。静态查到bounds/门邻接轮廓/后续tint三个同步缺口，尚未归因或改产品。
- UI v12因新增测试错误访问不存在的PlayerActor.ack而中断（主71/1、加22/1超时），失败保留。已改为host.inputs[id].consumed并逐项核对新增访问，修订BUiCases摘要36c118de；准备v13重测。对方超时前的手动停止尝试因已完成检查被拒绝，实际未手动停进程。
- 四轮性能正式报告field21-qualification-01.json明确qualified=false：baseline03装弹跨10秒导致0发射，四轮重复耗时接近翻倍。未换样本/降门槛。已运行紧邻两轮原AB007 --profile并只读CPU采样（profile-baseline-01、candidate-01）；两轮runner都通过、采样无错误，仍只诊断，不能作净性能资格。分析待续。
- rockets首次时序采样只有tick0一次房间载入，WeaponProbe随后替换confirmed回调使采样停止；10242ms不是火箭延迟。修订分析明确场景覆盖不足；v13外置源改为等原探针装好回调后再链入，并在stop当时冻结footer状态，旧证据保留。
- v13编译通过前不能运行新准备。运行器增加终态失败及时归档；当前无field suite继续，原runner冻结副本仍在各结果中。B玩家入口仍field3，A无修改。

用户随后要求检查A新增功能：只读核对见 `state/b-review-a-features-2026-10-25.md`。明确B尚缺安保共享/分别策略与联机快捷键自定义；队友投掷物抓回、地图标记须另验，未自动开始移植。A的Q视野传送、nativeui2仍未安装。

### 23:49 接续（field22源已组装，尚未编译）

- 固定seed2780491448的`b-field21-terrain-seed-01`准确复现旧基线949像素差异。格(28,23)的实际边界主侧Y1=930、加入侧920，原生绘制依赖此值而旧TILE表未传。只在SceneSnapshot.TILE末尾追加phX1/phX2/phY1/phY2；覆盖源、原始截图证据及17项真实原生组件检查在`experimental/b-field-terrain-bounds-fix`。不改门、色调、native021或旧字段索引。
- 最新组装源`build/ab/b190-field22-source`，重建参数`assemble.py --security --grab-selection --terrain-bounds`。产品22编译和prepared-v14外置驱动编译暂被其它会话中断登记阻塞；v14已等待超时，未生成。共享登记原测试PID被系统进程复用，负责会话正在处理；不停止系统进程、不绕过登记。待放行后先跑原seed，再做准确22八个核心场景。
- 两轮profile诊断及CPU只读采样见`experimental/b-field-perf-qualification/PROFILE-FINDINGS.md`。主capture.units约34ms、加replica.units约19ms是已测热点；多数队列为0，不能把延迟解释为大量积压。诊断不授净性能资格。正在设计独立连续射击负载，避免旧90发装弹跨10秒窗口；旧失败和原5%/重复1.2门槛保留，尚未跑新负载。

## 当前实际安装

- 玩家入口仍为 `build/ab/b3-playable-190/Player-1.cmd` 与 `Player-2.cmd`。
- **已安装 B3-0.1-field3**，SWF `fbaaea1b9f9da4514d0cbedff43403ed53fc694198ddd0e917980c7d922a1acd`，准确构建 `build/ab/b190-field9-build`。
- 部署回执 `build/ab/b190-field3-deploy-20261025-01/deployment.json` 已 verified；同目录 before 保存原 startup2 和包清单。启动器、AIR存档ID、配置与原生接口组合保留。
- 旧基线 `build/ab/b190-startup2-build` / `2c536b5d` 保留，B195 未晋升。详见 `state/b-field-repair-2026-10-25.md`。

## 本轮问题与当前证据（2026-10-25）

用户报告双侧卡顿、加入侧没有交互提示、关闭跟随后走到出口没有反应。

- 原 B 实际走出横向出口复现 `Unit.run #1010`。原生移动在请求换房后继续用旧房格子检测越界坐标；已在等待帧尾换房期间将位置保留在旧房边界内，换房仍原子提交。
- 加入侧显示对象缺少原生交互对象及鼠标指向更新。已为容器和掉落建立只读原生提示，保留主侧执行交互；不在加入侧再开箱或拾取。
- 性能采样显示主要成本在主侧画面状态采集、加入侧复制呈现。已减少重复矩阵/颜色数组、字段类型检查、指向候选去重、血条布局及普通字段写入。四轮对照主侧每帧耗时减少约 8%–10%；加入侧普通场景略好、密集场景基本持平，不能说已解决加入密集卡顿。

## 源码与验证

- 持久覆盖源：`experimental/b190-field-fixes/src`，只覆盖 startup2 的 9 个产品文件。
- 功能已验但性能未过：`build/ab/b190-field6-build`，SWF `71d873f16eb84a7967b7be08b61c3159a558943fa069169a6a6efcac7521fdca`；临时版本名 B3-0.1-field1。
- 测试工具：`tools/host_authority/field_driver`。
- `build/ab/b-field-regression6-01/boundary`：25 项通过；双方真实走出/返回，另一人留原房，加入侧确认新房。
- 同轮 `hover`：20 项通过；锁定/解锁提示、加入侧实际开箱、真实掉落提示及移开鼠标清除。截图已目视检查。
- 上述均含独立参考语义比较：160 组视觉状态和 192 组字段状态，涵盖编码解码及旧快照不可变。
- 同轮 `enemies` 失败保留：新外置驱动误在旧档安全基地执行战斗，而原生基地禁止开火。prepared-v8 改为原探针的新角色/random_mane，并停用该场景的外部按键注入。随后 `b-field-enemies-baseline-v8-01` 与 `b-field-enemies-fixed6-v8-01` 原 B/候选分别都通过主 119、加 112 项；包括原生识别、轻机枪实际伤害、14 阶段身体/血条/武器/护盾/死亡图像核对。
- 四轮 60 秒对照已完成（baseline-02/03、fixed6-01/02），实际敌人数/附着、双方耗弹与发射一致、每十秒窗口持续开火均核对。主侧密集平均 94.18→85.89ms、P95 134.5→126ms；加入密集平均 62.44→66.12ms、P95 95→104ms，低密度加入 P95 57→61ms。重复比均≤1.2，但未达到本轮≤5%退步门槛，`b-field-performance-fixed6.json` 明确 false。没有部署，也没有放宽门槛。
- `b-field-profile-detail6-01` 诊断：80 敌人加入 replica.units 11.68ms/确认，其中字段应用 5.58ms、原生 pose 3.02ms；指向提示仅 0.25ms/本机帧。诊断字节 fielddiag 不可部署。
- field7 / B3-0.1-field2：增加 NativeFields.apply 固定公开属性存在性缓存；数值仍每次写入，动态/访问器/未知字段仍走原检查。`profile-fixed7-01` 密集 replica.units 11.02→10.19ms/确认，仅诊断而非净帧率资格；`hover-fixed7-v9-01` 主13/加11通过。
- **当前安装 field9 / B3-0.1-field3**：固定普通存储字段比较实时值后避免重复写入，仍恢复本地修改；动态字段、设置器、NaN、正负零保持原行为。field8 是构建过但未运行的中间稿，静态发现正负零需特殊保留后转 field9，没有把 field8 算通过。
- 准确编译 `build/ab/b190-field9-build`：SWF `fbaaea1b9f9da4514d0cbedff43403ed53fc694198ddd0e917980c7d922a1acd`，source `461dc13d8295eb7c3578e0a19da83aea8b83a9d3d20cdacfe2b61a0f01ff9a61`。prepared-v10 增加设置器与正负零检查。
- `b-field-regression9-01` 三项均过：boundary33、hover28、enemies外置20及内部主119/加112；截图已查看，准入脚本准确字节/日志/原运行组合检查通过。新驱动与 v8 原B敌人基准的整个游戏场景/输入/连接代码等同，差别仅新增字段契约检查。
- 新同时段四轮 60 秒对照已完成：baseline9-02 → fixed9-01 → baseline9-03 → fixed9-02；`b-field-performance-fixed9.json` 的实际敌人数/附着、耗弹与发射、持续开火、准确字节、≤5%退步及≤1.2重复比检查均过。加入密集平均65.23→66.14ms，P95 104→105.5ms，属于基本持平，未宣传为改善。
- 部署后从实际 B 玩家文件另跑 `b-field-installed-smoke-01`：主21/加12通过，实际走门和自身控制正常，无FATAL，运行文件不变；随后 finalize 已核验并完成。
- 部署工具已完成 install 与 finalize；准确候选功能回归、性能无明显退步、备份、部署后复验均已落实。

后续重点：加入侧密集呈现与解码开销仍高；本轮只是局部优化。维持当前已部署修复，继续优化前从 field9 准确源开始，不混入 A 或 B195。保留所有失败，不降同步频率或删减战斗/动画来换速度。三个大测试副本已完整归档并回收，净释放938,069,625字节；索引见详细记录。
