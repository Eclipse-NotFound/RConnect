# RConnect —— 开发记忆入口

> 2026-10-09：**已部署0.2.22-dev。** 正式30完成38组4760/0，旧21对照及正常无驱动启动7ec5eb4ec4通过；155项外部保护指纹不变，最终80个实例描述符均已退出，实际宿主AIR为空。没有运行中的自有测试队列。[部署记录](deployment-m50-2026-10-09.md)。

2026-10-14：按用户要求准备将已部署 A22 原字节同步 GitHub，保持 0.2.22-dev 预发布标记；不含后续 M51/B。详见 [同步记录](github-a22-2026-10-14.md)。

## 1. 模组与职责

RConnect是Remains 1.02双人合作模组，覆盖同地图普通房分头探索、战斗、交互与共享奖励。本轮修复远端假翅膀和枪口/弹道错位，并统一集成效果与合作修复。运行入口为release/RConnectMod.swf。

原RConnect会话01a086bb-378c-7f60-b8e1-50d90ffa0996是唯一合并、构建、游戏测试和部署者。用户允许全部当前/后续RConnect会话协调；R2–R14已交接停写，分叉继承记忆不等于获得部署权。[协调记录](m50-coordination.md)。

## 2. 用户决定与保护边界

- 已授权现有合作功能修复、大幅重构、实机测试与本机候选部署。稳定重连、公网、三人以上、其它版本、新任务/背包/交易同步排除。
- 保留其它程序，不擅自结束或改优先级/亲和性。只用独立AppID/数据测试，不碰玩家存档；仅管理自有PID。WallBlend不发送消息，测试冲突时等待其结束。
- 普通房可分头，无人房暂停并保留本次联机进度；宿主发起整图旅行，剧情/挑战共同进入。退出沿用原版保存，不新增随机房完整战斗存档。
- 地上物品一份、先拾取者获得；XP双方奖励；存档点共同解锁，各自保存。跟随默认关。
- 菜单/SATS任一端可全队暂停，全部关闭才恢复；开关默认关、宿主管理，保留网络/聊天/SATS队列。
- 个人被抓许可默认关，WASD挣脱默认开；友伤默认关、宿主管理，个人投掷伤害默认关。紧凑浮窗280×36，各自30–100%透明度；Ctrl+Enter聊天/F10显隐，原生Enter不变。
- 仅写本模组；游戏本体/描述符/game-reference只读，其它模组必要最小只读；失败证据不覆盖。

## 3. 当前安装与验证

- **0.2.22-dev**：163453B、68类、SHA256 `32602e77a21b206d1f7ff0e927b953878c28254e7201529455818923a3539732`。
- 最终build/m50/final-presentation-30，69源/197验证输入；生产实际编译27。30严格保留37组相同编译/运行输入，跟随4ce63cbedf新跑；38组4760/0、全双端DONE，150张PNG。保留旧运行不等于重新运行。
- 原21负控051e28e849仍产生14假翼/14弹道几何失败；正常全模组、无驱动加载7ec5eb4ec4双端新版本/心跳/握手通过。38组+对照+启动共80实例描述符，实际宿主均退出。
- 快速念力四组110/110/100/90ms；原生容器空中最长停顿0/30ms；SATS停止差及恢复跳变0px。80敌人压力8秒88帧/p95 133ms，仅证明本轮达到原门槛，不保证长局流畅。
- 地形/握持/掉落固定回放新增66/0，Python资产/输入门禁11/0。固定回放不加载游戏档，也不替代实机。
- [M50审计](../knowledge/experiments/m50-validation-evidence.json)、[全部部署与回滚](deployment-m50-2026-10-09.md)、[历史失败](validation-m50-2026-10-09.md)。公开安装包/玩家README仍0.2.8，未推送。

## 4. 本轮实现与判断

