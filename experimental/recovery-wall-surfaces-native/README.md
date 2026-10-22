# 大地图持久墙痕：最小真实反例夹具

此目录是外部驱动和离线分析器，不包含生产修正。旧驱动的两次原生准备失败保留；当前准备修正仍待实际编译运行。区别是：**火星、火焰等短暂 Part 经过了旧的小房间测试；弹孔、擦除与焦痕是 Grafon 的持久前景像素，必须另外比较真实大图分块。** 不以粒子数作为墙痕证据。

## 初版的四个用例

真实从 `rbl` 经 `Game.beginMission("random_mane")` 加载合并场景；沿 scene12 使用测试固定种子 `1380142925`，宿主请求场景合并，加入端通过现有生产准备/恢复路径接入。固定的是这次隔离对照的输入，不改安装配置或随机生成实现。明确要求 `sceneLarge===true`、原生尺寸超过普通房、正确种子、独立且在显示树上的 `nativeBuffers[0]`，并与 scratch 不同。

依次为宿主 LMG、加入 LMG、宿主速射等离子 `plamg` 8 发、加入 `plamg` 8 发。只从真实生成的地图寻找四处相隔至少 160 像素、有 7 格干燥射击通道的现存墙面，每一处 `x>1920 || y>1000`。实际 Bullet 的 `tilehit` 和命中坐标也必须在此范围，不接受只有目标标签正确。若地图没有四处符合条件的原生墙面，明确失败；不会挪动边界、生成假墙或改装饰凑通过。选择条件是材质 1/2/3/4/6、HP 至少 100、门/水/假墙除外；原生拒绝耐久伤害的墙也允许，因为它们仍会产生原生弹痕。

武器由原生 `Invent.addWeapon` 内部 factory 创建，正常入背包并以 `changeWeapon` 装备，走 `Weapon.attack/step` 和真正 Bullet 碰撞。沿已成功 WallImpactTestDoc，在原生 setPers 后仅解除测试枪的 lvl/perslvl 使用门槛；不提升角色伤害技能。装满原生弹匣（LMG 90 / plamg 180，8 发需要 40），不再给会被附件模组退还的超容量 10000 发。夹具固定准心、去散射/后坐、terrain damage=1（避免这一轮从“留下痕迹”变为拆墙），不替换 projectile、decal、速度、射速和原生 burst。隔离角色无敌且静止、其它普通敌人暂停。没有 `hitTile/dyrka/Emitter` 直接调用，没有生产 receive/tick 调用，没有手写生产像素，未改变 CS、WB 或 RV 的装饰设置。

## 观测与不污染时序

- 按世界坐标裁出命中处 128×128，读取真实分块核心部分。gutter 的重叠世界像素只算一次；不直接把 scratch 当地图、不复制整张大图。块必须实际驻留且显示对象在舞台中。
- 源端仅把真正原生碰撞所在同步 simulation 区间的前后 BitmapData 作为墙痕来源。最终持久变化必须完全等于这些区间合并的稀疏差异；其它变化不能混成“预期”。
- 每次 RENDER 留下真实 native buffer 小片和真实 `visFront` 显示层小片，保存本机 getTimer 与同机墙钟。这个显示层包含原生位图和原有 WB 覆盖，无隐藏/替换操作。它是**前景显示层证据，不是整张舞台所有视觉叠层的像素等价证明**。
- 每例固定采样至少 10 秒，最多 480 帧；超容量报错，不静默丢帧。每次复制/绘制的实际耗时记录在 proof；仍可能有采样开销，因此本驱动不授予帧率/性能资格。
- 双侧都报告停止采样后，才进行 `getVector`、稀疏化、JSON 与 PNG 编码。所有截图保留采样时刻，编码和磁盘读写不在被测时间段。没有预热跳过首发。
- 分别给出远端首个相符 native 像素、首次完整 native 像素、首个相符前景显示变化、首次完整前景显示变化的墙钟延迟。源时间是实际原生碰撞区间后观察到像素的时间上界，不能声称机器指令级精确的碰撞时刻。
- 每例源/对侧初始世界像素与显示层基线必须一致，最终稀疏集合与颜色逐项一致，额外像素也失败。32 张 PNG 与 8 个 JSON 必须与对应日志的轮次、字节数、尺寸和内容一致，不能只数文件。

## 构建和运行（由根会话串行执行）

复用 `experimental/recovery-tests/prepare.py`、`run.py` 和现有 `tools/run_coop_regression.py`；没有另造 AIR 启动器。唯一变体是给原 native 函数做五处精确输入绑定：所选 RC、SHA、同字节外部 driver 绑定、版本、准确 FD92 宿主。其它 22 输入审计、原内存门槛、共享登记、独占、超时、异常扫描和 DONE 判断都沿用。结果保留原 `result.json`，额外分析为 `wall-surface-result.json`。

原框架的 `passed` 只覆盖启动、输入、原生动作和采样准入；**本项墙痕是否通过以追加的 `wall-surface-result.json` 为准**。旧14可能正常完成四轮、框架通过而精确像素比对失败；这是有效反例，工具最终返回非零，不能读前一个布尔值宣称修复。准入失败/无原生墙痕则是夹具失败，不能冒充同步反例。

