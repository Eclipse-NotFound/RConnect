# 普通墙沿结构版本候选：真实类源码

2026-10-23。源自准确恢复22 `build/m52/recovery-22/src`。本目录由根整合；本子任务只实现 `WallImpactVisuals`、`WallSurfaceBridge` 及现有 `WallSurfaceChecks` 组件扩展。组件01编译成功但79项处异常失败；修正生命周期缺口后，根运行组件02实际153项全部通过。完整产品源码现已准备并校验，尚未编译。**没有原生资产、视觉/性能或部署合格结论。** 正式安装版仍由根维护。

## 已写入的实际行为

- 普通房取消以碰撞 `phis` 判定能否贴墙沿颜色；真实22个漏点进入现有实际像素协议，不用接收侧alpha过滤。所有颜色继续经过准确22 `NativeWallColor.setter`。
- 普通cell增加 `sv/full/needsNative/rebase`。普通墨迹仅推进 `v`；权威结构完成从真实BitmapData取整格1600个像素（含0），推进同一revision产生的 `sv/v`。同sv普通擦除后迟到墨迹仍可接受；旧sv墨迹不能复活结构。
- 非权威已确认颜色与queued/pending预测分离；pending wire不变。局部underlay只存仍有预测像素的原生底色。旧ACK按seq退役后仍重新合成受影响cell，不能留下已退役预测，也不删除新sv queued。权威settle返回自身累计 `v/sv`，不回显请求颜色。
- 普通报告最多3个cell；单cell编码最坏13340字符，因此完整累计ACK最坏40020字符，低于旧48000限制。不新建ACK分片。large原有64cell/裁片/paintOrder逻辑保留，普通分支不复用其旧put。
- 对结构代、版本和坐标严格要求有限非负整数；高sv颜色必须是完整基线。完整包替换全部旧值；needsNative只有元数据，不能伪装透明图或进入普通更新/snapshot。restore保留导入版本并提高本机revision下限。
- 先安装待恢复数据，再由真实原生raster完成needsNative/rebase。接收方不能用自己的底图生成权威基线。新owner生成后必须由根的RoomSync接入回写既有record，再发送grant。
- `endSession` 清传输/预测及large状态，但保留本世界普通已确认结构；真正换世界仍 `reset`。普通事件钩子从初始化开始安装，与按联网启停的large钩子分开。
- 有真实普通宿主钩子时，`observe` 不再用弹丸大范围差分兜底；`ink-before`保存本次实际bounds的即时前像素，`ink-after`只比较这些像素，不与整cell长期shadow比较。因此同cell更早发生的mat7/gwall排除写入（包括在本次bounds内但没有再次改变的像素）不会混入普通墨迹。shadow只更新本次实际范围；无新钩子的旧宿主保留原后备观察，**不授予本候选实机资格**。

明确的视觉取舍：结构改变的40×40 cell整体推进结构代；同cell旧代迟到弹痕会被丢弃。inactive破坏或后续原生重绘基线化时，同cell剩余墙体上旧痕迹也可能被新底图清掉；范围外cell保留。这不是承诺所有旧痕迹无损保留。

## 根接入的公开接口

| 方法 | 契约 |
|---|---|
| `ordinaryRole(loc, authority)` | 设置该房权威身份；仅Grafon.loc匹配时读取房型，不用另一个房间的共享Grafon误判旧房。 |
| `prepareRestore(loc, list, authority)` | 校验并安装普通元数据，抑制旧数据重放；不读图。large暂存原list，finish走原restore路径。 |
| `finishRestore(loc):Boolean` | 重放有效确认数据；needsNative或原生失败时false。large沿原恢复逻辑返回，不把其既有异步raster误报失败。 |
| `hasNeedsNative(loc):Boolean` | 待基线或失败闭锁均true，用于禁止提前放行。 |
| `structurePending(loc, bounds)` | inactive权威破坏完成后推进结构代，仅存元数据，绝不读取别房frontBmp。 |
| `structureComplete(loc, bitmap, bounds, rebase=true)` | 只接受房间权威与Grafon.loc/frontBmp完全匹配的真实图；校验整格可读后取完整像素，更新shadow。 |
| `nativeRaster(loc, bitmap, success):Boolean` | 真实原生成功绘制、重放前调用；仅owner生成pending/rebase。不能由接入方拿当前bitmap假造成功。 |
| `endSession()` | 上述普通结构历史保留与传输清理。 |

