# 真实 CPU 采样正控制

首绘尾段实测 `8a09ea7cd3` 的两段完整窗口为2271/2276ms，但返回0个样本。此组件只确认当前准确真实接口能否在明显的 AS 计算期间返回 CPU 样本；不运行游戏，不把0样本归因于GPU、网络或等待。

只有一个正控制断言。复用冻结 v3 `FlashPaintTailSampler.as`（f0706d7f…e3f1601），顺序是 claim → clear → internalAllocs(false) → start → 约150ms计算 → pause → count → 有界枚举 → stop → clear → release。计算分为256次算术一批，每批检查时间，最多131072批（33554432次算术循环）；结果校验值写入JSON，计算不会因无可见结果而被删去。样本枚举上限32768，最多保留4个短栈例子。异常仍清理本人租约，未清理不释放；CPU必须大于0、总数与暂停后的枚举相等、清理及顺序完整才通过。

`run.py` 复用准确原组件运行器，只把唯一的 `-debug=true` 片段替换为 `-debug=false -optimize=true`。原登记、1GiB AIR启动门槛、隐藏独立进程、60秒保护、安装与源指纹检查不改。原运行器本身只读；真实编译命令仍写入 `compile-command.json`，单差异和包装指纹另写 `positive-adaptation.json`。组件只编译两个AS文件。

根执行：

```powershell
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/recovery-paint-sampler-positive/run.py --output build/m52/recovery-paint-sampler-positive-01 --registry-wait 900
```

预期断言数为 **1**。准备者未编译/启动AIR。完整输出包含工作耗时、循环数、校验值、API顺序、CPU/分配/删除样本数及短栈。单次失败仍需检查是否有异常、截断或进程被长时间挂起，不能直接宣布整个采样API不可用。

## 旧成功记录的只读核对

旧成功 `b3d7b8558b`：`build/m52/recovery-after-render-sampler-drivers-01/command.json` **f9e87e2c…672006** 也是 `-debug=false -optimize=true -swf-version=38`；其prepared指纹 **86e620b7…a66bac** 与旧运行intent一致，编译产物与旧运行实际复制的EffectsDriver逐字相同。新尾段实际编译命令 **9cce2b66…48a9e** 使用相同三个选项。**没有debug模式差异。**

旧源与实际编译源一致，API顺序同为 clear → internalAllocs(false) → start → pause → 枚举 → stop/clear。旧路径直接调用API，没有先调用getSampleCount；新路径通过准确adapter并在暂停后先读取count。旧记录主侧854/加入1614个CPU样本、每侧24窗，只证明那次成功采样，不能解释本轮0样本。此正控制保留新adapter和count顺序，先排查当前接口是否能产生样本；不新增游戏修正或性能资格。
