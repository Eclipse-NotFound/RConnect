# 首次绘制前恢复：独立调用序审查

2026-10-24。范围是本目录 RC 移植与准确 roomfix5 / old early2 的差异；沿真实 GameBridge、TravelGuard、World/Game/Grafon 调用顺序检查。没有编译、运行 AIR、修改实现或部署。本页是普通代码审查，不是测试报告或运行资格。

初审为五类，复核时实现方已补两处起步分支，并增加一行 WallImpactVisuals 未绘制门禁，故最终实际范围为六类。复核固定输入：

- `manifest.json`：`a989a74630b7ff4b3bf750b0922a39d9e8d61ad2bf83f776c82ecc28cfa31b56`。
- RoomSync：`dcf929fb066dc1d807c18176cb4a27485604a1582fc6580c8459d27d697c8ccf`。
- MapGeneration：`874cf31c714dab7ce4ba04f795ead2a6b92b9022181120c17f6b97aa6c62e1e0`。
- Session：`f864b203b8758b64cb0ca485a75553f99d7984c9d4a1a66fac0a8210ffe2e062`。
- GameBridge：`ac575c7ff5b6e0c9b75c69916e587b062bd2916235a5f60f21c063eaf31f5ddc`。
- WallImpactVisuals：`12eb9457f753373ea67516702d464aa4ac1266f651d2bc20bb7b50d2b4c80a59`。
- EarlyTravelGate：`544d61b428ca0e3b3daf603eb0a8c8546fc01a64d22834c73f7d90d323f6a814`，沿用 old early2 的实际 Gate 字节。

当前基底为 `build/m52/recovery-room-production-05/src`；旧实现重点为 `experimental/recovery-early-exit-authorization/src/rconnect/core/RoomSync.as` 的 startPreparedMap/completeEarly/cancelEarly，以及 `build/m52/recovery-early-host-01/after/scripts` 的真实 World/Game/Grafon 方法。当前宿主 A796 本身没有 early 桥；本次移植的 native 部分在 `recovery-room-first-raster-host-current`，仍需独立构建/回读，不能用旧宿主通过记录替代。

## Standards

未发现未修复的权限、运行时命名或现有代码约定硬违规。没有把旧 RoomSync 整体覆盖当前版，当前普通分房、barrierRoom/barrierLand、READY 去重、crossedUnchanged、连续过门与跟随暂停计时逻辑仍保留；Sandevistan 使用明确版本与身份的独立许可，不把没有接口当成 idle。

复杂度判断：Gate 保存事务身份/票据，RoomSync 负责暂停与消息，MapGeneration 负责 native/外部接口，分工与这一次加载事务相符。暂不据此要求增加另一套通用框架。`cancelNativeLoading` 的参数没有单独身份筛选，但现有真实 World 调用传的是该 World 当前 `game`，且取消时使用 Gate 的 World/Game/player 身份阻止把旧控制写进新角色；本轮未找到一条真实调用能据此证明旧 Game 异步取消新事务，不将其报为确定缺陷。

## Spec

### 已发现并在源码层关闭的两处遗漏

**1. 成功起步后没有撤销旧的房间暂停，会卡在 t_exit=21。** 初审 RoomSync `6993F3A9…` 的 startPreparedMap 缺少 old early2 第 524–527 行的释放分支。

真实可达顺序：加入侧普通 check 已 `hold → request`，此时 `busy=true / pending=0 / roomHold=true / onPause=true`；主侧先开始整图旅行并送 prepare。armEarly 允许 pending=0，真实 acquireEarly 特意允许由 roomHold 引起的暂停，继而 gotoLand 将 t_exit 设为 21。旧房间 pauseWorld 仍在，RoomSync.before 每帧继续令 onPause=true；nativeLoadingHold 要等 constructed 才返回票据，而 World.step 只有 `!onPause || loadingHold` 才推进 exitStep。于是无法到达 19 的 constructed，最终超时。forceCloseOverlays 只处理界面，不会清普通 roomHold。

