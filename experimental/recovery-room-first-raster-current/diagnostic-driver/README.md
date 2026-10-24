# 首次栅格诊断驱动（尚未编译/运行）

只验证首个 `random_mane` 的真实票据能否把昂贵地图绘制留到完整授权/恢复之后。生产六类、宿主及原三程刺激不改；原 `RoomTravelTimingTestDoc`、`RoomTravelSceneTestDoc` 保持 scene-driver02 的原始字节。新增观察类沿旧 `FirstRasterSceneProbe` 的真实回调和所有权方式，去掉旧 fallback 类依赖。

只保留四个计数节点：真实票据首次返回；主侧 READY / 加入侧 GRANT 处理前；同一 handler 实际把 waiting 释放后；首次已完成 native raster 的 RENDER。最后附真实 early gate 结束后的操作状态。回调原样调用一次；自身错误只使诊断失败，不截获生产回调异常。

前置等待及恢复结束前要求 `sceneRedraws`、`sceneRegionPasses` 无增长，授权后才增长并达到可见窗口就绪。`sceneResident` 仅作辅助，因为预加载会先分配空块；`sceneWarmCount` 也不能代表首次绘制。因此不要求任意计数等于 1。到激活只比较最多四块、每块四个原生缓冲的对象身份与累计 eviction；允许正常预热增加绘制和驻留数。不读取像素，不证明完整地图只画一遍、像素等价或 GPU 完成。

每端只在原驱动结束时写一次 `Local Store/first-raster-current.json`，并打印一条 `FIRST RASTER CURRENT RESULT` 和一条 `COOP PASS/FAIL first-raster-current`。原三程、出生、移动/输入、日志错误门槛必须另行完整通过。诊断要求两端各四个节点、实际授权、相同原生身份、无观察异常、回调恢复及所有 checks 为真；不以整体原功能通过替代这些证据。此版本 `performanceQualified=false`，速度对照必须使用无观察器的原驱动。

准备入口：

```powershell
python -B -X utf8 mods/RConnect/experimental/recovery-room-first-raster-current/diagnostic-driver/generate.py
python -B -X utf8 mods/RConnect/experimental/recovery-room-first-raster-current/diagnostic-driver/generate.py --check
python -B -X utf8 mods/RConnect/experimental/recovery-room-first-raster-current/diagnostic-driver/prepare.py --check
```

根会话明确执行以下命令才编译一次 scene SWF；默认无 `--build` 只冻结输入。目标必须是尚不存在的 `build/m52` 子目录。

```powershell
python -B -X utf8 mods/RConnect/experimental/recovery-room-first-raster-current/diagnostic-driver/prepare.py --output build/m52/recovery-room-first-raster-diagnostic-driver-01 --build
```

复用原声明库与 `scene/EffectsHarness.swf`，准确绑定 roomload1 `6D4655F3…55392` 及其实际构建回执。准备时记录真实当前 22 项安装，编译前后不得改变；旧原生驱动的历史安装仅是来源证据，不能冒充当前运行环境。实际运行仍由根复用原双实例入口及准确新宿主准入，保留内存/登记/清理和私有 CS 偏好；此目录不另造运行器。
