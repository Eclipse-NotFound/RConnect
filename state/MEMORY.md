# RConnect — 开发记忆入口

## 1. 模组与职责

Remains 1.02 双人合作模组，入口 release/RConnectMod.swf。A 是普通入口现用同步架构；B 是独立入口的主侧统一执行架构，两者并行。本会话 01a086bb-378c-7f60-b8e1-50d90ffa0996 统一验证和部署。当前已撤回motion2，沿574D基线统一处理A版加载、玩家念力光晕、击墙效果与高速运动四项；不恢复B。

## 2. 用户偏好与协作约定

- 中文通俗交流；目标是实际恢复操作达到单人对应流程耗时，不能只隐藏“房间交接中”。未换房玩家须继续正常运行，共同换图出生一致。
- 普通房分头，无人房暂停保留本次进度；剧情/挑战共同进入，宿主发起整图旅行。地上物品一份先到先得，经验双方奖励，存档点共同解锁各自保存。
- 跟随默认关；共享菜单/SATS暂停由宿主管理，默认关。被抓默认关、WASD挣脱开、抛掷伤害和友伤默认关。安保破解共享/分别开关默认共享，切换保留已获权限。
- B 双方有人房由主侧执行；共享时停，攻击伤害在结束回放结算。独立 TDFC/MSW/RV/Sandevistan 接口已授权，保持安装边界。
- 用户授权所有 RConnect 会话互通进度，由本会话统一验证和部署。FA 念力兼容已交回所有者；RV/WB 指定局部优化及 LAD/CS 测试部署时间协调已获准。未点名 Ghost，不使用。当前按客户端并行模式使用三个隔离子代理，普通跨会话进度不再反复广播。
- 仅管理自己的独立 AIR ID / 后台桌面 / 隔离存储，不关闭用户进程，不写真实存档。Littlepip29 只读复制到隔离槽9。
- 双实例启动可提交内存至少6GiB，单实例3GiB，运行中512MiB保护不降低。D盘节约，清理自己可重建运行副本，保留唯一失败证据。
- 10-20起测试统一使用 ModLoader 共享登记工具，整组双实例单次申请game。正常冲突自动等待，不再依赖人工独占窗口。中断必须查准进程和元数据再恢复登记。
- 本机验证及发布门禁通过后直接部署已有持续授权；未达目标或缺测试不部署。公网/重连/多人/其它游戏版本仍不在本轮。
- 10-21用户先选择保留候选，随后授权恢复实测；在获知密集性能门槛仍失败后明确“先部署现有版本”。后来用户实测报告无效和性能倒退并要求回退，现已撤回motion2；此例外不再用于后续部署。保留原性能失败及安装后冒烟的历史记录。

## 3. 当前安装与候选

