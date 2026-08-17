---
domain: knowledge-validation
type: facts

game-version:
  - "1.02"
  - "1.03"
  - "1.04"

confidence: high
verified: true

discovered-by: RConnect

evidence:
  - kind: decompiled-game-code
    symbol: "MainFE.loadSandevistanMod / onSandevistanModLoaded / onEnterFrameLoader"
    summary: "对游戏目录中三份补丁后 SWF 反编译（ffdec 26.2.1）；补丁管线在副本上实测，
      双标记校验通过，1016 个类无增减"

date-updated: 2026-08-15
---

# 补丁后游戏 SWF 的模组加载契约

> 本条描述的是**补丁后**游戏文件（Sandevistan 部署管理的版本）的加载行为，
> 不是原版游戏机制。公共注入模型总览见
> `shared-knowledge/knowledge-validation/facts/modding-interop.md`。

## 加载器位置与时机

- 三份游戏 SWF（根目录 `pfe.swf`=1.02、`DLC/pfe.swf`=1.03、`DLC/pfeUI.swf`=1.04）
  的文档类 `MainFE` 都带同一份单模组加载器代码。
- 时序：`MainFE` 构造注册 `ENTER_FRAME`；`loaderInfo.bytesLoaded >= bytesTotal`
  后 → 隐藏载入画面 → `nextFrame()` → `this.mainMenu = new MainMenu(this)` →
  `loadSandevistanMod()`。
- 推论：模组 init 发生在 MainMenu 构造**之后**——与 shared-knowledge 中
  "模组帧代码永远晚于游戏 step、KEY_DOWN 永远先于游戏 Ctr" 的时序结论一致。

## 加载契约（模组 SWF 必须满足）

1. 路径硬编码：`app:/mods/Sandevistan/release/SandevistanMod.swf`（app:/ = 
   游戏根目录，即 application.xml 所在目录）。
2. `new Loader()` + `new LoaderContext(false)` —— **未指定 applicationDomain，
   模组加载进当前（同一）ApplicationDomain**（本说法经 MoreSkills&Weapons 核实，
   见 shared-knowledge/knowledge-validation/discoveries/
   mod-loader-patch-structure.md）。internal/private 可见性按 ABC 块（SWF）
   强制，同域下模组仍访问不到游戏 internal 成员；public 动态访问与
   "不可 hook 游戏原型"等约束不变。
3. COMPLETE 后：`loaderInfo.applicationDomain.getDefinition("SandevistanMod")`
   → 拿到 Class → `cls.init(this)`。
4. 因此模组入口类名必须精确等于查找名，且 `init` 必须是**静态**方法，
   签名 `init(main:MainFE)`。
5. 加载/初始化全程 try 包裹，失败只 trace（"SandyMod: ..."），不阻断游戏。

## 多模组合并现状（2026-08-15）

- 根 `pfe.swf`（1.02）已含 4 个 loader（Sandevistan → RConnect → RealisticVision
  → MoreSkills&Weapons），其他开发者合并时**保留了本模组的 loader 段**；
- `DLC/pfe.swf`（1.03）、`DLC/pfeUI.swf`（1.04）只有 Sandevistan + RConnect；
- 合并前备份在各开发者自己手里（游戏根目录可见 pfe_1.02_before_* 两份），
  本模组备份在 `build/backup/current-merged-20260815/`。

## RConnect 补丁方式（本模组自用）

- `tools/patch_game_swfs.py` 用 ffdec `-export script` → 文本插入 →
  `-importScript` 重编译 MainFE，追加独立的 `loadRConnectMod()` 加载器：
  路径 `app:/mods/Rconnect/release/RConnectMod.swf`，类名 `RConnectMod`。
- 与 Sandevistan 加载器完全独立：任一失败不影响对方与游戏。
- 补丁幂等（已有标记则跳过）、自动备份到 `build/backup/`、校验两个标记共存。
- 锚点：`internal var sandyLoader:Loader;`、`this.loadSandevistanMod();`、
  类结尾 `   }`。锚点缺失时报错——说明 MainFE 结构已变化（如 Sandevistan
  sync 更新），需人工适配。