实现方现已在成功起步后仅对 `early.active && busy && pending==0` 恢复 savedPause、清 pauseWorld/busy/roomHold，随后仍把目的地标成未确认。已回读当前 DCF929FB 源码，与旧修正一致；没有提前声明旧房间 ready。

**2. 原生拒绝旅行后没有取消已取得的 early 许可。** 同一函数还缺少 old early2 的 `else if(early.active)cancelEarly(true,true)`。真实 Game.gotoLand 会在 dopusk 失败或 speedShtr>=3 时拒绝设置 t_exit；GameBridge.startSharedTravel 因此返回 false。此前已 arm/acquire 的加入侧会占着许可并反复重试，主侧也可能等到 45 秒。

当前失败分支已补回，回到普通流程并通知另一侧释放未完成优化。只在 early 已激活时触发，普通加载返回值语义不变。

两项修正均为**源码复核关闭，动态验证未关闭**。现有 room 组件的 GameBridge.startSharedTravel 固定返回 true，且旧 36 项入口未从 busy/pending=0 起步；不能用它们的历史通过数声称这两项已验。已直接同步实现方和根会话，要求补具体边界用例或保留待验证。

### 按调用序确认的行为

1. **协商与范围**：仅共同合并地图、双方 native 能力、有效场景渲染模式及真实 Sand idle 许可成立时 arm。一般房间门、同图分房不走 prepareMap/openFirstRaster 事务；缺能力或拒绝许可沿原加载。Session 的 hello/welcome 字段仅广告 native 能力，真正外部许可仍在起步时取得。
2. **构造到封存**：prepare 先固定 earlyId/起始 epoch；sceneOpen 获取同一 World/Game/player/Land/Location/renderer 票据。Game.enterToCurLand 的 constructed 必须在原生成、激活、出生和进入副作用之后。nativeConstructed 的 hold/controlOff 发生在同一调用栈内；World.exitStep 返回后再次检查 loadingHold，从而本帧不继续 Land/脚本步进。该结论依赖当前 native 移植保留这两个调用位置。
3. **退出许可**：grant 恢复之后只 allowPaint，不执行 TravelGuard.endTravel。要等原生 t_exit=0、至少下一帧、真实栅格 unpainted=false、sceneViewReady，再 ACK/activate；completeEarly 才结束退出许可并补被抑制的 controlOn。避免了 early1 在缓存重访时提前清许可的旧死锁。当前 TravelGuard 是 roomfix5 的单参数接口，没有拿旧双参数替身掩盖调用。
4. **旧/重复消息**：不匹配 earlyId 的顶层包直接忽略；active 时无/旧 id 的 seal 不能通过 acceptSeal。相同 seal 重复只复核 barrier/epoch/anchor，已发 READY 不重发；不同锚点会失败关闭。已 allowPaint 的重复 READY/grant 被忽略，旧 ACK/activate 不满足身份条件不能解冻。完成后旧 early token 也不能重复导入或 controlOn。普通消息路线保留当前基线行为，没有扩大为任意历史包的通用去重。
5. **普通分房与未移动的房间所有者**：无 early 事务时 begin 的 `hold(!ready || !currentSettledRoom())`、sendReady 的 keepOwner、commit 的 barrierRoom/scoped 路径未被替换；未移动的 owner 仍可运行。early 的两端暂停只覆盖整图共同旅程，不借此冻结另一人的一般过门。
6. **断开、死亡与换档**：断开 reset 以 disconnect=true 释放本事务；相同存活 player 才补控制，World/Game/player 置换或 t_die/comLoad/ng_wait 不把旧 pause/control 写回新角色。恢复后但未 activate 的普通取消保持失败关闭，不能由取消包暴露半完成状态。死亡/换档用例目前证明的是本端身份和租约撤销，未证明另一端自动恢复整次旅行；需要断开重试的失败关闭语义不应写成双端自动恢复。
7. **同一帧与首绘**：waiting 贯穿完整 checkpoint 恢复、必要 redrawLoc 与落点放置。allowPaint 之后 nativeFrame 必须增长，且栅格/退出条件都成立，才会在 RENDER 里 finishFirstRaster。firstRaster ticket 在同一 room 的 redraw 中复用，不能因调用 redrawLoc 提前放开。新增 WallImpactVisuals 门禁在 unpainted 时拒绝读取/写入 frontBmp，避免将未绘制暂存位图当成最终画面。

