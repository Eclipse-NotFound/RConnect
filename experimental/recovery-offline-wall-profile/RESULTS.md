# 墙面采集计时：执行记录

2026-10-23，根以准确 EB365 和已冻结两类覆盖，通过共享登记实际编译 `build/m52/recovery-offline-wall-profile-01`。版本 `0.2.24-wallprof1`，187570 bytes，SHA256 `19ff54a4c130fe645472a169c930759afd6c419dc80dadf03f63cbd0a6e83fcf`。

两次 JVM 退出0且已回收，所有来源/输出源码和22项安装核对通过。只增加 opt-in 聚合计时，不启动游戏或部署。完整构建回执为该目录 compile.json；复核入口 `experimental/recovery-isolated-overlay/build.py --verify --output build/m52/recovery-offline-wall-profile-01`。

准确产物及接口已发送给获授权的“大场景”会话，供其现有1200帧负载使用。

## 已返回的真实采样

CS 的 `knowledge/experiments/evidence/dense-rc-wall-20261023-scene-r1` 使用准确19FF和BEFC。根回读 summary.json、storage/result.json、diagnostic-rc.json：1200连续帧、原生奔跑和开火，26项全部通过；结束时探针关闭、重复stop结果稳定。隔离输入清单中的RConnect为19FF，不是正式安装被改写。

四个300帧窗口，早帧before与晚帧observe的外层耗时合计分别为0.4633、0.4500、0.3700、0.4067 ms/帧。每窗两外层各300次；包含observe内层before后before总600次。没有重建/克隆/格扫描/格比较，objectChainVisited约318455–320985次/窗。两外层可加，不能再叠加嵌套before。结论限于稳定场景：该采集不是此前约20ms差额的主要来源，因此不为此关掉离线墙痕历史。未测冷入图和重建，不授予双人、全显示配置或生产性能资格。

本轮采用6名高血量原生LMG敌人的持续交火夹具，玩家assr；保留原生开火/装填/输入，玩家补弹、无敌和敌方低伤用于持续采样。240×125地图，视野/灯光/WallBlend显示关闭，计时探针自身有开销。平均帧间隔56.9708ms、P95 76ms只是本轮观测，未做对应成对基线，不能解释为本候选带来的提升。

回读指纹：summary `404b2e38a63e34f4fc7f614d0ac52cbd71194f661d680f25aed0f1817a14f7f8`；storage/result `03e3d1464dde33f6779e68ee2eeaf3457a0c5cca8f9db96b39dec7a9a3d9661d`；diagnostic-rc `504e13ea99b3af832e6b96e607e56fcae196af20c31f8618dc50fb215c14969b`；inputs `2cfe7e214cabc2711984349f364874cc47c57fee14fb42dbc2bd7748c0b5e3b8`。原报告保留在来源模组，无需复制其整套资料。
