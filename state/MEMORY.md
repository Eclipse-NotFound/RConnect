# RConnect —— 开发记忆入口

> 协议见 GOVERNANCE.md §8；本模组参数见 ../AGENT_SCOPE.md。

## 1. 这个模组是什么

双人合作模组：加入者用自己的角色进入房主世界，房主结算敌人、伤害与场景状态，加入方上报行为并接收镜像。默认玩家状态约 20Hz，单位/场景快照约 5Hz。入口 RConnectMod.init(main)，AIR/amxmlc，swf-version=38。

## 2. 用户偏好与协作约定

- 已授权补齐已有合作探索、战斗与场景交互，允许大幅重构；稳定重连、三人以上、真实网络、版本兼容排除。暂不新增任务进度、背包与交易规则。
- 已授权部署候选供测试；2026-09-20 用户先反馈无敌人、极少发现加入者，后反馈动画卡顿及无法打伤敌人；M30 已修复后两项并更新候选。
- 2026-09-20 共享探索已定：双向共享；各端独立控制接收，关闭后保留已收到区域。原版按自身明暗机制，RV 以自身设定为准；用户明确允许顺便做 RV 接口，但不能硬依赖 RV。
- 本轮允许写 RConnect 与 RV 的共享探索接口；其余模组仅直接冲突所需最小只读。用户真实 pfe/pfe2 存档不动、游戏进程不动。测试用独立副本及随机 pfe-rconnect-coop-host/join-<token>，只清理自己创建的 PID。
- 2026-09-20 用户明确“替换正式版本”，已部署固定 M31 与配套 RV 产物，保留最新 ModSettings 迁移。同期另一个 RConnect 任务开发 M32/0.2.4；不得把它的工作树/暂存内容混入本次部署或提交。

## 3. 当前状态

- 本轮正式路径独立启动检查 **46b70da446 PASS**：双方 RC0.2.3 初始化、tick200、连接和 RV0.30 心跳；测试实例已回收。短窗口回滚和并行测试脚本版本竞争已解决并留在部署记录。

- **正式安装 M31 / 0.2.3-dev 共享探索，配套 RV v0.30.0-candidate**；与已验 build 产物完全一致。部署及回滚记录 state/deployment-m31-2026-09-20.md / .json。源码基线 e127ab7；工作树0.2.4属于同期M32开发，不等于已部署版本。
- 验证：无 RV 双实例 c5a976c81c 为 103 PASS；最终 RV 组合 e6c6df2924 为 104 PASS；RV 独立 37 PASS。普通最终候选无 RV / 配套 RV 启动 94f25cd6d6 / 510c982aa5 均通过。RC 候选 50175 字节，SHA 0e00e4f8…c3277157；RV 22310 字节，SHA ce3abb8d…3a8dfb5b。未操作用户游戏进程，测试实例已清理。
- **历史 M30 / 0.2.2-dev（已被 M31 替换）**；master，功能基线 8aeacb7，期间保留另一任务文档提交 26cf636。release 与 build/m30/RConnectMod.swf 同哈希，47919 字节，SHA-256 `97bf59edbde5d2b702d675af950de7ef3e8625f3dd27dc458ed410b989fe1995`。
- 敌人原生动画按游戏帧推进，坐标快照间插值并保持有效位置精度；用无本地 AI/死亡逻辑的原生受击器接收子弹。HP/护甲/护盾损耗在快照覆盖前排队，默认每 50ms 上报；房主不重复减伤，仍负责死亡。保护 gotoAndStop 同步 EXIT_FRAME 重入。
- 最终独立双实例 **d1575158a0：80 PASS / 0 FAIL**（35 既有、16 敌人、12 战斗/动画、17 TCP）。包含真实子弹命中、60→30 护甲后净伤害、两只同名敌人不串伤、护甲磨损、致死回传和实际动画像素变化。
- 正式产物启动检查 **3ee92b0907 PASS**：双方 0.2.2 初始化、心跳、welcome/单位同步。M30 当时 RV SWF 指纹 `5c26d604ba6ae33a92a5d11f8a6f6abcfbf8bde9663baf3ab68e919a32b8c242`，本轮实际加载测试。未验全模组组合。
- M29 备份：`build/backup/m30-release-20260920-114534-591961/RConnectMod.before.swf`，原哈希 `33ce3b722a3473cc24659e813f8bbb7a934b295f680bd5612a341515a6b38685`。复制回 release/RConnectMod.swf 并重启双方可回滚。游戏三份 SWF、配置与其他模组不变。

## 4. 正在进行与停点

