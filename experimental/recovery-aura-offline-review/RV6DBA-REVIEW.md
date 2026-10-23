# 新 RV 基线与第二轮光晕回归审查

2026-10-23。只读回核新原始结果与冻结代码，未编译、运行 AIR、改部署器或安装文件。本报告不把尚未完成的抛掷诊断当作通过。

## grip02：新组合实际591项通过

`build/m52/recovery-aura-offline-grip-02` / `989013e148` 的原始日志重新计数为主296、加295，合计591；双方0–15轮完整、零FAIL、DONE、aura1版本与连接证据完整。重新调用原 `errors_in` 检查两侧普通/stdout/module日志均为空；每份日志SHA与回执相符。

候选仍为 `DF0FA0E2…DC01E7`。已回读129份冻结驱动文件、10份工具、原input/run绑定；原部署器的只读 `recorded_run` 以准确候选和**真实新运行基线**核过147份文件，包含宿主、所有模组、角色配置与原生驱动/生产绑定。没有调用部署或完整audit。

- 22项安装前后完全一致；本次读取当前安装也与它们一致。
- 相对产品编译时基线，仅 `mods/RealisticVision/release/RealisticVisionMod.swf` 从 `83d8e590c062e181b70bd5cabef2200084d5e81aaca081d1d1ebc347205c7e65` 变为 `6dbbae60eb09ff8f42d34e31edc92fb9f83009ba918e9145980c6d289723d8ba`。
- 两侧实际runtime RV都为6DBA，未作override；RC正式文件仍EB365，测试隔离副本加载准确DF0F生产候选。
- 私有桌面、启动前无其他AIR、6GiB启动/512MiB运行保护均保留；126份内存样本最小可提交余量12,379,099,136字节，没有内存或重叠中断。登记passed=true/cancelled=false；结果记录自有host/join/frozen副本已清理。
- 本次未重新目检八张图，不能将此文当作“新8图已审”。新目录确有16张原生图，最终视觉审查必须绑定这次运行。

关键回执SHA：

| 文件 | SHA-256 |
|---|---|
| grip02/result.json | `209c89f36704fa2dae14346d14ed65d9c2be6c889c396ce33410c53a37cf43de` |
| grip02/intent.json | `e8104399ad2b08279c53621aa74d92590f6538dd058344fd2f970908973636a7` |
| 989013e148/run.json | `baeb6b8f9c43f9a58eee014809e5c58768566edf3a610900b1fb65acca1f7031` |
| 989013e148/host.log | `4467055639c0e0c0df9da24687d54506998858ac7642a3b56c4cbd32ce3651e7` |
| 989013e148/join.log | `12b6fec09604774bceaa538dd01fee0aefe00bcc8281b71dcf79b3cbaeaf5f44` |

## 新诊断 prepare.py 静态审查

审查对象 `experimental/recovery-aura-throw-diagnostic/prepare.py`，SHA `74a46d7995a694eb661cac31d8beeea59a9d6672bcf56edc28534e3ddc30075f`。未发现编译准入阻断，未执行该脚本。

- admission先核候选及原配方/模板，原freeze创建全新输出；唯一诊断AS在首次编译前换入，固定本子代理交付的 `ed115d53…1a38898`，更新新prepared的inputs，并增加diagnostic_overlay及原模板指纹。没有重写旧drivers或失败回执。随后原verify读取的即实际要编译的完整字节。
- 仅PeerThrowDamageTestDoc，20轮配置沿用原配方；组件选择为空。三条Java命令固定compc→mxmlc→mxmlc，原外部声明、harness、生产绑定及编译检查均由原配方负责。
- 所有三条编译命令使用共享登记，启动前1GiB检查、原 `wait_owned` 的512MiB/300秒保护、无窗口启动、自有PID登记，finally回收并记录退出码。原Registration类在结束时恢复；完整命令数和成功/回收状态最后再校验。
- `admission.inputs()`不要求当前安装仍是旧RV，它检查的是**既有产品的构建材料**，这一点适合只编译外部驱动；后续运行器仍须冻结真实6DBA组合。此处不能增加一个伪造的旧安装返回值来“通过”构建检查。
- 新manifest明确记录overlay来源，原source_recipe仍是复用配方SHA；部署审查应同时绑定新prepared、diagnostic_overlay、实际EffectsDriver及新运行intent，不只看source_recipe这个字段。

## 部署入口应精确分离两种基线

当前 `experimental/recovery-aura-offline/deploy.py` 仍把 `builder.verify(PRODUCT)`、原生运行和组件全部绑定到同一个旧installation_before。RV正常更新后，这会准确地拒绝现状；**不能通过改写历史prepared/compile、替换旧RV或伪造installation()输出来消除拒绝。** 建议只在新部署审查入口明确以下区分：

1. **历史构建核验**：保留产品prepared/compile的原始83D8环境记录及SHA。复用 `builder.base_check`、inventory、deps、sha等只读函数，核基底、78份源、工具、overlay、source.diff、candidate、编译回执和artifacts；唯独不把“今天安装仍等于当时安装”混为构建完整性要求。原compile必须仍自洽为当时before=after，且无构建期间变化。旧builder代码及历史收据不改。
2. **当前运行/部署基线**：从新grip02 intent取真实22项，先断言它相对历史构建恰好只有RV这一个差异，旧值精确83D8、新值精确6DBA，RC仍EB365，其余21项相同；再核当前安装严格等于该新基线。不能接受任意模组变化、忽略整个installation字段或只比较RV。
3. **原生与实际安装冒烟**：GRIP必须绑定02/989013e148及新八图；THROW必须有同候选、同6DBA组合下完整20轮真实通过；现在仍不能授予资格。每项可以各有自己的精确DRIVERS/manifest路径，不能让新诊断throw误绑定旧grip的单一DRIVERS。实际release smoke与旧原子部署引擎都传新运行基线，仍只允许RC从EB365变DF0F，其余21项保持新基线。
4. **无游戏的59组件**：可保留component02的真实旧83D8前后安装快照，其59条实际结果、源/Checks/runtime绑定、工具与内存检查全部继续核对。已再次确认原结果及原raw `gameLoaded=false`，组件runtime只有application.xml与Checks.swf，原runner只启动Checks。组件没有加载RV，故不需要把环境字段改成6DBA，也不借它证明与新RV联动成功。组件历史安装前后应仍等于历史构建基线；当前安装独立按第2项检查。
5. **原子部署保障不变**：旧引擎继续在共享登记后重算完整audit/proof、再次核当前22项、排他备份、原子替换、实际release冒烟；出现失败只回滚本次RC，不回滚用户RV。返回proof可同时明确 `build_baseline` 与 `baseline`（当前运行），避免后继误读。

本报告确认新RV光晕16轮功能回归以及新诊断准备器的静态边界。仍不授予抛掷20轮、新八图、安装冒烟、密集性能或四项整体修复通过资格。
