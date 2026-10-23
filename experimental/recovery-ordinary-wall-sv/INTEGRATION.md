# 房间恢复与交接接入草稿

2026-10-23，根会话负责 `src/rconnect/game/GameBridge.as`、`core/RoomSync.as`，均从准确 recovery-22 复制。尚未编译、运行或接入安装版。`TerrainSync.as` 目前只是准确22的未改副本；真实旧材质通知由独立宿主候选的 Location 在原生 die 前提供，不能声称这份副本增加了通知。

## 已写入的接入

- GameBridge 退出联网改用 wall.endSession；实际 Land 对象变化仍走 reset。只断开连接不能忘记同一世界的结构版本。
- roomRole 设置当前房间的 ordinaryAuthority。非 retained 恢复在地形恢复之前 prepareRestore，在原有 redraw 之后 finishRestore；needsNative 禁止 retained/相同地形快路，只复用原有一次正常重绘。完成失败不放行。
- RoomSync 中，主侧恢复自己的房间后，仅回写记录的 wallPaint，再生成 grant。若同房恢复推进了待重建/待重画的墙面状态，不能再用原始 msg.own 的 retained 字符串覆盖新结果。
- 分房新 owner 携 needsNative 时走普通恢复，不能凭 fresh/retained 跳过。加入侧放行前再次核对实际 wallStateReady。
- 持续留在原房的 owner 例外：其上次 grant 中的 needsNative 可能已经实际完成，但主侧记录仍旧。sendReady 只新增本次真实 `wallReady` 布尔值，与 info 在同一个同步函数内取得。原有 owner/key/无 own、无 fresh 的 unchanged 条件再要求它为 true；这种情况不能被主侧过期的 pending 快照强制回滚。真正离房仍按原路径提交完整 own checkpoint，无新增整墙 ACK。

## 核对及剩余

持续 owner 若报告 `wallReady!==true`，在处理/恢复记录前立即拒绝交接，不能转为重放宿主旧记录的完整恢复。否则旧记录可能回滚敌人和掉落，并通过 prepareRestore 清掉 owner 刚发生的真实绘制失败。这条反例由独立源码审查发现，已修正；尚未原生验证。

独立源码审查抓出了上面的“旧主侧记录重置正在探索的加入侧”反例，草稿已据此修正；这不是原生测试通过。精确差异目前只在两份完整生产类中，未修改 Session 或 codec。

接入依赖 WallImpactVisuals 的实际实现：ordinaryRole、prepareRestore、finishRestore、hasNeedsNative、endSession。原生绘制失败必须使 ready 为 false，不能只有一个无人读取的错误字段。ordinary/large 身份必须按 Location 保留，不能以共享 Grafon 当前所画的别房判断旧房。

宿主回调仍在独立 `../recovery-ordinary-wall-sv-host/` 编写；真实艺术范围、Location 两处 die 前通知、非权威结构前景暂停及成功 drawLoc 顺序均须完成并验证。组件需复用真实类；随后还要实际普通房墙沿22点、结构/晚包/换房、全配置密集开火及加载耗时复验。魔法墙和 large 路径不获得本候选新增资格。

原输入 SHA256：GameBridge `260cebd0f89e348979d05d00338f7e444a1abf2c0bbe4d03350475b05e01142d`；RoomSync `c2e68fe658a81be4b3ceb285daf453ca57b9d4a5895e80720dd629c374e3f85e`；TerrainSync `317c9658b0632f3bb8333c11cd302c68ef45e7a9f2f54ed6b6c631b6c1b92b44`。

## 构建接续边界（源码核对，尚未执行）

恢复22完整源码90类，均与 prepared.source 匹配，产物为 `746eef5713985f23fe13a57792516789bebd37a5e4142639ba8cc8b6590b3e93`。先复制完整源到新实验构建目录，再仅覆盖四个实际变动类、更新版本和 integration.json，才能使用现有 `tools/validation/prepare_recovery.py`；本目录局部src不能独立构建完整产品。TerrainSync仍未改。

当前安装宿主精确BEFC，其已有隔离后代为BEFC→E159（Game）→FD92（首栅格）→ACC（墙面桥）。新宿主补丁依赖ACC的桥层，不能原样重放到BEFC，也不能把整份ACC类导入称为仅本轮增量。最短验证路线是在ACC隔离副本定向导入新Grafon/Location两类，保留两类回读、pcode、非代码资源、loader、类列表及其他代表类不变核对。现有 `recovery-early-paint-timing-v3/build_host.py` 含相应登记、内存保护与前后回读流程，可据其做窄接入；旧只导入Grafon且硬锁FD92的prepare_host不适用。

真正部署前须单独核对上述依赖与当前安装版差异，保留其他模组已安装改动。现有BEFC代表类导出未含Location，不能假称已对该类逐字确认。这些是下一步约束，不是本轮已编译或通过的结果。
