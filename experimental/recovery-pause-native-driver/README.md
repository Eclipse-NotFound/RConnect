# 原生背包武器：八轮暂停驱动入口

本目录只准备外部驱动，未编译、未启动 AIR。使用已经实际运行 `60ccbb7140` 的 `build/m52/motion2-continuity-drivers-01/tests` 原文，**不改阶段、时间、采样或既有断言**；原 `A22PauseTimingTestDoc` 仍是 `super(true,8)`。60cc 是父驱动默认 continuity 用例的通过证据，不冒称这个八轮入口已经实测通过。

只带 4 个必要 AS，生产类全部通过原有 declarations/stubs 外链：

| 文件 | SHA-256 |
|---|---|
| A22PauseTimingTestDoc.as | f20ce2cb227c82b7a6afa5c2580849d364aa5d7b5b8ab1314b27736d36e1ec81 |
| PresentationContinuityTestDoc.as | 2e998334580505028b9fa58d3daa6067e3eaa92d3df313db4ecfeeba26a8e6f9 |
| MotionCadenceRegression.as | 7a852c65be2c89082c8b727d4f90f7e416a097a090c87644bc48063bfce2a366 |
| DropMotionBurstRegression.as | 5b76f1ff70f5771613ce0ab68d46390da7739dbd8b95a13c072e037c0d4b5835 |

来源 prepared.json：`d51ae3e751e93d1ae9d57b836c57a36e0a6f2d0fbb8bfcd02549247ac6976f31`。`--check` 实际通过：四文件逐字一致、入口未改、父驱动差异只限已存在的 openSats 修正、所有外部来源实际 SHA 一致、Python AST 有效。编译闭包仍待真正编译确认。

## 与失败旧夹具的差异

[fixture.patch](fixture.patch) 是完整父驱动差分，只有 openSats：

- 旧 `coop-bundle-drivers-04`：`new NativeTestGun` 后裸赋 `currentWeapon`/`childObjs[0]`，手动 addVisual/setPers。
- 已验证来源：`world.invent.addWeapon("lmg")` → `changeWeapon("lmg",true)`，并断言背包和 currentWeapon 指向同一原生武器；hold=90、lvl=0、后续 SATS 输入原样保留。

旧 `9a806dee8c` 的主 26/0、加 129/0 和总 FAIL 全部保留。其加入侧 FirearmAttachments.log 有 **12 条 #1009**，堆栈只到 `fa::Runtime/after()`；这不足以定位空引用具体字段。不能把本次夹具差异宣称为已证明根因或已解决 FA 问题，不忽略模块日志、不关闭 FA。实际重跑还需验证八轮和全模组日志。

## 准备、编译、运行

在 `mods/RConnect` 工作目录，Python 为当前已知本机运行时；以下命令由根会话执行，输出必须是不存在的新目录。

```powershell
$taskPython = 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
& $taskPython -B -X utf8 experimental/recovery-pause-native-driver/prepare.py --check
& $taskPython -B -X utf8 experimental/recovery-pause-native-driver/prepare.py --output build/m52/recovery22-pause-native-drivers-01 --build --registry-wait 900
```

`prepare.py` 沿已存在的 `build_motion_supplement` 外链命令和 `recovery-density-fixture` 登记/内存保护路径：原 Java 与 SDK、384MB 编译堆、原 declarations、原 GameCombatStubs、原 EffectsHarness，game 占用，编译前 1GiB 可提交余量，既有 wait_owned 512MiB 运行保护，只清理自己启动的编译器。没有重新编译生产/存根/harness，没有无关 impact 组件。失败目录不得覆盖重编。

输出为正式 `run_motion_comparison --case pause-timing` 需要的 `prepared.json.files` 与 `pause-timing/{EffectsDriver.swf,EffectsHarness.swf,driver-input.json}`。正式运行器负责精确候选绑定、安装 22 项、隐藏桌面、独占、6GiB 双开门槛和清理；本目录不另建运行框架。

为保持旧 9a806dee8c 的实际 RV 模板，使用已经冻结的配置透传副本（它保留正式 motion runner 的逻辑/门槛）：

```powershell
& $taskPython -B -X utf8 experimental/recovery-density-profile-settings/run_motion_comparison.py --candidate build/m52/recovery-22 --drivers build/m52/recovery22-pause-native-drivers-01 --case pause-timing --output build/m52/recovery22-formal-pause-native-01 --host-vision-config-template experimental/recovery-density-profile-settings/configs/host-RealisticVision_config.txt --join-vision-config-template experimental/recovery-density-profile-settings/configs/join-RealisticVision_config.txt --registry-wait 900
```

新驱动字节不同，不能把旧 9a 设为要求同字节的 `--reference`。其失败记录仍是待解释的旧结果。若改用 `tools/validation/run_motion_comparison.py`，目录格式同样可接受，但该正式原入口没有 RV 模板参数，不能把默认配置运行冒称与旧实际配置完全相同。

未额外提供 late-pause/repaint 的构建开关，避免首轮编入无关用例；现有来源中两入口可在后续明确任务下原样复用。

## 交付边界

一条最初的“AS 复制及现有二进制哈希读取”准备命令被本地护栏判作 binary-swf-use-release-pipeline 并拒绝，未执行。随后把准备收窄为 AS/JSON 文本来源，二进制标识由既有清单引入；只读 `--check` 又核对了真实文件哈希，已通过。未改护栏、未复制/构建二进制、未改安装或其他模组。准确差异/输入/旧失败指纹见 fixture-delta.json、inputs.json、provenance.json；冻结交付见 handoff.json。
