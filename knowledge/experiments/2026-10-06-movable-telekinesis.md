---
domain: world-objects
type: experiments
game-version: ["1.02"]
confidence: medium
verified: false
discovered-by: RConnect
date-updated: 2026-10-06
evidence:
  - kind: runtime-experiment
    summary: "两份实际角色存档、全部安装模组、隔离TCP双实例。C13运动/生命周期176项、Aura103项、EnemyGrab211项和加严复跑181项分别通过；同夹具M45为133/48。保留C13一次提前清除本机指针造成的179/2失败，原因未确认；联合发布门禁另做。"
  - kind: decompiled-game-code
    symbol: "fe.unit.UnitPlayer.control/actTele/actions/throwTele/dropTeleObj; fe.unit.Unit.actions; fe.unit.UnitAlicorn.control/findBox/dropTeleObj; fe.loc.Box.forces/run; fe.loc.Loot.step/run"
---

# 双端念力移动、释放与清理

用户反馈：双方观察对方抓握物体会跳动；加入侧空中松开箱子后悬浮；加入侧抓狮鹫出现光晕但不能正常抓起或抛出。

## 已确认

- 抓握运动原来由50ms会话时钟推进，而显示帧与物理帧有另一时钟。现在由最终显示帧推进同一来源时间缓冲，宿主接到加入侧Loot抓持也使用该缓冲。
- `fracLevit`是原生碰撞归属，松手或抛出后会保留。不能把它当仍在抓持，也不能据此拒绝释放更新。本地抓握优先权取实际`gg.teleObj`指针。
- 空中静止抓持也必须立即上报Q释放边缘；只按位置变化上报会让静止松手等到超时。加入侧松手需清掉网络持有、交还位置和速度，再由原生重力落地。
- 原生`Unit.levit_max`未声明数值类型，从XML读取后可以是XMLList。旧JSON将其写成字符串`XMLList`，接收后Number为NaN。现只把该字段在单位快照中转为Number；没有改变敌人的原生重量、资格、挣脱预算或角色能力。
- 原生天角兽/首领天角兽通过`findBox`选`levit==0`的箱子，持有时保留自己内部`teleObj`。仅画光晕/暂停物理不足以移交抓握。新原生包内辅助类仅解除正在持有同一Box的敌人指针，并沿用原生玩家抢取分支的普通天角兽冷却。网络Box持有设`levit=1`，不创建本机玩家指针；释放、超时、离房和断线解除。
- `RemoteLoot.run`在网络轨迹控制时不执行原生落地碰撞。因此源端原生`stay`必须随同一来源时间样本播放，不能拿最新stay配旧位置。弃用任意Loot网络轨迹后恢复原生重力，实际本地抓握不受此清理影响。
- 普通Box缓动原先在小于1px时仅删除轨迹，仍可能停在离地0.252px且stay=true的位置。现在缓动末端准确落位，小于2px的剩余偏差仍收敛到权威端点。
- MirrorHitUnit设置`noBox=true`，避免接收侧再结算一次原生箱体撞击；权威端原生敌人仍保留碰撞。

## 观察到

所有输入与二进制置于`build/grip-20261005/`的不可覆盖目录；两端实际字节、其他模组、角色复制档由`build/cooperation/<run>/run.json`冻结。用户存档只读复制为隔离slot9，原始游戏SWF和release未被本会话改写。

