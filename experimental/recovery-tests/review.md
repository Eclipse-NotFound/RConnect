# recovery-integrated 独立只读审查

日期：2026-10-21。范围为最终整合源码相对准确 `574D / 0.2.23-coop-bundle2` 的增量；不审查或修改安装版。采用 code-review 的规范与需求两个维度，但只列阻断项与验证边界。没有编译、AIR、部署或其它会话通信。

## 固定输入

- 审查目录：`experimental/recovery-integrated`，README 已存在并声明整合完成。
- `integration.json` SHA256：`72c8d1dd4464410ce0bb31d59d9bfb82c5b90db621146e75a69b73342899d0ac`。
- 已逐文件核对清单中的 84 个最终 AS 源码哈希全部一致；相对 574D 有 23 项变化。
- 当前源码映射按路径排序、Python JSON 默认格式编码后的 SHA256：`a7e88343ee38c5523156af1c310c06a1e4a53c78dfa3cad8535647b9204b2dd6`。此值仅用于本次审查的集合标识，正式构建仍以逐文件清单为准。

## Standards

未发现需要阻断合并的明确工作区规范违规。源码均留在隔离候选，没有将反编译参考或其它模组当作可写来源。未据动态访问、既有大类或重复循环单独提出风格性返工。

## Spec 与验证入口

本次限定路径未发现可凭静态证据认定的生产逻辑阻断缺陷；发现 **1 项验证准备器依赖遗漏**：

- `recovery-tests/prepare.py` 的 `COMPONENTS['impact']` 仍只复制 `ImpactEventQueue / BallisticImpactVisuals / EnergyImpactVisuals` 三个生产类。最终整合的 `ImpactEventQueue.as:19` 和 `EnergyImpactVisuals.as:181` 已直接调用新增 `ProjectileFrameStream`；`recovery-wall-impact/components` 模板也没有此类。组件只把自身 `components/impact/src` 交给编译器，因此按现有准备器冻结最终源码会遗漏该共同依赖。应在第一次冻结前把最终候选的 `rconnect/game/ProjectileFrameStream.as` 加入组件生产依赖列表并记哈希；不能用旧组件通过结果替代。这是静态可确定的构建输入闭包问题，尚未执行编译确认编译器报错。本次只读审查没有代改。

## 已确认的合并边界

### 加载与 room19

- `MapGeneration / NativeRoomState / NativeTileState / RoomTerrainView / TerrainSync / RoomCodec` 与冻结 room19 文本完全一致；最终 GameBridge 相对 room19 仅加入光晕、effects 与临时保留开关，房间提交和恢复增量没有被其它整文件覆盖。
- 最终 `RoomSync / RoomEntryView` 与 recovery-loading 覆盖文本一致。RoomSync 相对 room19 只移除交接文字；`entryPending`、实际暂停、房间身份、确认条件仍存在。
- `RoomEntryView.as:28–109` 复制原生 vwait 资源及本地化内容，没有调用副作用较多的 `World.setLoadScreen`；维护自己的场景/SATS覆盖层，不改 World 的 vwait 或剧情点击状态。`World.as:1134–1170` 的 20/19/18/16/1 工作边界保留。
- 宿主 `commit` 发送 grant 后恢复，pending 留到 ACK；未换房一侧不因单纯 busy 显示覆盖层。首次共同地图 grant 仍由宿主坐标执行 TravelPlacement。首次非随机地图未新增提前构建通知，且 room19 尚无本轮完整原生资格，不能因此宣称所有地图并行加载或达到单人耗时。

### 光晕

- `PeerGrip / TelekinesisVisuals / PlayerBodyEffects` 与 recovery-aura 覆盖文本一致。
- `GameBridge.as:274 / 1001 / 1681` 的三处玩家身体 `apply(... locallyHeld(...))` 全在，普通敌人未加入额外 held-peer 判定。
- PeerGrip 在原生抓取后采集真实 GlowFilter 和颜色，受抓本机经 `after` 与最终 RENDER 重绘；释放、抛出、失去许可、换房与断开经 reset 清理。TelekinesisVisuals 只额外接受 `loc.gg` 的真实本机玩家身份；PlayerBodyEffects 的原生抓取保护只作用玩家根颜色/透明度，不绕过普通敌人分支。
- 以上确认的是调用与所有权完整，不能替代 16 回合最终舞台像素、截图和 20 回合抛掷验证。

### Session 去重

- `Session.as:583–600` 先立即处理加入侧上传、调用 updateRemote，再省略仅发回上传者的额外 worldstate。`onTick` 的宿主定时广播仍在；抓取、伤害、握手、房间消息没有被这个分支推迟。
- `HostServer.as:75–123` 仅对 WORLDSTATE 为收件人复制包络并清空自己的 snap；保留名单、其它玩家与世界字段，不原地修改源包。加入侧 `applyWorldState` 本来就先跳过 myId，因而与其既有消费逻辑一致。
- 这不是“所有情况下延迟不变”的性能证明；移除冗余上传触发包后的真实到达间隔仍须测，但未见加入侧动作在宿主的立即应用被删除。

### 弹体、死亡、结束与换房

- 所有新增采集事件使用真实原生显示点；当前帧采集与 RENDER 同 stamp 修正均进入增量，200 ms 累积包保留。既有 records 合并新点，拒绝旧 sourceStamp 与 ended→live 回退；无图像事件的独立 impact 在弹体序号过滤前入队。
- `tickBeam` 的爆炸与真实 end 判定先于显示更新；不再按固定 30 FPS 计算新普通弹，不把迟到终点用于重缩已经显示的整段轨迹。旧无 frames 包才走兼容路径。
- 死亡处理 `GameBridge.as:5747–5754` 先清除 `_unitMotion`，再以 null 接收累积弹体；`ProjectileFrameStream.receiveClock` 接续旧显示时刻，覆盖弹体、能量接触粒子及命中队列。死者仍不进入 `readEnemyMotion / applyEnemyMotion` 快速通道，其尾段仍依赖 200 ms 全量；不能声称死后尾段已变为 50 ms。
- 会话结束、roomRole 和房间变更重置相关采集/显示；各显示 tick 另按 Location 身份清理。只重现显示，没有调用原生 Bullet 的伤害或碰撞逻辑。
- 有界降级仍在：64 点历史、160 活动弹体、256 能量接触、512 待播火星及 15 秒陈旧记录清理。它们不构成“密集场景所有效果完整”的证明。全普通弹改采帧增加每帧遍历和分配，必须保留密集性能门槛；此次只读审查不对性能放行。

结论：规范阻断 0；生产逻辑的确定阻断 0；测试准备依赖阻断 1。其余只确认上述静态边界，待统一编译与原生验证。
