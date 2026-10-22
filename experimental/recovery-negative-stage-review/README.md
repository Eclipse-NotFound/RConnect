# 原生加载尾帧：负优先级监听核查

2026-10-23。仅只读核查并保存本报告；未编译、运行游戏、改外部模组或部署。

## 输入和结论

依据 `build/cooperation/8f83135df8/input.json` 与 `build/cooperation/59bdfdf888/input.json`，两次实际加载的 **14 项模组字节完全相同**。完整 SHA256 以这两个输入文件为准；下表只缩写以便阅读。测试宿主为 host03 `29D36CDD…601EF7`，实际 RConnect 产品为 early2 `D356483F…7ACB3`，加载入口另为固定 harness `D52EF430…21086`。

最新实测由根完成：首进／重访 `-1 → -7001` 为 **2561／2522ms**，`-9001 → -10001` 为 **4／6ms**。前一区间包含下列模组回调及 RConnect 的 `CoopPause.after(-7000)`，不能只命名为 LAD/WB/CS。

**相同优先级的重要补项：**

| Stage 优先级 | 回调 | 来源强度 |
|---|---|---|
| -80 | LightAndDarkness `LadRuntime.onFrame`；PermanentInjury `frame` | 两者均逐文件构建指纹匹配 |
| -100 | WallBlend `onFrame`；FirearmAttachments `Runtime.after` | WB 为生成源指纹；FA 为部署文档指向的准确 Git 版本，缺独立构建源指纹 |
| -200 | ContinuousScene `onFrame` | 六份生产源及实际产物匹配 |
| -7000 | RConnect `CoopPause.after` | early2 全部 90 源文件指纹匹配 |

相同 Stage、相同优先级按实际注册顺序运行；本报告未把 loader 清单顺序当注册顺序证据。普通 DisplayObject 的帧广播监听不与 Stage 同级排序直接混用。

## 14 项清单

“强绑定”指已检查构建/冻结清单中的源字节及对应产物；“归档绑定”指准确部署记录或含同字节产物的 Git 归档，未等同独立编译源证明；“unknown”明确表示尚不能证明实际二进制对应源完全一致。没有源绑定的当前 HEAD 不用于排除回调。

