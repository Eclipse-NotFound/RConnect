# MSW无图像爆炸：原生失败复核与下一轮夹具

2026-10-22。仅新建本目录；未改 special 原目录、冻结候选、integrated 或安装；未启动 JVM/AIR。两个AS文件仅静态校验，不宣称编译或原生测试通过。

## 实际失败和可排除项

准确运行：`build/m52/recovery-special-native-01` / `build/cooperation/e82a41c002`，RC07 `c9f6492117124dea23a6991396cf9957d7b73a9730b747b4c8b1cad9533ca3bc`，driver02 `615475fe33de64615dca49382196375b9aa7ed696954f9f6e6a3c3a7a16a9328`。

round0主侧确实通过正常控制输入产生MSW手动爆炸支路，随后出现独立原生无vis Bullet（不是夹具创建），源端一个真实Part有最终舞台像素。dummy位置681.1390994302682,785.3725011408634；源端RENDER观察at81271。

加入侧在at42507确实收到stream10/seq3的独立`event.explosion`，无flight；其源at81250，type4、water=false、custom为空，位置与dummy相同。**不能直接相减81250和42507来算延迟**，它们来自不同进程。生产已把独立爆炸采到并经TCP送达；加入侧Part=0和像素=0是真失败。

driver02的 ImpactEventQueue / ProjectileVisuals / ProjectileExplosionVisuals 与07源码逐字节相同，排除“测试驱动编进旧接收器”。接收代码在遍历flight前即把独立事件交给队列；type4干地配方会请求`expl/flare/iskr`。原版AllData的expl是blit sprExpl、imp=1、minliv=15；Emitter的总粒子限额只拒绝imp=0，**一般maxParts上限不能单独解释expl消失**。实际运行资料还缺队列cursor、loc身份/active和真正emit前后Part数量，不能据现有日志决定修改门控或补发。

旧夹具只按准备时缓存的visClass/blitData对象身份识别expl，未报告其它Part或缓存身份是否变过。因此Part=0尚不能区分“没创建”和“创建后未被此选择器匹配”；也没有最终RENDER之间的时间样本。下一版保留原严格像素判据，额外记录所有首次见到Part的身份匹配、位置、stage、visible、alpha与bitmap尺寸。该诊断不替代通过判据。

round1加入侧原生首发支路断言失败，未见dummy，最终超时。原日志没有首发explRadius等字段，不能把某一项失败当成已证。但代码存在确定准备竞态：prepare新建/装备枪后立即发prepared，host收到立即go；夹具ENTER_FRAME priority100000会在下一游戏步前设置keyAttack，而MSW的正常priority0 onFrame在游戏步后才调用weapon.apply，将explRadius/destroy/tipDecal置0。主侧round0等待prepared时可能自然经过一次MSW帧，不能保证join round1同样经过。**这是驱动准备缺口，不是当前证据下应改的MSW生产玩法。**

原DONE带rounds/failed，run.py使用精确整行匹配而判done=false。这是额外格式错误；修正它绝不抵消以上原生失败。

## 外部驱动增量

`tests/MSWNoVisualExplosionTestDoc.as`准确从冻结driver02复制：

- 增加preparing状态。源侧在priority-1的真实ENTER_FRAME后，只读确认MSW已把本次拥有且装备的枪设为explRadius/destroy/tipDecal=0、noTrass=true、速度/重力与MSW实际配置一致；然后才发送ready。两侧都ready，host才go。
- 发出第一次真实控制输入前再检查这些实际字段，且要求经过下一游戏帧；失败直接记错，不重复Q、不改武器参数、不手动调用MSW apply、shoot/explosion/step/生产receive/tick/clock。
- 保留原生两轮、30秒运行超时、2.5秒观察窗口、所有像素/数量/位置/独立身份断言。首发保存primary实际字段供归因。
- 保存最多256条只读观察，满后记dropped，不在逐帧观察中写盘；finish一次导出。保持原来的关键事件日志。
- DONE恢复精确`COOP EFFECTS DONE msw-no-visual host`或`join`；rounds/failed移到独立OBSERVATIONS报告。原FAIL仍完整保留。

## 独立队列诊断副本

`diagnostic-src/rconnect/game/ImpactEventQueue.as`准确从07复制，只增加默认关闭的观察接口。必须单独构建诊断候选，不覆盖07或把它称为07原产物。相同驱动动态检测接口：常规07没有接口，记录diagnosticVariant=false；诊断副本才开启，finish关闭并导出。

有界128条标量环形缓冲记录receive、100ms限频的wait、play-before/play-after和丢弃理由；包括actual getTimer、原生产effective now、**实际sourceTime getter**、事件at、来源main身份/类、motion身份、loc与当前loc同一性/active、pauseAt、Emitter配方/粒子数量、原生play前后Part数及差值。读取sourceTime不调用sample/settle，不改时钟。缓冲区不保存游戏对象；身份表为弱键。

实际ProjectileExplosionVisuals.play保持原来顺序并位于诊断异常处理之外，原异常照常传播；不增加retry、不绕过Emitter.active/限额、不伪造命中、不接触伤害。观察自身取值失败仅记diagnosticError，不把它伪装成生产成功。粒子链计数只在真正play前后、诊断开启时发生；因此该副本只能作功能归因，不作性能验收。

下一轮按记录分支行动：

