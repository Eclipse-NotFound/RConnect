# M46联合候选门禁

这里保存本轮实际使用的门禁脚本；执行证据与冻结输入留在`build/m46/final-*`，可再生SWF不入Git。当前final39正在验证，尚未部署。

本轮执行的是`build/m46/`的冻结副本。下次继续或更改门禁时，先核对这里的正本与执行副本；把这七个脚本按原文件名复制到`build/m46/`，不要更改已冻结目录。旧`refreeze_diagnostic.py`是特定旧轮次的历史工具，不作为通用入口。路径根均为脚本向上两级，两个位置都指向模组根。

流程：新目录freeze→显式输出候选构建→FFDec类清单→finalize_restore_build→明确列出回归入口→audit_final→仅本模组备份部署→正常加载冒烟，失败先回滚。不能用构建默认输出（会直接写release），不能覆盖失败目录/driver，不能同时运行其他AIR测试或构建。

- `prepare_integration.py freeze build/m46/final-N`：冻结源、所有AS3测试/存根、执行工具、真实复制模板档；新目录不得存在。
- `finalize_restore_build.py build/m46/final-N`：构建后核对类清单与源的逐文件指纹，记录候选/存根来源。
- `run_final_regressions.py --list --snapshot build/m46/final-N`：只查看13组必需门禁。执行须列明确入口；Motion须传冻结目录中双方模板档。可分批串行，任何红停后续组并即时记journal。
- `run_old_restore_control.py build/m46/final-N`：用当前不变恢复驱动检查保留的905旧候选；预期严格即时恢复断言失败且两端DONE，不把程序崩溃当作有效负控。当前decl来源final13、旧实际编译来源final9、编译用当前已冻结存根在receipt分别记录。
- `audit_final.py --snapshot build/m46/final-N`：独立核对13组退出/原始日志/驱动/模块与配置闭包、旧负控、实际PNG白矩形、50生产类与保护文件。通过后写m46-validation-evidence.json。
- `deploy_verified.py --snapshot build/m46/final-N`：必须有已审计证据和既有部署授权；备份唯一命名，仅原子替换本模组release，不改游戏SWF/描述符或其他模组。
- `run_smoke.py`：正常无驱动加载双端、版本和网络心跳，失败立即还原备份再报告。

恢复的实际PNG规则实现位于`../verify_mask_png.py`：捕捉已实测的32×24连续不透明近白矩形，不等同整场景逐像素一致，也不自动保证所有第三方绘图合法。原149项/端恢复断言＋14项即时退役引用断言保留，真实PNG另验。F39根生产DEBUG已删除。

运行所需Java/AIR/编译器路径及实验边界见MEMORY和`knowledge/experiments/2026-10-06-m46-native-mask-restoration.md`。当前安装M45保护基线不可覆盖。发布后更新这里的状态说明及MEMORY/journal/changelog；游戏内UI仍只规划。
