# 普通房持久墙痕：沿用 driver04 的最小适配

仅外部测试源，生产、ACC 宿主、旧驱动与旧结果均未修改。准确候选是 recovery22 `746eef5713985f23fe13a57792516789bebd37a5e4142639ba8cc8b6590b3e93`，准确宿主 ACC `acc336b5f28012a5f0d2ef57d0a3bf46be46f72f1e4c3a69a2f063cae0535dfd`。尚未编译或运行 AIR；离线检查 **29/0**，不代表原生通过。

## 现有 22 大图结果的独立复核

`58af664bec` 双侧各 34/0，四轮严格源→对侧 uint 与最终显示像素一致；重新核对了独立分析所绑定的 45 个文件，原框架冻结输入不变、22 项双侧运行输入完整、安装变化为空。旧 PNG 表示误拒仍保留，没有把旧失败改绿。

| 轮次 | 武器/源 | 真实命中跨度 | 首击→对侧最终完整 | 最晚源变化→对侧完整的观察区间 |
|---|---|---:|---:|---:|
| 0 | 轻机枪/主 | 单发 | 778 ms | 下界未知，上界 924 ms |
| 1 | 轻机枪/加 | 单发 | 313 ms | 71–410 ms |
| 2 | 等离子/主 | 8 发跨 4550 ms | 5390 ms | 347–925 ms |
| 3 | 等离子/加 | 8 发跨 6347 ms | 6745 ms | 246–489 ms |

区间来自两端最终状态前后的 RENDER 位图拷贝，并非私有接收/播放时间；第 0 轮对侧第一张 RENDER 已完整，旧 proof 没有保存 baseline 拷贝时刻，不能拿较晚的 `startWall` 捏造下界。两轮等离子最后一次命中分别在 `1792645747306`、`1792645765002`；完整源状态首见 `...4747418`、`...4765064`，对侧首见 `...4748146`、`...4765400`。原 case2 的 5390 ms 大部分是源仍在持续开火，不能解释成最后几格静止后等待了 5 秒。

准确 22 的 `WallImpactVisuals`：`report` 等待当前 pending ACK 后才取下一批；`queuedBatch/updates` 保留 64 cell、48000 字符预算；`sentUpdates` 在实际交付 TCP 后推进版本，`snapshot` 轮转累计 cell。它们是可能的等待边界，现有 proof 仅有包类型/cell 坐标/版本，没有每份最终颜色、私有 queued/pending 或 ACK 时间，不能据此把本轮余下延迟归因到某一处。最大观察空档仍达 577 ms；功能通过不等于及时同步或性能合格。详细原值与文件哈希见 `recovery22-large-review.json`。

## 最小适配内容

- `LargeWallSurfaceTestDoc.as` 从冻结 driver04 精确替换 10 处，差分保存在 `ordinary-driver.patch`。保留原生 `Invent.addWeapon/changeWeapon`、`Weapon.attack/step`、`Bullet.tilehit`、四轮双向轻机枪单发/速射等离子 8 发、固定种子、原生 `beginMission`、10 秒/480 帧、自然墙面、武器准备/首发接受检查和所有采样顺序。历史类名、消息类型、DONE 与日志标签只为兼容现有包装器，资格由新的 ordinary 准入证明。
- 仅在隔离进程里将 CS 的 `nativeEnabled` 设为 false，让双方原生生成普通 48×25 房间；不修改任何配置文件或其他模组源码。自然选墙允许最右侧原生边界墙，128×128 crop 向内夹紧，仍完整落在真实前景内。保留干燥实体墙/材质/HP、七格射击通道和四处相隔至少 160 像素；没有四条合格天然射线时明确是夹具准备失败，不伪造墙或认作模组反例。
- 新 `NativeWallSurfaceProbe` 每次取样都要求 `sceneLarge===false`、原点为零、完成栅格绘制、当前 Location 确为 48×25、frontBmp 是 1920×1000、`sceneSurfaces()` 为空。通过 BitmapData **对象身份**在 `visFront` 中找唯一真实 Bitmap，要求在舞台上、可见、未平移缩放旋转。不会把大图 scratch 当普通房前景。
- 只对自有 128×128 位图 `copyPixels/draw`；动作期间不 `getVector/encode`、不写生产像素。双方都发出 sampled 后才读 uint 和编码 PNG，并记录采样/读回耗时。额外保存 baseline 拷贝时刻，避免第 0 轮那种下界缺失。
- 分析器复用冻结 driver04 的完整严格比较，只替换普通房几何/真实前景身份准入；PNG 单独复用已核验的直色/预乘表示检查。产品源→对侧仍逐 uint 精确相等；无容差。离线负例覆盖 scratch 冒用、非舞台/假身份、超界、无原生命中、首发拒绝、只播粒子、缺失/额外/单通道 1 级错色、短采样、完整后消失、伪 PNG 和重复日志。

## 根会话串行执行

在 `mods/RConnect` 下，使用现有框架，仅薄适配准确 22、ACC、入口说明和新的 fixture；登记、内存、独占实例、600 秒、22 项输入、错误/DONE、退出和自有副本清理均不放宽。输出目录必须全新。

```powershell
python -B -X utf8 experimental/recovery-ordinary-wall-native/check_offline.py
python -B -X utf8 experimental/recovery-ordinary-wall-native/native_tool.py prepare --source build/m52/recovery-22/src --output build/m52/recovery-ordinary-wall-driver-01 --build
python -B -X utf8 experimental/recovery-ordinary-wall-native/native_tool.py run --candidate build/m52/recovery-22 --drivers build/m52/recovery-ordinary-wall-driver-01 --game-candidate build/m52/recovery-wall-surfaces-host-01 --output build/m52/recovery22-ordinary-wall-native-01
```

本适配只接受准确 22 和独立回读验证后的 ACC。原框架 `result.json` 保留，额外严格结果仍叫 `wall-surface-result.json`，内含 `scene_mode: ordinary` 和 PNG 审计。输出可见延迟，**没有**把本测试设为性能合格。它只补普通房真实命中像素，不重复构造重返/毁墙/ACK 或新增协议测试；这些仍沿用原 85 项组件覆盖。
