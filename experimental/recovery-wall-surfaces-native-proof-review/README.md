# 大图墙痕证据独立复核

2026-10-22。只读重分析既有原生运行，未启动 JVM/AIR、未改驱动、模组、宿主或原结果。原 `wall-surface-result.json` 的 PNG 失败仍保留。本目录不是新的游戏运行，也不提供发布或性能资格。

## 结论

原分析器将 PNG 解码后的 straight ARGB 与 `BitmapData.getVector` 数组逐 uint 比较。两轮 PNG 的差异全部是半透明像素的 RGB 取整差异：alpha 完全相同，RGB 各通道最多差 1，且每一对差值都包围同一个整数预乘通道值。独立分析器仅修正这项**截图表示校验**，实际源端→对侧的 JSON uint 比较一字未改。

- 旧 14 + FD92，`b4380cdb0a`：32 张 PNG 均通过限定的表示兼容校验。四轮源端真实产生 119 / 101 / 1466 / 1262 个变化像素，对侧均缺失，四轮同步仍失败。现在可将这四轮作为实际负例；不能把原 PNG 解析失败本身算作产品失败。
- 16 + ACC，`f80b01a647`：32 张 PNG 同样通过表示校验，但四轮实际像素仍差 1 / 1 / 3 / 1，**四轮仍失败**。没有把这些差异归零、修改期望或放宽容差。
- 离线检查实际 15 / 0；原始 14 项结果也保留。它验证分析器及反例，并不表示候选游戏通过。

| 轮次 | 实际源端 | 旧 14 原生变化 / 未同步 | 16 原生变化 / 严格不一致 | 16 首次远端可见差值 |
|---|---|---:|---:|---:|
| 0 | 主侧 LMG | 119 / 119 | 104 / 1 | 888 ms |
| 1 | 加入侧 LMG | 101 / 101 | 53 / 1 | 444 ms |
| 2 | 主侧 plamg | 1466 / 1466 | 1327 / 3 | 739 ms |
| 3 | 加入侧 plamg | 1262 / 1262 | 731 / 1 | 1063 ms |

上述延迟是现有墙钟观察点之差，保留了采样误差和帧间隙，不能视为指令级命中到显示延迟。16 的最大观察间隙最高 462 ms；第四轮加入侧单次 capture 最大 92 ms。PNG 编码与像素读回均在双方动作采样结束后完成。没有性能通过结论。

## PNG 校验究竟改了什么

原 driver04 分析器固定 SHA：`a3e8d886772d8facada4363331e79b6277c582b316f05c00e360e7edd247e874`。`verify_evidence.py` 核验该指纹后加载原函数，仅替换一条 PNG 数组相等断言；断言锚点不是恰好一次即拒绝。其余 PNG 格式/尺寸、日志中的文件名和字节数、角色/轮次、真实 native collision oracle、武器开火、坐标、至少 5 像素、10 秒/480 帧、持久性以及源端/对侧精确比较全部沿用原函数。

兼容规则：相等值直接通过；不等值必须 `0 < alpha < 255`、alpha 完全相同。每个不同 RGB 通道必须相差恰好 1，并存在唯一整数 `p` 满足：

```text
min(c, d) * alpha <= 255 * p <= max(c, d) * alpha
0 <= p <= alpha
```

这是同一预乘字节还原为向下/向上整数的包围条件，不是任意 ±1 容差。不透明像素差异、alpha 差异、全透明隐藏 RGB 差异、2 级差异、位置错移，以及不满足该包围条件的 1 级差异均拒绝。例：`387f7f76 → 38808076` 符合；alpha 56 时通道 51→52 不符合。

旧版 32 张 PNG 共 936 个表示不同像素、1338 个不同通道；16 共 960 / 1408。两轮均没有不透明、全透明或 alpha 不同的 PNG 像素。详细逐文件结果及最多四个例子见两份 reanalysis JSON 的 `png_audit`。

AIR 官方说明 BitmapData 内部采用预乘像素，`getVector` 返回未预乘的 uint 值；这支持检查表示转换的方向，但官方没有保证本机 PNG 编码器与 `getVector` 的具体取整相同。[BitmapData 官方 API](https://airsdk.dev/reference/actionscript/3.0/flash/display/BitmapData.html)、[原生 PNG 编码说明](https://airsdk.dev/docs/development/display/working-with-bitmaps/compressing-bitmap-data)。因此报告使用 `png_representation_compatible`，**不称 PNG 位级相等**。本代理没有运行专门验证 PNG 编码取整的原生小测试。兼容规则不能排除刻意构造、恰好仍在同一包围区间的半透明 1 级篡改；其用途是既有截图表示交叉核验，实际游戏数组始终严格比较。

## 候选实际色差仍单独保留

16 的实际源/对侧差异：

```text
round0 index7106  f664625b → f663625b
round1 index6722  f6817f77 → f6807f77
round2 index5440  ee595953 → ee595952
round2 index6737  ff43433c → ff42423c
round2 index11201 e64d4d48 → e64c4c48
round3 index6081  e6524d4b → e6524c4b
```

主会话另行执行的 `recovery-wall-color-roundtrip-01/component-result.json` 7 / 0 表明：原生 setPixel32/setVector/setPixels 会重现这五个半透明变化，但单次写入不会重现 opaque `ff43433c` 的变化。这是实际回执，**不等于 PNG 编码取整的实验**，也不证明 opaque 差异已解决。该点的分块只读检查见 [gutter-review.md](gutter-review.md)。

## 文件与可复核命令

- `verify_evidence.py`：独立只读重分析，仅允许在本目录写一个尚不存在的新结果。
- `control-reanalysis.json` / `candidate-reanalysis.json`：两轮实际重分析；原日志、PNG、JSON、框架结果、原分析失败结果在前后逐文件 SHA 核验不变，哈希完整保存在 `input_sha256`。
- `check_offline.py` / `offline-result-v2.json`：15 项正反例；旧 `offline-result.json` 14 / 0 保留。
- `inspect_gutter.py` / `gutter-review.json`：复算既有 core 证据的世界坐标、重叠边界和逐帧值，不伪造缺失的邻块像素。
- `handoff.json`：本目录交付文件及引用源码/小实验结果指纹。

在 RConnect 根目录运行，纯 Python，不启动游戏：

```powershell
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/recovery-wall-surfaces-native-proof-review/check_offline.py
```

如需再次独立重分析，输出必须换为本目录尚不存在的文件名；已保存两轮结果无需重复覆盖：

```powershell
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/recovery-wall-surfaces-native-proof-review/verify_evidence.py --evidence build/m52/recovery16-wall-surfaces-native-01 --output experimental/recovery-wall-surfaces-native-proof-review/candidate-reanalysis-02.json
```

该候选仍有严格游戏像素失败，命令按设计返回 exit 1；不是分析器无法读取的错误。
