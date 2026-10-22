# 重访超时：有界原生诊断与源级因果链

2026-10-22。原生执行由根会话完成，本审查只读；不改变任何原失败报告。对应 `build/m52/recovery-early-revisit-frozen-rv-native-01`，raw run **`5b404cdea1`**。完整可复算提取见 `audit_probe.py` 和 `revisit-probe01-audit.json`。

**已经定位到确定的错误状态：加入侧画面和实体已经在马哈顿，当前目的地字段却被旅行限制器退回基地，令完成判定永远无法成立。它不是首绘票据一直不完成。**

## 运行组合核对

双侧 `game / assets / production / harness / modules / mod_assets` 与原失败 `3b3c31c5f5` 逐项相同；外部诊断 driver 不同。RV 实际加载均是 **7852f61e…be86764**，并非本轮安装更新的 AB46。非 RConnect 配置全部相同；RConnect 运行配置含本次端口，未将其散列不同当成生产变化。安装前后未变。

原生程序完整等待到失败：仍只有前两段完成，缓存重访没有 ready/activated。诊断段2主侧 11 行、加入侧 12 行，低于各段 20 行上限，均无读字段异常。诊断不提供性能资格。

## 直接观测

下列 `t` 是加入进程自身的 getTimer，不与主侧直接相减。

| 阶段 | 加入 t | 可见状态 |
|---|---:|---|
| 新场景已构造 | 45768 | curLandId=random_mane，Land.act.id=random_mane，exit19；票据 waiting/unpainted 都 true |
| 交付前最后一条变化样本 | 46324 | 两个地图字段仍为 random_mane，exit13 |
| grant handler | 46576 → 48320 | 结束时 exit10、ready=true；处理耗时1744ms |
| restore 中第二次桥调用 | 48268 | 返回与第一次同一票据；matchesKnownTicket=true、sameAsPrevious=true |
| 下一条变化样本 | 51220 | **curLandId=rbl、Land.act.id=random_mane、exit0**；真实票据 waiting=false、unpainted=false，Grafon.pending=false、sceneViewReady=true |
| 95秒结束样本 | 140455 | 同样的地图字段矛盾、已完成绘制、仍 earlyPending/busy/entryPending |

两个桥回调都非 null。世界、Game、玩家、Land、Location、Grafon 相对于票据创建时的严格对象身份在后期均相同。这直接排除了“restore 换了票据导致 gate 等旧对象”作为本次原因。

主侧自己的目的地字段始终 random_mane，绘制和身份也正常；它等待加入侧确认，直至 handoff timeout。故主侧也被拖住。

到诊断 `dispose` 前，双方 Sand 许可仍 held=true。此时是同步失败后保留世界冻结的状态；不能将它称为正常成功释放，也不能在没有断线清理后观测的情况下命名为永久泄漏。

## 源码链条

准确源：`experimental/recovery-early-buildsrc/src/rconnect/core/`。

1. `RoomSync` 的 grant 分支完成checkpoint和出生位置后，**无条件调用 `TravelGuard.endTravel()`**；随后才在 completingEarly 分支 `early.allowPaint()` 并返回。早期路径允许这个时点仍为 exit10。
2. `endTravel()` 清空 permittedLand/permittedTravel 和 authorizedExitWorld/remaining。
3. 下一次 `RoomSync.before()` 调用加入侧 `TravelGuard.guardTravel()`。它看到 exit>0，却已经没有授权，把缓存的 `travelState` 中 curLandId/curCoord/missionId/crea 回写并强制 exit=0。该快照是前一个稳定基地状态。与本次 **rbl / random_mane** 分裂逐字段吻合。
4. `EarlyTravelGate.destination()` 必须同时满足 Game.curLandId==目标、Land.act.id==目标。现在第一个条件失败，即使原票据已完成、对象身份和视口都正常，也无法 `viewReady()`。
5. `cancelEarly()` 在已经 allowPaint、玩家仍可恢复、连接仍在且非断线的情况下保留 blocked/hold；不放行一个尚未完成双侧确认的世界。主侧收不到 early ack，最后超时。

首次新图 grant 在原生倒计时结束后才到达，所以提前清授权没有触发 `remaining>0` 的恢复分支；缓存重访构造快，使 grant 落在 exit10，暴露了该顺序错误。这也说明增加等待上限或跳过绘制检查不是修正。

## 对根会话拟议修正的审查

同意精确移动旅行授权清理的时点：

- early grant 先释放绘制，不调用 endTravel；普通 grant 保留原清理。
- 在 `completeEarly()` 已校验 valid/localReady/earlyViewFinished、barrier/epoch，且 `releaseEarly()` 成功后，再执行 endTravel，随后恢复控制。

这不会把权限放宽为任意换图：现有旅行授权绑定World，而且同次 exit 倒数只能单调不增；更换World、重新增加倒计时或旅行token不符仍会失去授权。early完成前又一直持有同步暂停及玩家控制锁。完成条件本来就要求 exit=0，故此时清授权不会误伤尚在执行的原生退出阶段。

不要给所有 `cancelEarly()` 直接追加 endTravel：尚未完成构造时退回旧加载流程可能仍需要这次原生旅行授权。reset已经执行TravelGuard.reset；原有取消NativeEntry/SeedRaster各自清理应保持。

适当回归重点：真实 guard 的 exit10 早交付反例；exit0 晚交付；完成后清理；旧World／Game替换；重新抬高exit的未授权出口；失败releaseEarly不提前清理；原生三段重新验证。当前报告只确认旧版失效原因与修正位置，未声称候选已经通过这些回归。
