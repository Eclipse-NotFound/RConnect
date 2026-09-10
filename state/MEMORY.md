# RConnect —— 开发记忆入口

> 新会话从这里开始。协议见工作区 GOVERNANCE.md §8；本模组参数见 ../AGENT_SCOPE.md。

## 1. 这个模组是什么

联网合作模组：加入者用自己的角色进入房主世界，无需预先准备相同存档。房主结算敌人、伤害与场景状态，加入方上报行为并接收镜像。默认 tickMs=50 时玩家状态约 20Hz，单位/场景快照约 5Hz；WORLDSTATE 另有事件触发，不能统称 5Hz。入口 RConnectMod.init(main)，必须 AIR/amxmlc，swf-version=38。

## 2. 用户偏好与协作约定

- **2026-09-10 本轮范围**：完成已有合作探索、战斗、场景交互的明确缺口，允许大幅重构；稳定重连、三人以上、真实网络、跨游戏版本排除。用户已明确暂不扩展任务进度、背包与交易系统。
- 不碰用户真实存档，不干扰用户实例。本轮采用独立游戏副本、每次随机且正向识别的 pfe-rconnect-coop-host/join-<token>，全新角色，仅清理本轮创建的 PID。不要沿用固定 pfe2/pfe3，也不要用 appid != pfe 排除式识别测试。
- 仅写 RConnect；跨模组问题报告并记录边界。共享知识只写删除本模组仍成立的游戏事实。
- 既有 loader 授权见 decisions/2026-08-15-load-patch.md；本轮未部署，未改游戏 SWF。未来部署按 release-gate，修改游戏文件前比对当前文件和备份，合并其他模组改动，不能直接覆盖历史基线。

## 3. 当前状态

- **源码：M28 / 0.2.0-dev**，master；本轮起点 c675f07（接手调查，功能基线 a32633f/M27）。已补同名门箱身份、双向关门/解锁/破坏、脚本门、特殊敌人注入、嵌套姿态与换装、拾取移动、显示顺序与离线清理。
- **候选：build/m28/RConnectMod.swf**，44963 字节，SHA-256 `2A65D5F83567BD1FB8D537270BEE4499FBAA7BF6EF2EAF89BE161BFDE0A8CF56`。普通入口构建，不含测试类。
- **当前游戏部署：release/RConnectMod.swf 仍为既有 0.1.0 产物**，41659 字节，SHA-256 `44D61708FE3DCE531A5F42F4FF3D195A184A6FDB4FF4E69E2AE6130DD4E2274D`；没有用候选替换。
- 验证：游戏 1.02 的独立副本、同机双实例。e8f2045028、563e74694c 两轮各 40 项通过；最终 65e809e940 的 35 项定向 + 7 项真实连接 = 42 项通过，含跨房间 AI 恢复；最终普通候选 5ce32a15a1 启动/连接检查通过，详见报告。
- 既有互见、聊天、房主世界注入、双向战斗、换图/死亡跟随和迷雾等仍在；本轮没有把全部历史功能重新遍历验收。

## 4. 正在进行与卡点

- M28 实现、候选构建与本轮验证已完成；最新证据以 knowledge/experiments/2026-09-10-m28-cooperation-validation.md 为准。
- 无需用户补充规则即可实现的本轮明确缺口已处理；真实手感、完整剧情流程和跨模组组合仍需后续实测，不据定向检查声称全游戏完成。
- 原 design/architecture.md 是 M4/M5 蓝图；当前实现以源码和 M28 报告为准。接手调查 state/handoff-2026-09-10.md 保留为变更前快照。

## 5. 已知问题与验证边界

- 同名 Box 初次认领仍以相同 id + 就近为依据；配对后使用稳定键。生成几何严重不同、首次位置完全重合仍有歧义，位置保护不等于布局一致。
- 普通交互门保留稳定性窗口，autoClose 与游戏循环门的瞬态语义未重做；无 Interact 的脚本门本轮已有双向实机检查。复杂任务/脚本副作用不等于门瓦片同步。
- alicorn2、mine、bossalicorn 本轮原生构造及镜像通过；不能外推全部敌人变种与所有 Boss 战阶段。原生门/脚本门/箱子双实例通过；所有地区与物件型号未穷举。
- 动作内外层帧与换装显示对象已镜像，最终观感未由真人评价。EXIT_FRAME 检查包含晚注册隐藏回调与原生显示对象；未加载实际 RealisticVision/TDFC 做组合验收。
- 掉落物保留堆叠/状态并显示吸入移动，未新增共享背包/交易/任务奖励分配规则。取消 60 件截断后，大量物品时的带宽和耗时未测。
- 换房消息带房间信息，房主拒绝异房操作；退出会清除注入单位、远端化身并恢复访问过房间的原单位 AI。没有宣称还原整个加入方世界或稳定重连。
- 既有手动 Join 不自动重试、监听失败仍可能显示 HOSTING、公网需可达端口等问题保留，属本轮排除的连接工作。
- Steam 校验曾清除 loader；再次发生按 remains-game-update 先查版本与当前合并状态，不能盲用旧备份覆盖。

## 6. 下一步（优先级排序）

1. 在明确部署任务下走发布门禁，把候选放入 release 并重启验证；本轮停在可复核的候选，不主动替换正在游玩的版本。
2. 真人确认坐下/移动/换装、念力、黑暗中敌人显示；补实际多模组组合、不同地区、完整 Boss 战与较长合作流程。
3. 稳定重连、三人以上、真实网络和版本矩阵留待用户恢复范围；任务/背包/交易先定义规则再开发。

## 7. 深入了解

- **M28 证据**：knowledge/experiments/2026-09-10-m28-cooperation-validation.md；同目录 m28-validation-evidence.json；完整日志 build/cooperation/<token>/。
- **测试源码**：tests/CoopRegression.as、tests/CoopNetworkScenario.as、tests/CoopTestDoc.as；编排 tools/run_coop_regression.py，独立 ID/副本与仅本轮 PID 清理。
- **候选构建**：`python tools/build_mod.py --output build/m28/RConnectMod.swf`；测试构建加 `--cooperation-tests --debug --output build/m28/CoopTest.swf`。不带 --output 仍会写 release，不能当只读检查。
- **复现**：`python tools/run_coop_regression.py --candidate build/m28/CoopTest.swf`；普通候选加 `--smoke --seconds 45`。build/ 产物不入 git，报告保存关键断言及日志哈希。
- **本机工具**：Python `C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe`；AIR SDK `D:/RemainsMod/mods/Sandevistan/build/tools/flexsdk`；JAVA_HOME `C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre`，其 bin 加入进程 PATH。
- **历史/原因**：state/journal.md；knowledge/facts/engineering-pitfalls.md；decisions/2026-08-15-load-patch.md；M26/M27 见 knowledge/experiments/2026-09-07-m26-smooth-doors-rv-visibility.md。
- **玩家文档**：README.md、INSTALL.txt；旧 docs/automated-testing.md 的固定测试 ID/清理策略不可直接视为本轮专用。
