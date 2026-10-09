---
domain: world-objects
type: experiments
game-version: ["1.02"]
confidence: high
verified: false
discovered-by: RConnect
date-updated: 2026-10-09
evidence:
  - kind: runtime-experiment
    summary: "27741832f6采样发现地形扫描/垃圾回收长帧；采样开销使其仅供定位"
  - kind: deterministic-replay
    summary: "terrain-fixed-replay-03：60/0；180固定步、227条结果新旧一致；独立副本计数快照分配"
  - kind: decompiled-game-code
    symbol: "fe.loc::Tile public scalar fields; RConnect TerrainSync.hostPatch/capture"
---

# 地形扫描的临时对象分配

## 已确认

原TerrainSync.hostPatch为每格调用state，创建坐标和13字段对象，再与初始基线比较；capture同样为每个observed格重建对象。未变化格仍产生大量短命对象。1.02 Tile对应字段为public数据字段，并非有副作用的getter。

优化仅做两点：先直接比较字段，变化后才构造快照；初始基线按`base[x][y]`存储，避免反复拼接字符串。旧观察对象保持不可变，实际变化仍创建新对象。捕获预测伤害、确认前补捕获、房间关闭清队列、发送间隔、128格包上限和线上字段格式均不改。

不能使用`x * 当前房高 + y`缓存：同一个房间对象改变尺寸时，会取到别的格的基线。新回归用每格不同HP的矩形房缩小、恢复和扩展验证坐标不串格。

## 固定检查

build/m50/terrain-fixed-replay-03不加载游戏SWF、用户存档或网络，只在唯一AppID执行AS3。当前TerrainSync/RemoteMotion逐字节复制；基线取final23已冻结地形文件，只重命名类与包以并存。180步执行同样破坏、延迟/重复确认、背景变化及离房清队列，比较227条返回数据和最终地形。结果60 PASS / 0 FAIL。

原10项地形回归加12项新边界，两套类各22项；另有1项差分回放、6项持物、7项原始容器掉落轨迹、2项分配计数。原生checkpoint适配器调用即抛错；传送事件和武器调用也显式拒绝。不宣称覆盖原生存档、碰撞/渲染、武器/传送或网络时序。

两个额外类仅在state入口增加计数，不用于行为回放或生产。320格、双方各100次扫描、初始建表后：

| 固定输入 | 旧快照对象数 | 新快照对象数 |
|---|---:|---:|
| 所有格不变 | 64000 | 0 |
| 每次同一格改变外观 | 64000 | 200 |

数字只计地形状态对象，不是进程总内存或全部临时对象；本次不采用墙钟耗时/FPS比较。

## 未验证与原记录

- 27741832f6采样帧包括host TerrainSync.state/hostPatch和join sweep→state→capture→report；采样器增加开销，不能直接换算收益。
- 平面索引地形诊断74ae636f61宿主启动超时，无有效性能对照，未采用其索引方案。期间单次CPU采样100%，用户选择保留其它程序、先做代码和固定回放；不归因所有历史时序红。
- 回放01在编译前因CRLF归一化触发源码指纹拦截，02因独立运动夹具缺依赖编译失败，均未启动AIR。03修正字节复制并显式限定边界后通过，原目录保留。
- final24 SHA d62c0bd218995256fe4a26583b8a684df4a35b850f83c514459318c6ac1bb3f9，163276B/68类。编译和类表通过，但38组游戏验收尚未开始，安装仍21。正常玩法和真实负载收益待验证，故verified:false。
