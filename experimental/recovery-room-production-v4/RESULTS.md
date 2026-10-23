# roomfix4 当前验证范围

2026-10-24，未部署。准确产品 `build/m52/recovery-room-production-04/RConnectMod.swf`：`34a17de66e9a89165b4bde75d22ec1dd3d4295bb496b903124687af80422b703`，195145 字节。

## 已完成

- 在旧宿主 80CF / RV 0DBE 下编译成功，prepared `093916cf37eb1502fbc3b63f88da208d680e8314a4903840807fc0e09a775807`，compile `3cde928e206d5083ea826c8b62b05ad206ea2ad311e2c2e0875ae7e2e994e370`。没有改写编译环境为后来的 ABE2。
- 新旧真实 RoomCodec 211 项组件通过：交叉解码、完整地块标量表、墙面、协议字节保留，删除同步文件诊断。`recovery-room-production-clean-component-01`。
- 当前 ABE2 / RV 0DBE 的真实 BF6 房间回归 `0de27b7e59`，`recovery-room-candidate-entry-04`：主 25、加 53 检查通过。原生死亡/HP/弹药/破墙/容器/唯一掉落/未移动同伴等保留。原结果 SHA `e172e40af4200231831ad009f84989c7efe61f4be0e975f6e6c479b1ec00f93d`。
- 根会话实际目检 run 根目录 `host-presentation-room-entry-waiting.png` 和 `join-presentation-room-entry-waiting.png`：双方均显示原生绿色 Loading 动画，无定制“房间交接中”文案或未解析的资源标记。测试语言为英文，不把截图称为中文显示证据。

## 未完成

不授予加载速度/密集性能资格。roomfix3 历史同组合大图加入侧 15.675/2.844/7.711 秒仍慢于单人 7.518/1.916/3.571 秒；v4 没有据此被改判。

当前 ABE2 / RV 0DBE 的原生单人基准已完成：`8d4cf6e1db` / `recovery-room-scene-solo-current-host-02`，大图首次/基地/重访为 7.222/2.115/2.980 秒，原三程通过。先前 solo-01 在 AIR 启动前被沙箱拒绝私有 AppData 写入，保留失败；solo-02 沿已授权范围升级权限后完成。

最新密集旧574D对正式aura1都不合格，见 `../recovery-room-density-review/RESULTS.md`；它们没有测试 roomfix4，不能借为本候选无倒退证明。双人有界耗时计数已编、暂因内存不足未启动，见 `../recovery-room-loading-counters/RESULTS.md`。

正式安装仍 DF0F/aura1。目标未达到，不因遮罩和状态检查通过就覆盖安装版。
