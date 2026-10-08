# RConnect —— 开发记忆入口

> 2026-10-08 当前已部署 **0.2.21-dev**：131147字节、53生产类，SHA256 `5c372cf5d970212f0fd4e95bea5c0acfaabfe321c3ca531c80ed7e299c2914bd`。M49四项交付完成；20组2095/0/双端DONE，正常无驱动加载3611e15340通过。42个最终自有PID退出、其余56保护未变。[部署与回滚](deployment-m49-2026-10-08.md)。
>
> 本会话统一验证/部署，RConnect (2)/(3)保持只读。无待运行测试或待部署候选；用户保存并重启两端后实测21。未推送、未改公开安装包。公开玩家README继续对应0.2.8，文档发布记录见[玩家指引](github-player-guides-2026-10-08.md)；公开文档b586376/本地接入fb8a6b9保留。

## 1. 工作边界与机制

只写RConnect；游戏本体/描述符、game-reference只读，其他模组只作必要最小只读。共享知识按贡献规则。入口RConnectMod.init(main)，AIR/amxmlc，swf-version=38。loader硬编码app:/mods/Rconnect/release/RConnectMod.swf，小写c保持；实际目录RConnect。根application.xml指向pfe.swf 1.02，勿混淆app.xml。World.constructor.boxDamage=0.2，反编译首选game-reference/decompiled/1.02/src102/scripts。

双人各自原生角色；同房宿主结算，普通房分头时各端运行自己的房间战斗，由RoomSync交接。玩家/活跃念力箱和掉落/新生及飞行普通掉落约20Hz，敌人及完整场景约5Hz，显示逐帧推进。测试只开自有隔离AIR标识/PID，不动用户游戏或存档；构建/AIR串行，不允许其他会话覆盖release。

## 2. 用户决定与授权

- 已授权已有合作功能修复、大幅重构、候选部署及与RConnect (2)/(3)直接协调，由本会话统一部署；不重复确认。稳定重连、三人以上、公网和版本兼容排除；不新增任务/背包/交易规则。
- grilling Q1–Q5已确认：同地图普通房自由分头；空房暂停保留进度；宿主发起全队换图；剧情/挑战共同进入；退出游戏沿用原版存档，不新增随机房完整战斗保存。
- 地面物品一份，先拾取者入包；经验点双方奖励；存档点同步解锁，各自保存角色。跟随默认关，地图标记/传送沿用共同旅程限制。
- 任一端菜单/SATS可触发全队暂停，包括分房；全部关闭才恢复。两全局开关默认关、宿主设置；网络、聊天和SATS排队继续。
- 紧凑浮窗已实装：常驻280×36、展开通常280×240，四页/滚动、标题拖动、四角停靠。各自保存位置/开合/30–100%不透明度。主字号12，暂停提示独立不透明；Ctrl+Enter开聊、聊天框Enter发送、Esc收起、F10显示，原生Enter全屏保留。
- 本轮新增个人“允许队友念力抓起我”和“被抓时 WASD 挣脱”。用户要求双方独立设置；默认取值未收到额外回复，已明示按允许关/挣脱开实现，并非用户另行拍板。两端分别保存，关闭允许立即释放；挣脱关时WASD不打断抓取。浮窗外框未增高。
- 同机第二角色保留独立身份/保存；Start-Coop.bat只管理自己启动的进程；迁移保留原件，不反复覆盖角色。

## 3. 当前安装与回滚

- 当前21/5c372cf5/131147B/53类，最终冻结build/m49/final-lifecycle-16，54源文件/163验证输入。实际生产编译10；后续只修改独立测试和审计编排，源/实际字节不变。
- 20组2095 PASS / 0 FAIL / 双端DONE。18组原运行保留（10四专项、14两念力组、15十二组），16新跑WeaponAngle aa7eb649b6、PresentationContinuity 6347112b03。carry逐项核对实际driver类表、完整编译/运行依赖、配置与真实角色模板，不冒充重跑。
- audit_m49全部通过；正常无驱动/全已安装模组加载3611e15340通过（150秒上限，非150秒满时浸泡）。最终40个专项+2个启动实例PID均退出，其他56项保护一致。
- 上一20唯一备份：build/backup/m49-release-20261008-232026-727eb9/RConnectMod.before.swf，SHA `77e3886f7f76885db35558ba7da4a591ec486ab65faab37f95c14116d67bb3ee`。回滚：双方保存退出，复制回release/RConnectMod.swf后重启，不回退角色存档。
- 证据：knowledge/experiments/m49-validation-evidence.json；冻结目录内deployment.json、normal-smoke-result.json、closeout.json；本机发布记录state/deployment-m49-2026-10-08.md。

## 4. M49实现与实际证据