### 未授予的资格

- 上述是调用序审查，不是同帧画面截图验证。真实 Grafon、World、Game 与 Sand 接口接通、异常时的资源释放、缓存 Land 的引用寿命、同 Session 第二次同种子旅行以及 45 秒真实超时仍需原生验证。
- 现有组件使用真实 RoomSync/Gate，MapGeneration、Session、GameBridge 等仍有替身；不能证明真实许可、网络协商、完整恢复或首绘像素。预计原 227 项与新增边界用例应分别记账，未运行不写通过。
- roomfix5 的 WallImpactVisuals 仍基于 frontBmp；它没有旧 early 大包中的 WallSurfaceBridge/resident surface 支持。本次新增一行门禁避免未绘制时使用暂存位图，但 `finishFirstRaster → _wall.redraw` 不因此取得“大图所有墙痕首帧可见”的资格。它属于当前既有显示边界，不要求本轮顺便重写墙痕架构。
- 旧 early2 原生三程通过只说明历史组合功能跑通，未证明当前 A796/新 RV/当前 RC 移植或整体耗时。普通分房/背景门回归仍须保留。

轴向结论：Standards 当前无确定违规；Spec 发现两处起步遗漏，当前源码已修正，无新增确认的开放代码阻断，组件和原生验证仍待完成。

## 后续复核：新增起步组件与隔离输入接线

本节为同日后续只读复核，不回写上面的初审时间点，也不改动既有三轮对照报告。未启动 Python 验证入口、JVM 或 AIR。

已回读 `build/m52/recovery-room-first-raster-port-current-02` 的真实测试入口、冻结源码、`intent.json`、`component-result.json` 与最终 `receipt.json`。该入口使用当前 DCF929FB RoomSync 和 544D61B4 Gate，明确从普通 request 的 `busy/pending=0` 起步，另用返回 false 的 GameBridge 子类覆盖原生拒绝分支；12 条断言全部通过，进程退出 0。故前文两处遗漏已取得**组件行为验证**，不再仅有源码修正；仍未证明真实 native `exitStep/gotoLand`、外部 Sand 许可或两端整图耗时。`process.json` 是启动时的未完成快照，最终状态以 receipt 和组件输出为准，不能把其中初始 `passed=false` 当作运行失败。墙面新增组件同样有 12 项通过，只验证自身声明的 BitmapData 范围。

本轮接线审查固定输入：

- `../recovery-room-current-comparison/run.py`：`357b29cef98ca8f45869f7c37a8f4a78da0a0ef8d009b7030daca971d1325e08`。
- `../recovery-room-current-comparison/bridge_inputs.py`：`89bd7e5508a211c67789497c6a358348b0c3ee22bb8916f3527902c7e1dd1ddf`。
- 未改动的共享 `tools/run_coop_regression.py`：`7eca453b13480140da5f36bb33d2319739a927562ccafdbb61a8b20cdb5ae4d3`。

确认并已关闭一个 API 文件名接线问题：宿主 builder 的 `verify(output)` 返回 `build.json` 的内容，并不生成 `receipt.json`；最初 adapter 额外固定后者会导致非默认预检失败。当前已改为固定 `build.json`，与真实 builder 第 115–129 行一致。两个 builder 的 verify 均核冻结源、编译回执与产物，导入没有运行构建入口；RC adapter 还单独要求 compile.json 存在，不能把仅 prepare 的目录当作可运行产品。

沿共享入口实际调用顺序确认如下：