```powershell
$py = 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
& $py -B -X utf8 experimental/recovery-wall-surfaces-native/check_offline.py
& $py -B -X utf8 experimental/recovery-wall-surfaces-native/native_tool.py prepare --source build/m52/recovery-14/src --output build/m52/recovery-wall-surfaces-driver-04 --build
& $py -B -X utf8 experimental/recovery-wall-surfaces-native/native_tool.py run --candidate build/m52/recovery-14 --drivers build/m52/recovery-wall-surfaces-driver-04 --output build/m52/recovery14-wall-surfaces-native-03
& $py -B -X utf8 experimental/recovery-wall-surfaces-native/native_tool.py run --candidate build/m52/recovery-16 --drivers build/m52/recovery-wall-surfaces-driver-04 --game-candidate build/m52/recovery-wall-surfaces-host-01 --output build/m52/recovery16-wall-surfaces-native-01
```

反例基线是 recovery14 `225a794040c71f2a55ff433366a7969201ac3a58ffaab0a655cee1e4eefbe5f7`，宿主固定 FD92 `fd92fbd5ae92b5c8d4cbf8151d11796a140810f34988b7031e258c747d86734e`。调用已有 `reverify_host.verify()`，与 `recovery-first-raster-host-recheck-03/receipt.json` 逐项相等；同时保留 host03 原先 `sceneEnsure` 断言失败回执和后来独立核验，绝不把原 `validated:false` 改成 true。

同一个已编译驱动支持换 RC 候选，**不重新编译、不改 AS 测试输入**。默认仍准确 FD92；显式 `--game-candidate` 只另接受已构建的 `recovery-wall-surfaces-host-01` / ACC336B5…535DFD。每次通过 `recovery-wall-surfaces-host/recheck.py::verify_prepared` 完整读回，并与根保存的独立回执逐项相等，核对全部来源、读回文件、导入、实际 SWF 与 22 项安装输入。保留原宿主编译后的 `validated:false` 回执：其仅因未改变的 sceneDrawSteps 两处 FFDec 伪表达式被过宽规则拒绝，独立回读验证整方法与 FD92 相同。任意目录、source-only、仅有 kind/compiled 标记都不能获准；本适配不授予游戏/性能资格。

## 首版未覆盖，不能据此关闭的边界

首次真实运行 `31d33c03c7` 在选墙阶段失败，未取得射击或像素证据。driver-02 原源与失败记录保留。核对原版 `Location.hitTile`（公共1.02源码2511–2570行）表明，不可破坏或耐久阈值未被穿透时仍调用 `Grafon.dyrka`；排除这些墙并非本测试的必要条件。后续只移除选择器的 `indestruct/thre` 排除并记录各筛选阶段数量，保持天然几何、真实碰撞、至少5个变化像素、双侧最终像素和全部时间/容量要求。待新 driver-03 实测，不把首次失败称为产品反例。

跨 chunk/gutter 分割线的同一痕迹与所有副本；两侧同时写不同/同一格；实际屏外无驻留块命中后进入；移远淘汰再返回；整房离开重访；墙被破坏后的边缘残留；首次加载 pending→可见；SATS 暂停；一方未探索处；长时间累计、checkpoint 上限与 ACK 重传。之后按根会话安排扩充原生用例，不在本初版顺手放宽生产限额。

离线反例检查只证明分析器会拒绝错误证据、适配没有删原门槛，不证明 AS 已编译或真实四例通过。天然墙面选择、原生武器准备、两侧前景基线是否稳定，均须在首次实际运行核实；失败原样留下。

## df0cb3dad0 开火准备失败与修正

第二轮 `build/m52/recovery14-wall-surfaces-native-02` 选点成功，但实际源端 host case0、join case1、host case2、join case3 全部 shots/hits/nativePixels 为 0。观察者的 0 发是正常值，未将其算为源故障。原 `31d33c03c7` 和 `df0cb3dad0` 均不是产品墙痕反例，失败日志/PNG/JSON保留。

明确遗漏来自本夹具：原生 `AllData` 的 LMG lvl=5、plamg lvl=4；新建角色技能初始 0；`Weapon.checkAvail` 差值大于 2 即拒绝。旧成功 `WallImpactTestDoc` 已设置 `gun.lvl=gun.perslvl=0`，新夹具未带入。现仅恢复这项准备，不改生产攻击许可。新驱动在准备和首个真实 attack 保存等级、弹药、HP、冷却及返回值；首个 attack 拒绝即新增失败，不能靠后续重试掩盖。采样中最多两份标量诊断，不逐发写盘。

另一个可复核的夹具违规：正式 FA 0.3.5 / B330 对应发布提交 `fa2afee` 的 Runtime.before 只 `owned()`→`apply()`→`capture()` 背包枪，after 却读取当前枪 `snapshots[held].shots`。本夹具此前仅挂 currentWeapon、未入背包，解释两侧实际 Runtime.after #1009。当前采用成功 MSW 外部夹具的 `Invent.addWeapon` / `changeWeapon` 正常链，复制并恢复隔离背包/快捷槽/childObjs，不改 FA；此错误是否消失仍须下一次实际运行确认。其余首发时序、10秒/480帧、4天然墙面、真实碰撞、至少5像素与精确对侧图像断言都保留。

当前离线检查 28/0，其中包含真实源角色失败记录、原生等级门槛、两种准确宿主与拒绝任意宿主；没有 JVM/AIR 或新的原生通过声明。

## driver-01 编译失败与最小修正

根会话首次编译 `build/m52/recovery-wall-surfaces-driver-01` 时，ASC 报 `NativeWallSurfaceProbe.as(40)` 函数没有返回值：它未将 `try` 中返回与 `catch` 中重新抛出识别为完整返回路径。已仅在 `capture` 的 try/catch 后增加不可达 `return null`，没有改变捕获、错误抛出、玩法或门槛。原 driver-01 的源码、哈希与编译日志全部保留；下一次由根会话使用新目录 `recovery-wall-surfaces-driver-02` 编译。此修正尚未由本子代理编译或运行 AIR。
