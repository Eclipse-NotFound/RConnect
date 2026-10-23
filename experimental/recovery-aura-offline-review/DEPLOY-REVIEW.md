# aura1 部署器只读审查

审查对象：`experimental/recovery-aura-offline/deploy.py`，SHA `e689dafe6a05b7860d326b9970911a12ac9abf19b992f587a53c183c0c01d045`。复用引擎为 `experimental/recovery-offline-production/deploy.py`，准确 SHA `11ed24df492ec79ca006f12522361be60ed88be97749239194d26797798b9f04`。

2026-10-23；未执行 audit、编译、AIR 或部署。读取时新组件02、grip01、throw01均无 result.json，仍在共享测试流程中。因此本报告只有代码审查结论，不能被当作新候选功能通过。

## 部署前需要修正的证据绑定

### 1. 组件结果没有绑定本次驱动（第117—124行）

现有检查只读取 `result.json`、`component-result.json` 中的59/0等标量，然后记录 `intent.json` 的当前哈希，却完全没有读取其字段。若 COMPONENT 常量误指向某个旧的59项成功目录，这一段也能通过；历史目录实际存在同样59/0结果，故这不是只针对恶意伪造的假设。

应把该组件运行明确绑定到本次 DRIVERS：

- intent 的 `drivers` 路径、`prepared_sha256` 与 DRIVERS/manifest 相等。
- `component == aura`、`entry == PlayerAuraChecks`、expected_checks 为59；组件产品 SHA 等于本次 DRIVERS/components/aura/Checks.swf，保留 runtime/Checks.swf 也应逐字相同。
- `result.raw_result_sha256` 等于实际 component-result.json；读回每行真实布尔值和标签，核 observed/expected 59。
- intent/install-before 和 result/install-after 都等于本候选审计的22项 baseline；不是仅信任空 installation_changes。
- 同样核组件唯一描述符、1 GiB 启动/512 MiB运行记录、无压力/超时退出及 intent 的原工具指纹。否则新原生运行虽绑定正确，颜色恢复组件仍可能借用旧组合证据。

此项是部署前阻断：目前未证明组件成功一定属于这次 aura1 源和实际运行。

### 2. 八张目检图允许重复或来自旧运行（第125—130行）

目前仅要求 visual-review 的顶层 run 字符串和 candidate 匹配、images 长度为8、observed非空、文件哈希正确。没有核图片路径属于本次真实 grip 运行，也没有去重或对应角色/回合。填写八次同一张图、或把旧 recovery21 的八图列在新 run 标签下，都会过此处检查。

应要求八条路径唯一，解析后恰为 `build/cooperation/<本次grip实际run>` 内的以下八文件：双方 round1/9 的四张 raster-with；join round1、host round9 的各两张 raster-without 和 released。每张保留真实观察说明及哈希。这样才能证明双向四个视角和受抓者移除/释放对照都已实际检查。

此项是部署前阻断：历史八图只能作为参考，不能给新候选视觉资格。

### 3. 原生回执仍有可以直接补齐的原始日志核验（第93—115行）

候选/驱动及双角色输入绑定较完整，但 observed_rounds、failed_checks、errors、done 主要来自结果 JSON；原日志只重计 PASS 总数并搜索 DONE/版本字符串。建议从实际 PASS 行重算轮次集合为0—15/0—19，原始所有日志重新跑现有错误扫描，且无 COOP FAIL；核 result.run_receipt_sha256、intent.drivers 及 result.installation_after。registry-result 也应同时要求 passed 为真且 cancelled 为假。

不必另建框架，可直接复用当前 `experimental/recovery-tests/run.py` 的错误规则和轮次提取。该 runner 实际产生结果时已经做这些检查，本项是避免部署门禁将来只信任被错误聚合的摘要，而非声称当前队列中的测试已经漏检或通过。

## 复用部署主链未见丢失

`engine()`只更换旧模块的 BASE/NEW、CANDIDATE/VERSION 和 audit 函数。Python 函数执行时读取所属模块全局值，因此旧 `deploy`、`recorded_run`、`replace_rc` 实际使用的是 aura1 新常量，而非继续部署 offline1。旧模块 SHA 在加载前固定；没有重新实现另一套复制/回滚逻辑。

保留下列行为：

- 在原 game 登记已取得后，真正替换前再次完整 audit 与 proof 比较；22项安装必须仍等于基线，可提交内存至少6 GiB且没有其他AIR实例。
- 以排他新建写入唯一 `RConnectMod.before.swf`，flush/fsync并核 BASE；不覆盖已有备份。
- 写 release 同目录唯一临时文件，fsync、核源和临时字节，原子 replace 前再次核目标仍等于 BASE；回读正式文件必须等于 NEW。
- 冒烟参数直接 `--candidate <实际release/RConnectMod.swf> --smoke`，没有外部EffectsDriver/测试候选冒充正式文件；两侧核 aura1 版本、tick200，加入侧核welcome/unitsync。
- 冒烟原框架、内存/排他检查、资源/配置/module输入回读以及最后复核都保留；正常返回后还核实际共享登记 passed 且未取消。
- 替换后任何失败恢复本次备份；仅当当前release仍是NEW时回滚，若已经是BASE则保留；遇第三方新指纹拒绝覆盖。登记回调结束后的失败另取得同一资源登记再回滚。
- 其它模组、宿主、config不在写入范围；并发改动若在替换后被检测到，只撤回自己的RC版本，不回写别人文件。

