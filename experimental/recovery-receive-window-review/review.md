# recovery20 窗外收包路径：限定只读复核

**确认长采样窗内有实际解码和状态应用工作，但不能确认单次回调积压了多少包。** 唯一保留的可验证问题是：长窗是否由同一次 `onData` 连续处理多份相同房间状态构成，还是正常的一组快速/完整状态加其它工作。本次不提出丢包、降频、只留末包或新的生产候选；不编译、不运行。

准确候选为20 `0674019c…CE9F5`；原轮次 [b3d7b8558b/join.log](../../build/cooperation/b3d7b8558b/join.log)，外层 [cpu-profile.json](../../build/m52/recovery-after-render-sampler-20-01/cpu-profile.json)。原功能失败保持，不把诊断帧率当验收。

## 最长3个完整有样本窗与短窗

只按原 `stop-start` 排序；原始数组索引从0计。24个有样本窗均完整；以下六窗 stackOverflow/depthTruncated 均0，extraRenders均1。包含CPU样本相互重叠，不能相加，也不是包数或毫秒。

| 索引 / phase-frame | 窗长 | CPU样本 | onData | unpack | 完整单位应用 | 快速动作应用 | 探索应用 | 停采后整理 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 448 / 6-11 | 182 ms | 198 | 144 | 39 | 30 | 21 | 0 | 111 ms |
| 388 / 5-21 | 162 ms | 156 | 122 | 26 | 21 | 16 | 26 | 217 ms |
| 458 / 6-21 | 157 ms | 151 | 121 | 34 | 25 | 18 | 0 | 102 ms |
| 453 / 6-16 | 42 ms | 29 | 0 | 0 | 0 | 0 | 0 | 3 ms |
| 15 / 0-16 | 41 ms | 24 | 0 | 0 | 0 | 0 | 0 | 2 ms |
| 65 / 1-1 | 40 ms | 24 | 0 | 0 | 0 | 0 | 0 | 3 ms |

最长窗实际区间分别126665→126847、119815→119977、127875→128032。三者都有 `ByteArray.readObject ← BinaryMessageCodec.unpack ← TcpLink.onData`，以及 `applyUnitsSync`、`applyEnemyMotion ← Session.handleMessage ← onData`；第二窗另有探索合并。短窗主要是原生 `[pre-render]/[render]`，有少量最终显示修正。**所以至少能区分长窗含完整包与快速包两类路径**，不是只看到一个笼统的 onData 名称；但不能由此推断它们属于同一个 onData 调用。

长窗仍含实际渲染样本，不能把全窗或全轮811/1614包含样本全归网络。整理发生在 pause之后，不属于表中采样窗；111–217 ms整理本身会影响后续游戏调度，所以这轮的后续到达密度也不能直接代替普通无诊断运行。

## 代码上会怎样处理多包

[TcpLink.onData:161](../../build/m52/recovery-20/src/rconnect/net/TcpLink.as:161) 先把socket现有字节读入缓冲，随后while遍历所有完整长度帧，每帧解码后同步 `dispatchEvent(MESSAGE)`，返回后再读下一帧；不足半包才停，最后压紧未消费字节。**单次onData处理多份消息确实可达，没有包数/耗时让出条件。** 这只说明机制，不证明本轮最长窗实际发生了多份同类积压。

[Session:502](../../build/m52/recovery-20/src/rconnect/core/Session.as:502) 的快速 WORLDSTATE 与 [415](../../build/m52/recovery-20/src/rconnect/core/Session.as:415) 的完整 UNITSYNC 都会应用敌人motion/grip并入队姿态。若同一原生时刻的快速包与完整包依次到达，会再经过相同单位的这些步骤；若连续几份时刻不同，则它们本来就是轨迹中的不同点，不能称为无效重复。

| 路径 | 重叠部分 | 仍必须保留的不同语义 |
|---|---|---|
| 快速动作 `applyEnemyMotion` | motion/grip字段、queueUnitMotion、姿态历史 | 旧时刻拒绝；本地抓取保护；bodyEffects与该时刻visual；effects增量弹体事件。WORLDSTATE还含队友状态、掉落物轨迹和墙痕更新，不能只按敌人位置挑末包。 |
| 完整单位 `applyUnitsSync` | 相同motion/grip及姿态入队 | 先收本地待结算伤害；HP/护甲基线、存活集合、死亡、炮塔权限、碰撞/命中代理、外观/视野、完整武器事件；外层还负责单位/门箱存在性、破坏、出生掉落、地图进度与累计修复。 |

[RemoteMotion.pushTimed:147](../../build/m52/recovery-20/src/rconnect/game/RemoteMotion.as:147) 已拒绝倒序，等时刻只替换最后snapshot，不追加历史或重启时钟。但 [queueUnitMotion:5897](../../build/m52/recovery-20/src/rconnect/game/GameBridge.as:5897) 在push后仍按当前显示时间采样并设置位置；这并非“把所有同时间包整个忽略”，也不能改成如此：完整包可以补充快速包没有的武器/防御/终态。同房间/epoch、等时刻、相同位置均不足以证明整条状态可删除。房间事务、ACK与伤害回执另有顺序/身份语义，本次不将它们纳入合批建议。

## 当前证据只缺哪一步

既有外部驱动 [message:285](../recovery-after-render-sampler/tests/SustainedDensityTestDoc.as:285) 只把UNITSYNC数量累计到8秒阶段，并保留最后一个diagPacket供结束后探测；没有每个CPU窗的消息类型/数量、字节量、tick/sampleTime，也没有onData调用序号。`binaryReceived` 是全连接累计，现日志没有窗口首尾读数。稀疏的“unitsync matched”日志也不能补出精确包数。因此目前不能区分“一个完整包本身重”与“连续多个完整包重复应用”，不能断言处理积压是根因。

若根会话继续验证这个**单一问题**，最小证据是沿已有MESSAGE观察点记录每个诊断窗内按类型的包数与时间戳范围，不记录大payload、不改变发送/应用；这足以判断同窗是否多份完整状态。若还要断言“同一次onData批次”，必须额外有准确回调边界，不能把同窗当同回调。本次只指出所缺证据，没有添加观察器或改变采样范围；墙面编码/解码已交独立审查，不在这里重复提出改动。

## 输入与状态边界

- 原join.log SHA `2b9575e9f3ef4c66a1e7c85a30aa8019468320963bb7a45f7e46c1cd2aab5ef7`；cpu-profile SHA `4a93606310c5f0919d0261ca66fbc7dd102761b49e5ce5fcfa1facdc864b1049`。
- 本轮 [只读进程状态](../../build/m52/recovery-after-render-sampler-20-01/process-policy-readonly.json) 已实际读回两侧 `control_mask=0,state_mask=0`，SHA `d18f0c95efac165cb92a4f092be54c3c3280159ef473a53235bc8c93ca3ffcd6`。这说明没有该接口的显式控制位，不能证明Windows实际实施了节流，更不能把它当本次长窗成因。
- 没有新的正确性缺陷或可直接部署的优化结论；只收窄了“有真实网络CPU工作”与“多包积压是否主要原因”的证据边界。
