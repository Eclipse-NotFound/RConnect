---
domain: knowledge-validation
type: discoveries

game-version:
  - "1.02"
  - "1.03"
  - "1.04"

confidence: medium
verified: false

discovered-by: RConnect

evidence:
  - kind: runtime-experiment
    summary: "真机与测试容器实测：模组子域里访问 main 与 stage 的 loaderInfo.url
      均返回模组自己的 URL（app:/mods/Rconnect/release/RConnectMod.swf），
      而非宿主 SWF 的 URL；getQualifiedClassName(main) 正常返回 MainFE"

date-updated: 2026-08-15
---

# 发现：从模组子域跨域读取 loaderInfo 不可靠

## 观察到

模组（子 ApplicationDomain，LoaderContext(false) 加载）内：

- `main["loaderInfo"]["url"]` → `app:/mods/Rconnect/release/RConnectMod.swf`
  （模组自己的 URL，不是宿主游戏的 URL）
- `main["stage"]["loaderInfo"]["url"]` → 同样返回模组 URL
- `getQualifiedClassName(main)` → `MainFE`（正常，main 身份无误）
- `main == main["root"]` → true（文档类实例是 root，正常）

## 推测

- 跨 ApplicationDomain 访问 `loaderInfo`（DisplayObject 的 getter）时，
  运行时可能按"当前执行域"解析了某些内部引用，导致返回模组 SWF 的 LoaderInfo。
- 另一种可能：主时间轴存在命名实例遮蔽（MovieClip bracket 访问会先查时间轴
  子对象），但 stage.loaderInfo 同样反常，说明更可能是域解析问题。

## 尚未验证

- 具体机制（是否需要 SecurityDomain、是否为 AIR 30 特有行为）。
- 其他 DisplayObject 公共 getter 是否存在同类现象。

## 规避（模组现行做法）

- 版本识别改用 `fe.World` 实例的 `constructor` 读取静态常量（见
  facts/version-fingerprint.md），不依赖 loaderInfo。
- loaderInfo 仅作日志参考；凡涉及跨域解析的结论，一律以实例身份
  （getQualifiedClassName / constructor）为准。
