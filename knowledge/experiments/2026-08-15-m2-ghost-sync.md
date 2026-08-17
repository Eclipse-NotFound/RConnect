---
domain: knowledge-validation
type: experiments

game-version:
  - "1.02"

confidence: high
verified: true

discovered-by: RConnect

evidence:
  - kind: runtime-experiment
    summary: "真机双实例（AIR app id pfe2/pfe3 + 临时描述符）1.02 联测：
      程序化进游戏、双向幽灵单位创建/渲染/驱动全链路通过"

date-updated: 2026-08-15
---

# 实验：M2 幽灵单位双向同步（真机 1.02）

## 目的

在真实游戏中验证：
1. 程序化进游戏（不经菜单点击）；
2. 远程玩家以幽灵单位形式出现在双方世界中；
3. 位置/朝向快照同步驱动幽灵。

## 关键机制（反编译 + 实测确认）

- **进游戏**：`World.newGame(0,"LP",null)` 是公开入口；但主菜单打开时
  （`MainMenu.active=true`）`MainMenu.mainStep` 只跑菜单逻辑、**不调用
  `World.step()`**，因此 newGame 之后的 `ng_wait` 流程（newGame1 建 gg →
  newGame2 进世界）永远不推进。解法：newGame 后约 1.5s 把公开字段
  `World.w.mm.active = false`（等价于程序化关菜单），游戏主循环接管后
  自动走完 newGame1/newGame2。
- **存档模板**：新 AIR app id（pfe2/pfe3）直接复制用户的
  `%APPDATA%\pfe\Local Store\#SharedObjects\pfe.swf\PFEgame0.sol` 到对应
  storage 即可被读取（无域锁问题）；用户真实存档全程未被写入。
- **幽灵单位**（本模组实现）：
  - 类：`fe.unit.UnitPonPon`（被动 NPC 小马，构造时自带 visualStabPon 视觉；
    `param4.tr` 选配色）；
  - 入世界顺序与游戏建敌一致：`putLoc(loc,x,y)` → `loc.addObj`（Pt 链 +
    addVisual 挂到 grafon 层）→ `loc.units.push`；
  - 惰性化：`doop=true`（无碰撞、AI 不选为 priorUnit）、`unres=true`（无伤）、
    `fraction=100`（F_PLAYER；findCel 只针对 loc.gg 主动索敌）、`warn=0`；
    `addVisual` 之后 `disabled=true`（Unit.step 早退、视觉保留）；
  - 驱动：`setPos` + `setVisPos`（含 storona 翻转）+ dx/dy/stay 镜像；
  - 销毁：`loc.remObj`（摘视觉）+ `units.splice`。

## 结果（日志证据）

宿主（pfe2）：
```
RConnectGame: startGame: calling newGame (try 1)
RConnectGame: autoGame: menu closed, world.step should take over
RConnectGame: first snapshot x=0 y=0 storona=1 hp=1070
RConnectNet: peer #1 'JoinB' joined
RConnectGame: ghost #1 spawned at 0,0 qname=fe.unit::UnitPonPon
```
客户端（pfe3）：
```
RConnectGame: first snapshot x=0 y=0 storona=1 hp=1070
RConnectGame: ghost #0 spawned at 300.50360581079224,320 qname=fe.unit::UnitPonPon
```

## 结论

- 幽灵单位双向创建/驱动/销毁全链路可用，游戏本体无异常。
- hp=1070 / storona / 坐标快照 = 真实玩家数据（Littlepip 新档）。
- 双方各进各的存档世界（坐标不同源），**世界一致性同步是后续里程碑**
  （M4：同一 Location / 同一地图同步），M2 只验证状态管道与渲染。

## 踩坑

- `gg`/`loc` 缓存必须周期性刷新（每 2s），否则进游戏后旧缓存导致
  autoGame 无限重试 newGame（会重置流程）。
- 宿主侧曾漏掉"把 peer 快照应用到本地幽灵"（只广播不回放），补齐后双向才通。
- 测试实例必须用全新 app id（AIR 单实例）+ 独立 storage，防止污染用户存档。
