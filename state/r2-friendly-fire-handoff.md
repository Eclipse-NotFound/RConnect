# R2：允许队友伤害开关（M50 合并项）

2026-10-09。用户请求增加“允许队友伤害”开关；已向用户说明默认关闭、宿主设置并同步双方。此默认与控制权是沿用现有全局联机设置的实现选择，不记录成用户另行确认。原 RConnect 会话负责共同候选的编译、自动检查、部署、MEMORY/journal 和提交；R2 尚未构建或启动 AIR。

最新接续：原会话的 `build/m50/probe-peer-01` 已成功编译生产候选；FriendlyFire 外部测试曾因访问私有 `Session.stop()` 编译失败。按原会话单文件窗口，R2 改为公开 `leave()`，保留原会话添加的 finish 空 world 守卫，修正版 SHA256 `be650d2526d4bec60d903470f5d1ee207735135c06dc2f8461f7e7e4fb6e2168` 已发回并停止源码编辑。随后只读确认 `probe-peer-02/FriendlyFireTestDoc-build.log` 已产生 driver/harness，专项编译通过；尚未取得 FriendlyFire 双端运行结果，未部署。原失败副本保留。向统一会话发送此最新状态连续两次报 Codex app tool request failed，wait_threads 同样不可用；不能把未成功送达的消息当已收到。此前源与测试清单、修正 hash 已成功交接。后续由原会话继续统一运行、门禁、部署和本地提交；取得实际结果后再更新用户状态。

## 实现

- `FriendlyFire` 保存宿主 `friendlyFire` 选择，500ms 策略重发，点击立即发送；加入侧只读，不覆盖其离线预设。连接身份、策略代次、房间键/epoch/term、单调命中序号均检查。
- `PeerHitUnit` 只进入同房 `loc.units`，不进入模拟链或显示树，不进 SATS/敌人AI/地雷触发/念力选取。它使用队友化身的形状、闪避和抗性透明判定；普通原生子弹/近战弹先做原版几何命中，再将原始命中传给受害方 `NativeHit` → 原生 `UnitPlayer.damage`，护甲和生命只结算一次。
- 原 `RemoteDamageUnit` 用 `dopTest`/`udarBullet` 排除本地玩家及其武器来源的子弹，以免原生定向爆压同时击中化身与友伤代理。敌人弹和无来源的世界伤害保持原有链路。
- 关开关、换房、死亡、共享暂停、断线时停止接受新友伤并摘代理；重开产生新策略代次，旧命中不能重放。
- 设置页增加宿主开关、说明；保持外框高度，友伤行、说明、版本行随换行动态布局。

## 验证入口和当前证据

`FriendlyFireTestDoc`：双向各七场景（关/原生轻机枪/近战弹碰撞/激光伤害类型/原生 explosion/重复及错房包/开后关闭），每场景双方完成后才进入下一场景。核对原生受害者伤害参照与真实生命损失、爆压一发只结算一次、宿主保存、加入不能改设置；结尾断线检查代理退出；每端输出 `friendly-fire-settings.png`。输出前缀 `COOP PASS/FAIL friendly-fire` 与 `COOP EFFECTS DONE friendly-fire`。当前只有静态查验，不能标运行通过。

建议专项配置：`random_mane`、实际双方角色模板，关闭自动移动/攻击/回血/跟随，沿用现有隔离外部 driver；还需既有 CombatNetwork、GameplayNetwork、PeerGrip、HUD 和 RoomCooperation 回归。该测试不声称实际每一件近战或激光武器已穷举：除轻机枪外测试原生 Bullet 对应碰撞/伤害路径。

## 已知范围

原版 `Bullet.explGas` 直接调用 `damage(amount,type)`，不携带攻击者；玩家地雷也不记录原玩家对象，念力箱的阵营不足以区分两个玩家。这些间接/环境伤害尚未纳入友伤开关，不能宣传为所有间接伤害均已识别。常规玩家弹、近战弹、激光弹和有来源的爆压走本开关；原版自伤规则仍由实际本地玩家处理。

文件范围：新增 `src/rconnect/core/FriendlyFire.as`、`src/rconnect/game/PeerHitUnit.as`、`tests/FriendlyFireTestDoc.as`；修改 `src/rconnect/game/RemoteDamageUnit.as`、`src/RConnectMod.as` 接线、`src/rconnect/core/Config.as` 默认值、`src/rconnect/ui/NetHud.as` 控件和布局。没有改版本、release、GB/Session或验证编排。Unit编译存根新增两项原生方法声明由原 RConnect 会话负责。
