# B 主侧发布：字段/姿态变更分布实测（诊断构建，未部署）

日期：2026-11-04。承接 `experimental/b-fast2-host-publish-20261104/` 的结论：
主侧 `host.publish` 34.6 ms/帧，其中 `capture.units` 19.7 ms 占一半以上，但那 19.7 ms
到底花在"读"还是"写"、有多少是白干，此前只有 ms 级计时，无法归因。

本轮**只加计数、不改行为**，拿分布；**诊断构建未部署**（`B3-0.1-fast3diag`，版本串带 diag）。

## 1. 加的两个计数器（关闭时零成本）

| 计数器 | 位置 | 含义 |
|---|---|---|
| `field.declared` / `field.changed` | `NativeFields.capture` 字段循环末尾 | 该对象 schema 声明的标量字段数 / 本帧真正变化（含删除）的字段数 |
| `pose.nodes` / `pose.changed` | `VisualPose.captureNode`，只在 `depth==0` 汇总 | 一次根姿态捕获访问的节点数 / 该根捕获是否判定为变化（0=复用旧记录，1=新建） |

两者都在 `if(Timing.enabled)` 内，`Timing.enabled==false` 时只有一次布尔比较。
数值用 `Timing.record` 的 ms 槽承载（值域 ≤300，直方图上限 2000 不截断），
所以 `meanMs` 在这里读作"均值计数"，不是毫秒。

## 2. 实测（`build/ab/b-fast3-bench-diag-01`，`passed=true`，30 s，host 侧）

80 敌阶段，399 个发布帧：

| 指标 | 数值 |
|---|---|
| `capture.units` | 19.68 ms/帧（p95 33，max 82） |
| `capture.tiles` | 2.38 ms/帧 |
| `host.publish` | 34.42 ms/帧（p95 55，max 96） |
| `capture.nativeFields` 调用次数 | **178 次/帧**（71,022 / 399） |
| `field.declared` 均值 | **129.5 个字段/次**（p95 218，max 297） |
| `field.changed` 均值 | **2.86 个字段/次**（p95 12，max 15） |
| `capture.pose` 根捕获次数 | **198 次/帧**（78,954 / 399） |
| `pose.nodes` 均值 | **2.39 个节点/次**（p95 3，max 56） |
| `pose.changed` 均值 | **0.53**（约 47% 的根捕获判定为"没变"并复用旧记录） |

8 敌阶段同向：`field.declared` 108.1、`field.changed` 2.42、`pose.nodes` 2.63、`pose.changed` 0.598。

## 3. 结论（这轮真正买到的东西）

### 3.1 字段捕获有 ~98% 的写入是白干

`NativeFields.capture` 对"上一帧变过"的对象走 eager 路径：**边读边把全部 `declared` 字段写进新记录**
（`if(eager)out[name]=item;`）。实测每帧每对象只有 **2.86 / 129.5 ≈ 2.2%** 的字段真的变了，
其余 126 个字段的写入只是为了"造一份完整记录"。

每帧只有一帧的收益不是 CPU，而是**垃圾**：80 单位 × 129 槽 ≈ 10,320 个属性槽/帧、
约 150 KB/帧的短命对象。实测 `capture.nativeFields` 的 **max 达 62 ms**——
297 次属性读不可能花 62 ms，这个尖峰只能是分配触发的 GC 停顿。
这正是加入侧"偶发一两百毫秒卡死"的主侧来源之一。

### 3.2 姿态捕获是"每对象固定开销"，不是"每节点"

198 次根捕获/帧、每次只访问 **2.39** 个节点，合计才 473 个节点，却花了约 11.5 ms
（0.058 × 198）。换算每节点 ~24 µs——远超 20 次属性读的成本。
说明瓶颈是每个根捕获的固定开销：`display.transform.matrix`、`display.transform.colorTransform`
（每次调用各分配一个新对象）、`display.filters`（返回新数组）、以及新记录的分配。
**47% 的根捕获最后判定"没变"并直接返回旧记录，但固定开销已经付掉了。**
这条路要赢，只能减少"根捕获次数"（198 次/帧）或跳过固定开销，两者都需要新的廉价签名，暂不做。

## 4. 下一步：让字段记录只装变化项（已设计，未实施）

机制（可直接落地）：

1. 给 `NativeFields.capture` 加 `complete:Boolean=false`；
2. 每个对象的记录除 `state`（交给上层的不可变快照）外，再存一份**只在本机使用的可变镜像 `mirror`**，
   比较始终对 `mirror`，变化才写进新 `state` 与 `mirror`；
3. 于是 delta 帧的 `state` 只含变化键（`field.changed` ≈ 3 个），不再有 126 个无用写入；
4. `SceneSnapshot.capture` 在 `full` 帧（换房/首帧）传 `complete=true`，保证全量帧仍带完整记录；
5. 首次捕获 `previous==null` 时天然全量，不需要特例。

为什么不会破坏线上语义：J11 之后，delta 帧的字段本来就是
`[path,2,updates,removed]` 分组更新，接收端把 `updates` 累加进自己的 `fieldsDelta`，
**不会读取发送端那份 `fields` 的新内容**；接收端的全量 base 只在 `full` 帧更新。

风险（需要在安静环境跑完整套件才敢发）：

* `state` 变薄后，**主机侧**探针若直接读 `frame.scene.units[i].fields.X` 会读到缺失键；
  已知产品侧探针多已改用 `NativeFields.get/has`，但 `get/has` 对"只有 mirror"的主机记录仍需处理。
* `ContractChecks` 里"历史确认帧不可变"的若干断言必须逐条复核——这是本仓最重的不可变契约。
* `BDeltaPrefixChecks` 等外部 delta 前缀检查需同字节重跑。

预期收益：`capture.nativeFields` 约 −30%（读不能不读，写去掉 ~98%），
即 `host.publish` 约 −2.5~3 ms，**并显著削掉 62 ms 级 GC 尖峰**（后者才是体感收益）。

## 5. 复现

```powershell
# 把本目录 source-01 的三份文件覆盖到 build/ab/b-fast2-source-01，再编译：
python mods\RConnect\tools\host_authority\build.py --output build/ab/b-fast3-diag-02 `
  --source-root build/ab/b-fast2-source-01 --optimized
python mods\RConnect\tools\host_authority\field2_driver\bench_sustained.py `
  --workspace build/ab/b-field2-bench-20261025-01 --candidate build/ab/b-fast3-diag-02 `
  --native build/ab/b3-playable-190/game/pfe.swf --result build/ab/b-fast3-bench-diag-02 `
  --profile --seconds 30 --driver build/ab/ab-sustained-004 `
  --prior-preparation prepared-bench-fix-20261104.json
```

读 `result.json → roles.host.results[*].timings` 里的 `field.declared` / `field.changed` /
`pose.nodes` / `pose.changed`（`meanMs` 字段在此读作计数均值）。

## 6. 边界

* 单轮 30 秒、探针构建（`Timing.record` 本身有开销）、机器非独占。
* 计数用小整数承载在 ms 槽里，`n` 是真实的，`sum` 会被 ms 量化影响；
  §2 的均值取 `meanMs`（=sum/n），因为值域只有 0–300，量化误差可忽略。
* 本构建**未部署**，可玩包仍是 `B3-0.1-fast2`（`d0f5b197…`）。
