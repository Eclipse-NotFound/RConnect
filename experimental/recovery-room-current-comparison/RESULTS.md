# 2026-10-24 当前环境三程加载实测

被测技能：不作为技能验收；业务对象为 RConnect roomfix5 / roomperf1，报告整理采用 test-report 2026-09-16.1。
技能归属：测试入口属 Remains / RConnect；报告方法属 C:/Users/hello/.agents/skills/test-report。
测试工作区：D:/Program Files/Steam/steamapps/common/Remains/mods/RConnect。

## 结论

三组原生测试均完成，原框架的加载、同步和控制恢复断言通过。小范围优化候选 **roomperf1 没有显示出明确的加载收益，不部署**；当前正式安装仍是 roomfix5。双侧大图加载达到相应单人流程耗时的目标尚未完成。

本次只有一个基线双人组、一个候选双人组、一个基线单人组，各跑三程。固定布局种子后单位数量仍不同；这不是足以判定净性能改善或退化的重复配对实验。三个结果均保留 `performance_qualified=false`，不可把功能通过改写成整体性能合格。

## 实际输入和证据

| 组 | 产品 | 结果目录（build/m52 下） | 原始运行目录（build/cooperation 下） |
|---|---|---|---|
| 基线双人 | 0.2.24-roomfix5 | [recovery-room-current-baseline-dual-01](../../build/m52/recovery-room-current-baseline-dual-01/result.json) | [7cadcc8267](../../build/cooperation/7cadcc8267/run.json) |
| 候选双人 | 0.2.24-roomperf1 | [recovery-room-current-candidate-dual-01](../../build/m52/recovery-room-current-candidate-dual-01/result.json) | [6f633cee8e](../../build/cooperation/6f633cee8e/run.json) |
| 基线单人 | 0.2.24-roomfix5 | [recovery-room-current-baseline-solo-01](../../build/m52/recovery-room-current-baseline-solo-01/result.json) | [fc4111c750](../../build/cooperation/fc4111c750/run.json) |

准确产品字节：

- roomfix5：`78c052aea963f1689b705ae1e14d274916ae1a1f7e81933390caf8d1a88f4699`，来自 `recovery-room-production-05`。
- roomperf1：`1e26bdf38811268234af8e1ef060514388719a5dcaa21a861ff7501ef558ba81`，来自 `recovery-room-perf-current-01`。
- 两者使用同一个已编译 `recovery-room-scene-driver-02`：EffectsDriver `218246101949b35df2979011ce056419ff5718a24f2bcc8dd92f4224f7dbf18f`；EffectsHarness `d52ef4300c7d472ee05884d7b4709f4abf80b3e6ff935b695a9ed986db021086`。
- 本次包装入口 `run.py`：`0297781db69fa760e73d7e7ae7b15472c14398dc94d39c15708e352b9081f830`；共享运行器：`7eca453b13480140da5f36bb33d2319739a927562ccafdbb61a8b20cdb5ae4d3`。

当前运行环境为宿主 A796、RealisticVision BF4A、ModLoader 2050、ContinuousScene 7F1F、WallBlend 14112。三次 `intent.json` 的完整 22 项安装清单相同；独立核对时这些安装文件仍与清单逐项一致。三次原生资源清单的 98 项相同，14 个模组的装载字节及非 RConnect 配置相同。双人两端输入相同。候选是由相同 Harness 加载的准确生产 SWF，不能把 Harness 的路径摘要当成候选摘要。

历史驱动与产品的编译安装清单保存在 `intent.json` 的 `historical_*_installation` 字段，未冒充本次环境。完整源、构建和安装前后指纹见对应 `prepared.json` / `compile.json`。roomperf1 仅包含版本、NativeTileState/TerrainSync 已有局部优化、删除未使用的 byId 扫描、减少 RoomTerrainView 比较临时数组；仍执行完整恢复及必要重绘，未引入首次绘制前恢复方案。

