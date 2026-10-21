# 撞墙命中特效同步修正

负责：RConnect (5)，会话 `01a151ba-c524-70b1-b544-a5cf605efecb`。原 RConnect 会话 `01a086bb-378c-7f60-b8e1-50d90ffa0996` 统一合并、验证与部署；本记录独立维护，避免覆盖共用 MEMORY/journal。

## 当前停点

- 用户要求全面检查子弹撞墙火星等动画在对侧不可见。修正已实现并编译，**尚未通过完整游戏测试，未部署**。
- 当前准确候选：`build/m52/wall-impact-02/RConnectMod.swf`，版本 `0.2.24-wall-impact2`，SHA256 `07a7fa1399afcc34840cc04467f9888f3dfcb7d78af3338b1e66d1f51aa483f7`。
- 基于实际安装冻结源 `build/m52/coop-bundle-04`，安装 SWF SHA `574d2b51490ae8b25a1396555600f56a301f8a20ae50104c0e35cf2796441afe`。不使用历史根 src，不混入房间加载、光晕或运动连续性 WIP。
- 稀疏覆盖源：`experimental/wall-impact-effects/src`。候选02生产字节与当前覆盖源匹配；`prepared.json` 保留每文件指纹及外置驱动。
- 微型 AIR 组件 `build/m52/wall-impact-checks-02`：**32 PASS / 0 FAIL**，实际生产 `ImpactEventQueue`、`BallisticImpactVisuals`、`EnergyImpactVisuals` 原字节。原生 Part/Bullet/Emitter 仅为显式数据与调用边界替身，未加载游戏，不算网络或原生渲染通过。
- 两次双实例对照均在启动前被6 GiB可提交内存门槛拒绝，**没有启动测试AIR，不能计作旧版缺陷实测复现**。证据：候选01/02各自 `baseline-ballistic.json`、`.log`。用户已选择“释放内存后继续实测”，尚未收到释放完成的明确回复；不降门槛、不关闭用户进程、不反复启动。
- 本轮只在组件测试中启动过自有隐藏 AIR，已退出并登记结束。完整游戏安装22项输入前后无变化。测试没有写 release/真实存档，运行器自动回收冗余游戏副本。

## 机制与缺口

1. 原版 `fe.weapon.Bullet.popadalo` 在材质1/2/5/7产生 `iskr_bul`，额外按武器flare产生对应短动画。到期、部分软材质与未命中不会产生这组火星。
2. 当前安装源没有历史 `BallisticImpactVisuals`，只保留永久墙痕 `WallImpactVisuals` 和部分静止能量闪光 `EnergyImpactVisuals`。墙面贴痕不等于火星粒子，不能用墙痕已同步证明命中动画已同步。
3. 普通NPC弹不录逐帧轨迹，旧代码按出生700ms清记录；较慢或较远的弹到墙时记录可能已消失。
4. 能量闪光白名单未包含火焰漂移粒子，以及原生酸滴/特殊钝击类flare。`visualFlame` 原生有随机位置和速度，不能使用静止能量闪光的0.01像素匹配条件。
5. `PhisBullet.popadalo` 覆盖原方法，只处理爆炸/结束，没有普通Bullet的flare发射；不能因配置写有flare就虚构一段原版未实际生成的动画。爆炸继续沿已有 `ProjectileExplosionVisuals`，未重写伤害或地形逻辑。

机制来源：`game-reference/decompiled/1.02/src102/scripts/fe/weapon/Bullet.as`（popadalo/run/explVis）、`PhisBullet.as`、`fe/AllData.as`（part表）、`fe/graph/Emitter.as`、`Part.as`。这些是源码证据；尚无本轮双实例像素结论。

## 实现

