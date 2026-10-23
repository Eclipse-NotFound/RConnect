# 抛掷 round4 血量重算：证据与新夹具

2026-10-23。独立源码核查；没有运行 AIR、编译、部署或修改历史证据。新测试尚未通过。

## 结论与证据边界

`16edfc422f` 的旧 round4 继续是 FAIL，不能按新解释回判。`build/cooperation/16edfc422f/join.log:165–179` 的 holding / release 期间 hp 为 9000；敌弹控制之后基线 8960，`:190` 失败时为 9955.555555555555，`:195` 原 SAMPLE 保留。后者精确等于 `8960 / 9000 * 10000`。原观察没有 maxhp/器官伤级，故不能声称已直接观测到 9000→10000 的上限变化，也不能确定是哪次调用触发了最后一次重算。

源码已证实旧夹具不一致的机制，足以在新试验前修正：

- 原生 `game-reference/decompiled/1.02/src102/scripts/fe/unit/Pers.as:1945` 的 `healAll()` 只补 headHP/torsHP/legsHP/bloodHP/manaHP，不更新对应 `*St` 伤级。
- 同文件 `:845–847,2164–2166` 每次 `setParameters()` 把总上限重新从 begHP 和等级计算，器官上限重新从 `200 + (level-1)*40` 计算。旧夹具的 `inMaxHP=1000000` 不是持久输入。
- `:2158,2245` 重算保持 `hp/maxhp` 比例；`:2185–2194` 恢复器官比例后仍按既存伤级应用 `traumaParameters()`，后者 `:1984–1986` 使用 torsSt。
- `fe/AllData.as:5870–5872` 的 trauma_tors 一级精确乘最大 HP 0.9。上一轮留下 torsSt=1、下一轮只补器官而没清伤级，配合旧夹具强设 hp=maxhp=10000，就具备重算成9000的条件。
- `Pers.damage:1710–1724` 与 `heal:1878–1888` 会重新从器官数值算 torsSt；damage 的旧值也从器官数值重算，而非读取存下来的 torsSt。因此器官已补满但伤级残留时，伤级可以被更新为0而不在该次 damage 立即触发 setParameters，后续重算才恢复上限。此链与 round4 数值完全一致，实际具体调用仍缺原记录。
- 只读核 `PermanentInjury/src/PermanentInjuryMod.as:93–103`：只有结算真的造成永久损失/词条才走 changed→setParameters；该次模块日志所见事件均 loss=0、proc=false，不能把本次变化归为永久伤残或未证明的回血 effect。

## 新源修改（根已授权此独占文件）

`experimental/recovery-aura-throw-fixture/PeerThrowDamageTestDoc.as`

SHA256：`8fda8d98a52f03d1300ef5c6d51a4501ac5783b18523d2e62bb5ee0ae527c6b9`。

根先前加入的 `PeerAuraFixture.prepareCaster()` 持久技能/15级输入及 Q 前只读资格检查保留。此次仅补生命夹具与健康观测：

1. 每轮开始保留原 begHP=10000，先原生 `setParameters()`，再用公开 `Pers.heal(inMaxHP,4/5)`、`heal(inMaxMana,6)` 恢复全部器官并更新伤级，随后原生重算、一次补满当前总HP，再重算一遍验证一致。没有强设 maxhp、百万器官上限、神模式、飞行中补血或替换伤害函数。
2. 必须确认五类器官/伤级全好、HP=maxhp、两次重算上限不变且不是无敌。原生念力夹具15级对应器官池至少760；原有总血量基数继续保留，真实受伤仍正常发生。
3. 开始→Q→敌弹前必须满血且上限不变；敌弹仍是原生 Bullet 来源、原 `g.damage(40,0,bullet)`，原“确实掉血”断言不变，并新记前后HP/maxhp/全部器官和伤级。敌弹控制后上限也须未变，避免带入另一份不稳定基线。
4. 原20轮、真实 Q/E、至少3帧且上升20px、真实飞行和墙碰撞、伤害开关/中途撤销/原系数/外来接管/共享暂停/旧 release 重放要求都保留。**全部原20个断言文案仍在；原绝对 HP 比较表达式未改，不引入归一化比例通过条件或增大0.01容差。**
5. 无伤负例全过程要求 maxhp 不变；正例墙撞可造成合法新伤级，因此不对正例碰墙后强制同一上限，仍用原绝对HP下降断言，同时记录上限变化。重放窗口仍检查原HP不变，并加相同maxhp检查。
6. 所有原有有界诊断增加 health 对象；每轮健康上限变化最多4行、准备/敌弹/结尾各1行。没有重试Q、调整握手或放宽超时。

## 真实撞墙强度与限制

生产 `rconnect/core/PeerThrowDamage.as` 采用普通系数25、已有正系数61或外来接管37；原生 `Unit.as:3992–4001` 根据 `speed / 12 * damWall` 调真实 damage，并结束 t_throw。持久原生 telethrow 一级力为25，旧临时力为28；这一变化来自根采用既有原生能力夹具，不是此生命修正。`Pers.damage` 的头部器官伤为最终伤害×organMult×organMultPot×2，躯干/腿无×2；与40点敌弹相加，当前15级760器官池比旧实际重算后的200池更能稳定承受本测试量级。没有提高等级、降低伤害或禁用器官受伤来凑通过；最终必须回读实际器官池、伤害、存活和所有20轮。

