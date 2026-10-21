被测技能：remains-runtime-debug / remains-auto-testing 2026-10-20.1；remains-mod-build / remains-mod-memory；test-report 2026-09-16.1。
技能归属：Remains 工作区 `.agents/skills`（调试/测试维护驻地 ModLoader）；用户级 `C:/Users/hello/.agents/skills/test-report`。
测试工作区：D:/Program Files/Steam/steamapps/common/Remains/mods/RConnect。

# 2026-10-21 玩家被队友念力抓取时的身体光晕

## 当前停点

RConnect (3)，会话 `01a151af-a677-79c0-8d01-615a5405db46`。用户反馈对侧抓起玩家时身体没有念力光晕。本轮完成独立修正、实际 AIR 显示组件对照及正常加载器单人检查；**完整双人抓取未通过验收，未部署**。主会话 `01a086bb-378c-7f60-b8e1-50d90ffa0996` 已同意四文件隔离增量，继续负责最终合并、验证和部署。

14:41 内存余量恢复后继续原生功能检查。`control-03/c481f352f8` 已完整复现光晕问题，候选 `native-01/efa0b3cb6d` 在寻找走廊时失败。driver-03 已编译：仅测试副本固定为成功复现轮的原生种子1192051184，避免不同随机走廊阻断对照；正式地图逻辑未修改。随后 `control-04` 再次因低于6 GiB启动门槛未开AIR；15秒3样本可提交余量4.81–4.92 GiB（`control-04/memory-followup.json`）。所有本会话测试已结束，等待内存稳定后接续。

先前排队时误把共享表前一行 b1bb4e4adf 标成本轮，已纠正；提升只读确认 wrapper26868→runner112660、双端驱动指纹匹配，证据 `peer-player-aura-control-03/lineage-check.json`。未使用另一个会话的日志或结果，没有 UUID 碰撞证据。

- 安装基线：`build/m52/coop-bundle-04`，0.2.23-coop-bundle2，SHA-256 `574d2b51490ae8b25a1396555600f56a301f8a20ae50104c0e35cf2796441afe`。
- 候选：`build/m52/peer-player-aura-01/RConnectMod.swf`，0.2.24-peer-aura1，SHA-256 `4800783a6c158ca90f1e3dc7c4d6267bbee49e817de779771ac2244d193848d8`。
- 源码入口：`experimental/peer-player-aura/src`，只覆盖安装基线的四个文件；版本行由准备脚本更改。**不从历史根 src 整体构建，不覆盖 room-entry-fast、motion-continuity 等其它候选。**
- 可合并差异：`build/m52/peer-player-aura-01/increment.patch`，SHA-256 `4ed53919628a6e3a8d2397f605b5e2bb79a043489ef0939e6a44e46c8c9175a1`；四文件指纹见同目录 `increment.json`。

## 原因与修正

当前安装基线没有完整保留历史 M51 的玩家光晕路径，不能据历史通过记录认定本次安装已具备修正。

1. `PeerGrip` 的抓取报文只有动作输入，没有施法者原版光晕样式。本次在原生抓取完成后采集一次颜色与发光参数，随现有抓取报文发送；接收端按抓取生命周期显示并恢复。
2. `TelekinesisVisuals` 原先要求目标位于普通物体链。实际玩家由 `Location.gg` 单独管理，不在此链中。本次仅允许 `loc.gg === object && object.player === true` 这一真实本地身份绕过链检查；死亡、房间、失效对象检查保留。加入有限数值、滤镜数量及参数范围校验。
3. `PlayerBodyEffects` 的普通远端状态会覆盖原生 Q 刚设置的身体染色。本次给 `apply` 增加 `nativeGrip` 参数，抓取期间仅让出根颜色/透明度；`GameBridge` 的四处调用按 `peerGrip.locallyHeld(target)` 传值。未更改正常队友的 .75 透明度、护盾/其它子效果规则。

`PeerGrip` 与 `TelekinesisVisuals` 的增量采用已有历史修正；`PlayerBodyEffects` 只取此次必要的所有权处理，没有顺带采用历史根源码里的其它外观变更。运动、碰撞、权限、挣扎、伤害算法没有改动。

## 本轮证据

