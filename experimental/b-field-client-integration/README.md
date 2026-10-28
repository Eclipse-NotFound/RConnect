# B 默认环境适配与加入侧性能更新

2026-10-29：主体07与完整新环境已通过必要实机检查并安装到原 B190 两个 Player 入口，版本 `B3-0.1-clientenv1`。安装字节复验主127/加84通过，事务 verified，见 `deployment-summary.json`。当前状态和未解决问题以 `../../state/B-MEMORY.md`、`../../state/b-clientenv-progress-2026-10-29.md` 为准；本目录不是可单独启动的完整游戏包。

`source-07/` 是最新完整覆盖，保存相对已部署 loadfix 的18份源码差异和完整144份源码指纹，包含马蹄铁设置、两处缓存、新模组接口、列表类型修复、退出前消费已收到确认，以及复用配件模块的输入校验。`restore-source.py --snapshot source-07 --output build/ab/b190-visual-motion-<名称>-source` 从固定父来源恢复新的纯源码目录；不编译、不启动游戏、不更新测试包或安装版。恢复结果应为 `5854ef397c1e96cf24d8b637f32cdc24589502d91fe86cce892a3189b75041dd`。早期 `source-05/` 保留，不覆盖它。

`integrate.py` 是首轮集成过程记录，随后已有退出顺序、伤害收尾和列表复制修正；它不能作为完整恢复入口，也不能在已组装源码上重复执行。继续开发应恢复最新记录的完整覆盖源。

`prepare-environment.py` 更新独立功能测试目录；`prepare-bench.py` 和 `bench-environment.py` 复用性能目录，在同一环境中对照主体。它们不会验证模组玩法本身，也不会部署用户使用的B入口。所有运行均须遵守共享测试登记、产物指纹与资源限制。

`functional-evidence.json` 索引真实服药/退出、配件/复活、永久伤害、载入、马蹄铁、移动文字、基地显示和时停八类检查。`performance-summary.json` 保存同环境 ABAB 8/80敌人各60秒结果；缓存仅证明密集场景约3%–4%平均改善，普通场景基本不变。`visual-motion-review.json` 明确保留镜头回摆和慢帧，不能宣称全面消除卡顿。预测最终应用去重候选未合入。

默认关闭 ContinuousScene、RealisticVision、LightAndDarkness；其它模组采用发布版本及必要的独立B接口，不能直接用正式单人版本替换接口。马蹄铁共享默认开，由宿主设置，关闭仅影响之后的地图马蹄铁奖励。

`release.py` 本次绑定旧 loadfix1 安装基线，按 stage/check/install/安装字节复验/finalize 执行。它不是无条件覆盖工具；后续版本需重新绑定当时的安装清单，不能复用本轮事务伪装新验证。全部旧失败、原事务备份和准备文件保留。
