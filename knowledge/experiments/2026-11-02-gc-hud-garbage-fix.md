# 2026-11-02 HUD 每帧垃圾分配修复（gcfit1）

## 背景

ContinuousScene 会话在 2026-11-02 的大场景组合采样中把 RConnect 列为纯垃圾源之一：
`RCLocale$/fit < NetHud/layout < NetHud/refresh < Session/onTick` 每帧 ~139 个对象、
**100% 当窗死亡**（24 采样窗合计 3,324/3,324）。移交报告：
`mods/ContinuousScene/knowledge/handoff-gc-attribution-20261102.md`。

调用链语义：`Session` 的 `_tick` Timer（构造即启动，offline 也跑）每 tick 无条件
`mod.hud.refresh()` → `layout()` → 对 30+ 个 HUD 字段调 `RCLocale.fit()`。

## 根因（三处叠加）

1. **`RCLocale.fit` 拼签名串**：每次调用 `field.text+"\u0000"+width+"/"+height`——
   `TextField.text` getter 的 native String 封送 + Number→String + 多级 concat，
   每次调用约 5 个短命对象，每 tick 30+ 次调用。这就是被点名的 fit 栈。
2. **`NetHud.layout` 的每 entry 分配**：`t.scrollRect=new Rectangle(...)`（30/帧）与
   两处 `[...].indexOf(t)` 数组字面量（38/帧），叠加 `nativeObstacles` 的视口
   Rectangle 与结果数组。对应基线 `NetHud/layout` 栈 1,080 当窗死亡。
3. **`RCLocale.language()` 无缓存**：每 tick 被 `text()` 调 60+ 次，每次
   `normalize()` 新建 RegExp（字面量每次求值新建）与字符串。未进移交点名榜
   （单栈量低），但同在 refresh 每 tick 路径上。

## 修复（commit 3f99a7e，版本 0.2.24-gcfit1）

- **`RCLocale.fit` 数值键快路径**：缓存的比较键从"文本内容签名字符串"改为
  `(w, h, textWidth, textHeight, length)`——全部是标量 getter，比较零对象分配。
  正确性：fit 的输出（字号）只是这些标量的函数，键相等 ⇒ 结果必然相等；
  新键比旧字符串键更精确地对应决定因素（旧键在"文本变但测量值全同"时会做
  一次结果必然相同的重算）。
- **`RCLocale.language()` 结果缓存**：`codeCache` 由既有的 200ms 语言 watcher
  失效重读；`normalize()` 的分配从每 tick 60+ 次降到每 200ms 一次。
- **`NetHud.layout` 复用**：per-entry `entry.clip` Rectangle 复用；比较集合
  （connectInputs/noFitFields）惰性构建一次；`nativeObstacles` 复用视口
  Rectangle 与障碍列表；`peers()` 离线态共享空数组常量。

## 验证（A/B，探针字节与基线完全一致）

工具：ContinuousScene v14 FrameCostProbe（`flash.sampler` 出生栈归因），fork 到
`build/generated/gc-verify-v14-20261102/`——探针 SWF 与测量源文件逐字节等于原版
（probe-build.json sources 校验），仅 run_once/分析脚本是路径适配。运行副本
`build/runtime-gcverify/` 携带基线组合字节与 loader-manifest（14 模组+探针，
1.02 宿主 A9B39CC7），**唯一变量是 RConnectMod.swf：tcp1 → gcfit1**。
（正式清单当日被 ConditionSystemMod 重复入口阻塞，故跳过"从正式刷新"步骤，
这反而让 A/B 更单变量。）

证据：`evidence/rconnect-gcfit-verify-r1/`（result.json、inputs.json、日志、
lead-inputs.json；登记 owner=RConnect / gc-fit verify v14，独占 game）。

| 栈（24 采样窗合计） | tcp1 基线¹ | gcfit1 | 变化 |
|---|---|---|---|
| `RCLocale$/fit < NetHud/layout < refresh < onTick` 新/死 | 3,324 / 3,324 | **0 / 0** | 消除 |
| `NetHud/layout < refresh < onTick` 当窗死亡 | 1,080 | 37 | -96.6% |
| `RCLocale$/normalize`（translate/text 路径） | （未单列²） | 200ms 周期小批 | 周期化 |

¹ 基线 = ContinuousScene `envkey-gcattrib-r1`（同探针、同组合口径，取自其
gcattrib-summary.json）。² 基线数据中该路径的分配散在 language 栈，未单独点名；
gcfit1 后仅在 watcher 失效重读时出现（每 200ms 一次 normalize 批）。

残余（有意保留，不在点名链）：`getBounds` 的 native Rectangle（~11/帧，native
返回无法避免）、`HudLayout.measure` 返回 Object（1/帧）、`TextField.text` setter
内部（2/帧）、`NetKeybinds.tick` 的 getDefinitionByName（1.5/帧）、以及
GameBridge/roomKey 等游戏逻辑每帧路径（1-16/帧，合计 ~40/帧）——属另一话题，
量级低于本次消除的 ~185/帧。

功能面：`RConnectMod: v0.2.24-gcfit1 initialized`；tick 心跳 200→1400 连续 7 次；
`verror=false`；探针业务 checks 10/10 通过；世界 random_mane 135 单位/594 对象
（与移交报告场景同级）。

## 边界

- **对象个数口径**，非字节（String 死后无法测尺寸）；采样器自身增压，数字用于
  定位与对比，不作性能验收——沿用移交报告口径。
- 单实例 offline 即覆盖被修路径（Session._tick 不依赖联机）；HUD 视觉（字号/
  裁剪）未做截图核对，等价性靠"输出只依赖缓存键标量"论证，字号视觉回归留待
  后续 agent-debug visual（当前被正式名单 ConditionSystemMod 重复入口阻塞）。
- "修了不等于不卡"：移交报告预期管理适用——本修复的价值是把组合总分配速率
  降下来，帧收益需等 AddictionSystem 侧（persist/参数重建/Catalog 克隆，本轮
  数据中依旧健在：9,792/11,410/9,410/2,100）与 ContinuousScene envkey 缓存
  （67,412/98.8% 死，本轮榜首）一起组合复测。
- 部署：正式 release 已装 gcfit1（SHA256 `8AB94C8B…`，回执
  `build/gc-fit-deploy-20261102/deployment.json`，tcp1 备份同目录）。
  远端 GitHub 未发布；gcfit1 提交在 worktree 分支 `codex/a-tcp-tunnel`
  （`3f99a7e`，基于 b205d86）。

## 复现

```powershell
# 重建 runtime 副本（约 501MB，本轮结束已清理）
robocopy "mods\ContinuousScene\build\runtime" "mods\RConnect\build\runtime-gcverify" /E /MT:16
python mods\RConnect\build\gc-fit-deploy-20261102\make_harness_copies.py
python mods\RConnect\build\gc-fit-deploy-20261102\refresh_probe_hashes.py
cd mods\RConnect\build\generated\gc-verify-v14-20261102
python run_once.py <新证据名>          # 独占 game 登记；DSH 沙箱下需允许写 %APPDATA%（隔离测试应用存储）
python gcattrib_analysis.py <新证据名>  # 三榜+类型直方图
```