- M31 已替换旧 seen 路径：同房间持续采集、正确横纵坐标、双向消息、房间实例互认、参数校验及独立共享记忆。F10/可用模组设置页开关持久化，关闭/断线保留，读档/新世界按原有生命周期重置。
- RV 新增可选 active/capture/merge API；current 子格、classic 记忆与墙光各自遵循本地设置。原版只合成显示位图，不改原生 visi/t_visi；不扩大瞬移/悬停权限，也不把历史记忆写成当前视线。既有镜像敌人报点逻辑保留。
- 缺少 RV 仍可独立运行；RV 关闭/vanilla/基地透传走原版适配。旧 RV 没有接口，其自建雾层不保证新增共享显示；本次已一起部署配套 v0.30.0。
- 候选没有全模组组合验收；本轮准确覆盖 RConnect + RealisticVision，以及原生敌人 AI，不把 TDFC 等其他模组逻辑算进已通过范围。
- 若仍异常先读当前双方 RConnect.log，确认 0.2.3 初始化、房间身份、匹配数和显示状态，再定位是否 TDFC/随机房组合造成的新分支。

## 5. 已知问题与验证边界

- 受击器使用基础 Unit 的普通伤害计算；尚未单独同步持续伤害/特殊附加效果，全部武器与 Boss 特殊伤害覆盖、特殊击杀效果没有穷举。不能把普通子弹验收等同于所有战斗规则一致。
- 本轮保留 320px 近身补发现范围，使用原生墙/朝向/潜行判断；远程角色不是 UnitPlayer，未复刻完整发现度积累与听觉调查手感。更近且存活的现有目标优先保留。
- 镜像存活敌人继续使用既有合作报点显示语义；清除残留遮罩不代表重做 RV 雾场。死亡/隐身/离房/退出归还遮罩，未穷举所有原生特效。
- 首次认领使用同 id/class 就近匹配，绑定后不随位置交叉变更；几何严重不同和初次重叠仍有边界。所有 Boss/地区没有穷举。
- M28 既有门箱、脚本门、念力和拾取定向回归保留；不等于完整剧情/多人/公网/全部版本验收。
- TDFC 源码的战术目标仍以宿主为中心；本轮未修改或加载 TDFC 做长期合作索敌验收。
- 旧全模组独立 ID 会触发 MSWAutoTest（id != pfe）自动开档并曾与 RR 准备时序冲突，不可照搬正式资源根全组合自动开档方案。只用随机正向测试标识，不改用户进程/存档。
- 既有连接状态、稳定重连、公网可达性等仍在排除范围；Steam 校验若清除 loader，按 remains-game-update 恢复，不能盲覆盖旧游戏备份。

## 6. 下一步

1. M31 与 RV 已替换正式文件；用户保存后正常重启双方。后续升级先核对 M32 同期任务和当前 release 指纹，禁止用工作树版本推断部署版本。
2. 真人验收重点：分头探索同一房间、各端独立关闭/重开、关闭后的区域保留、RV 记忆暗度/模式。读档重置与旧 RV 的限制按玩家说明解释。
3. M30 真人复测与 TDFC 分支仍保留原验证边界；稳定重连、多人、公网、版本兼容及新任务/背包/交易系统仍排除。

## 7. 深入了解

- **M31 共享探索**：knowledge/experiments/2026-09-20-m31-shared-exploration.md、m31-validation-evidence.json；玩家说明 docs/shared-exploration.md；核心 src/rconnect/game/ExplorationSync.as。RV 接口契约在其 design/shared-exploration-api.md。
- **M30 真实攻击/动画与部署**：knowledge/experiments/2026-09-20-m30-combat-animation.md；m30-validation-evidence.json；build/m30/deployment.json。新类 src/rconnect/game/MirrorHitUnit.as，签名存根 tools/stubs，仅外部链接，不嵌入正式包。
- **共享探索探查**：knowledge/discoveries/2026-09-20-shared-exploration-feasibility.md；用户决定、待答问题、源码位置、RV 当前指纹、实施建议与验收清单。仅文档，不改变 M29 部署。
- **M29 复现/部署/失败记录**：knowledge/experiments/2026-09-20-m29-enemy-visibility-targeting.md；结构化证据 m29-validation-evidence.json。原始日志 build/cooperation/<token>/，部署指纹 build/m29/deployment.json。
- **测试**：tests/CombatRegression.as、EnemyRegression.as、CoopRegression.as、CoopNetworkScenario.as。`tools/run_coop_regression.py --candidate build/m31/ExplorationTest.swf --with-vision`；普通 SWF 用 `--smoke --seconds 45`。测试不应直接用正式用户 ID。
- **构建**：`tools/build_mod.py --java <java.exe> --output build/m31/RConnectMod.swf`；测试加 `--cooperation-tests --debug --output build/m31/ExplorationTest.swf`。不带 output 会写 release。
- **工具**：Python `C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe`；SDK `D:/RemainsMod/mods/Sandevistan/build/tools/flexsdk`；Java `C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe`。
- **本次权限现象**：受限环境的 AIR 子进程未完成 RConnect 加载；按审批启动独立测试后通过。工具路径存在不等于 PATH 可解析，优先显式 --java；不绕过审批访问 AppData。
- **历史**：state/journal.md；state/handoff-2026-09-10.md（接手前快照）；M28 报告与 state/deployment-m28-2026-09-10.md。玩家入口 README.md / INSTALL.txt。