若新试验的正例确实产生合法伤级，不能只凭 cap-change 日志当产品失败；同时不能只凭 HP下降宣称真实墙伤，仍须原飞行、原生墙到达、敌弹基线、结束归属与系数恢复要求全部通过。若负例上限仍变化，新测试明确 FAIL，继续定位而不重解释为通过。

## 静态核对

脚本只读对比冻结原测试：原20个 check 文案缺失0；十种 CASES 数组及 `round < CASES.length*2-1` 保留；新源无 `maxhp=` 赋值、无百万器官覆写、无 `g.hp/g.maxhp` 比例断言。实际编译/运行由根执行。本文件不更改 `3ebf5d73eb` 或 `16edfc422f` 的失败结果。

## 新20轮真实结果独立回核：46b56c60e3

准确输出 `build/m52/recovery-aura-throw-fixture-native-01`，冻结驱动 `build/m52/recovery-aura-throw-fixture-drivers-01`，生产候选仍 DF0FA0E2…C01E7。2026-10-23由根运行；本子代理只读复核，不再启动AIR。

**实际20轮通过，主/加各222 PASS、0 FAIL；原runner与wrapper均退出0。** 从原始PASS行重新算得双方均完整覆盖0—19；双方DONE，原始所有日志重新跑原错误规则为空。原20类断言继续成立；新增夹具检查没有替代原抓取、碰墙、伤害及清理断言。

- 每端20份准备健康和20份结尾SAMPLE完整、无重复缺轮；实际原生maxhp是10280，器官池760，初始所有伤级0、非无敌、godMode=false。所有40份SAMPLE的maxhp均10280、maxChanged=false，整个运行没有HEALTH changed行。结尾身体器官最小主640.9909/加639.4270，全部伤级仍0；没有靠死亡、回血或上限变化满足正例。
- 每端9次真实E武装、9次敌弹控制、9次退休release重放都通过；每端另外1次drop不武装。18次敌弹实际从10280扣40到10240，原生敌伤未被禁用。20次真实Q分两方向各10次，未引入Q重试。
- 十个有伤正例在敌弹基线后确实额外掉血；八个无伤/撤销/reset飞行负例额外扣血严格为0；两个drop仍10280且armed=0、frames=0。每端的外来接管和共享暂停控制各1轮通过。

| 用例 | 加入侧为受抓者（round0—9）额外墙伤 | 主侧为受抓者（round10—19）额外墙伤 |
|---|---:|---:|
| off | 0 | 0 |
| on | 48.702526 | 48.741213 |
| off-existing | 0 | 0 |
| on-existing | 120.572957 | 119.009102 |
| revoke | 0 | 0 |
| enable | 48.772517 | 48.737708 |
| drop | 0，未武装 | 0，未武装 |
| foreign | 73.137565 | 71.485570 |
| reset | 0 | 0 |
| pause-on | 48.792145 | 48.789982 |

此前失败位置的回读：

- 新round4加入受抓者的基线与结尾均10240，maxhp始终10280；`join.log:220` 原绝对HP禁伤断言PASS。反向round14同样0伤。旧8960→9955.55失败继续保留，不能因新轮通过改写旧结论。
- 新round9的Q前/后均mass12/master1，真实首hold同值、range640000、accel1.6、speed14；宿主首ACK accept=true。加入侧实际飞行并在共享暂停后扣墙伤48.792145，`join.log:412` 原断言PASS；反向round19同样首包/ACK有效。这证明持久技能夹具在本轮不再复现旧mass0.6/master0拒绝，不证明原旧首轮已通过。

证据链：只读调用原 `prepare.verify(runtime=True)` 核113份驱动文件，10个原运行工具指纹通过；实际调用旧 `recorded_run` 校验147份原生输入、配置、日志、描述符和资源。当前22项安装、intent.before、result.after完全一致，准确RV6DBA、RC仍offline1/EB365，生产在外部测试壳内准确DF0FA，不借用旧RV运行。131条内存记录最低10,432,876,544字节，无压力/重叠退出；共享登记passed=true、cancelled=false。结果记录自有host/join/frozen副本已清，三目录实际均不存在。

冻结指纹：

- result：`935cc185002707282e1675cdc91ea269e3516ea9150d4ca14f7e4af81560247c`
- intent：`6abb353190e417433936d1206cebf8651b7d3a3351d8f31d8c05883ffb7e8ce3`
- run.json：`a20a2ed1cb9752939c6970a3680e0da778de4fd321c6e69305863895dd482c82`
- host.log：`f01630f50d3450db448fcc4e84e7ef091f1a135995f83624d4f95b5250f3fe21`
- join.log：`c00f86db96ca354b39793a0436bf9636e07dd48f49fa284872e4a67109eb4583`
- registry-result：`95b84c53b61d1c0713b3b3ed8a4b6c0e3a7e96836ae20dbda4556742a2a5e3c2`

此复核未发现新的产品/原生阻断。资格仅覆盖本次原生双向抓投和个人伤害许可回归，不能扩为高速运动/密集性能通过，且不替代根的完整audit和实际安装smoke。
