# 共同旅行：提前交付隔离候选

2026-10-22。**最终源码对应六组组件已实际通过 217 项；完整 RC/宿主尚未编译或原生验证，不能部署。** 只覆盖双方显式支持、共同进入合并大场景的旅行。普通分房、小房、离线仍走原路径。没有改种子算法、检查点字段、发送频率或加载/按键时间门槛。

准确底：`build/m52/recovery-16/src`（A1519B…A31C），宿主为 ACC336…35DFD 的实际 `after/scripts/fe/World.as` 和 `fe/loc/Game.as`。完整来源哈希在 `manifest.json`。ACC 的 Grafon、首绘和墙面桥全部保持原字节；本目录没有 Grafon 覆盖。此候选不占用父会话后续版本号，也未混合 15/17/18 的其他差异。

## 改动

- `Game.enterToCurLand` 在原生进入动作、对象及触发器构造、出生和效果完成后通知 `constructed`。触发器的后续执行仍属于 Land.step，不能理解为剧情已执行完。此前的 `sceneOpen` 只做好初始化，暂不生成首屏块。
- 双方使用一个 `EarlyTravelGate`，绑定 World/Game/玩家/旧新 Land/Location/renderer、目的地种子和 `earlyId+epoch+barrier`。没有长期缓存第二套世界。
- 仍用原 `seal → ready → commit/grant → 完整 restore`。宿主只采一次共享检查点，宿主发 grant 后才开始首绘；加入侧完整恢复并采用宿主固定出生后才开始首绘。恢复过程中不调用会提前解锁的 `FirstRasterGate.beginRestore`。
- 原生 `World.step` 只允许有效票据推进 exit/camera/GUI，并在 exitStep 返回后再次检查，从而挡住构造完成同帧的 Land/脚本/计时推进。exit16 的视觉工作照常，controlOn 延后；加载点击仍保留，Pip/SATS 等菜单热键暂不执行。
- 加入侧必须原生 `t_exit==0`、真实首屏完成且进入下一帧才发 ACK；宿主自身也满足这些条件，并收到精确 ACK 后发 activate。双方各补一次原生 controlOn，再恢复自己保存的暂停状态。
- 未固定 grant 时可撤销优化并回到普通原生交接；已 grant/restore 后的异常保持不可操作，不能借取消解锁部分状态。死亡、换档、同 World 替换 Game 不向新 Game 回写旧暂停/控制。断开清理仍只释放自己的票据。

## 时停接口是前置资格

准确 CEC6 Sandevistan 有独立的 `gg.step/loc.step` 和敌人补步路径，**单靠 World.onPause 不够**。本候选 RC 侧已接入拟议的 `SandevistanTravelHoldV1`，要求 `version==1`、`contract==sandy-travel-hold/1`、查询身份成立并且原子 idle acquire 成功。缺失、未知版本、query null、活动/回放或 acquire 失败都回到普通流程；不能把“没有找到载体”解释成“没有安装时停”。

本目录没有修改 Sandevistan，也没有把接口替身当作真实接口已经运行。根会话另行处理 A 接口授权与实现；在此之前，实际安装 CEC6 下本候选不会启用提前加载。RC 保留实际 acquire 的对象、私有 owner 和 id，释放时不会重新按名字找载体。

## 可先运行的组件

现有正式入口 `tools/validation/run_recovery_component.py`，以下是已执行入口的参数结构；再次执行必须使用新输出目录：

```text
--source experimental/recovery-early-travel/components/gate --entry EarlyTravelGateChecks.as --output build/m52/recovery-early-gate-component-01
--source experimental/recovery-early-travel/components/room --entry EarlyTravelRoomChecks.as --output build/m52/recovery-early-room-component-01
--source experimental/recovery-early-travel/components/room --entry NativeTravelRoomChecks.as --expected 109 --output build/m52/recovery-early-legacy-component-01
--source experimental/recovery-early-travel/components/native --entry EarlyNativeChecks.as --output build/m52/recovery-early-native-component-01
--source experimental/recovery-early-travel/components/external --entry EarlyExternalChecks.as --output build/m52/recovery-early-external-component-01
--source experimental/recovery-early-travel/components/tile --entry EarlyTileChecks.as --output build/m52/recovery-early-tile-component-01
```

新组件不硬填未执行的条数，实际 assertions 全部写 result.json。旧 109 项沿已通过的 `recovery-seed-first-raster-room-01/src` 原顺序、原断言；新增能力默认关闭，不覆盖原失败记录。这不涵盖此前 seed ON/OFF 组件额外注入“成功恢复后旧 epoch 空 travelId seal”的 108/1 边界，更没有修复或洗绿该历史失败。每个准备来源和输出的指纹在 `component-inputs.json`。

根会话第一切片实际结果：gate 20/0、room 32/0、原 109/0、native 15/0。external 首次是 ASC 返回值检查编译失败；tile 前 10 项通过后，夹具 after 回调参数不足触发 #1063。01 原目录保留；当前第二切片补显式返回、整个 World 替换的许可清理，以及按真实 after(tile,x,y) 签名修正夹具，并新增反例。第二切片不能继承第一切片的通过结论。

