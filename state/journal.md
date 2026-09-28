# RConnect —— 开发日志

## 2026-09-28 M38：修复伤害、姿态与交互确认，部署0.2.10-dev

- 尸鬼碰撞高度和抗性序列化、玩家原生受伤与炮塔弹种、血翼姿态、武器帧间瞄准、门柜即时响应及开门解锁确认修复；密集敌人整体掉帧仍未完全解决。
- 最终生产字节79605，SHA c6c4e97848ae5fe3e456057316a2b839b22fa9bc98c11c6eeffbeeced6c2f005；8组391 PASS/0 FAIL，正常加载冒烟d525efc4c5通过，无测试类进入正式包。
- 原生锁门新增两条失败先在final2复现，final3修正；SATS末弹/回声补观测，护甲异步测试与网络换装冲突改为先后执行，未删除断言。完整证据和历史失败见M38报告。
- 备份0.2.9到`build/backup/m38-release-20260928-084315-636286/RConnectMod.before.swf`，仅替换RConnect release；52项游戏/其他模组/配置指纹不变。回执deployed-smoke-passed，未发布远程包。
- 下一步用户重启双端核对版本并复测原场景；密集敌人性能须在负载可控时继续定位。当前无本任务残留测试进程，不操作用户其他AIR实例。

---

## M38 分房门禁暂停（2026-09-28）

final4 的 e7d35c634c 在挑战房交接重建原生单位时出现 Unit.addVisual #1009（Location.addObj → GameBridge.restoreCheckpoint）；前面伤害、炮塔、SATS、合作六组通过。保留失败和日志，正式 release 仍为 M37；正在追查具体原生构造路径，不以重跑绿灯掩盖。

> 协议见 GOVERNANCE.md §8：只追加不改写，**新条目插在最上面**。

## 2026-09-27 M38门禁前：战斗与动画原因已复现，保留交互边界失败

- 用户确认轻机枪打尸鬼、加入侧受伤疑似偏低。复现与单变量修复证明：埋地碰撞高度0、抗性XMLList跨JSON失效、NPC扣血量二次普通伤害中继、原生AI与显示姿态分离、门10包延迟。真实TCP修复后尸鬼45/45且宿主仅结算一次；五种炮塔弹种按实际UnitPlayer计算一致。
- 初0.2.10候选炮塔60、特效破墙29、SATS24通过；1e7ef9c3b0补测原生loot=1时出现柜子画面/确认回流两失败，final2统一1/2已搜刮语义。989005e63d合作130通过1失败，旧生命周期替身未提供新增原生setPos契约，补齐替身方法而不删断言。
- 80敌人仍有明显整体掉帧；已测得包间瞄准推进和实际时间调度改善，机器有本任务外AIR实例，不能据FPS推导单独双人性能。测试与失败来源见knowledge/experiments/2026-09-27-m38-combat-state.md；抗性序列化原生事实已去重写公共库。
- 当前release仍0.2.9，未部署。final2候选79464字节、a503e24c…aa541c84，完整8组回归进行中；后续按发布门禁备份、单文件部署、正常启动、记录和提交。

---

## 2026-09-27 M37：修复加入侧SATS空图像崩溃，部署0.2.9-dev

- 用户报Sats/getUnits #1009。95d1afef99在旧部署精确复现；同房本体有图，碰撞代理vis为空；仅补图bf8f801f9d通过。修复保留原生选敌与攻击，同步隐身/禁选/目标资料，缺图排除，归属交接后退役代理不可复活或继续伤害。
- 正式字节76715字节、SHA 7f8e65ff…6f499432，四组247 PASS/0 FAIL：SATS e7537480f5（24）、完整合作f8df825ae5（131）、分房1e614a79fa（66）、画面42db1a0cda（26）。SATS原生连射弹90→84，双方敌人hp2000→1948；无测试类/原生存根进入正式包。
- 已备份旧0.2.8至build/backup/m37-release-20260927-201937-320917/RConnectMod.before.swf，仅替换RConnect release。83d542142e正常路径双实例加载0.2.9与tick200通过，47项游戏/其他模组/配置指纹不变；回执build/m37/deployment.json为deployed-smoke-passed。
- 失败夹具、审核超时与中断如实记录于knowledge/experiments/2026-09-27-m37-sats.md及m37-validation-evidence.json。公共机制新增shared-knowledge/ui-systems/facts/sats-unit-visual-contract.md，已查重且不需读取本模组使用。
- 2026-09-24到09-27中断间，外部已更新仓库历史及英文README；以fae082b为接续基线，保留其内容并更新双语版本状态，不改写历史、不推送。下一步用户重启双端核对0.2.9并实测SATS；排除范围不变。

---

## 2026-09-24 M36完成：部署0.2.8-dev，同地图普通房可分头，空房暂停保留

- 已按用户Q1–Q5确认实现RoomSync房间归属交接、真实原生单位/武器/交互/地形/掉落恢复，以及宿主共同旅行和挑战入口限制。保留既有炮塔、动作、探索、护甲、合作伤害和破墙修复；不新增退出游戏后的随机房战斗存档。
- 同一正式字节312 PASS/0 FAIL：分房782f885123（66）、完整合作0e6e0e6ee5（131）、炮塔54f1812bf3（60）、特效/地形a105a40e9a（29）、画面108e777d13（26）。包含在途回执后的320格修改及连续原生打墙后立刻交接；历史失败如实留证。
- 只部署RConnect 76546字节，SHA 0e808f08…4301925。31aa2003ea正常路径、无包装器双端启动/连接/房间协议/心跳通过；保护指纹最终一致。旧0.2.7回滚文件为build/backup/m36-release-20260924-085624-477508/RConnectMod.before.swf。
- fbf1ecd223因磁盘不足未启动加入侧；仅清理三个已结束实验的可重建副本，保留日志/候选/备份。runner现只复制运行资产并检查空间。报告knowledge/experiments/2026-09-24-m36-separate-rooms.md及m36-validation-evidence.json，开发状态state/MEMORY.md。
- 下一步用户双方完全重启测试实际地图。验证限1.02同机双人，特殊Boss/第三方敌人/长期全组合及同时失联/互换房未穷举；排除范围不变。

