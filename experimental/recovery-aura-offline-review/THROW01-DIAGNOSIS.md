# aura1 抛掷首轮超时：只读诊断

2026-10-23。原失败 `build/m52/recovery-aura-offline-throw-01` / `3ebf5d73eb` 保留：主4 PASS/1 FAIL、加3 PASS/1 FAIL，均在 round0 的 holding 超时，未进入 flying。未运行 AIR、修改产品、驱动或断言。

**目前不能确证“测试握手竞态”，也不能把主侧 Q 成功当成对侧已经被抓起。可以明确定位的是：测试流程已经越过准备握手，卡在本地 Q 之后、双侧实际抬起屏障之前；与已过16轮的 grip 相比，throw 仍使用不持久的能力夹具，且没有首个 hold/ack 证据。** 应先修正/核实这一测试前提，不为超时改生产许可或放宽抬起断言。

## 原始证据与握手

- `build/cooperation/3ebf5d73eb/host.log:37–38` 已 `holding` 且 `native Q takes permitted peer`；`join.log:29` 也已 `holding`。后续双方只有普通 tick/unitsync，未见 `flying` 或 `PEER THROW SAMPLE`；双方自己的90秒超时都生效。
- 冻结 `PeerThrowDamageTestDoc.as:99–117,216–219` 的顺序是：两边 `settled` → 主发 `grab` 并执行一次 Q → 两边分别等待 `held>=3 && minY<baseY-20` → 两个 `lifted` 才开始动作。收到 `grab` 不会重置 held/minY；准备阶段 `localReady/peerReady` 任一先到都能进入 holding。首轮不存在前一轮迟到包；当前日志也没有重复 holding、重新 start 或 phase 回退。**未发现可以解释本轮的准备握手丢失/重置路径。**
- holding 中主/加普通 tick 坐标分别持续 `(1360,640)`、`(1480,640)`；后者未见抬升。稀疏 tick 不能排除短暂抓住又释放，更不能判断具体拒绝原因。
- `PeerThrowDamageTestDoc.as:98` 只接收测试协议，`wireAfter:123–132` 仅在 flying 观察 release，holding 时不会记生产 `peer-grip hold/ack`。因此原日志无法区分“根本没发 hold”“被拒绝”“短暂接收又结束”，也不知道本地 held/minY 的终值。缺这层证据不能称已经证明产品抓取失败。

## 与刚通过的 grip 的实质区别

同一 aura1 的 `f871ad9d98`，grip 的主 round1 有原生 Q 成功、对端 ack accept=true、双方抬起屏障，源抬升约147.2px。该结果证明此候选存在真实双侧抓取成功路径；不覆盖 throw 使用的另一套夹具。

1. `PeerGripTestDoc.as:84` 调用 `PeerAuraFixture.prepareCaster()`：真实技能 tele14/magic20、等级15、telemaster/telethrow perk；安装时重复两次原生 `setParameters()`，核能力不变。真实日志 `host.log:35` 的参数为质量12、距离640000、master1、force25。其 before 不反复改派生能力。
2. **throw 完全没有调用这个已存在的 helper。** `PeerThrowDamageTestDoc.as:86–87,140–141` 仍在 start 和高优先级 ENTER_FRAME 直接写 `maxTeleMassa=1000,teleDist=1000000,telemaster=1,throwForce=28,...`。原生 `Pers.setParameters:2164` 调 `defaultParams()` 再按真实技能/perk重算；这些临时赋值并不是持久技能。虽每帧重写，生产50ms Timer 收包/发包不保证夹在该写入和下一次重算之间。这是明确的夹具不稳定条件，**本轮是否真的在首包被覆盖，缺少原数据尚未证明。**
3. 已过 grip 在 Q 边界只读检查能力，并观察首个真实 hold 的能力及 ACK；throw 只检查 `g.teleObj===ghost`。原生 `UnitPlayer.actTele:1790–1830` 成功只设置本机目标，生产抓取协议在随后 `PeerGrip.after:121–132` 才发送。接收端 `PeerGrip.receive:160–175` 仍会检查本人是否活着、许可、质量、距离、mana、token 等；源 `after` 也会因死亡状态丢弃目标。故局部 Q PASS 不足以排除此后一阶段失败。
4. throw 日志从准备之前就有宿主 `lbl=die`，holding 后仍是该标签；但 `sost=1`，没有 `world.t_die`。`GameBridge.isPlayerDead:1285–1295` 实际检查 sost和t_die，不检查动画标签。只能保留“夹具可能经历过死亡恢复”的线索，不能用 die 标签直接定因。

## 建议给根的最小下一步

在**新冻结的 throw 驱动**安装阶段复用现成的持久 `prepareCaster()`，移除那两处每帧/每轮覆盖派生念力能力；在第一次 Q 边界复用只读能力检查，并最多记录首个 hold、ack、以及超时时的 held/minY/teleObj/levit/死亡状态。无需修改产品或设计新测试框架。原20轮、双侧 `held>=3 && rise>20`、真实 E、墙撞伤害及重放防重复断言全部保留；helper 自然 throwForce25与旧临时28不同须明确记入新夹具，不能暗称完全相同输入。失败01不改判，也不靠重试 Q 掩盖原失败。

生产 PeerGrip 相对 offline1 的 diff 仅增加光晕采集/展示/清理，未改上述资格、hold/release握手或运动分支。本轮两日志没有 `RConnectPeerGrip: failed`，但缺包/状态记录仍不足以完全排除新增展示调用影响。修好夹具后必须真实重跑，现有光晕16轮通过不能替代抛掷20轮资格。

## 冻结指纹

- throw结果：`b43c3934b969897fdca2d68402286bcc6767dd28df685ced3ff1bd8e61b23874`；run.json：`1378a36a2f1d47332c1d5a6845e8f05175000a3416da3a94f89f90d6662422f3`。
- host.log：`242457d83d7269a3927588beac5586f6f08c4fed61269db3438665c145831cdd`；join.log：`785158caed819a4f77578a64044a0ba4e636f2457ca71c077329910e9dcefbfd`。
- 冻结 `build/m52/recovery-aura-offline-drivers-01/tests/PeerThrowDamageTestDoc.as`：`950fce4ada12525760b5c55c861b9b4188d2b4b5a5c5adf21c2cdcbdb4a52e9e`。
- 同目录 `PeerAuraFixture.as`：`39f0fec0b90fdcf5afb6388cf55fd476f4092ccaf0ae1d97e36fc9d28fffda4c`；`PeerGripTestDoc.as`：`9cf5f556abbb8053a3221375c420a2b8f34566c3ba859687cee7bca4b31da598`。
