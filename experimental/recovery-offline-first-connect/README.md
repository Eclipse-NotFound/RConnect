# 离线后首次双游戏接入：单入口原生检查

这里只新增 `tests/OfflineFirstConnectTestDoc.as`。产品固定为 `0.2.24-offline1` / `EB3653533CFB305BCCA0B0CFE5E81BC306EA28FA400AAE751AB7B5AE1CFA5FEE`。根会话管理同目录 `driver.py`、冻结、编译和实际运行；本交付未编译、未启动 AIR，不预先授予功能或性能资格。

入口复用现有外部声明及 EffectsHarness；新增资格接口均通过 `Object` 访问。不修改产品、共享运行器、其他模组或真实存档。

## 场景与准备条件

1. 双方使用正常新游戏引导，再原生读取隔离槽 9。配置必须 `autoRole=''`、`autoLoadSave=-9`；根运行器提供既有只读模板的副本，不传 `--land`，避免首次主持后另行自动旅行。
2. 各自正常读档与控制恢复后，仅在尚不处于 rbl 时调用一次公开 `gotoLand('rbl')`。实际土地身份与原生加载均完成，再稳定 4 秒后才保存玩家/库存身份。
3. 核实原 Session、原资格 hook 都允许从未联网的离线捷径。用私有 `Invent.weapons` 浅副本，通过 `Invent.addWeapon` 和 `changeWeapon` 装备一个 LMG。此枪从离线开火一直保留到联机正例结束，不补装、不清采集器、不读取 `readSnapshot`。
4. 双方各离线攻击一次，要求同一原生弹丸至少两个不同 ENTER 的最终 RENDER 位置、移动及实际像素，随后自然离链。原生 `addEffect('freezing')` 必须产生真实色变与像素；原生 `remEffect` 后本体恢复原色，至少 12 帧且 1.2 秒稳定，才发布本方就绪标志。
5. 双方均已离线就绪后，宿主只调用一次 `startHost`；真实 `server.bound` 后发布监听标志。加入侧见到该标志才调用唯一一次 `startJoin`。不自动重试；首次失败如实失败。观察真实 hello/welcome、房间就绪与同一玩家/同枪身份。
6. 从唯一一次 startHost/startJoin 调用起，连接中、准备中、静默窗以及第一枪前的等待都持续检查旧弹图、旧枪口动画与旧冻结色。双方静默至少 2.2 秒，必须在该窗内实际收到至少 3 个对方状态并看到同房间队友；不能让“没有数据”成为负例通过。首次真实攻击紧前，宿主先经同一 TCP 链发送纯阶段标志，再调用 attack；双方到此才封存早期证据，不用固定睡眠猜测另一端何时开火。
7. 宿主、加入侧各发一枪；对方须收到本人的 main LMG 生产事件，看到移动弹图、真实像素与枪口动画。接收位置须落在源端独立原生轨迹的包围范围内（80px 容差），不按 NPC 或自己开火的快照推断。
8. 宿主原生 freezing/clear，双方最终 RENDER 比较本体色彩；远端按正式 `PlayerBodyEffects` 的 0.75 队友透明度规则比较。冻结正例另用同步恢复的绘图差分确认该色变实际改变画面像素。

## 隔离与观察边界