| 试验 | 结果 | 证据与边界 |
|---|---|---|
| 生产候选及原生专项驱动编译 | 通过 | `peer-player-aura-driver-01/compile.log`；候选保持 4800783a。驱动含 PeerGripTestDoc、PeerThrowDamageTestDoc，测试类独立于生产 SWF。 |
| 旧安装版双人对照 | **未通过**：主 10 通过/2 失败，加入 9 通过/1 失败 | `build/cooperation/1e9a111c75`，汇总 `peer-player-aura-control-01/result.json`。round 1 原生 Q 没抓住目标，随后 holding 超时；未进入光晕采样，不能称为本次问题的双人复现。全模组含 CS 正常注册、scene.xml 齐全；22 项安装输入未变。 |
| 原生驱动修订 | 编译通过，后续完整运行 | `peer-player-aura-driver-02`。按既有组合模组周期重算 Pers 的经验，维持 start 已指定的能力预设，加入 native-input / fixture-drift 日志，保留原功能断言。首轮没有这些字段日志；具体漂移由control03捕获。 |
| 再次旧版双人对照 | **启动前暂缓** | `peer-player-aura-control-02/runner.log`，登记关联 `build/cooperation/00a74d0f61`。可提交内存低于 6 GiB，未启动 AIR；随后只读采样约 3.57 GiB。没有降低门槛、关闭用户程序或改绿失败。 |
| 完整旧版双人复现 | **主99通过/10失败，加入99通过/10失败** | `control-03/c481f352f8`，12回合完整结束；20个失败全是抓取光晕/染色，原生抓取、释放、挣脱、撤销、E抛出及共享菜单暂停通过。源端有GlowFilter但RGB被改回普通色；受抓端没有光晕。driver02日志还实际观察到 maxTeleMassa 被重算为0.6、小于玩家mass1；维护预设后原生Q成功。22项安装未变。 |
| 首轮候选原生检查 | **前提失败，0项** | `native-01/efa0b3cb6d`：随机种子3211735722的出生房没有满足原驱动要求的空旷走廊，尚未抓取。保留原失败；不能归为光晕代码失败或通过。 |
| 固定场景驱动 | 编译通过，尚未原生执行 | `peer-player-aura-driver-03`：两个原生专项的宿主测试副本使用1192051184；加入侧仍走生产种子采纳。光晕原断言保留并加双端种子一致检查；抛掷驱动同样维持原能力预设，不改伤害断言。生产候选字节未重编译。 |
| 固定场景旧版对照 | **启动前暂缓** | `peer-player-aura-control-04/result.json`、`runner.log`、`memory-followup.json`。低于6 GiB，无AIR启动；wrapper没有取得OUTPUT，run编号保留null，不猜另一行登记。 |
| 安装版显示组件对照 | **14 通过/6 失败** | `peer-player-aura-component-control-01/result.json`。失败包括模型本地玩家被跳过、未绘出身体边界外光晕、身体快照覆盖抓取染色、缺少接收参数校验。 |
| 候选显示组件 | **25 通过/0 失败** | `peer-player-aura-component-01/result.json`。实际 AIR 的 DisplayObject、GlowFilter、ColorTransform、BitmapData；验证边界外光晕像素、释放后与抓前像素相同、死亡/换房/reset、替换身体、保留后来本机效果、原生抓取优先及普通队友显示不变。 |
| 正常加载器单人检查 | **通过** | `build/cooperation/aa9a98ec9d`，汇总 `peer-player-aura-smoke-01/result.json`。精确 4800783a、现装宿主 BEFCF050、完整14模块输入，正常进入 begin/loc0_0；CS registered/scene.xml 核对通过，无异常，22 项安装输入未变。离线模式未触发 random_mane 旅行，不宣称已做战斗或双人验收。 |

以上短目录均在 `build/m52/`。旧对照缺少 `validated` 方法，因此只执行到其存在性检查，旧版20项与新版25项的差别来自后续5个校验用例，不是删掉旧失败项。

显示组件只替代 `GameBridge.probe` 的普通属性查询边界，不装载游戏，不模拟 TCP、玩家控制或真实抓投；使用实际生产的 `TelekinesisVisuals` 和 `PlayerBodyEffects` 源文件，前后指纹一致。组件像素通过不能替代原生双方截图和抓投回归。旧版 c481f352f8 已保存8张图，已目检 round1 host/join 抓取图：施法端有绿色轮廓，受抓端没有；修正版完整截图尚待取得。没有性能结论。

