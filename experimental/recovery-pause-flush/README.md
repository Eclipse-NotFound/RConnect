# 暂停边沿补发完整世界状态：独立源码候选

状态：仅完成源码与静态核对，尚未编译、运行组件或实机验证。没有改安装版、冻结候选、公共运行器或其它模组。不能据此关闭 SATS 延迟问题。

准确基底为 `build/m52/recovery-22`：候选回执 SHA-256 `746eef5713985f23fe13a57792516789bebd37a5e4142639ba8cc8b6590b3e93`。`prepared.json` 为 `cada3af2e49459a3fe7c3b53ddca0e31392ab8b8fd1589ad0c4b05aa0a3042ce`，`integration.json` 为 `63b2f0cc1d06a0be68b9f883430255b5ef500d624cce341e5184cef04a632a0a`。这两个改动类在 21 与 22 中逐字相同。

`src/` 是完整 90 个 AS 文件，其中 87 个与准确 22 逐字相同；仅 `CoopPause.as` 和 `Session.as` 有逻辑改动，`RConnectMod.as` 只替换主会话指定的版本号为 `0.2.24-recovery23`。`proposal.patch` 保存两个逻辑类的完整差异，`version.diff` 单独保存版本替换。`integration.json` 供既有 `prepare_recovery.py --source` 完整源入口使用，入口和清单版本一致；主会话指定下一输出为 `build/m52/recovery-23`。`inputs.json` 绑定本目录文本输入；没有 SWF 或新的运行器。

## 行为与顺序

宿主 `CoopPause.refresh` 在调用原 `setPaused` 前保存局部 `wasPaused`，其后先执行原有暂停状态发送，再且仅在 false→true 边沿调用 `Session.flushPausedWorldState()`。顺序为：

1. 原 `setPaused(true)` 完成，包括 `game.setCoopPaused(true)`。
2. 原有 `coop-pause/state` 的摘要、序号、250 ms 去重和发送流程完成。
3. 一次完整 `broadcastWorldState()`，包含其现有玩家、敌人、掉落和墙面更新流程。

宿主原有的早退改为等价发送条件块，保证即使状态摘要去重，真实暂停边沿仍可到达补发口。未改重复理由、恢复、加入端 report、常规 50 ms 世界状态定时器或消息协议。没有提前抓取快照、伪造 sampleTime、推进 tick 或独立发送敌人字段。

先发暂停确认，是为避免大场景的完整采集阻塞原有确认。同一 TCP 链上的发送顺序仍是 pause state→worldstate；加入端自身 SATS 已可先本地暂停。这个顺序不保证对侧立即绘制，也不消除主线程长帧、往返和显示时钟的全部延迟。

新增 Session 方法只接受已暂停的 HOSTING、当前同步且有权威的房间、非转场、已绑定且至少有一个连接的服务器。守卫不满足时连采集也不执行。正常补发复用原方法，墙面发送确认仍位于其原位置。方法没有新持久字段；补发抛出的异常在本方法局部记录，不影响此前已经发送的暂停确认，也不在以后每帧自动重试。

没有新增“发送中”布尔：实际 `TcpLink.send` 失败可经事件同步调用原有 `Session.onClientRemoved→broadcastWorldState`，该路径不经过新方法，单独给新方法加锁无从保护它。没有发现同步回调再次产生新 false→true 边沿的证据；`_paused` 已经为 true。完整 Session 的旧异常重入并未重构，也未由此组件证明安全。

## 组件范围与入口

预期 **50 条**断言（此前草案 48 条，最后增加了两条完整旧新 pause 消息序列对照）。`PauseFlushChecks.as` 使用完整实际新 `CoopPause`、完整原类仅改类名的 `ControlCoopPause`，以及真实新 flush 与逐字不变的完整 `broadcastWorldState`。Session 其余部分、GameBridge、房间和 TCP 为小外壳；不加载游戏，不声称覆盖完整 Session、真实套接字或实际显示流畅度。

- 宿主本地 SATS 和加入端 report 两个入口；先实际暂停，再发原 state，再采集。
- 重复帧、重复序号、附加暂停理由、恢复、下一次暂停边沿。
- 加入端不广播；断线、转场、未就绪、错误房间、无权威及新 epoch/term。
- 完整现有采集一次，原 sampleTime/tick 不变，墙面只在发送后确认。
- 发送异常、重复刷新、发送中最后连接移除，不制造每帧重试或重复确认。
- 原／新实际 CoopPause 的宿主本地及 report 消息数组，包括内容、序号、去重与 epoch，严格相等。

由主会话运行既有组件入口（在 `mods/RConnect`，输出必须新建）：

```powershell
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 tools/validation/run_recovery_component.py --source experimental/recovery-pause-flush/components --entry PauseFlushChecks.as --output build/m52/recovery-pause-flush-component-01 --expected 50 --registry-wait 900
```

现有工具负责登记、唯一 AppID、隐藏进程、内存条件、安装输入前后校验及自有进程清理。本子任务未调用该命令。

纯 Python 源码复核：

```powershell
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/recovery-pause-flush/prepare_sources.py
```

它核验准确 22 清单、完整 90 类与精确替换可逆性，更新文本指纹；只有显式 `--materialize` 才重新写入生成的 AS/补丁，不启动任何编译器或游戏。

## 原生对照入口与证据边界

现有正式策略运行器 `experimental/recovery-formal-policy-control/run_motion_comparison.py --case pause-timing` 可使用冻结 `build/m52/coop-bundle-drivers-04` 的八轮 `A22PauseTimingTestDoc→super(true,8)`。主会话已运行准确 22 对照 `9a806dee8c`：原功能主 26/0、加 129/0；总结果仍 FAIL，因加入端 `FirearmAttachments.log` 的 #1009。旧结果保留，不能先归因生产或夹具。

该旧包的 `PresentationContinuityTestDoc` 使用裸赋 `NativeTestGun`，与已修复的真实背包路径不同；不能以旧八轮单独关闭用户问题。主会话已委托从以下较新冻结源组建同八轮入口，本目录不复制运行器或重新编译：

- `build/m52/motion2-continuity-drivers-01/tests/PresentationContinuityTestDoc.as`，SHA `2e998334580505028b9fa58d3daa6067e3eaa92d3df313db4ecfeeba26a8e6f9`。它使用 `Invent.addWeapon("lmg")` 和实际换枪路径。
- `A22PauseTimingTestDoc`：`super(true,8)`，固定八轮。
- `A22LatePausePacketTestDoc`：`super(true,4,true)`，四轮迟到包。
- `A22PauseRepaintTestDoc`：`super(true,4,true,true)`，四轮迟到包加帧间重绘。
- `A22EnemyTimelineTestDoc`：`super(true)`，时间线模式。

这些更强入口保留原缓冲延迟、暂停端点、身体动画、倒退、SATS 位图和不依赖新游戏帧的重绘断言；新包须绑定准确入口及基础驱动字节，再用同一包进行候选对照。本目录只准备生产与组件源，未改变原断言或验收门槛。

既有 `60ccbb7140` 的首次观测暂停对齐为 159 ms，但默认驱动未导出请求／确认／敌人到包分账，不能把这段全部归为等待下一次 worldstate。本候选只取消其中可能存在的定时等待，实际收益仍待新八轮和必要迟到包／重绘用例验证。