- 已完成用户要求的回退，安装仍 **0.2.23-coop-bundle2 / 574d2b51490ae8b25a1396555600f56a301f8a20ae50104c0e35cf2796441afe**。回执 `build/m52/motion2-user-rollback-20261021-215647/rollback.json`；精确护栏授权已撤销，不再重做。宿主 BEFC，RV7852、CS7F1F；每轮冻结22项，历史不同组合不得混用。
- 准确 recovery13：`build/m52/recovery-13` / `1177eb1a…fddb1`，87AS。包含原版加载UI/首绘、念力光晕、击墙/气体/酸液与运动修正，但加载与密集性能仍失败，**未部署**。随机图首绘配套隔离宿主 `recovery-first-raster-host-03` / FD92；安装宿主未改。
- 新 recovery14：`build/m52/recovery-14` / `225a794040c71f2a55ff433366a7969201ac3a58ffaab0a655cee1e4eefbe5f7`，88AS，只在13叠墙痕专用编码及版本字符串。完整源码 `experimental/recovery-wall-encode-buildsrc`；其它85类原字节不变。4277cc066e同driver02密集仍失败：主29/0、加40/14；加入七段36–42帧、p95 306–405ms。原生高速6e154179bd完成8组，主63/0、加76/2，接触显示帧数及闪电95ms间隔未达标。
- 独立 recovery15：`build/m52/recovery-15` / `6fbb2d6cb8be8e454d875d7661714e2d879d8d92c1a96b8206f55e3e76ea1d72`，14仅叠武器姿态回退算术消重及版本。完整源码 `experimental/recovery-actor-pose-buildsrc`。e2ecb96939同场密集仍主29/0、加40/14失败，加入七段37–40帧、p95 339–395ms；没有足够整体改善，未部署。
- 独立 recovery16：`build/m52/recovery-16` / `a1519b39f27b6c073186a4581234de9bad656592ec6c17bb4a3eb494ade5a31c`，14仅叠真实大图墙面桥，89AS。独立 recovery17：`build/m52/recovery-17` / `a5d05ea89a5b689b44a0530832d288827d4f9261487fccad77af55c0be36673e`，14仅叠TerrainSync采集，88AS。两者已编译、互未合并，不含15；均未部署。
- 独立 recovery18：`build/m52/recovery-18` / `11b795d0d6681caa4edfcc2d1c0df73cb38f6d706a1fb3c26518163f738fe4d3`，准确16仅叠大图最后写色的原生反查表，90AS、完整69项组件通过。小房对应两处写色另有完整85项组件通过，尚未合入18。新候选均不替换574D。
- 活动 `experimental/recovery-integrated` 仍是13；14独立源码，勿用旧根src覆盖。新增正式 `prepare_recovery.py --source` 复用完整源码清单与编译流程，减少复制构建脚本；默认来源不变。
- 气体时钟诊断 `recovery-gas-clock-01` / `2142fe…b4759` 仅诊断，不是生产候选。原版13的3类插桩剥除后逐字节相同；输出 `recovery-gas-clock-native-01`。版本号相同不等于相同二进制。

## 4. 最近实际证据

