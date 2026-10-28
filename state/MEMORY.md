# RConnect — 开发记忆入口

## 1. 当前任务

A 为普通入口的双人联机；B 独立架构本轮不碰。根会话 `01a086bb-378c-7f60-b8e1-50d90ffa0996` 统一整合、编译、AIR测试及部署。
**10月28日晚最新A交付（animfix3）**：用户六项视觉反馈已做窄修并部署 `0.2.24-animfix3` / `eb6d11e6f20068f76d44d180bc5f579c14ba359caa46e4706d0506b0d4abc127`。准确全源 `build/m52/visual2-combined-04/src`，Git全源副本 `experimental/a-visual-round2/validated-src`；回执 `build/m52/visual2-deploy-5c955c7f/deployment.json` verified，旧F14A备份同目录。门开关误碎片、话语缺失、抛掷原生数字、敌人武器翻转/近战停顿已获对应实证；特殊弹已收轨迹内平滑，火焰重复343/454→0，近战翻转6/6、高频历史减至2–4帧。**普通枪弹仍伴随整帧停顿，coexist时序混合，不能声称全部卡顿或性能无回退。** 只改RC，宿主/配置/存档和B不改。自有测试均结束，运行副本已清理。详细六项状态、失败记录、验证复用与遗留见 `state/a-visual-feedback-repair-2026-10-28.md`。双方需重启。

**10月28日前一轮A交付（animfix2，已由上述版本替代）**：用户明确本次自己操作与远端弹道均卡来自A。Git核对已定位10月25日 `fa91de7` 扩大了无视觉爆炸辅助对象的联机记录泄漏，真实7次爆炸／56对象旧版停火后残留56，新版归零；同时避免完整轨迹重复合并。准确全源 `build/m52/a-stutter-repair-02/src`，已部署 `0.2.24-animfix2` / `f14a44e74ac98ec480875203d4d714acfbc496141980e5a1d7b0de0c7ad222fb`；回执 `build/m52/a-stutter-deploy-a3a3e26e/deployment.json` verified，旧2C49备份在同目录。仅RC改变，宿主/配置/玩家存档不改。仍不能宣称所有操作／弹道卡顿或总体性能已解决。详见 `state/a-stutter-investigation-2026-10-28.md`。

上一轮animfix2验证边界：driver02早期input主侧仍在原生复活，动作资格已撤回并保留失败；07da后半两个持续开火阶段独立逐点核实双方实际横向197–211px、纵向114–126px、res0、117/121和61/61发且远端弹丸显示，因此只复用这些有效阶段与9655519e55爆炸生命周期作窄修部署依据。新driver04已编译，feac0dd1d2排队10分钟暂缓、未启动AIR，不能称新驱动已实测；所有根AIR/JVM已结束，没有继续排队。旧性能单轮不授稳定收益。
此前主线（本轮未完成）：删除“房间交接中”定制界面，双方加载达到相应原单人流程耗时，解决新房间不同步，并按git核对性能倒退。**10月24日用户明确要求先部署再继续，roomfix5已实际安装；大场景性能目标尚未完成。**
用户现已建立持续目标：首次场景加载、双向远端角色/念力运动、加入侧本机尤其跳跃掉帧，三项都继续。之前高速弹丸/掉落/击墙动画也尚未全修；不要用局部通过声称全部完成，不扩回B或无关功能。当前三项证据与停点见 `state/three-performance-goals-2026-10-25.md`。

**10月25日晚历史交付**：斜楼梯静止在远端跑动、加入侧敌人/炮塔开火弹道及死亡卡顿、加入侧破门窗在主侧缺碎片。当时A为 `0.2.24-animfix1` / `2c49dfd05d524085ea43fb8ffa537d1a9359febd52fb13d6a19faae6e2563621`，宿主A796不变。准确全源 `build/m52/a-live-animation-product-04/src`，窄补丁与可重建配方 `experimental/a-live-animation-repair/`；不要用陈旧工作src。安装后原生键盘斜梯双人691c5ccdb4通过，回执 `build/m52/a-live-animation-deploy-01/verified.json`。仅RConnect验证，真实存档/正式名单不改。当轮get_goal实际为null，没有创建/恢复旧目标。旧加载/原生UI候选仍保留，本轮未合入。结论和边界见 `state/animation-repair-2026-10-25.md`，10月28日的新回归证据优先于旧局部结论。

