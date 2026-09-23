# RConnect —— 开发记忆入口

> 协议见 GOVERNANCE.md §8；参数与边界见 ../AGENT_SCOPE.md。

## 1. 这个模组是什么

双人合作模组：加入者以自己的角色进入宿主世界，宿主结算敌人、伤害与场景状态，加入方上报行为并接收镜像。玩家状态默认约 20Hz，敌人/场景约 5Hz；画面在快照间逐帧推进。共享探索有变化时最快 100ms 发送，三秒完整补齐。入口 RConnectMod.init(main)，AIR/amxmlc，swf-version=38。

## 2. 用户偏好与协作约定

- 已授权补齐已有合作探索、战斗、场景交互，允许大幅重构，并部署候选测试。排除稳定重连、三人以上、真实网络、其他版本；不新增任务、背包与交易规则。
- 本轮 M33 用户确认：自己流畅，主要是对方动作和共享视野跳；加入侧站在宿主身边仍看不到敌人本体。之前武器反馈为轻机枪打天角兽，M32 的伤害数字与护甲修复必须保留。
- 共享探索既定规则：双向共享，各端独立控制接收，关闭保留已收到区域；原版遵循自身明暗，RV 采用本机设置，可选依赖。M31 的 RV 接口授权不扩展为本轮随意修改其他模组。
- 本轮只写 RConnect。用户 pfe/pfe2 存档和进程不动；测试用随机应用标识、独立副本与新角色，只结束本轮创建的 PID。其他模组只做冲突定位与测试复制所需最小读取。
- 根游戏及其他模组有同期部署；测试须先冻结整套输入再供两端使用，不能把 host 启动后重新读取线上文件的 join 当成一致环境。

## 3. 当前状态

- **M33 / 0.2.5-dev 已部署并通过正式路径启动检查 370cad3918**，53331 字节，SHA256 `683f8573e45cfa8b709d683cd5f558eec6f0b82f0c020380e59b7eb352fff2e6`。双方新版初始化、连接、tick200 与单位同步通过。
- 最终 RC+RV 完整回归 **d5ee064ade：131 PASS / 0 FAIL**。含真实子弹/轻机枪、天角兽护盾与 HP 收敛、双方不同护甲、门箱/死亡、共享探索与退出清理；最终 HP1680.8/shield0，两端与逐击净损耗一致。
- 最终全模组画面专项 **816fae8134：26 PASS / 0 FAIL**。加入侧 merc2/merc5/alicorn3 的实际屏幕像素可见，连续 15 个 RENDER 帧缺失 0。宿主/加入侧两包间动作分别 8/8/8、5/5/5（采样帧/不同位置/不同动画帧）。停止帧保持，探索逻辑秒 10 包、该夹具流量少约 86%。不等于任意负载下实测 10Hz。
- 新增 RemoteMotion；原生动画播放与停止分开处理；探索变化行差分及真正绘制前合成；敌人同步 invis/isVis/alpha，并在原生动画后重施。保留天角兽隐身半透明闪现，不把隐身判定解除。正式包 18 类，无游戏存根/测试入口。
- 原根因红测为受控本地透明残留。用户旧日志只证明单位匹配与 parent/visible 正常，没有 alpha/invis/isVis；不能断言用户所有不显示都仅源于同一原因，新日志已补齐字段。
- 备份 `build/backup/m33-release-20260923-114237-479272/RConnectMod.before.swf`，SHA `4e65327f…996c5262`。复制回 release/RConnectMod.swf 并正常重启双方回到 M32/0.2.4；只回滚 RConnect，保留其他模组和新 loader。部署指纹在 build/m33/deployment.json。

## 4. 正在进行与停点

- 本轮修复、部署和独立重启验证完成，等待用户具体存档实玩反馈。
- 源码基于 M32 提交 e872c5d；M31 共享探索与 M32 HitFeedback/RemoteArmor 保留。两端必须同时升级到 0.2.5；新行差分协议不保证旧版互通。
- 当前根游戏为 1.02，新 manifest loader v2；测试基线 SHA `b7824465…8003305ac`，RV v0.30.0 SHA `ce3abb8d…3a8dfb5b`。本轮没有修改根游戏或 RV。

## 5. 已知问题与验证边界

- 普通受击器仍使用基础 Unit 损伤规则；持续伤害、特殊 Boss damage 覆写、全部武器及击杀效果没有穷举。
- 现有 320px 近身补发现保留原生墙、朝向、潜行判断；远端不是 UnitPlayer，未复制完整发现度和听觉调查。TDFC 战术目标仍偏宿主，本轮没改其 AI。
- 全合作回归只在 RC+RV；全部已装模组做了暗室显示/动态呈现专项，未验长期全组合战斗和全部地区。
- 仍保留合作报点显示语义；强制显示不等于重做 RV 雾场。真正隐藏、半透明、死亡、离房及退出有定向检查，所有原生特效未穷举。
- 首次认领同 id/class 就近匹配；绑定后按实例键，不随交叉换目标。首次重叠、几何严重不同仍有边界。
- 异构输入轮 dc940a9437 曾在加入侧缺后续场景数据，且测试空数组产生异常；冻结输入后的两轮显示专项和两轮完整回归均未复现。不要声称已定位/修复传输层原因，也不要据单轮失败重写重连。
- 未验证稳定重连、公网、三人以上和其他版本。Steam 覆盖 loader 后按 remains-game-update，不能恢复旧根 SWF 覆盖他人新加载器。

## 6. 下一步

1. 双方保存并完全退出游戏，再正常启动，确认面板 0.2.5-dev。
2. 真人复测加入侧敌人本体、双方跑跳/瞄准与分头探索。自动测试没有操作用户具体存档。
3. 若仍不显示，先核对两端版本、房间和单位匹配，以及新日志 a/hidden/isVis；继续区分透明状态、绘制遮罩与包同步，不覆盖原始证据。

## 7. 深入了解

- M33：knowledge/experiments/2026-09-23-m33-presentation.md、m33-validation-evidence.json；build/m33/deployment.json；tests/PresentationTestDoc.as。
- M32：knowledge/experiments/2026-09-20-m32-hit-feedback-armor.md，m32-validation-evidence.json；src/rconnect/game/HitFeedback.as、RemoteArmor.as。蓝色 S -数字是护盾消耗，普通数字是生命损伤。
- M31：docs/shared-exploration.md；knowledge/experiments/2026-09-20-m31-shared-exploration.md；state/deployment-m31-2026-09-20.md/json。RV active/capture/merge 为可选接口，不改原生交互/瞬移权限。
- 构建：tools/build_mod.py --java <java.exe> --output build/m33/RConnectMod.swf；--cooperation-tests / --presentation-tests 加 --debug 构建独立测试入口。**不带 --output 会写 release。**
- 回归：tools/run_coop_regression.py --candidate <测试SWF> --with-vision --seconds 360；画面专项加 --presentation --all-mods --seconds 210；普通 release 加 --smoke --seconds 150。画面专项进入 random_mane。测试需复制 mods/loader-manifest.txt；全模组标识 pfe-modsettings-rconnect-coop-* 避免 MSWAutoTest 抢驱动，普通 pfe-rconnect-coop-*。
- Python C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe；Java C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe；SDK D:/RemainsMod/mods/Sandevistan/build/tools/flexsdk。AIR/FFDec 沙箱加载不足时按实际工具审核，不用初始化日志冒充行为通过。
- 历史与玩家说明：state/journal.md、README.md、INSTALL.txt。报告有完整失败轮次与观察限制；build 下保留原日志、输入哈希及截图，不能作为新开发基线复制回源码。