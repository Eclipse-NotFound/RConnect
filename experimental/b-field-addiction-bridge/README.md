# B 独立药物接口候选

源自 `mods/AddictionSystem/src` 正式 0.1.0，原目录、发布点与游戏文件未改。原 Engine / Catalog / Panel 的数值与规则保持逐字一致。只增加 B 的角色归属、动作转发、确认和保存边界；本目录不是正式部署点。

## 运行接口

`main.getChildByName("AddictionAuthorityAPI").authorityAPI` 提供 `version:1`、`attach(options)`、`validAction(action)`。

`attach` 参数为 `{version:1, session:String, role:"host"|"join", withPlayer:Function, submit:Function, rebindContext:Function}`。同 session / role 重复 attach 返回已有 lease，另一 session 拒绝。宿主调用 `withPlayer(key, room, operation)` 必须安装该角色的原生环境；`rebindContext(key)` 在包装 Pers / Invent 后保存新引用，作用域退出后若返回同角色还须恢复其新引用。

lease 提供：

| 方法 | 契约 |
| --- | --- |
| `register(key:String, unit:Object, epoch:int, profile:Object)` | 仅宿主，key 为 `0` 或 `1`。首次导入该角色 profile；重复绑定保留 Engine 和包装对象；换身体/复活保留该角色最新状态。内部使用 withPlayer 并调用 rebindContext。 |
| `profile()` | 本机人物 `{version:1,state:String|null}`；state 为原 Engine JSON。旧档无状态时按原生 addictions 迁移。 |
| `snapshot(key)` | 宿主指定角色 `{version:1,state:String,notices:Array}`，notice 为 `{serial:uint,text:String}`，最多 32 条；只在正常确认传输。 |
| `present(state)` | 加入侧应用自己已确认的状态和按序去重的消息。不会推进药物时间、扣药、治疗或重算角色参数。 |
| `execute(key,action)` | 宿主在该角色环境重新验证并执行下面三种动作；未知动作或不合法参数返回 false。 |
| `carryState(game)` | 宿主按当前 world.gg 选择角色；加入侧用自己最新确认状态。写入给定 game.triggers 的单个原字段，保留其他触发器。 |
| `detach()` | 清远端 hook。宿主恢复 0 的单人运行；加入侧不把当前宿主地图当新单人世界继续计算，等待原世界重建。未收到确认的失败连接可立即恢复原单人角色。 |

动作统一通过 `submit({addon:"addiction",key:String,args:Array})` 进入 B 原有可靠输入队列：

- `dose`：`[id,count]`，药品必须属于原目录或 detoxin，整数数量 1–1000；宿主另验真实库存、医疗、角色状态与冷却。客户端不能要求自动服药。
- `treat`：`[family]`，必须是原四类成瘾；宿主另验医生菜单、费用和疗程。
- `cancelAuto`：`[]`，仅取消该角色等待中的自动服药。

每个宿主角色各有 Runtime + Engine；仅角色 0 写共享 `game.triggers['addictionsystem.state.v1']`。角色 1 的 JSON 经 profile、character.addons 和个人存档携带。计时仅保留原 `unit.childObjs` 调度，不增加 ENTER_FRAME/第二份联机 tick。加入侧 Panel 只提交动作，并显示宿主确认结果；展开详情每 8 次确认刷新一次，避免重建列表占用每一画面帧。

## 验证边界

独立编译脚本 `build.ps1` 仅读原模组的外部存根与配置，在本目录 build 输出；并检查无原生 Invent/Pers/Unit/PipBuck 类嵌入。编译不是实机资格。未自行运行游戏、部署或改 root 公共驱动。

`tests/BAddictionCases.as` 是给 root 实测入口调用的独立检查，不自行执行：`hostBindings`、`carryIsolation`、`joinReplica`、`rejectedHostActions`、`capture`、`joinDose`。检查直接运行实际 API / 包装对象，不额外推进 native step，不给药、不改存档。

还需 root 覆盖：双方分别服药只扣自己库存；加入侧医生疗程与取消自动服药；两人分房后各自 tick；SATS/菜单暂停时不推进；死亡复活和换图保留各自 state；连接失败恢复原单人；正常离开后读回自己的 JSON；和 FA 同开无副作用。若用相同存档开两人，初始 JSON 完全相同是合法的，不能用“两个 JSON 不同”代替独立对象和定向动作断言。