1. `--raster-host` 只能取 RConnect 的 m52 子目录，宿主 builder 进一步限制专用目录名前缀与准确 A796 基底。只有显式 `--sandy-bridge` 才加载固定 Sand003/3E220B59；无宿主却要求 Sand 的组合在创建运行输出、登记或启动前拒绝。未添加自动安装或替换正式文件的路径。
2. Sand 注入只替换所加载 runner 模块自己的 `shutil` 名称，不修改 Python 全局 shutil。代理只接受正式 CEC6 Sand 源到本轮 `frozen/mods/Sandevistan/release/SandevistanMod.swf` 的唯一复制，复制前验证源与 003 目标哈希；其余复制仍调用原方法。接着原 runner 从同一 frozen 复制两端，确保两端字节一致。宿主使用原生支持的 `--game-candidate`，没有另造进程入口。
3. 原 runner 在完成替换和两端副本后计算 `input.json` 的 game、production、driver、harness、modules；因此它们会记录实际新宿主、RC 产品与 Sand003，而非将历史驱动产物或正式安装清单冒充实际输入。intent 分别保留当前正式 22 项和历史驱动/产品来源；最终断言按真实选择分别比较候选与正式文件。
4. 两端描述符与 input.json 先完整产生，第一次 before_launch 才添加两端独立 AppData 的 CS 偏好及副本内 telemetry。路径检查、独占创建、唯一 AppID、原 input 哈希和 supplemental-input 均保留；在第一次原 before_launch 被调用前，两端设置均已完成。新接线没有碰正式 AppData 设置。
5. 共享登记、启动前独占、双人 6 GiB/单人 3 GiB 内存门槛、运行期 512 MiB 下限、外来 AIR 检查、所有模组错误扫描、三程原断言和退出收尸保持原实现。副本清理仍在原 runner 的 finally；child_stopped 包装在原进程已停止后检查设置，检查失败也调用原 stopped，并令外层最终结果失败。
6. 内层 finally 恢复两个登记回调及 runner.shutil；外层 finally 恢复 sys.argv、run_registered、shutil，复核正式 22 项与所有固定输入，并写 result.json。新 constructed/activated 断言仅在双人、roomload1、新宿主和 Sand 同时启用时要求两次事务完整闭合，没有取消三程尺寸、种子、位置与原日志断言。

异常边界：冻结输入阶段位于共享 runner 原有的进程清理 try 之前；若复制或输入校验此时失败，尚无 AIR，但可能留下本轮 frozen 证据目录。新 adapter 没有扩大删除范围或声称该阶段必然清理；正式文件最终核对和外层失败回执仍会执行。组件回执与本次代码审查均不授予整机性能资格。根会话仍需在新宿主构建完成后执行带两个可选参数的真实预检，再启动原生三程；本次复核未发现新的开放阻断。

## 宿主 donor02：本地槽、作用域与 Game 尾插复核

新宿主 02 的导入和 donor 导出已经完成，旧 retain 随后拒绝未经证明的 slot 指令。此节只读取准确 donor/基底，用 Python 在内存中解码和验证，没有重新启动 JVM、AIR，也没有修改任何 XML、实现或构建证据。

固定输入为 donor02 `7782b131496f38f47ef8ef5e702a504641b1c61603f08a72fdb352923ea9ac4f`、A796 XML `1d2642c7d55d1f97121738e6ae84996a140ebfeff686e6706c88cef82a7338da`、`activation_slots.py` `3d83359870b024faf6761676decd7822bfd4ec06e9df20160ff38887e5ced7e2`、`retain_v2.py` `1811657e117327c018536667fbca59a13be9e54448578361adc44ac4e795be55`。

### 槽接收者确实来自本次调用

独立解码全部 13 个目标及新增方法，当前 CFG 证明逐项通过。World.step / exitStep 各只有 2 次 catch 槽访问；sceneOpen 有 33 次 activation 槽访问及 2 次 catch 槽访问；drawLoc 为 202 次 activation 及 6 次 catch。其余方法没有 getslot/setslot。没有 newfunction、callmethod、callstatic、newclass、getouterscope 或全局槽操作。

指令实际关系为：函数先把 this 压入本地作用域，再 newactivation 保存至局部寄存器并压入本地作用域，所以 getscopeobject 1 得到本次 activation。异常入口重新压入 this 和该 activation，newcatch 后通过 dup/setlocal/dup/pushscope/swap 保存异常对象；这时 getscopeobject 2 得到当前 catch，对其 slot 1 的读写不是游戏实体字段。sceneOpen 的 activation 明确声明 6 槽，drawLoc 明确声明 19 槽；这些 trait 随对应 body 整体保留。

