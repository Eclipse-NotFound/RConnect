# 实验：M23 幽灵趴姿+悬浮残留修复（皮肤语义映射）——2026-08-28

- 用户报告（M22 之后）：双端视角中对方幽灵仍趴姿 + 有飞行药水效果。
- M16a"镜像对方真实 osn 标签"方案没有根治，本轮查明真正根因。

## 根因：同一标签、两张皮肤、两种语义

- **玩家皮肤（visualPlayer）**：`UnitPlayer.animate()` 的 idle 逻辑是——
  主状态 `gotoAndStop("stay")`（站立待机**基础段**，playhead 大部分时间
  停在 stay 段），随机触发 `free1/2/3` 小动作（短暂）。所以 idle 玩家的
  `vis.osn.currentLabel` **大部分时间读出来是 "stay"**，偶尔 freeX。
- **幽灵皮肤（NPC 小马视觉，UnitPonPon）**：M16a/M20 实证 "stay" 渲染为
  **趴/卧姿**（NPC rest pose，视觉上贴地/微浮——这就是"飞行药水效果"
  的主要来源），free1/2/3 才是站立待机。
- M16a 把源标签 1:1 镜像 → 幽灵大部分时间被 set 到对方的 "stay" →
  **趴姿 + 悬浮**。M16a 当时的"验证"恰好抓到 free3 瞬间，误判已修。
- 排除项：UnitPonPon 覆写 `animate()` 为空，游戏不会每帧重置幽灵 osn
  （"活体覆盖"假设不成立）；`isFly` 对 UnitPonPon 无置真路径
  （全游戏只有 fly 药水/Effect/alicorn 会置真），M18b 的 isFly=false
  本身没失效——悬浮是趴姿的呈现而非独立 bug。本次仍补了 `levit=false`
  （Obj 基类 public 字段）与 isFly 一起压制。

## 修复（GameBridge.driveVisAnim）

- **皮肤语义映射**：玩家 idle 族 {stay, free1, free2, free3} 映射到幽灵
  站立待机族——`stay → free1`，freeX 原样透传；run/walk/jump 等移动标签
  两皮肤语义一致，原样透传；其余未知标签仍走 catch 兜底。
- 效果：幽灵 idle 显示 free1/2/3（站立），**永不进入 stay**。
- 已知代价：源玩家坐下（isSit 也用 stay 段）/爬行（polz 是 body 帧，
  不改 osn 标签）时幽灵显示站立——osn 标签层面本就无法区分，记录为
  已知限制。

## 验证（双实例 m23_run2）

- 幽灵 osn 标签全程 **0 次 stay**；idle 呈 free1/free2/free3/pinok/trot
  （受击/小跑为源端真实状态镜像），死亡复活走 die/res（M10b 流）。
- 双向都有幽灵（ghost#0/ghost#1）、零错误对话框、心跳健康。
- 悬浮的视觉确认需真人观感（无法从日志判定像素级离地高度）。

## 附带修复：开机链门控（跨模组冲突暴露）

- 夜间并行 TDFC 会话部署了 v0.5.0，其 AutoTest 激活条件为实现层的
  `applicationID != "pfe"`（文档说的是只认 app_tdfc_test_* 描述符）——
  **把 RConnect 的 pfe2/pfe3 测试实例也劫持了**：双方抢开新档 + TDFC
  强制放行菜单打断开机链 → landData 未就绪时 Game 构造器 #1009
  （TDFC 源码注释自己写着这个教训），双端世界全建不起来（m23_run1）。
- RConnect 侧修复（本模组该做的）：`startGame` 调 newGame 前等待
  `world.landData != null`，未就绪就 return 由 Session 周期重入。
  m23_run2 实测与 TDFC AutoTest 共存可正常开局。
- **TDFC 侧问题（只报告不修）**：AutoTest.init 的激活条件应与其文档
  一致（前缀匹配 app_tdfc_test_*，而非 != "pfe"），否则会劫持一切
  非用户实例。已记 MEMORY 已知问题，待转告 TDFC 会话/用户。

## 教训

- **跨皮肤镜像标签前先建立语义字典**：同一 MovieClip 标签在不同视觉
  资产上语义可能相反（stay=玩家站立/幽灵趴下）。镜像"渲染意图"而非
  "播放头位置"。
- **日志级验证会漏呈现类 bug**：M16a 抓到 free3 瞬间就宣布修复，
  真人观感才暴露 stay 占大头。姿态类修复需要密集采样（心跳 10s 粒度
  不够，run11 的每消息 dump 才定位）。
- 双实例测试环境是**共享的**：并行会话部署的其他模组会改变测试实例
  行为（TDFC AutoTest 劫持）。断言失败先分辨"我的回归"还是"环境漂移"
  ——对比历史日志与产物 mtime 是最快路径。
