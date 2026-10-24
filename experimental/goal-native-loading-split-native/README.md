# 原生加载界面的普通分房回归接线

只准备独立运行入口，不编译、不启动 AIR、不部署。不会生成或修改先前被拒的 `split-probe/source.diff` 或 `source-manifest.json`。

`run.py --check` 先要求真实的探针清单及 `goal-native-loading-split-driver-01` 编译回执/产物，再调用 `goal-native-loading-split-build/build.py.verify()`。文件缺失会返回退出码 2、`status=not-ready`，不创建输出目录；编译失败或指纹不符不会转成就绪。

原生组合固定为 UI 产品 `9C8536A7`、宿主 `2DB0B4EB`、独立运行准入 `4FDA39F7`。复用 `goal-native-loading-native-v2` 已冻结完整 bundle 验证，保持 BF4A 编译环境与 638E 运行环境明确分开，其余 21 项不变。旧 UI 三程驱动只用于核对该已验证 bundle 的来源，不作为本轮执行驱动；执行的是实际新编译分房驱动。

执行直接复用 `recovery-first-raster-native/run_native.py` 的公开回调接线，不修改其源码。沿用原 `entry-room` 动作、600 秒上限、双实例 6 GiB 启动/512 MiB 运行保护、共享登记、独占私有桌面、完整错误扫描及自有进程/副本清理。产品/宿主/新驱动验证分别调用真实 verifier，不伪造历史安装表。

原共享运行器没有主动复制 telemetry 或固定 CS 私有偏好，因此接入冻结 `goal-native-loading-hidden-only/launcher.py` 的同一启动/清理挂点。唯一文本适配是输出目录前缀 hidden→split-native（严格匹配一次）；其余检查原样复用。原房间框架局部 subprocess 代理只把同参数的共享运行器调用导向本入口 `--shared-runner`，不修改全局 subprocess。

取得登记后、任何 AIR 启动前，先核真实 22 项和全部指纹，再检查双方独立 AppID/描述文件，为每份自有副本复制原始 `telemetry.json`，并只在各自 AppData 写 `{"nativeEnabled":false}`。不用玩家当天偏好决定场景，正式 CS 设置及选择不变。所有自有进程退出、运行副本删除前，原挂点核两份偏好与 telemetry 未变；原 hidden-only 验证函数再核 before/after 回执、描述身份和原 input.json。记录这两份回执的准确指纹。

新增验收只读取新探针实际日志 summary：双方必须有合法本机等待和释放观察、零观察错误、旧副本完整树检查通过；主侧必须在既有 prepared 消息后的 2000 ms 静止窗有真实最终 RENDER，原业务 stationary 断言仍须通过。原房间、旧包、伤害/物品与标量比较继续由原驱动及原框架验收。`split-result.json` 独立追加，不覆盖原框架 `result.json`。

该轮是功能和显示正确性验证，不授加载速度/GPU/性能资格。不要求原生黑幕永远透明。等待/恢复 PNG 仅按实际是否生成记录；没有 waiting PNG 不称已有等待像素证据。

根统一执行的入口（相对 RConnect 根）：

```text
python -B -X utf8 experimental/goal-native-loading-split-native/run.py --check
python -B -X utf8 experimental/goal-native-loading-split-native/run.py --run --output build/m52/goal-native-loading-split-native-01 --registry-wait 900
```

当前准备并不表示驱动已编译或本轮已运行；以实际回执为准。