| 产物/执行 | 结果 | 有效范围与失败 |
| --- | --- | --- |
| M45 `281f9516e4` | 87 PASS / 21 FAIL | 原生Q实档；Loot加入抓持在宿主52/53帧静止，天角兽指针仍占箱子，87次AI变化/87次夺回；XMLList线上限值失效。复用狮鹫后的抛出和重复Q存在夹具污染。 |
| C9 `588621dee0` | 102 PASS / 6 FAIL | 箱子地板、松手和天角兽正常AI95次变化/0次夺回通过。Loot镜像已落在top-1但stay=false；5个抛出相关失败发生在先前已挣脱、levitPoss=false的同一狮鹫。 |
| M45 `3e7f24d8a3` | motion 86/22；lifecycle 40/27 | 生命周期旧版红；首轮狮鹫与setup重复同id替换导致join观察旧实例，该轮无显示帧，不作为敌人显示产品红。其余独立狮鹫轮及生命周期有日志。 |
| C10 `1677365bb1` | 172 PASS / 3 FAIL | 独立原生狮鹫Q/E全部通过；严格Box地板gap0.252px失败、离线Loot重力交还失败、host离线3秒后本地指针未保持。全部旧失败保留。 |
| C11 `19817e0dfb` | **176 PASS / 0 FAIL** | motion108，lifecycle68，两端DONE，runner exit0。实档Q/E、数值、正常天角兽AI、严格Box/Loot地板、租约超时、共享暂停、本地Q接管、普通分房离返、实际Session.leave通过。 |
| M45 `c960697dc1` | **130 PASS / 46 FAIL** | 与C11首绿完全相同冻结驱动、存档和断言，两端DONE，runner exit1。motion89/19，lifecycle41/27；原生Q/E可用，但Loot加入抓持47/48观察帧静止、静止松手875–893ms、天角兽95次AI变化/95次夺回、数值与Box/Loot地板及清理失败。 |
| C11 Aura `1d792dc4a2` | 98 PASS / 4 FAIL | 原有光晕回归发现原生天角兽接管Box后，join颜色/染色/像素3项失败；武器换色25/31帧，单独保留。C11运动首绿不能外推光晕或最终候选。 |
| C11 Aura `9988740d17` | 99 PASS / 4 FAIL | 新增源端持续指针断言后，host enemyHeld=true但levit=0/glow=null；join光晕3项失败。该轮武器换色全部通过。 |
| M45 Aura `fa84f89249` | 99 PASS / 4 FAIL | 相同新增断言及驱动：源端天角兽pointer、levit2和光晕均正常，join显示正常。新远端Box物理标志契约2项旧版预期失败；武器round0/2换色出现1/31及3/37帧延迟，故换色瞬态不是仅C11出现。 |
| C12 Aura `7714b288d6` | 102 PASS / 1 FAIL | 物理源端pointer/levit2保留，但另一ENTER_FRAME呈现入口仍将旧remoteOwner看成有效，源端新敌方光晕变为旧玩家色；join仅颜色失败，染色与像素通过。 |
| C13 Aura `bb0a69b575` | **103 PASS / 0 FAIL** | 同冻结Aura驱动和新增源端指针断言；所有颜色、染色、像素、滤镜、武器呈现、离线清理通过，两端DONE、runner exit0。 |
| C13 Motion `83e46432bf` | **176 PASS / 0 FAIL** | 与M45 `c960697dc1`相同冻结Motion/Lifecycle3输入；同一C13字节完整运动、释放、独立狮鹫Q/E、分房与清理通过，exit0。 |
| C13 EnemyGrab `f13a9b9c0e` | **211 PASS / 0 FAIL** | 原有14场景机械回归，含重量、免疫、法力边界、自然挣脱、争抢、菜单、暂停和离线；该夹具使用明确能力设置，与真实存档Motion证据分开。exit0。 |
| C13 Style4 `0533f0415d` | **179 PASS / 2 FAIL** | 新增5项真实本机Q接管/leave光晕和CT检查全部通过；box-host在计划释放前已清指针并落地，5100ms记录dropY已为320，双侧fall=0失败。保留原失败，不能算整轮绿。exit1。 |
| C13 Style5 `1b2dab102d` | **181 PASS / 0 FAIL** | 只新增第一次提前指针清除前后条件日志，保持Style4全部物理、时序和断言；box-host持有至5123ms主动Q松手，正常落地。接管和leave前后本机光晕/CT通过。exit0。 |
| M45 Style5 `189a7923ac` | **133 PASS / 48 FAIL** | 与C13 Style5相同冻结测试源码、存档、规则；Loot远端47/48帧静止，静止松手740/930ms，原生天角兽96次AI变化/96次夺回；清理及地板失败。exit1。 |

C11固定SWF SHA256：`f13fe768c747950e7269d033a8f735b8be6c3bdf1dada304a3cbf884639674cd`，112269字节。安装基线M45：`59a03d1eb3ca7d8467015c709301bc1fbe6d585342de5857e984344a33572790`，110626字节。本对照排除RConnect(3)的独立projectile/targeting改动；最终联合字节必须另走门禁。

原生操作证据与合成报文证据分开：

- `TelekinesisMotionTestDoc`实际发送Ctr KEY_DOWN/KEY_UP；不直接指定玩家抓取指针、不强制敌人抓持物理。两个角色保留存档的mana=1000、maxMass=12、range=640000、unitLevitMult=2、throwForce=25。独立原生UnitMerc("1",10,lmg)，不加doop或抵抗豁免，原生limit=30。
- RENDER每帧采样，观察500–3100ms，要求>12帧、X跨度>40px、远端静止帧比例<0.5、最大跳步<25px。C11 Box/Loot观察端0或1次静止/37–55帧。静止松手相对实际原生指针清除的到达间隔1/214/244ms，阈值350ms。
- 松手后同时校验真实地板phis=1、phY1、Box Y恰好tile top、Loot Y为top-1、stay=true、dy=0和下落>20px；没有通过降低数值要求接受空中位置。
- `MovableGripLifecycle`以一次性TCP q=true报文测试租约失续，不把它算作Q抓取资格证据；真实Q用于本地接管、离房时另一个箱子持有和离线前后本机抓持。暂停使用原生Pip开关，超过1500ms租约；普通换房使用现有原生TravelGuard入口；离线用实际Session.leave。
- C11离线诊断：host在leave前后同一毫秒保持pointer=case、levit=1、eligible=true、mana=1000、KEY=false；3秒后仍持有。随后测试主动按Q，首次指针清除记录KEY=true。没有绕过原生掉落条件。