- SATS位图：GameBridge在停止末帧改变镜像/覆盖位置后置dirty，最终RENDER可见性处理后隐藏旧位图/目标覆盖，调用原生drawSats，再恢复图层开关。保留选中项及攻击队列，不运行暂停AI。旧20/9beba4f621原位图差24.5px；最终1f5ba08739差0px、2808/2808标记像素，选择/队列不变。
- 旧念力目标：冻结本体跳过Unit.step导致onCursor残留。按原生矩形、isVis、trigDis、sost、prior逐帧更新本体和命中代理，离开鼠标范围只清对应旧celObj。原生actTele/dropTeleObj仍作决定。旧20同一负控松手后仍抓54321；最终可换54322。
- 死机器：UnitPresentation彻底移除状态同时loc.remObj/remVisual；NativeRoomState不捕获或恢复in_chain，死亡恢复清链，不重复die/奖励。原生配对炮塔land/tr3及UnitMsp，真实角色两轮死亡/检查点复活/离房重返；旧20/950b33f377六红，最终3376200cb2七次绘制链检查均无残留。
- PeerGrip：由被抓玩家掌握许可与真实物理，施法者仍走原生Q/魔力/E。验证连接、房间epoch/term、距离/视线/质量/魔力、旧token失效；levit=2避免被当作玩家自身悬浮。挣脱关时暂存/抑制本帧移动键并恢复；切房、死亡、离线清理；共享暂停保留握持和租期。
- 队友暂停：60b7441492证明被抓宿主本体停在223.96905、加入画面235.93955，500ms后仍差11.97px。远端玩家收包和逐帧显示也调用既有motion.settle，位置改变一并重拍SATS。最终双向稳定误差≤1px。
- 原生E：85c5a17770确认仅松手、玩家t_throw未激活。Location.step先gg.step再化身step，45在帧末已经变44。RemoteDamageUnit新增step前回调，PeerGrip在化身模拟前转交原生冲量并清临时化身速度/t_throw，只玩家所有者模拟投掷。最终3d74518763为真实E两方向，12案例162/0。
- HUD 9dba6ccf2d为154/0、24原生PNG，个人开关/保存及语言宽度/240高均通过；不等于真人IME验证。14恢复PNG无已定义白块，抽看0/2离线图正常。

## 5. 回归失败与证据边界

旧红、单变量候选、完整冻结和日志均保留，详见knowledge/experiments/2026-10-08-m49-target-lifecycle.md与journal。

- 10接收端到自己的1000ms时已收到真实投掷，错误要求仍抓着；仅修接收前提。11箱体速度/落地未完成时被墙钟提前检查，箱轨迹改按原生帧推进、等速度<0.5再释放；保持40px/停顿<50%/跳变<25px/释放350ms。生命周期原时刻严格验解除，再有界等原精度落地。
- 12 / 5d1790d925有1131ms没有RENDER后26.1px跳变；13 / 7c584c5fb3首箱单次通道等待超时，未再现且根因未确认。14只加帧/控制消息诊断，d90b29e5e2完整198/0，绘制间隔最大123/133ms、跳变11.9/9px。没有排除长帧或提高阈值，不能声称全局卡顿修复。
- 14 EnemyGrab最后场景加入先抓起、宿主后查地面（317.76对320）；15改双方检查起点后才开始，48fc004aea全绿，原1px/升高/抗性/时窗保持。
- 15 WeaponAngle宿主160度两帧错。原夹具一端结束就停止维持输入，对端可能仍采样；16保持输入到双方完成并记录实际轴，aa7eb649b6双向14角度零错，700ms后源轴无变化。原红缺轴记录，不能断言已完全解释。所有旧红不改写为绿。
- 最终四场景快速搬运100–140ms；容器空中停顿0/45ms；稳定暂停差及恢复跳0px。这是受控路径，不是所有FPS/网络/长期稳定性保证。

## 6. 既有实现与未覆盖项

- M48：RemoteMotion保形三次插值；新生/运动普通掉落随20Hz快包传播，落地500ms尾段、epoch/term及快游标阻旧慢包；暂停收齐物体/敌人停止点。M47：原生武器世界矩阵、短角度插值和离散反射；50ms高频持物、约100ms显示缓冲，释放重复500ms。
- M46：抓物残留NPC指针、光晕/原生mask恢复、原生闪电与可见性/抗性代理等专项均有历史证据；不能把匿名Timer或全部1009均认作已修。见对应deployment-m46/m47/m48和实验。
- M43背景嵌门原反馈是宿主角色消失/控制丢失、返前景死敌重现，开/关跟随五轮均未可靠重现。本次死亡清链不证明该控制问题已解决，后续需实际复现/RoomTrace。
- 密集战斗仍可能卡顿；M46的80敌人与基础负载数据不是版本配对，不宣称性能提升。真人鼠标/中文IME、长期运行、所有NPC/第三方特殊状态和全部换房竞争未穷举。
- 房间只保留本次同地图联机，不新增随机房跨游戏完整战斗保存。公网、稳定重连、三人以上和其他版本未验证。既有Area/Trap #1063构造诊断是历史路径，未据总门禁绿宣布消失。

## 7. 接续工具

- 本轮已收尾，不重新部署16，不用旧20基线作新版本；下一轮另立当前21安装基线与全新冻结目录。所有失败目录、备份、原日志保留。
- 源/测试/工具冻结后运行期间不得修改。流程见tools/validation/README.md；M49为prepare_m49 baseline/freeze→显式构建/类表/built→20组→audit_m49→deploy_verified→run_smoke（失败先自动回滚）→closeout/记忆/本地提交。
- 构建tools/build_mod.py必须显式--output build/<新目录>/RConnectMod.swf，默认会写release。外部driver与生产SWF分离，不编入第二份生产/native实现。
- Python及子进程均-X utf8。Python：C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe；Java：C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe；SDK：D:/RemainsMod/mods/Sandevistan/build/tools/flexsdk；FFDec同tools/ffdec/ffdec-cli.jar。
- AIR后台策略查询仅自有PID，需要时走工具审核；不关闭用户原有实例。Tool会话中断时先查保存的run/receipt和准确PID，不覆盖旧结果或把启动未完成算功能红/绿。
- git用core.excludesFile=本模组build/m43/empty.gitignore避免失效全局排除路径；core.safecrlf=false。不推送。