## 2. 玩法、授权和执行约束

- 普通房可分头；无人房暂停保留本次进度；剧情/挑战共同进入；宿主发起整图旅行，同入口。未换房者不应被另一个人的加载暂停。
- 掉落一份先到先得，经验共享，存档点共享解锁各存角色；安保破解共享/分别可选，切换保留已有权限。
- 跟随、共享菜单/SATS暂停、被队友念力抓、抛掷伤害、友伤默认关；WASD挣脱默认开。
- 所有RConnect会话可协调，根唯一部署。指定FA/RV/WB修正、LAD/CS测试协调已有授权；不能扩展成任意其他模组写入。A独立Sand加载兼容已授权；B的其他接口授权仍限B。WB首次初始化删除refreshView提案仍待答，不改WB、不以此阻止RC工作。
- 共享ModLoader game登记，JVM/AIR串行；子代理只做独立目录源码/审查。无实质新证据不跨会话发状态消息，不逐个要求停测。普通授权不重复确认。
- 唯一AIR ID、私有后台桌面、只读复制Littlepip29至测试槽9；不写真实存档、不关闭用户程序、不调用未点名Ghost。AIR写独立AppData需require_escalated；已授权测试范围内执行，不维护新护栏授权表。
- 10月27日现行规则：使用 ModLoader TEST-RESOURCES 的实际资源快照和进程策略；玩家与隔离测试可同时运行，默认静音。旧双6GiB/单3GiB和一律退出玩家游戏的约束不再作为本会话额外门槛；性能对照标明环境，不能把coexist样本当干净排名。仍不关闭用户程序或篡改结果。
- 10月24日上午用户允许测试前关闭 LAD、RV、CS：仅用官方启动器改隔离副本，正式选择不变。普通房必须重测同组合solo，不借历史大图基准。用户答会保存退出；其普通实例随后确实退出，不需再问。
- **10月25日16:23用户进一步明确后续只测联机模组本身**：性能主线改为仅启用RConnect的隔离副本，对照同组合单/双；正式名单保持。已启动灯具图像轮收尾后不再追加LAD性能轮，候选及证据保留。三项目标仍继续，避免把其它模组开销归入联机。
- 省D盘，清自有可再建副本；保留失败、唯一证据及旧版。10月24日用户明确“先部署，再继续”，已依此提前安装roomfix5，不把未完成测试说成通过，也未降低后续性能目标。公网/多人/重连/其他版本不在本轮。

## 3. 实际安装与候选

**10月28日实测宿主**：`4e5fab45d6f5a2634c83be5e7eaf387443f9fb4e56b945cd2bf54880f1f73c75`，本轮aa7/07da/965冻结副本及F14A部署前后均相同。本会话未修改宿主；下方A796是旧环境，不重标历史证据。

**独立 B 会话补充（2026-10-25）**：本会话只负责B，独立记忆入口 `state/B-MEMORY.md`。原 `build/ab/b3-playable-190` 已更新为 `B3-0.1-field3` / SWF `fbaaea1b`，准确源 `b190-field9-build`；修复普通出口无反应和加入侧原生交互提示，减少重复采集与显示计算。功能 boundary33、hover28、敌人主119/加112，部署后实际文件33项均过；四轮对照主侧平均帧耗时改善8–10%，加入密集基本持平、仍未解决卡顿。原Player-1/2、存档ID及冻结原生组合保留，A安装未改，B195未晋升。回执 `build/ab/b190-field3-deploy-20261025-01/deployment.json` 已verified；详情和回滚见 `state/b-field-repair-2026-10-25.md`。自有AIR/JVM均结束，三个运行副本完整归档后净回收938,069,625字节；A后续占用以共享登记和当时进程为准。