---

## 2026-09-24 M36门禁复核：挑战房懒加载、交接前连续破墙与测试时序

- ecb65c2b24暴露宿主选中的随机挑战未必在加入侧本地池中；补原生buildProb/setObjects/preStep/prepare并验证进入结果。d7d4f5f424随后完整分房/UI/换层/挑战通过；0c4b9c389c炮塔与3d01c29c9f特效回归通过，均为中间候选1853d4ed…。
- 1494dae4bf/1140082ba1的动画终点检查在250ms早于实现允许的300ms；d7a65ed3f4终点通过，但并发测试桥相互控制同一单位导致像素采样不稳定。改为顺序启动共享房夹具，并按实际帧采样；保持精确位置与不同像素断言。
- 复核发现交接时一批瓦片伤害仍待回执，后续排队破坏可能遗漏。新增有序发送全部剩余批次，先结算再交接；补320格、回执在途及连续原生打墙后交接验证。场景常规扫描保留5Hz，伤害仍20Hz。
- 新候选0.2.8-dev，76546字节，SHA 0e808f082e30fe00444f4534ff67b9eca312a35e2921837022c3d5f474301925；生产包28类，无测试入口/游戏存根。正式部署仍M35。最终五组回归从fbf1ecd223开始重新验证，不拿中间版本通过当最终门禁。

---

## 2026-09-24 M36开发中：用户Q1–Q5确认，分房及房间交接候选进入验证

- 用户最终确认同图普通房分头、空房暂停保留、宿主共同换图、剧情挑战共同、本次联机内重访保留；继续既有开发部署授权，不再提问。
- 同包原生访问实证4118f518e5成功。新增RoomSync、NativeRoomState、TravelGuard、RoomCodec及原生访问器；实际分房交接/战斗/破墙/重访开发验证通过，正式仍0.2.7。
- 门禁尚未放行：380ff0928e正式字节试验在挑战捕兽夹重建遇原生UnitTrap特殊null参数异常，已修后重测。ae0b271a5a旧合作夹具遗漏新增地图编号导致后续级联失败，修夹具而不放宽生产串房拦截。
- 当前运行1494dae4bf（完整合作）和ecb65c2b24（全模组房间/UI/共同旅行）。候选76257字节，外部驱动与生产分离；后续需旧功能显示回归、备份部署、正常路径冒烟、报告与记忆收尾。

---

## 2026-09-24 M35：炮塔底座/展开与内嵌开火修复，部署0.2.7-dev；分房调查待玩法选择

- 用户要求修复加入侧炮塔，并增加双方异房行动，点名grilling；Q1已选同地图内。Q2空房保留、Q3共同换图发起方、Q4剧情/挑战范围待答。仅调查分房架构，未关闭autoFollow或把关闭跟随冒充完成。调查及准确接续见design/separate-rooms.md。
- 旧正式字节f030c6fc6d为39 PASS/9 FAIL：五类炮塔被用turretN而非原生底座参数构造，变成天花板型；两个隐藏型始终收起。新增TurretDisplay，正确底座构造、原生展开/收起、逐帧炮口与灯、内嵌开火片段；不调用本地射击结算。
- 同正式字节f65b37faef炮塔60 PASS/0 FAIL，d45d24de9b特效/破墙27 PASS/0 FAIL，a9138d5ff1画面26 PASS/0 FAIL。保留夹具错误41bfb35d39（internal字段）与92d28b41ee（宿主展开后未逐帧animate）的失败，后者只改夹具、同候选重测。
- 只部署RConnect 58331字节，SHA adfb72c5…24685562；677c0fd628正常路径双端启动、连接、tick200通过。备份build/backup/m35-release-20260924-071111-362542/RConnectMod.before.swf可回滚0.2.6。游戏/其他模组/配置保护指纹一致，用户进程和存档未改。报告knowledge/experiments/2026-09-24-m35-turrets.md及结构化证据。
- 下一步先接收Q2/Q3/Q4及最终共同理解确认，再实现房间归属和完整状态交接；现版本仍同房合作。不能直接解冻难度100的显示傀儡，不能遗漏挑战landProb、playerdmg房间世代和原生重返回血。特殊派生炮塔/长期全组合及原排除项未验。

---

## 2026-09-23 M34：敌人开火/机械死亡、枪械破墙与重绘后显示，部署0.2.6-dev

