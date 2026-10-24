# 原生加载画面显示租约候选

基底：准确已部署 roomfix5 `78C052…F4699`；宿主为 A796 的 `source-02` 中 World，源 SHA `F9B5D270…7AAF16`。本目录仅生成源码；没有编译、游戏运行或部署资格。

## 范围与行为

- 产品仅替换 RoomEntryView，入口版本改为 `0.2.24-nativeui1`。RoomSync、恢复字段、房间门槛、暂停和普通分房协议全部保持 78C。`busy` 不代替 `entryPending`，未换房的已确认一侧不会取得租约。
- 删除原来的两个 Sprite、全黑矩形、两份 `visualWait` 副本、显示树插入和素材同步。薄适配仅请求准确 World 的公开 `rconnectLoadingView(owner,pending)`，实际显示的是 `world.vwait` 本身，不改变其父层级。
- 显示租约仅隐藏原场景/背景/HUD 并借用原生加载文字与当前插图。完全不写 vblack：Camera/Script 自己管理原生淡幕，不能由租约保存恢复。没有 `setLoadScreen`、随机抽图、动画重启、控制开关或暂停写入。普通横向、背景门没有原生 Loading 调用，因此使用同一个实例的普通显示租约，不伪造跨图倒数。
- 原生跨图仍只执行原有一次 `setLoadScreen` 和原有 `exitStep=16` 收尾；在该同步步骤末尾重新维持显示，将**上屏的显示结束**延后到本机确认完成。原生声音、`controlOn`、`pip.noAct`、淡出、倒数和 HUD 顺序不延后、不重放。因此不是冻结原生过渡，也不是新增输入隔离器。
- 每项写入记录对象、字段、原值、写入值及显示代次。8 个确切原生显示写入入口在原逻辑前撤销旧显示写入并递增代次，涵盖同值写入的接管，防止“先被租约隐藏、后被剧情继续隐藏，取消却露出场景”。另在 newGame 入口保留已由主菜单交入的 native wait，不把相同值的后来显示恢复成旧隐藏状态。不保存整个界面后盲目恢复。
- 原生剧情、故事点击、读档/死亡、SATS、Pip、商店、暂停菜单、控制台及错误显示优先；出现它们时停止维持租约，不清这些状态、不重启控制、不关闭原生菜单。resize 与 native room activation 先撤旧写入，以更新后的状态重新取租约。不同 owner 不能接管/释放，Game/玩家身份改变拒绝旧请求。

## 明确限制与待验证

- 原生覆盖层优先意味着等候中主动打开 SATS/菜单时，显示租约会让开；本候选没有假称这等同于新的输入锁或“永不显示任何未确认状态”。输入和模拟仍由原有 roomHold/原生流程管理。必须实机验证普通过门、SATS、后发剧情和取消的显示结果；如果原有暂停合同不足，应另报具体缺口，不在本 UI 候选偷加控制状态机。
- 本租约只覆盖已核的 World 显示写入入口和 newGame 交入边界；原生非游戏 allStat、菜单、错误路径会拒绝续租，vblack 从所有权范围完全排除。其他模组直接写同一字段且写入相同值时，不能凭布尔值判断其新意图；本候选不宣称任意第三方同字段并发写入兼容。当前 A796 原方法已做反向核对，未修改原生主体或 E4X。
- 旧宿主没有接口时，适配明确记录 `native-bridge-unavailable`，不偷偷回到定制遮罩；这样的组合不具备部署资格。产品、宿主必须作为准确配对验证。`lastState` 和宿主 `rconnectLoadingUiFaults` 可供只读测试核对。
- 出现 native error/death 后租约释放的只是自己的显示修改；不清 error、不复活、不回滚房间。RoomSync 自身网络超时仍保留原错误/暂停与断开入口。本候选不解决生成或恢复性能。

## 源码准备与局部测试入口

`prepare.py --generate` 只在本目录生成完整 World、版本覆盖、测试 fixture、差分与 manifest；`prepare.py --check` 或 Python `verify()` 只读复核。它要求准确历史产品和 World 源，不将历史安装表冒充当前安装。生产构建/宿主字节移植及其真实读回由根按已有受监控工具另行执行；本目录不再包装一套构建运行器。

宿主改动是新增显示助手、8 个 native writer 的单句接管通知、newGame 保留交入 wait 的单句接管、exit16 尾部单句显示维持。新增实例字段均不设构造初始化表达式（写账数组首次需要时才分配），不要求改 World 原构造器。剥离增量必须精确恢复原 World（只归一化换行比较）。RoomEntryView 适配没有任何 DisplayObject 创建或重新挂载。

局部组件源为 `tests/`，入口 `NativeLoadingUiChecks.as`，正常路径预期 37 项，可复用 `experimental/recovery-ordinary-wall-sv/component.py`。测试 fixture 直接嵌入与 World 完全相同的助手；只模拟已审的原生显示边界，不模拟完整游戏、故事或 SATS 内部实现，不能替代原生测试。组件覆盖普通租约、原生 exit16、重复/过期释放、同值剧情写入、故事点击、SATS/error/death 优先、连续房间、resize、新身份、主菜单同值交入、损坏显示对象异常隔离及缺宿主接口；当前尚未执行。

根可直接复用的组件命令（本任务未执行）：

```text
python experimental/recovery-ordinary-wall-sv/component.py --source experimental/goal-native-loading-ui/tests --entry NativeLoadingUiChecks.as --expected 37 --output build/m52/goal-native-loading-ui-component-01
```

宿主最短接线是既有 `recovery-room-first-raster-host-current/build.py` 的六步命令序列（import → donor XML → retained XML serialize → final XML → AS → P-code）与其 `retain_v2.py`/`activation_slots.py` 的实际私有作用域及 activation 校验。**原冻结脚本不能原样执行本候选**：它固定了三类 early 桥、旧 donor 与目标清单。应在本任务独立接线中把范围设为仅 fe.World，按本 manifest 固定候选 World；不改原工具/原回执，不沿用 FBA 首绘宿主资格。

必要绑定是：原 A796 SWF、原 XML `mods/ContinuousScene/build/generated/scene-compat-20261024/tint/product/pfe.xml`（SHA `1D2642C7…338DA`）、原 World 源 `F9B5D270…7AAF16` 和本 manifest 中独立 candidate World SHA。原基底 hash 不替换成候选 hash。需保留的变更集合为：上述 8 个 native writer + newGame + exitStep 共 10 个旧方法，新增 7 个具名助手、6 个实例字段；原 World 构造器/静态初始化器及其他方法、所有其他类、资源原字节保持。新增字段无初始表达式，数组在助手内按需创建；不能为构建方便导入整个 World 构造器。现有保留器中 TARGETS/NEW/FIELDS、source.CLASSES 和准确 donor/输出 pins 需要显式适配；不是只换 SWF 路径即可。真实最终读回、异常控制流和私有调用绑定仍待根验证。

后续原生最低验证：准确双侧 host/product 配对；本机 `entryPending=true` 且无原生覆盖层时，屏上对象必须就是 `world.vwait`，显示树内不存在 `rconnect-room-entry` / `rconnect-native-loading` 副本；确认后原生层恢复、未换房者从未取租约；原三程/连续门/背景门/取消/错误断开保持原断言。不得以组件通过宣称性能改善。
