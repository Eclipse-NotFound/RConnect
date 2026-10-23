# roomfix1 大场景实测的有限复核

准确运行：`build/cooperation/1cbea1016e`；原 `recovery-room-candidate-scene-dual-01/result.json` 和登记回执均为失败，保持原样。此文件只解释现有证据，不授予通过资格。

## 断开后的偏好断言

加入侧原日志第 8 行先出现 `welcome id=1`，第 11–12 行才出现测试驱动配置 `merged=true`。真实 `Session.as:410` 在 WELCOME 处理内同步调用 `rooms.receivedWelcome`，后者经 `observeHost` 调用 `MapGeneration.receive`。该函数在首次接收场景字段时保存 `sceneClass.nativeEnabled`，之后不会再次保存；`reset` 恢复这个最初值。

测试驱动则直到 `mod.game.gg` 非空才设置 `nativeEnabled=true`。因此其设置发生在已联网之后，末尾用 `===merged()` 要求恢复 true，不代表“首次联网前的原偏好”。当前 CS 源码默认 false；本次唯一 AppID `pfe-modsettings-rconnect-coop-join-1cbea1016e` 的 `Local Store/ContinuousScene.preferences.json` 实际不存在，原框架也没有为 CS 预置该文件。此失败与测试设置时序不符有直接依据，不能由它断言产品恢复逻辑损坏，也不能删除断言后追认旧运行成功。

最小后续复测方式：在本次新私有 AppID 启动前预置真实 CS 偏好文件为 true，让 CS 自己读取，继续检查断开后恢复 true。保留现有原生地图生成、状态和计时检查；不要改用户真实配置。若仍需要只在运行中设置偏好，则必须把“连接前偏好”和“运行中设置”作为不同预期，不能混为一个。

## 186 / 317 不能直接视为敌人数不一致

`GameBridge.applyUnitsSync:5763–5772` 对合格存活镜像单位创建 `MirrorHitUnit`，并加入同一 `loc.units` 数组；该代理不加入原生 `firstObj` 推进链。`readUnitsSnapshot:5553` 明确排除它。驱动使用的是未经筛选的 `loc.units.length`，因此两端该数字没有相等契约。

本次普通基地为 38 / 47，同时日志为 9 / 9 已匹配单位，差值恰为 9。大场景为 186 / 317，差值 131；已有日志 `unitsync matched 137/137`。这些证据与额外命中代理的设计相符，不能据此说漏同步 131 个敌人；也没有类型普查能把这 131 个逐一确认为代理，不能把推断升级为已证实。死亡、触发器、非战斗单位与代理须在后续同一时刻按真实类别区分。

## 计时范围

大场景三段双侧较慢端为 15.818 / 4.913 / 8.966 秒；房间、种子、出生位置原断言通过。但本次没有同组合的大场景单人对照，不能沿用普通 48×25 房间的单人时间宣称大场景已达到单人耗时。加入侧存在约 2 秒 checkpoint restore 和恢复后约 3.4 秒帧间隔的真实记录，尚须作为性能现象保留。