- 用户明确加入侧使用枪械破墙。新增UnitPresentation传递成功开火事件并驱动子武器显示、复制UnitVortex旋翼机/UnitDron无马机的机械爆裂与机体移除，重复死亡不重播；新增TerrainSync正确x/y和opac/形状，宿主原生伤害结算+回执保护预测、去重、换房清理与大批瓦片轮转。
- 真正墙后无画面的另一原因是重绘后敌人仍挂在旧的离树Sprite：parent非空不足，新增stage归属检查与原生重挂接。保留M31/M32/M33语义。公共机制记录shared-knowledge/rendering/discoveries/frozen-unit-detached-layer.md。
- 正式文件外部驱动、全模组ded0968377为27 PASS/0 FAIL，墙后2154像素；合作b63258d97b为131 PASS/0 FAIL；画面74fbb372df为26 PASS/0 FAIL、15绘制帧缺失0、双方包间7位置/7动画帧。新增独立外部驱动验证同一份正式字节，不只用debug行为和release初始化。
- 仅部署RConnect 57505字节，SHA cab160ba…5f549b86；正式路径07638f0926双端启动/连接/tick200通过，其他游戏/模组/配置指纹未变。备份build/backup/m34-release-20260923-183657-115022/RConnectMod.before.swf可单独回滚0.2.5。
- 旧代码8项红测、测试造墙等待不足、厚墙夹具误设、修正走廊仍因旧图层失联而失败，均保留。报告knowledge/experiments/2026-09-23-m34-effects-terrain.md及m34-validation-evidence.json。特殊敌人/焚毁、全部武器、长期全组合及原排除项不宣称全通过；等用户双端完全重启后具体存档反馈。

---

## 2026-09-23 M33：对方动作/共享探索平滑与敌人显示，部署 0.2.5-dev

- 用户补充本机流畅，主要对方动作与共享视野跳动；加入侧站在宿主身边仍不见敌人本体。复现包间位置/动画停顿及受控透明残留，新增逐帧 RemoteMotion、原生动画播放/停止处理、宿主 invis/isVis/alpha 同步及最终绘制修正；保留隐身半透明闪现。探索从 500ms 整房改为最快 100ms 变化行，三秒补齐，合成移至真正绘制前。
- 最终 RC+RV d5ee064ade 为 131 PASS/0 FAIL，保留轻机枪、护盾/HP 收敛、双方不同护甲、门箱/死亡和共享探索；全模组画面专项 816fae8134 为 26 PASS/0 FAIL，实际视口三敌人有像素，连续 15 帧缺失 0，包间动作 5–8 个不同位置/帧。探索逻辑秒 10 包、夹具流量约减 86%，不是负载无关的实测速率承诺。
- 仅部署 RConnect release，53331 字节，SHA 683f8573…52fff2e6。正式文件重启 370cad3918 PASS，双方 0.2.5 初始化、连接、tick200/同步通过。备份 build/backup/m33-release-20260923-114237-479272/RConnectMod.before.swf 可独立回到 M32；游戏 SWF、其他模组、配置及真实存档/用户进程未改。
- 原测试副本漏 loader manifest、背景帧数不足、空夹具异常和两端 MSW 不同版本的失败保留。编排改为启动前冻结所有输入；异构轮的加入侧同步中断在最终一致环境未复现，未声称修复传输层。报告 knowledge/experiments/2026-09-23-m33-presentation.md 与 m33-validation-evidence.json。
- 用户旧日志缺 alpha/invis/isVis，受控复现不能冒充具体存档全因果；后续新日志可继续定位。双方需保存后完全重启并同时用 0.2.5；全模组仅显示专项、特殊武器/敌人/长期战斗及原排除项仍待验。

---

## 2026-09-20 M32：轻机枪命中反馈与双方远端护甲，部署 0.2.4-dev

- 用户提供组合为轻机枪/天角兽。红测复现护盾无数字、旧合并数字过期后不重建，以及远端服装动画读回本机穿着。独立反馈生命周期与远端服装帧修正保留原生损伤计算；蓝色 S -数字表示护盾消耗，伤害日志拆分 hp/armor/shield。
- 完整 RConnect+RV 双实例 d995672ebb 122 PASS / 0 FAIL；65 发原生轻机枪击破 500 护盾，双方最终 HP1695.2/shield0，与逐击损伤总和一致。不同护甲双方、跑跳/本机 armorWork、数字过期后再开火、已有合作/共享探索全部通过。早期短观察窗和双端 Timer 进度不同的失败如实保存在 M32 报告。
- 合入同期 M31 e127ab7，保留 ed0e38d 正式部署文档和配套 RV。仅替换 RConnect release，51393 字节，SHA 4e65327f…996c5262。候选启动 6ccefa9187、正式重启 c7ae0ed25a 均 PASS；17 类无游戏存根/测试类。备份 build/backup/m32-release-20260920-153135-660744/RConnectMod.before.swf 可单独回滚至 M31。
- 报告 knowledge/experiments/2026-09-20-m32-hit-feedback-armor.md、m32-validation-evidence.json；公开数字生命周期和服装全局状态机制各一条。当前主工作树为接续基线，build/m32-combat-appearance 仅保留最初隔离红测资料。
- 用户进程、真实存档、游戏 SWF/配置和其他模组未修改。下一步双方正常重启实玩反馈；特殊敌人覆盖、附加状态、全模组实战及原排除项未扩为已验证。

---

## 2026-09-20 M31 与 RV 已替换正式版本

- 固定RC0.2.3（0e00e4f8…7157）与RV0.30（ce3abb8d…fb5b）正式安装，保留ModSettings迁移。最终46b70da446双方初始化/连接/tick200及RV心跳通过。
- 先前短观察窗回滚、并行脚本版本竞争与最终冻结脚本验收见本目录deployment记录。用户保存后正常重启双方；本任务未操作用户进程/存档，仅替换两个目标SWF。同期M32代码、MSW发布保留。

---

## 2026-09-20 M31 部署门禁：短观察窗未覆盖加入侧心跳，先回滚

- 正式文件备份后替换，独立实例 5372c2cfae 双方初始化和连接正常；50 秒窗口结束时加入侧尚无 tick 200，RV 仅 tick 1。原脚本最终判断漏检加入侧心跳，误报 PASS。
- 已恢复两份部署前 SWF，修正最终检查必须包含双方版本与 tick 200；下一步延长独立观察窗后再部署。备份与指纹见 build/m31/deployment.json。本次没有操作用户进程或存档。