证明器沿真实控制流和异常边追踪对象来源，不确定的合流降为 unknown；只有 activation 中明确声明的槽及本方法 newcatch 的异常槽 1 可以通过。另在内存中构造四项反例：this 替代 activation、读取不存在的第 7 槽、this 替代 catch，以及 getouterscope，均被明确拒绝。原 donor 文件未变。这支持的是当前方法集合，不能据此宽放其他方法的任意 slot。

### scope 数字不是类捕获链的替代品

sceneOpen 由无 activation 的 init/max=4/5 变成有 activation 的 5/10；World 两个新增简单 helper 为 4/5，不能因为同类 step 是 5/10 就强行改成 5。已重新核对 [Adobe MethodInfo 的容量计算](https://github.com/adobe/avmplus/blob/master/core/MethodInfo.cpp#L643-L655)：本地 scope 容量取 max-init。另核对 [Verifier 的本地 scope 访问](https://github.com/adobe/avmplus/blob/master/core/Verifier.cpp#L1989-L2024)和[异常入口重置](https://github.com/adobe/avmplus/blob/master/core/Verifier.cpp#L919-L943)：getscopeobject 使用本地编号，外层捕获由独立链处理，异常入口重置本地 scope。

实际证明得到有 activation 方法本地峰值均为 3，容量为 5（World/sceneOpen）或 9（drawLoc）；简单 helper 峰值 1、容量 1。保留 donor 的 frame、NEED_ACTIVATION、activation traits 和异常表，同时保留原类/脚本声明与捕获流程，有静态依据；单独把 init 数字改回旧值反而没有必要。仍需最终 ABC 回读和当前 AIR 验证。

### Game 只插入准确通知尾部

Game 的 E4X 私有词法集合由 donor 重建，不能仅靠名称猜测旧 165 与新 183 等价。本次因此单独保留 A796 `enterToCurLand` 的原 body 前缀，只从 donor 取准确 9 条 constructed 通知尾部；其他七个旧方法继续上述有边界的 body 移植。

已在内存中调用 game_body 并独立逐条对照：原 body 659 字节，前 658 字节及 277 条指令完全一致；20 条原跳转的最大目标是 646，全部小于插入点 658，原分支无需重定位。原来只有末尾一个 return，无 exception 或 activation 区域。尾部的条件分支从新偏移 662 正确跳到 678 的 return；callback 接收者为明确 public QName，事件字符串为 constructed，参数为事件、this、null。尾部峰值为 4，原 max_stack=6 足够，原 frame 不变。新 body 679 字节，代码 SHA 为 `993fabfe255a1dc29ed8f44cf0f96aef1c39bb49191d63e827f75989bc1f74ac`。

这条尾插不跳过原生成、出生和进入副作用，也不会把异常退出当成成功 constructed。将所有八个方法重改成指令级插入需要额外编辑并重定位 World 条件分支和异常地址，当前没有证据表明这样比已证明接收者的窄移植更稳妥；Game 的特殊词法问题用单独尾插解决即可。此刻 v2 构建入口尚未落盘，其回执/API、最终产物和实际原生运行不在本节通过范围内。

### v2 构建入口完成后的复核

后续入口冻结为 `build_v2.py` SHA `b53dcaab3e301a9d27940300d4be71807649d060adaf00bbbbc267f081f7a749`，`v2-manifest.json` SHA `8e4ac01b04bf0e4a821335134ef5ab22c876fd176b4204fcb003e6e0857143c5`。已只读导入并调用 donor()/pins()，实际返回 58 项固定输入；没有调用 build、prepare 或 verify 未完成产物，也没有启动 JVM/AIR。

donor() 精确固定 02 的 build.json `660871ac69348fb0f08b43629377f28a34e953452dfb9881775837d7a1991383`，要求它是已编译但未 validated 的原 slot 阻断，而非把失败改成通过。两条历史 import/donor-xml 命令的名称、完整参数、0 退出和 reaped、冻结 import 源、prepared 回执、所有实际 artifact 哈希及前后安装一致均核对。真正复用的是这两条已完成命令及准确 donor SWF/XML；后续槽证明独立保存在 v2 输入中。

新 build 只在共享登记内执行 serialize、final-xml、readback、pcode 四条 FFDec 命令；仍保留 1 GiB 启动门槛、512 MiB Java 上限、wait_owned 的超时/内存控制、隐藏启动及 finally kill/wait/登记释放。每条调用前重新核输入与安装。serialize 后精确拼回原始资源标签，final-xml 后比较完整保留树；readback/pcode 必须产出三类对应文件。回执记录真实四条结果与独立历史两条来源，finally 即便失败也保存前后安装、输入和产物证据。

verify(output) 是正确的只读接口，返回 build.json 内容；它不调用编译，而是拒绝未完成或失败产物，要求四条参数准确且成功回收、原 donor 身份仍相同、实际 pfe 哈希、method-audit/retain/splice 文件及字段吻合、完整保留树往返相等、原始资源保持。它继续拒绝把该静态构建标成 native/gameplay/performance 已通过。新 comparison adapter 必须显式加载这个 v2 verifier，旧六命令 verifier 无需放宽。入口代码与只读 API 未发现开放阻断；四条实际新命令及最终 readback 当时尚未完成，不能用本节替代其结果。

## 显式阶段观测分支复核

当前 `current-comparison/run.py` SHA `fe35fed22c18474303ba1be2930f9f6986cf7260ee981a1029306198f071d192`；诊断 prepare.py SHA `e05269d1f5947c0f4d34f764a5392fd0fcb00d817656ea30b32e00fd62748371`。只读调用真实 `verify()`，driver-02 返回 verified/scene_only=true，核对 108 项源输入，驱动 `4fc27436aba55989c097abb72082e5b63121f9fc980fb9aa3789842d69875b4a`，原 Harness 仍为 D52EF430。未读取运行中的 native-diagnostic-02 结果，未调用构建或 AIR。

新增分支要求明确传入 `--diagnostic-driver`，且必须双人、指定宿主桥和 Sand 桥；产品必须与诊断编译实际产品一致。prepare 的 verify 没有编译副作用，精确核对原 Timing/Scene 源字节、Harness、当前产品及安装、唯一编译命令/回收结果、复制源文件和 SWF 哈希。入口在预检、AIR 前与 finally 再验证这些证据。原共享 runner SHA、3/6 GiB 启动门槛、512 MiB 运行保护、独占、私有设置、三程动作/断言和退出清理保持；新增四节点检查在原检查之后，不能替代或放宽原检查。

沿实际调用核对：观察包装先准确调用原 raster callback 一次，再记录它返回的同一个 ticket；不吞掉原 callback 的异常，不自行释放等待、不执行 checkpoint 或 restore。消息前后取样以同一事件对象配对，只有 waiting 真正解除才记录授权。RENDER 取样读取至多四份 surface 引用，并在事务结束或 finish 中移除监听、恢复自己持有的 callback。准确 host03 回读中的 `sceneViewReady()`、`sceneViewport()`、`sceneSurfaces()` 只检查/返回当前信息，不触发绘制或预热；观察器没有借这些 getter 推进场景。

driver-02 相对 driver-01 仅把快照中的房间身份从 `mod.game.roomKey()` 改为 `mod.game.roomKey(refs.loc)`，避免 ticket 刚建立而模块缓存仍指旧 rbl 时误报。当前 verifier 因这项有意改源拒绝旧 driver-01；这是历史源不再与当前源相同，不等于旧轮运行中发生漂移。主会话说明旧轮已完整结束、原 41 检查通过而额外身份检查失败后才修源重编；旧失败不改判，本节不把它当成成功观测证据。

这项分支未发现阻止当前限定试跑的代码问题。观察器本身会增加少量取样与事件处理成本，输出已明确 `diagnosticOnly=true / performanceQualified=false`；即使阶段检查通过，也只证明本次四个原生边界及抽样缓冲区关系，不证明 GPU 完成、逐像素等价、整张地图只画一次或稳定游玩性能。当前原生及性能结果仍以各轮已结束的独立回执为准。
