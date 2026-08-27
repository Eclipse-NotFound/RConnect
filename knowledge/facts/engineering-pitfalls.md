# RConnect 工程关键坑清单（14 条）

> 2026-08-27 自顶层 HANDOFF.md §5 迁入（原文在 git 历史）。编号与实验文档对应；
> 通用部分已沉淀 shared-knowledge 与工作区技能（remains-auto-testing / remains-runtime-debug）。

1. **mxmlc**：函数内所有 return 都在 try/catch 里 → 误报"无返回值"，需尾随兜底 return；表达式上下文别用全限定名，先 import。
2. **#2023/死代码消除**：入口类不能当文档类；RConnectDoc 空 Sprite + 强引用 MOD_CLASS。
3. **UTF-8 帧长度**：长度前缀必须用 UTF-8 字节数（ByteArray.writeUTFBytes 后 .length），不是 String.length（俄文房间名曾致流错位）。→ knowledge/discoveries/utf8-frame-length.md
4. **isMeet 要求 !disabled**：disabled=true 的单位永远不被索敌。→ shared-knowledge/entities/facts/findcel-targeting.md
5. **UnitPonPon 构造自带 invulner=true**；战斗化身须显式关 doop/unres/invulner/disabled。
6. **冻结会被游戏解除**：setNull 流程与 command("activate") 都会 disabled=false 且 setNull 重置 hp=maxhp → 冻结必须每轮重写；伤害上报只限 fraction 1..99。→ shared-knowledge/entities/facts/frozen-units-unfreeze.md
7. **幻影伤害**：世界被替换（读档/换图）后旧 hp 基线误报（实测 152 条）→ 按 loc 对象引用变化重置基线。
8. **旅行挂死**：加载中旅行或目标=当前土地会挂死；同地图 gotoXY 跳任意房间也挂死（M5 教训，autoTravel 已移除）。travelToLand 有防护。
9. **读档前置**：gui/sats 只在 newGame 创建，直接 loadGame 会 #1009 → 先 newGame 骨架再走原版 comLoad。→ shared-knowledge/world-objects/facts/save-load-api.md
10. **中继伤害不能钳制**：客户端 gg.damage 有护甲减伤，中继"剩余血量"会收敛永不致死；中继原始命中量（hp 可为负不是探测失败）。
11. **dopusk 旅行门控**：身体部件任一 ≤1 时 gotoLand 只弹提示不执行——死亡回城后需治疗才能再旅行。
12. **AIR 测试实例**：单实例转发需唯一 app id（pfe2/pfe3）；日志在 `%APPDATA%\<id>\Local Store\RConnect.log`；trace 不进 stdout。
13. **版本探测**：mod 域读 loaderInfo.url 返回自身 URL——用 World.boxDamage 指纹（0.2=1.02）+ 实例 constructor。→ knowledge/discoveries/loaderinfo-cross-domain-anomaly.md
14. **触发器类 UnitTrigger**（trigplate 等）曾致宿主崩溃——测试钩子一律跳过（isTrigger 过滤）。
