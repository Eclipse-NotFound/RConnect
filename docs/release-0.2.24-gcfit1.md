# RConnect A 0.2.24-gcfit1 — 联机面板垃圾分配修复

发布日期：2026-11-05（本版二进制于 2026-11-02 部署）
基线：**0.2.24-tcp1**（九语言界面、animfix3 修复、TCP 内网穿透）

## 本版改动

`0.2.24-gcfit1` 只改性能，不改玩法与界面文案：

- `RCLocale.fit`：文字测量改为比较缓存的标量值（宽、高、textWidth、textHeight、长度），
  不再每次调用拼接 `text+N+size` 签名字符串。测量结果只依赖这些标量，值相等则结果相等。
- `RCLocale.language`：缓存归一化后的语言代码；已有的 200ms 观察器负责失效，
  `normalize()` 的正则与字符串开销从"每次取文本"降到"每个观察周期一次"。
- `NetHud.layout`：每个条目的 `scrollRect` Rectangle 复用，比较数组改为惰性复用；
  原生遮挡列表与视口 Rectangle 共享，空 peers 数组共享。

## 证据与部署

- 归因：ContinuousScene 2026-11-02 的移交报告实测出每帧约 139 个纯垃圾对象，
  链路为 `RCLocale$/fit < NetHud/layout < NetHud/refresh < Session/onTick`（24 帧采样 3,324/3,324），
  另有 1,080 个窗口内 `NetHud/layout` 栈上的死亡对象。
- 对照：冻结的 ContinuousScene v14 探针，同一组合只替换 `RConnectMod.swf`（tcp1 → gcfit1），
  探针字节相同。修复后上述垃圾分配不再出现，检查 10/10 通过。
- 部署：2026-11-02 本机部署 `0.2.24-gcfit1`，
  二进制 `RConnectMod.swf` SHA256 `8AB94C8B11E642D55DF11DD94490259BCBF47619EEB52A63F6E181AEFEE94EA8`（216,565 字节）。

## 验证边界

- 这是垃圾分配修复，**不等于**整体卡顿解决。长会话逐帧收益未做 A/B 复测（受组合模组阻塞）。
- HUD 字号的视觉核对（截图比对）未完成，只做了分配归因与离线检查。
- 真实公网节点、异地长局、稳定重连、三人以上、其他游戏版本与全部模组组合仍未验证。
- 仅支持普通 TCP；不使用 HTTP/HTTPS/UDP 转发或 Proxy Protocol。模组没有房间口令或应用层加密，
  请只向可信队友分享地址。

## English

`0.2.24-gcfit1` is a performance-only update on top of tcp1. It removes the per-frame garbage
allocated by the co-op HUD: cached scalar comparisons in text fitting, a cached normalized
language code invalidated by the existing 200 ms watcher, and reused scroll rectangles/arrays in
panel layout. Verified with a frozen ContinuousScene v14 probe that only swapped the mod SWF;
the recorded garbage chain disappeared. This is not a blanket stutter fix: long-session frame
gains, HUD text size visuals, real long-distance sessions and all mod combinations remain
unqualified. The full release notes (Chinese) are in `docs/release-0.2.24-gcfit1.md`.
