---
domain: rendering
type: experiments
game-version: ["1.02"]
confidence: medium
verified: true
discovered-by: RConnect
date-updated: 2026-10-07
evidence:
  - kind: runtime-experiment
    summary: "相同04438276/原9项和5500ms，原发弹夹具8/1且31个真实闪电事件帧均为空；仅改敌人为原生currentWeapon及attack/step后9/0、真实轨迹与画面出现。"
  - kind: decompiled-game-code
    symbol: "fe.weapon.Bullet constructor/step/run; UnitPresentation.observeWeapon; ProjectileVisuals.beamFrame"
---

# 弹道测试不能在原生显示前移除闪电

> 2026-10-07后续核对：本实验之后，0.2.18-dev/04438276已完成14组1648/0、最终旧905负控与正常无驱动eb84c49f11并部署。最新状态见[state/deployment-m46-2026-10-07.md](../../state/deployment-m46-2026-10-07.md)。下文的未部署/待验证语句描述当时阶段，原失败和因果边界保留。


正式ProjectileNetwork `d4efbfe668` 为8 PASS/1 FAIL，加入侧敌人闪电像素0；双方普通枪弹道、枪口及天角兽护盾仍绿，两端DONE。正式候选044382765a2340ce9babe6f3d01eb61197a438f7d1f9ea70262601535714f042，UI17/a569尚未更换。

NativeTestGun.fireAt是普通枪伤害夹具：直接shoot、推进最多5次run，然后loc.remObj。它仅为spring>=2的激光调用step并留在原生链；天角兽闪电实际spring=1。原生Bullet构造时vis.visible=false，step才设置位置/尺度并令图像可见。新闪电同步记录宿主真实显示帧，而该夹具未曾产生这些帧。

只读复制 `projectile-debug-observe-01 / 3d63125cb7` 保持原9项/5500/1000/20000ms，8/1、双方DONE。前3个源弹丸实际spring1、babah=true、in_chain=false、visible=false、stage=false、beamFrame=null；加入真实收到31个visbullightning事件，全部ended=true且frames=[]，记录peak2但可见0。直接证据在序列化前已无显示帧，不用“网络丢包”解释。

对照 `projectile-debug-native-02 / 6ad438b6e2` 保持生产、原地图和原9项/时窗/普通枪路径，仅把敌人阶段换为天角兽原有currentWeapon及Weapon.attack/step。原9项全部绿（host6、join3）；join真实收到1个含显示帧事件、3个可见帧。原生充能/开火条件仍起效，不延长原5500ms去追更多发数。此前LightningSmart27项另覆盖实际原生连续/长飞行及结束时长，不把此3帧当作流畅度证据。

正式测试采用这一原生输入并补“原有alilight武器”前提检查，原9项/时窗保留，普通枪NativeTestGun及所有生产代码不改。改过的Projectile必须新跑；其他8组只在源、实际编译内容和运行输入完全不变时保留旧结果。观察/对照64份输入、driver/harness和实际日志原件留存，57保护不变；58916/36696、34640/24332已独立确认退出。完整门禁仍待完成，不宣称密集战斗或所有敌人弹道都已解决。
