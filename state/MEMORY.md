# RConnect —— 开发记忆入口

> 新会话从这里开始。协议见工作区 GOVERNANCE.md §8；本模组参数见 ../AGENT_SCOPE.md。

## 1. 这个模组是什么

互联网联机模组：安装了 RConnect 的玩家通过 TCP 直连（IP+端口）一起游玩。**核心卖点：加入方无需准备与房主一致的存档，用自己的角色共同游玩房主世界**。宿主权威：客户端上报玩家状态/伤害/交互，房主结算并同步；默认 tickMs=50 时玩家状态约 20Hz，单位/场景快照每 4 tick（5Hz），WORLDSTATE 还会在收到玩家状态等事件时广播，不能统称 5Hz。入口类 `RConnectMod`（swf-version 38，AIR 专属 API，必须 amxmlc 编译）。

## 2. 用户偏好与协作约定

- **已获授权（2026-08-15）**：补丁三份游戏 SWF 加装本模组 loader（决策见 decisions/2026-08-15-load-patch.md）；版本策略 = 尽量兼容 1.02/1.03/1.04。**新方案涉及改游戏本体内容（如种子替换）必须重新确认授权**。
- **改游戏文件前必查**：与 `build/backup/current-merged-20260819/` 基线哈希比对（他人改动先合并，绝不直接覆盖）。
- **绝不碰用户真实存档**（%APPDATA%\pfe\）；测试用临时 app id（pfe2/pfe3）+ 存档模板只读复制。
- **不干扰用户游戏实例**（命令行含 `application.xml -nodebug` 的不动）；测试实例用 `app_rconnect_test_*.xml`。
- 跨模组 bug 只报告不修复；shared-knowledge 贡献仅限"删除本模组后仍成立"的知识。

## 3. 当前状态

- **0.1.0 开发版，代码已至 M27**（2026-09-07）；2026-09-10 接手代码基线 master / `a32633f`，接手前工作树干净。M1–M27 各有历史验证记录，不能理解为所有边界均通过。
- 已实现：互见/外观/武器、房主世界注入、双向战斗、死亡复活、换图跟随、聊天、配置限定的重连、探索迷雾、瓦片/物品/门容器同步；M26 加念力位置平滑与落点防越界，M27 强制显示房主快照中存活且非隐身的匹配单位。
- 最近历史双实例验证为 2026-09-07（M26/M27）：门/箱双向同步、敌人可见性采样通过；真人观感仍待确认。2026-09-10 仅静态接手，未构建/启动/部署，也未重新核验当前三份游戏 SWF 的 loader。

## 4. 正在进行与卡点

- **等真人体验测试**（双开/邀请朋友手动联机，反馈幽灵标签/透明度、换房跟随手感）——当前无真人测试条件。
- 记忆原先落后于 M26/M27，现已补齐；最初 architecture.md 仍是 M4/M5 阶段蓝图，不能代替当前实现说明。目标与覆盖表见 state/handoff-2026-09-10.md。
- 当前证据主要为同机双实例，不能据此宣称三人以上、公网延迟场景或三版本全功能矩阵均已验证。完整任务/脚本进度与背包/交易规则也没有充分的目标及验收定义。
- **Steam 校验风险（2026-09-06 实发）**：Steam 曾于 09-06 05:46 还原三份游戏 SWF 抹掉全部 loader（症状=读档 #1009 Invent.addLoad + 模组日志零新行）。恢复路径已演练：build/backup/steam-restore-20260906-0546/ 存 Steam 原版，current-merged-20260819/ 存合并基线，按 remains-game-update 技能覆盖即可。再次发生照此办理。

## 5. 已知问题