---

## 2026-09-20 M31 双向共享探索、各端开关与 RV 可选接口候选完成

- 用户决定：各自控制接收，关闭后保留已取得区域；允许同步修改 RV 接口但不得硬依赖。用显示层共享保留原版交互/瞬移与 RV 本地即时视线；当前世界生命周期结束才清理，不新增磁盘探索存档。
- 实现：独立 ExplorationSync 替换旧单向 seen 缓存与原生字段改写；持续双向快照、正确坐标、房间实例互认、参数与尺寸校验。F10 和可用模组设置页开关保存本端配置。RV 动态载体提供 active/capture/merge，独立共享子格/瓦片/墙光记忆；无相互类依赖。
- 验证：无 RV 双实例 c5a976c81c 为 103 PASS；最终 RV 组合 e6c6df2924 为 104 PASS；RV 单独 37 PASS；普通候选无 RV / 有 RV 启动 94f25cd6d6 / 510c982aa5 均通过。动画观察窗与网络验收时序的失败、修正及完整指纹见 knowledge/experiments/2026-09-20-m31-shared-exploration.md 和 m31-validation-evidence.json。
- 产物：RC 0.2.3-dev 普通候选 50175 字节，0e00e4f8…c3277157；RV v0.30.0-candidate 22310 字节，ce3abb8d…3a8dfb5b。仅写 build，未部署、未修改真实存档/用户进程。普通包无 fe.* 存根与测试类。
- 协作边界：RV 同期 ModSettings 迁移改动保留，已向“MSW”任务发送共享文件提交协调，互不整文件暂存对方改动；本任务没有新增子代理。后续部署需核对两个模组及设置任务的最终源码，不能盲覆盖并行任务产物。

---

## 2026-09-20 M30：修复加入方动画和真实子弹伤害，部署 0.2.2-dev

- 做了什么：复现 disabled 排除原生子弹、快照覆盖伤害、格心量化及 EXIT_FRAME 受击重入。新增无 AI 受击器、损耗队列、净伤害回传、每游戏帧动画与坐标插值。80 项双实例检查通过，正式 release 启动检查 3ee92b0907 通过；仅替换 RConnect SWF。
- 关键决定/发现：真实射击必须通过 Bullet.run 碰撞；原生 gotoAndStop 可同步重入 EXIT_FRAME。编译签名外链，正式 14 类无存根或测试入口。报告 knowledge/experiments/2026-09-20-m30-combat-animation.md、结构化 m30-validation-evidence.json。公开事件机制已另存 shared-knowledge/rendering/discoveries/synchronous-exit-frame-during-hit.md。
- 部署：47919 字节，SHA-256 97bf59edbde5d2b702d675af950de7ef3e8625f3dd27dc458ed410b989fe1995；M29 备份 build/backup/m30-release-20260920-114534-591961/RConnectMod.before.swf。源码基线 8aeacb7，保留另一任务 26cf636 文档，不改共享探索决定。
- 遗留/下一步：双方用户窗口重启后复测。特殊附加效果、全武器/Boss、TDFC/RR/MSW 组合未穷举；共享探索另任务停点与原排除项保留。没有修改或关闭用户游戏/存档。

## 2026-09-20 共享探索源码探查，双向与 RV 自身规则已确认

- 做了什么：按用户“请进行探查”读取 RConnect 同步/配置/UI、1.02 原版光照与最小范围 RV 代码；按 grilling 的事实核查要求委托一名只读子代理研究 RV 接口。新增 knowledge/discoveries/2026-09-20-shared-exploration-feasibility.md，更新记忆。未修改功能代码、运行游戏或部署。
- 用户决定：双向共享；原版遵循其明暗机制，RV 以自身设定为准。Q3 开关归属、Q4 关闭/断开是否恢复个人探索仍待答。
- 关键发现：现有 seen 缓存不跟随同房间新探索，space 横纵坐标颠倒，仅单向广播且房间校验不足；原生 visi 还影响交互/瞬移。RV current/classic 有独立子格/瓦片记忆且无公开共享接口，可靠接入需小接口；已有 MSW 设置 API 可供注册。旧 M14 记录不能直接推广到当前机制。
- 边界：RConnect release 仍为 M29 指纹；RV 当前 v0.29.0-candidate 指纹与 M29 回归时不同，本轮无运行验证。探查期间其他战斗相关工作树改动未纳入本轮提交。
- 停点：接续待答问题，再确认纯显示/原版操作权限及跨模组实施范围。独立本地与远端记忆为建议，尚未实现；完整证据、方案与验收场景见报告。

---

## 2026-09-20 M29 修复加入方敌人显示及索敌，部署 0.2.1-dev

- 做了什么：复现真实 RV 下 visible=true 但渲染内容为零、同名敌人被合并、已有房主目标挡住近加入者索敌、普通地雷构造失败。修正遮罩及退出恢复、实例键与伤害路由、原生感知选目标和数字变体构造。仅写 RConnect，未改用户存档/进程和其他模组。
- 验证：34373dd227 的 35 既有 + 16 敌人 + 9 TCP 检查全部通过；保留所有失败试验与夹具修正证据。正式 release 产物 e7c3ca8fe9 启动/连接检查通过；测试 PID 已结束。
- 部署：45574 字节，SHA-256 33CE3B722A3473CC24659E813F8BBB7A934B295F680BD5612A341515A6B38685。旧 M28 备份 build/backup/m29-release-20260920-095514-292641/RConnectMod.before.swf。配置/游戏 SWF/主描述符指纹不变。
- 关键发现与边界：见 knowledge/experiments/2026-09-20-m29-enemy-visibility-targeting.md 及 m29-validation-evidence.json。实际组合只测 RConnect + RV；TDFC 全组合、完整潜行发现度与用户原场景手感待验。
- 停点：用户需重启双方加载 0.2.1-dev；未扩展稳定重连、三人以上、公网、跨版本及任务/背包/交易系统。无委托。