正式RC：`0.2.24-animfix3`，SHA `eb6d11e6f20068f76d44d180bc5f579c14ba359caa46e4706d0506b0d4abc127`。旧F14A备份见本轮visual2-deploy-5c955c7f回执。本次来源、行为证据和回退见第一节。上一版animfix1为2C49/196402B，旧回执a-live-animation-deploy-01及78C备份保留。下面roomfix5及更早记录是历史，不代表当前安装。
用户要求先部署后继续；回执`build/m52/recovery-room-user-deploy-01/deployment.json` SHA16EF10BA，22项仅RC变化；同目录备份DF0F/aura1。执行脚本原字节冻结deploy-executed.py（639166DB），随后维护源失败路径已加固但未重跑。安装后单实例smoke ed2fa23d99已通过：78C准确字节、14模组初始化、tick200及日志检查；installed-smoke.json SHA BCAD4048，独立副本已清理，仅启动资格。性能资格仍false。准确产品源/编译在recovery-room-production-05，不是历史src/dev版本。
此前aura1回执recovery-aura-offline-deploy-02，smoke7d45932e01及EB365备份保留；上一层574D见recovery-offline-deploy-01。房间修正本次首次交付，高速运动等尚未全交付。

12:39正式ModLoader另行更新为2050E023，启动smoke实际用了该新字节；旧性能证据仍是BD71不重标。新测试需另记telemetry.json存在/内容/隔离复制。post_deploy.py先前预检通过，但现在正确拒绝这项额外变化，不继续叠历史适配。

历史10月24日至25日宿主A796：`a796827173af7d6fab9885fb66ecc62182ab5335918a30c7cce4c44914a238b7`，CS于10月24日上午从ABE2独立更新Grafon两处颜色方法，回执`mods/ContinuousScene/state/scene-tint-deployment-20261024.json`已verified。前一ABE2来自Camera.calc修正，旧回执`vertical-camera-band-deployment-20261023.json`。RV于15:17左右独立部署为BF4AC9CD (`bf4ac9cd87272b03fae7ec22ee67d045f037362f412ee801cad3f9ba9fe3afef`)，其会话回执effect-load-v3-output/deployment；此前0DBE为历史组合，其余CS7F1F/SandCEC6/WB14112等未变。旧80CF/ABE2/6DBA的历史不改写、不与新宿主耗时混算。

**10月25日02:39:37 RV再次独立部署**：正式RV现为 `638e2d408e2cf46683c41114f75773829a1b4417d74bffe9d08855a4fe343710` / v0.33.10-render-cache，回执 `mods/RealisticVision/state/deployment-v03310-2026-10-25.md`。根随后实际核22项仅此一项从BF4A改变，RC78C/宿主A796未改。上文截至02:37的原生测量与host03构建仍属BF4A，不能重标或将新RV速度计入RC收益。原生UI已编译产物可保留，但旧探针验证器强绑历史安装，下一测试入口须准确区分编译时与运行时环境；不伪造installed()、改旧回执或无谓重编宿主。

**房间对照候选roomfix4**：`build/m52/recovery-room-production-04`，SWF `34a17de66e9a89165b4bde75d22ec1dd3d4295bb496b903124687af80422b703`，195145B；prepared093916CF，compile3CDE928E。编译时80CF/0DBE，已完成实测ABE2/0DBE须分清。源配方`experimental/recovery-room-production-v4`。roomfix5为78C052，已按用户要求部署，真实遮罩/性能仍待验证。
来自准确aura1的11类房间修正：并行生成，未换房者不停，当前原房不自恢复，实际入口放置，绑定原生Land/Room交接与连续过门请求，READY观察标记去重、暂停时不耗跟随期限，原生加载素材与文本，地块完整标量表/准确绘制缓存。v4仅比v3删除RoomCodec每次同步文件诊断（候选误留，正式版无此日志）及改版本。房间生成/字段/伤害不删减。

诊断专用roomtime1：`recovery-room-loading-counter-product-02`和`recovery-room-loading-counter-driver-01`已编；来源`experimental/recovery-room-loading-counters`。只测首次grant及随后2帧9函数、14阶段标记、消息累计；原场景/断言不变，不能部署也不给净性能资格。product01因AS try/finally返回分析编译失败，原失败保留。

## 4. 最新实测与卡点

