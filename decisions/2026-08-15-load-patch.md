# 决策：RConnect 采用"追加独立加载器"补丁方案

- 日期：2026-08-15
- 状态：已采纳并实施
- 决策者：用户授权 + agent 执行

## 背景

补丁后三份游戏 SWF 的 MainFE 只有一个单模组加载器，硬编码只加载
`app:/mods/Sandevistan/release/SandevistanMod.swf`。RConnect 若不被加载，
一切联机功能无从谈起。

## 考虑过的方案

| 方案 | 结论 | 原因 |
| --- | --- | --- |
| 修改 Sandevistan 让其为 RConnect 提供多模组加载 | 否决 | 修改其他模组，超出 AGENT_SCOPE 授权边界；需跨模组协调 |
| 把加载器路径/类名替换成 RConnect，由 RConnect 转手加载 Sandevistan | 否决 | 链式耦合：RConnect 缺失/出错会连带破坏 Sandevistan；也依赖对方内部契约 |
| 字节级硬补丁（直接改 ABC 字符串/字节） | 否决 | 新字符串更长时需重建常量池，脆且难维护 |
| ffdec `-importScript` 重编译 MainFE 追加第二加载器 | **采用** | 语义清晰、可脚本化重复执行、可校验；MainFE 很小（~100 行），重编译风险可控 |
| 手术式 ABC 改写（只改单个方法体） | 备选 | 风险更低但工程量大；若 importScript 实测有问题则回退此方案 |

## 决定

1. 在 MainFE 中追加与 Sandevistan 加载器**平行、独立**的 `loadRConnectMod()`
   / `onRConnectModError()` / `onRConnectModLoaded()`，新增字段
   `rconnectLoader:Loader`；加载 `app:/mods/Rconnect/release/RConnectMod.swf`，
   查类名 `RConnectMod`，调用静态 `init(main)`。
2. 不改变 Sandevistan 加载路径、类名、调用方式与顺序（两者都在 MainMenu 构造后
   依次发出加载请求，互不等候）。
3. 补丁做成幂等脚本 `tools/patch_game_swfs.py`：
   - 每次改前自动备份原 SWF 到 `mods/Rconnect/build/backup/`；
   - 补丁后重新导出校验：RConnectMod 与 SandevistanMod 标记必须同时存在；
   - 锚点缺失即报错退出，绝不静默产出半成品。
4. 三个版本（1.02/1.03/1.04）全部补丁，满足"尽量全兼容"。

## 风险与对策

- **Sandevistan sync 覆盖**：其同步脚本可能用 C:\RemainsMod 里的版本覆盖
  游戏目录 SWF，补丁丢失。对策：补丁脚本可随时重跑；文档与 state 均已记录。
- **importScript 重编译语义风险**：MainFE 是文档类，重编译理论上可能引入
  细微差异。对策：副本实测 + 校验 diff 仅三处新增 + 真机启动游戏验证
  （沙盒期先跑 1.03）。
- **与未来 Sandevistan 版本冲突**：若对方更新 MainFE 结构，锚点失配脚本报错，
  人工适配后再跑。
