---
domain: rendering
type: experiments
game-version:
  - "1.02"
confidence: medium
verified: false
discovered-by: RConnect
evidence:
  - kind: runtime-experiment
    summary: "旧905候选在真实原生本体存活的Session.leave后留下空vis/hpbar遮罩；新8case专项使用实际RV、原生武器引用及只读独立裁剪对照。"
  - kind: source-review
    summary: "仅直接未共享字段证明历史mask引用；自有过渡位图与原生RV存储隔离，早帧只观察引用，晚RENDER检查重复孤立遮罩。"
date-updated: 2026-10-06
---

# M46 存活原生本体的遮罩恢复

> 2026-10-07后续核对：本实验之后，0.2.18-dev/04438276已完成14组1648/0、最终旧905负控与正常无驱动eb84c49f11并部署。最新状态见[state/deployment-m46-2026-10-07.md](../../state/deployment-m46-2026-10-07.md)。下文的未部署/待验证语句描述当时阶段，原失败和因果边界保留。


接续R2回交记录`2026-10-06-m46-mask-ownership.md`。该旧记录中的“唯一前置同签名Shape可认定原生mask”是905时期策略；root现已删除此猜认。本记录只涉及RConnect共享显示引用和当前安装RV的直接协作，留在模组自有实验区。当前安装仍为M45，恢复专项通过不代表联合门禁或部署通过。

## 已确认

- `final-20 / d173763da3`旧905候选实测：真实Session.leave保留原生本体与vis/hpbar，但即时mask为空（P2）。同形孤立对象被错认归属（P1）尚未动态复现，只是审查风险，不能把两者合称一个实测根因。
- 一个Shape同时只有一个实际mask持有者。真实原生Weapon取得同一Shape后，body.mask可能被运行时清空；恢复body不能抢走Weapon的引用。本轮驱动明确将原生Weapon加入loc.firstObj对象链来覆盖RV的对象遮罩分支，不能说所有原生手持武器天然处于该链。
- 共享本体vis/hpbar还供原生SATS使用；不能为修白块删除这些引用，或把真实敌人身份/锁定资格伪装成NPC。MirrorHitUnit保持真实id/isVis/npc/noAgro，代理只在loc.units碰撞/锁定列表，不运行原生AI链；退役只清代理引用。
- “未调用release”不表示字段从未被RV改写。直接字段在别处成为mask持有者、RV晚帧重赋mask、退出发生在晚RENDER之前，都需要恢复检查。因此在实际alias前prepare保存直接字段引用；早ENTER_FRAME只观察共享字段当前mask；晚RENDER使用独立captured标记去重并做图形检查。
- 若历史原生mask仍附着且没有其他真实持有者，就还原该精确对象；否则同步copyFrom绘入RConnect自有ARGB位图，放入原RV层过渡裁剪。原RV BitmapData仅提供短时绘图引用和尺寸/矩阵元数据，不调用其getPixel/getVector/clone/dispose，不留作本模组长期位图。clean在离线/roomHold早返回之前执行；RV接管、字段重建、退出房间或视野停用后只销毁自有副本，不改后来者mask。
- 当前实际RV为40px Tile /8子格，原填充格为5px。元数据导出的matrix.a/d约4.998779，且repeat/smooth标志与RV源码调用参数不一致，不能用导出标志证明原绘制算法。元数据有时为空，原因未定。whole-tile矩形回退到5px是当前安装RV的采样格式假设，**不是所有权证明**。
- 1px世界光栅再开smooth会产生二次alpha采样；`final-26`独立自有像素对照观察12个alpha像素少1、RGB差0。关掉这次smooth使严格遮罩光栅一致，但尚不足以保持小数位置字段裁剪。保留原5px填充格后，final-33两端8case的mask与独立字段裁剪hash均精确一致。

## 测量与测试边界

`MirrorMaskRestoreTestDoc`先经真实双端TCP握手，再结束网络自动加入；各端随后分别经实际GameBridge快照/镜像接口驱动原生本体、RV回调和Session.leave。八个场景是本地生产接口复放，不能说八个都通过真实网络传输。其余联合驱动另验TCP业务。

| case | 场景 | 保留的断言 |
|---|---|---|
| 0 | 共享前已知原生mask | 精确identity还原，原生本体/血条仍存活，RV清扫 |
| 1 | 初始mask空、原生Weapon引用、同形反例 | 不抢Weapon，不借同形对象，独立裁剪与清理 |
| 2 | 共享中原生vis/hpbar重建 | 新字段裁剪即时恢复及后续RV接管 |
| 3 | alias之后Weapon取得历史原生mask | 历史所属不等于当前使用许可，独立副本 |
| 4 | 首次部分RV绘制之后、晚RENDER之前leave | 早引用观察覆盖；不是全可见转部分可见测试 |
| 5 | 副本后视野inactive且roomHold | 早返回前回收自有Shape并清空自己的引用 |
| 6 | 副本后原生字段再次重建 | 旧副本移除，新RV引用不被旧清理覆盖 |
| 7 | 最后观察之后后来白色bitmap Shape接管 | 精确新引用/cache/挂载/visible保留；不覆盖提前观察到的所有第三方时序 |

