# 离线采集资格生命周期：原生运行独立复核

2026-10-23。复核实际 `7a10b4a47f`，根结果 `build/m52/recovery-offline-lifecycle-native-03/result.json`。仅读取源码、冻结产物、原始日志与运行记录；未启动游戏、未改冻结输入、未部署。

## 结论及准确身份

**此单实例生命周期检查通过，56项断言、12类覆盖全部通过，cleanup零错误。** 它验证真实Session及本机socket状态迁移，不等于两份游戏完成合作握手、同步采集确实执行或性能通过。

| 对象 | SHA256 |
|---|---|
| 产品候选 `recovery-offline-production-01/RConnectMod.swf` | `eb3653533cfb305bcca0b0cfe5e81bc306ea28fa400aae751ab7b5ae1cfa5fee` |
| driver03 `EffectsDriver.swf` | `ad26d81691d5aa527dd2ca633a7ced39f3feb86acffb2c7ec75bfe5000af6e0f` |
| driver03 prepared | `ab5220e9cee933f986528660d2a038c77a9d3150ac9cecfb78de500442f5ab6a` |
| 原生宿主 | `befcf0509e11fac9fef7afb834708b8b93752a14ae3d5cd72b42aa6d42f9b82a` |
| 原始 host.log | `20bcbec6afe9ed40839fba7fb65e0b39aec66ff2f003ff4c55c7b57981231e68` |
| wrapper result.json | `f97729db4fab9a37406887847691374351597e359f149665d9fbc5356997d4f1` |

driver03的全部files、tools、源AS、wrapper、候选和intent中的清单指纹均读回一致。run.json中的production/driver/harness/game对应实际准确输入；input.json SHA与run.json一致。唯一应用ID为 `pfe-modsettings-rconnect-coop-host-7a10b4a47f`，solo/private_desktop/require_exclusive_air均为true，autoRole为空。描述符及保留的6份配置副本逐项匹配运行清单。真实加载使用当前RV83D8、SandCEC6；不是加载优化支线early2/Sand003的继承测试。

## v2失败与v3范围

旧 `9f6a0461c6` 原始结果仍为56断言、12覆盖完成，但failed=6：清理阶段产生六条 `Error #2002: Operation attempted on invalid socket.`，旧夹具会无条件再次close已记录的Socket。旧日志没有资源编号，不能仅按数量精确归属六条错误；本轮未改写、删除或重新分类旧失败。

独立逐行对比 `recovery-offline-lifecycle-v2` 与v3：

- `driver.py` 逐字相同。
- AS只改finish清理：记录每个socket/server索引和前后状态；仅connected socket调用close；仅bound server调用close；状态未释放或任何异常均记失败。删除按errorID辨别的旧catch，**没有增加#2002豁免**。
- `native_runner.py` 只加强passed_row：必须6个socket全部connectedAfter=false、4个server全部boundAfter/listeningAfter=false。两次#2031的有限分类函数没改。
- 其余场景、56断言、12覆盖、原生调用与资格判断不变，两个运行使用相同EB365候选。

因此v3修正的是重复清理测试资源的错误，并增加可核对的清理证据；没有更改模组逻辑或降低原通过条件。

## 真实错误分类

完整扫描实际保存的所有模组日志，按共享runner同一错误表达式复算：恰有3条匹配行，均仅在RConnect.log中。两条是同样的 `RConnectNet: link failed: IOError: Error #2031: Socket Error. URL: 127.0.0.1`，第三条是包含这两条观察文本的唯一成功JSON；**没有其他错误行**。host.log与保存的module-logs/host/RConnect.log逐字相同；stdout也未发现Error编号、TypeError、ReferenceError或内存错误。

两条预期错误分别有实际socket事件佐证：join-refused于33412ms/frame305，join-refused-retry于35707ms/frame360，kind均ioError、attempt与phase一致，均来自本轮保留但不listen的61595端口。只有这两个事件和完整成功结果可分类为负测试预期。混合其他错误、额外重复、失败结果或清理错误不能通过该分类。原生host占用测试错误为既有业务文本，不把它改成全局错误豁免。

实际56/0结果逐字段等于wrapper保存的row；abortReason为空。正式错误扫描、超时、取消、内存与独占逻辑仍用准确共享runner `7eca453b…b5ae4d3`，只多一个限定预期错误判断。

## 生命周期与资源清理

初始未联网及未联网leave仍可省略观察；首次无人host后，leave、真实join失败、手动重试、loopback连接/关闭/重连、端口占用host失败和最终leave都保持资格false。两次loopback接受地址均127.0.0.1，原生HELLO只被读取丢弃，没有伪发WELCOME，所以客户端停在joining是预期范围。

本轮自有端点：预留无人host 61594；拒连保留端口61595；loopback 57463；占用host 57471。loopback的localServer初始记录listen=false，后续listen后实际两次接受分别来自57464/57470，不能把初始记录当未监听。

- cleanup：6个socket索引0–5齐全，connectedBefore/After均false；4个server索引0–3齐全，bound/listening前后均false。它们在各原生步骤和session.leave中已关闭，最后清理没有再错误调用close。
- Session最终offline且server/link为空，peers/remotes空；sessionReleased=true。
- 私有port/hostIp恢复原值，configRestored=true，errors=[]。没有保存进真实用户配置。
- 运行登记 `578ee6b2327941bf80d4a6f62b4296f7` 已完成、非取消；自有PID36956复核不存在。host/join/frozen可重建目录均已清理，原始证据保留。
- 29个内存采样，启动余量5,905,784,832字节，高于单实例3GiB；运行最小4,009,803,776字节，未触发512MiB保护；无foreign_air、无压力/重叠中止。不能据此声称满足双实例启动门槛。
- wrapper记录22项安装前后一致；本审核再次重算22项，与intent全部一致。正式RConnect仍574D，本轮未部署EB365。

## 仍未覆盖

运行结果明确保留以下false：`twoGameConnectionQualified`、`cooperativeHandshakeQualified`、`automaticReconnectQualified`、`failedFirstAttemptQualified`、`collectorExecutionQualified`、`nullThrowCollectorFallbackQualified`、`performanceQualified`。join失败是在首次host之后测试，尚不能单独证明新Session首次join的撤销动作；重试是手动调用，不能冒称自动重试。后续应分别补真正采集fallback与必要联网回归；本轮不赋予双人密集、视觉等价、加载或发布资格。
