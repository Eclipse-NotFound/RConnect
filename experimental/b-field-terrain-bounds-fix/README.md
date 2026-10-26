# B 地形实际边界同步补丁

统一验证（2026-10-26）：field22已通过原固定失败种子和普通随机轮的主130/加75检查，17项组件检查、开火前及破墙后像素与碰撞全部通过，已部署复验。准确指纹与测试路径见[统一验证记录](../../state/b-field22-validation-2026-10-26.md)；下文保留修正时的分析与计划。

基于准确 `build/ab/b190-field21-build`。本目录只有一个产品覆盖文件：`src/authority/SceneSnapshot.as`；在 `TILE` 表末尾追加 `phX1/phX2/phY1/phY2`。既有索引和 native021 保持不变，不修改门、色调或碰撞算法。

## 已证实原因

`build/ab/b-field21-terrain-seed-01` 固定种子 `2780491448` 重现了此前 `b-field21-final-01/terrainlive` 的基线哈希：主侧 `bc128cd5`，加入侧 `c1a70072`。基线和第一轮破墙后均有相同的 949 个像素不同，集中在裁图右下方已有的砖石。完整元数据比较只发现格 `(28,23)` 的实际边界不同：主侧 `[1120,1160,930,960]`，加入侧 `[1120,1160,920,960]`，`zForm` 都是 1。色调、房间参数、其余原有 TILE 字段、门/陷阱引用标志相同。数据与图片指纹见 `evidence.json`，原始 PNG 保留在上述结果目录。

原生 `Tile.setZForm()` 修改 `phY1`，`Grafon.drawKusok()` 绘制特殊形状时使用实际 `phY1/phY2`。旧同步表传了 `zForm`，却没有传实际边界；加入侧直接赋值各字段，不会调用 `setZForm()`，因而保留新建 Tile 的整格边界。补齐实际值也覆盖了可独立移动、改变的边界，避免加入侧根据形状猜算。

普通墙死仍满足 `TerrainPatch` 的精确增量判定，因为四个边界没有变化。若破坏同时改变边界，现有判定会拒绝增量捷径，继续按原生完整几何路径处理。

## 外置组件检查

`BTerrainBoundsChecks.as` 使用已加载的真实 `SceneSnapshot`、`FrameDelta`、`TerrainPatch` 和原生 `Tile`，没有复制这些算法。私有单格夹具不加入世界，无显示根和脏像素；不调用 `Tile.die` 冒充武器命中。共 17 项：

- 四边界属于实际确认表。
- 原生 `setZForm(0..3)` 的边界采集、经过真实 AMF 和 FrameDelta 后的值均精确一致（8 项）。
- 仅移动边界产生差量，保留小数，不修改上一份确认（3 项）。
- 普通墙死仍可增量处理（1 项）；任一边界同时变化都保守回退（4 项）。

供根会话复制进外置驱动目录，并在 `BTerrainCases.componentChecks` 已取得真实 `mod.access` 和 `domain` 的位置调用：

```as3
BTerrainBoundsChecks.run(mod.access,domain,
 function(ok:Boolean,name:String):void { check(ok,"component bounds: "+name); });
```

已静态逐项核对访问字段为 public，签名与当前产品一致；尚未编译或运行。旧 field21 会在首项明确失败并返回，不伪造后续通过。

## 根会话待验证

1. 编译 field22 和新外置准备版本；组件 17 项全过。
2. 原固定种子 `2780491448` 重放，完整区域像素断言保持不变，预期原有 949 个差异归零；保留旧失败和图片。
3. 继续真实双向轻机枪与爆炸破墙，验证碰撞、完整区域像素、增量计数以及普通 hp 变化不重画。固定种子属于诊断，不能替代正常核心场景验收。
4. 准确 field22 的核心功能和性能资格由根会话统一执行；未通过前不能部署。

SHA256：产品覆盖 `1de136c11631fa72feefc5adaf49b291d290a11d7fd54337be5a957d0855724a`；外置组件检查 `83d7e46897edc77b7d0b07a218cd748cfa8e4052869abb15ab83b44c58da9f7c`。