## 恢复时直接执行

先确认至少 6 GiB 可提交余量、共享测试登记和当前安装输入，再使用同一份 driver-03 重跑旧版，修正版，以及 PeerThrowDamageTestDoc。各模组仍在并行开发，不能沿用此前运行的安装组合推断当前组合。若旧版仍卡原生 Q 或场景，先读新增原生输入/种子/属性漂移诊断定位夹具；不得直接放宽断言或宣布已修好。

```powershell
# 从 mods/RConnect 执行；Python 用 MEMORY 中已验证路径。
python -B -X utf8 tools/validation/peer_player_aura.py run --candidate build/m52/peer-player-aura-01 --drivers build/m52/peer-player-aura-driver-03 --output build/m52/peer-player-aura-control-05 --control
python -B -X utf8 tools/validation/peer_player_aura.py run --candidate build/m52/peer-player-aura-01 --drivers build/m52/peer-player-aura-driver-03 --output build/m52/peer-player-aura-native-02
python -B -X utf8 tools/validation/peer_player_aura.py run --candidate build/m52/peer-player-aura-01 --drivers build/m52/peer-player-aura-driver-03 --entry PeerThrowDamageTestDoc --output build/m52/peer-player-aura-throw-01
```

- 原生光晕驱动12回合：双方互换施法者，禁抓、允许抓且不挣脱、WASD挣脱、撤销许可、E抛出、共享菜单暂停。每个实际持有阶段对比原版源样式，释放检查无残留。round 1/7 保存抓取及释放的 `presentation-*.png`，完成游戏断言后才编码；完成后需逐图核对。
- PeerThrowDamage 原生驱动尚未运行。它已有20个双向抛掷情景，须验证撞墙伤害开关与恢复，不以光晕组件替代。
- 原生双人合格后交主会话合并；主会话合并后的新字节仍须对应验证与发布门禁。本记录不授权把此独立 SWF 直接盖到安装版。
- 本轮正常保留用户 `application.xml -nodebug` 实例；自己的测试均由 runner 清理进程及可重建游戏副本，唯一失败日志、编译源和结果保留。

## 技能实战回流（同一任务合并）

自然采用调试/自动测试技能的独立 AppID、后台桌面、共享登记、完整运行资源核对及失败保留方法；本轮没有使用 Ghost。单人检查曾自动等待其它登记释放后开始。没有为此另建受限盲测任务。

本轮回读技能 SHA-256：auto-testing `d6c2efbb03c2d5431c438b4626b83ae00c36e2904b91dba10c4d4a2b06a4dc89`；runtime-debug `6017fbd0d89c8aa08f31c3b8474f7feca6f901c483f0fe08f10178e1246f6eb7`；test-report `cde4695f98417768f2c11ea42f6ea1f4400ddecc5d00f5a224fcc988646febf5`。

- [已落盘→`knowledge/experiments/2026-10-20-isolated-mod-resources.md` / KB-000105] 运行资源完整性须看延迟初始化及 scene.xml，而不能只看 SWF 指纹；本次确实检查两个证据。
- [已落盘→`state/coop-bundle-2026-10-19.md`] 组合模组可能周期重算测试角色 Pers。此历史事实用于设计 driver-02；control03新日志捕获maxTeleMassa=0.6/目标mass=1，维护预设后原生Q正常，支持夹具前提漂移解释，首轮具体参数没有日志不可补造。
- [已落盘→`state/validation-m51-2026-10-09.md`] 历史原生玩家光晕修正与回归存在；不能直接作为当前安装组合资格。
- 本次新增产物：独立四文件修正、外部原生驱动快照、显示组件、精确冻结/运行工具、此记录。新证据是当前安装源的显示组件负对照、候选正对照和旧版双人完整复现；候选原生双人证据仍不足。
- 本地保护曾将“源码复制加只读 SWF 指纹核对”混合命令拒绝；分开只读核对与仅 AS 源码复制后原工具正常接受，未维护授权表或绕过护栏。
- 处置：全局台账已纯追加并成功回读，状态待吸收；待技能维护者核对。共享 MEMORY/journal 由主会话接入此记录，避免覆盖其并行主任务。
