---
domain: knowledge-validation
type: experiments

game-version:
  - "1.02"
  - "1.03"
  - "1.04"

confidence: high
verified: true

discovered-by: RConnect

evidence:
  - kind: runtime-experiment
    summary: "独立测试容器（build/testapp，AIR 30 运行时）双实例联测：
      加载契约复刻、TCP 握手、worldstate 中继、聊天转发全链路通过"

date-updated: 2026-08-15
---

# 实验：独立测试容器验证模组加载契约与双实例联机（M1）

## 目的

不依赖游戏本体，验证 RConnect 模组：
1. 能按补丁后 MainFE 的契约被加载（app:/ URL + LoaderContext(false) +
   getDefinition("RConnectMod").init(main)）；
2. AIR 网络 API（ServerSocket / Socket）在模组运行环境中可用；
3. 双实例 TCP 握手、状态中继、聊天转发可用。

## 方法

- 测试容器 = 最小 AIR 应用（build/testapp/），文档类 TestMain 复刻游戏加载器
  的调用方式；模组 SWF 放在 `app:/mods/Rconnect/release/`（应用沙箱内），
  与真实游戏布局一致。
- host/join 两个实例目录：各自 app.xml（**app id 必须不同**，否则 AIR
  单实例机制会把第二次启动"转发"给第一个实例然后退出）、各自
  `mods/Rconnect/release/config.txt`（autoRole: host / join）。
- 用游戏同款运行时 `adl64.exe -runtime runtimes/air/win64 <app.xml>` 启动。
- 无头验证：模组 `Log` 类把日志写文件（app 目录写不进时回退到
  applicationStorageDirectory）。

## 结果（日志证据）

host 侧 RConnect.log：
```
RConnectNet: autoStart host
RConnectNet: peer #1 'JoinB' joined
RConnectNet: chat 'JoinB': hello from JoinB
```
join 侧 RConnect.log：
```
RConnectNet: autoStart join
RConnectNet: connected to host, sending hello
RConnectGame: remote player #0 first seen
RConnectNet: welcome id=1 host=HostA
```

## 结论（已确认）

1. 加载契约成立：`getDefinition("RConnectMod")` 可找到普通类（无需继承
   Sprite）；但 mxmlc 编译时必须用**空的 Sprite 文档类**（RConnectDoc）作主类，
   否则 RConnectMod 被当作文档类 → 加载时 Error #2023
   （"Class must inherit from Sprite to link to the root"）。
   且文档类必须**强引用** RConnectMod（如 `public static const MOD_CLASS:Class =
   RConnectMod`），否则 mxmlc 死代码消除会把入口类整个剪掉（SWF 仅 565 字节）。
2. **AIR 网络 API 在模组沙箱可用**：ServerSocket.bind/listen、Socket.connect、
   双实例握手全部成功（AIR 30 运行时，模组按 AIR 内容编译，swf-version 38）。
3. worldstate 中继、peer id 分配、聊天转发按设计工作。
4. 模组日志写 `app:/mods/Rconnect/` 在本机（Program Files 路径下 ADL）
   **失败且静默**，回退到 applicationStorageDirectory 成功
   （真实路径 = %APPDATA%\<appId>\Local Store\）。

## 踩坑记录（有价值）

- AIR 单实例转发：同 app id 的第二个 ADL 实例不启动（"invocation forwarded
  to primary instance"）→ 测试实例必须用不同 app id。
- Windows ADL 的 trace 不进 stdout（GUI 子系统）→ 必须文件日志才能无头验证。
- File.applicationDirectory 在 Program Files 下写入失败时无异常细节可查，
  一律 try/catch + 多级回退。

## 尚未验证

- 真实游戏内加载（下一实验：真机冒烟）。
- 幽灵单位渲染（M2）。
