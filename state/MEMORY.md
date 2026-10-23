# RConnect — 开发记忆入口

## 1. 当前任务

A 为普通入口的双人联机；B 独立架构本轮不碰。根会话 `01a086bb-378c-7f60-b8e1-50d90ffa0996` 统一整合、编译、AIR测试及部署。
用户最新重点：删除“房间交接中”定制界面，双方加载达到相应原单人流程耗时，解决新房间不同步，并按git核对性能倒退。**加载修正尚未部署，目标尚未完成。**
之前的高速弹丸/念力/掉落/击墙动画也尚未全修；不要用局部通过声称全部完成。本轮优先房间，不扩回B或无关视觉任务。

## 2. 玩法、授权和执行约束

- 普通房可分头；无人房暂停保留本次进度；剧情/挑战共同进入；宿主发起整图旅行，同入口。未换房者不应被另一个人的加载暂停。
- 掉落一份先到先得，经验共享，存档点共享解锁各存角色；安保破解共享/分别可选，切换保留已有权限。
- 跟随、共享菜单/SATS暂停、被队友念力抓、抛掷伤害、友伤默认关；WASD挣脱默认开。
- 所有RConnect会话可协调，根唯一部署。指定FA/RV/WB修正、LAD/CS测试协调已有授权；不能扩展成任意其他模组写入。A独立Sand加载兼容已授权；B的其他接口授权仍限B。WB首次初始化删除refreshView提案仍待答，不改WB、不以此阻止RC工作。
- 共享ModLoader game登记，JVM/AIR串行；子代理只做独立目录源码/审查。无实质新证据不跨会话发状态消息，不逐个要求停测。普通授权不重复确认。
- 唯一AIR ID、私有后台桌面、只读复制Littlepip29至测试槽9；不写真实存档、不关闭用户程序、不调用未点名Ghost。AIR写独立AppData需require_escalated；已授权测试范围内执行，不维护新护栏授权表。
- 启动余量：双6GiB/单3GiB/组件编译1GiB，运行512MiB保护，不降低。用户已答释放内存后继续，不重复提问。测试时读取当前余量，旧内存状态不是现在的结论。
- 省D盘，清自有可再建副本；保留失败、唯一证据及旧版。合格后直接备份部署复验，未合格不得覆盖。公网/多人/重连/其他版本不在本轮。

## 3. 实际安装与候选

正式RC：`0.2.24-aura1`，`release/RConnectMod.swf` SHA `df0fa0e2ca952e77e5132e75d71e73558dc919c7b8cdeba5da05fc9e94dc01e7`，186738B。
回执`build/m52/recovery-aura-offline-deploy-02/deployment.json`，真实安装smoke7d45932e01通过；同目录备份EB365/offline1，再上一层574D/bundle2备份见recovery-offline-deploy-01。已交付仅独立离线采集优化和玩家被抓光晕，没交付房间/运动修正。

当前宿主ABE2：`abe2b65edf3d0e4e0fa8eca76a60e577d40e47f20b9acecebec7730849a2602a`，CS 10月24日00:00独立部署Camera.calc；回执`mods/ContinuousScene/state/vertical-camera-band-deployment-20261023.json`。RV为0DBE (`0dbe0d7a95b8e496fb393d7fcd75f88d60c34a1d0fabb33266b122e3fa04f2bf`)，其余CS7F1F/SandCEC6/WB14112等未变。旧80CF/6DBA历史不改写、不与当前耗时混算。

**当前生产候选roomfix4**：`build/m52/recovery-room-production-04`，SWF `34a17de66e9a89165b4bde75d22ec1dd3d4295bb496b903124687af80422b703`，195145B；prepared093916CF，compile3CDE928E。编译时80CF/0DBE，当前实测ABE2/0DBE须分清。源配方`experimental/recovery-room-production-v4`。
来自准确aura1的11类房间修正：并行生成，未换房者不停，当前原房不自恢复，实际入口放置，绑定原生Land/Room交接与连续过门请求，READY观察标记去重、暂停时不耗跟随期限，原生加载素材与文本，地块完整标量表/准确绘制缓存。v4仅比v3删除RoomCodec每次同步文件诊断（候选误留，正式版无此日志）及改版本。房间生成/字段/伤害不删减。

诊断专用roomtime1：`recovery-room-loading-counter-product-02`和`recovery-room-loading-counter-driver-01`已编；来源`experimental/recovery-room-loading-counters`。只测首次grant及随后2帧9函数、14阶段标记、消息累计；原场景/断言不变，不能部署也不给净性能资格。product01因AS try/finally返回分析编译失败，原失败保留。

## 4. 最新实测与卡点