光晕回归揭示了一个候选引入的旧释放/新持有竞态：join上轮Q松手报文可晚于host开始新的原生天角兽抓持。仅保护gg.teleObj不足，旧网络缓动会把新的levit2清成0。C12为此按本机模拟端真实UnitAlicorn/UnitBossAlicorn.teleObj保护新持有，只拒绝旧q=false和旧缓动；真实q=true仍可按原生抢取规则解除敌方指针。镜像端不凭其残留NPC指针拒绝权威快照。显示帧先清理旧缓动，再处理光晕，避免旧remoteOwner回调覆盖新的原生颜色。

C12还存在另一ENTER_FRAME入口先呈现后清理的问题，物理保护单独通过但颜色仍错。C13在所有入口共用的remoteOwner回调中显式排除本机新NPC持有；`TelekinesisVisuals`删除旧持有者样式前也判断真实本机玩家/本机原生施法者，避免清理旧样式时恢复CT覆盖新的原生Q/NPC样式。C13固定SWF为`4f3f94f80649177661b7195362c9be8835683b9ec6b42872168ca31e757d0e8f`，112413字节。最新运动/生命周期加严181、Aura103、EnemyGrab211均通过，原运动176首绿及Style4失败仍完整保留，不跨夹具抹掉失败。

Style5保留真实Q下的光晕参数及CT：本地接管、leave同步返回、leave后3秒均与第一次本机原生持有样式一致。`TelekinesisVisuals.reset`源码未通过nativeOwns判断的风险仅是源码推测，本轮加严检查没有复现；没有据此预先修改生产代码。Style5只对第一次意外清除增加条件日志，不强制本地Q跨越原版的距离、法力、受击或资格限制。

最终固定证据包为`build/grip-20261005/final-evidence-c13.json`：49份冻结AS源、stub、所有候选及驱动/测试输入、每端日志、角色复制档、其他模组SWF指纹、exit code和自建PID退出审计。自身4个整文件及GameBridge排除两条R3 targeting后的源码与C13逐字一致；MirrorHitUnit仅本轮noBox纳入C13。runner记录了角色配置生成参数，但旧测试副本自动移除后未保留其他模组config.txt逐文件指纹；最终联合门禁应另外保留配置指纹。

## 推测

C10宿主离线后本地抓持消失的具体原因未得到诊断证据，不能声称是哪一个源改动直接修复。C11增加了实际leave前后及首次指针变更日志；当前首绿只证明这次清理保持了本地抓持，仍安排同字节复测。原生敌人禁用状态会在endSession恢复，夹具后续临时禁用敌人不保证跨断线永久禁用。

C13 Style4的box-host约1653ms清除指针，随后真实重力落地，约2881ms已在支持地板；该轮没有清除前的法力、celDist、pinok等记录，不能归因为原版限制或网络清理。Style5对同字节补记录后未重现这个箱子提前松手。原失败与未归因边界交给联合发布会话，不能以一次绿复跑宣称查清原因。

M45在部分真实存档条件下仍能原生抓起和抛出狮鹫。这里没有复现“所有加入侧狮鹫始终抓不起”，不把之前M43已有红例移用于本轮M45，也不把XML数值修正独自归因为整个症状。

## 尚未验证

- C13 Style4一次本机箱子提前松手的原因；Style5同字节全绿，但不能反向确定旧失败原因。
- RConnect(3)变化合入后的联合源码、最终SWF门禁及用户人工测试，由原RConnect会话完成。
- 本轮范围以外：稳定重连、多于两人、真实外网、其他游戏版本。

## 保留的夹具失败与修正

早期`40ec41bb58`、`394b8065b4`、`f2eb153324`、`57c6f86720`等涉及相机覆盖输入、连接早于读档或原生资源未准备好；不算产品红。`c25416b97f`、`68c628b3fe`在100秒预算内尚未完成原生读档恢复，未进行任何Q/E，改测试等待预算240秒。`5cd3f481d1`的KEY_UP在慢帧原生control前触发会取消输入，改为原生step后的KEY_UP。`b78a62ca90`在持有5.1秒后按E时敌人已自然挣脱，改为仍持有的1秒时按E。未削弱原生规则或断言。

独立狮鹫需要独立身份及接收端准备屏障；初始setup已建round4实例，不能再创建相同id的round4替身。每轮之后仅为新的round5/6创建新原生对象。自然挣脱后不再发送作为“松手”的Q，避免它变成新的抓取。构建、原始源码、失败日志及各版输入均保留，不覆盖旧输入后重新解释结果。

GameCombatStubs只新增UnitAlicorn/UnitBossAlicorn内部teleObj及dropTeleObj声明；native helper通过同包访问真实游戏字段。声明索引以external-library方式使用，没有将游戏存根链接进产物。新索引SHA `636dd6d40422aa524e032cec9c7280f0c28b0fe4a07345688a8d5c32571da551`，旧索引及两种输入保留在`handback-declarations`与早期候选目录。
