# RConnect —— 开发记忆入口

> 协议见 GOVERNANCE.md §8；本模组参数见 ../AGENT_SCOPE.md。

## 1. 这个模组是什么

双人合作模组：加入者用自己的角色进入房主世界，房主结算敌人、伤害与场景状态，加入方上报行为并接收镜像。默认玩家状态约 20Hz，单位/场景快照约 5Hz。入口 RConnectMod.init(main)，AIR/amxmlc，swf-version=38。

## 2. 用户偏好与协作约定

- 已授权补齐已有合作探索、战斗与场景交互，允许大幅重构；稳定重连、三人以上、真实网络、版本兼容排除。暂不新增任务进度、背包与交易规则。
- 已授权部署候选供测试；2026-09-20 用户先反馈无敌人、极少发现加入者，后反馈动画卡顿及无法打伤敌人；M30 已修复后两项并更新候选。
- 2026-09-20 新需求当前为共享视野探查：已确认双向共享探索；原版按自身明暗机制，RealisticVision 以自身设定为准。开关归属与关闭后保留规则尚待用户回答；不把推荐当决定。
- 只写 RConnect。用户真实 pfe/pfe2 存档不动、游戏进程不动。测试用独立副本及随机 pfe-rconnect-coop-host/join-<token>，只清理自己创建的 PID。
- 其他模组仅直接冲突所需最小只读；不改其代码。游戏原始 SWF 本轮未改；将来修改需核对当前合并状态并保留其他 loader。

## 3. 当前状态

- **M30 / 0.2.2-dev 已部署**；master，功能基线 8aeacb7，期间保留另一任务文档提交 26cf636。release 与 build/m30/RConnectMod.swf 同哈希，47919 字节，SHA-256 `97bf59edbde5d2b702d675af950de7ef3e8625f3dd27dc458ed410b989fe1995`。
- 敌人原生动画按游戏帧推进，坐标快照间插值并保持有效位置精度；用无本地 AI/死亡逻辑的原生受击器接收子弹。HP/护甲/护盾损耗在快照覆盖前排队，默认每 50ms 上报；房主不重复减伤，仍负责死亡。保护 gotoAndStop 同步 EXIT_FRAME 重入。
- 最终独立双实例 **d1575158a0：80 PASS / 0 FAIL**（35 既有、16 敌人、12 战斗/动画、17 TCP）。包含真实子弹命中、60→30 护甲后净伤害、两只同名敌人不串伤、护甲磨损、致死回传和实际动画像素变化。
- 正式产物启动检查 **3ee92b0907 PASS**：双方 0.2.2 初始化、心跳、welcome/单位同步。当前 RV SWF 指纹 `5c26d604ba6ae33a92a5d11f8a6f6abcfbf8bde9663baf3ab68e919a32b8c242`，本轮实际加载测试。未验全模组组合。
- M29 备份：`build/backup/m30-release-20260920-114534-591961/RConnectMod.before.swf`，原哈希 `33ce3b722a3473cc24659e813f8bbb7a934b295f680bd5612a341515a6b38685`。复制回 release/RConnectMod.swf 并重启双方可回滚。游戏三份 SWF、配置与其他模组不变。

## 4. 正在进行与停点

- 本任务 M30 修复/测试/部署已完成；用户游戏未被结束，需双方重启复测真实战斗手感。下列共享探索工作来自另一任务，保持其停点。
- 新一轮共享探索源码探查已完成，未实施/编译/运行/部署。现有 seen 同步存在同房间缓存不刷新、横纵坐标读反、单向和房间身份校验不足；RV 另有独立记忆且无公开共享接口。
- Q3 待答：宿主统一开关（推荐）或各端自控；Q4 待答：关闭/断开恢复个人探索（推荐）或保留收到的探索。下一轮还需解释原版瞬移/交互权限的连带影响；可靠 RV 兼容涉及其小接口改动，当前仅最小只读。
- 共享探索探查时 RV 已是 v0.29.0-candidate，旧 M29 测试不能代表新组合。M30 已针对上述当前指纹验证敌人显示/战斗，仍未实现或验收双向共享探索新规则。
- 候选没有全模组组合验收；本轮准确覆盖 RConnect + RealisticVision，以及原生敌人 AI，不把 TDFC 等其他模组逻辑算进已通过范围。
- 若仍异常先读当前双方 RConnect.log，确认 0.2.2 初始化、房间身份、匹配数和显示状态，再定位是否 TDFC/随机房组合造成的新分支。

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

- 当前优先：用户重启双方复测连续移动与普通开枪；若仍失败，确认版本/同房/具体敌人和武器，查本轮已加入的伤害回报与宿主应用日志，再缩小到全模组交互或特殊攻击。
1. 接续共享探索 Q3/Q4，按原版/RV 的数据区别形成可审阅方案；详见探查报告。源码事实已经查清的部分不重复问用户。
2. 实施时区分本人探索与远端记忆，使用正确坐标及地图身份；聚合设置页 + F10 入口可复用现有 API。探查不是已实现，跨模组改动范围需先明确。
3. M30 真人复测与 TDFC 分支仍保留原验证边界；稳定重连、多人、公网、版本兼容及新任务/背包/交易系统仍排除。

## 7. 深入了解

- **M30 真实攻击/动画与部署**：knowledge/experiments/2026-09-20-m30-combat-animation.md；m30-validation-evidence.json；build/m30/deployment.json。新类 src/rconnect/game/MirrorHitUnit.as，签名存根 tools/stubs，仅外部链接，不嵌入正式包。
- **共享探索探查**：knowledge/discoveries/2026-09-20-shared-exploration-feasibility.md；用户决定、待答问题、源码位置、RV 当前指纹、实施建议与验收清单。仅文档，不改变 M29 部署。
- **M29 复现/部署/失败记录**：knowledge/experiments/2026-09-20-m29-enemy-visibility-targeting.md；结构化证据 m29-validation-evidence.json。原始日志 build/cooperation/<token>/，部署指纹 build/m29/deployment.json。
- **测试**：tests/CombatRegression.as、EnemyRegression.as、CoopRegression.as、CoopNetworkScenario.as。`tools/run_coop_regression.py --candidate build/m30/CombatTest.swf --with-vision`；普通 SWF 用 `--smoke --seconds 45`。测试不应直接用正式用户 ID。
- **构建**：`tools/build_mod.py --java <java.exe> --output build/m30/RConnectMod.swf`；测试加 `--cooperation-tests --debug --output build/m30/CombatTest.swf`。不带 output 会写 release。
- **工具**：Python `C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe`；SDK `D:/RemainsMod/mods/Sandevistan/build/tools/flexsdk`；Java `C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe`。
- **本次权限现象**：受限环境的 AIR 子进程未完成 RConnect 加载；按审批启动独立测试后通过。工具路径存在不等于 PATH 可解析，优先显式 --java；不绕过审批访问 AppData。
- **历史**：state/journal.md；state/handoff-2026-09-10.md（接手前快照）；M28 报告与 state/deployment-m28-2026-09-10.md。玩家入口 README.md / INSTALL.txt。