- **git准确归因**：574D→EB365→DF0F的房间/遮罩/旅行源码相同，加载修正从未正式交付。并非“已修又坏”；这是交付缺口。无证据否认用户性能倒退。见`experimental/recovery-room-repair-review/PERFORMANCE-REVIEW.md`。
- **普通48×25（历史80CF/6DBA）**：旧aura1双24.780/13.300/19.241秒，重访错位1109px；同组合solo9.903/6.386/6.272。roomfix2主7.462/2.121/3.457、加7.520/2.097/3.488，入口一致。仅此样本，不代替大图/最终候选。
- **大240×125（80CF/0DBE同组合）**：solo1f971dc179为7.518/1.916/3.571秒；roomfix3 d86f5d2d22主10.161/2.364/4.640、加15.675/2.844/7.711，种子/房/入口一致、重复seal已消失；仍不达原单人。首次grant2.033秒（解码187、恢复1827ms），之后3.688秒长帧待定位。
- **当前ABE2/0DBE单人**：8d4cf6e1db，`recovery-room-scene-solo-current-host-02`，7.222/2.115/2.980秒通过原三程；这是之后新双人直接基准。旧solo01/fb00d86688因sandbox拒绝私有AppData，在AIR启动前失败；02升级权限后正常，未改真实存储。
- **最终roomfix4真实分房**：BF6 0de27b7e59 / `recovery-room-candidate-entry-04`，主25+加53通过；死亡/HP/弹药/墙破坏/容器/唯一掉落/静止同伴保留，22安装不变。根实际目检双方waiting截图，均正确原生Loading动画而非原定制交接字样；无性能资格。
- **背景门**：roomfix3 2b02103aa3 / `recovery-room-hidden-03`，真实12轮主121+加157；控制/跟随镜头/身体像素/前景死亡保留/返程轻机枪伤害均过。v4同房间源码和等价Codec，尚未另跑v4背景门。
- **组件**：真实RoomSync READY92/0，cross68/0及5条实等；实际UI20/0；最终新旧Codec211/0，交叉解码/地块/墙面字节相同且无文件日志。通过项不盲目重跑。
- **密集版本对照（ABE2/0DBE）**：旧574D c0657f7dd9对当前aura1 394edfb54d，fixture/dimension/driver/runtime成对可比；加入7窗P95旧456/627/1135/860/936/972/513、新442/587/706/533/512/515/465ms。两版都严重失败，21/18条阈值不合；新版两个同步间隔更差。一对墙钟刺激不能否认用户回退，也不给roomfix4资格。见`recovery-room-density-review/RESULTS.md`。
- **采样失败不是无开销**：573fe88372原场景功能过，但grant与首帧采样全丢、第二帧截断；不把0CPU样本当0开销，不重复已失效flash.sampler路线。已改有界真实函数计数。
- **当前阻碍**：计数双人19e66eb57c / `recovery-room-loading-counter-native-01`因可提交余量3.76GiB无AIR；solo结束仍约3.8GiB。30秒7点复查为3.99–4.03GiB，证据`memory-followup.json`。全部根测试和编译均已结束，无活动自有AIR/JVM。内存够6GiB再以新输出native-02运行计数器。现有结果保留，不重复启动失败副本。

## 5. 未解决与已否决

- 要求仍是实际加载/操作速度，不是隐藏覆盖层。不能把功能通过或旧普通房速度当大图合格。
- MirrorMasks.capture确有pending×layer枚举，但签名计算已有本次缓存；没有计时前不盲改。索引还须保留多record保存visible的次序、真实引用及首个mask后续成为候选的情况。尚未写性能候选。
- 不复用仅靠U序号/150px近邻的原生敌人；不完整恢复mapxml/interact/脚本引用会破坏炮塔/状态。不删快照/视野/动画或放宽门槛换速度。
- 当前Sand CEC6活动/回放绕过普通pause；A已授权接口候选未完成整段旅行验证，暂不并入。WB首次刷新提案无答复不动它。
- 旧墙面结构代C6A3与宿主6616有逐像素/分房功能证据，但等离子延迟和密集未合格；旧ACK/NoDelay/主动收包/暂停23等分支均无完整收益，不合入。详细已否决路径和准确旧证据见归档，不重建。
- 真实用户Unit.run #1010在Littlepip29隔离中未复现，不称已修。

## 6. 下一步入口

1. 首先只读查当前余量。足6GiB后运行已编有界计数产品02+driver01：`experimental/recovery-room-loading-counters/run.py --product build/m52/recovery-room-loading-counter-product-02 --drivers build/m52/recovery-room-loading-counter-driver-01 --output build/m52/recovery-room-loading-counter-native-02`；AIR需require_escalated，原共享登记/6GiB/512MiB/600秒/所有断言保留。
2. 从三个窗口和grant后消息耗时定位主因，再做最小算法修正。网络聚合时长不含外层Tcp解帧/AMF；函数total包含子调用不可相加；Stage区间包括其他监听器。不要把阶段空档全归RC或WB。
3. 最终准确生产候选用当前ABE2/0DBE与solo8d4cf6e1db对照大图，再核密集；不是不断换环境重跑所有旧套件。当前根唯一AIR/JVM/部署。
4. 合格后备份、部署、实际安装复验；否则诚实保留候选，不覆盖已安装DF0F。当前未批准降低速度目标或性能标准。

## 7. 详细记录

- 近期完整取证归档：`state/recovery-evidence-through-roomfix4-2026-10-24.md`；更早`state/recovery-evidence-through-offline-collector-2026-10-23.md`。
- 房间源/配方/测试准确绑定：`experimental/recovery-room-production-v4`、`experimental/recovery-room-repair-review`；旧检查器锁80CF，新`current_host_verifier.py`分别绑定旧构建和当前ABE2，不改历史回执。
- 现有正式有限发布：`experimental/recovery-aura-offline/RELEASE.md`。历史过程在journal顶部及各experimental/RESULTS；日志只追加，失败不改判。