| 实际模组 / SHA 前 12 位 | 可核对的 ENTER_FRAME 注册 | 证据与边界 |
|---|---|---|
| AddictionSystem `5A4D9A405777` | `main.stage.frame` 默认 0 | 归档绑定：Git `74d1621` 同时保存与实测一致的 release SWF；该提交 `src/addiction/Runtime.as:12`。无单独构建源清单，不宣称逐字编译证明。 |
| ContinuousScene `7F1F2961C6E2` | Stage `onFrame=-200` | 强绑定：`mods/ContinuousScene/build/large-map/source-manifest.json` 的六份生产源全部匹配，实际同目录 SWF 为 7F1F；`ContinuousSceneMod.as:46`。 |
| FirearmAttachments `B3304596EB7E` | Stage `before=+100`、`after=-100` | 归档绑定：`state/keybind-deployment-2026-10-15.md` 明确实现 `8d570a9`；直接读该提交 `src/fa/Runtime.as:36–37`。`build/out/keybind-2026-10-15` 的产物/validated 均 B330。当前 Runtime 与该提交已经不同；没有使用当前源冒充。缺源哈希，编译对应关系仍未独立证明。 |
| LightAndDarkness `8ADBA6914DF5` | Stage `LadRuntime.onFrame=-80` | 强绑定：`state/brightness-deployment-2026-10-21.json` 中 23 源文件逐一匹配。另 `LadSceneBake` 的 `g.visual ENTER_FRAME=-10000` 挂在 visual，不是 Stage。 |
| ModLoader `BD71B6F31774` | `main.tick` 默认 0；不是 Stage | 归档绑定：`state/keybind-integration-2026-10-15.md` 指 BD71 / 提交 `55d789d`；该提交 `src/settings/SettingsHost.as:45`。无准确构建源指纹，实际源绑定强度不足；不以当前 debugger 测试源码算实际回调。 |
| MoreSkills&Weapons `526A6FD09297` | Stage `onFrame=0`、`onSmartBeforeFrame=+1000`；main `onRetry=0` | 强绑定：`build/out/flash-visibility-20261021/candidate1/source-hashes.json` **59 份冻结源全匹配**，同目录 SWF 为 526A；`src/MoreSkillsWeaponsMod.as:139,178,179`。冻结源未发现负优先级帧注册。 |
| PermanentInjury `D4F6A096EE06` | Stage `frame=-80` | 强绑定：`build/out/PermanentInjuryMod.build.json` 的五份 AS 与默认配置全匹配，同目录 SWF 为 D4F6；`src/PermanentInjuryMod.as:19`。 |
| RandomRooms `3F8789C62F9B` | Stage `onFrame` 默认 0；两条互斥启动路径 | 归档绑定：部署/整合记录指向发布标记提交 `4b6b280`；直接读该提交 `src/RandomRoomsMod.as:190,202`。无独立冻结源清单，实际源绑定强度不足。 |
| RConnect harness `D52EF4300C7D` + 产品 `D356483F927C` | 产品负优先级见下一节 | 产品强绑定：`build/m52/recovery-early-exit-compile-01/prepared.json` 的 90 源全匹配；源为 `experimental/recovery-early-exit-authorization/src`。harness 字节冻结明确，但本轮未重建其源→二进制对应关系，harness 自有注册列为 **unknown**，不并入产品回调。测试驱动的新增标记亦另算。 |
| RealisticVision `7852F61E0839` | Stage `onFrame` 默认 0 | 强绑定：`build/regression-recovery-output/production-singlepass/manifest.json` 中六份源及 SWF 全匹配；`RealisticVisionMod.as:458`。`RVExplorationAPI.active` 仅布尔查询，无大图初始化。 |
| RModifier `4F1D6CF19979` | 冻结源没有 ENTER_FRAME；`LootEditorMod` 使用 500ms Timer | 强绑定：`build/out/localization/installed-input/source-input.json` 十项文件全匹配，旁侧本地化产物为 4F1D，与部署回执一致。Timer 不能当负优先级 Stage 监听；不据此排除它对全局运行的所有影响。 |
| Sandevistan `3E220B595F54` | Stage `onFrame` 默认 0 | 强绑定：`build/out/a-travel-hold-20261022-003/intent.json` 的 11 份 frozen 源全部匹配；`frozen/src/SandevistanMod.as:441`。补丁用 MainFE 源不是该 SWF 的实际主类，不重复算注册。 |
| TDFC `7ACD45193109` | 来源目录 `TdfcRuntime.onFrame` 默认 0；实际精确源绑定 **unknown** | 产物已匹配 `mods/ContinuousScene/build/generated/tdfc-threat/TDFCMod.swf` 与 `state/performance-deployment-20261020.json`。来源目录及 `tdfc-threat.py → tdfc_scene_compat.py` 生成链可读，基于 `fb73655` 加场景桥；但 source-origin 只记录更改文件名，缺最终全源指纹，且旧生成器从当时 HEAD 摘桥代码。不能把该目录或 TDFC 当前 HEAD 当已证实准确源。 |
| WallBlend `14112DA06214` | Stage `onFrame=-100` | 强绑定：`mods/ContinuousScene/build/generated/wb-motion-source/source-manifest.json` **13 文件按原生成器的 LF 文本哈希全匹配**；实际旁侧 SWF 为 14112，`state/deployment-v082.json` 指向该产物。原文件 CRLF，不错误地把 raw-byte 不同当源漂移。`WallBlendMod.as:62`。 |

## RConnect 产品的负优先级列表

准确 early2 源：`CoopPause.after=-7000`；`EnemyGrip.after` 和 `PlayerMines.after=-8000`；`PeerGrip.after=-8500`；`ProjectileGrip.after=-8700`；`RoomSync.after` 和 `GameBridge.onMirrorMaskFrame=-9000`；`GameBridge.onMirrorFrame=-10000`；`TeammateMap.tick` 和 `RoomDiagnostics.tick=-12000`；`ExplorationSync.requestRender` 和 `ManualStartup.tick=-20000`。