- `BallisticImpactVisuals` 从历史实现窄移植：必须找到本帧真正生成、位置和类型匹配的原生Part，记录数量、位置与方向。普通火星与原生血色粒子使用原生纯视觉Emitter回放，不创建第二个伤害Bullet、不调用碰撞/伤害/破墙。重叠弹丸超过50个粒子时分组，防止Emitter单次上限截断。
- `ImpactEventQueue` 单独保管命中序号，避免弹体已退场、旧弹命中晚于新弹、重复快照造成漏放或重放。沿用角色播放时钟；暂停、换房、断开重置和过期清理有界。
- `UnitPresentation` 在recorded分支之前采集命中，覆盖普通NPC弹；普通NPC弹存活时不按700ms出生期限删除，结束后从实际命中/出生窗口退役，不新增对endSentAt的依赖。既有离线recorded记录滞留是独立问题，未宣称解决。
- `ProjectileVisuals` 只增加receive/tick/pause/reset接线，**未修改tickBeam**；与主会话motion2的曲线/闪电改动可精确合并。
- `EnergyImpactVisuals` 补全相关flare映射，移动火苗只认附近新生Part、每弹认领一次，随后回放其实际位置/透明度/动画帧。旧火苗、未撞击的弹或远处粒子不构成新命中证据。

## 已做验证与边界

- 两版生产和外置驱动均成功编译。候选01为 `579cf1864e7aa3b9d923956b342232634c666413accf64899853ed13cffbc233`，没有后续火苗/长飞行修正，不能作为最终部署对象。
- 组件01为18/0；组件02扩展到32/0。验证重复100次消息、旧弹晚到、不同武器流、200个密集命中、源时钟暂停/恢复、换房/重置、过期、不认识的配方/无效坐标、Part唯一认领、73个重叠粒子、真实位置保留、火苗漂移与退役等。
- 组件不衡量游戏帧率，不证明网络输入路径、当前全模组组合、原生艺术资源或最终屏幕像素合格。
- 已冻结43个原生双侧场景：普通14个（轻机枪、自动步枪、散弹、NPC普通弹、刻意降低枪速的长飞行边界、12发连续射击、未命中到期、肉体命中）；能量15个（激光/等离子、速射等离子12发、NPC闪电、战斗喷火器、未命中到期）；魔法14个（telebul/mbul/ice/lightning/mray/dray/skybolt双向）。长飞行明确是测试夹具改枪速，不能描述为原武器默认速度实测。
- 原生驱动沿原 `EnergyImpactTestDoc` 的真实Weapon.attack/step、Bullet碰撞、生产TCP与最终画面像素差分路径；不直接调用命中同步私有方法。普通火星驱动移除了无关的历史运动插值组件调用，仅限定测试范围，未放宽命中数量/位置/像素/伤害约束。代表场景会保存 `presentation-impact-*.png`，实测后还需目检。
- 特殊投掷物、爆炸、材质差异、换枪收尾及全模组组合仍需补原生回归；不能用本轮43个尚未运行的用例声称这些已通过。

## 继续步骤

1. 用户释放内存后读取即时可提交余量，至少6 GiB再跑双实例；共享登记自动排队。先同一驱动跑安装冻结版与候选的普通弹对照，保留全部失败，随后能量、魔法和完整模组组合。
2. 使用：`python -B -X utf8 tools/validation/run_wall_impact.py build/m52/wall-impact-02 --suite WallBallisticTestDoc --label <新唯一标签> [--control] [--all-mods] --registry-wait 900`。能量/魔法替换suite为 `WallEnergyTestDoc` / `WallMagicTestDoc`。工具链Python绝对路径见MEMORY；PowerShell login:false。独立后台桌面可能需当前客户端的执行提升权限。
3. 每轮读取实际输出日志、所有模组私有日志、结束标记、运行时资源指纹和图片；未过不能部署。若时间/夹具失败，明确归因后新目录重测，原失败保留。
4. 查验低速NPC确实超过700ms仍传命中，持续开火停止后普通记录回落、无命中不造火星、换房清理；补材质/爆炸/特殊弹药观察。有缺口继续改覆盖层，再生成新冻结候选，不能改候选02字节。
5. 把准确增量及回执交主会话精确合并motion等改动，再对最终字节运行发布门禁；本会话不覆盖其统一部署职责。

构建入口：`tools/validation/prepare_wall_impact.py <build/m52/新目录> --version <新版本> --registry-wait 300`。组件入口：`tools/validation/run_wall_impact_checks.py <build/m52/新目录> --source <冻结候选>/src --registry-wait 300`。