残留临时名称 `.offline1-...tmp`、回滚登记文案“offline1”只影响标签，目标和指纹均从新常量取得，不构成误部署。无需为改标签复制整段部署引擎。

## 当前状态

脚本可解析；真实新测试结果尚未完成，完整 audit 目前应失败关闭。修复前两项绑定后，再由根在新测试和实际八图目检全部完成时执行 audit。此审查不授予密集性能、四项整体恢复或发布完成资格。

## 修订复核：两项阻断已关闭

复核修订 SHA `981ffd43792e72fb17e53f076b6ecbc03f97ca878e67216ce67a367a9fde2199`。以下结论覆盖上文初稿的两项阻断，保留初稿历史。

- 组件已明确绑定本次 DRIVERS 路径与 prepared、aura/PlayerAuraChecks、实际源组件和 runtime 的 Checks 字节、raw结果SHA、当前22项安装前后状态及工具指纹；新增1 GiB启动/512 MiB运行、无超时/压力原因检查。此前旧成功组件误填路径的漏洞已关闭。
- 图像总数8，并要求解析后的路径集合恰好等于本次真实grip目录的八个指定文件。期望集合本身有8个元素，因此长度和集合相等同时保证去重；旧运行图、缺少任一方向/释放对照均不通过。各图哈希和观察说明检查保留。
- 原生部分已从真实PASS行重算0—15/0—19覆盖、重新调用原错误扫描、核run.json哈希、installation_after及registry未取消。未改任何原生测试断言或部署执行主链。

本次只读执行了从修订 `audit` 提取的**组件核查段**，对现有component-02的17份记录/工具文件读回通过；再仅在内存中分别替换驱动目录、raw结果SHA、installation_after和内存压力原因，四种反例均被该原段拒绝。未调用完整audit/部署函数，没有伪造落盘测试材料，也没有启动编译器或AIR。

新的component-02确已实际59/0：result SHA `ce9035bea5400dfdd96602d1fa6c1c7494436cebc0f40cd342a3ab29767c4179`；本次DRIVERS manifest SHA `31293852757cca21b802f493cedfd1ceaaa722b51ca923772cdf4b4bb477a16c`。读取时grip01、throw01仍无结果，图像门槛只能静态审查，尚不能给予原生或部署通过结论。

复核范围内未发现新的部署阻断；根可继续排队执行两项原生回归和真实八图目检。所有证据完整后仍须让完整audit实际通过，不能用本复核替代它。

## RV6DBA 与新生命夹具复核

最新审查 SHA `25107e8b91bb83623640e6b3802b91e5188aa63242141d52031dffb02a6e3b12`。

- `frozen_product()` 逐条保留原 builder.verify 的静态来源、overlay、源树、工具、依赖、编译回执、产物指纹及原安装前后自洽核验，只把“现在的安装必须等于历史构建环境”拆到运行门槛。未改原83D8构建回执。已只读实际调用此函数通过。
- 当前22项安装从历史构建清单复制，只允许准确RV83D8→6DBA；真实 installation 再与此清单全等。只读回读确认实际恰有这一项差异，RC仍EB365。59组件仍绑定原83D8环境和原文件，因它确实不加载游戏/RV，不把历史组件改标新组合。
- GRIP明确指向grip02/989013e148，THROW明确指向待产fixture-native01及独立fixture-drivers01。新源SHA锁定8FDA8D98…27C6B9，原始20轮、旧源SHA、prepared输入、实际编译驱动文件及新准备器指纹均关联；没有让旧首轮失败或诊断失败替代新20轮证据。
- 根新八图记录绑定989013e148，实际唯一路径集合及八个SHA全部只读回核通过。图像内容的实际目检由根完成，本子代理仅核来源和字节。
- 原11ED24DF部署引擎保持不变，proof.baseline改为当前6DBA运行清单后，替换前二次audit、并发变化检查、RC唯一备份/原子替换/失败回滚、直接加载正式release的smoke仍正常继承；其它模组不会被回滚成历史值。

此次未发现新增静态阻断。检查时新驱动prepared已出现，但新THROW的result.json尚不存在，完整audit仍应拒绝；本次没有调用完整audit、构建、AIR或部署。必须由根等待新20轮真实通过后，再执行完整audit与实际安装smoke。
