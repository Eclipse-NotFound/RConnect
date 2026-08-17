# RConnect 联机架构设计（MVP → 目标）

> 本文是当前模组的实现设计，非游戏本体知识。游戏机制依赖见
> `knowledge/` 与 `shared-knowledge/`。

## 1. 目标

让安装了 RConnect 的 Remains 玩家通过互联网联机游戏。
MVP 范围：两人在同一 Location 内互见对方角色实时移动。
后续：更多人、战斗/物品/敌人状态同步、公共服务器列表。

## 2. 总体拓扑：宿主-客户端（host-client）

```
[宿主 A]──ServerSocket(端口 P)──┬──[客户端 B]
   自己游玩                     └──[客户端 C]（后续扩展）
```

- **MVP 采用"宿主权威中继"**：每个端每 tick（默认 20Hz）把自己的玩家状态
  快照发给宿主；宿主合并成世界快照广播给所有端。
- 直连：客户端手动填宿主 IP:端口。NAT 后宿主需端口转发（文档注明）。
  后续版本考虑公共中转/打洞服务器（独立进程，不进游戏）。
- 不采用 P2P 对等网：两人无服务器情形下谁当宿主谁开端口即可，复杂度最低；
  也避免对等网中的冲突仲裁。

## 3. 协议（MVP：TCP + 长度前缀 JSON）

- 帧格式：`uint32 big-endian 长度 + UTF-8 JSON`。JSON 便于开发期调试，
  4 人以下 20Hz 流量远低于带宽上限；优化为二进制留到功能稳定后。
- 消息（`type` 字段区分）：
  - `hello`：握手。{proto 版本、昵称、角色 host/join}
  - `welcome`：宿主发 {分配 playerId、当前 tick}
  - `playerstate`：玩家状态快照 {id, seq, x, y, storona, dx, dy, stay,
    sost, hp, aimX, aimY}（字段随接入能力增减，缺失字段容忍）
  - `worldstate`：宿主广播 {tick, players:[{id, ...快照}]}
  - `chat`：聊天 {text}
  - `goodbye`：离开
- 规则：客户端只发 playerstate/chat/goodbye；宿主只发 welcome/worldstate。
  版本不匹配时按 `proto` 字段拒绝并提示。

## 4. 模组内部结构（AS3）

```
src/
├─ RConnectMod.as      入口类（静态 init(main) —— 加载器契约要求）
├─ core/
│  ├─ Session.as       状态机：offline → hosting/joining → connected
│  ├─ NetClock.as      tick 定时（Timer，默认 50ms）
│  └─ Config.as        读 release/config.txt（JSON；缺省值兜底）
├─ net/
│  ├─ Protocol.as      消息类型常量 + JSON 编解码 + 帧读写
│  ├─ TcpLink.as       Socket 封装：分帧、粘包/半包处理、事件分发
│  └─ HostServer.as    ServerSocket：接受连接、peer 表、广播
├─ game/
│  ├─ GameBridge.as    游戏状态读取/写入（public 成员 + 探测，遵守 #1069 规则）
│  ├─ VersionProbe.as  运行时版本识别（1.02/1.03/1.04）与能力探测
│  └─ RemotePlayer.as  远程玩家幽灵单位：创建/驱动/销毁
└─ ui/
   └─ NetHud.as        覆盖层：连接状态、输入 IP/端口、聊天框
```

## 5. 游戏接入（关键约束来自 shared-knowledge）

- **只能动 public 成员 + 反射**；internal/private 不可访问；密封类用
  `obj["不存在成员"]` 抛 #1069 且吞 try——一律先 `try { hasX = obj["x"]!=null }`
  探测再分支。
- **时序**：模组 ENTER_FRAME 晚于游戏 step（读到的状态是"本帧游戏刚算完的"，
  正适合采集）；KEY_DOWN 先于游戏 Ctr（用 `stopImmediatePropagation` 才能抢键，
  MVP 界面按键注意避开游戏键位）。
