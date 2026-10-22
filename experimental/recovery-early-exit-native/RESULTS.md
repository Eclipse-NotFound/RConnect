# 退出许可修正实测记录

2026-10-22。准确 RConnect `0.2.24-early-travel2` / `d356483f927c608b5973982558127ce4feb0873a36676909ed3b3d6ac8b7acb3`，完整编译通过。仅 RoomSync 的两处许可结束时机及版本变化，其余 88 个 AS 与 early1 相同。

| 检查 | 实际结果 | 证据目录 |
|---|---|---|
| 旧 RoomSync + 完整真实 TravelGuard，同一新夹具 | 55 条到达、26 条失败，复现提前撤销许可与旧地图编号回写 | `build/m52/recovery-early-exit-baseline-component-01` |
| 修正版 + 完整真实 TravelGuard，同一新夹具 | 79/0，通过 | `build/m52/recovery-early-exit-fixed-component-01` |
| 既有提前交付回归 | 36/0，通过，原断言不变 | `build/m52/recovery-early-exit-room-component-01` |
| 既有原生旅行回归 | 109/0，通过，原断言不变 | `build/m52/recovery-early-exit-legacy-component-01` |

基线和修正版 24 个夹具源文件只有真实 RoomSync 不同。修正版多出的 24 条为六轮各四个成功 ACK 后才能到达的原断言，没有删改负例。独立复核见 `../recovery-early-sandy-evidence/authorization-components-audit.json`。

三组修正版共 224 项实际 AIR 组件检查通过。组件使用原生 World、网络等显式替身，不证明实际绘制、加载耗时、完整游戏功能或发布资格。未变的 Gate 等旧模块没有为凑总数重复测试。

同一准确候选的原生有界诊断 **f95499e5a7** 已完成，主侧 47/0、加入侧 36/0，三段均通过。重访 grant 仍在原生 exit10 到达；之后加入侧 exit9→3→0，地图编号保持 random_mane，旧卡死的触发条件没有被测试绕开。两侧实际完成 ready/activate，三段最终 Sand 许可均 held=false；双方出生距离 1/0/1px（原验收容差80px），六次真实按下／松开控制检查通过。

除了生产 RConnect 从 10B 改为 D356，实际宿主、资产、Sand、旧 RV、诊断驱动、其他模组和非 RC 配置与旧失败 5b404cdea1 相同。准确证据 `build/m52/recovery-early-exit-native-01`，独立审查 `../recovery-early-sandy-evidence/early2-revisit-native01.md`。

诊断轮 elapsed：主侧 10674/2696/6672ms，加入侧 10924/2778/6671ms；主侧 controlResponseElapsed 11762/2879/7593ms，加入侧 11827/3446/7414ms。诊断开销和单人准确新组合尚未配对，这些数字不提供性能资格。原无诊断驱动的同候选双人／单人对照继续，不能把死锁修复称为加载目标已达成。

原无诊断双人 **6b322acc0f** 也已完成三段，主47/0、加36/0，实际输入、模组、安装均通过原严格核对。elapsed 主11659/2223/6922ms、加11934/2469/6861ms；控制响应总耗时主12718/2406/7960ms、加13045/2875/7667ms。证据 `build/m52/recovery-early-exit-scene-dual-01`；不能拿去除观察器前后两轮直接判定性能变化。

同候选单人 **981583ffbc** 已实际完成三段，35/0，elapsed 7051/1968/3370ms，控制响应总耗时7546/2254/3855ms。安装与输入核对通过，证据 `build/m52/recovery-early-exit-scene-solo-01`。此轮确认离线旅行与操作恢复没有回退。

独立加载路径审查发现，solo 与 dual 虽同种子同尺寸，入口位置和单位数组不同，完整场景等价尚未证明。精确 CS7F1F 来源中的 NativeSceneAdapter.spawn 使用独立 Math.random，布局种子并不固定入口；首段两模式都走 beginMission/newLand，差异不是单人误读缓存。单人轮首先用于离线功能回归；只有补齐相应场景/入口工作量核对后才能用于正式性能比较。见 `../recovery-early-first-load-review/README.md` 与 `followup.md`，不把两轮差值叫作改版收益或劣化比例。

测试使用隔离 Sand003 和旧 RV7852，安装的 RV AB46 与 RConnect 574D 均未修改。尚无部署资格。
