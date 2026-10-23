# offline1 上的玩家念力光晕修正

目标是修复玩家被队友念力抓起时身体没有光晕。基于当前已安装的 `0.2.24-offline1` / EB365，仅移植准确 recovery-21 已通过的光晕部分，候选版本 `0.2.24-aura1`。加载、击墙、运动与接收实验均不在此产物中；这些问题仍然开放。

## 实现范围

- PeerGrip 发送原生施法颜色与 GlowFilter 参数，接收侧仅接纳有限且合规的参数；使用现有抓取许可、连接身份、令牌和房间边界。在更新及最终显示时补画真实受抓玩家的身体光晕，结束抓取时清理。
- TelekinesisVisuals 识别真实玩家并不在普通物体链中；释放时分别处理颜色与透明度，只恢复仍由本效果持有的值，保留后来出现的本地效果。
- PlayerBodyEffects 在本机真正抓住队友期间让原生抓取控制身体颜色。GameBridge 仅三个调用增加这个判断，保留 offline1 的离线采集优化。

前三类完全来自准确21，GameBridge只改三个参数。`prepare_overlay.py` 对来源做精确校验，`source-manifest.json` 与 `source.diff` 保存实际输入和差异。未增加宿主或其他模组接口，未改用户设置。

## 候选及验证边界

`build/m52/recovery-aura-offline-01/RConnectMod.swf`：`df0fa0e2ca952e77e5132e75d71e73558dc919c7b8cdeba5da05fc9e94dc01e7`，SWF38，186738字节。原overlay构建器已编译通过，22项安装及完整输入未变。

准确21历史结果 d460ff8f14 双侧296/0+295/0和8张目检只作为移植依据。历史使用RV7852，当前安装RV83D8，需要本候选的新双人结果；不会借历史通过直接部署。计划复用原59项颜色/清理组件、16轮PeerGrip和20轮PeerThrowDamage驱动，所有断言、资源保护、独立存储及错误检查保持。

## 本轮实际结果

- `recovery-aura-offline-component-02`：原59项全部通过。01在创建隔离桌面时权限失败，旧证据保留，未运行游戏。
- `recovery-aura-offline-grip-01` / `f871ad9d98`：RV83D8组合，主296/加295，双向16轮完成。根实际打开8张截图，光晕出现、去滤镜对照及释放清理正确，见`visual-review.json`。
- RV会话随后正式更新为6DBA，本会话没有回退它。原驱动/候选再次运行 `recovery-aura-offline-grip-02` / `989013e148`，仍为296+295、零失败。根另开8张本次实际截图并记录`visual-review-current.json`。独立回核见 `../recovery-aura-offline-review/RV6DBA-REVIEW.md`。两次运行和构建的真实环境分别保留，不改写历史指纹。
- `recovery-aura-offline-throw-01` / `3ebf5d73eb`：旧抛掷夹具首轮holding超时，主4/1、加3/1。失败未豁免。只读分析见`../recovery-aura-offline-review/THROW01-DIAGNOSIS.md`。
- 只加观测的新驱动 `recovery-aura-throw-diagnostic-native-01` / `16edfc422f`：前九轮真实抓投运行，第9轮再次抓取失败。原生帧将临时质量上限1000/telemaster1改回0.6/0；真实首hold携带0.6，队友质量1，随后ACK为ineligible。已证明这个旧夹具的能力输入不持久；不能改判先前没有观测的首轮失败。另有round4绝对hp断言失败，正在单独核查。

- 新原生技能/生命夹具 `recovery-aura-throw-fixture-native-01` / `46b56c60e3`：主222/加222、20轮全过。40份准备/结尾最大HP都为10280、器官池760；18次真实敌弹各减40。10个有伤正例碰墙继续损失48.70–120.57，8个禁伤/撤销/reset负例不额外掉血，2次普通放下不武装抛掷且不掉血。旧问题round4和9均在本新运行通过；旧失败不改判。

本候选目前59组件+591光晕+444抓投共1094项通过，根实际检查新组合8图。完整audit01通过；第一次deploy01因工具模块导入路径不足在任何替换前失败，安装仍EB365，原失败已保存。仅补齐与旧部署入口一致的工具搜索路径后audit02再次通过；deploy02已完成正式安装及实际release双人smoke `7d45932e01`，本次只改RC，备份/范围/门禁见 `RELEASE.md`。产品未因测试夹具或部署脚本失败而改动。本结果不表示加载、击墙或运动性能已修好。