每组结果目录包含 `intent.json`、`supplemental-input.json`、`supplemental-after.json`、`runner.log`、`result.json`；原始运行目录保留 `host.log` / `join.log`、标准输出、`module-logs/`、`input.json`、`run.json`、描述文件和配置副本、内存及登记回执。本报告独立回读了这些证据，而非只引用根会话的成功说明。

## 三程耗时

单位为秒；从驱动发起/收到本程指令，到原生切换、同步、最终落点、黑幕消失和控制恢复条件满足。各端用自身时钟记录，不用两个进程的绝对 `at` 值直接相减。

| 组与角色 | 首入 random_mane | 返回 rbl | 重访 random_mane |
|---|---:|---:|---:|
| roomfix5 单人 | 6.642 | 1.732 | 3.101 |
| roomfix5 主侧 | 9.040 | 2.401 | 5.189 |
| roomfix5 加入侧 | 15.068 | 2.321 | 8.208 |
| roomperf1 主侧 | 9.531 | 3.632 | 5.171 |
| roomperf1 加入侧 | 15.358 | 2.043 | 8.259 |

候选相对双人基线的绝对变化，主侧为 `+0.491 / +1.231 / -0.018` 秒，加入侧为 `+0.290 / -0.278 / +0.051` 秒。方向不一致，主要的大图加入侧延迟没有消失；不能宣称本候选实现性能提升，也不能仅凭这一对样本把全部差异归因于代码。

另提取 `elapsed - exitEnd`，表示驱动观察到原生 `t_exit` 回到 0 后，到全部结束条件满足的间隔：

| 组与角色 | 首入 | 返回 | 重访 |
|---|---:|---:|---:|
| roomfix5 单人 | 0.005 | 0.006 | 0.009 |
| roomfix5 主侧 | 1.374 | 0.480 | 1.303 |
| roomfix5 加入侧 | 7.362 | 0.273 | 4.722 |
| roomperf1 主侧 | 1.577 | 2.009 | 1.382 |
| roomperf1 加入侧 | 8.201 | 0.258 | 4.802 |

这个间隔说明加入侧完成原生切换后仍有明显等待/处理段，值得继续定位。它不是已测得的单个函数 CPU 时间，也不能全部归到重绘或网络。候选主侧返回 rbl 时 `paused=1.910` 秒，基线为 `0.360` 秒；本次没有额外阶段诊断，原因未定。

## 布局、落点与工作量边界

三组都按 `random_mane → rbl → random_mane` 执行。第 0、2 程为 240×125 合并大图，布局种子 `1380142925`；中间 rbl 为 48×25 普通图，种子 0。`merged=true` 是设置偏好，rbl 的 `actualMerged=false` 是正确的原生行为。

两个双人组各自在三程末尾均同房、同尺寸、同种子、落点距离 0：大图 `(1161.8,4800)`，rbl `(961.8,800)`。单人 rbl 落点相同，但大图是 `(161.8,4320)`。原生出生点选择未被测试强行改写；不能把单人和双人的时间差当成同一摄像区域的纯联机开销。

| 组与角色 | 首入 units.length | 返回 | 重访 |
|---|---:|---:|---:|
| roomfix5 单人 | 180 | 37 | 180 |
| roomfix5 主侧 | 177 | 38 | 177 |
| roomfix5 加入侧 | 301 | 47 | 301 |
| roomperf1 主侧 | 181 | 38 | 181 |
| roomperf1 加入侧 | 308 | 47 | 308 |

这是原始 `loc.units.length`，包含各端原生/镜像实现对象，不能直接当成“存活敌人数”，也不以两端数组长度不同判定复制出多余敌人。布局种子一致不保证全部原生 `Math.random` 状态、单位工作量及出生选择一致。