`ExplorationSync.requestRender` 只申请重画，全图绘制在 RENDER 路径；不能把名称含 Render 就当这里在绘制。大量联机回调在本轮 solo 离线状态早退。此前 onMirrorFrame 间接调用 RV active 的“大图初始化”假说已由准确 RV 源排除。本轮新 4／6ms 分段进一步表明该段不是已观察的约 2.5 秒主要成本，但不代替完整联机性能验收。

## 首绘后初始化与日志边界

- **WB：** `SceneBlendCache.update` 对新 surface 先建立 pass/view；`refreshView` 遍历该块 tile 构造局部 space，真正重建前又调用一次。6ms deadline 只用于首次、非视口内块；可见块 `sceneDeadline=0` 同步做完。旧实测 heartbeat 39762ms 已显示 35 chunks / 35 updates / 70 visible overlays；第二次为 35 / 70 / 70。普通 `render`/`background` 的 totalUpdateMs 来自另一组 renderer，不包括各 scene pass。scene 总耗时未输出；maxSliceMs 仅专用 motion 测试入口查询，本轮未用。首段 WB heartbeat 在最低 Stage 标记前 7ms，但缺开始点，不能推出其占用了整段时间。
- **LAD：** 两次目标大图 ATTACH 都为 `beforeRaster=true`、45 灯；灯具发现/strip 已在首绘前。首绘后仍可能首次建立视口灯光/阴影/背景缓存，并遍历机器/地标对象。heartbeat `renderMs=87/97` 仅覆盖 `LadLightField.render`，不包含 `lights()` 等或整个 onFrame。BAKE 860/668ms 是基地流程，不能移到目标尾帧记账。
- **CS：** `registered` 在 14159ms，首旅开始为 31144ms；后续 onFrame 的 `NativeSceneAdapter.attach` 仅保存 world/初始化三个 Class 缓存，不调用 `prepare` 的地图合并。Pip 未打开时 refresh 即退。现有日志未记录整个 onFrame 耗时。
- **PI / FA：** 这次新发现的同优先级注册必须保留在分段解释中。PI frame 处理本地角色记录、参数刷新和 UI；FA after 为准确旧版本回调，不能只因名称像武器逻辑就假设加载阶段零成本。本报告没有它们的回调起止计时。

## 下一步边界

细分标记已经由根在64bb6b4030完成，完整结果见`../recovery-paint-enter-modules/RESULTS.md`：-100组2733/2505ms，-80组4/4ms，-200组0/0ms。停止继续扩单人分段探针；不能把组间隔直接当单个函数时间。

准确FA归档的`Runtime.after:160`中，战斗更新需要帧前记录的`wasPlaying`（包括allStat=1、t_exit=0）及原生stamp推进，meleeStep另需meleeSpec；本轮加载日志gun为空、saved assemblies=0，没有实际全单位扫描证据。无条件drawAttachments在缺held/heldId/held.vis时返回。这更支持先检查WB初始化，但没有计时证明FA严格为零。

WB已有surface身份/revision、sceneViewport、scenePending/sceneDeadline续作和paintMaterials共享缓存。优先核对makePasses时与更新时两次refreshView，以及延期判定前已建立pass的开销；没有证据要求再缓存材料。beforeRasterClear会清所有pass/材料，重访重建本身不等于同一轮重复建立35块。不能简单等loc.active再跑，这会把阻塞移到恢复操作后。

根已向准确WB负责会话`smoothconnect`（01a11bd2-fd9e-7d10-bc64-ca32e8625ed3）交付限定证据、请求只读核查最小方案，不要求停测或改正式版。FA B330部署负责会话为`改枪 (3)`（01a13b7b-fe67-7a00-a10f-dd2df045fad9），不是后来0.4.0未部署分支`改枪 (主)`。本次没有修改其他模组。
