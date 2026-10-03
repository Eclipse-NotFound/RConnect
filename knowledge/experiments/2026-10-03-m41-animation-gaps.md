---
domain: rendering
type: experiments
game-version: ["1.02"]
confidence: medium
verified: true
discovered-by: RConnect
date-updated: 2026-10-03
evidence:
  - kind: runtime-experiment
    summary: "真实TCP双端、精确生产字节外部驱动；普通/武器掉落、原生肉食灵暂停恢复、蜘蛛地雷完整爆炸与拾取控制。"
  - kind: decompiled-game-code
    game-version: "1.02"
    symbol: "fe.loc::Loot.step/run; fe.unit::UnitBloat.animate; fe.unit::UnitMsp.dropLoot; fe.weapon::Bullet.explVis"
---

# M41 合并候选：掉落、原生飞行时间轴及死亡爆炸

本记录来自「RConnect (2)」会话 `01a0ffcd-eed2-7e50-8c9c-9b2cb2e3f495`。用户在两个会话授权协调，最终生产候选冻结、全部回归、版本号、部署、MEMORY/journal与合并提交统一由「RConnect」会话 `01a086bb-378c-7f60-b8e1-50d90ffa0996` 完成。本会话不独立覆盖 release。临时目录 `build/m42-animation` 仅为避开并发工作的 `build/m41`；最终版本属于联合 M41 / 0.2.13-dev。

当前：联合M41 / 0.2.13-dev已部署，13组503项同字节门禁和正常加载冒烟通过。最终安装SHA256 `8f62e2dda36447d7c016f6cbab05da62e5a62542ae6b6df6beeb2ff022f477fa`；详见[M41部署记录](2026-10-03-m41-feedback.md)。本记录保留动画定位过程和交接构建，不将交接构建混作最终安装字节。

## 已复现的问题与修复

1. **掉落物卡住/跳动**：旧版普通掉落在5Hz快照直接设置X/Y、清速度，而 `Loot.step` 在 `stay=true` 时不会更新vis，导致实测225帧显示位置不动。改为携带源游戏帧时间，通过现有 `RemoteMotion(200)` 保存短轨迹，在同一帧时间采样；重复RENDER不额外推进。`RemoteLoot.run` 只在网络控制期间停用第二套重力位移，仍运行原生交互/吸取检查；本地冲量、念力、吸取和拾取请求接管时退出网络轨迹。移动显示时保留原生武器的10px垂直偏移，房间权属切回后恢复原生物理。不会新增库存规则。
2. **肉食灵飞行动画**：`UnitBloat` 的 `animate()` 为空，实际是子 MovieClip 自行推进。AIR返回的 `isPlaying=false` 不代表停住；宿主225帧/226次变化、加入侧只有20次。发送端逐游戏帧观察实际换帧，标签切换不作为持续播放。接收端在首次、显式停止/恢复和子clip替换时执行命令，不依赖本地getter来跳过命令。相同持续播放包不重启。
3. **蜘蛛地雷缺完整爆炸**：原生死亡先 `expl()` 产生metal/miniexpl，再 `dropLoot()` 调用真正的大爆炸；旧镜像只有前一类通用碎片。`DeathVisuals` 捕获单次自爆配方，只在已见活体转死亡时播放粒子/声音，不调用 die/dropLoot/Bullet.explosion，不结算伤害、破墙、AI唤醒或奖励。配方覆盖原生蜘蛛地雷、Mine各伤害类别，以及tr=2等离子滚轮；本轮逐帧TCP直接实测蜘蛛地雷。初始已经死亡的快照和重复死亡快照不重放。

## 红绿链与验证边界

精确输入、候选指纹和日志见 `m41-animation-evidence.json` 及各轮 `build/cooperation/<token>/run.json`。均为新AIR标识、新角色、冻结双端输入、`--responsive`进程策略；未动用户游戏、用户存档或安装文件。

