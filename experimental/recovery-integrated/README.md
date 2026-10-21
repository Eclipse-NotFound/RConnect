# Recovery integrated source — 0.2.24-recovery6

此目录是隔离源码整合候选，不是安装版。recovery2追加光晕RGB/alpha分组恢复，recovery3合入原生旅行计划、旧grant防护与两处采集消重，recovery4追加有界墙痕解码缓存，recovery5修复射手离房后的待播命中时钟；当前recovery6将逐格编码诊断改为显式启用，共85个AS文件。冻结产物为 `build/m52/recovery-06` / `3f828464b5c27a8fb5bb25e1bfb483a72631318684cf30872c7c3bed7e9281d1`，已编译，未部署，尚无本版本的原生和性能资格。

当前实测状态统一见 [恢复记录](../../state/recovery-2026-10-21.md)。下文原整合检查是来源说明；各轮冻结目录与回执才是对应版本的编译和执行证据。原生旅行需搭配隔离 `recovery-native-travel-host-01` / E159；cost499、RoomSync50、计划33、墙痕缓存120组件通过。03已通过16轮原生光晕与固定地图三段旅行，但实际高速飞行仍失败。04真实8轮仍有6条连续性失败，不能称性能达标。05追加的impact-detach共用组件旧版35条中13失败、修正版35/0；05普通枪14轮实际主106/0、加104/0，但不代表真实离房场景通过。06编码诊断开关199/0组件通过。probe-fast仍未合入。

## 来源与合并顺序

1. `build/m52/coop-bundle-04/src`，产物指纹 `574d2b51490ae8b25a1396555600f56a301f8a20ae50104c0e35cf2796441afe`。
2. `build/m52/room-entry-fast-19/src` 相对该基线的 10 个变化文件，未用其整树覆盖无关文件。产物指纹 `051240012891ab8e6e41d30d8fb13ab16d120f41c5d9578a84a9146906257fea`。
3. `experimental/recovery-loading/src`：原生加载资源呈现。
4. `experimental/recovery-aura/src`：被队友念力抓取时身体光晕。
5. `experimental/recovery-wall-impact/src`：确认真实碰撞后采集原生火星、血花及能量接触粒子。
6. `experimental/recovery-motion/src`：运动插值与 50 ms 新特效样本通道。
7. 只取 `build/m52/motion-fast-01/src` 的 `HostServer.as`、`Session.as` 网络去重增量。该冻结产物指纹 `8846030829d8ab707f7019c0e693a11722e2b682d2dfc492fffdf552b9611dda`，其它文件未引入。

`integration.json` 保存每层输入与祖先文件哈希、逐文件合并选择、最终全部源码哈希。中间 merged_sha256 是当层结果，最终 source 清单为准；源码统一 LF，不把换行差异算作功能修改。整合前后所有输入文件哈希一致。

## 重叠方法与额外修正

- `GameBridge` 保留 room19 改动、3 处 held-peer 身体光晕、独立 effects 采集及接收。`UnitPresentation` 的相邻插入冲突按方法合并；未把其中一整个文件覆盖掉。
- 普通 NPC 子弹也记录真实原生显示点，使用已有 frames 通道。所有新弹体播放都不再假设源端每秒固定 30 次逻辑更新；舍弃新加的按终点重缩放整段路径方案，以免终点包迟到后画面倒退。旧无 frames 包保留原兼容路径。新增 frames 的带宽、CPU 和停顿表现必须实测。
- effects 包包含新点、同时间戳的实际修订、停止/结束、爆炸、`flight.impact`（无原生图像时为 `event.impact`），以及 `gun.impacts`。确认击中事件在弹体序号过滤之前进入独立队列，不能因弹体已经消失而丢失。
- 同时间戳但值未变的对象不重发；普通/特殊弹相同 seq 的后续真实结束会更新。合并时不让较旧完整包覆盖新样本，不允许 ended 被变回 live。缺少最初图像的低 seq 可稍后补收；已消费 ID 有界去重。
- 射手死亡后 `RemoteMotion` 被清除时，弹体、能量粒子和等待中的火星从当时显示时间继续，而不是抓着已不再推进的旧时钟；不提前消失，不执行第二次伤害。
- `UnitPresentation.retainUnsent` 默认 true。GameBridge 构造设 false，并以 `presentationNetworkActive` 属性转接。Session 每 tick 按 open CONNECTED / HOSTING 且有 peers 设置、stop 时立即清除。已结束但未发出的临时弹体记录：离线 700 ms、联机 15 秒退役；发送过结束的记录仍保留 700 ms；活弹不按年龄删除。此开关不跳过世界观察，不改永久房间进度。
- 网络层不给收件人回传其自己的 snap，只有一个加入者时不在其每次上传后额外再广播一次全世界；主侧立即应用和 50 ms 定时广播保持。

`ProjectileFrameStream` 是整合新增的共同依赖，必须一并编译；不能只复制旧 wall-impact 的 3 类组件入口而漏掉该类。

## 验证状态与下一步入口

已做静态检查：84 个文件括号平衡、无合并标记、无重复同名方法；3 处光晕调用仍在；快速 effects 收发仍在；新普通弹均使用 native frames；输入哈希未变。这里的静态检查不等于编译或运行通过。

墙面特效原生入口位于 `experimental/recovery-wall-impact/tests/`：`WallBallisticTestDoc` 14 项、`WallEnergyTestDoc` 15 项、`WallMagicTestDoc` 14 项，共原有 43 项；另 `RecoveryWallMaterialsTestDoc` 14 项覆盖材质与反向。组件入口在该候选的 `components/`（入口为 `ImpactCaptureChecks.as`、`ImpactQueueChecks.as`，执行说明见候选 README），新增候选 41 断言尚未运行。当前 motion/effects 额外组件由 `experimental/recovery-motion-checks` 提供，父会话统一构建和执行；需覆盖同 stamp 不变/变动、漏 seq 补收、死亡时钟、低源帧率飞行不倒退、迟到结束、离线 700 ms / 联机 15 秒清理与长寿命活弹。

旧候选 32 项 wall 组件、网络 102 项组件与包重复减少证据属于旧来源，不是本整合通过证据。旧性能未合格，禁止沿用其 FPS 结论。本次须重新串行做真实武器命中、多人暂停/死亡/换枪，以及高射速与密集敌人 CPU/帧时间/流量对比。

仍有限制：不宣称房间加载已达到单人流程耗时；不宣称密集场景已流畅。墙面粒子只重现源端真实确认的效果，未扩展水面蒸汽/水滴、未知第三方粒子类别。现有投掷物与爆炸通道保留，需要原生矩阵共同验证。编译/实测失败应保留证据并修正候选，不能改写安装版。