---

## 2026-09-10 M28 候选部署完成，供用户测试

- 按用户授权部署 10d46ac 对应普通候选至 release/RConnectMod.swf，44963 字节，SHA-256 2A65D5F83567BD1FB8D537270BEE4499FBAA7BF6EF2EAF89BE161BFDE0A8CF56；旧版备份 build/backup/m28-release-20260910-153718-905444/RConnectMod.before.swf。配置及游戏三份 SWF/主描述符前后哈希一致。
- 正式资源根独立 ID 两次建图 #1009 均回滚；只读确认 MSWAutoTest 对全部非 pfe 自动开档，错误时 RR 房间未 finalize。旧版延长观察在 35 秒通过。未改其他模组，未把全组合判为通过。
- 最终从正式 release 读取产物，隔离 host/join 检查 80abe809ae 的新版初始化、心跳、welcome、单位同步通过，测试进程已清理。未改源码/重新编译，此前 42 项功能证据仍适用。
- 详见 state/deployment-m28-2026-09-10.md；用户重启后 F10 测试，完整组合与真人体验待反馈。主侧顺序完成，无委托。

---

## 2026-09-10 M28 部署首次检查失败并回滚

- 用户明确要求部署候选；核验候选与既有测试哈希后，备份至 build/backup/m28-deploy-20260910-152024-b20615/RConnectMod.before.swf。
- 正式资源根下独立测试实例的 0.2.0-dev 初始化成功，随后 Land.prepareRooms/newGame2 报 #1009，未到 tick 200；已自动回滚旧 release 并关闭本轮 PID 7204，未动用户进程/存档。
- 原因待核验；证据在备份目录 RConnect.log、stdout.log、deployment.json。再次部署必须重新通过检查。

---

## 2026-09-10 M28：补齐已有合作交互、角色显示与退出清理

- 做了什么：按用户排除稳定重连/三人以上/真实网络/版本兼容、暂不扩展任务背包交易的范围，新增房间内对象稳定身份；修双向关门/解锁/破坏、脚本门与 Box 补建；特殊敌人改原生地图参数构造；玩家内外层姿态与换装实际替换；拾取物完整堆叠/状态、吸入移动与无 60 件截断；念力插值基线、EXIT_FRAME 显示和退出恢复访问过房间的原 AI 标记。
- 关键发现：真实双实例曾发现脚本门关闭意图被旧瓦片同步覆盖，修为保留待确认意图直至宿主回应；收尾复核补跨房间恢复记录。原 M27 日志的“加载顺序保证”不成立，本轮改用帧事件阶段消除该依赖，但未声称实际 RV 组合验收通过。
- 验证：e8f2045028、563e74694c 两轮各 40 项通过；最终 65e809e940 为 35 项直接桥接/原生对象检查 + 7 项真实双实例 = 42 项通过；最终普通候选 5ce32a15a1 启动/连接通过。失败轮 a33ec2e235 保留。测试全程独立游戏副本、随机专用 AIR ID、全新角色、仅清理本轮 PID。Python 语法、输出保护和 diff 检查通过。
- 产物：源码版本 0.2.0-dev；普通候选 build/m28/RConnectMod.swf，44963 字节，SHA-256 2A65D5F83567BD1FB8D537270BEE4499FBAA7BF6EF2EAF89BE161BFDE0A8CF56。release 及游戏 SWF 未改，当前安装仍为旧版。新增 tests/ 三入口、tools/run_coop_regression.py；构建脚本支持独立候选和测试入口。
- 证据/遗留：knowledge/experiments/2026-09-10-m28-cooperation-validation.md 与 m28-validation-evidence.json 保存覆盖表、失败修复、断言和哈希。真人观感、实际多模组组合、全部地区/Boss 阶段/完整流程留待后续；同名对象初始重合、循环门语义与排除目标没有伪称完成。由主侧顺序完成，未委托子代理。

---

## 2026-09-10 接手调查：目标与 M27 执行现状核对

- 做了什么：读取权限、记忆、设计、近期实验及网络/会话/游戏桥接源码，确认代码基线 master/a32633f；新增 state/handoff-2026-09-10.md 的目标—实现—待验矩阵，更新滞后于 M26/M27 的 MEMORY。
- 关键发现：区分 WORLDSTATE 与 UNITSYNC 频率；M26 念力平滑已实现，TDFC 测试误触发已在其 v0.5.4 修复。M27 加载先后保证与离线显示清理仍待验证；手动 Join 默认不自动重连，监听失败后模式提示不一致。完整内容、多人与真实网络验收不能由同机双实例记录推定。
- 验证边界：仅静态检查及工具路径存在性核对，未编译/运行/部署，未修改源代码、release、游戏文件或用户存档；旧游戏 loader 核验仍标历史，不假称本轮通过。
- 遗留/下一步：当前同步缺口与 M26/M27 体验验收优先；自动化前核实 pfe2/pfe3 占用与存档模板，避免旧脚本干扰用户第二窗口。详细证据和范围见接手报告。

---

## 2026-09-07 M27 强制显示宿主可见敌人（用户拍板 a："队友报点"）

