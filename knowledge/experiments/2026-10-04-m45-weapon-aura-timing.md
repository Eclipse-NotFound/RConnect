---
domain: rendering
type: experiments
game-version: ["1.02"]
confidence: high
verified: true
discovered-by: RConnect
date-updated: 2026-10-04
evidence:
  - kind: runtime-experiment
    summary: "同一光晕驱动对照：旧候选宿主485帧出现9次武器/光晕错配；修复候选宿主485帧、加入侧450帧均零错配，102项通过。"
  - kind: decompiled-game-code
    symbol: "fe.unit.Unit.step; fe.unit.UnitPon.setWeaponPos; fe.weapon.Weapon.step/actions"
---

# M45 换枪光晕时序与验证夹具

## 失败与调查

M45第二次冻结产物为110625字节，SHA256 `e9b626fdf2454d2b4869917a13cd245b82e47ec6912801e665bfb9a99f755f02`。慢换图、暂停、抓敌、分房共747项已过，但光晕`c1708bce4a`为82 PASS/2 FAIL：宿主首轮武器像素为0、换枪颜色仅10/12符合。部署停止，后续五组未执行。旧冻结完整保存在`build/m45/final-before-weapon-state`。

只加日志的`cd930fbc47`显示，一部分错误颜色采样早于新武器包；另一部分在新assr包到达后，其kor子对象仍没有光晕。该轮还出现Timer读取物品染色不符、最终未完整结束，不能据此将失败归为无害抖动。

`4a95148405`增加最终RENDER观测，按ENTER_FRAME去重，同时保存两端场景PNG。运行使用初版诊断SWF，SHA256 `c3562121ee818ccef84a658fd8ef29eb099a1656284962a1c553add0ba88918f`；其源由`build/m45/build_telek_render_diag.py`生成。后来追加identity诊断的源编译失败，**没有进入该轮SWF**，不把它当成引用身份的证据。

实际查看截图后，宿主首两轮整个游戏场景为黑色，仅保留原生开场文字与HUD；加入侧已显示房间。该轮宿主首轮10个最终帧光晕参数正确，但像素均0，不能解释成单个武器消失。宿主换枪时还记录到独立问题：新assr包已到，最终RENDER有1帧kor光晕缺失，随后7帧正常。截图及指纹在`build/m45/telek-render-diag/evidence`。本轮Timer物品染色仍有一次不符，未记录最终RENDER物品染色，因此不认定它已证明产品缺陷。

## 产品原因与修复

GameBridge原先在收到最新玩家包后调用syncRemoteWeapon，立即更换武器实体；driveGhost却使用RemoteMotion延迟播放的快照驱动位置和光晕。于是新assr显示对象能暂时收到上一把lmg的aura.kor=false，旧颜色涂在根对象上，而真正的kor没有光晕。

现将syncRemoteWeapon移入driveGhost，与driveWeaponVis共用同一个播放快照。没有增加网络包、改念力伤害或重写滤镜；只是让武器身份与其光晕在同一帧生效。

## 测试修正与红绿对照

- 原夹具在开场尚未结束时就冻结玩家，且新建武器后没有运行原生瞄准。Unit.step遇disabled立即返回，不会推进子武器；Weapon构造只setNull/animate，不计算rot，因此原日志持续rot:null和旧weaponX偏移有明确来源。
- 新夹具等待两端原生开场/复活动作和黑幕结束，再冻结位置。通过celX/celY、setWeaponPos和Weapon.step生成真实武器姿态，不直接写角度或滤镜。
- 原先从本机startRound之前计固定1.5秒，可能把对端重绘、排队和网络到达也当作显示收敛期。现从收到符合本轮武器/颜色的源数据后开始同样的有界等待，**不等待目标滤镜正确才开始计数**。
- 稳态检查改到最终RENDER并按ENTER_FRAME去重；保留原84项颜色、像素、物品染色、松手/换枪/离线清理等断言。另加16项原生角度有限检查和两端全过程武器/光晕配对检查；后者包括等待期间，以免稳态等待掩盖换枪闪烁。
- `84cab910a8`首次使用180秒窗口，原生开场较慢，仅跑到round1就到runner期限；原始日志保留，不能算有效的功能红例。后续改为360秒总期限，未放宽行为断言。
- **红验`c64816fd73`**：同旧e9b候选、新驱动完整结束，101 PASS/1 FAIL。宿主485帧中9次assr根对象带旧lmg色而kor为空；加入侧460帧零错配。原84项均通过，首轮宿主/加入侧可见光晕像素1488/1016。
- **绿验`e2bdb8a864`**：相同测试源码，修复候选102 PASS/0 FAIL。宿主485帧、加入侧450帧均零错配；首轮像素1488/1029。各次托举物染色与原生源一致，清理和无关滤镜保留检查均通过。测试PID50232/45712已退出。

修复产物110626字节，SHA256 `59a03d1eb3ca7d8467015c709301bc1fbe6d585342de5857e984344a33572790`，48个生产类。将通过绿验的原字节直接冻结到`build/m45/final`，没有重新编译替换成不同产物；49个源文件、121个验证输入留存。其余九组回归在这份新冻结上重跑，最终结果及部署状态以`m45-validation-evidence.json`和部署记录为准。

本调查不证明所有用户动画卡顿已修复，也不把开场夹具黑幕归因于联机暂停。两个暂停开关在光晕专项始终关闭。