最终实际回执：gate-01 20/0；room-02 36/0；room-regression-02 109/0；native-02 16/0；external-02 22/0；tile-02 14/0，合计 217/0。全部对应本目录当前组件字节，`handoff.json` 逐项绑定原始 `intent.json`、`receipt.json`、断言输出及 SWF 指纹。上述全是边界/原方法组件，不是真实 Sand 实现、完整游戏冻结或加载性能资格。另有源码审计 113/0 与宿主回读验收反例 14/0，二者均只运行 Python。

真实类：EarlyTravelGate、RoomSync、NativeTravelPlan、FirstRasterGate、SeedRasterEntry、RoomCodec、NativeTileState、NativeRoomState。网络、GameBridge 原生操作、载体是明确替身。World 组件逐方法提取准确前后 `step/exitStep`，周边原生服务为计数器；MapGeneration 组件提取准确 acquire/release 方法，不能冒称完整显示树集成。旧 native Game 的尾回调由静态精确差异检查，正式宿主仍需 FFDec 导入及回读。

Tile 组件保留所有字段的真实传输：8 个 `kont1..4/pont1..4` 仍完整保存，`shelf` 仍是必需字段。组件区分绘图前后轮廓值可以不同与真正平台/破坏状态不可丢失；它不证明所有模组都只把这 8 字段当显示派生量。真实图像与可碰撞状态仍须按原生用例检查。

## 仍必须通过的原生资格

1. 在宿主 constructed 后故意延迟 peer：`t_exit`、相机及原生加载点击继续，双方单位/掉落/脚本/时停计数不变。不得用隐藏遮罩代替此证据。
2. 同一固定大图首次/基地/重访：源 checkpoint 定稿在宿主首块绘制之前，宿主和加入侧首绘重叠，双方出生一致；旧死亡、破墙、容器、掉落和无人房进度保留。
3. 同字节 scene12/真实按键组件，保留原 1000ms、3 帧 no-input baseline 和所有按键/恢复期限；再跑同驱动 solo。组件通过不能证明加载已达单人耗时。
4. 正常小房与普通分房，不变的玩家不得进入等待；死亡、换档、断线、同 World 新 Game、配置变化、失败和重复旧消息都不能误解锁。
5. 全组合输入：SATS、菜单鼠标、时停热键/鼠标释放，以及既有 mod onPause 契约。当前 World 组件包含明确反例：外部直接调用 Land.step 仍可推进，所以不能单凭该组件声称冻结所有模组。

`generate.py` 和 `prepare_components.py` 只生成本目录源码。`check_sources.py` 只做来源、差异和顺序检查，不启动编译器或游戏。正式整包/宿主准备由根会话在最终审查后沿现有登记构建入口进行；本目录目前不复制整树、编译器或游戏资源。

## 冻结及正式构建入口

`handoff.json` 固定最终来源；冻结后不要再运行生成器覆盖。独立审查已保存于 `../recovery-early-travel-safety-review/current-overlay-review.md`，未发现正常事务及已列取消路径的新增确定阻断；真实 A 版 Sand 接口仍待授权和实现。`constructed-ui-boundary.md` 记录进入场景时自动开界面的已查路径与未证边界。本目录到此停止改 AS，任何后续修正须新记录来源并重验受影响组件。

下面均从 `mods/RConnect` 执行。使用已配置的 Python；输出路径必须不存在。版本名是隔离诊断标记，不占用 recovery18。准备脚本未执行过整包组装或 FFDec，根会话负责串行运行。

```text
python -B -X utf8 experimental/recovery-early-travel/prepare_sources.py experimental/recovery-early-buildsrc --version 0.2.24-early-travel1
python -B -X utf8 tools/validation/prepare_recovery.py build/m52/recovery-early-compile-01 --source experimental/recovery-early-buildsrc --version 0.2.24-early-travel1 --build
python -B -X utf8 experimental/recovery-early-travel/prepare_host.py build/m52/recovery-early-host-01 --build
```

第一条只从准确 recovery16 组装新 90 类完整源码：原 89 类仅改 RoomSync、MapGeneration、Session 和版本，新增 EarlyTravelGate；其余逐字相同，生成既有正式工具接受的 integration 清单。第二条复用正式 `prepare_recovery.py --source`，没有复制新编译器。第三条沿共享登记使用原 FFDec，只导入 World/Game，核对 ACC 源、两类实际方法回读、Grafon 等代表类、类清单、非代码标签、影片头与 22 项安装输入；回读仅允许两个已明确单句 if 被 FFDec 加花括号。任何失败写新目录，未改历史结果。

`prepare_host.py` 不启动 AIR、不部署、不修改 CS 或 Sandevistan。编译成功也不能直接交给旧原生驱动：后续需显式接入这一新宿主的准确回执与 SHA，并将真实 Sand 许可作为准入项。当前没有为绕过该资格新增放宽入口。
