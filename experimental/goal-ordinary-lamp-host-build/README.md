# 普通房灯具首绘：三方法宿主构建接线

仅准备隔离构建。基底是已经构建并通过原生加载界面回归的 `goal-native-loading-host-03/pfe.swf`（2DB0B4EB）与其实际 `final.xml`（C20F3569）。当前游戏安装仍是 A796；准备回执分别记下这两个指纹，不能把安装版说成 2DB0。

首个 `goal-ordinary-lamp-host-01` 已实际在 import 阶段失败，没有新宿主：旧 `sceneDrawSteps` 的反编译水循环含 `§§findproperty`。同一原文件的 `sceneEntitySameColor` 另有三处 `§§push/pop`。本次只在供体导入副本复用已验证的 A796 清理：两条循环自增恢复为 `j++/i++`，颜色方法使用原 `source-equivalent.as.inc` 合法源码。清理前后逐字核对三目标方法相同，其他方法只允许这两个非目标方法不同；最终 ABC 仍从 2DB0 保留它们的原始字节，没有把整理体带入最终宿主。

host01 原输出保持原样；其执行时三文件已完整保存在本目录 `host01-build.py.txt`（A7BCE8）、`host01-retain.py.txt`（F34F62）、`host01-README.md.txt`（03F59E）。准备阶段另存 `donor-only.diff`、`donor-source.json` 并把供体指纹和目标方法指纹放入 `prepared.json`。当前 `--verify` 不用于重标旧失败配方。首轮 FFDec 自身日志文件权限错误同样保留，原 SEVERE 检查不删、不豁免。

host02 的 import 和 donor XML 已真实成功且无 SEVERE，随后严格证明器在 `drawLoc` 的 pc3723 遇到尚未支持的 LOOKUPSWITCH 而失败。旧失败回执保持，执行时源码已保存为本目录 `host02-*.txt`，SHA分别为 5AD0DDBD / F34F62F0 / 75165F96。新默认输出 host03；供体源码仍为 FBBC2B32，三个目标方法没有再次修改。

导入源只读借用 `goal-ordinary-lamp-first-raster-candidate`，清单 09DB44FE、冻结记录 35D4613F、Grafon EEEDEA03。此候选源的原始 Grafon 是准确 A796；host03 的既有保留回执证明其改动全在 World，因此本次 Grafon 基底仍相同。

保留器只取供体的 `Grafon.drawLoc` 和新增私有方法 `beginOrdinaryLampRaster`、`completeOrdinaryLampRaster`。没有新字段、类、构造器或静态初始化器。其余原方法（包括全部 World/UI 方法）、旧成员、类头、脚本表和非 ABC0 原始资源逐项保留。旧常量前缀、私有命名空间绑定、activation/catch 槽来源、异常区间和序列化往返检查继续使用已审过的实现；未知指令仍会失败。drawLoc 只有 NEED_ACTIVATION 标志可以随实际方法体改变，其余签名元数据保留。

`retain.py` 对冻结 `retain_v2.py` 做四处精确、计数唯一的私有源码适配：关闭旧静态字段写入、把两个固定添加数量改为本次确切集合长度、增加新方法必须属于原 Grafon 私有命名空间的检查。目标集合固定为上述三个方法，不是通用移植器。`build.py` 复用原六步构建函数，只改输出前缀、准确安装版检查与说明标签；`--print-diff` 直接输出这两份真实内存适配差分，不写文件。

槽来源证明的 `in` 适配：新助手的 `in` 对应 AVM2 `0xb4`，弹出两个操作数、压入一个 Boolean，因此按 `replace(2)` 处理，不会把结果误认作 activation/catch 对象。依据是当前 `ContinuousScene/build/native-crop-audit.py:125` 的无立即数解码表，以及实际 FFDec `lib/ffdec_lib.jar`（2A9DFD3D…64B4F2）中的 `com/jpexs/decompiler/flash/abc/avm2/instructions/other/InIns.class`（A5154CDE…8B8EAF1）：构造指令含 `sipush 0x00b4`，`getStackPopCount` 完整 Code 为 `05ac`（返回2），`getStackPushCount` 为 `04ac`（返回1）。共用证明器不改，`--print-diff` 输出私有副本的全部差分。

host03 只再补 LOOKUPSWITCH 的控制流分析。沿用原 `core.decode` 已解析和校验的绝对目标（默认目标及 count+1 个 case）；弹出一个 selector，把相同后栈/局部变量/作用域状态传给所有目标，不隐含顺序落空。原异常入口、槽来源、合流栈高和容量判断全部保留，其余未知指令仍拒绝。真实 host02 donor 的 `drawLoc` method3283（code SHA827CC21B）在 pc3723 有 default3731 / case0=3704；前者正常返回，后者取出保存的异常并重抛，二者均先执行 pc3719 的 complete 调用。

只读离线核验已实际完成：9个小字节码正反例覆盖默认非紧邻目标、没有隐含落空、三个分支分别出现未知槽、合流栈高不一致、坏目标、selector 下溢、其他未知指令拒绝及 b4 保留。使用真实 host02 donor 的完整三个方法再跑原证明：drawLoc 1703条指令/228处槽/5个异常区，begin 137/21/1，complete 60/8/1，全部通过。没有修改字节码，没有运行 Java/AIR；最终序列化产物仍须完整保留审计与原生验证。

六步仍为 import → donor XML → retained XML 序列化 → 最终 XML → 实际 AS → 实际 P-code。只有显式 `--build` 才启动 Java；共享 game 登记、每步 1 GiB 提交余量、512 MiB 运行保护、300 秒限时、隐藏窗口、自有子进程回收、前后完整 22 项安装核验及失败回执均沿用原实现。输入/输出不可覆盖，失败目录必须保留。这里不启动 AIR、不部署、不写 LAD/正式游戏，不复制已有大 XML 或 SWF到 experimental。

命令从游戏根执行（`<python>` 使用现有 Python 路径）：

```powershell
& <python> mods/RConnect/experimental/goal-ordinary-lamp-host-build/build.py --check
& <python> mods/RConnect/experimental/goal-ordinary-lamp-host-build/build.py --print-diff
& <python> mods/RConnect/experimental/goal-ordinary-lamp-host-build/build.py --prepare --output build/m52/goal-ordinary-lamp-host-03
& <python> mods/RConnect/experimental/goal-ordinary-lamp-host-build/build.py --build --output build/m52/goal-ordinary-lamp-host-03 --registry-wait 900
& <python> mods/RConnect/experimental/goal-ordinary-lamp-host-build/build.py --verify --output build/m52/goal-ordinary-lamp-host-03
```

可直接导入 `verify(Path)` 只读核验实际编译结果；不存在真实 build.json 时不会授予资格。当前环境采用原生 UI v2 已核的完整 22 项（RV638E），与 host03 历史 BF4A 环境分开；只承认该已有 RV 部署回执所证明的一项变化。

`build_checks_passed=true` 仅指保留和编译检查通过，`validated/gameplay_qualified/performance_qualified` 始终 false。实际新 drawLoc 的 finally、错误恢复、两私有调用绑定，仍须审查最终 AS/P-code；原生同帧行为、灯具/墙体完整像素、界面与耗时必须由后续真实测试取得。本配方自身没有给这些结果。
