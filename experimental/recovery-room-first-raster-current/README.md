# 当前房间版的首绘延后候选

状态：仅准备可编译源码与组件，尚未编译、原生运行或部署。版本为 `0.2.24-roomload1`；准确底座是 roomfix5 / `78C052…4699`，不含 roomperf1 的局部优化。

本候选把完整地图事务的地块绘制延后到收到完整检查点之后。原生生成、进入事件、对象与单位恢复仍执行；不是删快照，也不凭种子相同跳过恢复。普通房、背景门、连续过门、未换房的权威玩家和现有原版 Loading 界面继续使用当前分支。

## 接线范围

- 当前 `MapGeneration / RoomSync / Session / GameBridge` 四类的窄增量，加上逐字复用的 `EarlyTravelGate`。只允许双方协商的 `sceneMerged` 整图事务；缺宿主桥、缺真实 Sand hold 载体，或 Sand 非 idle，则退回当前流程。
- 另只给 `WallImpactVisuals.front` 增加 `rconnectRasterPending!==true`。准确 A796 的 `scenePrepare` 会创建或保留非空 `frontBmp`，票据等待时它仍可能只是临时/旧像素；等待期间不得把它观察、复制为墙痕底图。未移植旧的 `sceneLarge` 排除、表面桥、解码缓存或其他墙痕改造。
- 保留 old early2 的完整恢复→允许绘制→下一原生帧且 exit0/viewReady→ACK/activate→释放退出许可顺序。旧普通房 `busy && pending==0` 的 hold 在真正开始整图旅行后撤销；原生拒绝旅行时取消并释放本次许可。
- 当前 `advanceSharedTravelFade` 仍运行，保留 20/19/18/17/16/1 等原生工作边界。事务 nonce 使用时钟与局部序号，不消费游戏的随机数。独立 45 秒上界替代未移植的旧后备计划计时。

宿主三类的当前 A796 文本移植由 `../recovery-room-first-raster-host-current/` 独立维护。本目录不改宿主或 Sand；旧三后备类 `NativeTravelPlan / FirstRasterGate / SeedRasterEntry` 未加入。

## 构建入口（由主会话执行）

```text
python -B prepare_sources.py --check
python -B build.py --check
python -B build.py --build build/m52/recovery-room-first-raster-product-01
python -B build.py --verify build/m52/recovery-room-first-raster-product-01
```

`prepare_sources.py` 无参数仅重新生成本目录的文本。`build.py` 只有显式 `--build` 才编译：冻结 roomfix5 完整源码和工具，覆盖六类、仅另改入口版本；准确新增一个类，支持原清单没有该键。它拒绝覆盖输出目录，在共享登记内运行原有两次编译命令，保留 1 GiB 启动门槛、384 MiB Java 上限、原内存保护/300 秒界限、隐藏子进程与 finally 回收。仅局部替换所加载构建模块的 `subprocess.run`，不修改共享脚本或全局 subprocess。

编译前冻结真实 22 项安装输入，并要求正式 RConnect 仍是准确 roomfix5；排队后与完成后再次核对。历史 roomfix5 编译回执与当前输入分开；最终验证失败也写 `compile.json`，不覆盖原失败。`verify(folder)` 只读核来源、产物及原构建期间环境未变，不伪装当前安装为历史清单。

## 验证范围与停点

组件接线见 `COMPONENTS.md`。文本校验只是准确复现源差分；组件尚需主会话编译并执行，之后还需当前宿主、真实 Sand003 组合的三程原生加载、普通房和隐藏门回归。

墙面小组件只能证明现有 BitmapData 路径在票据期间不观察、状态不丢、解除票据后重放；不能据此声称 CS 大图所有分块的完整墙痕首帧均可见。实际两端加载重叠、原生输入恢复、真实缓存对象寿命、同会话连续同图事务与整机耗时仍未验证。历史 early2 功能结果只证明旧组合，本候选不继承其运行或性能资格。
