# 普通墙面结构版本：执行记录

2026-10-23。正式安装版未改。本记录只覆盖明确列出的隔离候选，不代表墙面或四项恢复功能已经合格。

- 独立源码审查先后发现并修正：普通 ink 夹带同 cell 更早的排除写入；留在原房的 owner 未就绪时被宿主旧记录覆盖。前者改为本次范围即时前后比较，后者在任何记录恢复前拒绝交接。二次窄审查闭合这两条具体反例，未赋予运行资格。
- `build/m52/recovery-ordinary-wall-sv-component-01`：准确两类生产副本编译成功，Checks.swf `264a581933f9e51d58a0857a4f4babcea55be1063dd999ec3e250ec31c6ba519`。原计划153项；实际运行到第79项时出现 #2015 Invalid BitmapData，78通过、1异常，余项未运行。
- 异常链为 WallSurfaceChecks:239 → before → replay → ordinaryCompose:721。更换位图时释放旧 shadow 后未清空引用，重放同步过程因此复制已释放 BitmapData；不是测试先释放 front。作者正在做最小生命周期修正，旧断言与失败回执保留。
- 首轮实际回执为 `receipt.json`，断言为 `component-result.json`。编译、AIR、安装与源码核对均有记录；自有实例已回收，安装不变。组件不能覆盖 GameBridge/RoomSync 完整编译、真正宿主资源、原生房间交接和性能。

## 同日：生命周期修正后153项通过

WallImpactVisuals `12682bff279d35d3dc2181d4832a9d948f9ee68fcfcdf5188ee53dec2c91ff72` 仅在释放 shadow 后立即清空引用，组件原断言不变。新 `component-02` 编译后 Checks.swf `534518c0e19fe6767da65233724bf2ac0bd9d990ec540b7b4b85ba367d01e846`，独立 AIR 实际153项全部通过、退出0。真实生产类与组件副本一致，运行前后源码与安装不变。保留首次失败；此通过仍不包含完整产品、宿主资产或性能资格。

## 完整90类产品构建通过

根按已冻结 `prepare_product.py --build` 执行，`build/m52/recovery-ordinary-wall-sv-production-01` 的两次Java编译均退出0并回收。版本 `0.2.24-wallsv1`，SWF 219,761 bytes，SHA256 `c6a3b1136bde63c32d23c4e555dfc240f3a573384d19c4fe9636a4138193496d`。准确22的90类与71构建输入被固定，只覆盖四类及入口版本；TerrainSync未变，源码/工具/22项安装核对通过。

这只补上完整 GameBridge/RoomSync 与两类墙面代码的编译验证。宿主两类尚未编译，未启动该产品的游戏实测，未部署，也没有性能资格。

## 宿主两次构建失败，候选未进入游戏

`recovery-ordinary-wall-sv-host-01` 的第一条FFDec导出退出0，但工具写自身AppData日志被沙箱拒绝；stderr为CP936中文，严格UTF8读取在错误筛查前失败。没有执行import，没有生成新宿主，22安装未变。原脚本及回执保留，不能把导出成功当作构建成功。

host02只为JVM明确UTF8及en/US日志，并以测试所需权限执行；工具环境已通过。实际import退出1，准确错误为 `CURLY_CLOSE expected but COMMA found on line 874`，对应新增普通桥的多变量声明。此时编译尚未成功，不能据此推断运行时像素结果。正在创建独立native-v2，仅将新增逗号多变量声明拆为同顺序单条声明，原宿主源和host01/02失败保持不变；后续host03重新构建，产品C6A3及已安装EB365均未改变。

## host03 实际编译通过，但回读发现 E4X 语义错误，拒绝使用

native-v2 只把六处多变量声明拆成同顺序单声明。host03 的六条 Java 指令均退出0、进程回收，SWF `a2ffea6a401046e2124c324bd1d3950cef37d6929a4cf620a8b26851673d88f7`。构建审计先在未改 `allAct` 方法发现文本差异；进一步独立查证，`createObj` 原 `@id == id` 被真实编译为两次读取相同本地 id 的恒真条件。该错误可能影响物品创建，不能当作反编译文字差别放行。原 `build_checks_passed=false`、`validated=false` 完整保留，未启动游戏或部署。详细证据见 `experimental/recovery-ordinary-host03-review/README.md`。

## host04 仅 Grafon 中间版构建完成，尚无运行资格

`build_method_stage.py` 从准确 ACC 只导入 Grafon，五条 Java 指令退出0并回收；`grafon-only.swf` 为 `9b3622541784fdab1104a2fd01b9858e94297388b5df102d50f62e8dba2f913f`。中间版 Location 回读源码与 ACC 逐字节相同。已保存 ACC、中间版、失败 host03 的实际 XML，用于只移入 `hitTile`、`dieTile`，避免重编 Location 其它方法。两类同属一个 DoABC，不能直接用失败供体整块覆盖。此中间结果没有 wallsv 完整功能或游玩资格；后续必须逐方法保留及最终实际回读。22项安装与冻结输入未变，未启动 AIR。

## host05 双方法移植构建与完整回读通过

