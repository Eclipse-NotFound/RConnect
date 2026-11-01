被测技能：code-review 2026-10-08.1（C:/Users/hello/.agents/skills/code-review/SKILL.md）
技能归属：用户级
测试工作区：D:/Program Files/Steam/steamapps/common/Remains/mods/RConnect

# B 版后续迭代审查（2026-11-01）

结论：优化方向和已有测试有实际依据，但目前不能作为“无正确性退化”的版本通过审查。发现 3 个行为问题和 1 个源码留存问题。本轮只审查、核对已有证据和保存记录，没有修改产品、启动游戏、部署或回滚。

## 范围与依据

- 用户要求检查另一 agent 的迭代；沿用“不改 A、保持实际运行效果”的要求。
- 基线：本会话最后交付的 `build/ab/b-smooth-04-build`，SWF `c3118075c414887aea770d7df36b349e52fe330a441571218fa969c25bff44fa`。
- 被审版本：`build/ab/b-p0-06`，SWF `a382e94f66fa22e008c1a056871a6634bdf4915e1e84a9b2b9a3de0347818386`，source `ec5945be3f642135994b95873ff511c46b6d5e7f675385188d6655dcfe4558d7`。实际 B190 可玩入口的安装字节一致。
- 比较完整冻结源码（144→145 份 AS），并核对未提交的两份外置测试驱动、B 记忆与实验记录。HEAD 仍为 `716d8a3`，暂存区原为空；因此只看 Git 提交或顶层旧 src 会漏掉本轮主要产品变化。
- 变化：FrameDelta/NativeFields 稀疏字段；PoseTween/ReplicaScene 对应应用与跳过；SceneSnapshot 尸体缓存；新增 TerrainBitmapCache；4 个内置探针/检查消费者适配；BuildInfo 指纹。Stage 1 和 J13～J19 等未晋升候选不作为当前安装功能。
- 规范依据：工作区 GOVERNANCE §2.1（本轮相关源码/记忆提交、构建产物可再生）、§6（验证对应实际产物，保留配置与 A）；本次需求按“优化但不破坏现有同步”核查。另一会话新增授权仅参考其记录，没有把未读到的逐轮指令当作独立事实。

## Standards：源码留存

### S1 · P2：已部署的新源码只留在被忽略的 build 目录

定位：`.gitignore:2`；`build/ab/b-p0-source-01/src/authority/TerrainBitmapCache.as:18`；`build/ab/b-p0-06/build-input.json`。

最新产品源码尚未入库，也没有本会话 smooth04 那样的可恢复覆盖源。对 experimental/src/tools 的同名文件做字节比对，最终 TerrainBitmapCache、SceneSnapshot、ReplicaScene 均没有匹配副本。未跟踪的调查目录有 J11 初期补丁脚本，但没有最终 J12/P1/P3/P0 的完整恢复配方；其中早期 PoseTween 补丁也不同于最终字节。

这不是要求把构建产物全部纳入 Git，而是必须留存唯一源。用户此前要求精简 D 盘测试文件，按 build 可再生的约定清理后，可能只剩可玩 SWF，失去已部署版本的源代码和可复核构建依据。

建议：保存最终相对 smooth04 的源码覆盖和完整文件指纹，验证恢复后再提交；部署回执和失败实验摘要一起留存。不要在审查提交中夹带另一 agent 的未提交代码。

未另外把命名、动态对象访问等项目既有写法列作缺陷。

## Spec：行为正确性

### B1 · P1：移动物件的插值仍读取基线位置

定位：`build/ab/b-p0-06/src/authority/FrameDelta.as:76`、`PoseTween.as:143`、`ReplicaScene.as:195`。

J11 对 scene.units **和 scene.objects** 都把变化写入 fieldsDelta，不再更新 fields。refreshMotion 却只遍历 units；对象没有新的 motion。PoseTween 对 objects 因而回退到旧 fields，ReplicaScene.interpolate 又直接把这些旧坐标写回对象。

具体调用轨迹（源码推导，非新实机复现）：箱子首帧 X=100，随后确认帧 X=140/160；新解码后 fields.X 仍为 100，fieldsDelta.X 为 140/160。确认应用可短暂写入 140，但两确认间插值会把对象 X 和边界重新写成 100；显示 pose 则可以正常移到 150。随后 pointer/selection 用对象的 X1/X2/Y1/Y2 判断鼠标命中，便出现图像与交互区域分离。静止后 J12 还可能跳过重复字段恢复，错误位置不一定在下一确认消失。

受影响范围是 scene.objects 中发生位移的可交互物，例如被念力移动的容器。不能将这个问题扩大为所有掉落物或所有子弹，它们还有独立 effects/projectiles 路径。

建议：为对象提供与单位同语义的有效运动字段，插值和交互始终读该有效值。回归应经过实际 FrameDelta 解码，再移动可交互箱子，并分别核对画面位置、实体坐标、鼠标命中；当前只在确认时核对外观不足以覆盖。

### B2 · P2：稀疏字段删除会重新露出基线旧值

定位：`build/ab/b-p0-06/src/authority/FrameDelta.as:43`、`NativeFields.as:120`。

删除操作只 `delete sum[fr]`，但 fields 基线不变。NativeFields.get/has 在 delta 中没有键时回退到 fields，于是“已删除”和“从未修改”变成同一种状态。

