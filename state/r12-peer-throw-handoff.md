# R12：队友念力抛掷撞击伤害个人开关

2026-10-09。本会话为 RConnect (12) / `01a11c5a-4440-7923-a53b-dfe647bb1a1b`。用户请求增加允许队友念力抛掷造成伤害的开关。按接收者个人设置、默认关实现；已向用户说明此默认、撞击范围及开启时使用原版普通小马系数，用户没有另行指定数值。原 RConnect 掌管统一构建、AIR、部署、提交、MEMORY/journal；本会话不代替它。

## 已写源码与接口

- `src/rconnect/core/PeerThrowDamage.as`：独立的受害者本体撞击许可；不注册第二套消息或物理回放。
- `src/rconnect/core/PeerGrip.as`：实例化；before/after 临时系数与恢复；仅已经验证连接、房间键/epoch/term、同一握持 token 的真实 release kick 能激活。普通松手、拒绝、挣脱不激活；新握持与 reset 清理旧投掷归属。异常退出恢复系数。
- `tests/PeerThrowDamageTestDoc.as`：20 个双向场景，原生 actTele、真实 keyAction E、真实玩家 run 与墙碰撞，不以直接调用 arm/damageWall 代替行为。

给共同 UI 的公开接口（均在现有 `mod.peerGrip`）：

```as3
peerGrip.throwDamageAllowed:Boolean
peerGrip.setThrowDamageAllowed(value:Boolean):void
peerGrip.throwDamageActive:Boolean // 专项诊断：本次真实队友投掷归属仍有效
```

Config/HUD/入口与共用验证工具交原 RConnect，本会话没有改这些共享文件。请添加 `Config.DEFAULTS.peerThrowDamage: "0"`，个人设置按钮建议 name `rconnect-throw-damage`，标签“允许队友抛掷伤害我”。可放在抓起/WASD设置旁边，保持现有滚动外框高度。英文 `Teammate throw can hurt me`；俄文 `Урон от броска союзником`。提示须说明各自设置及仅控制本次被队友抛出的撞击。此个人开关独立于宿主的全局枪械/近战友伤策略，不需要广播策略或在加入侧禁用。

已备好具体共享接线补丁 `state/r12-ui-integration.patch`，SHA-256 `f81761dcfb28439207cbb9181cc55f2d4d7dd03f8db57a5a958a4483e10f47f6`。`git apply --check` 对当前共同源通过；**未 apply，没有代改 Config/HUD**。它增加默认值、三语个人按钮/点击、免撞击说明与滚动行位移，不增加外框高度。原会话核对当前基线后可直接应用或手动并入。

## 原版证据与选择

- `fe/unit/UnitPlayer.as:1836–1893`：throwTele 给 Unit 设置 `t_throw=45` 并加入真实冲量；原 M49 的 beforeNativeStep 已把它交给实际角色所有者。
- `fe/unit/Unit.as:176–178`：damWall 默认为0、damWallSpeed为12。`AllData.as:20–24` 的 littlepip 不设置 damwall；普通小马 raider 在 `AllData.as:70` 使用25。
- `Unit.run` 四方向碰撞入口 `:2138,2215,2315,2446` 检查 t_throw>0、对应速度>damWallSpeed 以及 Boolean(damWall)。`damageWall:3992–4039` 先清 t_throw，再在 damWall>0 时调用原生 PHIS 伤害、护甲、受击/眩晕。
- 因此关闭时临时使用 **-1**：碰撞仍进入 damageWall 清理投掷，但不进入伤害/护甲/眩晕分支。若使用0会跳过撞击终止，改变后续飞行行为。开启使用本体已有正系数，原值非正则本次用25；正常速度门槛及护甲减伤仍由原版结算。
- 每一真实游戏步后立即恢复旧系数，不改 invulner/godMode/hp。普通敌人攻击、枪弹、流血和环境伤害仍走原生路径。设置开关可在飞行中改变下一步的许可。
- 房间、连接、角色、死亡、原生 levit 接管、计数异常或写入另一个系数都会清理归属。敌人天角兽/Boss 抛玩家使用 `t_throw=30` 与 `damWall=dam/2`（UnitAlicorn:1233–1234、UnitBossAlicorn:688–689）；恢复采用值比较，避免覆写异源系数。

## 专项验证安排与当前证据

仅完成源码核对、接口核对与 git diff --check。**尚未编译、启动 AIR 或部署，不能标运行通过。** 本会话收到的两次进度发送工具报错，状态以此 handoff 与实际文件为准；最初边界消息已被原会话确认。

专项建议：`PeerThrowDamageTestDoc`、`random_mane`、360秒、关闭自动移动/开火/回血/跟随；新隔离 app 存储、外部 driver 方式沿现有共同编排。入口已由原会话加入 tools/build_effects_driver.py 的选项；请再加入共同候选 required entries/CHECKS，具体由原会话维护。

每一方向包含：关/开、原有正系数关/开、途中撤销/允许、普通松手、原生异源字段接管、reset、共享暂停后恢复。检查真实抬升、单个真实 E 冲量与飞行、撞墙后的生命损失、投掷时普通敌伤仍生效、系数恢复、独立保存；已退休 release 重放不得重激活。异源控制明确为根据原版合同写入30/37的生命周期夹具，**不声称跑了实际天角兽/Boss AI**。悬停与飞行中角色坐标不由夹具推进。

还需共同 PeerGrip、FriendlyFire、HUD、CombatNetwork、CoopPause、RoomCooperation 回归。个人按钮的实际存在/布局、配置重启、死亡/换房/断线与长期真玩由共同候选门禁补充；本专项不冒充硬件按键实测或覆盖所有环境伤害。

源码停写后以另行发送的 SHA-256 为冻结确认；任何修复须先与原会话解除这三个文件的冻结。

当前已停写的三个文件：

| 文件 | SHA-256 |
|---|---|
| PeerThrowDamage.as | `8e375c08409d3a886a55278c9e9410002df05c18956e004d8579ffaceecb0097` |
| PeerGrip.as | `2d44e4b2dabec605ff512ebb3319708b5c76b6e62c489bcca9a95f2ee7d9651b` |
| PeerThrowDamageTestDoc.as | `5cf5b4a8b26c1da47b928066081705bc9198953238a940fe60111e3dd13db116` |

最终停写消息也返回工具错误，随后 read_thread 同样失败。本地交接完整保留。共用编排实际已将 PeerThrowDamageTestDoc 加入 M50 的 CHECKS 与 required（当前300秒）；可按该既定上限先验证，超时时保留失败，检查阶段后决定时长，不能无证据冒充360秒已经运行。