- 自己状态读取：`loc.gg` 公开字段（x/y、storona、dx/dy/stay、hp、sost、
  瞄准 celX/celY 等），详见 shared-knowledge/entities/facts/unitplayer.md。
- 远程幽灵单位：计划用现有小马单位类（UnitPon）或 VirtualUnit 克隆一个
  "不受 AI 控制的旁观单位"，`setPos/setVisPos` 驱动位置，用公开动画接口
  （animate/anims 状态字段）驱动姿态；具体构造方式在阅读反编译源码
  （game-reference/decompiled/1.02/src102 首选）后定案并记录。
- 显示层注意：Grafon.setLight→drawAllObjs 会重建显示层，可能抹掉孤儿视觉
  —— 幽灵单位必须挂进游戏自己的容器（loc 单位体系），不要自建游离 display 树。

## 6. 版本兼容策略

- 加载契约三版本相同（knowledge/facts/loader-contract.md），入口类一致。
- 游戏类 API 可能随版本不同：GameBridge 所有访问先探测
  （getQualifiedClassName 分流 + 布尔探测），不假设单一版本。
- 用 `describeType`/探测结果在运行时记录"本版本能力清单"，写入日志便于诊断。

## 7. UI（MVP）

- 屏幕角落一个半透明 TextField 面板：状态行（离线/主持中/已连接+延迟）、
  昵称、IP/端口输入框、主持/加入按钮、聊天输入+消息列表。
- 全部是模组自建显示对象，挂 stage，不进游戏显示树。
- 键位：F10 开/关面板（避开游戏键位表 keyXML 里的常用键）。

## 8. 配置

`release/config.txt`（JSON）：nickname、role、hostIp、port(默认 23456)、
tickMs(默认 50)。缺文件或字段缺失用默认值；宿主与客户端各自本地保存。

## 9. 测试策略

1. **独立测试容器**（build/testapp/）：最小 AIR 应用，按游戏加载契约
   （Loader + LoaderContext(false) + getDefinition + init）加载 RConnectMod.swf，
   暴露假 world 对象。用它验证：加载、AIR 网络 API 可用性、双实例 TCP 互连、
   协议往返。不依赖游戏本体。
2. **游戏内冒烟**：真机启动游戏，确认补丁加载器日志（RConnectMod: load start
   → init returned），HUD 可见。
3. **双开联机实测**：两实例同机 127.0.0.1 联机，验证幽灵单位随动；再测局域网。
4. 每次实验产出记入 knowledge/experiments/。

## 10. 里程碑

- M1（完成）：补丁加载器 + 模组加载成功 + HUD 显示 + 双实例 hello 握手。
- M2（完成）：位置同步（幽灵单位可见、跟随）。
- M3（完成）：姿态动画（visualPlayer 驱动）、血量 HUD、断线重连、聊天。
- M4（完成，世界一致性 MVP）：世界身份握手 + 宿主 5Hz 单位镜像。
- M5（规划）：战斗权威、跨房传送同步。

## 11. 世界一致性（M4 方案与 M5 课题）

前提（实测）：同存档模板开局 = 确定性世界（同地图/同房间/同坐标源/同单位集，
按 Unit.id 可 100% 匹配）。详见 knowledge/experiments/2026-08-15-m4-world-sync.md。

- M4 现状：宿主权威——每 200ms 广播 `loc.units` 快照，客户端按 id 镜像
  位置/朝向/sost/hp。
- 已知缺陷（M5）：
  1. 客户端本地 AI 与镜像对抗（单位在同步间隔被本地 AI 挪动再被拽回）。
     候选方案：客户端侧对"被同步单位"置 disabled + 只播动画（与幽灵同思路），
     把 AI 完全交给宿主；代价是客户端看敌人是"傀儡"，攻击结算需事件化
     （客户端发起攻击 → 宿主结算 → 状态回流）。
  2. 跨房传送：welcome 后 worldInfo 不更新；宿主换房间时客户端需跟随。
     公开入口 `World.ativateLoc/ativateLand/redrawLoc` 待调研。
  3. 进度不兼容：不同进度的存档世界无法互相对齐（文档限制：联机需同档开局）。