`nativeFailure`（未知结构范围/缺pre-die证据/观察写入失败）闭锁到世界reset或合法restore；普通成功raster不会洗掉它。单独的`rasterFailure`可由后续真实成功raster清除。桥消费者抛异常时另记整个桥实例的sticky故障并原样重抛，不能被宿主catch后当作成功；此故障需重建模组实例，网络开关/reset不清。任何失败存在时checkpoint抛错，避免导出空列表洗掉失败。外层房间key/epoch/term及发送方校验仍由既有Session/RoomSync负责；这两个类不新增一套term协议。

## 与宿主窄接口对齐

另目录 `experimental/recovery-ordinary-wall-sv-host` 由宿主代理负责真实Grafon/Location源码。独立静态字段 `Grafon.rconnectOrdinaryWallBridge:Function`，单参数事件对象。公共字段：`kind/grafon/loc/bitmap/bounds/token/valid`；结构额外 `tile/ordinaryPhysical/prepared`。

- `structure-prepare`：必须在 **Location.hitTile/dieTile 中 Tile.die 清front之前**调用。返回携带room-state、tile身份和旧范围的token；此时不推进版本。不能仅在已清旧front的Grafon.tileDie入口取范围。
- `structure-before`：token必须属于当前room-state/同一tile；实际资产范围与旧轮廓范围并集。返回 `{allow, token}`。仅明确ordinaryPhysical且非owner时 `allow=false`，只延迟结构前景写，原生粒子/HP/物理仍保留。owner缺prepare保留原生执行但记录失败，不能合格。
- `structure-after`：同一token、匹配实际bitmap、valid且written时完成完整权威cell。
- `structure-pending`：原生die完成且无活动图；校验prepare token后仅owner登记pending。
- `ink-before` 返回 `{token}`，`ink-after`比较真实修改后的有界cell；`ink-failed/structure-failed`记录失败。
- `raster/raster-failed`来自真正原生drawLoc完成/失败，前景内部catch也必须计入，不能只看外层返回。

根负责的接入文件位于本目录 `src/rconnect/game/GameBridge.as`、`TerrainSync.as`、`src/rconnect/core/RoomSync.as`；本子任务没有改这三类。接入必须覆盖接收侧TerrainSync固定 `tileDie(t,9)`，保证不会在权威颜色之后再执行不同本机eraser。pending/rebase交接不得走旧fresh/retained快捷放行；完成后的wall checkpoint须回写相应record，不能发送旧pending。已写或待完成程度由根记录，不能从本README推断整合已通过。

## 组件与资格边界

`components/WallSurfaceChecks.as` 使用完整实际生产类；保留原85项的large/实际uint检查，对其中3个普通旧格式断言改为显式sv协议断言。新增真实22点、普通擦除后late ink、结构后旧ink、旧ACK退役、新sv queued、错误元数据/不完整full、inactive/新owner基线、失败闭锁、same-bitmap rebase、session保留、导入版本、3cell批次、实际桥事件token等。

**静态推算正常路径应153项**（不是实测通过数）。Bullet与Grafon为原组件接触/绘制夹具，不是真正游戏战斗或资产；组件只能验证实际类的协议与BitmapData合成。新增即时范围反例：先写同cell排除像素，再在另一位置普通decal，上报只含此次变动，范围内外旧排除色都不入报告。最后一项主动触发真实消费者异常，验证桥错误不会被原生catch洗成ready。`src`与`components`中的两份生产类应逐字相同；根冻结编译前需核对。

本轮未覆盖并明确不合格：mat7/gwall权威建墙事务、其他模组直接写前景、真实全部材质轮廓、两端随机eraser/粒子完整原生效果、真实交接链、短时火星、持续密集破墙流量和总帧时。mat7/门特殊结构/gwall保留宿主旧绘制分支，没有冒称加入已支持玩法。实际资产异常或宿主ordinary错误计数非零时不可部署。完整cell未来重复ACK/snapshot成本须实测，不因组件正确就认定性能合格。

本目录只保留最终源码，临时生成脚本已删除；不会再次运行生成器覆盖根的接入文件。编译/AIR/部署仅由根执行。

