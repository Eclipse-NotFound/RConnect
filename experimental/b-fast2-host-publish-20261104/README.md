# B 主机发布耗时：瓦片扫描 1/3 削减与类名缓存（2026-11-04）

只处理 **B（主机权威线）**。A 源码、A 正式体、宿主 SWF、存档、配置均未改。
承接 `experimental/b-fast-prediction-20261104/`：那一轮证伪了"给播放头限速"，
并留下结论「加入侧延迟 = `clock.delay`，只能靠压低主侧发布间隔来同时降延迟与卡顿」。
本轮就打这个。

## 1. 改了什么

### 1.1 `SceneSnapshot.capture` 的整房瓦片扫描（主要收益）

原实现每个发布帧对整房 `spaceX × spaceY` 逐格比较 39 个标量：

```as3
for(var x:int=0;x<room.spaceX;x++)for(var y:int=0;y<room.spaceY;y++) {
   var at:int=x*room.spaceY+y,t:Object=room.space[x][y],old:Array=tiles[at],changed:Boolean=full;
   ...
   if(!changed)for(var j:int=0;j<TILE.length;j++)if(t[TILE[j]]!==old[j]){changed=true;break;}
```

内层循环每格都要重新取 `TILE`（静态 const 数组槽）、`TILE.length`、`room.spaceY`、
`room.space[x]`，并做 `t[TILE[j]]` 的静态数组二级索引。改成：

* 把 `TILE`、`TILE.length`、`room.spaceY`、`tiles`、`plainFront`、`result.tiles`
  全部提到循环外；
* 外层按列取 `column = room.space[x]` 一次，内层直接 `column[y]`；
* 内层用 `while` + 本地 `tileFields[j]`。

**比较的值、顺序、`plainFront` 的读取时机（先读旧值再写新值）、以及产出记录的形状完全不变**，
只有取值路径变短。`full` 帧、换房、`Tile` 变化判定逻辑一处未动。

### 1.2 `ClassNames`：按对象身份缓存 `getQualifiedClassName`

新增 `authority/ClassNames.as`：`Dictionary(true)`（弱键）按显示对象身份缓存类名。
一个对象的类在其生命周期内不会变，所以这是对纯函数的缓存，不可能让两个对象共享类名。

替换的热点（每帧每节点都会调，且这些都是反射调用）：

| 文件 | 原调用 | 每帧量级（80 敌） |
|---|---|---|
| `VisualPose.captureNode` | 每个子节点的 `getQualifiedClassName(child)`；每个 Sprite 的自身类名 | 数百次 |
| `VisualPose.apply/motion` | `getQualifiedClassName(target)` ×4 处、`getQualifiedClassName(parent.getChildAt(i))` | 每确认帧数百次 |
| `SceneSnapshot.capture` | 单位 `cls`/`clip`、炮塔挂载、物件 `cls`/`clip`、影子 `clip`、效果 `clip`、`Loot` 判定、未归属子节点 `clip` | 约 100 次 |
| `RoomRuntime.projectile` | 每颗弹丸的 `clip` 类名与 `PhisBullet` 判定（每 tick 最多 3 次对象链遍历） | 随射速 |

**故意没有缓存**：`display.filters` 返回的滤镜对象类名（滤镜每次读取可能是新实例，
缓存会让字典无界增长），以及 `matchesFilters` 里的比对（同上）。

## 2. 实测（同环境、同宿主、同一冻结基准、同驱动）

`bench_sustained.py --profile --seconds 30 --driver build/ab/ab-sustained-004`，
8 敌与 80 敌各一阶段，探针构建（`Timing` 开销在内，作相对比较）。

| 分项（ms/帧，均值） | fast1-03 | fast2-01 | 变化 |
|---|---:|---:|---:|
| `capture.tiles`（80 敌） | 3.681 | **2.379** | **−35.4%** |
| `capture.tiles`（8 敌） | 3.522 | **2.439** | **−30.8%** |
| `host.publish`（80 敌） | 36.008 | **34.619** | **−3.9%** |
| `host.publish`（8 敌） | 15.022 | **13.792** | **−8.2%** |
| `capture.units`（80 敌） | 19.656 | 19.732 | +0.4%（噪声内） |
| `capture.objectsAndParticles`（80 敌） | 0.707 | 0.655 | −7.4% |
| `host.simulate`（80 敌） | 17.997 | 18.704 | +3.9%（宿主代码未改，噪声） |
| join `client.present`（80 敌） | 12.669 | 12.841 | +1.4%（噪声内） |

两次运行 `passed=true`、`runtime_changed` 为空、无 FATAL。

**边界**：单轮 30 秒、探针构建、机器非独占（编译一次曾 >30 分钟）。
`capture.tiles` 的方向与幅度两次敌人数都一致且远大于其它分项的抖动，可以认为成立；
`host.publish` 的 −3.9% 与之相符（瓦片约占 publish 的 10%，砍掉三分之一 ≈ −3.5%）。
`capture.units`（19.7 ms，占 publish 一半以上）**没有改善**——它才是下一个目标。

## 3. 冻结基准漂移（必须记录）

`build/ab/b-field2-bench-20261025-01` 的可复用 host/join 副本，与其 `prepared.json`
已经漂移 16 个文件（`pfe.swf` + 13 个模组文件 + `mods/loader-manifest.txt` 等，由后续会话来刷新）。
本轮**不改写历史 `prepared.json`**，另存 `prepared-bench-fix-20261104.json`
（逐文件记录 `was → now`，host/join 漂移集合完全一致），并用新的驱动副本
`build/ab/ab-sustained-004` 让工具生成 `prepared-sustained-004.json`。
A/B 两轮共用同一份新基准，所以上表是受控对照；但它**不能与 j11/j12/p0 时代的绝对数直接相加**。

## 4. 未做 / 下一步

1. **`capture.units` 19.7 ms**（每单位 282 个原生字段 + 整棵姿态树）仍是 publish 的一半以上。
   需要先加"哪些字段/子树本帧真的变了"的计数，再决定分级采集；S1/S2 字段裁剪此前两次 ABAB
   方向相反，不能盲裁。
2. `FrameDelta.decode` 大包尖峰（41–49 ms）属协议层。
3. `capture.untrackedEffects` 本轮在 80 敌下反而 +35.9%（0.311 → 0.423 ms），量级很小但
   说明未归属显示对象的清理路径值得单独看一眼。

## 5. 复现

```powershell
python mods\RConnect\tools\host_authority\build.py --output build/ab/b-fast2-02 `
  --source-root build/ab/b-fast2-source-01 --optimized
python mods\RConnect\tools\host_authority\field2_driver\bench_sustained.py `
  --workspace build/ab/b-field2-bench-20261025-01 --candidate build/ab/b-fast2-02 `
  --native build/ab/b3-playable-190/game/pfe.swf `
  --result build/ab/b-fast2-bench-fast2-profile-02 --profile --seconds 30 `
  --driver build/ab/ab-sustained-004 --prior-preparation prepared-bench-fix-20261104.json
```

（路径相对 `mods/RConnect`；`build.py` 每次必须新的输出目录，`bench` 的结果目录也必须新建。）