- **18:21整合候选实测结束，未部署**：`goal-native-ui-jump-product-01`，版本`0.2.24-nativeui2`，5325A3AAEFF65E215D8E01CD6EF5F87FEEA362CE422CE3B93B35A038A5CB4930，195167B；prepared E19BBF8E / compile F764786B。仅原生UI与正常跳跃补帧，77个原类不变、82最终类，配2DB0宿主。新驱动1640137C，加载5045b51c6f原35+双方11通过；jump da4b846568双6、held fffba1414c主43/加42通过，实际仅RC，22安装不变且副本已清。功能通过不授性能或部署资格。
- **加载仍有疑点**：5325首入主4585/加4985ms，相同入口9C前轮3966/3989ms；加入侧restore63→471ms，effects→redraw5→399ms且未复用地形。9C补轮54722首入4396/4408ms，但入口不同，不能消除差异或归为噪声。源码地形复用逻辑逐字相同；具体拒因未取得。详见`state/nativeui2-loading-review-2026-10-25.md`（929DF00E）。
- **整合运动证据保留差别**：held四程拟合100/90/90/100ms，移动段重复位置均0/79，双方约30fps、无>100ms绘制间隔；jump远端身体重复主71/347、加67/346，明显优于78C的194/347、141/350，但差于52D单独轮49/349、46/346；保留一次103ms加入侧长帧。52D/5325相关三类及Session/RoomSync完全相同，2DB0未发现正常游玩热路径新增跳跃调用，原因仍不明。详见`state/nativeui2-motion-2026-10-25.md`（2DF5C9FE）；不宣称全部运动修复。
- **仅诊断已编译，未运行**：`goal-terrain-reuse-diagnostic-product-01`，677644650C93EC7A5CD481E3FF5245ACEF6BB807D15C2C90B15DF4C7DA2C13CB，197430B；两条编译exit0，源/22安装不变，根verify通过。仅5325两类加首拒因日志，其他80类不变，保留原短路/调用次数/返回；独立源码窄审通过。公开版本沿nativeui2以复用驱动，但独立SHA、DIAGNOSTIC_ONLY，不得部署或作净性能对照。`experimental/goal-terrain-reuse-diagnostic/run.py` 5423DACE只读预检已过，真实绑定6776/1640/2DB0；新运行接线尚未独立审查，暂停后未启动AIR。
- **onlyRC运动两臂已完成**：78C跳跃75ac、念力2673bc6f78；52D跳跃13b3f522be、念力3fb602435d，原双6及43/42、实际双SOL仅RC全部通过，副本回收。正常跳跃远端身体不变帧主194/347→49/349、加141/350→46/346，原地与跑跳均改善，本机仍约30fps；52D加入侧保留一次106ms长帧。念力四程拟合78C为80/100/80/90ms，52D为90/90/90/90ms；52D有一次38ms重复位置，其余移动段0重复，双方无>100ms绘制间隔。不授所有运动/密集战斗或性能统计收益。详见`state/only-rconnect-jump-2026-10-25.md`、`state/only-rconnect-motion-2026-10-25.md`。

- **onlyRC加载四格均完成**：908DF505驱动；78C solo e6e8045625三程6968/3701/3801ms、dual25735bd74f主4549/857/894、加4608/934/979；9C/2DB0 solo6afc7b40c1为7031/3737/3798、dual58d295cd42主3966/857/931、加3989/949/1017。原业务及各自UI检查通过，实际requested=ok仅RC、err空，22安装不变、副本已清。solo/dual淡出路径与首入口不同，不以dual较短授达到单人水平资格。准确分析见`experimental/goal-rconnect-only-loading/SOLO-AND-DUAL-BASELINE-ANALYSIS.md`。

- **16:43 onlyRC首轮已实际完成**：`goal-rconnect-only-motion-jump-baseline-01`/75ac7b113b准确78C/A796，双方MainFE SOL的requested=ok仅RConnectMod，含ModLoaderMod在内其余13项未加载。原18秒/6+6全通过，local ENTER主30.003/加29.998fps、RENDER29.999/29.992fps；ENTER峰81/85ms、RENDER97/99ms，均无>100ms长帧。该普通基地/冻结背景AI窗未重现本机掉帧，不授全部战斗或运动已修复。源/22安装不变，自有29516/40280及副本回收，result3C787D00。host远端源戳均67.665ms（约14.78Hz）；join混合消息534条/166非递增，需按真实路由分析，不能简单丢同戳。当前无根AIR/JVM。

- **onlyRC入口已冻结并实际使用**：motion `experimental/goal-rconnect-only-motion`，48AC6762/selector2BBE601D/清单782D19B8，复用原9EE/FEF，支持78C/52D双人jump/held，单人不支持。loading `experimental/goal-rconnect-only-loading`，build09EDAF5A/run8272C4DC、源2B836F00/运行C32CFE9F，唯一driver908DF505；原三程23+12或solo11、UI9C双人11观察，baseline/solo只8通用并保留11原始结果。用户性能主线仅RC，LAD候选不加入；入口不重新编译或修改原断言。