- 做了什么：applyUnitsSync 每轮重建存活镜像集（sost<3 且非 invis），GameBridge 构造时挂 ENTER_FRAME 每帧恢复 vis.visible+prior（被 RV 视距整只隐藏的镜像敌人）。
- 关键发现：零闪烁靠**同帧注册顺序**——RV 的隐藏也在 ENTER_FRAME 且先于本模组初始化，同帧回调按注册顺序，我们的恢复必然在其后。
- 验证（m27_run1）：M26 实证 s=0 的敌人 → 全部 s=1；RV 在视野内软边遮罩（m=1）原样保留；5/5 匹配零错误。
- 遗留/下一步：观感待用户实测（黑暗中敌人现在应可见）；window1 类无 inter 脚本门不同步仍待用户确认是否为其测试对象；RV 会话可选做联机豁免（选项 b，未动）。

---

## 2026-09-07 M26 念力平滑 + 门复验 + RV 视距敌人隐藏定位

- 做了什么（grilling 轮答后）：①念力平滑（上报 1Hz→5Hz + 接收端 tween 插值）；②注入/镜像落点校验（修 rr_showroom #1010 崩溃）；③诊断埋点（宿主门清单 + joiner 敌人可见性采样）；④双实例复验门/箱全通。
- 关键发现（→ knowledge/experiments/2026-09-07-m26-*）：
  - **敌人"不显示"根因 = RV（RealisticVision）视距机制 × 联机**：RV 把不在本地玩家视线内的敌人整个隐藏（hideUnit→vis.visible=false），采样实证 merc2 s=0。宿主看得见的敌人在加入端自己的黑暗里。修法待用户拍板（A 强制显示镜像敌人 / B RV 侧豁免 / C 现状）；
  - 门机制复验通过（doorIcTest 开关→joiner ist apply open 双向）；random_mane 门清单 door1/door1a 均 ac=0 可同步，**window1 类无 inter 的脚本门不同步**（宿主开它走 scrOpen，我们读不到）——用户测试的门可能属此类或当时不同房；
  - 扫描提速后 ist 稳定性门 3→6 次（5Hz 下 ≈1.2s，循环门照滤）；
  - phoenix p=0（vis 未挂树）观察项待跟。
- 遗留/下一步：敌人显示修法等用户第二轮拍板；脚本门同步评估待确认；念力平滑观感待用户实测。

---

## 2026-09-06 Steam 还原游戏 SWF 事件（#1009 报错根因）+ 恢复

- 做了什么：用户报"进入游戏 #1009（Invent.addLoad）"→ 排查发现三份游戏 SWF 于 09-06 05:46 被 Steam 还原（体积 -7.5KB、loader 标记全无、今早 07:11 主游戏以纯原版启动）——原版物品表没有存档里的 MSW 模组物品 → `Invent.addLoad` 的 `this.items[id].kol` 空引用。**存档本身没坏**。按 remains-game-update runbook + 2026-08-15 授权，从基线备份恢复：备份 Steam 原版（build/backup/steam-restore-20260906-0546/）→ 覆盖 current-merged-20260819 三份 SWF → 测试实例验证指纹 `game version=1.02 bd=0.2` + RConnect 初始化 ✓。
- 关键发现：
  - 诊断捷径：模组日志**完全无新行**（连 mod init 都没有）= loader 不在；先查 SWF mtime/标记再怀疑代码。
  - 基线恢复比重跑 6 个模组补丁脚本更稳（current-merged-20260819 含 6 loader + M13 Land 补丁，字符串扫描校验过）。
  - 跑测试实例遇到"静默无输出"先别当挂死——原版游戏开到菜单就是静默的（stdout 缓冲不 flush）。
- 遗留/通知：主游戏 07:11 起的实例是原版（内存里没 loader），**用户需重启游戏**；其他模组会话请核验各自功能（loader 已随基线恢复）；若 Steam 再次校验，重跑本恢复路径即可（原版备份 + 基线都在 build/backup/）。
- 附带：run_m2_dualtest.py 加 M2_LOADSLOT（程序化读档槽位可配）。

---

## 2026-09-05 second_player.bat 存档镜像（用户工具改进）

- 做了什么：用户报告第二窗口读档菜单为空——根因是 pfe2 实例存储与主档案（%APPDATA%\pfe\）天然隔离且从不复制。重写 bat（纯 ASCII/CRLF）：启动前把主档案全部 PFEgame*.sol + config.sol **只读镜像**到 pfe2（每次启动刷新到最新进度），并清理残留第二窗口实例（只按描述符特征匹配，绝不动主窗口）。
- 冒烟：11 槽全部镜像 ✓、第二窗口进程起来 ✓、模组初始化 ✓（读档入口在游戏菜单，需用户手动加载后 F10 加入）。
- 注意（已写进 bat 注释与文档）：第二窗口是测试实例，它自己存的进度会被下次启动的镜像覆盖；主档案只读不写。

---

## 2026-09-05 M25 念力移动物品同步 + 门/容器状态双向

- 做了什么：读用户真实联机日志诊断三项报告——敌人"不渲染"实为 boss(alicorn)/mine 类注入受限（其余 27/27 正常，注入失败日志已加堆栈）；念力 Box 位置与门 ist 补双向：objs 快照带 wall/托举态，joiner id+就近落位（含边界+抗重力）；新消息 MSG_OBJS 上报 joiner 移箱与 ist 变更，宿主 setAct+ever-seen 重播收敛；本地偏差保护（镜像不吞本地移动，M24 loot 推动同洞一并修）+ 3s 稳定性门（滤循环门风暴：545→0）+ ist 扫描按对象实例跟踪（同 id 多箱互殴修复）。
- 关键决定/发现（→ knowledge/experiments/2026-09-05-m25-levit-box-ist-bidirectional.md）：
  - 双向同步三件套：镜像保护+上报通道+收敛检测（基线刷新时机是止振关键）；
  - 按 id 的状态机在同 id 多实例房间必然互殴——一律按对象实例+附位置就近匹配；
  - 新档 travelToLand 到基地型土地（rbl/stable_pi）触发游戏侧 buildProb #1009（测试环境坑，random_mane 稳定）；
  - 用户真实日志（%APPDATA%\<appid>\Local Store\RConnect.log）是最快诊断入口。
