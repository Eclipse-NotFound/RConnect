# 随机地图首次绘制：独立扩展

精确基线为已编译 RC `recovery-first-raster-02 / 7975167a…8f239`。仅覆盖 RoomSync，并新增本机身份记录 SeedRasterEntry；继续使用原 FirstRasterGate。宿主仍是 `FD92FBD5…6734E`，无需新 Grafon 改动。真实类组件 `build/m52/recovery-seed-first-raster-room-01` 已完成109/0；精确合入recovery13并编译，生产1177EB…FDDB1。仍没有真实游戏的首屏、控制恢复或耗时通过结论。

原缺口：scene12 的 random_mane 由 seed prepare 触发，未创建 NativeTravelPlan。旧首绘方案要求 nativeTravel.current，因而不会覆盖已测大随机图。此扩展只在现有 startSharedTravel **确实返回成功**后记录 World、Game、旧 Land、目标 id、非零 seed、sceneMerged 和起始 epoch；有未完成旧 barrier 时保留原绘图路径，不接管它。

新 Land 身份、实际 seed 与目的地一致时，原 sceneOpen 才可取得同一 FirstRasterGate。首个匹配 seal 需要新 epoch、准确目标/seed/mode、有限坐标，再绑定 barrier 和固定入口。旧 epoch、不同 seed 或已替换 Game 的空 travelId 消息不能授权当前图。重复 prepare 不覆盖正在执行的身份；重复 seal/grant 不重复恢复。所有网络字段、空 travelId、种子算法和同步频率不变；内部 seed-raster token 不发到网络。

随机出生原路径的实际依据是 seal.info 的 x/y/roomKey；nativeTravel 为空时 seal/grant 的 entryAnchor 均为空。原加入侧 grant 会读后来可能变化的 hostInfo 坐标。本扩展复制首个有效 seal 的入口，完整 checkpoint 恢复后在同房间放置该入口，再等待下一原生相机帧和真实 viewReady，最后重画逻辑墙痕并 ACK。没有跳过单位、地形、容器、掉落或永久修改恢复。

死亡、World/Game 更换、断开与失败均清除本机身份并释放 renderer 等待；失败仍沿原 hold/错误流程，不能为取消绘图等待放行未确认世界。不支持绘图配置保留完整旧路径。host、offline、普通分房、未实际开始的 seed prepare 没有新 raster 等待。

生成与窄组件（不会自动编译）：

```text
python experimental/recovery-seed-first-raster/generate.py
python experimental/recovery-seed-first-raster/prepare_components.py
python experimental/recovery-seed-first-raster/check_sources.py
python tools/validation/run_recovery_component.py --source experimental/recovery-seed-first-raster/components/room --entry NativeTravelRoomChecks.as --output build/m52/recovery-seed-first-raster-room-01
```

组件保留上一份真实 RoomSync 的全部原场景，追加 seed 生命周期检查；只扩 native 构造替身，使其报告实际 seed/mode。真实生产 RoomSync、SeedRasterEntry、FirstRasterGate、NativeTravelPlan、RoomCodec 都来自准确源。对象构造、地图生成、像素和真实 Camera 仍是明确替身，不能凭组件称已达到单人加载耗时。

优先审查：空 travelId 无全局旅行编号，因此只绑定已开始的本地事务，并要求 epoch 增长且 barrier 一致；它不是重连/乱序协议改造。随机地图进入/基地返回/缓存重访仍必须运行 scene12 同路径并与 solo 对照；外部真实按键恢复适配另在 recovery-first-raster-native 准备，不能把原 stable() 控制标志当实发按键响应。
