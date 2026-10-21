# 恢复整合版：统一外部测试驱动

本目录只含测试源码及冻结、构建、运行包装器，不改生产源码、安装文件或既有冻结目录。`prepare.py` 采用现有外部声明 SWC + EffectsHarness 结构；编译持有 ModLoader 的 `game` 登记，沿用 Java `-Xmx384m`。**prepare.py 不启动 AIR，也不调用生产模组编译器。run.py 只运行已编译产物，不编译或部署。**

## 使用

在 RConnect 目录执行，先完成最终生产候选编译。`--source` 指定该候选的 `src`，旁边必须已有 `RConnectMod.swf` 与 `build/GameCombatStubs.swc`，以便绑定准确生产字节。

```powershell
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/recovery-tests/prepare.py --source build/m52/<最终候选>/src --output build/m52/<新驱动目录> --build --registry-wait 900
```

不传 `--build` 只冻结源码及输入。可对同一输出第一次追加 `--build`，此前冻结的全部原文件、工具、候选字节必须仍匹配。已有编译日志（含失败）或成功编译的目录不得覆盖；修正后使用新目录。

冻结的 `prepared.json` 记录：

- 最终生产源码逐文件指纹、准确生产二进制、候选构建清单、游戏声明、测试源码来源与指纹。
- Java、编译器、AIR 配置、airglobal、登记工具和本脚本指纹。
- 每个驱动的用途、场景数、建议运行上限，以及所有构建产物指纹。
- `compiled` 只代表编译。`air_started`、`native_qualified` 始终为 false，不自动生成任何功能通过结论。

`verify(out, source)` 会核对冻结输入、原始输入以及已完成的构建产物。等待共享登记后会再次核对，避免排队期间源码改变。

## 驱动目录

| `drivers/<入口>` | 原生场景数 | 内容 |
|---|---:|---|
| PeerGripTestDoc | 16 | 双向 Q、身体最终舞台光晕像素、释放/挣脱/抛出/reset/换房返回 |
| PeerThrowDamageTestDoc | 20 | 双向 Q/E、真正碰墙及伤害开关/暂停 |
| WallBallisticTestDoc | 14 | 普通弹/NPC 慢弹/连射/肉体/到期负例 |
| WallEnergyTestDoc | 15 | 能量、天角兽闪电、喷火、速射 |
| WallMagicTestDoc | 14 | 七种魔法武器双向击墙 |
| RecoveryWallMaterialsTestDoc | 14 | 材质 1—7 双向，包括不应有火星的材质 |
| ExplosiveVisualTestDoc | 14 | 普通爆炸物、入水、飞行中原生换枪 |
| SpecialWeaponTestDoc | 12 | 酸性、等离子、EMP、冰冻、毒气、燃烧与地面附效 |
| MagicExplosionTestDoc | 4 | 快捷魔法槽火球与 eclipse |
| HeavyProjectileTestDoc | 8 | 火箭、重弹、榴弹的原生轨迹/朝向/寿命/近墙 |

共 10 个原生入口、131 个声明场景；**不是通过数**。刻意纳入 SpecialWeaponTestDoc，避免漏掉本次用户点名的酸性炸弹。

每个目录都含 `EffectsDriver.swf`、`EffectsHarness.swf` 和绑定准确候选 SHA 的 `driver-input.json`，可直接交给 `run_coop_regression.py --effects --effects-driver <目录>`。`controls/<入口>` 使用完全相同的驱动字节，仅绑定准确 574D 旧版作负对照。脚本会核对固定旧二进制哈希，不默默采用当前安装版。

组件分别位于：

- `components/aura`：实际生产 `TelekinesisVisuals` / `PlayerBodyEffects` + 显示边界夹具，26 个声明检查。
- `components/impact`：实际生产命中队列/能量/普通粒子三个类 + 明示的游戏边界替身，41 个声明检查。

组件都附独立唯一 AppID 的 `application.xml`，编译后入口为 `Checks.swf`，`visible=false`。运行包装器每次另建新 AppID 与描述符，使用已有独立桌面工具；单看描述符不会隔离 Windows 启动画面。组件不加载原游戏，也不证明原生碰撞和双人画面合格。

## 运行包装器

每次只运行一个已冻结组件或原生入口。输出必须是全新的 `build/m52` 直接子目录，不写驱动冻结目录。以下命令由统一测试会话执行；本次脚本交付没有执行它们。

```powershell
# 真实 AIR 组件，二选一：aura / impact
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/recovery-tests/run.py component --drivers build/m52/<已编译驱动> --component aura --output build/m52/<新组件结果> --registry-wait 900

# 按 prepared.json 入口、场景、地图、时长运行双人功能测试
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/recovery-tests/run.py native --drivers build/m52/<已编译驱动> --entry PeerGripTestDoc --output build/m52/<新原生结果> --registry-wait 900

# 同一个驱动字节，对照准确 574D / 0.2.23-coop-bundle2；失败原样保留为失败
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/recovery-tests/run.py native --drivers build/m52/<已编译驱动> --entry PeerGripTestDoc --control --output build/m52/<新对照结果> --registry-wait 900
```

