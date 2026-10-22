# 屏外身体位图只读核查

结论：准确 recovery21 的身体变帧绘制没有屏外裁剪，但现有密集夹具**没有形成明确的屏外身体负载**，CPU 证据也没有把卡顿指向屏外 blit。此次停止于核查，不实现候选，不改变动画、网络频率或任何门槛。

## 先纠正实际场景

读取冻结 after-render 驱动及原始 `build/cooperation/b3d7b8558b/{host,join}.log` 中的 `DENSITY FIXTURE`，双方准备状态相同：

| 项目 | 实际值 |
|---|---|
| 原生房间 | 48×25 格，即 1920×1000 像素 |
| 视口 | 1280×800 |
| 相机/显示变换 | isZoom=2，scaleV=2/3，visual=(0,66) |
| 房间投影 | X=0..1280，Y=66..732.67，整张房间能放入视口 |
| 80 敌人位置 | 1 只 X=251.8、78 只 X=321.8、1 只 X=331.8；全部 Y=960 |
| 敌人中心投影 | X=167.87..221.20，Y=706，在左下方屏内 |

`SustainedDensityTestDoc.prepareDensityArena:357–379` 把原两只放在玩家 X+90/+170，其余 78 只均放在玩家 X+160。`DensityFixture:40` 明确 `setZoom(2)`；`CorridorFixture` 重设场景并恢复显示附着，没有把敌人铺满地图。计时阶段 `:581` 只对原地位置作小幅 ±2 摆动。因此“房间 48×25”不能推出“80 只分布在地图各处且多数屏外”。

这是已保存的准备快照和驱动刺激的结论，不是每帧每只身体像素包围盒的测量。`visualStatus` 的 visible/非空检查也不是视口相交检查；不把它当作额外的裁剪证据。

## 准确 21 的绘制路径

- `fe/unit/RConnectAnimationAccess.as:86–111`：姿态具有 blit 且动画存在时，按动画 id、整数帧号、visData 身份判断是否需要 `u.blit`；没有 isVis、visible 或相机矩形判断。**同一已画帧已有缓存，不能说每次 tick 都复制位图。** 改变帧号的真正屏外单位在此路径仍可能复制位图。
- `UnitPresentation.animateBody:457` 仍要完成相同时钟的姿态接收；`tick(...,!paused&&!clocked)` 对有时钟的姿态不再自行推进动画。位置、手臂、枪械、枪口、弹体不是可随身体一起跳过的内容。
- `GameBridge.tickFrozenAnims:6392` 先按 `u.loc===loc` 排除其他房间单位。隐藏房间/分房已有位置身份边界，不应以新屏幕裁剪替代。
- `GameBridge.applyUnitView:401`、`unitCanShow:419` 明确把 isVis 用于隐藏/伪装的游戏语义，斑马和天角兽即使不可被瞄准也可能有淡淡的可见像素。isVis **不是屏外标志**，不能直接拿来跳过重画。

公共原生 1.02 参考中，`Unit.blit:2863` 直接调用 `visData.copyPixels`；`UnitRaider.animate:399–487`（实际 Slaver 的父类）和 `UnitMerc.animate:158` 依动画状态 blit，并没有按屏幕位置或 isVis 裁剪。原生 disabled 会跳过 Unit.step，而加入侧正因此由 RC 接管显示；不能把原生 disabled 当作可删掉 RC 绘制的依据。这些原版类是公共参考，不伪称对本轮宿主新导出的逐字证明。

## 现有 CPU 能证明什么

准确 20 与 21 的 GameBridge、UnitPresentation、RConnectAnimationAccess、RemoteMotion 字节相同，指纹见 evidence.json，故可参考两次既有诊断中的这条实现路径。

| 加入侧诊断 | CPU 样本 | AnimationAccess.tick 包含栈 | animateBody 包含栈 | Unit.blit / copyPixels 包含栈 | [render] |
|---|---:|---:|---:|---:|---:|
| 043b72eaec，ENTER 至最终 RENDER | 958 | 1 | 4 | 0 / 0 | 1 |
| b3d7b8558b，最终 RENDER 后至下一 ENTER | 1614 | 0 | 0 | 0 / 0 | 410 |

样本数量有限且窗口不同，0 样本不证明零成本；包含栈相互重叠，不能据此计算可节省 CPU 比例。后一组 `[render]` 是运行时渲染，既不能指定为敌人身体，也不能指定为 GPU 位图上传。现有资料没有“某次屏外 blit 的耗时/上传次数”证据，不能把 410 样本归给这项方案。原性能失败保持，无新性能资格。

## 接口与风险边界

现有 Camera 公开了 scaleV/vx/vy、屏幕大小以及 `setKoord`，但本次所查的原生实体/相机路径没有现成的“身体位图确定在视口外”谓词。若未来有真实屏外成本证据，应基于**当前显示层变换和身体实际边界**判断；中心点、碰撞 scX/scY、isVis 都不足以替代。每帧额外 getBounds/变换本身有成本，本轮不增加这类扫描。

只跳 blit 也必须留下重入补画责任，不能把未画帧记入 painted 缓存；相机移动、缩放、旧帧重入、visData 更换、SATS 暂停都可能要求不推进时钟就补上当前帧。原生 `Sats.getUnits:453` 以相遇/可选中/视线和 getTileVisi 筛选，再由 `drawUnit:361` 直接画现有 vis；它不是屏幕矩形筛选。因此不能假定屏外身体当前帧永远没有其他读者。隐藏房切换仍须绑定当前 loc，暂停或房间恢复后的首显不能读到旧位图。

这些是将来实现必须解决的条件，**不是本轮实现计划或已发生的新故障**。当前场景动机被实际快照否定，且没有净收益证据，故不继续制造优化候选。

本目录仅新建只读结论和小型摘录；未改源码、夹具、旧结果、配置或安装，未编译、未运行 AIR。
