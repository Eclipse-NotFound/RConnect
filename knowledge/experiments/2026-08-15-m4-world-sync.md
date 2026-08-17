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
    summary: "真机双实例（pfe2/pfe3，同存档模板 PFEgame0.sol）：双方新档进入
      rbl/loc0_0 同房间，单位快照 27/27 持续全匹配镜像"

date-updated: 2026-08-15
---

# 实验：M4 世界一致性（身份握手 + 单位镜像）

## 目的

验证联机双方是否处于可互相理解的世界：同一地图/房间/坐标源，以及
宿主权威单位状态能否镜像到客户端。

## 关键结论（实测）

1. **同模板新档 = 确定性世界**：两个实例各自从同一份 PFEgame0.sol 模板
   开新档后，进入**同一地图（rbl）、同一房间（loc0_0）**，双方坐标同源
   （宿主被 autoMove 挪到 966,900，本机 966,800——同一坐标系的相邻点）。
2. **单位集合一致且可匹配**：`loc.units` 在双方世界各 27 个单位，**按
   `Unit.id` 匹配成功率 100%**（持续多轮 27/27），无 id 冲突。
3. 宿主每 200ms（5Hz）广播单位快照（id/坐标/朝向/sost/hp/fraction），
   客户端按 id 匹配后 setPos/setVisPos/sost/hp 镜像，运行无异常。

## 日志证据

```
RConnectWorld: host=rbl/loc0_0@966,900 mine=rbl/loc0_0@966,800
  -> landMatch=true locMatch=true
RConnectNet: unitsync matched 27/27   （持续）
```

## 已确认的公开身份字段

- `World.game` → `Game.curLandId`（String）、`Game.curCoord`（String）——公开；
- `World.loc` → `Location.id`（String）——公开，即房间 id；
- `Location.landX/landY/landZ` 公开；
- `Unit.id` 公开（本模组幽灵标记为 `rconnect_ghost_N` 以便过滤）。

## 已知问题（M5 课题）

- 客户端自己的 AI 仍在运行：被镜像的单位在两次同步（200ms）之间会被本地
  AI 挪动，再被宿主状态"拽回"——近距离看有抖动。彻底解决需"客户端侧
  冻结被同步单位的 AI（disabled）或完全权威化"，涉及战斗结算归属，M5 决定。
- 跨房传送：宿主换房间后客户端不会跟随（welcome 后 worldInfo 不再更新）。
  `World.ativateLoc/ativateLand` 是公开入口，M5 调研传送同步。
- 双方必须同模板（或同存档）开局；不同进度的存档世界不兼容。
