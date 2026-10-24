# 原生加载画面：最薄双端运行接线

仅新目录中的运行适配。原 `goal-ordinary-loading`、共享 `tools/run_coop_regression.py`、已冻结观察器、UI 源码及构建器全部不改。本目录不编译，不提供部署功能；实际 AIR 仅根在准入完成后启动。

准确组合限定为：正式安装 78C / A796 保持不变，测试副本替换为 `0.2.24-nativeui1` 产品及同一 A796 派生的原生 UI 宿主，Sandevistan 仍为正式 CEC6。没有采用旧首绘桥、Sand003 或其它候选的资格。

## 三项独立准入

1. 已冻结 `goal-native-loading-probe/build.py.verify()` 核真实 driver 编译回执和外部 ABI，候选基底 78C；不是拿旧驱动哈希冒充新驱动。
2. `goal-native-loading-build/build_product.py.verify()` 核准确 78C 加两类 UI 覆盖、版本与真实编译产物。
3. `build_host.py.verify()` 核 A796 派生宿主的结构保留结果。其 `validated=false` 保持原意；另必须取得根对最终 P-code/回读的独立语义准入。缺实际产物或准入时 `--check` 返回 2，输出 `ready=false`，不会创建运行目录或启动实例。

根提供的宿主输出目录 `runtime-admission.json` 合同：

```text
kind = native-loading-ui-host-runtime-admission
validated = true
scope = native-test-only
installed = false
base_sha256 = 实际 A796
candidate_sha256 = 本次实际宿主
build_manifest_sha256 = 本次 build.json 的 SHA
semantic_review = 根实际语义核验文件的绝对路径
inputs = {准确绝对路径: SHA256}
```

`inputs` 必须覆盖该语义文件、pfe.swf、build.json、method-audit.json、readback/scripts/fe/World.as、pcode/scripts/fe/World.pcode。此目录只读取准入，绝不自行填写已审或发布资格。三份编译环境与当前 22 项安装分别核对；历史普通驱动的原校验仍先对原产物真实执行。

## 原检查如何保留

`recipe.py` 固定两个原文件 SHA，保存展开文本和 `source.diff`：共享运行器只有 **2 处**替换（新增可选完成前缀参数、原 effects 完成判断再 AND 新标记）；普通入口只有 **7 处**（指定 UI 宿主、独立宿主准入、传完成标记、限定双端/600 秒、排除启动前旧观察文件、清理前保全、终态资格校验）。没有复制修改一套新的执行框架。

准确旧共享运行器原来**不存在 `--done` 参数**，因此此前冻结 probe README 中“已有 --done 可用”的假设不成立。本目录局部展开副本增加该参数，不改原文件。实际等待要求原 COOP EFFECTS DONE 以及 `NATIVE LOADING PROBE DONE host` / `NATIVE LOADING PROBE DONE join` 同时存在；仍在原 600 秒期限内，没有另加宽限、重试或无限等待。

原三程动作、种子、48×25 房间、入口距离/维度/种子、原生控制恢复与原 35 项检查全部保留，并核 host=23、join=12。原私有桌面、独占、登记、6 GiB 启动门槛、512 MiB 运行中保护、模块/游戏错误扫描、遥测文件和 CS 私有偏好、22 项安装变化检测、自有 PID 回收/副本清理均沿原入口。退出/压力/超时没有豁免。

## 输出与最终通过

在原 `record.child_stopped` 接点、全部自有进程退出且副本清理之前，复制各端本次独有 AppID 的：

- `Local Store/native-loading-observer.json`
- `Local Store/native-loading-terminal.png`

原始字节保存在新输出 `observer/host/`、`observer/join/`；`observer-collected.json` 记录来源、SHA、字节数及任何缺失。启动前要求这两个文件均不存在，不能接受旧回执。失败时尽量保存双方现有证据，然后仍沿原回收流程退出。

最终仍是原入口的 `result.json`，只有原框架/35 项与两端额外观察共同通过才会 `passed=true`。新 `observer_passed` 和 `observer` 记录 11 项检查、真实 RENDER 覆盖、采样时长及图片指纹。除检查 JSON 的 passed 外，还回核每条真实行与阶段计数、零故障、原生对象身份、终态恢复、日志先后与 PNG 实际字节/尺寸；任一端缺新标记、输出失败、缺终态或图片都失败。原框架输出单独的 PASS 不代替最终结果。

这些时长是受观察开销影响的采样记录，不是 GPU 帧耗时或性能达标证明。只有普通共同旅行；不授分房、隐藏房、死亡或发布资格。

```text
python -B experimental/goal-native-loading-native/run.py --check
python -B experimental/goal-native-loading-native/run.py --output build/m52/goal-native-loading-native-01
```

若根为失败重试使用新编译目录，显式传 `--product`、`--host`、`--drivers`；每项仍须通过真实构建器和同宿主目录的独立准入。默认目录末尾均为 `-01`。允许 `--admission` 指定同一宿主目录内的准入文件；不允许跨候选借用。
