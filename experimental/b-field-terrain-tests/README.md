# B 外置真实破墙验证

仅测试源，无产品改动。入口 `BTerrainCases.as`，构造参数、`input()`、`step()`、`finished` 与外置 `BUiCases` 相同。由 root 复制到统一驱动、接线、编译并登记运行；本子任务没有运行 JVM/AIR，没有部署。

建议独立场景名 `terrainlive`，避免覆盖驱动现有内置 `terrain`（WeaponProbe 贴花测试）。驱动需在 `external()` 与 `BFieldCases` 增加此分支，沿现有外置场景提供 `home`、`floorY`、`check/write/read/finish/log`。建议整轮超时 300 秒；每阶段另有 45 秒截止。只允许既有 `pfe-modsettings-rconnect-b-startup-` 隔离应用运行。

## 核验内容

- 组件检查优先动态调用已编译 `TerrainPatchChecks.run`。该类通常被生产编译裁剪，缺失时外置保留原测试的输入和断言，通过 ApplicationDomain 直接调用真实产品 `TerrainPatch.isFrontDestruction`、`TerrainInk.freshFrontCoverage`，字段表取真实 `SceneSnapshot.TILE`。没有复制判定算法。
- 旧 field9 不包含 TerrainPatch 时，日志明确记录组件跳过；不将缺失记为通过，真实测试仍照常执行。
- 四轮：宿主轻机枪、加入侧轻机枪、宿主导弹、加入侧导弹。实际按开火键，通过原版 Weapon、Bullet、Location.hitTile、Tile.die 路径。没有调用 die、hitTile、damage、attack 等方法制造命中，也没有删除在途子弹制造静止。
- 普通金属/墙面瓦片由原生 `Tile.mainFrame("A")` 建立。仅测试准备调整初始耐久和随机散布，保留枪械自身 destroy、子弹寿命、爆炸半径及结算。两名玩家分别站在墙前 500/650 像素，避免队友挡住弹道。原生轻机枪第一次降低耐久后松手，观察至少 90 个主侧 tick，要求墙仍有碰撞、两侧实际前景像素哈希和碰撞字段一致，且加入侧 terrainRedraws 不增加。
- 再次真实开火，直到至少一块墙被摧毁；导弹轮要求至少两块墙消失以覆盖真实范围爆炸。松手后等待至少 90 个 tick，前景区域连续 20 个不同 tick 稳定才取样。对比实际 `Grafon.frontBmp` 区域（墙外多取 64 像素边缘）和原生瓦片碰撞/耐久字段，并确认主侧前景确有透明擦除。
- 加入侧只在实际 `displayFrame.tick >= sourceTick` 时检查稳定结果，首次符合帧门槛即报告；不会把错帧重试到偶然相同。记录实际源/显示 tick、像素哈希、碰撞差异、重画数、增量数和主侧原生弹丸出生数。
- 候选有 `incrementalWalls` 时要求普通墙死亡确实增加计数且没有全房重画。旧基线缺少计数时明确记录实际全房重画次数，不伪造“增量通过”。

## 测试边界

场景是隔离房间，要求至少 24×11 瓦片。首次准备调用已有 `ProbeArena.floor` 清除随机柜子/陷阱等干扰；之后测量期间没有清理弹丸。所有枪击与破墙发生在正常模拟中，测试不修改产品模块或 Native 回调。

门/陷阱、水、斜坡、平台、后景、缺像素、新位图代次等保守回退均包含真实组件否定检查。这里没有用真实开门或水体事件补充端到端回退案例，不声称这些额外场景已经实测。外置 helper 尚待 root 编译和实机验证；文件本身不构成通过证据。

公共字段审查：原生 Tile 的 mainFrame、phis/hp/front/opac、四个碰撞边界、shelf/diagon/stair/water/zForm 及准备字段均 public；Weapon 的 destroy/explRadius、装备与弹药/视觉方法均 public；Unit 的 currentWeapon/childObjs/invulner，UnitPlayer 的 invent/pers/setLocPos 均 public。产品 RoomRuntime.spawnsFor、ReplicaScene.terrainRedraws/incrementalWalls、ClientReplica.displayFrame 均 public。没有读取内部 AI 字段或私有按键锁存字段。

prepared-v9 / `b-field2-fixed20-01/terrainlive`：主侧 56 项通过后，在发布 baseline-0 参考时，驱动替换控制文件触发 Error #3012，测试没有进入真实开火。因此这轮仅是组件/准备证据，不能记录破墙实测通过。当前外置源已同步 currentWeapon 为空时跳过 remVisual，并将参考字段与阶段一次发布，避免中间不完整消息；根驱动新增的 #3012 重试须进入下次准备版后复测。

`b-field20-terrainlive-02`：起始墙面像素/碰撞相同，但 chip-0 超时，原生弹丸出生为 0、弹匣保持 90、墙耐久保持 300，不能认作破墙回归失败或通过。源码发现夹具未配置武器技能：原生轻机枪要求枪械等级 5，Weapon.checkAvail 会拒绝技能差大于 2 的角色。修订仅在装备前使用原生 setForcLevel(60)、smallguns/explosives=100、setParameters/healAll 做一次准备，保留武器要求与开火路径。另等待双方首次画面就绪、角色原生存活且可操作后再布置；若等待期间房间或地面基准改变，明确失败，不沿用旧位置或逐帧拉回。首次开火 20 个 tick 后及超时记录公开的角色、输入、武器门控，供下一轮确定未开火原因。原始失败缺少生命/控制采样，不能据此确认其与 security-02 一样曾经开场死亡。

`b-field21-final-01/terrainlive`：四轮真实轻机枪/导弹都已走到原生破墙，碰撞相同，incrementalWalls 累计 1/2/17/32，死亡未触发全房重画；主侧共 99 过、10 失败。失败均为裁剪区域 frontBmp 像素不相同，且四轮开火前 baseline 的主/加哈希各自固定为 bc128cd5/c1a70072；取样 sourceTick=displayTick，房间键相同。因此需排查基础绘制差异，不能据此断言为网络延迟，也不能直接将夹具或产品任一判为根因。新增取证仅针对 baseline-0/death-0，各侧两张248×328左右的小区域 PNG，加同刻房间/图层身份、颜色变换、周边完整瓦片字段/边界、64像素区块哈希与透明度统计。输出到隔离 applicationStorageDirectory，runner 原有 PNG 收集流程负责归档。没有降低或替换像素断言，没有改产品。
