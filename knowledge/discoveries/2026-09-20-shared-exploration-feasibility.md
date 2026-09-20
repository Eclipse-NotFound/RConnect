---
domain: rendering
type: discoveries
game-version:
  - "1.02"
confidence: medium
verified: false
discovered-by: RConnect
evidence:
  - kind: source-code
    summary: "RConnect GameBridge.readSeenMask/buildSeenMask/applySeenMask 与 Session.broadcastWorldState/applyWorldState；Config 与 NetHud 设置入口。"
  - kind: decompiled-game-code
    game-version: "1.02"
    symbol: "fe.loc::Location.lighting/lighting2/getTile; fe.loc::Tile.updVisi; fe.graph::Grafon.setLight"
  - kind: source-code
    summary: "RealisticVision v0.29.0-candidate 的 computeFov、resetRoom、子格探索记忆、渲染与 MSW 设置注册，仅最小范围只读。"
date-updated: 2026-09-20
---

# 双向共享探索：源码可行性与待定规则

本轮任务是探查，未修改功能代码、编译、启动游戏或部署。以下区分用户决定、源码证据和待验证方案。RConnect 已提交基线为 `8aeacb7` / M29；探查期间工作树出现其他战斗相关改动，本轮不把它们作为已验证行为，也不纳入本轮提交。

## 已确认

### 用户目标与决定

- 目标：任一方探索过的区域也能在另一方显示，并在设置里保留开关。
- Q1 已决定：**双向共享**。
- Q2 用户原话：**“按原版机制确实为已探索的区域完全明亮。对RealisticVision的兼容以它自身的设定为准”**。实现不能绕过 RV 的记忆暗度、模式和其他视野设定。
- 当前范围是探索显示的调查；尚未拍板原版瞬移/目标交互是否同时把共享区域算作本地已探索，也未拍板改动既有 M27/M29 的镜像敌人报点规则。

### 现有 RConnect 有同步骨架，但并未满足目标

| 位置（本次读取行号） | 源码证据 | 后果 |
|---|---|---|
| `GameBridge.readSeenMask`，1949 | 只有 `loc` 对象改变时才重建 `_seenCache` | 同一房间后续探索不会持续发布；退出也未清空该缓存。 |
| `buildSeenMask`，1972；`applySeenMask`，2014 | 按 `space[y][x]` 读写；原版是 `space[x][y]` | 收发两端同错可能掩盖转置，但非正方形房间会漏采样、漏应用。 |
| `Session.broadcastWorldState`，1121 | 宿主 WORLDSTATE 带 `{locId, cols, data}` | 仅宿主向加入端发送；加入端没有对应探索上报路径。 |
| `Session.applyWorldState`，1151 | 直接应用 seen；只靠 `loc.id` 匹配 | 缺少地图身份、房间代际、行数/长度和转场保护；相同房间 id 不保证同一地图。 |
| `GameBridge.applySeenMask`，2014 | `visi>=0.5` 编为 1；收到后直接设 `Tile.visi=1` | 把连续光照当布尔历史，没有配套目标光照/重绘逻辑，且不更新 RV 自有探索记忆。 |
| `Config.DEFAULTS`；`NetHud.buildPanel/refresh` | 当前没有共享探索选项 | 需补配置、会话有效状态和界面状态。 |

世界标识可复用 `GameBridge.readWorldInfo` 已有的 `curLandId`、`locId`、坐标与 `landStage` 等数据，再增加会话/房间代际。其他场景消息已有 `sameHostRoom` 和转场保护，探索通道尚未使用。

旁证：场景瓦片补丁 `buildTileBase/applyTilePatch` 也用了 `space[y][x]`，后续应检查公共网格访问方式；本轮只记录，不扩展为场景同步修复。

### 原版的“亮”不是独立探索布尔值

- `Location.getTile`（2328）返回 `space[x][y]`。
- `Tile.visi` 是当前连续光照，`t_visi` 是目标值；`updVisi` 向目标推进，若当前值高于目标会压回目标。仅改 `visi` 可能在下一次 `lighting2` 被覆盖。
- 普通房间 `Location.lighting`（3148）跳过已完全明亮的瓦片，保留探索亮度；距离边缘/遮挡可能只得到部分亮度。`retDark=true` 是会重新变暗的原版例外，不能据“原版已探索全亮”推导为取消此规则。
- 实际黑暗贴图为 `Grafon.lightBmp`，绘制坐标是 `(x,y+1)`；`lighting/lighting2/setLight` 都有相应更新代码。
- `Tile.visi` 还影响鼠标目标（`Location` 3486，0.1 门槛）、瞬移落点（`UnitPlayer` 1671、1703，0.8 门槛）及 `Unit.isVis`。修改它会改变玩法判定，不能把纯显示与操作能力混为一件事。

### RV 有独立记忆，现有代码无公开共享接口