- 遗留/下一步：alicorn 注入待用户实测堆栈定位；念力动画平滑度（5Hz 近似）；其余按 MEMORY §6。

---

## 2026-08-28 M24 可移动物品（Loot）全量同步

- 做了什么：盘点敌人同步（M4/M8/M19/M21 已闭环，无结构性缺口）→ 物品侧补齐：宿主 Loot 稳定键（Dictionary 对象键，L#n）+ unitsync `loots` 数组（空数组也发=移除信号）→ joiner 认领/生成/位置镜像/缺席移除；joiner 拾取与推动经新消息 MSG_LOOT 上报宿主权威落位；readNewObjs 退役 Loot 坐标键（避免与 M24 双重生成）；测试钩子拆成 lootSpawnTest/lootPushTest/lootTakeTest（M2_LOOTTEST/M2_LOOTJOIN）。
- 关键决定/发现（→ knowledge/experiments/2026-08-24-m24-loot-sync.md，文件名 2026-08-28）：
  - `Item(构造器)` param2 赋给 id 而非 base——物品身份键读 item.id（读 base 恒空 → spawnLoot 静默拒绝）；
  - "缺席即移除"必须真的发空数组，否则 joiner 无限重复上报 picked；
  - 测试钩子动作窗口必须 ≥ unitsync 广播间隔（200ms），否则物品生命周期短于采样窗永远不可见（6 轮迭代定位）；
  - AS3 对象键映射必须用 Dictionary（Object 键字符串化全撞键）。
- 遗留/下一步：suction 动画不镜像（直接落位）；同 base 重位误认领（仅键归属，无增减）；推动限频 1s/键；其余按 MEMORY §6。

---

## 2026-08-28 M23 幽灵趴姿+悬浮根治（皮肤语义映射）+ 开机门控

- 做了什么：用户报告 M16a/M18 修复后幽灵仍趴姿+悬浮 → 每消息 dump 定位真正根因：玩家皮肤 idle 主段是 "stay"（free1/2/3 只是偶发小动作），而幽灵皮肤 stay=趴/卧——**同标签不同皮肤语义相反**，1:1 镜像必然大部分时间趴。修复：idle 族映射 stay→free1（freeX/移动标签透传）+ levit 压制。另修复 startGame 无 landData 门控问题（夜间并行 TDFC v0.5.0 的 AutoTest 劫持测试实例暴露）。
- 关键决定/发现（→ knowledge/experiments/2026-08-28-m23-pose-skin-mapping.md）：
  - 跨皮肤镜像必须建语义字典，镜像"渲染意图"而非"播放头位置"；M16a 的日志级验证抓到 free3 瞬间误判已修——呈现类 bug 需密集采样/真人观感；
  - TDFC AutoTest 激活条件（appid != "pfe"）比其文档宽，劫持 pfe2/pfe3 抢开新档打坏开机链；RConnect 补 landData 门控自保，TDFC 侧问题只报告不修（见 MEMORY §5）。
- 遗留/下一步：悬浮消失需用户真人观感最终确认；坐下/爬行不镜像（标签层不可分）；TDFC 激活条件待转告。

---

## 2026-08-27 M22 门/容器交互状态同步（Interact ist 镜像）

- 做了什么：查证 M16 的 door/door_opac 字段同步是无效同步（XML 类型常量）→ 真实状态在 `Interact`（open/lock/loot/mine）→ 实现 ist 快照/应用（宿主 `save()`+实时 open 打包，joiner `setAct()` 官方存档恢复路径幂等应用）+ 门死亡走 die(-1) 清瓦片 + doorIcTest/boxLootTest 钩子 + M2_PORT/M2_DOORTOGGLE/M2_BOXLOOT/M2_HOSTWALK 测试变量。11 轮双实例迭代验证。
- 关键决定/发现（→ knowledge/experiments/2026-08-27-m22-door-interact-sync.md）：
  - 宿主须广播"曾经非默认"字段（ever-seen），否则关门/解锁永远到不了 joiner；
  - autoClose 门 open 不同步（游戏存档语义）+ open/lock 滞回（10 条 unitsync）——rbl door3 是游戏侧 1.4s 周期循环门，忠实镜像会变 setAct 风暴；
  - 同机残留测试实例抢 23456 端口致串线：bind 失败现在写 RConnect.log，测试换 M2_PORT；
  - 本机工具链：flexsdk 在 D:\RemainsMod\...\tools（AIR SDK 51.3.3，须显式 -swf-version=38），Java 11 在 _sandevistan_dev\jdk-11（build_mod.py 已修）。
- 遗留/下一步：门被摧毁 die(-1) 未做双实例专项；客户端交互上报宿主（双向门）未做；容器搜刮 joiner 侧等有容器房间现场验证；其余按 MEMORY §6。

---

## 2026-08-27 外置记忆迁移

- 由 state/current-status.md + 顶层 HANDOFF.md 拆分迁移（原文在 git 历史）：现行状态 → state\MEMORY.md；14 条关键坑清单 → knowledge/facts/engineering-pitfalls.md；M1-M20 里程碑流水浓缩为下方条目。
- 注意：HANDOFF 提及的 M21 仅存在于 git 提交信息，无实验文档——后续接手者应从 git log 补认。

