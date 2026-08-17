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
    summary: "真机双实例（pfe2/pfe3）：幽灵换用 visualPlayer 视觉并按位移驱动
      osn 标签，stay/run/walk/jump 双向流转无异常"

date-updated: 2026-08-15
---

# 实验：M3 幽灵姿态动画（visualPlayer 视觉驱动）

## 目的

让远程玩家幽灵不再是"站桩"，而能按远端位移播放 stay/run/walk/jump 姿态。

## 关键发现（见 shared-knowledge/rendering/facts/player-vis-anim-pipeline.md）

- visualStabPon（UnitPonPon 默认视觉）没有行走动画：`osn.pon` 的 32 帧
  无标签，是体型选择帧——站桩 NPC 视觉。
- visualPlayer 有完整姿态系统：`osn` 是标签壳，`osn.body` 是动画体；
  驱动模式 = `osn.gotoAndStop(标签); osn.body.play();`（与 UnitPlayer.control
  同款）。

## 实现

- 幽灵仍是惰性 UnitPonPon（doop/unres/fraction=100/disabled），但 spawn 时把
  `vis` 换成 `new visualPlayer()`，并按 UnitPlayer 构造方式初始化
  （osn.stop()、隐藏 pip2/inh/cryst/fetter/rat/shit/svet）。
- 姿态映射（每快照 20Hz）：dy!=0→jump；位移≥6px→run；≥1px→walk；否则 stay。
  标签变化时才调 gotoAndStop+body.play（防重启动画）。

## 结果（日志证据，双向）

```
RConnectGame: ghost #0 spawned at 1066,800 qname=fe.unit::UnitPonPon
RConnectGame: ghost #0 anim:  -> run
RConnectGame: ghost #0 anim: run -> stay
RConnectGame: ghost #0 anim: stay -> run
RConnectGame: ghost #0 anim: run -> jump
RConnectGame: ghost #0 anim: jump -> walk
RConnectGame: ghost #0 anim: walk -> stay
```

- 测试方法：autoMove=1 让本地玩家每 5 秒在 4 个点间传送，远端幽灵按位移
  流转姿态；全部标签存在、无异常。

## 结论 / 待办

- 姿态驱动链路可用。阈值（run≥6px/walk≥1px 每 50ms）是按 1.02 步行节奏粗估，
  待真实联机观感校准。
- 视觉观感（幽灵是否与玩家一模一样、是否过于显眼）需人工确认；后续可考虑
  加名字标签或半透明化区分幽灵。

## 附：断线重连验证（同轮）

- 宿主进程被 kill → join 侧日志：`link closed, auto-rejoin try 1/20` →
  `link failed, auto-rejoin try 2..4/20`（2s 间隔持续重试）；
- 宿主重启后：`connected to host, sending hello` → `welcome id=1` 自动恢复，
  幽灵重建（`ghost #0 spawned`）并继续姿态同步（stay→run→jump→walk→stay）；
- 宿主侧重新 `peer 'JoinB' joined` + `ghost #1 spawned`。
- 结论：意外断线两端自动恢复，状态管道完整重建。重试统一走 maybeRejoin
  单通道（避免新旧两套 Timer 竞态双连）。