组件流程：

- 申请共享 `game` 登记，排队结束后再次核对所有冻结源、工具、安装指纹。
- 新输出中复制准确组件，另建唯一 AppID，通过 `HiddenProcess` 放在从不切换到前台的独立桌面。至少 1 GiB 可提交余量才启动；运行中低于 512 MiB 或超过 60 秒则只停止本次进程，均不能算通过。
- 读取该 AppID 写出的真实 `checks`，逐条统计布尔结果，并核对原始 `pass/fail` 汇总。26/41 只是 `expected_checks`；记录是否相符，不改任何 AS 断言、不用期望数替代实测数。
- 保留原始组件 JSON、stdout、内存时间线、输入清单和最终结果。组件结果永远不是原生游戏通过。

原生流程：

- 最终候选与准确 574D 对照各用匹配的 `driver-input.json`；生产、驱动、harness、版本源码和准备脚本均绑定 SHA。
- 复用 `run_coop_regression.py` 的全模组、独立桌面、原生 UI 就绪后显示、等待宿主世界就绪、禁止其他 AIR 重叠、共享登记机制。包装器不再嵌套抢占登记；双实例沿用 6 GiB 启动、512 MiB 终止保护。
- 安装前后检查完整 **22 项**游戏/名单/启用模组/配置/CS 场景指纹。数量改变则停止，不忽略新增文件。双侧运行副本也逐项核对：只明确接受外部 harness、隔离角色配置、去注释后的启用名单这三类测试替换，生产字节另核对 `tests/RConnectProduction.swf`；其他模组和配置逐字节保持安装输入。
- 所有原生资源也核对运行器记录；双侧输入必须一致。检查角色唯一 AppID、描述符、共享登记结果、内存和重叠记录。
- 两侧分别检查对应 suite 的 PASS、FAIL、完整 DONE、生产版本、所有声明回合，以及加入侧连接证据；扫描角色日志、stdout 与该 AppID 收集的**全部模组日志**，并要求 ContinuousScene 完成注册。
- 为核对运行器尚未单独保留的名单字节，临时使用 `--keep-copies`；得到本次唯一 `OUTPUT` 后，结束时仅清理该次 `host/join/frozen` 三个冗余副本，保留日志、配置、描述符、截图和指纹。若启动早期没有输出所属目录，记录归属未确认，不猜目录删除；可由统一会话按登记证据处理。

`result.json` 无论成功失败都声明 `functional_only=true`、`performance_qualified=false`。像素采样、全模组日志扫描及启动串行化不适合出具性能通过结论。原生某一入口通过也只覆盖它声明的场景；光晕截图仍由统一会话查看，不能拿组件替代实景验收。

## 旧爆炸/重弹夹具修正

旧源码直接 `Weapon.create` 后赋给 `currentWeapon`，没有放入 `Invent.weapons`，可重现全模组下 FA 的空状态错误。本目录仅覆盖这两个测试文件：

- `ExplosiveVisualTestDoc`：备用 LMG、普通爆炸武器、快捷投掷和快捷魔法全部通过原生 `Invent.addWeapon` 创建；当前装备通过 `changeWeapon` 切换，并断言同一对象在原生背包中。每回合仅在测试背包副本移除对应旧绑定，再原生创建新枪，避免上一回合的 Bullet 引用干扰单发断言。
- `HeavyProjectileTestDoc`：火箭/重弹/榴弹同样通过原生背包装备，保存原快捷槽；每回合先原生卸下，结束恢复原背包与角色引用。
- 两者只在独立实例里使用保留字符串键的背包数组副本；不写真实存档。原有弹速、重力、碰撞、伤害及原生效果/轨迹判据未改变。保存 childObjs 的数组副本，避免原生换枪修改原引用后无法恢复。
- `MagicExplosionTestDoc`、`SpecialWeaponTestDoc` 继续继承上述同一修正父类，不另抄执行算法。

墙体驱动直接冻结 recovery-wall-impact 已修好的背包夹具；光晕直接冻结 recovery-aura 的新版 16 回合与 20 回合驱动。生产类只放入 external declarations，原生驱动不内嵌另一份联机实现。组件用到的生产类单独复制，边界替身不会进入原生驱动。

## 当前验证边界

已做 Python 语法/导入/参数帮助、工具路径存在、入口/场景清单及差异静态检查；`run.py` 也只做这些静态检查。没有执行冻结命令、没有编译、没有 AIR 运行；AS3 与运行包装器仍需主会话正式验证。旧候选历史测试不构成本次整合候选通过。