- 只读选择已有干燥、无邻近敌人的通路，不改地形、不移除敌人、不禁用玩家步进、不手动推进武器或子弹。双方轮流从同一前方站位向右开火，接收者在其后方140px；每轮开始核对通路并交换前后站位，保留原600ms等待和两次真实运动采样。前方净空仍至少为运行时 LMG `2*abs(speed*speedMult)+80`，整段弹道至少14格、4层空气；两站位另外按原生站立身体尺寸核对空气、落脚地板及与NPC的碰撞范围，不要求接收者上方与身体无关的高处也空出4层。弹道附近原有NPC排除范围不变，排除队友仍只用 `getRemoteGhost(实际 peer id)` 对象身份。双方分别用自己的武器速度/身体尺寸核验传来的完整通路。搜索失败时保留类别计数、尺寸和最多6条实际阻挡记录；找不到即准备失败，不另造地图。
- 玩家开火只调用一次真实 `attack`，其后由原生链推进。单发核对弹丸身份与弹匣消耗；`kol_shoot` 会被原生 `Weapon.step` 重置，不能当累计发射数。临时设自身无敌，防止准备场景的意外伤害使存档人物重生；位置/瞄准只用于该隔离夹具，结束恢复本地保存的属性。
- 线上事件按对方 `playerstate` 或 `worldstate.players[id=0]` 筛选，不扫描所有 NPC 包冒充队友。两边预先从本地同款 LMG 取得真实弹图类，准备消息必须确认两者相同；因此早到事件不等待 peerClass 才观察。所有相关 LMG 事件都分类，未知/非 main/无 flight/类名不符保留后拒绝，不能静默跳过。`ended=true` 本身不代表安全：只有 `frames` 明确为空数组且 ended 为真才当空结束通知；缺少 frames 的旧式事件仍能创建短时弹图，视为可播放。同一 stream/seq 若 payload 改变也重新检查，不能让早先空通知遮住后来的可播放内容。首次尝试事件账本跨 begin(0)/begin(1) 保留，最终封存时带原始事件深副本。该严格事件负例与最终画面负例分别保留；失败不自动证明是 offline1 相对 574D 新增回归。
- 每次调用 snapshot/capture 都可能造出历史，因此驱动完全不主动调用它们，也不改公开 hook。freezing 只验证当前身体状态采集/应用，不代表所有身体附件的观察历史均已覆盖。
- 双方先记录 `File.applicationDirectory` 的原始 URL、nativePath 与 AppID，再用 `new File(nativePath)` 遍历真实磁盘父目录（AIR 的 `app:/` 虚拟根可能没有 parent）。nativePath 必须非空且不超过4096字符，各祖先逐级判空；随后仍严格核对 file:、本角色名、`cooperation/<10位token>`、build/RConnect 和唯一 AppID，不从其它路径补猜运行编号。只写本角色 `offline-first-connect-<role>-ready.json`，宿主另写 listening。先完整关闭临时文件再同目录改名发布，内容只有运行/角色/阶段标识，不传游戏快照或效果。各角色收尾只删自己创建的文件，不删共享目录或对方标志。
- 硬上限：总计 300 秒；启动 180 秒；等待对方/首次连接 150 秒；其他单阶段 20 秒。最多 96 条观察、每阶段 64 条不同事件版本/64 个源端点/64 个远端点；首次接入整窗共享同一 64 条账本，原始 JSON 每条最多 8192 字符、累计最多 65536 字符。超限失败，不静默截断。像素差分最多 150000 像素，超出或看不到不能用作像素通过证据。
- 每个真实错误均失败，保留原因；会话释放、装备还原、配置核查、标志清理分开尝试。不会伪称回滚了整个原生世界时间或战斗状态。

## 输出

末行 `OFFLINE FIRST CONNECT RESULT {…}`，随后 `COOP EFFECTS DONE offline-first-connect`。字段包含 version、role、passed、failed、checks、phase、endedFrom、abortReason、attempts、coverage、cleanup、observations。

coverage 固定十项：`virgin / offlineShot / offlineBody / offlineClear / firstConnection / quietNoReplay / hostFire / joinFire / bodyApplied / bodyCleared`。必须按实际检查全真、attempts=1、无错误和清理成功；不预设检查总数。成功也只覆盖这一个首次接入、两枪及宿主 freezing/clear，`performanceQualified=false`。

清理回执包含 `sessionReleased / equipmentRestored / configRestored / bodyCleared / hookUnchanged / flagsRemoved`，全部实读为真才可 overall passed。身体色变的自然解除由最后一个阶段证明；失败中途只能据实记录 `bodyRemovalRequested / bodyCleared`，不能把发出了解除调用当作画面已经恢复。

## 首次实测后的路径修订

原生运行 `5589fa431d` 两边都在通过4项启动检查后，于装备准备/首次联网前出现 setup #1009（attempts=0）。失败位于原 `applicationDirectory.parent` 及祖先访问区间，原版本未留下路径诊断，不能把具体哪个空引用当成已经运行证实。路径修订将虚拟 app: 路径转换为实际 nativePath、增加原始日志和逐层空值边界，保留严格角色/运行编号/AppID 条件。随后 `622039485c` 实际通过该路径及装备检查（双方7项），原始URL确为 `app:/`；之后因旧夹具要求28格双向通路而准备失败，attempts=0，清理全过。原各驱动及失败证据均保留，不把准备失败算作产品联机结果。

## 单向通路修订依据

旧成功运行 `build/cooperation/f6eece7606/host.log` 的原生通路为射手 `(620,640)`、空气范围 `x=560..1120 / y=480..640`。这证明当时 rbl 存在14格通路；旧武器是flamer，不能用它替代本轮LMG的真实双侧验证。原版 `RoomsCamp.as` 的rbl布局显示前方 `(620,640)` 与后方 `(480,640)` 均可落在现有地板上，后者上方较高处有墙，因此本次按玩家实际身体高度检查后方站位。新算法仍扫描实际房间，不硬编码成功坐标；speed=200时前方所需480px落在旧通路内。此修订只缩掉无必要的反向弹道，不降采样次数、不改武器或地形；编译与新实测仍由根另建输出完成。

