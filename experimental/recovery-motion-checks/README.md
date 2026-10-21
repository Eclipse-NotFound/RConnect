# 快速弹体采集：语义审计与独立组件

2026-10-21。本目录由 native_loading_fix 子任务维护；生产由主会话与 wall_impact_fix 独占。初始交付仅静态检查；随后获主会话委托，按共享登记编译并运行独立组件，结果保存在 build/m52/recovery-capture-*。不改生产或安装版。

## 实际检查的调用链

`GameBridge.onAfterFrame / onVisForceFrame → UnitPresentation.observe / observeFinal → Session.broadcastWorldState → readEnemyMotion → captureEffects → TcpLink.send / BinaryMessageCodec → applyEnemyMotion → ProjectileVisuals.receive → tick`。

仍保留200ms全量 `readUnitsSnapshot → capture → applyUnitsSync`。发送 Timer 与原生显示帧不是同一个事件；`_sampleAt` 在一帧内不变，RENDER 可用同 stamp 替换前面的真实显示点。组件覆盖这种合法调用顺序，**尚未测得实际游戏中 Timer 落在两次观察之间的频率**。

原 recovery-motion 审计来源：

- UnitPresentation：`66b39598ce965a4c75a7dadc7085b0bb5a956ca758f9f60004d2a5b19de58e0e`
- ProjectileVisuals：`a93ff907e8d41d2606d1bd73dad3850ae480b00b93354692d4a8855425e24d09`
- ProjectileFrameStream：`b737793e702511d5d3eda2cfbe9cbaec9de3b13eb478fbb45c68724802205ab5`
- GameBridge：`9c222bc99a490d5a1038f2e58c8a5b7acc2cb5b99736c1acbc2a977d1741c5d1`

## 发现及处理边界

1. **普通弹真实结束不能到达既有视觉记录。** 新快速通道会在普通 NPC 子弹尚未命中时发首包；原 receive 对同seq非beam完全不更新。随后200ms全量包的真实终点也无效，子弹可能继续穿过已命中的敌人直到碰墙或2.5秒。已即时报告。最初的 bornAt/stopAt 解析路径仍有 age*30 假定帧率、终点到达后重缩整条路径回跳的问题；集成最终将普通 NPC 弹也改为真实原生显示帧。新增10FPS、迟到终点测试：无后续确认点时保持，段内不超真实轨迹，收到迟到终点不后退。recovery-capture-03 的采集组件已通过，原生和网络整链仍待验证。
2. **同 stamp 最终点丢更正。** after 只取 at>fastAt；RENDER 替换同 stamp 的位置、帧或缩放后没有快速更正。集成所有者已补修订检查。对象地址本身不能区分真变化与每次重建的同值点；已进一步报告，当前集成改用 samePoint 字段比较。组件同时覆盖真更正和同值不重复发。
3. **死亡后可能持有停止推进的旧时钟。** applyUnitsSync 删除 `_unitMotion[target]` 后传 null；原 receive 更新既有记录却不替换它保存的 motion。仍在飞行的弹体会持有被冻结的旧时钟，可能停至15秒清理。已即时交集成所有者。集成已增加 receiveClock/sourceTime/shiftClock，覆盖弹体和命中队列；组件验证已存在弹体的时钟交接，队列原生整链仍待实测。
4. **确认命中并不等于弹体结束。** 原 captureEffects 没有 impacts；本次集成已增加真实命中队列和 energy captureDelta。必须保留“确认的原生 Part/命中证据”，不能以视觉预测碰墙替代。组件的命中采集端是明确替身，仅验证已确认事件能传出、晚于更高seq到达仍触发一次；真实命中匹配由原生用例另验。
5. **低seq后变可见仍可能丢。** 第1发首次vis=null而第2发先发送；第1发稍后获得vis，captureEffects会补发，但 channel.last 已为2，原接收端将第1发当重复。200ms累计包也不会自动修复。集成已改为有界已收序号集合。未证明原生 Bullet 具体何时有“无vis后恢复vis”，不把夹具可构造当用户复现；组件保留此边界断言。
6. **死亡快速通道仍被 GameBridge 双端过滤。** 采集器可直接采死者剩余弹体，但 readEnemyMotion / applyEnemyMotion 都跳过sost>=3；死者尾段仍依赖全量通道。组件直接调用死者采集通过不等于真实网络尾段已是50ms。
7. **全量与增量。** 单TCP正常顺序下同序列重复可合并；原接收端直接赋值完整 history，若时间较旧则可能回退。集成已加 sourceStamp和结束单调保护。还有64点历史上限、既有记录被160活动上限移除后不重建等既有降级边界。没有在此扩成可靠重连/乱序协议。
8. **终态保留时间和单人开销。** 最终接口为 UnitPresentation.retainUnsent，由 GameBridge/Session 的实际连接状态设置。联机未发终态保留15秒，无peer未发终态及已发终态700ms后退役；活弹不按出生时间删除。组件直接设置该字段验证四个分支，不代表已验证 Session 的状态注入。使用真实 getTimer 等待约15.2秒，不替换生产时钟或修改私有记录。

