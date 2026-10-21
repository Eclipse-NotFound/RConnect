# 仅共同大图首次栅格的隔离候选

基线：RConnect **recovery-11**；宿主 **E159**。当前修订 **final-03** 仅源码，未编译 / AIR / 原生验证，不可按“已修复”部署。准确 Camera/GUI/Land/Location 依赖补充来自 `build/m52/recovery-raster-dependencies-01/scripts`，其中 Camera.calc 的第 288 行确实调用 sceneTick；不另调 Camera.calc。

final-03 只修宿主导入：E159 反编译的 sceneDrawSteps 两处捕获变量递增出现 `§§findproperty` 伪指令，导致 host-02 FFDec 导入失败。精确恢复为 `j++`、`i++`，完整 tile 循环与 CS 已编译 Grafon 来源逐字去空白一致；没有引入 CS 其他候选改动。证据见 `host-import-repair.md`。RC 覆盖与三个组件的 AS 文件保持 final-02 指纹不变；这些组件不执行 sceneDrawSteps，不能据此声称导入修正已运行通过。新 host-03 由 root 单独构建。

final-02 仅补两处边界：绘制配置从支持变为 nonpreload+cull=false 时先取消旧 ticket 再退回原路径；ticket.unpainted 已为 false 时不再每帧调用 viewReady 扫描。前一轮真实组件结果 gate 19/0、room 76/0、native-methods 18/0 均保留在各 `build/m52/recovery-first-raster-*-01`，但不作为本次源码资格：当时 room 冻结 SHA 为 7E6323…，之后 compile-01 的 355781… 已有后加 guard；本次又修正该 guard 和 Grafon，须新 02 重跑。

范围：RoomSync 已接受并实际采用的 native travel、加入侧、`sceneMerged=true`、新 Land 且同一 World / Game / Location / renderer / travel 身份。普通分房、host、offline、缺少宿主接口仍走旧路径。无协议变化、无世界快照合批、无发送频率变化。

已有 `sceneViewReady` 在裁剪关闭时检查整张地图；因此 `scenePreload=false` 且 `sceneCullRender=false` 的配置保留旧绘制路径，避免把“首屏等待”变成等待后台逐块画全图。默认 E159 为 preload=false / cull=true，属于本候选范围；preload=true 也支持。

## 文件与合入顺序

`generate.py` 按精确唯一源码片段，从冻结 11 / E159 生成稀疏覆盖和 `proposal.patch`；`integration.json` 保存所有来源和覆盖 SHA。只覆盖：

- RC `RoomSync`：批准首绘延后；grant 完整恢复、放置 anchor 后，等待下一次原生相机更新及真实 viewReady，再 ACK/解除加载。重复 grant 不再执行恢复。
- RC `FirstRasterGate`（新）：绑定一个目的地，只有等待、恢复完成等首屏、完成/取消；不维护房间所有权。取消只放开 native raster，不假造像素完成。
- RC `MapGeneration`：可选安装 Grafon 回调；回调不可用时无优化。
- RC `GameBridge`：未画地形不能走 RoomTerrainView 复用；首屏就绪时补逻辑墙痕到已绘缓冲。
- RC `WallImpactVisuals`：未画缓冲不作为墙痕采样/回放目标；逻辑墙痕仍正常接收、恢复。
- 宿主 `Grafon`：只改大图 sceneOpen/ensure/tick/viewReady 周围。保留 sceneOpen 全部初始化与顺序；只等 chunks。单独宿主覆盖位于 `native/fe/graph/Grafon.as`，**World/Game/Land 未修改**。

`rconnectRasterTicket.waiting` 由 RoomSync 生命周期释放；`unpainted` 只能由 native raster 在 resident>0 且 viewReady 后清除。原生退出计数仍运行，首绘钩子不调用 hold/onPause。

## 当前修订组件：未执行

运行 `generate.py`、`prepare_components.py` 只生成源码。之后由 root 使用既有通用登记 runner，输出必须是新的 `build/m52` 子目录：

