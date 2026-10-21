# recovery11 单位构造与对象恢复：窄审阅

2026-10-22，只读；未改候选、未运行编译/游戏。核对冻结 `build/m52/recovery-11/src`，SWF SHA-256 `cd721f0e56679302747ab2c9e687e20bd877a1ee8f520d6d589c7c43fa64ebb5`。GameBridge SHA仍为 `e1cd085795e134ca293a5eb83fe44e22a0bc7edfb172f960a2c6a1e8bdec9260`，与09一致。

**没有发现可直接消掉136单位构造主要耗时、同时保持构造副作用及顺序的局部捷径。唯一明确的无用工作是对象恢复前建立了一个从未使用的id索引；收益未测，预计不应作为新的加载优化主线。**

最有依据的一处：`GameBridge.reconcileObjs:2989–3006` 新建 `byId={}`，遍历整个loc.objs，通过 `probe(b,"id")` 填表；随后直到方法结束（3120）再未读取该表。实际匹配始终调用 `_objects.resolve(h,objs,consumed)`，下一阶段 `restoreCheckpoint:6244–6253`又按对象键恢复runtime/inter。删掉无用byId建表不会省略对象匹配、构造、die/setAct、运行时字段或交互状态恢复，也不调换这些调用。

安全范围：原生 `Location.createObj:1980–2004`将Box放入objs，`Box.as:30`的id是普通public String变量，所以这里的原生id读取无getter副作用。若要求覆盖其它模组注入的非Box对象/Proxy，必须保留未知对象原读取语义或先证实对象类型；不能仅凭“表没有使用”宣称任意动态getter也可删除。本次没有扩大检查外模组，也没有实施该删除。诊断未单列这一遍扫描，不能把对象恢复208ms归因于它。

构造主段的核对边界：

- `restoreCheckpoint:6259–6284`在foreign路径移除旧单位，按checkpoint顺序各构造一次、putLoc/addObj/bind，再restoreUnit。不是同一restore循环把每个单位构造两次。旧诊断435–505ms/136次为冻结07证据；11路径相同，但本轮没有11新的构造计时。
- `NativeRoomState.restoreUnit:73–91`已经复用构造所得、slot/id/variant相符的武器，只在不符时create。旧诊断91把武器仅新建28把，不能以“构造后又恢复武器”为由跳过整个步骤。
- 原生Unit构造会建立Interact/effects/显示及子类对象，并消费原生随机选择（`Unit.as:578`起，未给turn时调用isrnd）。checkpoint只保存标量/原始数组及选定internal字段，刻意不保存显示、目标和链表引用（NativeRoomState类说明及scalars）。直接复用上一份原生单位、跳过子类构造或改变构造顺序，不能由最终hp/坐标相同证明等价。
- `reconcileObjs → runtime/inter restore`两段也不能整体当重复删掉：前段调用原生die/setAct等完成图像、门瓦片和交互变化；后段恢复动画进度、内部计时、save字段等。当前证据不足以把两段合成“只复制最终字段”。

结论：保留原单位构造与对象恢复主链。无用byId扫描仅登记为小型清理机会，不据此再造候选/框架或声称可显著缩短加载。