- **加载**：13+FD92 双人96b09cd943主47/0、加36/0，三次出生完全一致。加入首进/基地/重访17356/2836/12868ms，单人f1e94fd2b0为7928/1960/4032ms（35/0）。真实按键另计三帧基线，不能仅隐藏UI便称达标。
- **普通分房**：外部提交观察器改为区分本机commit和对侧ACK；真实组件43/0，77afbadd8d主25/0、加53/0。原a542373a5f两条host误报保留。该78项功能通过不等于大图加载性能通过。
- **seed gate ON/OFF**：同字节驱动，准确13 ON c0df7677dd与只取消seed首绘gate的OFF7242e75f15，均在join首轮原1000ms无输入基线窗口失败，无法比较完整三轮。OFF候选49006c…7672；未放宽时限，原结果保留，正只读归因。
- **seed组件**：新共同on/off组件各108过/1失败，不能沿用早期109/0。新测试把旧epoch注入从等待首绘改成全部ACK后，暴露既有空travelId防重放边界；正常顺序TCP尚未证明可达。见 `experimental/recovery-seed-epoch-review`，不混进本次gate单变量实现。
- **密集走廊**：双方80本体/39演员武器/玩家与远端对象真实挂载。相同driver02，旧574D fc179988af主29/0、加40/14失败；13 6fa1e2589c主29/0、加39/15失败。加入每8秒约32–39帧，两者均未过原门槛。未据波动给改善百分比；该场地仍有128格地形轮转成本，与旧随机房不是同工作负载。
- **密集采样**：3b8269a9a7诊断主2689CPU样本，WallImpactVisuals.packed包含797（29.6%），实际开火期updates也占大头；不是只有初始快照。JSON分配表中的ReferenceError类名触发包装器正则误判，原失败未改。含调用关系的百分比不可相加或推算FPS。见 `experimental/recovery13-density-review`。
- **14密集采样**：a6a7e27789主2318样本、packed500，加入1259样本、tickFrozenAnims278/RV236/WB187，包含式计数不能相加或换算收益。确认武器位置先按旧回退计算再被clockSample覆盖的小冗余，正在独立等价修改；射击重启是原生所需，不删动画。RV以本体/命中代理两次处理同一vis属结构成本，不能移除命中代理或MirrorMasks规避。见 `recovery-join-animation-review`。
- **姿态小修正**：`recovery-actor-pose-fast-component-01`实际54/0，组件0316e899…753a2d，安装/输入未变；完整旧新类的边界调用、姿态和射击队列一致。已编译独立15并完成原生密集，仍失败，不把它称为整机性能改善。BinaryMessageCodec只读审查未找到安全且明确有益的微优化，停止重复尝试该方向。
- **大图弹痕实质缺口**：准确14只读Grafon.frontBmp，sceneLarge时它是scratch，真实显示另在sceneSurfaces的nativeBuffers[0]；解码还限1920×1000。既有210项普通枪火星原生记录全部largeScene=false，不能证明大图持久弹痕正确。`recovery-wall-surface-review`已查明坐标/绘制/重建路径；正在独立宿主局部绘制回调及真实大图反例，未改CS源码或安装版。
- **加载CPU采样失效**：825a566b2a再次在首轮加入侧1000ms基线失败，出现1597ms整帧空档。采样原始序号3→0、0 CPU、callbackDrains0，冻结collector拒绝非单调记录；`recovery-input-cpu-invalid-01`保存原JSON与无效说明，不作函数归因。不得把38项静态检查当作原生采样成功。
- **逐帧采样取得局部证据**：398cddcf6b仍首轮输入基线失败；逐帧driver C8D1…C456、profile F824…62F共345 CPU样本。窗0无CPU、窗1超原生枚举上限，无效；窗2/3完整、窗4为输入失败前有效半窗。collector核验通过但完整六窗/性能资格均false；扫描自身213/137/79ms也计入原失败，不能拿诊断时长替代普通运行。精确记录 `recovery-input-cpu-frames-partial-review-01`。
- **大图墙面桥组件/宿主**：完整实际组件54/0，`recovery-wall-surfaces-component-01` / 8D45…CBA8。新宿主ACC336…35DFD实际编译；原host-01回读因全局禁FFDec伪表达式失败，独立recheck证明两处都在与FD92完整相同的sceneDrawSteps，所有改动方法、首绘、7类、header/非代码tags/类表及22安装项通过。原失败保留于host-01，新证据为`recovery-wall-surfaces-host-recheck-01`，不是原生资格。现存1200墙格检查点上限未放宽。
- **大图真实负例已建立**：31d选点失败、df0零射击失败保留。driver04改原生背包/装备和测试使用门槛后，旧14/FD92的b4380cdb0a框架通过，四轮真实墙痕119/101/1466/1262像素，对侧均0。16/ACC的f80b01a647四轮墙痕已到达，但严格颜色仍差1/1/3/1像素；首次远端显示差值888/444/739/1063ms，没有性能资格。原PNG比较误拒保留，独立proof-review仅接受半透明截图表示转换，游戏uint比较仍严格，两轮四例都仍失败。
- **墙面颜色进一步定位**：原生roundtrip01诊断7/0，5个半透明差异由setPixel32/setVector/setPixels重复取整精确复现；另一个opaque差异尚未定因。猜测公式component01有6项失败，保留。实测反查表component02完整10/0、65536原生ARGB状态零误差（旧直写5886例变化）；只供最终像素写入的helper正在隔离18集成，未改线包/逻辑颜色、未部署。gutter/core先采顺序是剩余opaque问题的候选原因，暂无邻块同帧像素证明。
- **18实际大图颜色验证**：9927d091b8同driver04/ACC框架通过；独立严格uint复核四轮中0/1/3完全一致，case2两点仍错（world655,4465及654,4466，均opaque）。源实际变化109/68/1186/953像素；首显474/182/855/1892ms，没有性能资格。原PNG误拒记录保留，`recovery-wall-surfaces-native-proof-review/recovery18-reanalysis-01.json`只修截图表示校验。继续同帧core/gutter/真实wire的独立小范围诊断，禁止猜测改绿。
- **上述“首显”用词纠正**：原分析器first_frame找的是首次匹配最终源颜色，连续开火中不是首个墙痕。只读时序复核给出16实际首变888/444/739/237ms、18为474/182/855/253ms（相对native sourceFirst）；八轮都匹配当时或此前真实源色，不表示追平。18 round0观察空档536ms，round3为110ms，不作为纯网络延迟。原功能失败/最终色指标原样保留；见`recovery-wall-latency-review`。
- **gutter诊断01**：7855df2737框架和观测完整性通过，准确18/ACC；原两个点本轮没复现，唯一opaque错(651,4431)位于选定cell16,111之外，所以尚未定位根因。继续准备覆盖原验证crop的受限诊断，不凭正确点推断故障已修；该轮始终没有性能资格。
- **普通房同源写色问题**：`recovery-wall-small-color-component-01`实际85/0 / FF968…583B；完整旧类精确复现5例损失，新类只改WallImpactVisuals.put/replay两个最终setter，六色接收/回访及原69项全过，尚无完整游戏候选。
- **时停加载边界**：准确安装CEC6源AD931…4492D存在独立敌人补步和热键启动，World暂停不足以冻结。已在RConnect内准备A版独立hold接口22行+载体，闲置原子准入；B授权不复用，已一次向用户申请新A接口授权，尚待回复。无接口不得把早交付视为完整组合通过；未写其它模组。提案见`recovery-sandy-travel-hold-proposal`。
- **早交付组件**：最终切片gate20/0、room36/0、旧room回归109/0、准确World方法16/0、外部许可替身22/0、真实地形序列化14/0，共217项实际通过。external01的ASC尾返回编译失败与tile01的替身回调#1063保留。根审核修正无票据exit同步改onPause时序、整个World替换许可清理、controlOff抛错后的责任标记；未运行真实Sand接口或完整原生加载，不把旧109通过混同历史seed108/1边界修复。
- **早交付完整编译**：冻结handoff90c92be5…58b82，90AS的`recovery-early-compile-01`/10b24987…1fae6已编译；宿主`recovery-early-host-01`/2d415dd3…dd29已编译，原回读因init2局部声明提到函数首失败。独立recheck严格仅允许这一无提前读取的声明变形，4个反例拒绝、42/26方法及6代表类/头/非代码tag通过，原失败保留。没有真实加载资格，A Sand授权仍待回复；见recovery-early-host-review。
- **地形采集组件/原生**：`recovery-terrain-capture-component-01`实际154/0，B9B6…8BED。真实Tile无变化快速判断只比phis/hp，动态getter及其它路径不变。30,000格×5旧171/199ms、新113/114ms。17同driver02密集78a808f81c仍主29/0、加40/14，七段36–39帧、p95 295–424ms，未取得整体改善。场地/driver/安装相同但准备快照有一把枪hold12/0差异，严格input_comparable=false；不计算版本收益百分比。详见recovery17-native-01.json。
- **14高速复核**：case4数据提前到达，23ms是同一gameFrame两次RENDER（含22ms像素读回），下一真实帧晚80ms；确定失败为只有1个接触帧，不能断言提前删尾。case6闪电95ms空档前已有足够轨迹，缺的是中间最终游戏帧，不是缺下一位置包。详见 `recovery-flight14-review`，原阈值/失败均保持。
- **墙痕编码**：真实组件 `recovery-wall-encode-component-01` 49/0；82份历史自然数据像素/uint/旧格式、原子拒绝、预测ACK/毁墙/复访/批次界限通过。两次ABBA旧编码740/739/771/773ms，新475/499/510/517ms；冷解旧314/312/318/304，新290/280/277/282。只是独立完整类成本，原生频率和整机收益待验。第二次原生接触触发缓存失效没有直接组件断言，失效逻辑本身未改。
- **气体v2**：b15c17f816主37/0、加33/0及24PNG/JSON通过；严格轨迹13错：10条漏末姿态+3条派生一一对应错。9条漏1末采样、1条漏2；没有有序歧义或terminal收到前删除。源/线/显示四轮12/12/23/23。首轮80–158ms，旧4733dbf4b4秒级首显未再现，不归功于仅修夹具。见 `experimental/recovery-gas-v2-review`。
- **气体时钟诊断**：faf749b4fb四轮原生通过，24PNG/JSON通过，严格轨迹仍12错（8显示+4派生）；两侧诊断完整。首朵10:1实际对应remote id0，收到→显示116ms；末姿态80229已在最终RENDER出现，结束游标80300.9>end80267。先前误把它与失败id1混同，已纠正。id1实为10:2，其32ms末姿态区间被42ms的1.0x正常游标一步跨过，未提前删除；严格末姿态失败保留，不能为补帧延长原生寿命。诊断输出 `clock-diagnostic.json`，不作性能资格。
- 已有准确功能边界：03双向玩家被抓光晕777fe3bdcf完整16轮591项过并目检；05普通枪墙击4c2df11055共210项过，首显88ms；09酸液a5dc1bb2ee共92项过、24图定位/自然寿命过；11念力85、容器/SATS52、真实跳跃12过。最终14仍须统一回归，不能借祖先局部通过发布。
- 高速原生12的48e9ff1838仍闪电109ms>87ms失败，已收轨迹但无新游戏帧；不是全部由缺包解释。普通性能门槛保持，不用诊断FPS替代。

