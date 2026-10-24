# 普通房首次灯具绘制：待批准的独立接口提案

本目录只有可审查 diff 和本文。仅修改 RConnect 内这两份提案，没有改 LAD、WallBlend、宿主安装或任何冻结实现，未编译、未运行。LAD 既有授权只覆盖测试/部署时间协调；**必要的 LAD 独立接口、隔离验证及合格后部署仍待用户批准，由根统一请求。本提案不涉及 WB 修改。**

目标是省去首次随机普通房 LAD 转换时的双重 BAKE。34df1bfb97 原日志为主 913 / 加 910 ms，约 0.9 秒只是待验证预期，不能视为净收益或整体加载达标。

## 来源和现有接口限制

- LAD 8ADBA691 部署回执：`mods/LightAndDarkness/state/brightness-deployment-2026-10-21.json`。准确 `src/lad/LadRuntime.as` SHA256：`C139A63C2DA131898B9D68D2A681E8D3560EEE9C11104FF83AF7B6670BE1DE2C`。
- A796 准确 Grafon：`build/m52/recovery-room-first-raster-current-source-02/source/scripts/fe/graph/Grafon.as`；来源由同目录 receipt 绑定；源码 SHA256：`667D4295F417E67DBC7298A082E5B409CDBA5A4C3B61C0104A0840BBD9B12540`。后续宿主实现需保留当前已通过改动，不能整份覆盖。
- 现有 `continuousSceneBeforeRaster` 仅从大场景 sceneOpen 发出，LAD 私有处理器硬要求 sceneLarge。普通 drawLoc 的 scenePrepare 将 sceneLarge 清为 false。不能伪造此标志，也不能借公开 render 代替 attach。

## 最窄实现：只跳过绘制，原生对象引用始终保留

1. Grafon.drawLoc 入口记录 `param1.grafon==null`。原逻辑绑定本次 loc、grafon 和尺寸后，调用 `World.w.main.getChildByName("LightAndDarknessCarrier").ladAPI.runtime.beginOrdinaryRaster(World.w,this,nloc,firstRaster)`。没有两个新接口时完全走原流程。
2. LAD 只返回本次候选灯具对象的 Dictionary 和短期票据；不提前 bind store、discover、造素材、创建代理、写入存档或挂 tick，也不修改 bo.vis/light/erase。
3. 准确 A796 Grafon.as 的原 **3790—3845** 段是 `j=-2..3` 的多层循环。每次 bo 访问计算一次是否在集合内，仅给原 **3799 的 bo.vis、3834 的 bo.erase、3838 的 bo.light** 三个绘图判断增加 `!omitOrdinaryLamp`。原 `sloy/er` 条件、j 循环、矩阵、色变、非灯背景、层间 copyChannel 及其它绘制全部保留。没有跳过整个对象层循环；同一灯在其适用的各层中均省掉这三项，效果对应原 strip。
4. 原 drawLoc 外加 finally，正常完成 redraws++ 后标记成功，再由同一 runtime.completeOrdinaryRaster 接收票据。原生错误或未完成不给成功资格；未改对象引用，所以没有跨失败出口残留 null。若绘图期间收到关闭请求，先标记取消，在当前画面完成后恢复，不提前丢票据。
5. LAD 原 -80 回调、换 Game/store 和 detach/attach 顺序不变。原 attach 执行 writable、environment、discover、darkZones、targetClass；这些成功之后才核对实际发现集合。只有灯具数量、对象身份和去重都与票据集合完全相同，且仍是同一未重画的世界/房间，才直接 strip。**成功 strip 之后**才清票据；代理、flush、render 等后续失败已有完整 lamps 数组，仍走原 detach 恢复路径。

Grafon 的 sceneRasterizing/sceneRepaint 是私有字段，只在其自身 helper 检查；LAD 仅使用公开 sceneLarge/sceneRedraws。

## 已闭合的两条失败路径

- **store/discover 或其后、strip 前失败：**票据没有被提前拿走。原 attach 的 catch 进入 detach(true)，先由 cancelOrdinaryRaster 恢复遗漏的原生灯图；即使 lamps 仍为空也有票据集合可恢复。
- **discover 跳过不可转换素材：**实际集合不等于预选集合，canUseOrdinaryRaster 先取消优化并恢复原生画面，再走原 BAKE，只转换原 discover 真正接受的灯。未匹配灯保留原生画面，不为省重画提前制造素材或代理。

