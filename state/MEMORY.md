# RConnect —— 开发记忆入口

> 协议见 GOVERNANCE.md §8；本模组参数见 ../AGENT_SCOPE.md。

## 1. 这个模组是什么

双人合作模组：加入者用自己的角色进入房主世界，房主结算敌人、伤害与场景状态，加入方上报行为并接收镜像。默认玩家状态约 20Hz，单位/场景快照约 5Hz。入口 RConnectMod.init(main)，AIR/amxmlc，swf-version=38。

## 2. 用户偏好与协作约定

- 已授权补齐已有合作探索、战斗与场景交互，允许大幅重构；稳定重连、三人以上、真实网络、版本兼容排除。暂不新增任务进度、背包与交易规则。
- 已授权部署候选供测试；2026-09-20 用户反馈加入侧无敌人、极少发现加入者，本轮修复并更新候选。
- 只写 RConnect。用户真实 pfe/pfe2 存档不动、游戏进程不动。测试用独立副本及随机 pfe-rconnect-coop-host/join-<token>，只清理自己创建的 PID。
- 其他模组仅直接冲突所需最小只读；不改其代码。游戏原始 SWF 本轮未改；将来修改需核对当前合并状态并保留其他 loader。

## 3. 当前状态

- **M29 / 0.2.1-dev 已部署**；master，本轮基线 1e46cbc（M28 部署记录）。正式 release 与 build/m29/RConnectMod.swf 同哈希，45574 字节，SHA-256 `33CE3B722A3473CC24659E813F8BBB7A934B295F680BD5612A341515A6B38685`。
- 修复实际 RV 遮罩残留导致 visible=true 仍画不出敌人；同名单位改稳定实例键，动画/血量/伤害不再共用。修复已有远房主目标阻止发现近加入者、普通 tr=0 地雷及数字变体构造。
- 最终独立双实例 **34373dd227：60 PASS / 0 FAIL**（35 既有、16 敌人、9 实际 TCP）。加载正式 RealisticVision；同名两敌人各自渲染出非透明内容，原生索敌与伤害路由通过。
- 普通 release 产物启动检查 **e7c3ca8fe9 PASS**：双方 0.2.1 初始化、心跳、welcome/单位同步。测试进程已清理。用户的现有游戏仍是旧内存版本，需双方重启。
- 备份：`build/backup/m29-release-20260920-095514-292641/RConnectMod.before.swf`（M28）。复制回 release/RConnectMod.swf 并重启双方可回滚。

## 4. 正在进行与停点

- 本轮修复、回归和部署已完成，等待用户在原有存档场景重启复测。
- 候选没有全模组组合验收；本轮准确覆盖 RConnect + RealisticVision，以及原生敌人 AI，不把 TDFC 等其他模组逻辑算进已通过范围。
- 若仍异常先读当前双方 RConnect.log，确认 0.2.1 初始化、房间身份、匹配数和显示状态，再定位是否 TDFC/随机房组合造成的新分支。

## 5. 已知问题与验证边界

- 本轮保留 320px 近身补发现范围，使用原生墙/朝向/潜行判断；远程角色不是 UnitPlayer，未复刻完整发现度积累与听觉调查手感。更近且存活的现有目标优先保留。
- 镜像存活敌人继续使用既有合作报点显示语义；清除残留遮罩不代表重做 RV 雾场。死亡/隐身/离房/退出归还遮罩，未穷举所有原生特效。
- 首次认领使用同 id/class 就近匹配，绑定后不随位置交叉变更；几何严重不同和初次重叠仍有边界。所有 Boss/地区没有穷举。
- M28 既有门箱、脚本门、念力和拾取定向回归保留；不等于完整剧情/多人/公网/全部版本验收。
- TDFC 源码的战术目标仍以宿主为中心；本轮未修改或加载 TDFC 做长期合作索敌验收。
- 旧全模组独立 ID 会触发 MSWAutoTest（id != pfe）自动开档并曾与 RR 准备时序冲突，不可照搬正式资源根全组合自动开档方案。只用随机正向测试标识，不改用户进程/存档。
- 既有连接状态、稳定重连、公网可达性等仍在排除范围；Steam 校验若清除 loader，按 remains-game-update 恢复，不能盲覆盖旧游戏备份。

## 6. 下一步

1. 用户重启双方，复测原先敌人消失房间与“房主远、加入者近”的遭遇；确认真实手感。
2. 若仍出现索敌异常，重点区分原生 AI 与 TDFC 战术目标重写；跨模组代码修改另按授权范围处理。
3. 排除项与新任务/背包/交易系统等待用户恢复范围，不自动扩展。

## 7. 深入了解

- **M29 复现/部署/失败记录**：knowledge/experiments/2026-09-20-m29-enemy-visibility-targeting.md；结构化证据 m29-validation-evidence.json。原始日志 build/cooperation/<token>/，部署指纹 build/m29/deployment.json。
- **测试**：tests/EnemyRegression.as、CoopRegression.as、CoopNetworkScenario.as。`tools/run_coop_regression.py --candidate build/m29/EnemyTest.swf --with-vision`；普通 SWF 用 `--smoke --seconds 45`。测试不应直接用正式用户 ID。
- **构建**：`tools/build_mod.py --java <java.exe> --output build/m29/RConnectMod.swf`；测试加 `--cooperation-tests --debug --output build/m29/EnemyTest.swf`。不带 output 会写 release。
- **工具**：Python `C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe`；SDK `D:/RemainsMod/mods/Sandevistan/build/tools/flexsdk`；Java `C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe`。
- **本次权限现象**：受限环境的 AIR 子进程未完成 RConnect 加载；按审批启动独立测试后通过。工具路径存在不等于 PATH 可解析，优先显式 --java；不绕过审批访问 AppData。
- **历史**：state/journal.md；state/handoff-2026-09-10.md（接手前快照）；M28 报告与 state/deployment-m28-2026-09-10.md。玩家入口 README.md / INSTALL.txt。
