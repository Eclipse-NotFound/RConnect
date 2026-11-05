# recovery13 动态字段读取：仅小组件证伪

旧 `recovery-probe-fast` 仍为未合入提案。本目录只提取准确 recovery13 的方法；不复制旧版完整 GameBridge，不改加载实验、生产或旧提案。

- recovery13 SWF：`1177eb1ae9b227bcf3c0eb39dedad92b63ac16dcb7ffb0b421ea0a2024bfddb1`。
- GameBridge 文件：`26bb0f7cd4da7c74c83bd2657575823247196c41a861babf23bb40c17fc3cbf7`。
- `probe` / `probeOptional` / `probeNum` 与 recovery01 逐字相同，三张原字段表也相同。逐方法指纹、完整输入指纹见 `extraction.json`。
- 额外 Weapon 13、Bullet 14 字段已在准确 FD92 宿主 ABC 中核对为公共变量，不是 getter；六条继承关系相同。无 JVM 的只读解析证据也在 `extraction.json`。
- `components/probecheck/ProbeBefore.as` 是准确13的真实方法与字段表。After 仅增加27字段的快捷路径；未知 getter、Proxy、原保护读取保持原样。变化见 `methods-only.patch`。
- 替身只模拟 sealed 变量、原生继承与字段类型。游戏引用字段简化成 Object；不执行游戏构造器，不代替真实游戏性能测试。

原语义检查完整保留，结果改为通用组件 runner 接受的 `assertions:[{passed,label}]`，启动/JSON出口/退出都齐全。显式运行六组基准，不再依赖不存在的 marker：新增字段、旧快捷字段、普通/显示对象、Proxy、未命中 Pt、人工混合。每组各暖身10000次，再按 AB、BA 交替6对（3个 ABBA 次序块），每路径每样本60000次；另采样各20000次分配。新增7项只确认六组确实跑完，**不把任何耗时当功能通过条件**。采样器零分配记录不证明零分配。

准备阶段仅完成静态核对。没有编译、没有 AIR 运行、没有收益结论。根会话串行执行下列命令，工作目录为 `mods/RConnect`，`python` 替换成本机已确认解释器：

```powershell
python -B -X utf8 tools/validation/run_recovery_component.py --source experimental/recovery-probe-fast-runtime/components --entry ProbeFastChecks.as --output build/m52/recovery-probe-fast-component-01 --registry-wait 900
python -B -X utf8 experimental/recovery-probe-fast-runtime/run_negative.py --output build/m52/recovery-probe-fast-negative-01 --compile --registry-wait 900
python -B -X utf8 experimental/recovery-probe-fast-runtime/review_results.py --result build/m52/recovery-probe-fast-component-01
```

反例编译先要求合法的同继承/同字段入口编译成功，再要求 `hold` / `babah` getter 替换继承变量被编译器明确拒绝。源码路径、错误类型与字段源码均核对；SDK、依赖或语法错误不算反例通过。该入口只编译，绝不启动 AIR，所有输出限新建 `build/m52` 目录；保留原始失败。

微基准输出逐轮毫秒与每次读取的微秒尺度，不外推整帧CPU。自动摘要采用保守筛选：新增字段和人工混合的中位节省不超过2ms/60000次、少于5/6轮更快，或未命中 Pt 等路径出现回退，则建议搁置。即使筛选过也只有继续原生对照的理由，不是集成或部署资格。人工混合含27个新增字段，权重不代表实际游戏；方法调用、循环和取行开销也计入两侧。

`check_sources.py --freeze` 只做静态核对并生成本目录 manifest。`prepare.py` 只重新提取组件和字段证据；冻结交付后不要在根正在编译时重跑生成器。
