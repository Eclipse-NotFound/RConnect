# RConnect B 开发入口

本会话按用户最新指令只负责 B。A 的当前状态见同目录 MEMORY.md；不要用 A 的最新源码或未获资格的 B195 替换 B 的冻结基线。

用户随后要求检查A新增功能：只读核对见 `state/b-review-a-features-2026-10-25.md`。明确B尚缺安保共享/分别策略与联机快捷键自定义；队友投掷物抓回、地图标记须另验，未自动开始移植。A的Q视野传送、nativeui2仍未安装。

## 当前实际安装

- 玩家入口仍为 `build/ab/b3-playable-190/Player-1.cmd` 与 `Player-2.cmd`。
- **已安装 B3-0.1-field3**，SWF `fbaaea1b9f9da4514d0cbedff43403ed53fc694198ddd0e917980c7d922a1acd`，准确构建 `build/ab/b190-field9-build`。
- 部署回执 `build/ab/b190-field3-deploy-20261025-01/deployment.json` 已 verified；同目录 before 保存原 startup2 和包清单。启动器、AIR存档ID、配置与原生接口组合保留。
- 旧基线 `build/ab/b190-startup2-build` / `2c536b5d` 保留，B195 未晋升。详见 `state/b-field-repair-2026-10-25.md`。

## 本轮问题与当前证据（2026-10-25）

用户报告双侧卡顿、加入侧没有交互提示、关闭跟随后走到出口没有反应。

- 原 B 实际走出横向出口复现 `Unit.run #1010`。原生移动在请求换房后继续用旧房格子检测越界坐标；已在等待帧尾换房期间将位置保留在旧房边界内，换房仍原子提交。
- 加入侧显示对象缺少原生交互对象及鼠标指向更新。已为容器和掉落建立只读原生提示，保留主侧执行交互；不在加入侧再开箱或拾取。
- 性能采样显示主要成本在主侧画面状态采集、加入侧复制呈现。已减少重复矩阵/颜色数组、字段类型检查、指向候选去重、血条布局及普通字段写入。四轮对照主侧每帧耗时减少约 8%–10%；加入侧普通场景略好、密集场景基本持平，不能说已解决加入密集卡顿。

## 源码与验证

- 持久覆盖源：`experimental/b190-field-fixes/src`，只覆盖 startup2 的 9 个产品文件。
- 功能已验但性能未过：`build/ab/b190-field6-build`，SWF `71d873f16eb84a7967b7be08b61c3159a558943fa069169a6a6efcac7521fdca`；临时版本名 B3-0.1-field1。
- 测试工具：`tools/host_authority/field_driver`。
- `build/ab/b-field-regression6-01/boundary`：25 项通过；双方真实走出/返回，另一人留原房，加入侧确认新房。
- 同轮 `hover`：20 项通过；锁定/解锁提示、加入侧实际开箱、真实掉落提示及移开鼠标清除。截图已目视检查。
- 上述均含独立参考语义比较：160 组视觉状态和 192 组字段状态，涵盖编码解码及旧快照不可变。
- 同轮 `enemies` 失败保留：新外置驱动误在旧档安全基地执行战斗，而原生基地禁止开火。prepared-v8 改为原探针的新角色/random_mane，并停用该场景的外部按键注入。随后 `b-field-enemies-baseline-v8-01` 与 `b-field-enemies-fixed6-v8-01` 原 B/候选分别都通过主 119、加 112 项；包括原生识别、轻机枪实际伤害、14 阶段身体/血条/武器/护盾/死亡图像核对。
- 四轮 60 秒对照已完成（baseline-02/03、fixed6-01/02），实际敌人数/附着、双方耗弹与发射一致、每十秒窗口持续开火均核对。主侧密集平均 94.18→85.89ms、P95 134.5→126ms；加入密集平均 62.44→66.12ms、P95 95→104ms，低密度加入 P95 57→61ms。重复比均≤1.2，但未达到本轮≤5%退步门槛，`b-field-performance-fixed6.json` 明确 false。没有部署，也没有放宽门槛。
- `b-field-profile-detail6-01` 诊断：80 敌人加入 replica.units 11.68ms/确认，其中字段应用 5.58ms、原生 pose 3.02ms；指向提示仅 0.25ms/本机帧。诊断字节 fielddiag 不可部署。
- field7 / B3-0.1-field2：增加 NativeFields.apply 固定公开属性存在性缓存；数值仍每次写入，动态/访问器/未知字段仍走原检查。`profile-fixed7-01` 密集 replica.units 11.02→10.19ms/确认，仅诊断而非净帧率资格；`hover-fixed7-v9-01` 主13/加11通过。
- **当前安装 field9 / B3-0.1-field3**：固定普通存储字段比较实时值后避免重复写入，仍恢复本地修改；动态字段、设置器、NaN、正负零保持原行为。field8 是构建过但未运行的中间稿，静态发现正负零需特殊保留后转 field9，没有把 field8 算通过。
- 准确编译 `build/ab/b190-field9-build`：SWF `fbaaea1b9f9da4514d0cbedff43403ed53fc694198ddd0e917980c7d922a1acd`，source `461dc13d8295eb7c3578e0a19da83aea8b83a9d3d20cdacfe2b61a0f01ff9a61`。prepared-v10 增加设置器与正负零检查。
- `b-field-regression9-01` 三项均过：boundary33、hover28、enemies外置20及内部主119/加112；截图已查看，准入脚本准确字节/日志/原运行组合检查通过。新驱动与 v8 原B敌人基准的整个游戏场景/输入/连接代码等同，差别仅新增字段契约检查。
- 新同时段四轮 60 秒对照已完成：baseline9-02 → fixed9-01 → baseline9-03 → fixed9-02；`b-field-performance-fixed9.json` 的实际敌人数/附着、耗弹与发射、持续开火、准确字节、≤5%退步及≤1.2重复比检查均过。加入密集平均65.23→66.14ms，P95 104→105.5ms，属于基本持平，未宣传为改善。
- 部署后从实际 B 玩家文件另跑 `b-field-installed-smoke-01`：主21/加12通过，实际走门和自身控制正常，无FATAL，运行文件不变；随后 finalize 已核验并完成。
- 部署工具已完成 install 与 finalize；准确候选功能回归、性能无明显退步、备份、部署后复验均已落实。

后续重点：加入侧密集呈现与解码开销仍高；本轮只是局部优化。维持当前已部署修复，继续优化前从 field9 准确源开始，不混入 A 或 B195。保留所有失败，不降同步频率或删减战斗/动画来换速度。三个大测试副本已完整归档并回收，净释放938,069,625字节；索引见详细记录。
