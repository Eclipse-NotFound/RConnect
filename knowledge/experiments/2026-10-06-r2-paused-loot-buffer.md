---
domain: world-objects
type: experiments
game-version:
  - "1.02"
confidence: medium
verified: false
discovered-by: RConnect
evidence:
  - kind: runtime-experiment
    summary: "隔离双实例暂停字段与独立AS3固定到达顺序，原检查时间、阈值不变。"
date-updated: 2026-10-06
---

# M46：暂停时收齐已收到的物品位置

final39 首组 `7df722ef4c` 加入侧仅一项 pause-expiry 的 loot 检查红；该断言是 `stay===true && Y<floorY-80`，旧日志没有当时的两项值，不能直接称为租约过期。

只读诊断 `abe8a83a22` 两端104/0、82/0且DONE，没有复现旧红。加入侧实物为 RemoteLoot、普通motion轨迹，remoteHeld/until字段缺失。assert-pause时实际Y=200/stay=true；游标已经选到宿主抬起帧。诊断API/每包日志已从生产与生命周期测试移除；原日志保留。

独立AS3固定顺序：200ms物品流，先收到地面位置，700ms收到Y=200的抬起位置，720ms冻结呈现时钟。缓冲仍显示较早位置，之后静态抬起快照继续到达。测试没有加载游戏、存档或已安装模组，仅编译对应的RemoteMotion源。相同测试和文档SHA：旧final39源 `47467ce38c` 三项失败，修正源 `d37af256be` 六项通过，覆盖带时间戳/无时间戳收齐、1500ms以上暂停、恢复不倒播及恢复落地。

这证实缓冲暂停边缘缺陷，但不是对旧7df唯一因果的反向认定。旧源负控fallback是原GameBridge的sample(pauseAt)调用；新源调用settle(pauseAt)。测试只收齐收到的末帧，不外推未知位置。

修正仅在GameBridge的暂停loot路径调用RemoteMotion.settle：清到最新已收到位置/状态，保留游标；运行时继续原sample平滑路径。不改变原生念力资格、NPC所有权、TTL、重力或原生命周期断言/时长。新6项顺序检查加入Motion测试，原MovableGripLifecycle内容恢复。

候选 `final-r2-pause-02` / `2c83df6b…` /116001B/50类/51源/140验证，原生双人Motion `12b52871d3` 返回0，两端DONE且无FAIL，原暂停loot断言两端通过，原断言/时间/阈值不变。精确计数、日志SHA与候选闭包见 `build/m46/r2-pause-fixed-handoff.json`。当前release仍M45，57保护指纹未变；此项通过不替代其余联合门禁。总审计与部署窗口在原RConnect会话，本会话交回证据和代码窗口。

测试输出路径首试 `0fddcc43fd` 编译成功，但独立AIR向app:/写结果触发FileStream.open错误后超时。自身PID已终止，input/build/adl原证据保留；后续改唯一appid的专用storage后两次正常结束。这是独立测试输出路径失败，不计游戏异常。诊断回读入口 `build/m46/r2-pause-diagnosis.json`。
