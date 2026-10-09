---
domain: rendering
type: experiments
game-version: ["1.02"]
confidence: medium
verified: false
discovered-by: RConnect
date-updated: 2026-10-09
evidence:
  - kind: decompiled-game-code
    symbol: "fe.weapon.Weapon.shoot; fe.weapon.Bullet.step/popadalo; AllData.d.weapon; visbulflame/visbulflame2/visbuldflame"
  - kind: source-inspection
    symbol: "rconnect.game.ProjectileVisuals; rconnect.game.UnitPresentation; FlameVisualTestDoc"
---

# M50 火焰弹体原生轨迹与独立验证输入

## 已确认

1.02 源码中的普通 `flamer` 设置 `flame=1`。Weapon.shoot 给新生弹体加上随机负向 ddy、180–220 的 brakeR 与 brakeR/7 的 liv。Bullet.step 超过制动距离后将 dx、dy、vel 每步乘0.9，打开 vRot 并以当前速度重新计算旋转。这条路径既非匀速，也非固定朝向。

`cflamer` 未设置 flame，使用 grav=1，因此依靠原生重力和 vRot 改变轨迹/朝向。其原始型与改进型分别使用 visbulflame、visbulflame2；相应参数不同，不能靠普通 flamer 的属性推导。visbulflame、visbulflame2 与 visbuldflame 的剪辑均在第31帧停止。

普通 Bullet 的 flare 在 popadalo 命中分支发出独立 Part；此处未发现每个飞行步生成 flame 粒子的路径。因此不会为修正火焰弹体而添加凭空的飞行尾焰。命中 Part 与持续燃烧状态由各自的同步模块处理。

已部署21的 ProjectileVisuals 由 begx/begy 与采样时当前 dx/dy 推算轨迹、固定 rot，并采用简化结束过程。原 RConnect 会话在M50共享入口加入原生弹体帧回放：玩家全部弹体以及敌人的 flame 与上述火焰剪辑使用原生显示帧。这里描述实际源码差异，尚非运行通过结论。

## 观察到

用户确认对侧火焰“方向、位置或长度不对”，未指定单向或双向。RConnect (7) 本轮尚未启动AIR或部署；没有本轮运行日志可以证明症状已消失。

## 推测

旧固定轨迹没有保留原生减速、旋转、动画尺寸和结束时刻，足以产生所述偏差；需要已部署21负控与同一原生输入的新候选对照来验证。既有普通子弹测试的成功不能证明火焰家族正确。

## 尚未验证

独立 [FlameVisualTestDoc](../../tests/FlameVisualTestDoc.as) 已准备9轮18方向：flamer0、cflamer0/1，各向左、向右与斜上方发射短连发，双方均为真实 Weapon.attack/step 和 Bullet.step。测试不修改弹体速度、重力、制动、生命或碰撞。

每颗原生 Bullet 从原生对象链独立记录，远端只观察最终RENDER中的非原生火焰剪辑；一条远端显示对象的完整轨迹只能匹配一个原生弹体，使用全局一对一配对防止重复计数和混用源。动画帧须相同，位置/旋转/缩放/透明度/局部边界联合误差不超过0.08；兼容相邻原生帧之间的插值。每弹可见时长偏差限180ms，另检查实际显示像素、原生刹车/转向前提与清尾，保留每端18张活动/清理PNG。

本会话2026-10-09最终测试输入 SHA256 为 `95f41fe617c5922c353749f80258060ca34988bc18d6f76eaf168729f98de17a`。源码静态分隔符/9个场景/无Bullet物理字段赋值检查通过，尚未经过AS3编译。按原会话同意，观察字典对一轮内的真实Bullet强持有，防止原生出链后垃圾回收使夹具漏记end；下一轮替换字典释放，不改变原生模拟或检查阈值。旧probe输入不改。

编译、旧21负控、新候选运行、图片审查与部署均由原「RConnect」会话统一完成。实测runID须以该会话回执补记；此记录不能作为发布门禁通过证据。本会话不改共享源、工具、版本或release，也不自行提交整棵并发工作树。MEMORY/journal由原会话统一接续本记录，避免并发重写。
