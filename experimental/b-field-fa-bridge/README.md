# FirearmAttachments 0.3.5 的 B 独立桥

当前状态：源码与候选已编译；未运行游戏、未部署。正式 FA 目录与其 0.4.0 开发源码未改动。

## 版本依据

- 正式部署记录：`mods/FirearmAttachments/state/keybind-deployment-2026-10-15.md`。
- 对应源码：FA git `8d570a918a8f316988f7f54018471348b23d1927`，正式版本 0.3.5。
- 正式 SWF：`b3304596eb7e08796f9de2cf02e1e7cccff10e188d26fedfa960aa6370d2a4b9`。
- 复制的原始文件指纹见 `upstream.json`；未采用 FA 当前未部署的 0.4.0。
- 当前候选：`build/ab/fa-b-bridge-04/FirearmAttachmentsMod.swf`，版本 `0.3.5-b1`。
- 候选 SHA256：`75b8f76067bfe17fc2324469f067923332af1a50fac7447a7d09dcf5b247226c`。
- 对应 `build-input.json` 保留构建命令、精确源码指纹，明确 `tested:false,deployed:false`。01/02/03 为被后续源码取代的编译记录，不作最终候选。

## 接入契约

`main.getChildByName("FAAuthorityAPI").authorityAPI` 提供 `{version:1,attach,validAction,validInput}`。B 环境必须用此独立 SWF 替换同一实例中的正式 FA SWF，不能同时加载两份。

`attach({version:1,role,session,withPlayer,submit,rebindContext,allowHarm})` 返回：

| 接口 | 职责 |
|---|---|
| `register(key,unit,epoch,profile)` | 宿主登记两名真实玩家；相同 unit/epoch 重入无效果，新 epoch 沿用该玩家配置。 |
| `profile()` | 本机角色的配件与个人 FA 设置，交 B 握手传送。 |
| `input()` | `{overlay:Boolean,settings:Object}`，改装台打开时由 B 屏蔽本机行动输入；设置在宿主按玩家独立应用。 |
| `beforePlayer(key,unit,epoch,input)` / `afterPlayer(key)` | 只能在正确玩家的原生环境内成对调用；B 负责调度，FA 不再依靠帧监听重复执行。 |
| `execute(key,action)` | 在对应玩家环境执行允许的操作；仍由原版 FA 检查持有武器、冷却与物资。 |
| `snapshot(key)` / `present(state)` | 宿主返回配件、模式、冷却、反馈；加入侧只更新显示状态。 |
| `carryState(game)` | 将当前玩家的配件写入明确指定的个人保存对象，避免 `world.game` 引用共享导致串档。 |
| `detach()` | 宿主丢弃远端 headless 运行器，前台恢复正式 FA 的本机循环。必须在 B 已恢复本机角色之后调用。 |

`withPlayer(key,room,operation)` 由 B 实现真实玩家作用域。`submit(action)` 必须进入 B 的可靠动作队列，不能在客户端直接执行。`allowHarm(source,target)` 仅决定玩家刺刀目标是否允许；实际伤害仍走原生 `target.damage`，保留 B 伤害/时停钩子。

动作格式固定 `{addon:"fa",key:String,args:Array}`：

- `modify`：`[gunId,assembly]`，重新校验枪型和轨道合法性；不接受客户端重置冷却。
- `grenade`、`bayonet`、`bipod`、`optic`、`grenadeMode`、`leaveGrenadeMode`：空参数。

宿主 actor 0 复用已有前台运行器及其原始武器参数缓存，避免把已加过配件的参数再次当作基础值。actor 1 使用独立无界面运行器，配件、支架、接触冷却、榴弹冷却与个人数值互不共用。加入侧保留 UI 和快捷键，但不推进战斗。B 用 `world.onPause=true` 冻结加入端原生循环，因此仅加入端前台输入忽略这一冻结标志；宿主执行仍遵守原暂停条件。

配件绘图仍挂到真实武器显示树上，由 B 原有显示快照捕获。没有添加额外的子弹或伤害重放。未新增宿主 native 钩子：FA 自带的同包 helper 继续使用现有 1.02 原生成员。

## 保存和 UI 边界

- B 接入已约定在 host 保存、join 确认保存、join `prepareReturn(entrySave.game)` 调用 `carryState`。
- `detach` 在 host/replica 销毁及 join 返回个人世界后调用，避免把远端共享世界当作个人存档。
- 改装台发送请求时不改实枪；双方均等宿主确认后更新试装基线。
- 重新连接重置加入侧确认版本缓存，不能因两个连接恰好使用相同 revision 而漏更新。
- 04 修复原生复活保留武器对象、只增加 epoch 时丢失参数基线的问题：复用每名玩家的运行器和按武器对象存放的弱引用缓存，只清理支架、近战接触、减速、旧绘图等临时状态，避免配件效果被再次相乘。
- 本地快捷键偏好仍保存在每个 AIR 实例的原有 FA preferences 中；远端 headless 不读取宿主偏好。
- Assembly 静态快照按 revision 缓存；每次仅另建少量动态冷却状态，避免每个玩家每步反复复制整个配置。

## 验证交接

已完成：独立编译成功；link report 确认未把 `fe.World`、`Weapon`、`UnitPlayer`、`PipPage` 存根嵌入产物；与 root 的 `experimental/b-field-client-integration/AddonsBridge.as` 入口、字段、动作白名单逐项对齐。

`BFAAddonCases.as` 是供 root 手工注册到 field2 driver 的独立场景，不修改公共驱动。它只允许全新 startup 测试 AIR ID，使用真实 B 动作队列与实际改装 UI；预期覆盖两人不同弹匣配置、增倍镜切换、榴弹各扣各的物资、冷却阻止重复发射、加入侧确认 UI，以及可选真实断开再连接。准备武器和位置属于测试布置，不用伪造伤害、命中或确认结果。

场景入口由 root 登记为 `attachments`，构造参数与现有 `BFieldCases` 一致，`cfg.faReconnect=true` 开启真实断开再连接。驱动新增调用两人的原生 `resurect()` 并沿用 PlayerLives 的 epoch 更新步骤，再等待 B 自行重绑，断言容量仍为 120/72。这是复活边界检查，不宣称覆盖从扣血至死亡、等待和奖励的完整死亡流程。`BFAAddonDoc.as` 及两个 `.compile*.swf` 仅用于编译检查，不加载进游戏。

尚需实机：上述场景、刺刀友伤开关、分房攻击、复活换图、时停延后结算、附件绘图在远端的视觉结果、原版武器菜单中的改装入口。编译通过不等于这些玩法已验证。常规 FA 数值算法保持正式 0.3.5，但同帧与 MSW/其它武器改动的执行顺序仍须在完整 B 环境核对。

重新编译使用本目录 `build.py --output build/ab/fa-b-<新目录>`，仅构建独立候选，不改正式目录或玩家存档。
