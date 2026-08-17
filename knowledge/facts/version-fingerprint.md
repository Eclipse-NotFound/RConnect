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
    summary: "三份游戏 SWF 反编译对比 World 类：唯一可区分的公开静态常量差异是 boxDamage
      （1.02=0.2；1.03=0.3；1.04=0.3 与 1.03 相同，1.03/1.04 其余 1016 个类同名同字段）"
  - kind: runtime-experiment
    summary: "真机三版本分别启动实测：application.xml→pfe.swf→0.2；app.xml→DLC/pfe.swf→0.3；
      app104.xml→DLC/pfeUI.swf→0.3，与磁盘文件逐一对上"

date-updated: 2026-08-15
---

# 游戏版本识别与启动链真相

## 启动链（实测确认）

- 用户正常启动链：`Remains.vbs → 1.BAT → adl64.exe -runtime runtimes\air\win64
  application.xml`。
- 根目录描述符内容（勿与其他描述符混淆）：
  - `application.xml` → `pfe.swf` = **1.02**（默认游玩版本，与 shared-knowledge
    "用户当前游玩 1.02" 一致）
  - `app.xml` → `DLC/pfe.swf` = **1.03**
  - `app104.xml` → `DLC/pfeUI.swf` = **1.04**
- DLC 目录内另有一套描述符/launcher（相对路径会解析到 DLC/DLC/…，不可用），
  不要被混淆。

## 版本指纹（模组可用）

- `fe.World.boxDamage`（public static const）：
  - 0.2 → 1.02
  - 0.3 → 1.03 或 1.04
- 1.03 与 1.04 的**类结构与公开 API 面完全一致**（1016 个类同名同字段），
  差异仅在 AllData 数据 XML 与少量内部逻辑数值（PipPageMed 治疗量、
  Unit 战斗音乐时长等）——联机接入无需细分。
- 可靠读取方式：先 `getDefinition("fe.World")` 拿 `w` 实例，再用
  `w["constructor"]["boxDamage"]` 从**实例自己的类**读常量。
  直接读 getDefinition 得到的类对象的静态成员理论上等价，但见
  discoveries/loaderinfo-cross-domain-anomaly.md 的教训：涉及跨域解析时
  一律以实例为准。

## 对模组的影响

- 版本探测以 boxDamage 为准，URL/loaderInfo 只作日志参考。
- 三个版本均已打加载器补丁，任一版本启动都能加载 RConnectMod。
