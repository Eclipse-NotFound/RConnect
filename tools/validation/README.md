# RConnect候选门禁入口

当前安装 **0.2.18-dev / 04438276…**，保留紧凑浮窗，M46核心已部署。最终14组1648/0、各DONE、旧905负控有效、正常无驱动150秒eb84c49f11绿；见state/deployment-m46-2026-10-07.md。32自有游戏PID退出，其他56保护不变。原念力错色/匿名Timer失败保留，不能由新场景绿反推所有旧因果。

下述脚本固定本次UI17→18验证链，现在直接重跑prepare/deploy会被安装基线守卫拒绝。后续发行建立新的安装基线、版本和冻结目录，不覆盖本轮基线或结果；已完成本轮无需重复运行。

## 已完成UI发行

独立编排ui_release.py只从已验证M45冻结源派生，不使用含M46的工作树核心。最终build/ui-20261006/stable-ui-07保存50源/131验证/49类、四组同字节、22原生PNG与部署/正常加载receipt。生产仅NetHud、新HudLayout与版本变动；17UI不能替代18核心验证。

所有入口用明确UTF-8启动：`python -X utf8 tools/validation/ui_release.py <mode> --snapshot build/ui-20261006/<新目录>`。prepare/build/test/audit/deploy/smoke；每步新输入在启动前冻结，输出不覆盖。当前脚本绑定M45安装起点，已经部署后不再重跑prepare或deploy。首次默认GBK读取deployment receipt在AIR前失败已先回滚，原错误和receipt保留；同字节-X utf8重试正常加载成功。该失败不是UI运行崩溃。

## UI之后的M46核心

- 旧build/m46/integration-baseline仍保存M45；旧final-* / build/m46执行副本/全部失败不改。
- build/m46/integration-baseline-after-ui-20261006保存当时UI17字节、57保护、UI源出处与正常加载run。只能创建一次，不能用新基线抹去旧失败。
- 正本在本目录执行，**不再复制覆盖旧build/m46脚本**；新freeze冻结所有本目录Python及验证依赖，源manifest记录baseline路径和指纹。validation_baseline.py检查当前输入，拒绝旧M45基线用于新安装、篡改baseline hash、18核心复用17版本、漏掉Hud专项。
- 最新冻结build/m46/final-after-ui-clock-05：52源/146验证，0.2.18-dev、123147B、51生产类、SHA044382765a2340ce9babe6f3d01eb61197a438f7d1f9ea70262601535714f042；编译出处clock-01，52生产源及实际产物相同，后续只更换测试/审计输入时如实记录候选复用，不冒充重编译。
- clock-original-02与固定100ms延迟控制均15/3，共享真实RemoteMotion补偿为18/0。14组全部1648/0，旧恢复905负控8221fc329d两端各130/33/DONE、实际空mask；正常无驱动eb84c49f11绿。本轮已部署，全部源/实际字节/测试/配置/日志/PNG/保护/负控/进程/部署证据在m46-validation-evidence.json。
- Beam固定300→60产生真实240伤害请求、SATS固定远距look0/近距look20、Projectile旧fireAt提前移除使31个真实闪电事件帧全空，各有同生产字节的复制红/绿对照。只修正式测试前提，原断言/时窗保留；全部旧失败和复制输入不覆盖。对应控制由audit_final核对实际生产/驱动/日志与源差异。

顺序：新freeze → 显式输出候选构建 → FFDec类清单 → finalize_restore_build → 明确回归入口串行 → 当前不变恢复驱动旧905负控 → audit_final → 备份部署 → 正常无驱动加载，失败先回滚。

1. `python -X utf8 tools/validation/prepare_integration.py baseline`已创建新安装基线；不要重复执行或覆盖。
2. `python -X utf8 tools/validation/prepare_integration.py freeze build/m46/final-after-ui-N`冻结源、AS3测试/存根、正本工具和原真实模板档；目录必须全新。
3. 显式输出候选，不能用默认构建（会写release）。类清单与当前build/GameCombatStubs.swc都按本次编译记录，然后`python -X utf8 tools/validation/finalize_restore_build.py build/m46/final-after-ui-N`。
4. `python -X utf8 tools/validation/run_final_regressions.py --list --snapshot build/m46/final-after-ui-N`只列计划；执行必须明确entry。Motion须传本次冻结的两份profile。14组为原13组加HudTestDoc；导航/慢换图仍可按变化额外跑。不放宽时长/阈值追绿，任一红停后续并即时记journal。
   独立夹具变更时，carry_same_byte_checks.py只允许已完成的八个入口：生产源/SWF、所有编译与运行依赖、存根、角色档、配置必须一致，并实际导出driver类表确认不含改过的测试类。只有审计工具变化时也须全新冻结和同样核对；收据明确“保留旧运行”，保留origin递归出处，不增加运行次数。改过的入口必须重新运行，不沿用旧绿。
5. `python -X utf8 tools/validation/run_old_restore_control.py build/m46/final-after-ui-N`检查保留旧905实际生产字节；预期严格即时恢复红、两端DONE、实际空mask记录，不把崩溃当有效负控。编译声明来源和当前存根分别记receipt。
6. `python -X utf8 tools/validation/audit_final.py --snapshot build/m46/final-after-ui-N`核对14组/驱动/配置/实际字节/类/PNG/保护/负控。只在全部真绿后更新m46-validation-evidence.json。
7. `python -X utf8 tools/validation/deploy_verified.py --snapshot build/m46/final-after-ui-N`仅替换本模组release，唯一备份；receipt存该snapshot，旧记录不覆盖。
8. `python -X utf8 tools/validation/run_smoke.py --snapshot build/m46/final-after-ui-N`正常加载双端，失败先回滚。无snapshot只用于旧历史global receipt。

恢复PNG规则在../verify_mask_png.py：检测实证的32×24连续近白矩形，不能等同整场景像素一致或所有第三方绘图都合法。149原恢复断言/端＋14即时退役引用断言保留，实时PNG另验。新核心仍须用最终同驱动重新旧905负控。

Java/AIR路径与业务边界见MEMORY；只有当前源/测试/字节闭包及新基线同时满足才可能部署。R2/R3仍只读，root移交具体窗口后才能运行；不同时编译/跑其他AIR，不改用户进程、存档或其他模组。UI关闭/正常部署不算稳定重连修复。