- PeerAppearance读取真实翅膀；WeaponDisplay保留原生翻转/后坐/矩阵；角色、武器和实际Bullet帧共享源时间，换枪在途弹保留，接收侧只重放效果。
- 主动持物100ms目标缓冲；普通掉落批次到达时保留轨迹、不跳批末；火焰存续期间保持共用时钟正常速率，全部结束后恢复渐进追赶。TerrainSync先比13字段再分配变化快照，未改同步频率/伤害协议。
- 近战、重型弹、爆炸、命中、火焰/燃烧、墙痕、传送、身体效果、地雷、友伤/投掷和跟随导航均完成正式专项。地雷重返会重新挂当前显示层。
- 正式29跟随仅在准备确认超时；迟监听旧836f19eb50复现、新ec722761a6通过。正式30提前监听/幂等确认与有限阶段重发，原30秒及业务检查不变。[夹具实验](../knowledge/experiments/2026-10-09-follow-fixture-startup.md)。
- 法力断言改为真实持有期扣除，游戏扣费/回蓝不变；原失败没有逐帧法力，解释保留边界。[法力实验](../knowledge/experiments/2026-10-09-peer-grip-mana-observation.md)。
- 旧武器坐标轴零值未复现，新有效性检查正式通过；NativeWindow.visible初始false不等于本机OS窗口隐藏，未采用CREATE_NO_WINDOW/SW_SHOWNORMAL诊断改动。[坐标实验](../knowledge/experiments/2026-10-09-native-coordinate-precondition.md)。

## 5. 已知边界

长局高密度卡顿未证明稳定解决；M43背景门原宿主消失/失控未可靠复现。受控隐藏房往返通过不覆盖全部低频条件。镜像地雷的拾取/拆除/枪击/念力交互、旧Trap/Area #1063、其它#1009与全部NPC/武器/第三方组合仍不能保证。真人鼠标、中文输入法、公网及其它版本未覆盖。

持续火焰保持正常速率可能保留已有积压；没有对缺失数据外推，也不靠降阈值放行。旧23–29失败及所有诊断完整保留，当前绿不反推旧红全已解释。

## 6. 下一步

本轮测试与部署完成，等待用户游玩反馈；无需主动重跑。新反馈先核对实际版本、日志、触发武器/房间，再针对性复现。需要新发行时先建立22安装基线，不复用21→22部署命令或旧基线覆盖结果。

回滚必须双方保存退出后，把 `build/backup/m50-release-20261009-182002-d83866/RConnectMod.before.swf` 复制回release/RConnectMod.swf，再重启；备份SHA `5c372cf5d970212f0fd4e95bea5c0acfaabfe321c3ca531c80ed7e299c2914bd`。M49备份是旧20，不能混用。

## 7. 接续入口与工具

- [journal](journal.md)、[呈现实验](../knowledge/experiments/2026-10-09-m50-peer-presentation.md)、[验证工具](../tools/validation/README.md)。M50原安装基线integration-baseline-0.2.21-native-assets有157条（自身SWF大小写双记录），发行外部保护155条/98原生资产；保持历史原样。
- AIR/amxmlc、SWF38；build_mod默认写release，开发构建务必显式--output到新build目录。loader硬编码app:/mods/Rconnect/release/RConnectMod.swf，大小写怪癖勿改。
- 实际application.xml→根pfe.swf 1.02；app.xml不是启动正本。反编译首选game-reference/decompiled/1.02/src102/scripts。
- Python：C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe，所有父子进程显式-X utf8。
- Java：C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe；SDK D:/RemainsMod/mods/Sandevistan/build/tools/flexsdk，FFDec同tools/ffdec；编译日志可能GB18030。
- 实际宿主CIM核对AIR，失败不可当成空列表。新测试使用唯一目录和原生完整资源/配置；源码或测试变化另建freeze，不改旧清单。
- 本模组git使用build/m43/empty.gitignore、core.safecrlf=false；eclipse/helloimyyt@163.com本地提交，不推送、不改写历史。
