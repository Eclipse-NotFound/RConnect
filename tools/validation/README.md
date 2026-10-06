# RConnect候选门禁入口

当前安装 **0.2.17-dev紧凑UI / a5698f9f…**，M45游戏核心。UI681/0、正常无驱动加载4a3257643f绿，见state/deployment-ui-2026-10-06.md。当前工作树M46核心为0.2.18-dev，仍有念力错色及旧匿名Timer红，未部署。

## 已完成UI发行

独立编排ui_release.py只从已验证M45冻结源派生，不使用含M46的工作树核心。最终build/ui-20261006/stable-ui-07保存50源/131验证/49类、四组同字节、22原生PNG与部署/正常加载receipt。生产仅NetHud、新HudLayout与版本变动；17UI不能替代18核心验证。

所有入口用明确UTF-8启动：`python -X utf8 tools/validation/ui_release.py <mode> --snapshot build/ui-20261006/<新目录>`。prepare/build/test/audit/deploy/smoke；每步新输入在启动前冻结，输出不覆盖。当前脚本绑定M45安装起点，已经部署后不再重跑prepare或deploy。首次默认GBK读取deployment receipt在AIR前失败已先回滚，原错误和receipt保留；同字节-X utf8重试正常加载成功。该失败不是UI运行崩溃。

## UI之后的M46核心

- 旧build/m46/integration-baseline仍保存M45；旧final-* / build/m46执行副本/全部失败不改。
- 新build/m46/integration-baseline-after-ui-20261006保存当前UI字节、57保护、UI源出处与正常加载run。只能创建一次，不能用新基线抹去旧失败。
- 正本在本目录执行，**不再复制覆盖旧build/m46脚本**；新freeze冻结所有本目录Python及验证依赖，源manifest记录baseline路径和指纹。validation_baseline.py检查当前输入，拒绝旧M45基线用于新安装、篡改baseline hash、18核心复用17版本、漏掉Hud专项。
- 0.2.18-dev准备冻结build/m46/final-after-ui-01：52源/143验证。仅准备闭包及拒绝守卫通过，没有构建SWF/启动AIR/新增核心绿。若改核心/测试/工具，重新freeze到新目录；不能复用该准备冻结的绿声明。

顺序：新freeze → 显式输出候选构建 → FFDec类清单 → finalize_restore_build → 明确回归入口串行 → 当前不变恢复驱动旧905负控 → audit_final → 备份部署 → 正常无驱动加载，失败先回滚。

1. `python -X utf8 tools/validation/prepare_integration.py baseline`已创建新安装基线；不要重复执行或覆盖。
2. `python -X utf8 tools/validation/prepare_integration.py freeze build/m46/final-after-ui-N`冻结源、AS3测试/存根、正本工具和原真实模板档；目录必须全新。
3. 显式输出候选，不能用默认构建（会写release）。类清单与当前build/GameCombatStubs.swc都按本次编译记录，然后`python -X utf8 tools/validation/finalize_restore_build.py build/m46/final-after-ui-N`。
4. `python -X utf8 tools/validation/run_final_regressions.py --list --snapshot build/m46/final-after-ui-N`只列计划；执行必须明确entry。Motion须传本次冻结的两份profile。14组为原13组加HudTestDoc；导航/慢换图仍可按变化额外跑。不放宽时长/阈值追绿，任一红停后续并即时记journal。
5. `python -X utf8 tools/validation/run_old_restore_control.py build/m46/final-after-ui-N`检查保留旧905实际生产字节；预期严格即时恢复红、两端DONE、实际空mask记录，不把崩溃当有效负控。编译声明来源和当前存根分别记receipt。
6. `python -X utf8 tools/validation/audit_final.py --snapshot build/m46/final-after-ui-N`核对14组/驱动/配置/实际字节/类/PNG/保护/负控。只在全部真绿后更新m46-validation-evidence.json。
7. `python -X utf8 tools/validation/deploy_verified.py --snapshot build/m46/final-after-ui-N`仅替换本模组release，唯一备份；receipt存该snapshot，旧记录不覆盖。
8. `python -X utf8 tools/validation/run_smoke.py --snapshot build/m46/final-after-ui-N`正常加载双端，失败先回滚。无snapshot只用于旧历史global receipt。

恢复PNG规则在../verify_mask_png.py：检测实证的32×24连续近白矩形，不能等同整场景像素一致或所有第三方绘图都合法。149原恢复断言/端＋14即时退役引用断言保留，实时PNG另验。新核心仍须用最终同驱动重新旧905负控。

Java/AIR路径与业务边界见MEMORY；只有当前源/测试/字节闭包及新基线同时满足才可能部署。R2/R3仍只读，root移交具体窗口后才能运行；不同时编译/跑其他AIR，不改用户进程、存档或其他模组。UI关闭/正常部署不算稳定重连修复。
