被测技能：remains-runtime-debug、remains-auto-testing、remains-mod-build、remains-release-gate、remains-swf-patching、remains-mod-memory；diagnosing-bugs；test-report 2026-09-16.1
技能归属：Remains 工作区级及 C:/Users/hello/.agents/skills 用户级
测试工作区：D:/Program Files/Steam/steamapps/common/Remains/mods/RConnect

# M29：加入方敌人显示与索敌修复

2026-09-20。用户反馈加入侧无敌人显示，敌人极少发现加入者。本轮沿用已授权候选部署范围，只修改 RConnect；不改用户存档及其他模组文件。

## 复现与原因

- 用户 pfe/pfe2 的 RConnect 日志中，大部分单位可匹配，不能据此认定已经渲染。另有 `Mine` 构造 #1009。只读定位，不将真实用户日志整份归档。
- 隔离双实例 `51c83cb01e`，加载已安装的 RealisticVision：加入方原生 UnitSlaver 的 `visible=true / parent=true / alpha=1`，但残留 Shape 遮罩，绘制得到的非透明区域面积为 **0**。同名两只敌人仅保留一只，日志仍声称匹配 3/3。五项断言失败。
- 同轮原生感知 `isMeet=true / look(joiner)=20 / look(host)=0`，旧 redirectNearbyAggro 因 celUnit 已指房主而跳过。原生 findCel 的默认候选只有 loc.gg，不能自动补发现加入者。
- 地雷快照的 tr=0 被写为 XML 显式属性，原生构造跳过按 id 取武器定义，产生空引用。数字变体只在大于零时写入；同时修正奴隶贩子等数字变体的构造参数。

## 最终改动与验证

最终测试 `34373dd227`：**60 PASS、0 FAIL**，35 项既有回归、16 项新增原生敌人检查、9 项真实 TCP 场景检查。双方心跳持续至 tick 1400，没有游戏错误对话框。

- 显示：在帧结束恢复镜像显示时解除残留遮罩，并隐藏脱离遮罩角色的 Shape，避免白块；换房、退出、离开存活集合时归还遮罩。实际 RV 下两只敌人绘制区域面积均为 8463；这是非透明像素包围区域的面积，不是逐像素计数，也不是全屏截图验收。
- 身份：单位有房间内稳定 U 编号，贯穿注入、位置、动画、血量及回传伤害；同名敌人交叉位置后不交换身份。血量基线和冻结集合使用对象引用。玩家阵营宠物不进入敌人广播。
- 索敌：保留 320px 近身补发现范围，调用原生 isMeet/look 检查朝向、遮挡及潜行；加入者明显更近时可替换旧房主目标，用 setCel 更新完整瞄准状态。加入者的 visibility/stealthMult/demask/noise 随角色状态同步。验证原生 findCel 保留加入者、近房主不被抢目标、不可见及范围外加入者不被强制锁定。
- 构造与恢复：普通 tr=0 地雷、旧 alicorn/mine/boss 测试通过；断线恢复借用的遮罩；既有门箱、脚本门和拾取检查继续通过。

## 环境与失败历史

- `40be8a2155`（新测试）及 `7c6d5f60ea`（旧测试对照）在受限进程环境中均无 RConnect 初始化和测试日志，属于**测试未运行**，不是通过。按权限流程运行独立 AIR 测试后可以加载；不能据此推断所有 AIR 操作都需提升权限。
- `e63e453885` 首次原生试验复现地雷失败；索敌场景首次 look=0，证据不足。调整原生眼睛坐标并先断言可见后，`51c83cb01e` 才确证目标选择故障。
- `b21dc526f8` 核心修复通过，但既有 AI 恢复检查失败：旧假对象未提供原生单位必有的 X/Y，新的就近认领无从配对。补齐夹具坐标后最终回归通过；没有删除断言。此轮也发现宠物仍进入广播，已统一排除玩家阵营。
- Java 文件存在，批处理在本次受限环境中无法解析 PATH 上的 java。构建工具增加显式 `--java`，经真实编译验证；不是工具丢失或新装 Java。
- 以上环境经验建议归入工具环境记录，状态 **[未落盘]**（尚未写入共享总库）；模组显示/身份/目标策略保留本项目，避免当成原版游戏规则。

## 部署及验证边界

版本 **0.2.1-dev / M29**，普通候选 `build/m29/RConnectMod.swf`，45574 字节，SHA-256 `33CE3B722A3473CC24659E813F8BBB7A934B295F680BD5612A341515A6B38685`。静态确认不含 CoopTestDoc、EnemyRegression、CoopNetworkScenario 测试入口。

只替换 `release/RConnectMod.swf`。备份：`build/backup/m29-release-20260920-095514-292641/RConnectMod.before.swf`，旧版 SHA-256 `2A65D5F83567BD1FB8D537270BEE4499FBAA7BF6EF2EAF89BE161BFDE0A8CF56`。复制该备份回 release 并重启双方即可回滚。配置、三份游戏 SWF 与 application.xml 前后指纹一致。

部署后从正式 release 读取产物的独立双实例 **e7c3ca8fe9 PASS**：双方日志均有 0.2.1-dev 初始化、tick 200；加入方 welcome 与单位同步通过。仅结束本轮测试 PID，用户实例保持运行，需用户重启双方加载新版。

范围：游戏 1.02、同机双人、真实 RealisticVision SWF（指纹见证据 JSON）。没有加载 TDFC/MSW/RR 做全组合验收；TDFC 自有战术仍主要以房主为目标，此轮没有修改其源码。没有穷举全部地区/Boss/潜行积累手感；未声称完整复现用户存档环境。稳定重连、三人以上、真实网络、版本兼容及新任务/背包/交易系统仍排除。

## 本次产物与证据

- 源码：GameBridge、ObjectIdentity、Session；tests/EnemyRegression.as、CoopNetworkScenario 等回归入口；build_mod.py 显式 Java 参数。
- [结构化证据](m29-validation-evidence.json)：各轮断言、日志指纹、候选与部署指纹。原始隔离日志在 `build/cooperation/<token>/`，不依赖读取其他模组源码即可核对结果。
- `build/m29/deployment.json` 保留部署前文件指纹及回滚点。
- 此记录按测试报告约定登记；无委托，无修改技能正式行为。
