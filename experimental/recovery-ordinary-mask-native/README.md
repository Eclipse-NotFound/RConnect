# ordinaryMaskBounds 修正的最小原生测试适配

此入口只切换隔离宿主，继续使用准确 **C6A3 RConnect 产品**、原 **BF6 entry-room 驱动**、原普通墙面四轮像素驱动及原测试框架。没有新增 AS 测试源码、没有重新编译驱动、不改旧包装脚本、旧 pins 或 `binding.json`。

新宿主固定为 `build/m52/recovery-ordinary-mask-host-02`；唯一允许的目标修正由 `experimental/recovery-ordinary-mask-host-fix-v2/build.py` 的 `verify_result` 及真实 `method-audit.json` 核对。这里不编译宿主，也不部署候选。

## 准入分开核对

1. 调用准确旧 `recovery-ordinary-wall-sv-rooms/run_native.py` 的 `preflight()`。其内部仍核原 C6A3、host05、BF6、原像素驱动和真实 22 文件安装组合。这份旧绑定只作为历史基线，绝不改成返回新宿主。
2. 必须存在由主任务核验实际产物后保存的 `build/m52/recovery-ordinary-mask-host-02/runtime-admission.json`。字段契约：

   - `kind = ordinary-mask-host-runtime-admission`
   - `validated = true`、`scope = native-test-only`、`installed = false`
   - `candidate_sha256`、`build_manifest_sha256`、`readback_audit_sha256`、`method_audit_sha256` 与实际文件相等
   - `inputs = {绝对路径: SHA256}` 包含新 builder、`prepared.json`、`build.json`、两个 audit、`pfe.swf`、`build.json.artifacts` 中的所有产物及主任务验收材料；入口逐项回读指纹

3. 在核准 builder 指纹后调用其只读 `verify_result(HOST)`，要求实际 `compiled`、`build_checks_passed` 为 true，**builder 的 `validated` 仍为 false**。不能以编译成功代替主任务的原生测试准入。
4. 单独要求 `method-audit` 的准确目标为 `fe.graph.Grafon::0:1:ordinaryMaskBounds`，`passed`、`exactRetainedRoundTrip`、`nonTargetBodiesByteExact`、`classTraitsScriptsPreserved`、`oldConstantPrefixPreserved` 为 true，并保留 `targetProof` 的 flags、frame、privateMappings、oldAndAddedMasks、geometryTailUnchanged 证据；最后一项须为 true。
5. 两个场景运行前、运行后均重新核新宿主、主任务回执、全部输入和安装表；前后绑定必须完全相同。主任务回执缺失或任一指纹/语义证明不符即失败，不启动游戏。

## 使用

从 `mods/RConnect` 目录运行，或给输出传绝对路径。使用本机已配置 Python，禁止 `-O`。

```text
python -B -X utf8 experimental/recovery-ordinary-mask-native/run_native.py --check
python -B -X utf8 experimental/recovery-ordinary-mask-native/run_native.py --scenario rooms --output build/m52/recovery-ordinary-mask-rooms-01
python -B -X utf8 experimental/recovery-ordinary-mask-native/run_native.py --scenario pixels --output build/m52/recovery-ordinary-mask-pixels-01
```

`--check` 不编译、不运行 AIR、不写测试结果；缺少新准入文件时会直接报缺失。实际运行必须使用尚不存在的输出目录，名称为 `recovery-ordinary-mask-rooms-NN` 或 `recovery-ordinary-mask-pixels-NN`；可沿用 `--registry-wait`，默认 900 秒等待共享测试登记。

- **rooms**：仅设置原 entry-room 框架公开的 `audit`、`host_input`、`verify_host_intent`、`verify_driver`、`installation` 回调。RConnect 仍为 C6A3；BF6 的全部断言及实际输入核验保留。真实新宿主和新回执明确进入原 `intent.json`。
- **pixels**：直接调用旧 `wall.execute`，显式传入新宿主、新准入回执及新输入指纹。原五锚点适配、四轮驱动、精确 uint 像素分析器完全复用，不增加源码替换。旧 execute 末尾的 `verify_binding()` 仍真实验证原 host05；它不被 monkey-patch，也不冒充新宿主核验。新宿主由本入口的独立前后核验负责。

原框架的 600 秒测试时限、错误解析/DONE、真实 22 安装文件、6 GiB 启动与 512 MiB 运行保护、共享登记、独立桌面/专属测试实例及收尾清理路径保持。没有错误豁免、超时放宽、成功模拟或历史结果覆盖。

## 输出与资格边界

- 原 `result.json`、像素场景的 `wall-surface-result.json` 及原始日志/图像不被本入口改写。
- 新增 `mask-adapter-result.json`，记录新宿主准入、原历史宿主身份、运行前安装及全部冻结输入、运行后复核、原结果指纹。适配层任何异常或后验漂移都使本层失败，即使旧框架已写 `passed=true`。
- 进房场景不证明四轮墙痕；像素四轮不证明所有房间/所有 mask 资产均实际走过。两个场景仍须独立判读。
- 通过仅是对应原生功能试验，`performance_qualified=false`、`gameplay_qualified=false`、`installed=false`。旧 pixel 通过或新静态准入不能证明新宿主已经实测，也不构成部署动作。

此目录只准备适配入口，编译和 AIR 由主任务串行执行。当前未运行任何新宿主测试。
