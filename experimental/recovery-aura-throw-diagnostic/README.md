# aura1 抛掷首轮：有界观测驱动

仅新增 `PeerThrowDamageTestDoc.as`。来源为冻结 `build/m52/recovery-aura-offline-drivers-01/tests/PeerThrowDamageTestDoc.as`，SHA `950fce4ada12525760b5c55c861b9b4188d2b4b5a5c5adf21c2cdcbdb4a52e9e`。本目录源 SHA：`ed115d533b2a7c1600d71ca10ae4c8a9b52b2bc33eab50b02ac47f4cf1a38898`。

保留全部20轮、原属性赋值、真实Q/E、所有屏障与断言、90000ms超时、原监听优先级和50ms Timer。没有调用 `prepareCaster`、重试Q、放宽标准或修改生产。10处文本增量可逆移除后逐字还原冻结源，已静态核对；未编译或运行。

输出前缀 `PEER THROW DIAG`，每轮均有上限：

- 首次Q前后：记录原生技能/perk与派生能力、mana、sost/hp/work/ggControl/t_die/死亡判定、levit/teleObj身份、房间及许可状态。
- 原低优先级 `wireAfter`（-10000）：各记录首个生产 hold/ack/release，完整 input、token/accept/reason/房间标记；同时读取接收端质量、距离、视线、是否已进入levit=2等适格字段。该时刻位于生产默认优先级协议处理之后，**不是接收前原状态**；private retired token/outgoing不读取。
- 首三个holding游戏帧：在原before（99000）改派生属性之前、之后各一次，以及原after（-9500，晚于PeerGrip的-8500）一次。这样可比对临时夹具赋值与原生/模组推进后的值。
- holding等待：250/500/1000/2000/4000/8000/16000ms各最多一次，超时时最后一次，总计不超过8。包含双方抬起标记、held/minY，以区分未抓住、抓住后释放和动作屏障未满足。

字段使用已知接口及 `GameBridge.probe`；观测异常单独写 `PEER THROW DIAG ERROR`，不改游戏控制流。日志自身仍增加少量执行成本，**不用于性能资格或精确净时延比较**。

旧throw01失败保持原状。现有材料尚未证明派生属性重算就是本轮首因；本诊断先保留原夹具观察原因。后续实际运行已改用RV `6dbbae60eb09ff8f42d34e31edc92fb9f83009ba918e9145980c6d289723d8ba` 时，根必须冻结并标明新组合，不能把旧RV83D8的成功资格挪用。