确定的协议例子：基线 X=100，更新到 X=140，再发送 removed=[X]；当前逻辑返回 X=100 且 has(X)=true，正确结果应是缺失。这类删除不是虚构操作：NativeFields.capture 对 Number 变成 NaN/Inf、String 变为 null、Object/* 由标量变成引用时会发 removed；等长单位数组中的实体替换也会发生字段集合变化。缺失坐标的判断在 SceneChecks 中原本就是明确支持的分支。

建议：用独立删除标记或生成等价有效记录，同时约束 get/has、motion 和 apply 的语义。不要简单把 null 当成通用删除值，因为 Number/null/缺失的原语义不同。新增测试需使用 scene.units/scene.objects 的真实路径；当前 BDeltaPrefixChecks 的模拟树主要用 room/units 等根，未进入这条新增特判，因此那些通过项不能证明本分支正确。

### B3 · P2：尸体缓存没有覆盖其实际保存的可变状态

定位：`build/ab/b-p0-06/src/authority/SceneSnapshot.as:93`。

达到 60 tick 后，缓存只以 sost、animState、取整 X/Y、根 MovieClip 帧和 alpha 判断不变，却复用整份记录，跳过后面的 fields/inter/pose/blit/weapons/attached/positionEpoch 采集。缓存命中后也没有定期完整复核。

因此，只要尸体挂载/可见性、交互、燃烧或回放状态发生改变，而上述六项没有变，新状态就永远不会发出，直到其它缓存键碰巧变化或房间重置。尤其 burning/replay 已在循环开头算出，却在命中缓存后被忽略；原有代码本来在这两种状态下强制走完整姿态。原生 blit 动画帧也由 AuthorityAnimation 从 blitRect 读取，并不等同于这里的根 currentFrame。不能仅凭“根帧一段时间没动”证明完整视觉和交互已经稳定。

建议：只缓存证明静止的视觉子记录；继续采集交互/生命期字段，对燃烧、回放、显示对象或挂载变化立即失效。加入“稳定尸体之后再改变状态”的专项回归，而不只检查刚死亡的那几帧。本轮确认的是失效条件缺口，未将某一种具体敌人的现场症状写成已实测复现。

## 已有证据核对

被审 build-input 中所有源文件与磁盘字节一致。七组结果的候选 SHA、日志 SHA、运行器 SHA 都核对通过，均记录 runtime_unchanged=true：

| 场景 | 主/加外层断言 | 结果目录（build/ab 下） |
|---|---:|---|
| 文字与移动 | 104/117 | b-p0-test-textmotion-01 |
| 火箭 | 50/50 | b-p0-test-rockets-01 |
| 实时地形 | 178/123 | b-p0-test-terrainlive-02 |
| 敌人 | 50/50 | b-p0-test-enemies-01 |
| 加载 | 68/62 | b-p0-test-loading-02 |
| 交互界面 | 127/84 | b-p0-test-ui-02 |
| 边界/换房 | 61/52 | b-p0-test-boundary-06 |

共 1176 个外层断言；enemies/rockets 还包装内置玩法检查，不能将外层 50 误解为没有运行战斗。检查通过是真实已有证据，但没有覆盖上述新增稀疏字段边界和稳定尸体后续变化；本轮没有另启动游戏。

从 ABBench.log 的原始 intervals 重新计算：

- J12 对 smooth04：80 敌加入侧 34.131/33.843ms，对照 39.791/39.185ms，约降低 13.9%；主侧同期平均约 63.18 vs 60.69ms（约慢 4.1%），不足以宣称主侧也得到确定收益。
- 当前 P0 对 P13 两组 ABAB：加入 80 敌四次平均为 41.275/43.899/43.302/38.641ms，对照 44.449/44.001/44.172/39.580ms。按四轮均值汇总约 **41.779 vs 43.051ms（−2.95%）**；P95 四轮均值 70.25 vs 74.5ms。原 B-MEMORY/journal 写的“42.59 vs 43.04（−2.9%）”均值汇总有笔误，收益方向仍有这些数据支持。不能把不同日期、机器负载的绝对数横向相加来宣称总收益。
- 现有换房日志能看到缓存命中（如 boundary 的 10ms）与未命中真实 drawLoc；这支持重复进房收益，不等于首次加载或所有战斗卡顿已解决。
- 当前 A 正式体仍为 `690604878bd8707007a99e3ad14f8f5f3f55cdd4948c8debe6cc87363afd38c9`，与既有 A 见证一致。版本字符串仍 smooth1，应按完整构建指纹识别本次被审版本。

## 审查边界与接续

这是冻结源码、调用路径与已有运行证据的审查，三个行为发现按源码路径提出，未冒称本轮新增实机复现。原版参考源码的一条只读搜索被本地护栏拒绝（read-only-reference），未重试或绕过；因此对 TerrainBitmapCache 与原版 drawLoc 所有内部副作用的逐项等价性不作通过结论。共享知识查询也有部分源不可读；没有把空结果当成没有经验。

核对结束后，尝试生成额外 JSON 摘要的只读取指纹/写摘要组合指令，被本地护栏按 binary-swf-use-release-pipeline 拒绝；未执行、未重试，也未生成该可选文件。本文已保存实际读取获得的版本、位置、测试结论及限制，不把缺失的 JSON 摘要当作已归档证据。

未改动/回滚当前安装，也未替另一 agent 归档产品源。后续先修 B1/B2，补 B3 的缓存失效，再补相应针对性回归；源码留存应在任何构建清理之前完成。

Standards：1 项，主要风险为唯一源码留在可清理目录。Spec：3 项，最高为移动物件的画面与交互位置不一致。

## 技能实战回流

本次实际使用 code-review 的范围固定、未跟踪/忽略目录审查及规范/行为分轴方法；同一主会话完成，未委托子代理。已将“功能日志通过”与“新增分支正确性”分开。新场景是产品迭代全部在被忽略 build 中、Git HEAD 未变；仅用 git diff 会漏审。未改变技能或治理文件。已查重追加全局测试报告台账并回读确认，状态为待吸收。
