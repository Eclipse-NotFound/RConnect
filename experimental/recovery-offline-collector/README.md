# 离线资格 hook：原生采集执行回退

2026-10-23，仅准备两份源码/说明，未编译、未运行。目标是准确 EB365353…5FEE / `0.2.24-offline1`；根会话负责外部声明SWC构建、测试登记和单实例runner。本驱动不修改产品、其他模组、私有字段或真实配置。

## 为什么这个证据可用

准确提案 `GameBridge.readSnapshot:701` 返回的 `weapons` 是数组；应选择唯一 `main===true` 项，而非访问 `weapons.current`。`UnitPresentation.capture:179` 调用默认 stamp=0 的 `observeWeapon`，可以创建事件和当前弹道描述；但 `observeWeapon:144–157` 仅在 stamp>0 时追加原生显示帧。因此“有事件”或“hook被调用”均不足以证明采集执行，至少两个不同时间、不同位置的 `flight.frames` 才能排除单次读取制造历史。

驱动在 Stage ENTER +100000 施加有限原生输入，在 Stage RENDER -40000（产品最终观察之后）记录实际同一 Bullet.vis 的 x/y。每阶段原生子弹至少三次不同ENTER的可见运动后，仅由驱动读取一次readSnapshot；正例要求两个不同at、不同位置的采集帧，位置均能在独立原生记录中找到。时间不要求与getTimer精确相等。同帧重复RENDER只记一次。读取后的记录立即复制，避免产品后续修改live frames数组污染历史证据。

第六阶段无人HOSTING时，产品Session自己会周期readSnapshot，因此不能声称系统只有一次capture。所有这种capture仍是stamp=0，不能凭空补出多帧历史。选择原生flamer，其flame>0使 `usesNativeFrames` 天然为true；避免HOSTING定时capture先创建recorded=false事件的准备竞争。

## 六个阶段

coverage固定为 `virgin / null / throws / falseValue / truthyString / afterHost`：

1. 保留原生产hook身份且真实Session从未联网。实际子弹已运动三帧，但history frames必须为空。
2. 临时把公开hook设null，实际多帧历史必须存在。
3. hook抛字符串 `RC_COLLECTOR_EXPECTED_SENTINEL`，只在hook内部计数；外围不得出现未捕获异常或游戏错误框。多帧历史仍必须存在。
4. hook返回Boolean false，同样采集。
5. hook返回字符串 `"true"`，验证只有严格Boolean true才允许跳过。
6. 恢复原hook身份，自有ServerSocket.bind(0,localhost)取端口并成功close后，临时设置私有config.port、调用实际startHost；确认实际bound且没有peer。使用新枪核多帧历史，证明首次真实尝试后原生产hook开放采集。最后实际leave，资格仍false。

前五阶段始终不调用startHost/startJoin。原生产hook不包装；只有规定阶段替换公开函数，finally式清理恢复原函数身份。每次替换都会核对象身份，未知替代对象不清理。刻意抛出的哨兵不含通用ERROR关键词，预期抛出也不输出异常日志；计数不能单独使阶段通过。

## 原生输入与保存边界

- 仅接受隔离 `pfe-modsettings-rconnect-coop-host-` 应用ID和空autoRole。沿v3生命周期引导：正常begin稳定后原生gotoLand到rbl，等待land身份、加载结束及五帧稳定。必要继续点击与启动时healAll同原引导；不加载用户存档。
- 一张现有房间，只读选择干燥、无邻近敌人的开阔射线区域，原生setPos/setVisPos定位。没有合适区域即准备失败，不改地形、禁AI、修改子弹或另造房间。
- 原背包weapons映射暂存，使用私有浅副本；每段通过原生 `Invent.addWeapon('flamer',16777215,200)` 创建全新枪，再 `changeWeapon` 装备。原生attack只调用一次，正常Unit链负责weapon.step和Bullet.step；不手动补步、不裸赋currentWeapon、不改速度、寿命、伤害、技能或采集历史。200发为新建测试枪的初始弹匣；原装备对象不用于开火。
- forceRot/findCel仅用于有限瞄准输入。必须检查同一真实武器/子弹/owner/loc身份；弹丸过早消失、无足够运动、额外开火均失败。各段等待自己的子弹正常离链后再开始下一段，最多32条原生样本/段、64条总观察。
- finally式清理恢复原hook、port、原weapons数组、原装备与childObjs身份、原瞄准/位置/按键，并实际leave。没有Config.save，不向外网连接。玩家物理、敌人AI和原生射击在这张私有测试地图上正常运行；不声称回滚了原生世界时间或全部战斗后果。原生弹丸不强删。
- 内部总期限240秒、启动180秒、每阶段15秒，另有250ms看门计时。runner仍须设外部绝对超时并回收自有进程。

## 输出及验收

逐项 `COOP PASS/FAIL offline-collector ...`，最后 `OFFLINE COLLECTOR RESULT {…}` 和 `COOP EFFECTS DONE offline-collector`。成功要求准确候选指纹、version正确、phase=done、passed=true、failed=0、abortReason空、六coverage均true、driverSnapshotCalls=6，以及cleanup的errors空且hookRestored/configRestored/sessionReleased/equipmentRestored均true。

`observations`中六个collector-proof必须保留真实native点、产品frames、匹配的不同时间位置对数、每段驱动快照次数、hook实际调用/throw次数和产品可能自行capture的说明。仅有布尔绿灯不够。

`collectorExecutionQualified`只指“真实玩家弹丸帧历史在这些hook分支下的采集/跳过行为”；不证明全部body effects、双人握手、对侧最终视觉或性能。尚未执行，不能预先宣称这些断言通过。
