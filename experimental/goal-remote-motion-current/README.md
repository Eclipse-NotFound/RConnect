# 当前 78C 的 RemoteMotion 单类候选

基底为 `build/m52/recovery-room-production-05`（正式 `0.2.24-roomfix5`，SWF `78c052…f4699`）。本目录产品覆盖源仅 RemoteMotion 与 RConnectMod 的版本行（`0.2.24-motionclock1`），其余 79 类逐字保留；不改 GameBridge、Session、发送频率、弹丸或其他模组。不要把 `components` 中的边界存根合入产品。

两处改动：普通小幅时钟校准交由既有播放速度调节，避免同一显示时间直接前跳；一个插值区间开始播放后固定其曲线切线，避免后续采样改写已经播放的跳跃／抓取／掉落轨迹。大幅启动积压恢复、暂停、传送阈值及禁止越过已收位置的规则仍在。

来源证明见 `source-manifest.json` 与只读 `check.py`：当前完整 RemoteMotion 的 SHA 为 `19f035…174aa`，与旧 37 项失败对照的完整类逐字相同；本次完整覆盖类 SHA 为 `d2688b…98cd`，与当时 37/0 候选逐字相同。差分只涉及 `pushTimed` 与 `curve` 两个函数。清单另保留当前全部 81 类源指纹和 prepared/compile 证据，未复制整树。历史 31/6 与 37/0 是旧组件事实，不冒充本次已运行。

旧 37 项覆盖普通／抓取的同时间校准、抓取／掉落曲线变形、接收端点约束、暂停与恢复、掉落批次、有限特效时钟、20Hz 曲线、敌人追赶和身体循环。`components` 使用相同五份检查源码与完整候选类；仅主入口的结果对象及单条记录键名调整为现有组件运行器合同，输入、循环、阈值、断言和退出码不变，见 `component-output.diff`。其 TeleportVisuals/WeaponDisplay 是原夹具的显式拒绝边界：真的走传送或武器几何就抛错；不是当前游戏实现。Log 仅 trace。原生武器、MovieClip、真正联机与帧率不在这 37 项覆盖内。

根会话运行（工作目录 `mods/RConnect`，子代理未执行 Java/AIR）：

```powershell
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/goal-remote-motion-current/check.py
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 tools/validation/run_recovery_component.py --source experimental/goal-remote-motion-current/components --entry MotionContinuityChecks.as --expected 37 --output build/m52/goal-remote-motion-current-component-01
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/goal-remote-motion-current/prepare.py --check
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/goal-remote-motion-current/build.py build/m52/goal-remote-motion-current-product-01
```

运行器原有登记、1GiB 组件启动余量、运行内存保护、独立 AppID、源／安装复验和失败保存均沿用。输出目录须不存在；本目录不带另一套运行器。

产品 build.py 只绑定既有 production-v5/build.py 的 BASE/HERE/prepare 接口，不复制编译实现。原有两条 384MiB JVM、每次 1GiB 提交余量、512MiB 运行保护、共享登记、300 秒超时、子进程回收及安装不变检查保留。prepare.py --check 仅核已写好的文本；build.py 的 verify(output) 必须存在真实成功 compile.json，返回编译回执，不授予原生功能或性能资格。manifest 固定两份薄入口和旧构建器指纹。

本候选针对远端显示的两个确定跳变，不解决没有新显示帧的整帧卡顿，也不能解释或保证修好加入侧自己的普通跳跃；本机角色不经过该插值。旧 motion2 整包实测没有取得密集性能资格，因此这里不恢复整包、不继承其部署或性能结论。之后仍须在实际当前组合上比较真实角色／念力轨迹与帧间隔。
