# A animfix1 卡顿回归窄修正

来源为准确安装 2C49 / `build/m52/a-live-animation-product-04`，没有使用过期的顶层 src 或 B 候选。用户已确认本次反馈来自 A。

仅三份覆盖源：

- UnitPresentation：结束但无 flight 的记录也从捕获开始进入原有 700 ms 清理窗口；活弹、未捕获末态不提前清除。
- ProjectileVisuals：新完整历史覆盖旧历史且没有丢终态／爆炸时直接复用；连续后缀与缺失终态仍合并，接收播放不修改入包。
- RConnectMod：版本 `0.2.24-animfix2`。

当前候选 `build/m52/a-stutter-repair-02/RConnectMod.swf`：`f14a44e74ac98ec480875203d4d714acfbc496141980e5a1d7b0de0c7ad222fb`。`build.py --output <新build目录>` 构建，`verify.py <该目录>` 只读检查定义和准确来源。两个脚本不部署。实际安装状态以本轮 state 报告及部署回执为准。

## 已有证据

`experimental/a-stutter-investigation` 是独立真实游戏驱动；产品不内嵌驱动。定点原生爆炸 11bf552a4e（2C49）与 9655519e55（F14A）：均7次火箭爆炸、56个真实无视觉伤害辅助对象，原生链末段均归零；旧版联机记录仍56，候选归零，候选峰值8。证据和适用边界见 `state/a-stutter-investigation-2026-10-28.md`。

双向玩家枪械旧78C、当前2C49与首个实验候选F278已跑。首候选还试了移除时补采显示终点；由于原生子弹本来也有命中停留，实测没有支持明显改善，已从本目录最终覆盖源撤出。完整实验源仍保存在 `build/m52/a-stutter-repair-01`，不覆盖或删除其结果。当前候选没有改变轨迹点、播放时钟、发包频率或战斗规则。

最终资格不能用“完成测试场景”代替流畅度结论。只有确认无错误、实质发射与远端显示、记录退休后才交付对应修复；密集战斗总体帧率和用户全部卡顿仍要区分。

## 实际部署

2026-10-28 已部署 F14A / animfix2。事务 `build/m52/a-stutter-deploy-a3a3e26e/deployment.json` 为 verified，旧2C49备份是同目录 `RConnectMod.before.swf`，实际安装SHA与候选一致。仅RConnect SWF更新，宿主和配置未变。

`deploy.py --player-run 07da49464b` 复用了真实爆炸生命周期及该轮两个晚段的双方移动／跳跃／持续射击数据，逐项核实实际位移、发射数、远端可见与无复活状态。早期input阶段主侧开场复活造成零位移，明确不计通过；原始失败保留。driver04补充双方自然控制就绪检查，但新轮feac0dd1d2排队超时未启动AIR。窄部署资格来自同一F14A已经存在的有效晚段，不来自超时或降低检查要求；不授整体性能或全部弹道已流畅结论。

部署采用唯一备份、旧／新指纹校验和原子替换，失败回滚也先校验临时副本再原子替换。`review_audit.py` 保存误把已有访问桥判成原生存根后的只读复核，原失败记录未覆盖。