## 性能核查

captureMotion 和 captureEffects 各建立武器列表；每个 recorded 事件的 after 都扫描最多64点并分配数组，同stamp修订又查一次。每帧 observeFinal 还观察历史武器。因此密集场景新增开销随武器数、在途弹体数增长；不能仅凭包小就称更快。beginCaptureBatch 已避免逐敌人全扫历史武器，但没有消除上述逐事件成本。应保持现有发送频率，比较无弹、普通高射速、闪电/火焰、大量在途投掷物四种场景的采集CPU、AMF编码CPU、分配/GC和包字节。不要把字段静态估算写成实测百分比。

## 组件边界及运行

`run_checks.py` 冻结所选源码中的真实 UnitPresentation、ProjectileVisuals、ProjectileFrameStream、RemoteMotion、BinaryMessageCodec；若有 ImpactEventQueue，也直接用生产类。SHA与所有夹具写入 inputs.json。源码在运行期间改变或安装改变则整轮失败。

替身：原生 Unit/Bullet、舞台原画（Sprite）、身体/武器/念力/近战旁路、真实碰撞和 Part 采集。命中替身只提供已确认事件并记录播放次数。测试经过真实二进制编码与解码，**没有 TCP socket、完整 Session、GameBridge 或原生物理**。死亡时钟测试直接模拟 GameBridge 已查明的 null motion调用，原生整链另测。

14组：普通+recorded连续序号、增量和全量修复、束状形态保持、同stamp最终修正、空帧和结束、换枪、死者采集、死亡时钟、普通弹真实结束、普通弹低帧率和迟到终点、命中独立载荷、无vis低seq命中、低seq后变可见、联网与离线终态退役。位置、缩放、透明度的同stamp修订经过真实采集；动画帧字段 f/lf 的比较另用合成点验证生产 samePoint（Sprite替身没有多帧原画）。不是现有37/19项的重复通过，实际断言结果分别记录。

工作目录 mods/RConnect，主会话串行执行（脚本自动登记，小组件1GiB启动门槛，不降低游戏双实例门槛）：

```powershell
$capturePython = 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
& $capturePython -B -X utf8 experimental/recovery-motion-checks/run_checks.py --source experimental/recovery-motion/src --output build/m52/recovery-capture-control-01 --run --registry-wait 900
& $capturePython -B -X utf8 experimental/recovery-motion-checks/run_checks.py --source build/m52/recovery-01/src --output build/m52/recovery-capture-03 --run --registry-wait 900
```

输出只在 build/m52 的新子目录，唯一AIR ID、后台桌面与独立存储；不加载游戏。首次 recovery-capture-01 因最终生产接口新增 hasPending 而编译失败，原始证据保留。替身补齐该接口并核对 34 个调用方法后，recovery-capture-02 编译通过、107/110 断言通过。三项失败来自同一夹具把 spring=2 束状武器当成 spring<2 飞行弹要求插值；已修夹具，并新增束状形态保持测试，未改生产。修正轮为 recovery-capture-03，实际结果见其 receipt.json；02 不回写为通过。

运行复验：`build/m52/recovery-capture-03` 使用冻结 `build/m52/recovery-01/src`，编译和隐藏桌面运行通过，**116/116 断言、exit=0**。`installation_unchanged=true`、`production_unchanged=true`；`native_game=false`、`tcp_socket=false`。此前 01/02 的失败证据完整保留。这证明本目录标明边界内的采集/编解码/接收组件，不证明实机性能或原生效果匹配。
