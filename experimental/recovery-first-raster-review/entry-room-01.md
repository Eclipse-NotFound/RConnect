# entry-room01 两项失败审阅

原结果保留失败：[recovery-first-raster-entry-room-01](../../build/m52/recovery-first-raster-entry-room-01/result.json)，run `a542373a5f`，主25 PASS / 2 FAIL、加53 PASS，22项安装未变。两失败目前指向外部观测器的确认时点前提，**没有证据要求重新暂停已经提交本地状态的主侧**。

准确主日志：本轮一开始已停留 `random_mane//0,4,0`；初次握手 `ready` 处理72574→72647ms，期间已输出 `commit 1`。返回时 `ready=true,busy=false,term=1,exit=0`。72699/72701ms两次失败记录都是 `confirmed:null`；ACK到73201→73202ms。不是先收到旧房身份确认后又切换新Land的证据。

生产13 `RoomSync.commit` 先保存 `settledRoom=game.loc`、`settledKey`、`term`，把完整grant排入TCP，然后 `release()` 恢复本地；`pending`继续保留，下一事务不能越过ACK。`canSyncWorld`仍要求当前Location与已提交身份一致。此时本地权威已经成立，随后同一TCP中的世界状态排在grant之后，不必等加入侧绘图完成再允许宿主本地运行。

旧 `RoomEntryProbe.settled` 却只在主侧**收到ACK**时保存 `confirmedRoom/Land`；因此 commit→ACK 之间 `sameConfirmed=false`，它误将合法本地发布与无覆盖判为“新房未确认”。两断言本意应保留，不能删除；应让未来独立夹具区分“本地主侧已提交”与“对侧已确认接收”。还需反例确保“没有真实commit却只有ready标志”或“Location已替换”的情况仍失败。

历史边界：安装574D `coop-bundle-04/RoomSync.commit` 确实没有末尾release，此旧观测假设符合其等待ACK的时点；但 recovery06 已明确采用 commit 后立即release，与准确13相同。所以这不是已证明由本次随机首绘引入的新发布竞态。原 frozen driver12、失败结果及生产均未改；当前结果不能改绿，也不拿其余分房检查替代上述待补的独立确认时点测试。
