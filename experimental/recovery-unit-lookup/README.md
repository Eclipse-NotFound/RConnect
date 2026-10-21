# applyUnitsSync 单次调用内部消重（冻结 recovery10）

仅独立稀疏源码、精确patch及组件。**未编译、未运行 AIR、未测定向时间，也未修改 integrated/安装版。** 不网络合批，不改频率/事件/状态恢复，也不改prepare/register接口。

基线 `build/m52/recovery-10`，SWF `184EEA3D6405EE57CB0BC3F6CFA78668F5CA9334888B0CA2AF04095BC17C4608`。本次两类与冻结09逐字节相同；准备时强校验两份基线及哈希，实际来源/覆盖/组件指纹见 `inputs.json`。

## 准确改动

`proposal.patch` 只有两个方法：

- `GameBridge.applyUnitsSync`：先建本次调用的对象→数组下标提示，传给resolve；有效位置只计算一次；新建MirrorHitUnit已在构造末尾sync，不再紧接着重复sync。
- `ObjectIdentity.resolve`：新增可选 `members:Dictionary=null`，已有调用默认完全原路径。已绑定found每次仍检查 `list[int(memberIndex)]===found`，不匹配/缺提示时走原 `list.indexOf`；used检查、原距离认领、类过滤、绑定及遍历顺序全部不动。

索引仅是提示，绝不是开头截取的永久成员集合。数组增删移位/原地替换之后，现场对象检查防止返回已移除单位。重复对象取最后下标也合法；最后副本消失而首个副本仍在时自动回退。新建命中代理push后不刷新提示，原生indexOf回退处理新成员。数组本身没有复制；未知键仍按当下原数组和距离查找。

## GameBridge 副作用顺序

- prepare/register全部保留，包括新建前prepare、同步前prepare和register里的默认prepare。本提案不借此改遮罩行为。
- 坐标分支原来连续两次 `validLandPos`，有效路径两次之间没有回调。现在沿用第一次结果，原日志分支、queueUnitMotion及后续原生/特效调用顺序不变。
- 新命中代理的构造末尾已经 `sync()`；之后只有赋 `_hitUnits`、数组push、原prepare。prepare记录vis/hpbar遮罩信息，不写target单位或代理属性，因此省去第二次sync。已有代理仍在原位置sync。构造及其内部原生调用未移位。
- 该索引的存在检查不会冻结后续回调能修改的数组：每次resolve读取当前objects键映射和当前数组槽位，失败回退。没有跳过used，也没有提前进行距离绑定。
- `check_static.py`验证其它所有方法不变、两份全类组件准确、相关回调令牌顺序及本次3处差异。它**不执行真实GameBridge/原生碰撞**；这两项改动的运行集成仍须主会话验证。

## 可直接交给组件运行器

- 主类：`components/UnitLookupChecks.as`；唯一source-path：`components`。不带候选完整GameBridge，不带game SWF或游戏存根SWC。
- 全类旧版是冻结ObjectIdentity仅改类名/构造名；新版是实际覆盖ObjectIdentity原样。唯一依赖 `GameBridge.probe` 为明确替身，支持普通字段与getter并记录调用顺序。场景对象是LookupUnit，非原生Unit，不声称游戏效果测试。
- 18组案例逐步比结果对象身份、used、绑定、数组和回调状态、probe访问顺序及输入未变；独立预期覆盖重复键、已used、原地替换、增删移位、新成员、重复对象、原生式回调/字段getter回调、未知键最近距离/同距顺序/类过滤/150px边界、空输入、房间保存恢复和reset、未传新参数的旧调用者。
- 计数使用独立的两份完整类，只将原 `list.indexOf(found)` 替换为计数后调用**真实Array.indexOf**；不是模拟返回值。136个单位＋131个代理、40次完整查询，预期旧5440次indexOf、新0次；另测默认接口136次、移位和新增成员各恰好1次原生回退。实际结果须等AIR，静态不冒充通过。
- 定向计时使用**无计数插桩的完整旧新类**，先各20轮预热，6组交替先后顺序，每组200次全量查询。新版每次都重新构建成员字典，分配及填表成本计入。输出每组毫秒、精确checksum、中位数、比值；不以更快作为功能断言，也不据此宣称游戏性能合格。若净收益很小或倒退，应撤掉索引，只保留其余消重。
- ADDED_TO_STAGE执行；实际assertions、failed、逐步案例和测量写唯一测试app的 `File.applicationStorageDirectory/result.json`，完成后退出。当前预计84条运行断言，**未执行**；实际计数以结果为准。
- 由主会话按测试登记、独立AIR ID及隐藏桌面编译运行到新的 `build/m52` 目录。`component-plan.json`记录入口；不修改失败历史。

准备命令（项目根 `mods/RConnect`）：以已知Python执行 `experimental/recovery-unit-lookup/prepare.py`，再执行 `experimental/recovery-unit-lookup/check_static.py`（`-B -X utf8`）。两者都不会启动编译器或AIR。准备器只重建本独立目录的生成文件，不更新集成树。
