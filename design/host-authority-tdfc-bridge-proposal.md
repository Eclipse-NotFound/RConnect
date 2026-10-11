# B 架构与 TDFC 的最小协作接口提案

2026-10-11。用户已明确授权必要的 TDFC 接口修改与协调；接口已实施，正在隔离验证，安装版保持原样。实况见 state/host-authority-2026-10-11.md 与 TDFC/state/authority-bridge-2026-10-11.md。

## 已有证据

B 原生炮塔能识别、开火并伤害两名真实玩家。掠夺者使用 TDFC 的独立 ENTER_FRAME：`TdfcRuntime.as` 每次只读一个 `loc.gg`，同一份玩家样本用于所有敌人的感知和执行。`ActionExecutor.apply` 会写 celUnit 并可调用原生 attack。这些调用不由 B 的房间步统一调度。

`build/ab/b1-incoming-tdfc-002` 保留目标/发射/受伤失败：右方掠夺者未锁定加入侧，也未生成弹丸，加入侧 HP 未下降；该轮还存在独立的嵌套负重标记失败，已经修正并另建 017，不能直接把所有失败都归因 TDFC。较早 014 的“窗口内曾锁定”检查不足以排除此问题。

## 需要改什么

给 TDFC 增加可选的主侧驱动入口；没有连接 B 时，继续既有单人入口。

拟定公共接口：

```as3
// TDFC 返回一个会话驱动；所有方法同步完成，不保存 RConnect 的临时作用域。
public static function attachAuthority(owner:Object):Object;

// owner: {session, role, version:1, withPlayer:Function}
// 返回：{version:1, stepRoom:Function, releaseRoom:Function, detach:Function}
// stepRoom(room, players, simulationTick)
// players: [{key, epoch, unit}]；都是主侧自己的原生对象，不来自网络反序列化。
// withPlayer(key, operation) 使用该玩家的属性/背包/房间执行 operation，并保证恢复。
```

1. B 连接后，TDFC 的舞台事件只更新诊断界面；战术更新由主侧房间步调用。加入侧不执行第二份战术。detach 后恢复原来的单人更新，接口被占用或版本不合则拒绝连接，不能同时跑两个入口。
2. 感知与战术状态按房间保存，暂停房不推进计时；普通空房保留记忆直到本次联机结束。B1 先验证一个房间，接口为 B2 的多房集合留入口。
3. 每个敌人对不同玩家保存不同的目击/声音记录。可见、距离与已有目标决定选择；不把另一玩家的已知位置或确认状态冒充当前目标。切换目标不能让旧的掩体/报告坐标跟着错误玩家走。
4. 队友报告附带玩家身份/出生代次/房间身份，接收者只更新对应记录。噪声限幅按玩家保存原值和写入值，不能来回切换单一 PlayerNoise.player 导致互相覆盖。
5. 感知中的原生 look/listen 与最终动作在 withPlayer 内执行；不在作用域外开火。不改 TDFC 的视锥、延迟、听觉误差或战术参数来凑通过。

预期涉及 TdfcRuntime 的可选入口和房间状态、BrainState 的目标记录、PerceptionModel 的报告身份、PlayerNoise 的多玩家原值管理；GameBridge/ActionExecutor 仅做必要接线。RConnect 提供调度、身份和作用域，不复制 TDFC 战术算法。

## 验证与回退

- 精确冻结当前 TDFC 源/构建基线和本提案；新产物先放 RConnect 自有隔离运行副本，不替换 `mods/TDFC/release`。
- 先证明无 B 时仍走一次原入口；B 同房时每敌人每模拟步一次，加入侧零战术步。
- 两玩家轮流可见/遮挡、交换远近、切换目标、枪声与队友报告、嵌套伤害；核对真实弹丸/受击和双方资源，保留失败。
- 进入 B2 后另验后台房、空房暂停、重访和共享暂停；不能用单房绿色宣称多房完成。
- 释放适配器后恢复其写入的敌人字段；A/B 的完整副本互不覆盖。后续正式集成必须重新固定两边公共 TDFC 输入，不把公共修复记成 B 的架构收益。

## 权限边界

用户已授权必要接口和协调，限定先构建隔离测试版；不含无关功能与安装版发布。首次保存本提案所用的单指令临时授权已在成功后撤销，授权表回到空列表；不可复用。原提案中的公共类入口仍保留，另以隐藏的公开 carrier 解决同级 loader 之间的发现问题。