## 单发断言诊断

原生运行 `9b2366ad51` 双方都实际选中 `(620,640)` / 后方 `(480,640)` 通路，随后通过8项检查（包括一次 `attack` 被接受），在首次弹丸观察中失败；attempts=0，清理全过。失败时原驱动没有记录复合断言中具体哪一项不同，尚不能归因为多发、归属改变或弹药变化。

原版 `Invent.addWeapon` 第3参数写入弹匣 `hold`；`Weapon.attack` 安排攻击计时，后续 `Weapon.step → shoot` 才创建 `Bullet(actor)`、写 `b.weap=this` 并扣除 `rashod`，`kol_shoot` 随准备计时归零。本次保留原失败判据，新增失败时的一条有界 `OFFLINE FIRST CONNECT SHOT` 原始诊断，并同时写入最终观察：弹丸/枪/持有者身份比较、`in_chain`、准备时与攻击紧前/失败时弹药、`rashod/kol_shoot` 和换弹/攻击计时。没有把未证实的结束弹丸清理或准备期弹药变化当成通过条件；根另建驱动复验后再按实际失配值决定修法。

后续真实运行 `d87d5871bf` 已定位为弹药基线的时机错误：双方弹丸均 `inChain=true`，`gun.b`、owner/weap 身份正确，`sourceShotCount=1`；但准备时记录的是临时装入的200发，600ms等待中弹匣已收敛到宿主72发、加入侧90发。实际攻击紧前/射后分别为72→71及90→89，`rashod=1`。独立源码核查进一步对应到 FirearmAttachments 0.3.5（提交8d570a9）的 `Runtime.as` 118–121 行按实际 holder 退回超额弹药，双方日志分别记录 `capacity refund lmg 128 p556` 和110，因此不能把容量写死成90。最小修订在唯一一次攻击前先核 `gun.b===lastBullet`，确认准备中没有额外弹丸，再用已记录的 `attackBefore.hold` 设置本次消耗基线；原始200仍保存在 `attackBefore.armedAmmo`。sourceFrame 的弹丸身份、持有者、同枪及精确弹药消耗判据保持原样，没有跳过真实多发或归属异常，也不改配件模组或RConnect产品。新驱动仍须另行编译、实测。

## 最终确认与收尾

真实运行 `c6c9757ebc` 双方十项coverage均真、首次连接各一次。加入侧39项检查、零错误并完整清理；宿主完成双方最后一轮证明并发出finish后，仍处于round采样状态，把加入侧按协议退出误报为房间未就绪，因此整轮失败证据保留，不能提前宣告通过。

最小修订增加 `finishing`：宿主只有本方与对方最后一轮proof齐全后进入，再发送finish；加入侧收到finish时仍必须已完成最后一轮，先进入finishing再发ack与清理。finishing不再采样已完成的画面或连接健康，但原总300秒及该阶段20秒上限继续执行。宿主必须实际收到对应round4的finish-ack才可成功，结果另记 `finishAckReceived`；未确认、超时或任何清理失败仍失败。之前所有观察阶段保持原错误判据，晚到report不能重新进入收尾并延长时限。根另建驱动完整复验，不覆盖旧结果。

## 冻结来源

- `build/m52/coop-bundle-drivers-04/tests/FastHeldTestDoc.as`：`0BE443B3109D361B1216410116CBFFC2E5612ED87A63B4AD198826AFCAD3BC62`，正常读档/控制稳定后联网的引导。
- 同目录 `BodyEffectsTestDoc.as`：`7B4E80FF429CBE036FD3FD83700F92895C092B9497C6435FDA1C16454FBE33D9`，原生 freezing/clear 与显示色彩读取；未复用其旧裸武器创建夹具。
- `build/m52/recovery-drivers-11/tests/NativeFlightContinuityTestDoc.as`：`E530E573A67A4E0ED6C5D231BE9C134806DE999B677ADF5B4C1BAE12FF26C5BF`，原生弹丸最终 RENDER 与真实画面像素检查；未复制其 8 轮、全地图改造或手动武器推进。
- `build/m52/recovery-offline-collector-driver-01/tests/OfflineCollectorTestDoc.as`：`6CF7534860BBB4DAF89B0CA90CFD5B302AB3AE7DDE9BF4F2AD12AC8D5BE96A69`，保留实际库存身份、单发及有界观测；未复制它的 hook 替换或主动快照读取。