---

## 开发历程（M1–M21，每条含实验文档指针，新在上）

### 2026-08-21 M21 敌人可见性漏洞修复 + 会话报告诊断
- 内容详见 git 提交（无独立实验文档）。

### 2026-08-20 M14–M20 观感与"宿主权威"全面补齐（六连发）
- **M14** 幽灵走路动画修复（密封类 #1069 中断 driveVisAnim）+ 武器镜像（new Weapon 挂幽灵手）+ 探索迷雾同步（visi 掩码广播）。→ knowledge/experiments/2026-08-20-m14-*
- **M15** 双存档随机图布局差异根因 = LandAct.landStage 随存档持久化参与房间池过滤 → adoptHostLandParams 采纳宿主 stage；幽灵趴姿修复（sost 每帧强制 1）。→ m15-landstage-pose
- **M16** 姿态终局（幽灵优先镜像对方真实 osn 标签）+ 物品/箱破坏状态同步（objs 快照按 id 镜像）。→ m16-pose-mirror-objs-sync
- **M17** 瓦片破坏差分广播（200ms 对比 loc.space，仅 1 次重绘）+ 新生成物品/Loot 镜像（沿 Pt 链扫描）。→ m17-tile-loot-sync
- **M18** 外观镜像（快照带 Appear 六元组，构造时临时换全局）+ 悬浮药水假象修复（isFly 每帧 false）。→ m18-appearance-mirror
- **M19** 敌人同步三件：皮肤 vf、死亡掉落、仇恨朝向 cx/cy。→ m19-enemy-sync
- **M20** 鲁棒性：兜底姿态 free1、外观热更 restyleGhost、近身敌人转火（每轮≤4）。→ m20-robustness

### 2026-08-19 M13 随机图（rnd）房间布局确定性
- 根因：房间几何结构随机点仅 7 处、全在 Land.as，双实例 Math.random 时序不同 → 布局分歧。
- 修复（游戏文件，已授权）：tools/patch_land_determinism.py 给 Land 加静态 PRNG（fnv1a(act.id) 播种），rnd 土地自动播种 → 双端同布局；内容随机保留。三份 SWF 一并补丁（备份+双标记+全加载器校验）；基线刷新至 build/backup/current-merged-20260819/。
- 验证：双实例同 locId+同坐标+同 8 点 tile 指纹。→ knowledge/experiments/2026-08-19-m13-rnd-layout-determinism

### 2026-08-18 M11–M12 用户报告的两个阻断性问题
- **M11 不同存档加入场景加载失败**：根因 = 加入方在世界过渡期（t_exit/t_die/comLoad）被 autoFollow 拉着跳房 → 反复重进注入不收敛。修复：GameBridge.isTransitioning() 门槛 + 读档前后 8s 跟随抑制。→ m11-save-follow-settle
- **M12 同地点两侧房间不同（失焦冻结）**：根因 = 窗口失焦游戏自动开 PipBuck 且无复位 → allStat=2 冻结。修复：优先级 1000 拦截 DEACTIVATE + forceCloseOverlays 兜底。→ m12-blur-pip-freeze；贡献 shared-knowledge window-blur-pip-allstat

### 2026-08-17 M8 + M10 世界注入与双向战斗收尾
- **M10a** 敌人打客户端化身：根因 = 化身 disabled=true 时 isMeet() 恒假；活体化（disabled=false + id_replic="" 禁言）。**M10b** 死亡/复活全链路（化身被动化→客户端原版回城→复活重建）。两个关键坑：中继伤害不能钳制（护甲减伤收敛陷阱，须中继原始命中量）；hp<0 是致死一击正常状态。→ m10-death-aggro
- **M8 房间内容同步**：reconcileWorld 扩到中立单位（fraction 0..99）；程序化读档 autoLoadSave（先 newGame 骨架再 comLoad，防 #1009）；三个连带修复（travelToLand 防护 / 世界替换基线重置 / 每轮重冻结）。→ m8-room-mirror

### 2026-08-16 世界注入 + 威胁归属（宿主权威两支柱）
- **世界注入**（worldInject）：宿主有本地无 → 按 AllData XML 动态生成傀儡；本地多出 → 移除；只处理敌人，单轮 8 上限幂等收敛。实测不同进度存档加入后 unitsync 6/6。
- **敌人威胁归属**（ghostCombat）：客户端幽灵在宿主世界成可攻击化身（显式关 invulner）；拉仇恨（priorUnit/celUnit 指化身）+ 伤害回传（化身 hp 下降 → 客户端 gg.damage 走原版流程）。实测双向 50 伤害闭环。

### 2026-08-15 建仓 + M1–M6 联机管道全线打通
- 授权补丁三份游戏 SWF（loader 注入，patch_game_swfs.py 幂等+备份+双标记）；版本指纹落地（World.boxDamage）；入口类 #2023 陷阱（RConnectDoc 空 Sprite）。
- **M1** 测试容器双实例全链路（加载契约/TCP 握手/中继/聊天）；**M2** 幽灵双向同步；**M3** 姿态动画+HUD+断线重连+聊天；**M4** 世界身份握手+单位镜像 27/27；**M5** 战斗权威闭环+跨房传送（gotoXY 挂死教训：autoTravel 移除）；**M6** 傀儡动画（像素级采样验证 blit 帧真渲染）+幽灵半透明/名字标签+跨地图传送。
- 深夜马哈顿闭环：UTF-8 帧长 bug 修复（长度前缀=字节数非字符数，俄文房间名曾流错位）；随机地图单位匹配率 ~60% → 成为 M8/M13 课题。