- **16:49发送节拍窄查**：准确Session14AAC9是50ms Timer，每回调客户端直接发PLAYERSTATE，没有玩家last=now阈值。75ac的267包seq连续，约67.665ms源戳/67.658ms到包，无缺号；主侧WORLDSTATE同时由Timer与收到客户端包触发。加入534包含166同源戳、无倒退，367正间隔均48.951ms，不能把含零平均33.705ms称有效30Hz。RemoteMotion已对同戳替末点不重置时钟；完整包仍有装备/生命/念力/弹丸及世界数据，不能仅按玩家时间戳丢掉。未新增调度候选，先完成onlyRC基准。

- 原生UI候选9C85/2DB0已通过普通三程35+双方11及12轮背景门主121/加157，未部署；正式78C仍是自制背景+原生素材副本。分房专用新探针记录被用户明确暂缓，不偷偷恢复。
- 跳跃身体补帧候选52D已编，72组件、真实双向中间帧与共享抓取回归通过；全模组帧率先15后19，不能授稳定收益。旧motionclock1、v2、探索noop、自身快照裁剪未获稳定整体收益，不重复盲测或合并。
- LAD候选8A127/宿主7B3首普通房快速分支已由准确源码+日志确认，35+双方11及双方8图像检查通过，10对原生PNG像素全等；并非加载速度达标。首轮实际RENDER等待跨度主5659→5223ms、加5633→5668ms，入口/人口不同；cover计数会漏长帧，不可当实际显示时间。候选未部署，用户改为onlyRC后不再追加LAD性能轮。
- 历史逐轮失败、精确授权执行/撤销、清理与已结束进程全部保留在 `state/memory-through-only-rc-jump-2026-10-25.md` 和 journal；归档中的“正在运行/待批准/阻塞”均是当时状态，不能覆盖本节。此前连续磁盘阻塞已解除，goal当前active。

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

1. 当前F14A窄修已部署并回读核实；若继续总体卡顿，优先取密集敌人／尸体和持续房间实战的发送、接收、显示耗时，不盲加播放时钟补丁。driver04已修双方开场控制就绪但未实测，后续使用时先核实际动作。不能重标旧input失败或把普通晚段当密集场景。共享登记照常，不逐条打断其他会话。
2. 后续若继续此前加载主线，先核对6776/1640/2DB0的旧78C基线与当前2C49差别，再审查诊断接线、查真实地形复用首拒因；不改写旧准入/安装回执。onlyRC、22项核验和共享登记不变。缺日志/faultCount非零不算取得原因。
3. 保留52D→5325普通jump重复帧增多的疑点；源码未找到解释，不归为噪声。不重复已完成的四格基准及组合功能轮来凑通过次数；新增测量必须回答具体原因。
4. 此前加载、原生UI/跳跃整合疑点仍未完成。后续部署应以实际F14A/4E5F为基线保留本轮修正，不把旧候选直接覆盖新版；正式玩家名单保持。其他模组候选不随本轮安装。
5. 三项目标仍全部保留。公开网络/多人/稳定重连/其它版本仍不在本轮；B由独立会话负责，自己的当前状态见 `state/B-MEMORY.md`（若已建）及对应回执。

## 7. 详细记录

- 首绘实测总表与最新失败/收益边界：`experimental/recovery-room-first-raster-current/NATIVE.md`；当前桥源码与组件见同目录COMPONENTS/independent-review。循环配方目录冻结不可顺手维护，结果记NATIVE/state。
- 当前此前详细快照：`state/recovery-evidence-through-first-raster-2026-10-24.md`（归档中“正在进行”均按本快照为准）。
- 近期完整取证归档：`state/recovery-evidence-through-roomfix4-2026-10-24.md`；更早`state/recovery-evidence-through-offline-collector-2026-10-23.md`。
- 房间源/配方/测试准确绑定：`experimental/recovery-room-production-v4`、`experimental/recovery-room-repair-review`；旧检查器锁80CF，新`current_host_verifier.py`分别绑定旧构建和当前ABE2，不改历史回执。
- 现有正式候选发布：`experimental/recovery-room-production-v5/RELEASE.md`；旧aura发布说明保留。历史过程在journal顶部及各experimental/RESULTS；日志只追加，失败不改判。
