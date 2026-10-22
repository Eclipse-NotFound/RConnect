# 有限接口评估：不继续生产实现

## 准确18 / ACC 中已经可达的链

- `WallSurfaceBridge.onNative("after")` 把第一个副本的变化交给 `changed`，同时把整个观察矩形加入 `entry.covered`。后来的 core 即使色值不同，也因 covered 不再采集。
- ACC `Grafon.sceneRestoreMarks` 最后调用 `rconnectWallNotify("raster")`；18 `WallImpactVisuals.surfaceRaster` 调用 `WallSurfaceBridge.replay`，从 `state.cells` 写入 scratch。此时 cells 已可能含临时 gutter 色。实际 core 原生色会在最终复制前被自己的重放覆盖。
- 因而仅在最终复制后读取 BitmapData，再称作“core 的正确颜色”，不成立。新增组件直接记录 raster 前后的 uint 验证这条链；它不改变生产回调顺序。
- 另一个静态边界是 `acknowledge → put`。ACK 清空 pending 后，`put` 对 large 像素执行 `cell.paintOrder[key]=++surfaceOrder`，即使颜色相等。以后旧 native mark 用原 `entry.order` 校正，会被 `surfaceChanges` 的 `paintOrder > order` 拒绝。这是保留较新队友像素所需的同一屏障；不能简单删掉。

## 曾考虑的最小发布接口（仅方案，未实现）

```text
native mark（已有 birth / life）
    │
before → after：本次 token，绑定 bitmap / loc / generation / 观察片段
    │
    ├─ raster 重放：可能已经污染待发布颜色 ← 不能仅向后移动通知
    │
实际 style 复制 / batch 分块 / warm 交付
    ├─ 成功 → publish-core(token, 最终 bitmap, 精确最终 copy clips)，至多一次
    └─ 取消 → 仅释放本 token，不确认任何像素，不全局搜索
```

只增加这一个通知种类仍不够。要避开上述污染，必须在 `raster` 前暂存本次真正原生的稀疏颜色，再跟随最后生效的 style copy clips 移交；不能把早期 scratch、随后被覆盖的 style 或取消的 warm 当作最终输出。若同时要求“core 不在时先把 gutter 发出去，core 可见后再校正”，自己的 ACK 和后续权威写入又必须能区分临时本地样本与真正较新的队友颜色。现有 wire/ACK 没有这份来源身份；仅凭颜色相同判断会破坏第4条反例。

这会使原本的一次完成通知承担跨绘制尝试、确认回包及权威顺序的责任。为当前极少数单通道一级差异继续叠加 provenance、回滚或新的长期历史，成本超过已证明的收益，也不解决主要长帧。**因此停止在反例和风险说明，不修改 ACK、权威顺序、线包、绘制频率或生产时钟。** 本目录没有第二套房间历史、全局发布队列、强制绘制或通道值容差。

single / batch / region / warm 的最终复制区域仍需将来统一覆盖；现在没有完成这些宿主接线。不得因本目录的接口图或原69组件通过而宣称已经修复。此前错误点尚未完整追溯，本次完整crop四轮通过也没有被撤销。