| 轮次 | 结果 | 证据 |
|---|---|---|
| a18d7ab011，已安装M40 | 5 PASS / 4 FAIL | 掉落225帧全停；bloat1/8各仅20次变化；地雷只有miniexpl |
| 3b3b99eaa4，仅加入源帧观察 | 7 PASS / 2 FAIL | 两种肉食灵都226次变化；掉落/爆炸仍失败 |
| 724bc90968，加掉落轨迹 | 8 PASS / 1 FAIL | 接收123帧0停顿；地雷完整爆炸仍失败 |
| ab825a9cb5，完整效果+扩展场景 | 20 PASS / 1 FAIL | 爆炸、抛落、偏移、交互通过；bloat1暂停恢复后仅56/128次变化 |
| c65472ff37及pause2 | 各21 PASS | 仅加探针曾偶然通过；不能当作上一失败已修复 |
| 3ca204dd44，同帧停止/恢复定向红测 | 21 PASS / 2 FAIL | 初次停止无效；恢复后51帧零变化但isPlaying仍true |
| 879d5a8e63，接收显式状态转换 | 23 PASS / 0 FAIL | 两个同帧边界、原始网络暂停恢复和全部掉落/爆炸通过 |
| bc8576b407，最终动画断言 | 25 PASS / 0 FAIL | 恢复段>85%连续换帧要求也通过；接收掉落0停顿 |
| 80f242da7e，既有GameplayGap | 24 PASS / 0 FAIL | 实际拾取原生入包、独占领取、物品属性、XP/存档点等 |
| fb78e3a67e，GameplayNetwork | 0 PASS / 1 FAIL | 首个测试ready早于宿主测试监听；业务场景未启动，交统一门禁修测试握手 |

`3ca204dd44` 同时证实了两个方向：原生自动播放时flag可为false；真正停住后flag可为true。后者使旧的“同帧、标志相同则跳过gotoAndPlay”漏掉恢复。最终夹具另增恢复段>85%帧变化要求，总计25项，避免仅用整段平均掩盖局部停顿。

最终本会话候选90057字节，SHA256 `d74c9c53bd1c480e28bc6b9115c0c5c6c13c9d4717a01b3889abecf72f995c6a`。它包含同期血条/数字修复，前述定向测试未单独隔离其影响；动画因果轮的特定失败/转绿链已分别保留。全部生产源码指纹在证据JSON的 `production_sources_at_handoff`，最终安装指纹以发布会话为准。

`fb78e3a67e` 的host日志只有room resumed之后的`GAMEPLAY TCP host wait`，join收到grant后已发唯一ready；测试把 `watch(link)` 放在rooms门控之后，首包可能早于监听。双方网络心跳和单位同步仍运行，无新游戏错误对话框。这不是已完成的业务场景，未记作掉落回归通过。交接后由发布会话修测试准备握手（提前监听、等待阶段重发、宿主幂等）并重新验证。

验证入口：`tests/AnimationGapsTestDoc.as`，外部驱动构建后运行 `tools/run_coop_regression.py --candidate <SWF> --effects-driver <driver> --effects --all-mods --responsive --seconds 115`。既有 `GameplayGapTestDoc` 同参数seconds110；`GameplayNetworkTestDoc` seconds190。最终联合门禁还需既有平滑、画面、战斗、SATS、分房、合作、持续密集测试，归统一部署会话执行。

交接后的只读审阅补充：`Unit.explosion` 构造不入链Bullet后立即爆炸，默认 `inWater=-1`，只有后续 `run()` 才检测水；本次三类直接自爆不会先run。因此发布会话采纳将配方固定 `water:false`，匹配原生而非按当前位置擅自选择水中特效。按其协调要求，夹具增加一项原生不入链Bullet对照（临时湿砖、无伤害调用、立即恢复砖值），**最终AnimationGaps预期26项**。这不回写此前25项通过的历史；新增项由发布会话在重新冻结后验证。

未声称全敌人/全Boss动画已经穷举；云雾持续爆炸与脚本攻击事件不属于本次单次死亡配方。对刚入房即已死亡的敌人不补播历史爆炸。每帧数会随全部模组和运行负荷改变，定位轮不是通用性能提升结论。

## 资料与留档

采用已核验KB-000061 rev1（精确生产字节的外部驱动）与KB-000071 rev1（后台进程策略的对照纪律）。共享检索返回部分来源不可读，未把缺失视为无经验。原生MovieClip的条件和未知项另记共享库 `rendering/discoveries/movieclip-playing-state.md`；本模组代码与发布进度仍保留在这里。