1. raw wire有而队列receive无：查Session/room过滤，不能先改Emitter。
2. receive有而长期wait：以实际cursor、eventAt和pause/loc记录定位，不用估算时钟补偿。
3. drop：按真实异房/超时/源过期/容量理由检查，不放宽全局期限。
4. play有、newParts=0：查真实active、配方、worldLocSame；expl imp1已使普通粒子上限假设较弱。
5. newParts>0但夹具expl=0：查只读Part类别/bitmap身份/渲染时间，修选择器前证明对应原生爆炸身份，不按“任意Part”放宽。

## 父会话接入与未做事项

已追加 `native_tool.py`，沿用special-impact的薄适配方式，只在本进程登记专用入口，复用原来的 `recovery-tests/prepare.py` / `run.py`。驱动只替换本目录的一份AS，保持生产源来自所指定的准确冻结候选。常规模式可用于07或08，不限制版本名称，但必须是 `build/m52` 中已编译且源码清单、SWF指纹相符的完整候选。运行仍执行既有双侧22项实际加载核验、准确candidate/driver绑定、原始FAIL与错误扫描、两轮覆盖和精确DONE，不新增宽松判据。

下列命令供主会话在 `mods/RConnect` 中串行调用，**本次没有执行**。目录名仅示例，须使用尚不存在的新目录；旧失败目录不会被覆盖。省略 `--build` 只冻结文本和输入，不启动编译器；该适配器不原地续编已存在输出，重新准备时用新目录。

```powershell
$py = 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
$tool = 'experimental/recovery-special-native-followup/native_tool.py'
& $py -B -X utf8 $tool prepare --source build/m52/recovery-07/src --output build/m52/recovery-special-followup-driver-01 --build
& $py -B -X utf8 $tool run --drivers build/m52/recovery-special-followup-driver-01 --output build/m52/recovery-special-followup-native-01 --entry MSWNoVisualExplosionTestDoc
```

要对08进行常规检查，第一条的 `--source` 换成其冻结src，并使用新输出名。`run --control` 仅适用于常规驱动，仍使用框架固定574D负对照与同一驱动字节。

诊断分两步准备，先编译独立候选，再为其编译准确绑定的驱动：

```powershell
& $py -B -X utf8 $tool diag-prepare --source build/m52/recovery-07/src --output build/m52/recovery-special-queue-diag-01 --build
& $py -B -X utf8 $tool prepare --source build/m52/recovery-special-queue-diag-01/src --output build/m52/recovery-special-queue-diag-driver-01 --build
& $py -B -X utf8 $tool run --drivers build/m52/recovery-special-queue-diag-driver-01 --output build/m52/recovery-special-queue-diag-native-01 --entry MSWNoVisualExplosionTestDoc
```

`diagnostic_candidate.py`只把指定候选的ImpactEventQueue替换为本目录诊断覆盖，其余源码和既有GameCombatStubs逐字节复制。**替换前要求队列仍与07准确基线相同**；若08已改该文件，明确停止，先重审/重做诊断覆盖，不能抹掉08修改。所有源、脚本、编译工具与原候选指纹被冻结；取得共享game登记后、编译前后再次核对。编译只写新目录，用原生 `RConnectDoc.as` 入口和既有AIR编译选项；JVM受登记管理，超时仅终止自有编译进程，保留原日志。准备前后检查22项安装不变，不写release、不部署、不启动AIR。

常规原生运行完全沿用框架资格。诊断原生运行另存 `framework-result.json` 原始检查结果，`result.json` 与控制台总是 `passed:false / native_game_pass:false / production_qualified:false`；`diagnostic_checks_passed`独立表示本轮检查是否成功。诊断模式退出码0只表示诊断检查成功，**不能按退出码把候选算为生产合格**；诊断检查失败仍退出非0、原FAIL和例外保留。禁止诊断驱动加 `--control`，避免把无探针控制轮错误标为诊断轮。

`offline-checks.json`记录本次9项离线检查：两个Python文件解析、准确07输入只读核验、两份AS指纹不变、常规/诊断各自成功与失败分支、诊断控制拒绝、helper变化拒绝。运行器用假对象代替且禁止创建子进程；这证明包装与资格区分，不证明编译或游戏行为。没有调用JVM/AIR，未创建任何build目录。

常规轮证明正常候选行为；诊断轮解释失败，双方资格独立。两者都保留严格assertions、超时、像素与原始FAIL。若后续要修生产，至少共用反例覆盖重复独立爆炸只播一次、无vis且真实isExpl才产生事件、同弹普通impact和爆炸各自一次、暂停/离房不失去待播或串房、接收端不生成伤害Bullet。

目前未确认一个可据此直接改07生产行为的根因，因此本目录没有生产功能修正。

## driver03 编译失败后的单点修正

`build/m52/recovery-special-driver-03/compile.log`保留原失败：驱动第109行对普通类RConnectMod访问不存在的loaderInfo，未启动AIR。已只把查找改成驱动Sprite的 `this.loaderInfo.applicationDomain`。核对该轮冻结harness：先取得production Loader的domain，再用 `new ApplicationDomain(domain)`加载EffectsDriver，因此这里能继承准确生产候选的ImpactEventQueue；游戏main域不能反向查子域，未改成main域。核对生产入口RConnectDoc是Sprite，而RConnectMod是普通类。

相对driver03的测试AS只有该表达式和两行说明发生变化，Python配方、队列覆盖、动作和断言不变。manifest已更新新AS指纹；原9项离线结果仍是此前配方检查的历史记录，不代表本次AS已编译。下一轮使用新driver04目录；本次未执行JVM/AIR。
