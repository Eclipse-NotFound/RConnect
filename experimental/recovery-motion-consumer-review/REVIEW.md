# 既有长空档的显示消费复核

2026-10-23，只读复核。未运行游戏、编译器或部署，未改生产、旧驱动、阈值或旧证据。结论：**这三段记录尚未定位出一个可确证的显示消费器错误，不建议据此修改生产。** 已证明“有位置可画”不等于“事件循环已经提供了绘制机会”；不能再把所有空档都算作缺包，也不能反过来断言都是插值故障。

## 回读的实际窗口

路径均相对 `mods/RConnect`；原日志仍在原位。本次重新解析原 JSON 行并核日志 SHA，没有依赖旧 README 的状态描述。

| 原运行／观察窗口 | 实际证据 | 可以与不可以判断的内容 |
|---|---|---|
| `6e154179bd`，case6 闪电，加入侧 `69306→69401 ms` | RENDER `128→129`，gameFrame `65→66`，X `1388.75→1440.95`。`69288 ms` 已收到至源 `107917` 的后续位置。两显示点反推源游标约 `107835.13→107869.98`，都在已收区间内。 | 已排除这两点之间缺少下一位置。准确驱动逐次记录 RENDER，含空 clip，不按 gameFrame 去重；窗口内没有其它最终回调记录。不是“有很多绘制帧却一直消费同一点”的证据。游标实际推进约35ms而回调间隔95ms，可能包含帧首到帧尾耗时变化；未记录帧首时刻，不能把差额定因为游标停滞。 |
| `f8bc3462f4`，round3 持有掉落物 | 源加入侧 reference `73460→73679`，219ms；观察主侧 render `110244→110493`，249ms，X `368→375`。两段均在持有中，远早于松手、拟合和整段日志输出。 | 源自身也有长采样间隔，不能只归远端插值。冻结驱动按 gameFrame 去重，因此没有记录不能证明中间不存在显示专用 RENDER。没有私有游标或每次调用记录，不能证明消费器被调用却不前进。 |
| `60ccbb7140`，round0 掉落，加入侧 `31553→31713 ms` | 坐标 `(277.25,280.70)→(289.25,291.45)`，均在空中；`31569 ms` 已收到后一位置，下一条显示采样在144ms后。 | 已证明不能把整个160ms解释为尚无位置；但此驱动同样按 gameFrame 去重。无法区分未产生新游戏帧、额外 RENDER 被去重、或某段工作延迟了最终观察。原 `longestStillMs=0` 只说明相邻记录坐标不同，不代表时间连续。 |

## 源码核对

- `build/m52/recovery-21/src/rconnect/game/RemoteMotion.as:181–225`：`sampleTimed()` 只按传入时间的正向差值推进，重复时间不再推进，最终不超过已收的最新源时间。`ProjectileFrameStream.as:16–18` 读取所属角色已有游标，没有自行采样或再造时钟；`ProjectileVisuals.as:170–197` 在确认的轨迹两点间插值，收到 end 且游标抵达 end 才删除。这些分支中没有能直接解释上述95/249/160ms窗口的“每N次才更新”门槛。
- `GameBridge.as:132–135,340–384`：高优先级 ENTER_FRAME 写 `_sampleAt`；身体、持有物与弹丸共用该帧时间。`onMirrorFrame` 中弹丸先于敌人采样，但最终 `onVisForceFrame:282–289` 会在敌人采样后再放置弹丸。因此仅凭 ENTER_FRAME 的局部顺序，不能判定最终显示必落后一帧。
- `GameBridge.as:242–336`：最终 RENDER 通常复用当前姿态；暂停新包例外会先消费新姿态再更新 SATS。重复 RENDER 复用 `_sampleAt` 是明确的同帧策略。将其直接改为 `getTimer()` 可能改变角色／武器／弹丸的相位，又不能填补没有最终回调的95ms窗口；本轮证据不足以支持该改动。
- 本次逐字节确认14与21的 `RemoteMotion`、`ProjectileVisuals`、`ProjectileFrameStream` 相同；两版 GameBridge 的上述回调块也相同。**offline1/aura1 的前两类不同，且没有 ProjectileFrameStream 文件**；不能把历史14/21的内部判断冒充当前安装已复现，也不能将整套未合格运动分支移入光晕候选。

准确采样器：`build/m52/recovery14-flight-driver-01/tests/NativeFlightContinuityTestDoc.as:79,189–237`（每次最终 RENDER 都记录）；`build/m52/motion2-native-input-drivers-04/tests/FastHeldTestDoc.as:344–355`（按 frame 去重）；`build/m52/motion2-continuity-drivers-01/tests/PresentationContinuityTestDoc.as:274–295,367–385`（运动记录按 renderFrame 去重，旧断言只限重复坐标持续时间）。没有新增采集或网络诊断方案。

## 可追溯指纹

| 文件 | 本次回读 SHA-256 |
|---|---|
| `build/cooperation/6e154179bd/host.log` | `4b568590f5e336ea39e2dc0db4c35b36a4e5290ecc454a05889acbbbab5219e1` |
| `build/cooperation/6e154179bd/join.log` | `c625e6376d66b279b8cb3e5d0684c04d133c803ab16ace6e8d4ae27a0cfc70da` |
| `build/cooperation/f8bc3462f4/host.log` | `ac6cf8a87bdd9092f1371923d3c5827bc64f6ff415a4c2940626a7f77bcf108b` |
| `build/cooperation/f8bc3462f4/join.log` | `8517776cce57942b9ef3ff45c47239533968ee0d2cd1eef7d9fadfaf76ce1297` |
| `build/cooperation/60ccbb7140/host.log` | `f24a6014df9bd3512af9e0606ae0d7c22866c74ff2f03c6fadd59ac716f36619` |
| `build/cooperation/60ccbb7140/join.log` | `9b11b44a982005409bb8e3f3a21a86dad0c376d75b41c2f842f98db5d0a53ea2` |
| 上述14的 `NativeFlightContinuityTestDoc.as` | `e530e573a67a4e0ed6c5d231be9c134806de999b677adf5b4c1bae12ff26c5bf` |

历史原始结果和“流畅度未合格”结论均保留。当前停点是**生产原因未定位**，不是已排除所有消费器错误；本轮不提出无实证的缓冲、帧率、外推或动画寿命修改。
