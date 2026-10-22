# CS 离线采集实验：计时读取边界

2026-10-23。根会话仅只读源码审查；本记录没有新的运行结果或性能资格。

候选为 `88CC639E8293FD38DFE4B4855ED2359F2DACF58A8DF18B3F7766B20AE1D0E968`，来自准确 RC574D，来源回执 `0BE07E23517B619520D841B83913EDE88C28142604C6189F8E199C60FC5EC81C`。CS 正准备原生输入20×60帧ABBA；这只回答从未尝试联网的离线采集成本，不回答双人性能。

## 已核查的计时路径

只读 `mods/ContinuousScene/src/ContinuousSceneMotionProbe.as` 当时工作源：

1. 约931行 `now=getTimer()`，写入 `row.frames(now-last)`。
2. 每段第60帧在采样之后执行人口统计、断言和 `save("progress.json",report)`（约1006–1017行）。
3. 随后 `startCase` 约341行记录 `caseBegin`，约411行重新设置 `last=caseBegin`。
4. 下段首个 `row.frames` 含该次 `startCase` 开销，却不含前段最后一次 `now` 到 `caseBegin` 的处理时间。这段期间部分工作由 `probeTiming` 的 census/save/postSample 等列另记。

因此 `rc-offline-combat-run.py` 的 `primaryTiming='All frames; first frame includes startCase and switch cost'` 中，All frames 仅表示选取每段已有的60个样本，不能解释为整个运行连续墙钟均已覆盖。前段末与后段首又跨越开关，不可把所有边沿成本无条件归于单一组。

已一次性向CS反馈：不打断现有测试，保留原始轮及分项；若未冻结可增加连续间隔/时间戳，结果须明确遗漏区间和诊断开销。后续以实际冻结探针和结果为准，不能把当前工作源当作未来运行来源。不要删除边沿帧或旧失败来取得绿灯。

## 后续读结果

- 核对实际冻结源、SWF、配置和开启/关闭计数，防止拿工作源解释另一构建。
- 主表保留切换样本，并明确帧集合与连续全程耗时的区别；不能从总耗时中直接相减重叠的计时列。
- ABBA 内采集历史、AI及地形会变化。必须结合每块结果、实际开火/人口与切换恢复成本，不只看合并平均数。
- 即便离线收益成立，也仍需画面/事件等价和首次联网生命周期验证。该候选不能直接部署或当作双人卡顿修复。

安装 RC574D 已再次读回一致；本次未修改产品源码或安装文件。WB 初始化提案继续等待用户对新修改范围的答复，与这份实验无关。

## 后续收到 r1 实际结果并读回

CS完成 `mods/ContinuousScene/knowledge/experiments/evidence/rc-offline-20261023-native-abba-r1`，根只读核查：84份冻结探针源码、探针SWF、编译配置哈希一致；实际输入RC为88CC，loader显示RC及组合加载成功。1200个分段样本、90项检查无失败，原生输入 `forcedPositionCalls=0`。这是对CS运行证据的读回，不是根另跑一轮。

- 根从原始 `storage/result.json` 重算A/B均值 **66.6483/57.5817ms**，中位63/54，P95 86/77；五块中位差7/10/6/10/11ms。段内集合呈正向线索。
- 玩家射击计数200/200，敌射403/396；不能因此称两组全部AI工作量相同。
- 结束计数mirror跳过600、final跳过1200、eligibilityErrors0，perception未跳过。每B帧两次RENDER观察是本轮计数，不能外推所有场景。
- 真实配置 `noLighting=true`、`noWall=true`、`vision=false`，不代表玩家完整视觉配置或双人条件。
- 冻结探针仍含上述last重置，计时缺口真实存在，结果尚不能作为完整墙钟性能。CS已保留r1，准备连续时间戳r2；不覆盖旧轮。

文件SHA256：result `4ef03c2c9abd312beee8f3877ea5dbf66a19667f5ef0586292bae77c7c8b4e5e`；summary `2c6904fe2c04283df473f7138b01569a29345b9608feadcec14e53759d07ec03`；probe-build `0a0c8801c0f632277b501bc52539774de2a68838297693248c4168f37bb6e825`；runner-inputs `77301fc84fffcbe9df1572cc6da08f0778c44b081282f1db81be78375cb1f1da`。

源审及上述限定证据已集中反馈CS。正式产品不得携带诊断载体/ABBA开关；即便内部收益复验成立，仍需对未改574D及联网生命周期验证。根没有批准合并或部署。