```text
python tools/validation/run_recovery_component.py --source experimental/recovery-first-raster/components/gate --entry FirstRasterGateChecks.as --output build/m52/recovery-first-raster-gate-02
python tools/validation/run_recovery_component.py --source experimental/recovery-first-raster/components/room --entry NativeTravelRoomChecks.as --output build/m52/recovery-first-raster-room-02
python tools/validation/run_recovery_component.py --source experimental/recovery-first-raster/components/native --entry FirstRasterNativeChecks.as --output build/m52/recovery-first-raster-native-methods-02
```

- gate：真实新类，身份更换/取消/旧授权/实际帧就绪要求。
- room：真实修改后 RoomSync + NativeTravelPlan + RoomCodec + RoomEntryView；保留原 50 条场景，追加首次栅格场景。GameBridge/Session/native 构造与像素是明确替身。测试通过不代表原生实体恢复通过。
- native：从拟合入 Grafon **逐方法提取**原文 sceneOpen/ensure/tick/viewReady 和三个小 helper。只把 assets、chunk 实际绘制、native objects 替成计数对象，核对初始化顺序、等待入口、preload 开关、取消和未知回调退回；不是像素等价测试。

所有组件输出真正 `result.json` 并退出；不填写未经执行的固定总数。`component-inputs.json` 记录每个实际生产来源和替身指纹。

本次新增 room 三条：不支持配置退回、旧 ticket 释放但不伪造像素、随后 grant 走原完整恢复和 ACK；native 两条：preload 与 nonpreload 完成后各三次 camera tick 不再进入就绪扫描。计数仅放在替身 sceneViewport，提取的生产方法正文不变。

最终生成顺序：`generate.py` → `prepare_components.py` → `check_sources.py`。最后一步写 `final-source-manifest.json`，枚举本目录全部源码、组件、配方和文档 SHA（不含清单自身和 Python 缓存）；交付后停止修改。

## 源冻结和宿主准备命令

下面命令从 `mods/RConnect` 执行，输出须是不存在的新目录。省略 `--build` 只冻结文本/命令；带 `--build` 才在原有共享登记内调用冻结编译入口或 FFDec。未提供“复用已有输出再构建”，失败证据不覆盖。

```text
python experimental/recovery-first-raster/prepare.py build/m52/recovery-first-raster-compile-02 --version 0.2.24-recovery11-raster2 --build
python experimental/recovery-first-raster/prepare_host.py build/m52/recovery-first-raster-host-03 --build
```

宿主准备以冻结 E159 的 pfe.swf 为输入，**不以安装版 BEFC 替代**；只 import Grafon。复用现有工具链路径、共享登记、SWF tag/header 与源码正规化工具。核对 MainFE、World、Game、Land、Location、Camera、GUI 导出未变，非代码 tag、类表和 movie header 未变；Grafon 新入口逐方法回读。未声称审计所有 ABC 方法的语义。不会重新加入 Game 桥，也不写宿主安装点。

首屏坐标时序：`scenePreload=true` 时初次 hold 为零 chunks；恢复中的 sceneOpen 走原生全景预绘一次（因此出生 anchor 不会再使它补画另一视口）。`scenePreload=false` 时恢复中的 sceneOpen 本来就不 ensure，实际首次 chunks 生成来自 anchor 设置后的自然 Camera.calc→sceneTick。组件分别检查这两条路径；目前尚无实际耗时结果。

## 原生验证前的边界

1. preload 开 / 关，首绘准备零 chunks；恢复后完整 tile（包括 shelf）、对象、单位、门箱、掉落、墙痕均保留。首屏来自 anchor 后的自然相机更新；按键可操作时间须按原 scene12 测法与 solo 对比。
2. 两侧只有实际换图的加入侧延后；host/offline/普通分房绝不等待该 gate。单边缺少新接口不应报错。
3. 首绘时的 loc.grafon、lightBmp、visObjs 已完成原生初始化；对象构造、副作用与相机/GUI的原顺序不改。恢复过程中外模组的像素依赖仍需原生全 22 项组合验证。
4. 死亡、World / Game / Location 替换、断开、失败要取消精确 ticket；失败仍沿 RoomSync 原来的 hold/错误界面策略，不能为解开 raster 顺手放行未确认世界。旧 grant 不能 ACK 或导入新 Game。
5. 该候选只减少先画本地又马上销毁的栅格工作。仍有单位构造、完整恢复及网络等待；不宣称已达到单人耗时。