## 5. 已知问题与边界

- 四项目标统一看[当前清单](recovery-2026-10-21.md)。功能、实际画面、性能分开登记；最终同一候选必须复验，不用组件/握手关闭视觉问题。
- 历史motion2已撤回；room19、native-loading1、peer-aura1、wall-impact2等独立增量不按旧口头结论部署。没有回退其他模组，不声称整个下午的全部安装状态恢复。
- B195性能及血翼像素问题、旧独立motion1/Q07等仍未关闭；本轮不恢复B，不混用旧权限或版本。
- 早期明细已在统一清单/journal及git b783c4b的旧MEMORY；更早[快照](memory-before-room12-2026-10-20.md)只作历史。原失败和唯一截图不可删或改绿。

## 6. 下一步

1. 准确14/15密集仍失败，停止没有整体证据的小修正扩散。禁止跳动画/减同步频率换FPS。
2. 加载关键路径已确认宿主先绘、完整交付后加入侧再绘；仅延后加入侧首绘没有解决串行。独立early-travel方案已有217项组件与完整编译/独立回读，尚无原生资格。Sandevistan独立步进的准确版本已核查，A接口授权待回复；不能只凭World冻结就宣称全组合安全。详见recovery-loading-critical-path-review及recovery-early-host-review。
3. 18大图三轮精确通过、一轮opaque仍失败；下一步补覆盖实际差异的同帧gutter/core/wire判因。普通房85项修正待合并。只读delta审查确认直接脏像素包破坏预测后的快速补修和大图paintOrder，需独立权威基线，且快慢同tick可能双编码；未证收益，暂不实现。其它三个目标仍须最终候选统一回归。
4. 所有最终目标与门禁满足后才部署；目前继续保持574D。构建/测试共享登记串行，常规状态不广播外部会话。

## 7. 入口

- [统一修复记录](recovery-2026-10-21.md)、[日志](journal.md)、[加载原记录](room-loading-2026-10-19.md)。实验目录README和prepared/intent/results绑定精确代码与数据。
- Python `C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe`，加 `-B -X utf8`；Java `C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe`；SDK `mods/Sandevistan/build/tools/flexsdk`。PowerShell `login:false`。
- 构建 `tools/validation/prepare_recovery.py <新build/m52目录> --source <experimental完整源码目录> --version <版本> --build --registry-wait 900`。完整integration指纹必须匹配，输出不可覆盖。
- 组件 `tools/validation/run_recovery_component.py --source <组件源> --entry <入口.as> --expected N --output <新目录>`；专用自然数据组件沿其README适配，仍统一登记。
- 普通原生 `experimental/recovery-tests/run.py`；加载/密集独立入口见本轮对应README。每轮唯一AIR ID/后台桌面/冻结22项/内存门槛/只清自有副本。取消只写本轮cancel-request，经finally退出，不直接杀排队父进程。
