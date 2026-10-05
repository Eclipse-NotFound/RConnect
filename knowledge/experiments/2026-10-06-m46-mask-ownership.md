---
domain: rendering
type: experiments
game-version:
  - "1.02"
confidence: medium
verified: false
discovered-by: RConnect
evidence:
  - kind: runtime-experiment
    summary: "共享 vis/hpbar 的实际遮罩对象与显示树反向引用；只隐藏已归属的孤立遮罩并恢复，记录光晕像素和实际 PNG。"
  - kind: runtime-experiment
    summary: "同生产字节在原遮挡位置通过 108 项 Aura；真实 Q/E、TCP、原生物理和复制角色档通过 186 项 Motion。"
date-updated: 2026-10-06
---

# M46 念力续报与共享显示遮罩的补充证据

本记录接续 `2026-10-06-m46-joint-validation.md`，保留旧红结果；只描述 R2 回交前的修复与验证，发布及总门禁由原 RConnect 会话负责。

## 已确认

- 在未改生产字节的 `91fb453ffe` 和 `3f94367f45`，Session 接收前后观测到同一条旧 `objs.moved.q=true` 续报：原生 Alicorn 抓箱指针 true→false、Box levit 2→1、t_tele -100→-600。旧保护只挡 q=false，续报仍会走解除 NPC 指针的路径。两端 sampleTime 使用各自进程时钟，不能直接相减声称网络延迟。
- 同一 vis/hpbar 被本体和碰撞代理借用，实际产生重复的位图遮罩；用显示树 `.mask` 反向引用排除仍使用的遮罩，再以已观察的 alias 遮罩图形/矩阵/几何签名归属孤立 Shape。`3f94367f45` 只临时隐藏四个归属对象，箱子光晕像素 0→523，随后恢复全部 visible。单个隐藏仍为 0，其他重叠遮罩会继续遮挡。真正 PNG 保留于该运行目录。
- `readGraphicsData` 返回的 BitmapData 对象身份不稳定，不用返回对象的 identity 作为归属依据，也不释放 RV 的 bitmap 存储。
- 咖啡测试原先会抓到地图自带的另一份咖啡。夹具改用唯一数量 997，并断言加入侧发送的稳定物品键等于宿主实际抓握键；原 103 项断言与时间/像素阈值保留。

## 观察到

| 冻结目录 / 执行 | 结果 | 边界 |
| --- | --- | --- |
| final-6 / 91fb453ffe | 98 PASS / 6 FAIL | 生产仍为 0f861…；唯一咖啡身份已正确，NPC 四项和箱/咖啡遮挡各一项仍红。 |
| final-7 / 3f94367f45 | 98 PASS / 6 FAIL | 同生产字节；完成上述可逆四遮罩干预。 |
| final-8 | 编译失败，无 AIR | 缺 DisplayObject 导入；错误日志及冻结源保留。 |
| final-9 / c0ab7db50d | 104 PASS / 0 FAIL | 新 905… 字节；入口位置 241.8/960，无已观察 alias 遮罩，不能单独证明部分视野遮挡分支。FFDec 默认沙箱启动失败，提升权限后在同字节上完成类清单。 |
| final-10 | 驱动编译失败，无 AIR | 测试直接访问 extern 未声明字段；只改诊断为动态 probe，未改生产。 |
| final-11 / 531c0edabc | 108 PASS / 66 FAIL | 原断言和四项回收检查均过；宿主关闭、join 自动重连尝试和连接失败之后，join 出现 66 次匿名 Timer #1009。只确认日志顺序，来源未定，不作绿结果。 |
| final-12 / 16c3ac0b90 | 108 PASS / 0 FAIL，两端 DONE | 同 905…；固定原白块位置 1681.8/320，实际八个同区域遮罩均隐藏，PNG 白块消失，真实主动 leave 后六个代理回收、零可见孤立遮罩。 |
| final-12 / 647fde0dc2 | 186 PASS / 0 FAIL，两端 DONE | 原完整 Motion 与复制角色档；普通 Q/E 抓箱、落地、抓/抛狮鹫、自然抵抗、过期/暂停/接管/离线和真实 damage 松手对照均通过。新 Q 可以从 NPC 抢箱，NPC 原生 AI 推进 83 次、零重新抢回。 |

905…候选为 `0.2.17-dev`，114046 B，SHA256 `90504759317724fc80018f8d30a1390a4f6d70cc15f9cfa98e1707d31d37aa16`，50 个生产 AS 类；编译产物与声明存根、测试类分离。final-9 编译，final-10/11/12 复制相同生产字节。final-10/11 的旧 manifest 来源标签写错为 final-5，实际复制来自 final-9；追加 `candidate-origin-correction.json`，保留旧 manifest。final-12 标签已正确。

## 推测

MirrorMasks 在原生 body 已有 mask 时保存其真实对象；若注册时尚无 mask，只在本体先于代理且有唯一前置同签名孤立 Shape 时认定原生 mask。多个候选时不猜；保留较新第三方显示状态。这个保守恢复策略有源码依据，不能把离线后本体已被删除的测试当成现存本体恢复的完整实测。

## 尚未验证

- final-12 回收 `liveFields=0`，证实代理回收和白块不残留，但未覆盖离线时仍存活的原生本体遮罩恢复；final-11 的两项 liveFields 证据随整体红结果保留。
- final-11 匿名 Timer #1009 未修复：堆栈只有 `MethodInfo-1()`、`Timer/_timerDispatch()`、`Timer/tick()`，未做原版/无驱动对照，不能认定属于 RConnect 生产、游戏/其他模组或测试驱动。完整 66 个原堆栈、发生端和前序标记见 `build/m46/final11-timer-failure-provenance.json`。final-12 调用真实 Session.leave 隔离自动重连分支，未宣称它解决了错误。
- 其余联合回归、SATS/智能武器借用显示资格、完整发布门禁与安装冒烟由原会话继续；本记录不代表已部署。
- 保留敌人原生重量、法力、距离和抵抗规则，不承诺任意角色能无限抓握所有敌人。所有首领、红外专属和密集战斗帧率不由这两组验证概括。
