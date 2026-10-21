# 武器姿态：省去必被覆盖的回退计算

2026-10-22；基于准确 `build/m52/recovery-14`，SWF `225a794040c71f2a55ff433366a7969201ac3a58ffaab0a655cee1e4eefbe5f7`。仅输出独立源码和组件准备，未编译、未启动AIR、未部署。

唯一生产覆盖为 `src/rconnect/game/UnitPresentation.as` 的 tick 一段。`proposal.patch` 是完整准确差分；旧源码SHA `d67dbcbed8d3ef67771eb10e41516102dabb34aad3a7065ab71ec7822ff53178`。没有版本字符串或其它生产类变化。

原顺序总是按本机到包间隔计算 m/p/angle，写入武器 X/Y/rot；若当前源时间样本里有同一武器，又立即覆盖三个值。新顺序仍在原位置读取 `elapsed=getTimer()-m.at`，先找源样本。只有找不到匹配时，才执行原式、原顺序的回退计算。四个匹配字段 slot/id/variant/stream、`==` 比较和第一个匹配优先保持。

后面的 prep/reload 计时、queue/next/flash、shoot重启、每帧 animate、光晕、透明度/可见性、近战及炮塔显示逐字节未改。没有减同步频率、跳过动画或改源时钟。

## 副作用与边界

- 原回退只有数值读取、算术和 X/Y/rot 赋值；三次赋值到源姿态覆盖之间没有 animate、其它方法调用或读回。这些是原生 Pt.X/Y、Weapon.rot 的普通字段，不是设置属性时执行脚本的接口。m 是 apply 创建的普通数据对象，源样本是 RemoteMotion/网络数据对象；对有效游戏数据，删除临时写入没有可见副作用。
- 保留 elapsed 的原时点和读取次数，匹配源姿态也继续更新 prep/reload。暂停时原本仍执行的这些显示更新照旧执行。
- null clock、null currentSample、缺少或非Array weapons、空数组、四个身份字段任一不匹配均走原回退；不匹配的旧枪/旧stream不能控制新武器。遇两个匹配仍取第一个，保持原行为。
- 不新增包验证，不改变无效数据政策。本候选的等价范围是原生字段/普通网络记录；不承诺外部注入自定义getter/setter具有副作用或畸形null武器条目时，异常前的临时字段写入也保持一致。正常源样本构造/插值已使用这些条目的字段，不将人为getter副作用作为玩法契约。

## 实际类组件

`components/rconnect/game/PoseBefore.as` / `PoseAfter.as` 分别是**完整**旧/新 UnitPresentation。准备器只改类名、把 getTimer 绑定到确定性组件时钟、增加只读 fixtureState 访问器和 play 请求观测点；剥除这些变换后必须与对应完整生产类相同。tick/apply 不是测试里重写的镜像算法。`components` 在交付后冻结，不能现场修改。

54项待运行断言：21种姿态情况各核对完整新旧输出、独立目标坐标、prep/reload和一次动画/光晕/近战调用；10种实际 apply/tick 序列覆盖 defer、立即更新、连发冷却、暂停、换弹、重新挂载、炮塔、双枪、换枪旧身份到新身份；另2项用只读 r 访问计数证明匹配时实际旧类读2次、新类0次，回退时双方仍2次。

记录比较包括每次 native animate 边界的姿态与计时、play 请求序列、queue/next/flash、aura/melee/burn/turret顺序、最终可见性/透明度及 getTimer 次数。真实原生武器资源和其帧脚本不在小组件内；MovieClip为空测试资源，play 保留完整生产方法并记录调用请求，**不能把组件过关称为真实枪口像素或整体性能过关**。没有伤害、敌人AI、房间加载或其它模组。

主会话依共享登记串行执行：

```powershell
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/recovery-actor-pose-fast/prepare.py --verify
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 tools/validation/run_recovery_component.py --source experimental/recovery-actor-pose-fast/components --entry ActorPoseChecks.as --expected 54 --output build/m52/recovery-actor-pose-fast-component-01
```

原通用组件入口保留安装/源码/工具前后指纹、唯一AIR ID、后台桌面、共享game登记、60秒组件时限和失败证据，未加新运行框架。本代理仅执行文本生成和 `check_offline.py` 静态检查。收益未实测，不能把 profile 中 gotoAndPlay 的71个样本当作此改动可以省去的成本。