- NAT：MVP 直连需端口转发（远期公共中转服务器）；
- M3 遗留：动画阈值（run≥6px/walk≥1px）按真实联机观感校准；
- 外观换装靠 restyleGhost 热更（M20），会话内复杂变化仍可能需重建刷新；
- Sandevistan 同步可能覆盖游戏 SWF 补丁——重跑 `tools/patch_game_swfs.py` 恢复（锚点缺失报错 = MainFE 结构已变，需人工适配）；
- M22：autoClose 门与 rbl door3 这类**游戏侧循环/瞬态门**的 open 不同步（游戏存档语义本就如此）；joiner 对 open/lock 有 2s 滞回，状态变更最多延迟 2s；
- M22：门被摧毁的 die(-1) 清瓦片路径已实现但未做双实例专项验证；
- M23：源玩家坐下/爬行时幽灵显示站立（osn 标签层面无法区分，已知限制）；
- M24：Loot 的 suction 拾取动画不镜像（直接落位）；同 base 物品初始位置重合时认领启发式可能误认领键（不产生物品增减）；joiner 推动经上报落位，连续推动按 1s/键限频合并；
- M25 遗留：**boss（alicorn）与 mine 类敌人远端注入受限**（构造器 #1009 / 无 unit XML）；同 id 多门的宿主→joiner ist 应用仍是 first-match。念力已有 M26 平滑，不再写成“尚未实现平滑”。
- M26/M27：window1 类无 inter 脚本门未覆盖；phoenix 视觉未挂树观察项；念力和黑暗中敌人显示观感待真人确认。
- M27 的“总在 RV 后执行”依赖初始化顺序：已有双实例通过记录，但旧加载决策是独立异步 loader，不能把请求顺序等同初始化顺序。离线后的强制显示集清理也需专项验证。
- 自动重连仅 `_autoRole == "join"` 生效；默认手动 Join 不享有该重试。端口绑定失败后 startHost 仍写 HOSTING，需注意状态提示与实际监听不一致。
- 跨模组历史修正：TDFC 的排除式 AutoTest 误触发已由 v0.5.4 改为精确 `pfe-tdfc-test`（本会话上一轮已核对），不再列为当前未修复问题；本次不修改 TDFC。

## 6. 下一步（优先级排序）

1. 补当前环境的隔离验证基线，优先复核 M27 加载先后/退出清理、连接状态及已有同步缺口；本次接手未启动功能修改。
2. 真人验证幽灵姿态、念力搬运、换房跟随与 M27 黑暗中敌人显示；补特殊敌人、脚本门和门摧毁的专项覆盖。
3. 再确定完整任务/脚本进度等剩余世界一致性范围；随机内容种子是历史候选方案，改变游戏本体仍按具体授权执行。
4. 多人/真实网络/版本矩阵验收，之后发布收尾；自动穿透、中转与公共服务器列表属远期方向，尚未实施。

## 7. 深入了解

- **本次接手**：state/handoff-2026-09-10.md（最终目标、现状矩阵、静态发现与环境边界）
- **M26/M27**：knowledge/experiments/2026-09-07-m26-smooth-doors-rv-visibility.md；journal 顶部对应记录。
- **开发历程**：state/journal.md（M1–M22 逐里程碑浓缩 + 指向各实验文档）
- **关键坑清单**：knowledge/facts/engineering-pitfalls.md（14 条，编号对应实验文档）
- **架构**：design/architecture.md；src/rconnect/ 结构（GameBridge 游戏桥接 / Session 状态机 / Config / net 三件 / NetHud F10 面板）
- **决策**：decisions/2026-08-15-load-patch.md（游戏 SWF 补丁授权与方案）
- **测试手册**：docs/automated-testing.md（双实例编排/场景矩阵/断言表）；`python tools/run_m2_dualtest.py run|cleanup`，环境变量含 M2_PORT（默认 23456 被占时必换）/M2_DOORTOGGLE/M2_BOXLOOT/M2_HOSTWALK 等
- **构建（本机）**：`python tools/build_mod.py`；工具链在 `D:\RemainsMod\mods\Sandevistan\build\tools\flexsdk`（HARMAN AIR SDK 51.3.3，已显式 -swf-version=38）；Java 11 在 `C:\Users\hello\Documents\_sandevistan_dev\jdk-11.0.32.1+1-jre`（PATH 挂 bin）
- 2026-09-10 amxmlc 与上述 java.exe 路径存在，未执行验证。build_mod.py 直接写 release，不作只读检查使用；双实例脚本固定 pfe2/pfe3 并会清理匹配的测试进程，执行前必须确认没有占用用户第二窗口，不能把固定 ID 当作本轮专用。
- **用户向文档**：README.md、INSTALL.txt
- **共享知识贡献**：12 则（menu-worldstep-gating、findcel-targeting、player-vis-anim-pipeline、world-identity-determinism、land-travel-api、frozen-units-unfreeze、save-load-api、programmatic-gameplay-driving、player-death-respawn-flow、spectator-avatar-unit、mod-loader-cross-domain-anomaly、version-fingerprint 等）
- **技能**：remains-auto-testing、remains-runtime-debug、remains-swf-patching、remains-mod-build