## 组件01失败与最小修正

保留证据：`build/m52/recovery-ordinary-wall-sv-component-01/component-result.json`、`receipt.json`。实际编译退出0；组件78条通过后，第79条记录未捕获#2015，栈为 `ordinaryCompose:721 → replay:563 → before:165 → WallSurfaceChecks:239`。旧断言正在更换前景图，旧front在before返回后才dispose，不能把它归咎于测试过早释放。

实际错误是before先dispose旧shadow却仍保留非null引用，再更新active/bitmap并replay；新ordinaryCompose同步shadow时误用这块已释放对象。修正为释放后立即置null，让新图先完成重放、再创建新shadow。同一shadow变量在redraw/nativeRaster替换处也保持此不变量；copyFront分配失败仍抛原异常。组件内容、原断言和153项预期均未减少，组件01证据不覆盖；新源码尚未重跑。

## 完整产品准备入口

根已完成生命周期修正后的组件02，实际153/0（详见本目录RESULTS）；组件01仍保留。`prepare_product.py` 以准确恢复22完整90类、71个原构建输入为基线，只覆盖冻结的 `WallImpactVisuals/WallSurfaceBridge/GameBridge/RoomSync`，再把版本改为 `0.2.24-wallsv1`。TerrainSync必须与准确22逐字相同。

默认输出 `build/m52/recovery-ordinary-wall-sv-production-01`。三个显式入口互斥：

```text
python -B -X utf8 experimental/recovery-ordinary-wall-sv/prepare_product.py --prepare
python -B -X utf8 experimental/recovery-ordinary-wall-sv/prepare_product.py --verify
python -B -X utf8 experimental/recovery-ordinary-wall-sv/prepare_product.py --build --registry-wait 900
```

前两条只复制/核对源码与工具及记录SHA，不启动Java或游戏。`--build`须已prepare，私有加载候选自己的原build_mod，仍只调用原compc/mxmlc两次；保持game登记、每次Java前1GiB、运行中512MiB保护、300秒单次超时、隐藏窗口和自有子进程finally回收，不修改共享构建工具。候选目录已存在则prepare拒绝；任何失败及已启动构建均保留，不覆盖重试。

严格输入固定为准确22 manifest/SWF、四类overlay、未改TerrainSync、组件02证据、SDK/JRE/内存与登记工具，以及组件02的22项实际安装指纹。根目录游戏、安装模组和真实存档都只读。准备完成只说明完整源码可复核，不能替代随后完整产品编译、宿主资源与实机资格。

本轮已实际执行 `--prepare` 与 `--verify`，均退出0。production-01包含90源码、71工具，只有四个修复类和版本入口与准确22不同；TerrainSync及22安装输入不变。脚本SHA为 `c74a4f4aae790b39c09131a12ba258feca4b69153090736c4f320e64e2b085bf`，prepared.json SHA为 `707718036263940c4f63ee1babe3f913735e81aee4e181f95f9b6cb4dad30083`。`compiled/air_started/installed`均false。本轮未执行 `--build`；脚本与候选源码已冻结，后续更改脚本会使该候选verify拒绝。

## 独立宿主构建入口（后续接续）

根后来已完成上述完整产品编译，准确SWF为 `C6A3B1136BDE63C32D23C4E555DFC240F3A573384D19C4FE9636A4138193496D`。新 `build_host.py` 只准备它所需的隔离宿主，不改旧产品recipe/manifest，也不把独立EB365离线优化混入此墙面产品。

宿主依赖链明确为安装BEFC → `recovery-native-travel-host-01` E159（Game旅行桥）→ `recovery-first-raster-host-03` FD92（Grafon首栅格）→ `recovery-wall-surfaces-host-01` ACC336…35DFD（大图墙面桥）。**此次在ACC上仅定向导入Grafon、Location；相对安装BEFC并非只有这两个小改动。** FD92与ACC原失败回执和其后独立recheck均保留并固定指纹。新入口只按本轮component02精确22项核安装，RConnect一项允许原574D或独立EB365，其余21项禁止漂移；实际prepare与build状态分别记载，每次build全过程必须同一安装状态。

最短接续命令（从RConnect目录；使用已登记Python）：

