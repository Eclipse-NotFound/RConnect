# 缓存地图重访卡死：外部有界诊断

仅诊断 `3b3c31c5f5` 第三段重访卡住。保留准确 early1 / 2D415D 宿主 / Sand003 和安装 22 项准入，不替换生产代码。原三个旅行流程、全部时间门槛、出生距离、原生按键及原 raster 断言不变；只有 `FirstRasterSceneProbe` 增加读取。源差异见 `probe.patch`。

每段至多 20 行 `EARLY REVISIT PROBE`，每 250 ms 最多一次标量查询；状态变化最多 13 行，另为 8/15/30/44/60/90 秒和结束留位。超时仍能保存真实票据的 waiting/unpainted、Grafon pending/sceneViewReady、renderer.loc 身份、原生退出/暂停/读档/死亡标志、联机交接和 Sand 查询。World/Game/玩家/地图/房间/renderer 只记引用是否与开始或实际票据创建时相同，不复制大对象。只读 sceneViewReady；不推进渲染、清票据、申请许可或放行交接。

`RoomTravelTimingTestDoc.as`、`RoomTravelSceneTestDoc.as`、`A22RoomMetrics.as` 从原冻结入口原样准备。`finish()` 的原判断逐字不变。准备保留 `original-prepared.json`，新清单同时核对原来源和新观察器。原 runner 原样复用；薄运行包装新增诊断记录有效性，不删除原失败、不授性能资格。

根会话在 mods/RConnect 使用既有 Python（`-B -X utf8`）：

```text
experimental/recovery-early-revisit-probe/check.py
experimental/recovery-early-revisit-probe/prepare.py --output build/m52/recovery-early-revisit-driver-01 --build --registry-wait 900
experimental/recovery-early-revisit-probe/run_native.py --candidate build/m52/recovery-early-compile-01 --game-candidate build/m52/recovery-early-host-01 --drivers build/m52/recovery-early-revisit-driver-01 --output build/m52/recovery-early-revisit-native-01 --sand-mode bridge --registry-wait 900
```

只允双实例诊断。编译保留 1 GiB、运行保留原双实例 6 GiB/运行保护 512 MiB、共享登记、隐藏桌面、唯一实例及隔离存储/清理规则。未编译或启动 AIR；源检查通过也不代表 AS 编译或原生有效。