host03 的新常量顺序与仅 Grafon 中间版不同，不能直接复制其方法。因此从准确 host04 再只导入 Location，生成独立 `recovery-ordinary-wall-sv-location-donor-01`，四条 Java 指令退出0。供体 `bfc9e672615c1b27c83b41d1158ce0b93349ffa31cc35180b86a223c954c664c` 本身不可游玩，只提取两处目标方法；它的旧常量前缀全部相同。

冻结 `method_transplant.py` C422C540…9268E 与 `build_final.py` 9EF068B7…671AF 后，host05 六条 Java 指令退出0，产物 `00c7c511ffa51745cb4932e820365091d2540978eedd6dfe726a5cfd7818aa48`。只移植 `hitTile`、`dieTile` 的完整方法体及前者必要的 activation 标志；其余5,787个方法体、类/脚本结构和旧常量前缀精确保留。序列化后及最终 SWF 均重新导出核对；非代码资源从原中间版逐 tag 保留。旧 E4X 错误没有进入最终版本。

独立中间审查还确认24个匿名方法属于 Grafon 的闭包链，无其他类引用；没有把匿名方法笼统忽略。准确证据见 `experimental/recovery-ordinary-host04-review/README.md`。host05 的 `build_checks_passed=true` 只表示构建/保留检查通过，`validated=false`；独立目标绑定/异常审查与双人原生墙面、结构重访、性能尚待验证。22项安装保持 EB365/BEFC，不代表本候选部署。

## 实际双人四轮普通墙面通过；显示延迟仍待优化

独立目标绑定/异常审查完成，`recovery-ordinary-wall-sv-host-review-05/receipt.json` 只授予原生测试准入。冻结新绑定后，直接复用原 ordinary driver，不编译测试驱动、不改变原 uint 比较或错误规则。`recovery-ordinary-wall-sv-native-01` / `76b2f38ec6` 实际运行退出0，原框架和独立像素分析均通过；主、加分别34项全部通过。测试进程及 host/join/frozen 副本回收，22项安装与冻结输入未变。

| 开火侧/武器 | 本次期望像素 | 丢失/错误/多余像素 | 原分析器最终颜色首次匹配差值 |
|---|---:|---:|---:|
| 主侧轻机枪 | 118 | 0 | 73 ms |
| 加入侧轻机枪 | 96 | 0 | 155 ms |
| 主侧速射等离子 | 1,030 | 0 | 54 ms |
| 加入侧速射等离子 | 1,059 | 0 | 328 ms |

全部四轮的原生前景和最终显示像素均完全一致。旧普通房加入侧等离子漏22个墙沿像素的复现已不再失败；本次图案像素数与旧轮不相同，不能把两轮当固定同图的性能A/B。观测间隔最高仍有190ms；表中328ms的连射指标解释见下方修正，不是首发显示延迟。本次保留 `performance_qualified=false`，不能声称卡顿已修复。截取PNG及最终uint读取本身有额外成本，结尾约2秒批量读回不能算作游玩帧停顿。

边界：普通48×25房、四个mat2原生墙面选点，CS native场景关闭；两次单发轻机枪、两次8发速射等离子。使用真实Weapon.attack/Bullet.tilehit，不直接写预测像素。该测试刻意低地形伤害，不替代真实破坏/晚包/权威交接/重访，以及全配置密集性能。继续复用已有RoomCooperation回归补物理交接检查，并从本轮时序证据定位延迟。

### 连射“首次显示”指标解释修正

进一步逐阶段读取既有 proof 发现，原分析器 `first_frame` 只查八发结束后的最终颜色。加入侧等离子第一发的545个像素后来全部被改色，旧指标没有计入，直到第二发留下一个最终颜色才得到328ms；因此不能把表中该值解释成第一发迟迟没出现。实际第一发原生命中时间1792722090559、源端首次RENDER为0567，主侧0688已显示完全相同的545像素：命中到首次远端显示129ms，画面对画面121ms。八个对应完整阶段的画面差为121/50/48/121/191/172/190/113ms。

此更正不改变旧分析器、像素判定或原始结果；最终一致性通过仍成立，流畅度仍不合格。现有wire只含入站wallPaint数组，缺少出站report与ACK时间，不能据此把残余延迟直接归因于网络或某一个发送函数。

## 真实物理破墙后的汇合回归失败

`recovery-ordinary-wall-sv-rooms-01` / `2e1db25ddc` 使用同一 C6A3+host05 和已有 BF6C entry-room 驱动，完整原流程退出1。加入侧独立房原生子弹破墙已通过；汇合时 seal3 调用 checkpoint 出现 `Unqualified native wall checkpoint`，宿主最终报交接超时仍暂停，主/加仅3/9项通过，未完成。该文案只由 observer/native/raster 失败标志触发，不是未绘制 cell 或普通 ready 检查；原日志不能确定哪个具体失败分支。

保留原始两端日志、`result.json`、`rooms-result.json`，不修改断言或记录为通过。自有实例及可重建副本已回收，22项安装及冻结输入不变。下一步只增加首次失败事件及原因的隔离诊断，复用同一房间驱动，不清失败标志或跳过 checkpoint。功能失败已足够阻止本候选部署。
