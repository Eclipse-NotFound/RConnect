# 只缩小本地破坏观察的字段比较

状态：仅源码和静态核对，尚未编译或AIR运行，不能宣告等价/性能合格。准确祖先为recovery14 `225a7940…be5f7`，TerrainSync与13、15相同，源SHA `317c9658b0632f3bb8333c11cd302c68ef45e7a9f2f54ed6b6c631b6c1b92b44`。实际动机见`../recovery-input-frames-review/review.md`：两个有效完整窗口中，30,000格的capture链分别30/134与26/136个CPU样本，非GC叶；这只证明局部工作存在，不证明它解释全部首进延迟。

唯一生产覆盖：`src/rconnect/game/TerrainSync.as`。capture对真正`fe.loc.Tile`只比较旧`p/h`与实时`phis/hp`是否严格相等；其它对象仍走原matchesTile。其余字节不变。全格遍历、200ms场景报告频率、请求/ACK/预测/结束时排空、hostPatch的全部13字段、checkpoint和原生破坏行为都保持。

安全依据：capture只消费旧记录x/y/p/h；observed的其它字段没有跨调用输出。apply使用新采before并比较刚写入observed的新值；hostPatch读独立base，checkpoint读真实Tile。只变视觉字段时省略观察快照刷新，不会丢掉完整场景同步。该行为特意不推广到动态getter，后者的读字段顺序、异常和副作用仍需保持。

## 组件边界

- 新、旧**完整TerrainSync类**同时运行；旧类仅改类名为ControlTerrainSync，新类与生产覆盖逐字一致。不把capture抽出来做替身算法。
- `fe.loc.Tile`使用参考1.02的完整源码（未删函数/字段、未改门或陷阱类型）。其实际constructor、setZForm、udar、die运行；Form/Box/Obj及Unit相关依赖只为独立编译提供小边界。Tile.dec/inForm/mainFrame以及真实Location图形/物理未执行。房间hitTile/dieTile调用实际Tile方法，但Location副作用由明确夹具记录，不能当实机破墙通过。
- NativeTileState与NativeRoomState为准确14完整字节。getter替身独立命名，测试完整比较的调用顺序、异常、NaN、缺值及会改变HP的getter。
- 计划**154条**实际断言：初次/重复/错误ACK；pending间二次伤害；apply预测保护；door/indestruct改变后的新伤害；无HP变化的破坏；全部11个非伤害字段仍出现在hostPatch；NaN视觉字段fallback；130格排空且128批次界限；重复settle不重复伤害；原生碰撞形状与最终opacity；完整checkpoint/restoration/reset/换房；动态getter；30,000格末格仍可检测。
- ABBA为旧A1、新B1、新B2、旧A2，各5次相同30,000原生Tile无变化扫描。构建、建立baseline、双方各1次暖扫描、断言、序列化全部在计时外；计时内只有循环调用report及非空计数。输出每槽原始ms，不设“必须更快”的断言，也不把组件成本变成游戏性能资格。整个测试按独立ENTER_FRAME分任务，复用60秒总时限，不逐帧写日志。
- AS未运行，154是静态数出的计划值；异常提前结束将使真实数量不足并被现有运行器拒绝。不得改expected去适配失败。

## 现有入口

以下前两条仅Python/source，不启动进程：

```powershell
python -B -X utf8 experimental/recovery-terrain-capture/prepare.py --materialize
python -B -X utf8 experimental/recovery-terrain-capture/check_sources.py
```

由根会话串行执行原登记运行器，使用新输出目录：

```powershell
python -B -X utf8 tools/validation/run_recovery_component.py --source experimental/recovery-terrain-capture/components --entry TerrainCaptureChecks.as --expected 154 --output build/m52/recovery-terrain-capture-component-01
```

没有新runner、不改通用工具；1GiB启动/512MiB停止、登记、唯一AppID、HiddenProcess、22项安装前后指纹、源码冻结及逐条断言检查均沿现有工具。所有补丁仍在本独立目录，未改integrated/安装版。组件合格后仍需同输入原生加载与原功能回归。