```text
python -B -X utf8 experimental/recovery-ordinary-wall-sv/build_host.py --prepare
python -B -X utf8 experimental/recovery-ordinary-wall-sv/build_host.py --build --registry-wait 900
python -B -X utf8 experimental/recovery-ordinary-wall-sv/build_host.py --verify
```

默认新输出 `build/m52/recovery-ordinary-wall-sv-host-01`；已有候选与失败不得覆盖，可显式传新的 `--output build/m52/recovery-ordinary-wall-sv-host-02`。`--check-inputs/--prepare/--verify`不启动Java或游戏。只有`--build`执行6条固定FFDec命令：ACC原类导出→仅两个冻结源导入→候选回读→两类pcode→前后完整class清单。每条命令共享game登记、启动前1GiB、运行中512MiB保护、300秒超时、隐藏窗口，并finally只回收本脚本子进程。不生成/修改安装文件、存档、配置或其它模组。

核验保留MainFE加载器、World、Game、Land、Camera、GUI完整读回一致；ACC与候选逐tag比较，仅允许代码tag72/82变化，资源与SymbolClass标签、电影头、全部class清单必须一致。Grafon未改方法按ACC真实读回逐词比较，包含原报告漏计的属性getter，故核验口径为91个旧方法/访问器中88个不改；Location为74中72个不改。新/改方法不使用任意变量改名、声明移动或伪表达式擦除来自动放行，保存完整source-readback.diff与pcode供根审查。

`build.json` 的 `compiled/build_checks_passed` 与 `validated` 分开：前两者仅表示编译及上述静态检查，后者始终false。新增回调的字段绑定、异常控制流、实际材质/随机数/透明像素及普通22点/分房/重访/大图/流量/帧时仍需后续检查；不能凭构建退出0直接启动完整资格判定或部署。`--verify`只复核不可变prepared和build证据，不把这些待核项改绿。所有命令、内存轨迹、失败与读回保存在新输出，旧证据不改。

本子任务已实际执行宿主`--prepare`和`--verify`，均退出0；39个固定输入及当前22安装通过，实际RConnect为EB365。脚本显式拒绝`-O/-OO`，不允许关闭断言。冻结脚本SHA `D94CDE1D29B6277F6E9CA0B613492935FC4FB718095E28B6F7B57D532BC9792F`；host-01 `prepared.json` SHA `1D39F186E2CE9351E680146EEC3418EACB3AAC23F23AAA4B46E9E7A815CE5F54`；`commands.json` SHA `F11F93F90E4B6F24CE795EE3C3839F8BB9695776C0B88D3D8E743B1D73D0F770`。**未执行--build，没有新宿主SWF或实机资格**；根下一步可直接执行上面`--build`一条命令，无需重做prepare。

### host02：仅修正构建工具日志环境

随后根实际运行host01：第一条before导出退出0，但JPEXS全局AppData日志写入遭沙箱拒绝，stderr采用cp936中文严重日志；UTF-8读入先报解码错，尚未执行import，没有新宿主SWF。原失败完整保留，`host-01/build.json` SHA仍为 `BB499E4C04FA7EF87B09646D96C58010C09B7648E379737A91D83430E3D774C2`，原脚本原字节保存为 `build_host-host01-failed.py`，SHA仍D94C…792F；旧manifest不改，也不把它重判通过。

新脚本仅有两个差异：默认输出改成 `build/m52/recovery-ordinary-wall-sv-host-02`，六条JVM命令全部明确 `-Dfile.encoding=UTF-8 -Duser.language=en -Duser.country=US`。严重日志规则、登记、内存保护和所有源/宿主/安装输入未改变。**此问题属于工具运行环境，不是产品功能故障。** 根将为正常JPEXS日志写入按系统权限执行实际构建，本子任务仍不启动Java。

host02已实际`--prepare/--verify`退出0；脚本SHA `57D3B09CE8F1F9C144F5ED38C434EB53B640EDEE3E678A659CA3043D2D9DBAFA`，prepared SHA `CA6D0FC58B67141DC86202CD48FDB1F908A24C809EB1756B32D111F6512537FD`，commands SHA `94BA1B1DA9781D7431E615CEE7FCD39BA64CC440C0405D628389A20CD3A63B19`。上述最短`--build`命令现在指向host02；无新宿主SHA，实际编译/语义/原生验证仍待根执行。