单人组是 **相同 14 模组环境下的离线原生旅行流程**，不是移除所有模组和补丁后的干净原版。共享框架保留其既有模式差异：单人配置 `autoRole='' / autoFollow=0 / freezeAI=0`，双人为角色名、`autoFollow=1 / freezeAI=1`；场景驱动随后统一关闭跟随设置。没有为求好看数字改动原框架或这些参数。这一单人组可作本机当前流程的参考，不能授予“精确达到未修改原版”的资格。

## 隔离、断言与清理核对

五个实例均使用唯一 `pfe-modsettings-rconnect-coop-{role}-{token}` AppID、私有桌面和自有游戏副本，新建测试角色，不复制或写入用户真实存档。首个 AIR 创建之前，所有参与端都已写入：

- 私有 `ContinuousScene.preferences.json`，内容 `{"nativeEnabled":true}`，SHA `cc989162b2b44eddbed5c3e2e8437d8537c1e4541b9e5ed24bc4f2c5ba05c89c`。
- 私有副本中的正式 `telemetry.json`，内容 `{"enabled":true}`，SHA `a050ef06ea542b8fd8781f1e945f9adcd03c7ae5190719e66ba826e2059fce12`。

两类设置在进程停止、运行副本清理之前回读一致，原 `input.json` 未被回写；补充输入单独记录。独立复核时私有 CS 偏好仍为同样字节。各端标准输出的 14 个 requested 模组与 14 个 ok 模组集合一致，包括 LAD/RV/CS；本三轮没有关闭这三项模组。

| 组 | 原检查数 | 启动可提交余量 GiB | 运行最低余量 GiB | 采样次数 |
|---|---|---:|---:|---:|
| 基线双人 | 主 26、加 15 | 9.243 | 4.574 | 73 |
| 候选双人 | 主 26、加 15 | 9.921 | 6.593 | 73 |
| 基线单人 | 14 | 11.472 | 8.960 | 32 |

原检查包括每程控制恢复、固定种子与真实大图、双端最终房间/尺寸/种子及同入口；加入侧结束断线后还检查 CS 偏好保留。原共享 runner 的双 6 GiB / 单 3 GiB 启动门槛、512 MiB 运行停止保护、独占 AIR、模组错误扫描和回收不变。三组 `registry-result.json` 均 passed，退出码均 0，无模组错误、交接超时、内存压力停止或外部 AIR 重叠。

五个自有 PID `17624 / 71704 / 42292 / 120784 / 16956` 在独立复核时均不存在；各次 `host`、`join`、`frozen` 运行目录均已删除，唯一日志与回执保留。源/产品固定输入、正式 22 项安装和额外 telemetry 文件核对不变。报告整理没有启动游戏、编译或部署。

## 核对指纹与未完成项

三个 `result.json` SHA-256：

- 基线双人：`0f9c3faa51b65a256ab01df785b9c441dec8f934ad14dd0dee4b0e81b94698a5`。
- 候选双人：`fdad35f33654d683a94cb236739514cfc8a6874a2c682c4056e1fa87b719d0b4`。
- 基线单人：`4e7f57143b67e2be65f8340977e0834e5f6209d1ff3f7019a43b96a91fd097b3`。

独立复核还重新计算了原 `run.json`、`input.json`、双方日志、描述文件、保存的配置、产品与工具指纹，均与回执匹配。状态为 [已落盘→本页所列原始运行与结果目录]，本次新增产物仅本报告。

仍待：解决大图加入侧原生切换后的长间隔，验证后续首次绘制前恢复方案，重复同条件对照，并补充游玩阶段和用户问题的专项检查。三程未覆盖持续战斗、高速弹道/念力/掉落动画、所有背景门/分房情形，也没有本轮截图来证明任意界面像素。原全程帧统计包含启动及加载长帧，不能用其 p95 等指标宣称稳定游玩性能合格。

本页按根会话指定范围只写 RConnect 业务结果。全局测试报告台账本次未写，登记状态为待登记；未创建另一份技能测试报告，未修改技能状态。
