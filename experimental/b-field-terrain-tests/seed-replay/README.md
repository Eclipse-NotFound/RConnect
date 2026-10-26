# 旧失败房间的有界生成种子回放提案

本目录是未应用提案。`../seed-replay.patch` 为两个工具文件的精确差异，`manifest.json` 记录原工具字节、提案字节及旧失败判据；本子任务没有修改 tools、刷新驱动、编译或启动游戏。

旧失败 `build/ab/b-field21-final-01/terrainlive` 的 host-ready 与 stdout 两处都保存了原生生成种子 **2780491448**，起点房间键 `random_mane:2780491448:0:4:0:`。旧轮未保存生成后的房间/颜色/瓦片数据、PNG 或存档，因此不能直接逐字节恢复整张地图。新通过轮 seed=1963887932，两侧 baseline-0/death-0 图片均零像素差，周边瓦片与64像素区块也相同，但它不能关闭旧失败。

应用前核对当前两个工具文件与 manifest 的 original_sha256 相同；如其他工作已有改动，按 patch 手工三方合并，不能整文件覆盖。源文件提案分别为 BStartupDriverMod.as、run.py。统一集成人待当前 suite 完成后应用并编译新 preparation。

新增命令参数 `--terrain-seed 2780491448`，仅允许 `--scenario terrainlive` 的运行；准备/刷新操作和其它场景不能使用。运行回执新增 `diagnostic_only=true`、`terrain_seed`，startup-test.json 增加 terrainSeed，其指纹仍由原流程冻结。未传该参数时 startup JSON 内容和顺序、回执字段均保持原状。部署工具不会将这项带额外诊断输入的记录冒充原来的干净核心场景。

仅宿主在 beginMission 之前临时替换现有公开 `Land.rconnectSeedSource`。第一次 random_mane 构造取值时立即恢复原回调，再返回指定种子；其它地图仍调用原回调。提前结束时也会清理尚未消耗的回调。phase1 检查实际土地种子及回调已恢复，否则明确失败。没有写随机数生成器内部状态、没有改产品和 native 本体、没有改瓦片/像素或旧断言。

原生019中的 Land 已将镜像、门连接选择、pickRoom/pickLoc 的一部分随机选择换为 rndNext，但仍保留 buildRandomLand 的若干 Math.random 分支（例如 verified Land.as 594/631/663/712），挑战房选择及敌人生成也有独立随机。RandomRooms 同样在当前冻结组合内。因此固定 layout seed 是最接近原证据的重建入口，不预称整图完全确定。下一轮仍要保存旧失败房间条件与PNG，比较是否真正复现旧 baseline 哈希 **host=bc128cd5，join=c1a70072**；两哈希是复现证据，不是放宽通过门槛。

目前完成 Python 语法及参数边界检查：5 个允许输入、7 个拒绝输入，未导入/执行 runner；原 tools 两文件摘要仍相同。AS3 尚待统一编译与实机验证。

另有独立 run.py hunk：双方已经启动后，若任一驱动已记录 DONE 且 failed>0，立即抛出 `Driver completed with failed assertions`，进入既有 finally 归档两侧真实日志、记录 complete=false/passed=false 并释放本轮测试进程。不会把尚未结束的单条 FAIL 当结束、不会隐藏实际断言，也不让另一端多等300秒。通过4组纯条件检查（失败DONE、成功DONE、未DONE的FAIL、另一侧失败DONE），尚未在游戏进程中执行。
