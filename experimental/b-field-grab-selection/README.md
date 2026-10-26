# B：按画面身份抓取投掷物

基准：`build/ab/b190-field14-build/src`。本目录只存差异源码；未启动编译、AIR、JVM或部署。由主会话合并到当前候选。

## 根因和行为

加入侧的 `ClientReplica.projectilePointers` 是延迟播放位置的显示代理，`PlayerPointer.run` 却仅按网络传来的鼠标坐标重新搜索主侧当前物体。原生 `UnitPlayer.actions` 在Q首次按下时只调用一次 `actTele`；错过后持按不会补抓。主侧抓加入侧成功、反向失败与这个不对称链条一致，仍须同一实机用例验证修复。

新流程只给加入侧Q的第一下附带“看见的投掷物ID+发布序号A/B+插值比例+鼠标位置+房间和角色代次”。主侧核对确实发送过的画面及当时命中框，再临时选择同ID的真实 `PhisBullet`。不倒退投掷物，不提前执行抓取，不扩大选中框。原生仍核算当前距离、质量、视线、法力；现有生命周期与另一玩家持有保护仍生效。

## 集成文件

- `RConnectMod.as`：在 `replica.present()` 之前只读保存上一屏的点选信息；输入最后仍含Q时才附加。MSW浮层、选择器、暂停消耗Q时不附加。
- `ClientReplica.as`：从上一屏代理和当前鼠标取得ID及实际播放时钟；没有抓取或物理操作。
- `ReplicaScene.as`：抽出只读 `selection`，与现有 `pointer` 共用资格和优先级判断；普通 `pointer` 仍写所有原生 `onCursor`。
- `Commands.as`：第一个尚未消费的Q沿冻结其提示，包括null；后续持按/释放/第二次按键包不会覆盖已排队的第一沿。消费、500ms失联和换房清空。
- `ProjectileSelection.as`：只记录成功发送后的数据；最多96次发布、2秒、每次最多256颗带grip数据的投掷物。按presentation区分暂停中同tick的多帧；房间/角色代次变更清空。只保留坐标、尺寸、状态和身份，不持有历史实体或整帧。
- `HostSession.as`：绑定加入玩家的校验器，成功发送后登记，结束释放。
- `PlayerActor.as`：一个可选桥接引用；主侧玩家不绑定。
- `PlayerPointer.as`：在原生step的现有try/finally范围中临时替换celObj/onCursor；原始hover、距离和levitPoss仍在finally恢复。

`RoomRuntime.as`无修改，复用现有 `projectileId(object)`；Q按下时有界扫描当前房间链查ID，不增加每帧扫描或反向实体强引用。

## 验证输入与实机边界

外置 `test/BProjectileSelectionInputs.as` 可以在驱动加载候选后调用 `BProjectileSelectionInputs.run(domain,check)`。它回放Q按下→持按→释放在同一主侧tick前到达、下一次Q换目标、空白点选、失联过期、换房清空、非法字段不吞序号，以及离散暂停画面的输入约定。它不能替代真实抓取验证。

沿用当前controls真实投掷物用例，继续瞄准加入侧看到的上一屏投掷物，不改成主侧最新位置。正例须最终检查原生teleObj是相同PhisBullet、真实levit/移动/投掷/到期爆炸；双方各两种轻重投掷物均测。加入侧快飞目标应产生projectile-pick接受记录，但记录本身不算成功抓住。

负例：未知ID、从未发送或超过2秒的发布、不同房/复活代次、插值鼠标在框外、真实对象liv<=5/已爆炸/不在链、被对方持有；以及已合法选中但当前超距/质量超限/被墙挡。后三项允许选择提示核验成功，必须由原生拒绝实际抓取。长按不重复抓；松Q再按可正常松手或换抓；主侧自身Q维持原生。暂停相同tick的两次发布不能串用序号。时停回放画面不接受该提示。

无效提示回落到既有原生坐标选择，不新增断线或重试逻辑。现有房间中的其他目标仍可能被原生正常选中；提示不是强制禁止一切普通Q行为。当前2秒/96帧上限对极端长卡顿会降回既有行为，不缓存无限历史。UI层的投掷物可见/悬停及原生远距抓取规则未扩展。

诊断 `projectile-pick` 仅说明提示核验结果，不能宣称最终抓取成功。`verified/rejected/last`是有界计数及最后一次小记录，无每帧日志。

## controls实机后外置夹具修订

field20首次controls：phase2加入侧真实抓到主侧酸弹，主侧反向两种均成功；phase0加入侧普通弹未抓到且没有任何projectile-pick记录，不能据此宣称全通过。首次准备发生在peer-view-ready之前，加入侧helper进入后仅采到两帧便到结算；阶段未互等。两次加入侧hover=false都来自step读取新画面的celObj，与input为上一屏位置设置的鼠标进行比较；phase2已成功抓取也false，说明该断言有时序错误。

`test/BGrabCases.as`是基于根当时工具的独立修订，根统一复制：每轮ready等待加入侧确认对应房间/角色代次/500与640站位/准备后的source time，且原生输入ack已推进一轮neutral，再允许真实投掷。host还要求awaitingFirstView已解除、已consume这份ack并且Q/E/投掷均释放。按键仍只瞄加入侧上一屏实际显示的活跃投掷物；不使用主侧实时位置、不改引信或飞行速度。第一次真实Q的只读选择在present之前采样并写一条带完整发布序号的日志，之后始终保持该次Q，不自动释放重试。主侧真实teleObj、所有者、寿命及投回/到期仍是效果验收。新增少量grab-stage、grab-ready、grab-input-edge日志用于分清准备、真实边沿与产品校验。

根会话v10实机`build/ab/b-field20-controls-02`完整主38/0、加27/0。四例均由原生快捷栏产生一颗真实PhisBullet：普通手雷双向抓取并E投回；酸弹双向抓取后原生引信到期，持有引用正确释放。owner、projectile ID、递减引信和仅一次spawn均通过。加入侧第一Q沿普通弹点选source14/t=0，酸弹source242→243/t=.5957；发送的aim等于加入侧显示位置。主侧核验时普通弹currentX1195.46而pictureX689.26，酸弹currentX1035.96而pictureX660.50，实际teleObj仍抓住原始实体。这验证身份桥跨过了真实显示延迟，不是夹具改瞄主侧实时位置。夹具使用高技能/较大念力范围保证正例，不把它当成普通角色全部距离/遮挡负例测试。

field9→field20只读回归审查发现并获根采纳：selection重构曾把native Number优先级截断为int，Box原生在整数优先级加1/(scX*scY)，重叠对象可能选错。本覆盖仅把priority:int改为priority:Number；由根合成field21，冻结field20不改。`test/BSelectionPriorityChecks.run(mod,domain,check)`创建既有case/door1b/term1原生资产，挑两个同整数档但小数不同的真实优先级与交叠碰撞框，两种遍历顺序都必须选较高者；同时确认只读选择不改onCursor、UI选择保持完整Number。没有把它们放入房间物理链；原生Box构造本身仍会写门格子并增加land.kolAll，因此构造前记录所有原tile的front/phis/opac/door/mat/hp/thre（保留引用）、房间重绘/照明标记和三项kolAll。finally恢复上述状态、房间指针和鼠标坐标。该新增检查尚待根统一编译实测。