恢复的 BAKE 顺序是：保留**此刻**的三项引用 → 暂时置 null → 调用原 LadSceneBake.change → 由其 mutation 恢复刚保留的引用 → finally 再恢复仍为本次 null 的引用。第一次 clean baseline 因而与当前“省略这些灯”的栅格相符；不会先恢复引用、再把缺灯像素错误识别为破坏痕迹。新产生的血迹、墙痕继续由原像素比较保留。引用取当前值，不能把首绘时的旧 frame/状态恢复回来；finally 不覆盖其它代码在重画期间安装的非 null 替代引用。

若这期间已发生另一次原生完整 drawLoc，sceneRedraws 不再匹配。该次 drawLoc 的 firstRaster 为 false，本来已经按未改动引用完整绘制；这里只丢弃优化票据，后续 attach 走原路径，不执行额外“恢复”、不回滚开关灯动画或状态。若换房/换 World，当前画面归属不符，同样不重画别的房间。

恢复仍依赖原 BAKE 能正常完成；内存不足或绘制本身失败不能凭静态审查声称可自动修复。本补丁没有用清空破坏像素来掩盖失败，也不改变原错误处理/性能门槛。

## 首绘判据、初始化和同帧游戏逻辑边界

- 仅原生 t_exit==19、新随机地图、普通正尺寸 <=48×25、World/Game/Land/Location/Grafon/gg/gg.loc/loc.gg 身份一致、active 且无原生错误；已附着或已失败的 LAD 房间不接收。普通门、剧情房、大合并图不优化。
- `Location.grafon` 在准确源码初始为 null，第一次绘图后保留，out/reactivate 不重置。因此已绘制/复访/有破坏像素的房间不会进入。逻辑层已保存 Tile/门箱状态照常参与首次绘图；CS marks 属于大图，本方案排除。RC 后续 checkpoint/地形/留痕恢复不改。
- `Land.ativateLoc:1323–1326` 先选 land.loc、gg.inLoc、loc.reactivate，再调用 World.ativateLoc；后者 :1080–1081 先选 world.loc，再 drawLoc。新接口放在 Grafon 自身 loc 绑定后，所以不拿旧房或旧 gg 环境执行；camera.setLoc 在 drawLoc 之后，begin 不读 camera 或建立灯具代理。
- **不能假定首次 drawLoc 与 LAD 回调之间没有游戏推进。**准确 A796 `World.step:1262→1273` 是 exitStep/enterToCurLand 返回后，同帧继续 land.step。`Location.step:3566–3586` 会执行玩家、prob、链表对象；`Land.step:1649–1655` 还执行运行中脚本。`Location.allon/alloff:2967–2971、2990–2994` 会调用 backobjs.onoff 并 World.redrawLoc。
- 因此本版已取消早期置 null 的设计：上述游戏逻辑始终得到原 bo 引用；帧号、开关、alpha 等原生更新不改。若触发整房重画就自动回原路径。`Location.lightAll:3116` 遍历 objs 光源，lighting 按 Tile 可见度工作；本次未发现它读取被省略的背景像素。未声称覆盖任意第三方在两回调之间直接采样背景像素的扩展；该边界需当前组合实测。
- 调用链使用 RConnect 已有导出文本；本轮读取受保护 game-reference 的命令被护栏拒绝，没有执行或换通道重试。BackObj 的准确方法正文本轮没有新增读取；保留全部引用的方案不依赖“onoff 能容忍 null”这一未验证假设。

## WB 时序和最小验证

LAD 仍在 -80 完成原 attach，WB 仍在 -100 根据本房原生表面进行前/背景重建。未调用 WB.refreshNow、未改配置、未跳过融合，也未新增 RConnect 每帧遍历。新增 Dictionary 仅在首次房绘制和这一次 attach 使用。

批准后复用既有原生加载驱动，不新建框架：

- 正常首程双人/单人保留原35项与11显示检查，确认同图同入口、出生、首帧、模型、灯状态、代理数；省略集合只消费一次，原 BAKE 确实减少，完整加载耗时无退化。
- 注入 store/discover 失败；注入 getObj 缺失使集合不匹配；确认原生灯图恢复且首个 tick 的墙痕/血迹保留，再核 attach 没有重复代理或静默漏图。
- 首次 World.step 触发 allon/alloff 或完整 redraw，必须计为放弃优化，保持真实灯 frame/光照状态；在完整绘图期间关闭 LAD，完成后正确取消。
- 零灯、缺接口、禁用、非19、剧情/大图、普通门、背景门、死亡恢复、复访和损坏房均继续原路径。
- 比较透明背景、开关灯、坏灯、灯的前后层/擦除/颜色贡献；同帧新留痕必须保留。图像轮与净性能轮分开，不能拿 BAKE 消失直接授整体性能资格。

静态准确上下文匹配只证明补丁对准来源，不等于 AS 编译、图像等价或实际性能通过。本目录无构建/部署入口。
