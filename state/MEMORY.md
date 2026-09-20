# RConnect —— 开发记忆入口

> 协议见 GOVERNANCE.md §8；本模组参数见 ../AGENT_SCOPE.md。

## 1. 这个模组是什么

双人合作模组：加入者用自己的角色进入房主世界，房主结算敌人、伤害与场景状态，加入方上报行为并接收镜像。默认玩家状态约 20Hz，单位/场景快照约 5Hz。入口 RConnectMod.init(main)，AIR/amxmlc，swf-version=38。

## 2. 用户偏好与协作约定

- 已授权补齐已有合作探索、战斗与场景交互，允许大幅重构；稳定重连、三人以上、真实网络、版本兼容排除。暂不新增任务进度、背包与交易规则。
- 已授权部署候选供测试；M29/M30 修复敌人显示、动画及真实子弹命中。本轮用户反馈轻机枪打天角兽没有伤害数字、双方看到对方穿着与己方一致；M32 已复现并修复。
- 2026-09-20 共享探索已定：双向共享；各端独立控制接收，关闭后保留已收到区域。原版按自身明暗机制，RV 以自身设定为准；用户明确允许顺便做 RV 接口，但不能硬依赖 RV。
- M31 任务获准写 RConnect 与 RV 的共享探索接口；本轮 M32 只写 RConnect；其余模组仅直接冲突所需最小只读。用户真实 pfe/pfe2 存档不动、游戏进程不动。测试用独立副本及随机 pfe-rconnect-coop-host/join-<token>，只清理自己创建的 PID。
- 2026-09-20 同期共享探索任务已部署 M31 与配套 RV，提交 ed0e38d。本轮在其完成后部署 M32，只替换 RConnect，保留 RV 和 ModSettings，不回滚他人部署。

## 3. 当前状态

- **M32 / 0.2.4-dev 已写入 release**，51393 字节，SHA256 `4e65327f3014211b3811e3917d4ff4dd984e9d6d2964c38f0ee21d51996c5262`。候选启动 6ccefa9187 PASS；正式路径启动 c7ae0ed25a PASS，双方 0.2.4 初始化、tick200、连接/同步通过；测试实例已清理。
- 完整双实例 **d995672ebb：122 PASS / 0 FAIL**。真实轻机枪 65 发击破 alicorn3 的 500 护盾，双方最终 HP1695.2 / shield0；宿主最终损伤等于加入方逐次原生命中损伤之和。双方不同护甲、跑跳切帧、数字过期后的下一轮射击通过，同时保留共享探索与门箱/死亡回归。
- 根因：受击器不执行 Unit.actions，原生 hitPart 缓存不清理；原生服装新动画部件重新读取本机全局穿着。新增独立 HitFeedback、仅远端服装帧修正 RemoteArmor；宿主/加入方均显示蓝色 S -数值表示护盾损耗，普通数字表示生命损伤。原生伤害计算及 M30 净损耗回传保留。
- 正式包 17 类，无游戏存根或测试类；本轮未改游戏三份 SWF、配置和 RV。配套 RV v0.30.0 SHA `ce3abb8d1321df4f2a6e1053ecbb44aabff66a6e27f81b517d3a341b3a8dfb5b`，来自同期共享探索部署。
- 回滚本次修复：`build/backup/m32-release-20260920-153135-660744/RConnectMod.before.swf` 复制回 release/RConnectMod.swf，正常重启双方，回到 M31/0.2.3（0e00e4f8…c3277157）；无需恢复 RV。部署指纹见 build/m32/deployment.json。

## 4. 正在进行与停点

- 本轮修复、部署和独立启动验证完成，待用户实玩反馈。用户测试重点：轻机枪击打天角兽、停火后再次射击、双方穿不同护甲并跑跳/换装。
- M31 共享探索已合入并保持部署：持续双向采集、房间实例互认、各端 F10/模组设置接收开关，关闭/断线保留，读档/新世界按原有生命周期重置。
- RV 的 active/capture/merge 为可选接口；current/classic 各自遵循本地设置。原版只合成显示，不改原生 visi/t_visi、交互或瞬移权限。未装 RV 走原版适配；旧 RV 自建雾层不能保证新增共享显示。
- 本轮准确覆盖 RConnect+RV 的隔离同机联机，不是全部模组组合实战。异常先核对双方 RConnect.log 的 0.2.4、房间身份、单位匹配，以及伤害日志的 hp/armor/shield 三项。

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

1. 用户保存并正常重启双方，复测本轮轻机枪/天角兽与双方不同护甲。S -数字是护盾损耗，护盾吸收时生命可不下降。
2. 共享探索真人验收仍保留：分头探索、各端关闭/重开、区域保留、RV 暗度/模式与读档重置。
3. 后续若用户报告仍异常，先看本轮版本及分别记录的损耗，再调查 TDFC/随机房等组合分支；原排除项不扩大。

## 7. 深入了解

- M32 报告：knowledge/experiments/2026-09-20-m32-hit-feedback-armor.md；结构化 m32-validation-evidence.json；部署 build/m32/deployment.json。新代码 src/rconnect/game/HitFeedback.as、RemoteArmor.as，测试 AppearanceDamageRegression.as / LightMachineGunScenario.as。
- M31：knowledge/experiments/2026-09-20-m31-shared-exploration.md，m31-validation-evidence.json；docs/shared-exploration.md；state/deployment-m31-2026-09-20.md/json。原配套两模组部署回滚与本轮单 RC 回滚区分。
- M30：knowledge/experiments/2026-09-20-m30-combat-animation.md，m30-validation-evidence.json；原生受击器 MirrorHitUnit.as。公开机制条目位于 shared-knowledge/rendering/discoveries：synchronous-exit-frame-during-hit、player-armor-frame-global-state、damage-number-unit-actions-lifetime。
- 构建：tools/build_mod.py --java <java.exe> --output build/m32/RConnectMod.swf；测试加 --cooperation-tests --debug，正式产物无测试类。运行 tools/run_coop_regression.py --candidate build/m32/FeedbackTest.swf --with-vision --seconds 240；普通 SWF 用 --smoke --seconds 150，双方心跳必检。不带 --output 的构建会写 release。
- Python C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe；Java C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe；SDK D:/RemainsMod/mods/Sandevistan/build/tools/flexsdk。
- AIR/FFDec 在普通沙箱曾加载不足，按审核使用独立实例；不能凭初始化日志当完整通过。测试 Timer 在后台两端进度可能不同，等业务完成后断言。build/m32-combat-appearance 保留最初隔离副本及红测日志，修复已合入主工作树，勿作为新开发基线。
- 历史：state/journal.md；state/handoff-2026-09-10.md。玩家入口 README.md / INSTALL.txt。
