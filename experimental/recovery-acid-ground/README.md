# 酸液爆炸地面视觉补齐候选

后续实际状态（2026-10-22）：组件01/02分别在夹具私有方法名与参数静态类型处编译失败；只修夹具后组件03实际49/0，SWF `009c9a2cfa17f4edf21bde3b7b592724264a567f2686a63600825780d397bb47`，安装与输入未变。准确两类增量已由根合入08→09并编译，未部署。以下为提案时记录；原生Part、TCP、最终画面与性能仍待独立驱动检查。

本目录是冻结 `build/m52/recovery-07` 的独立两文件增量。未合入 integrated，未编译、未运行 AIR、未部署；不代表实机视觉或性能验收。`prepare.py` 钉住两个祖先 SHA，`inputs.json` 记录全部候选及组件输入。旧/新组件来自完整真实类，只改类名及对应类引用，测试替换 GameBridge 的字段读取、Emitter/Snd 的调用边界。

## 已确认的缺口与原生依据

原生资料均来自 `game-reference/decompiled/1.02/src102/scripts/`：

- `fe/weapon/Bullet.as:946–954`：首次酸液爆炸 `expl_t==0` 发出 acidexpl、acidkap，随后 `explLiquid("acid")`。这里**没有水中排除**。相对地，火焰分支 `:988–999` 要求 `inWater<=0`，并调用 `explLiquid("fire",-33)`。
- `Bullet.as:879–912`：武器的 `visexpl` 优先走自定义分支（包括 sparkle 自己的水中/干地效果），不会进入普通 acid/fire 分支。候选保留这个优先级。
- `Bullet.as:1008–1043`：按爆炸圆内地块中心、`ty>1`、实体或搁板、斜坡或上方无实体筛选表面，Y 为 `phY1+offset`，X 在格中心随机左右 2 像素。`explRun:706–720` 先执行原生地形及伤害，再作视觉。
- `fe/graph/Emitter.as:174` 的 `cast():Part`，`:204` 始终 `new Part()`。`fe/AllData.as:6945` 的 acid 定义采用 `visualAcid`，动画、渐入/渐出、寿命 100 加随机 0–29 帧、`imp=1`，没有 `water` 限制字段。
- `fe/graph/Part.as:141–214` 的完整 `step()` 只更新运动、画面帧、透明度、水条件与寿命；没有碰撞伤害、Effect、地形结算或 AI 唤醒。酸伤害来自 Bullet 的原生爆炸/气体结算，不来自地面 acid Part。

冻结 07 的 `BurnVisuals.captureGround` 只接收 `tipDamage==3`，`ProjectileExplosionVisuals.play` 的 type 10 只发酸液爆炸及飞溅。因此地面酸液在同步数据和重放两端都缺失，不能仅补接收端一个 emitter 调用。

## 精确改动

1. `src/rconnect/game/BurnVisuals.as`：原地面坐标收集增加 type 10；酸液使用 `phY1`，不套用火焰的水中排除；火焰仍使用 `phY1-33`。沿用原半径、房间边界、256 点上限及自定义效果排除。
2. 同类 `playGround` 增加可选参数 `kind="fire"`，仅接受 fire/acid。旧三参数调用完整保留；新酸液在接收侧加原生 ±2px 分布的视觉抖动，不额外消耗发送侧游戏随机数。使用游戏原生 acid Emitter，因此外观资源、透明度、动画、寿命与粒子上限由原版决定。
3. `src/rconnect/game/ProjectileExplosionVisuals.as` 的首次 type 10 播放地面酸液。仍使用已有 shot/explosion 身份与 ImpactEventQueue 播放时钟；repeat 不重复酸液。未修改 UnitPresentation、队列去重、伤害、气体脉冲或网络频率。

旧包缺 `ground` 时仍安全播放旧爆炸效果。接收侧不读取自己的地形来猜酸液位置，因此不会因地形补丁稍晚到达而在错误表面生成。无跨包或跨房间地面缓存，新足迹数据随原有爆炸事件生命周期处理。

## 49 条共用新旧组件

`components/AcidGroundChecks.as` 包含 37 条直接断言，加 6 种火焰情形每种 2 条（合计 49）：

- 同一原生位置数据下旧类明确漏酸液、新类得到正确表面；干地/水中、搁板、被覆盖地块、斜坡、严格圆边界、顶行排除、无效半径及非酸类型。
- acid 与 fire 的 Y 偏移、火焰完整捕获和调用序列新旧相等；custom/sparkle 的独立规则与水中行为。
- 首次与 repeat，缺 ground 的旧包，原生酸滴数量区间，±2px 接收侧抖动、源包不变、独立返回数组。
- 无效/越界坐标、256 点上限、关闭房间、空参数、拒绝任意 emitter 名；接收侧不重新扫描地形，不触发伤害/地形/AI 方法。

只做了纯 Python 生成、哈希核对与静态断言数量审阅，**49 尚未执行**。组件里的 Emitter 和 Snd 是记录调用的边界替身，不是真实 Part、游戏图形资源或 TCP；“使用原生粒子”目前由源码路径证明，后续还需原生酸液爆炸画面和生命周期验证。没有随机数逐次一致保证，酸液左右抖动和寿命采用同分布，而非复制源 Part 的实际随机样本。继承旧火焰路径的 radius<=800/256 点/有效地图边界限制；没有扩大范围。气体后续原生脉冲仍不靠墙钟推算。

准备与检查（不启动编译器）：

```powershell
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/recovery-acid-ground/prepare.py --verify
```

由主会话排队执行独立组件（输出必须为新的 m52 直接子目录）：

```powershell
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 tools/validation/run_recovery_component.py --source experimental/recovery-acid-ground/components --entry AcidGroundChecks.as --expected 49 --output build/m52/recovery-acid-ground-component-01 --registry-wait 900
```

整合时只能拿本目录 `src/` 两个覆盖；与其他对 BurnVisuals/ProjectileExplosionVisuals 的覆盖需逐处合并，不能覆盖较新的无关修复。父会话负责实际冻结输入、编译、共享测试登记、原生验证与性能门槛。