测试不写现场mask/cache/visible来做图像对照。mask签名和字段裁剪绘入独立自有缓冲区；字段对照把固定字段图像和独立mask放到真实父坐标系，比较全部RGBA。实际整场景PNG另保存，不把独立裁剪hash等同整场景一致。

final-33独立检查4张真实PNG：加入case1/2即时退出、宿主case3即时退出、加入case3清扫后，右上角仍有原生敌人及血条，未见本轮白色矩形。这只是这些帧的人工视觉检查，不能保证任意场景/相机/帧都无白块。

## 观察到的失败与修正

所有旧输出保留，失败在当轮journal即时记录；不将驱动纠正倒推成生产根因。

| 轮次 | 结果与含义 |
|---|---|
| final14–19 | 编译/条件等待/原生武器对象链/单mask引用前提修正；直接draw现场mask可能全透明，改为独立graphics.copyFrom。final19突然停止来源未定。 |
| final20 | 旧905实测P2；P1尚未实测。 |
| final21–22 | 恢复候选仍红；旧测试现场写mask污染已删除，随后只读oracle仍在即时退出红。 |
| final23–26 | 原8case扩展前的7case恢复仍红；25是驱动AS3控制流编译失败；26取得12px alpha差证据。 |
| final27 | 去二次smooth后遮罩光栅绿，字段小数位置裁剪仍红。 |
| final28–30 | 独立副本未生成，条件/异常取证，不能把缺日志当成已证明异常或网格有效。 |
| final31 | 实际5px grid分支的严格对照绿；元数据为空回落1px的字段仍红，前后字段矩阵与采样区域一致。 |
| final32 | 早ENTER_FRAME完整capture后只有case0注册、无DONE；没有FAIL也不是通过。为何停止未认定。 |
| final33 /62fe2777d4 | 改纯引用observe＋last/captured分离，8case两端各149 PASS/0 FAIL/1 DONE；51源/138验证/57保护指纹独立核对，PID49528/9068已退出。仍含生产DEBUG，仅诊断候选。 |
| final34 /4ce66e3065 | 移除DEBUG/收紧metadata后两端149/0/DONE，但**实际两端case4-leave PNG明确白块**。旧字段hash及40帧后孤儿检查遗漏即时无持有者Shape；停止联合门禁/部署。 |
| final34旧905负控 /6576f2690c | 两端116/33/DONE、vis/hpbar即时为空，无游戏错误。审计初次v/h键名误读，保留initial receipt后按实际vis/hpbar JSON只读纠正，无重跑/断言变化。 |
| final35–36 | 新增即时退役mask无引用时不能visible的只读检查，149原断言保留；35 main接点编译错，36改为mod.main、在同a963字节上先验证红。 |

final33 receipt：`build/m46/final-33/restore-closure-audit.json`。其余原运行/result/log、PNG与输入闭包在各final-N/及build/cooperation/<run>保存；联合审计将汇总实际计数和hash。

## 推测与尚未验证

- 早回调完整图形工作是final32重要变量；pure observe的下一轮成功支持避免该工作，但没有单独因果实验，不能认定它就是卡死根因或声称性能普遍改善。
- 当前duplicate孤立Shape抑制仍按已观察RV格式签名判断，不能推广任意第三方白色绘图；整Tile5px回退也与当前RV安装格式耦合。case7仅保护last-observation之后的新接管。
- 所有房间/换世界路径、全可见→部分可见、全部Boss/红外分支、长时间高负载组合未穷举。位图dispose仅源码静态审查，没有运行时disposed-storage内部观测。
- `final-11 /531c0edabc`匿名Timer #1009来源未定未修，稳定重连仍在明确排除范围；真实主动leave检查不证明重连稳定。
- UI设计/HTML与此候选源码无关，NetHud尚未改版。

2026-10-06追加：R2指出unreleased且current===last的alias mask替换后可能仍visible。root立即核对final34两端case4即时PNG，看到白矩形；此前4张case1/2/3的有限视觉检查没有覆盖此窗口。后续恢复必须同时满足字段裁剪和即时退役Shape不作为普通内容绘制，不能只等RV下一轮清扫。

2026-10-06追加（37–39）：37的明确restore栈显示maskReferences递归#1009；38实际记录MovieClip but1–but5 numChildren=3但getChildAt(0)为null。加空节点守卫后原149项全部通过，只有新即时case4两个retired无持有者/visible检查及真正PNG白矩形仍红，证明字段恢复和孤立遮罩是可分开的缺口。39移除诊断，退役capture只处理已观察current，不把后来者升为last；再在替换后隐藏确实无引用的非native旧alias。当前39尚在验证，不计通过。此局部restore栈不解释早先匿名Timer、final19/32停止原因。

2026-10-06追加（39实测）：1beb6133c4两端163/0/DONE，149原项＋14同帧退役项。固定PNG门槛在两端case4原失败图捕获1094/119起32×24白矩形，39的14张即时图全部为负；两张原失败case4真实图由root人工核对，也没有白矩形。51源/139验证/57保护闭包独立核对，生产DEBUG已移除。根修复与当前byte d4c42d1f…详见restore-closure-audit.json。13组联合门禁尚未齐全，不标总发布绿。
