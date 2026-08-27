# RConnect —— 开发记忆入口

> 新会话从这里开始。协议见工作区 GOVERNANCE.md §8；本模组参数见 ../AGENT_SCOPE.md。

## 1. 这个模组是什么

互联网联机模组：安装了 RConnect 的玩家通过 TCP 直连（IP+端口）一起游玩。**核心卖点：加入方无需准备与房主一致的存档，直接玩房主的存档**（宿主权威架构：客户端上报 PLAYERSTATE/伤害，宿主 5Hz 广播 WORLDSTATE/UNITSYNC 并权威结算）。入口类 `RConnectMod`（swf-version 38，AIR 专属 API，必须 amxmlc 编译）。

## 2. 用户偏好与协作约定

- **已获授权（2026-08-15）**：补丁三份游戏 SWF 加装本模组 loader（决策见 decisions/2026-08-15-load-patch.md）；版本策略 = 尽量兼容 1.02/1.03/1.04。**新方案涉及改游戏本体内容（如种子替换）必须重新确认授权**。
- **改游戏文件前必查**：与 `build/backup/current-merged-20260819/` 基线哈希比对（他人改动先合并，绝不直接覆盖）。
- **绝不碰用户真实存档**（%APPDATA%\pfe\）；测试用临时 app id（pfe2/pfe3）+ 存档模板只读复制。
- **不干扰用户游戏实例**（命令行含 `application.xml -nodebug` 的不动）；测试实例用 `app_rconnect_test_*.xml`。
- 跨模组 bug 只报告不修复；shared-knowledge 贡献仅限"删除本模组后仍成立"的知识。

## 3. 当前状态

- **0.1.0-dev**（未发布）：M1–M20 全部通过**真机双实例自动化验证**（2026-08-15~20），覆盖：互见/姿态/武器/外观镜像、宿主权威世界注入、双向战斗、死亡复活协调、换图/跨图跟随、聊天、断线重连、探索迷雾/物品/瓦片破坏/Loot 同步、随机图布局确定性。
- 三份游戏 SWF 均含本模组 loader（已核验 `app:/mods/Rconnect` 标记）；工作树干净。

## 4. 正在进行与卡点

- **等真人体验测试**（双开/邀请朋友手动联机，反馈幽灵标签/透明度、换房跟随手感）——当前无真人测试条件。

## 5. 已知问题

- NAT：MVP 直连需端口转发（远期公共中转服务器）；
- M3 遗留：动画阈值（run≥6px/walk≥1px）按真实联机观感校准；
- 外观换装靠 restyleGhost 热更（M20），会话内复杂变化仍可能需重建刷新；
- Sandevistan 同步可能覆盖游戏 SWF 补丁——重跑 `tools/patch_game_swfs.py` 恢复（锚点缺失报错 = MainFE 结构已变，需人工适配）。

## 6. 下一步（优先级排序）

1. 真人体验测试（用户有条件时）；
2. 门/箱（瓦片级 Obj）同步 + 随机地图种子同步——都属"改游戏本体"级，需用户授权后评估；
3. NAT 穿透 / 中转服务器（远期）；
4. 发布收尾：版本号、打包（tools/make_release.py）、README 已有。

## 7. 深入了解

- **开发历程**：state/journal.md（M1–M20 逐里程碑浓缩 + 指向各实验文档）
- **关键坑清单**：knowledge/facts/engineering-pitfalls.md（14 条，编号对应实验文档）
- **架构**：design/architecture.md；src/rconnect/ 结构（GameBridge 游戏桥接 / Session 状态机 / Config / net 三件 / NetHud F10 面板）
- **决策**：decisions/2026-08-15-load-patch.md（游戏 SWF 补丁授权与方案）
- **测试手册**：docs/automated-testing.md（双实例编排/场景矩阵/断言表）；`python tools/run_m2_dualtest.py run|cleanup`
- **用户向文档**：README.md、INSTALL.txt
- **共享知识贡献**：12 则（menu-worldstep-gating、findcel-targeting、player-vis-anim-pipeline、world-identity-determinism、land-travel-api、frozen-units-unfreeze、save-load-api、programmatic-gameplay-driving、player-death-respawn-flow、spectator-avatar-unit、mod-loader-cross-domain-anomaly、version-fingerprint 等）
- **技能**：remains-auto-testing、remains-runtime-debug、remains-swf-patching、remains-mod-build
