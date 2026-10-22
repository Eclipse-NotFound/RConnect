# 准确21镜像敌人显示步进：只读结论

**没有证实敌人身体/武器同时被原生 step 和联机显示重复推进；现有运行计数反而与每个 ENTER 帧一次 `tickFrozenAnims` 完全一致。另有直接证据证明同一 ENTER 区间重复发生终视野 RENDER 修整，但它不是第二次敌人动画步进。** 本轮到此停止，不新增优化、采样或测试框架。

## 调用入口及阻止重复的边界

| 路径 | 准确源码与实际职责 |
|---|---|
| 原生逻辑 | 1.02 `MainMenu.as:85/804` 将 `mainStep` 注册到 stage ENTER（默认优先级），经 World/Land/Location 调单位 step。`Unit.as:1761–1769` 在 `disabled || trigDis` 时立即返回；其后的 `animate`（1836）和 `childObjs[i].step`（1852）不会执行。UnitPet 的唯一额外 step 覆写仍调用 super.step。 |
| 镜像冻结 | 准确21 `GameBridge.as:5720–5726` 每次全量应用重写 `disabled=true`，登记 `_frozen`；`6203` 房间权限同步 `freezeAI=!authority`。渲染修复临时放开 disabled 仅为 addVisual，finally 恢复（313–315），不调用 step。 |
| 常规显示 | 构造器 `132` 只注册一个 stage ENTER `onMirrorFrame`（-10000）；`362` 调 `tickFrozenAnims`。后者从 `_frozen` 每单位读取一次：sample/setPos/setVisPos → 必要时 apply → animateBody → tick（6392–6434）。源码无其它常规调用点。 |
| 暂停补画 | `onVisForceFrame:254` 仅 `_mirroring && coopPaused && _pausedMotionDirty` 时补调。`queueUnitMotion`/进入暂停会置 dirty；tick 结束清除。1ms Timer 只 invalidate/updateAfterEvent，不直接 tick。ENTER 后收到新的暂停终态时，同一区间额外调用可达且有目的；当前密集样本没有证明发生。 |
| 递归保护 | `_animatingMirrors` 拒绝同步重入；RENDER 同时检查 `_forcingVisibility/_animatingMirrors/_applyingUnits`。不再以 EXIT_FRAME 注册整个敌人动画循环，避免 gotoAndStop 内同步广播导致重复步进。它不是按时间戳永久去重，暂停新数据仍能补画。 |

`UnitPresentation.apply` 在这条帧路径收到 `deferTick=true`，不会又内部 tick。新选择的 blit 快照可能在 apply 和 animateBody 各经过一次 `RConnectAnimationAccess.receive`：前者安装原生动画属性，后者安装同游标插值帧；receive 本身不 step、不 blit。真正 `RConnectAnimationAccess.tick` 每轮一次，clocked 身体传 `advance=false`，且 painted 字典按动画/帧/bitmap 身份避免同帧重复 blit。没有有效网络姿态的兼容分支才用一次本地 tick/animate。

武器由 `UnitPresentation.tick:438–445` 更新枪口计数并调用 `w.animate()`，不会调用 weapon.step/actions/attack。原生 `Weapon.step:914–925` 原本经 owner.childObjs 执行，已被 owner 的 disabled 早退截断。`Weapon.animate:1966` 的位置、翻转和准备帧选择仍正常保留。MovieClip 子时间线自行前进是显示播放；`RConnectAnimationAccess.tick` 对 clip 返回成功，不再额外调用单位 animate 重选动画，不能把自动播放本身算作第二次 AI/武器步进。

MirrorHitUnit 仅置于 `loc.units`，不挂 `firstObj` 逻辑链，借用身体 vis 供碰撞/SATS；它不是第二个会 step/animate 的身体。没有据此提出删除代理。

## 现有实际计数与 CPU 证据

读取 `build/cooperation/b3d7b8558b/join.log`，即已完成的 recovery20 after-render 诊断。21 与20 的 GameBridge、UnitPresentation、RConnectAnimationAccess、RemoteMotion **四份源码逐字节相同**；指纹及小型原始摘录见 `evidence.json`。该记录不能冒称21重跑结果。

原 driver 在进入测量区时清零 presentationTiming，每阶段打印累计值。将相邻累计值相减后：

| 阶段 | driver ENTER帧数 | motionCalls 增量 | viewCalls 增量 |
|---|---:|---:|---:|
| 0 | 65 | 65 | 128 |
| 1 | 76 | 76 | 152 |
| 2 | 78 | 78 | 156 |
| 3 | 76 | 76 | 152 |
| 4 | 73 | 73 | 146 |
| 5 | 70 | 70 | 140 |
| 6 | 75 | 75 | 150 |
| 合计 | **513** | **513** | **1024** |

因此这次有计数的密集运行没有显示额外 tickFrozenAnims 调用。日志仅一个 RC initialized，也没有重复构造回调的实证。计数不含逐单位身份，不能单凭它排除外部模组绕过 Unit.step 手工改帧。

after-render 的513行中，506行 `extraRenders=1`，其余7行没有额外RENDER；24个实际采样窗全记录一次额外RENDER。计数器只在该行已经见过 RENDER 后再次收到同一 stage RENDER 回调才增加，不能解释成事件名字相似。

这24窗合计1,614个 CPU 样本；其中64含 `onVisForceFrame`。该链内含 PlayerBodyEffects.apply 21、MirrorMasks.capture 19、probe 19（包含关系，不能求和）。没有 tickFrozenAnims、UnitPresentation.tick/animateBody、RConnectAnimationAccess.tick/receive、Unit.step、Weapon.step 或 MainMenu.mainStep 栈。另有410个 `[render]` 样本，无法只据该标签分到某个单位或动画。

**可以确认的是重复的最终显示修整回调，不能确认它重复执行敌人身体/武器步进，也不能把64个样本换算成可省毫秒。** onVisForceFrame 平时负责可见性、颜色/光晕、碰撞遮罩、血条、弹体及掉落物最终附着；只在上述暂停 dirty 分支才调用敌人动画 tick。额外RENDER的具体发起方、本机重绘工作中可安全省略的部分，本证据未定位，也不在本轮继续扩查。

## 资格限制

- 原生 Unit/Location/Weapon 的依据是公共只读1.02参考；本次没有导出运行宿主来重新逐类核验，也没有审查所有其它模组的手动推进。RC四份关键源与采样时源码的相等已实际核对。
- 采样窗口从 RENDER 尾到下一 ENTER 开头，常规原生 step 与 ENTER 动画本来大多在窗外；零采样不能证明这些函数从未运行。一次/帧的结论主要来自真实 motionCalls/ENTER 累计计数，不来自零CPU样本。
- 这是诊断证据，原性能失败与资格不变；没有编译、AIR、部署或生产编辑。