- `fov` 表示本地即时视野；`explored` 表示曾见瓦片；`seenSub/fullySeen` 表示每格 8×8 子格的探索历史。三者不能互相替代。
- `computeFov`（1161）产生本地探索；`resetRoom`（748）按房间保存/恢复 `roomMem`。793–794 的注释明确记录过从 Tile.visi 播种记忆的方案已回滚。
- classic 的地板记忆主要读 `explored`（1967）；current 的地板记忆读 `seenSub/fullySeen`（1885）；墙面还使用原版光照（1824）。因此单写一个数组也不足以兼容全部模式。
- `inst`、上述数组及配置均 private。`startup` 只挂 stage 事件，没有公开实例、命名能力载体或探索接口。兄弟加载域中不能假定可直接取得对方静态类。
- 可以沿用项目已有的命名能力载体方式；RV 当前通过 `World.w.main.getChildByName("MSWModAPICarrier")` 读取 `modAPI`，用 get/set 回调注册设置页（3093 起）。这是消费设置 API，不是 RV 已有对外 API。
- 设置可接入现有“模组设置”聚合页，并在 F10 保留入口；聚合页缺席时仍需 F10 可用。无需为接入设置页修改 MSW。

## 观察到

- 本轮正式 RConnect SWF 仍为 M29，SHA256 `33CE3B722A3473CC24659E813F8BBB7A934B295F680BD5612A341515A6B38685`。
- 本轮 RV 源码及部署 SWF 均有 `v0.29.0-candidate` 标记；部署文件 20608 字节，SHA256 `5C26D604BA6AE33A92A5D11F8A6F6ABCFBF8BDE9663BAF3AB68E919A32B8C242`。标记和时间顺序相符，不代表已证明源码逐行对应产物。
- 该 RV 指纹已不同于 M29 回归时加载的文件，不能沿用旧组合测试来声称本次兼容通过。
- 旧公共记录 `world-objects/facts/location-space-seen-fog.md` 对“直接写 visi 自动显示、每房间发一次足够”的表述来自早期 M14 条件；不能推广到持续探索、目标光照回写及当前 RV。此次保留历史记录，差异在本报告明确标出，尚未用新运行实验裁定所有边界。

## 推测：建议实施方案，尚未执行

1. RConnect 负责双向采集与传输；按会话、地图、房间代际隔离。入房提供完整快照，随后发送变化，避免随 20Hz 玩家状态反复附带整张探索图。大小、编码、序号与转场校验必须在应用前完成。
2. 从一开始分开保存“本人探索”和“收到的探索”，渲染时合并。不能从已合并的画面重新采集并回传，否则远端数据会被误记成本地数据，关闭后也无法可靠恢复。
3. 原版采用专门适配层，先确定是否只改显示，再决定是否写原生光照字段。只改显示的路线可研究在原生光场绘制之后合成远端亮度；仍需实测图层、帧时序及恢复。
4. RV 增加小范围公共契约：导出本地探索、接收当前房间远端记忆、清除远端层及能力版本。可使用命名能力载体，或公共 `DataEvent` 携带版本化数据；不用跨域自定义类强转。子格、墙面、亮度的解释留在 RV 内。
5. 共享记忆不直接写入 `fov/currentSight`。历史探索与实时敌人显示是不同规则；既有 M27/M29 强制镜像显示与 RV 自身遮罩间的关系需明确后单独回归，不能默默撤销原先报点决定。
6. 当前合作流程加入方跟随宿主房间，可先按相同房间同步与缓存；对从前探索过的房间，进入时提供该房间可取得的历史。未确认的离线存档历史、地图重生成、不同房间自由探索不在已证明能力内。

可靠的 RV 兼容需要涉及 RV 的小接口改动，而当前工作区权限只允许本会话写 RConnect；这是后续实施范围需要明确的事项。本轮仅最小只读 RV。

## 尚未验证与待决定

当前已发出的提问（等用户回答，不把推荐记成决定）：

- Q3：宿主统一控制开关，还是双方分别控制本地显示？推荐宿主统一控制。
- Q4：关闭/断开时恢复个人探索，还是永久保留已收到的探索？推荐独立保存并恢复个人探索；其实现成本更高，但可避免共享永久改变单人视野。

下一轮应说明原版交互/瞬移的连带影响，再确认是否只共享探索显示。已知规则不能因开关问题尚未回答而重复提问。默认开关值、重新开关及地图缓存生命周期应随上述决定形成具体方案，未确认前不标作完成。

实施后的必要验收（本轮均未运行）：

- 长方形地图四角；同房间持续新增探索；宿主和加入者分别贡献；双向回流不污染个人记录。
- 加入/换房/读档/重新生成地图；相同 locId 的不同地图；延迟旧房间消息及错误尺寸被拒绝。
- 原版完全明亮、部分明亮与 retDark 特例；只共享显示时不改变瞬移/鼠标交互权限。
- RV current/classic/vanilla、总开关、记忆暗度、子格边缘和墙面；运行中切换模式与共享开关。
- 开关关闭、断线及重新加入；本地后来亲自探索过的区域仍保留；已有敌人显示与目标判定回归。
- 设置持久化、宿主/加入侧状态提示、MSW 存在/缺席；双方使用不同渲染模式时各自遵循本地设定。

结论：双向共享探索可实现；现有同步不能直接视为可用基础。下一步是完成上述玩法与范围决定，再实施 RConnect 同步层及 RV 协作接口，并做隔离双实例验证。
