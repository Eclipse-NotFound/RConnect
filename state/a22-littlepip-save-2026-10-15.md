# A22 Littlepip（29）存档只读定位 · 2026-10-15

## 定位与边界

用户提供的名字匹配 `pers.persName=Littlepip`、`pers.level=29`，29 是等级。普通入口 `application.xml` 的 AppID 为 `pfe`；双开第二窗口 `tools/second_player_descriptor.xml` 为 `pfe-modsettings-rconnect-player2`。`RConnect.Profile.ps1` 证明当前第二角色从旧 `pfe2` 迁移；没有执行启动器或迁移函数。

仅枚举这两个已确定 profile 的 `Local Store/#SharedObjects/pfe.swf/PFEgame*.sol`，共 22 个存档。**每个 profile 均有槽 0 和槽 5 匹配 Littlepip（29），因此名字不是唯一槽位标识。** 槽 0 为今天的最新记录，第二窗口槽 0 的当前武器是 `quick`，与本轮速射等离子枪反馈相符，适合作为优先复现候选；不能声称用户已经唯一指定它。

本次不启动游戏、不复制或写入用户存档；新工具仅解析显式给定的文件，AMF3 中的类名作为数据，不执行 application 类。开始与结束再次核对两个槽 0 的 SHA256 相同。

## 精确候选

| 角色资料 | 文件 | 字节数 | SHA256 |
|---|---|---:|---|
| 第二窗口，最新槽 0 | `C:/Users/hello/AppData/Roaming/pfe-modsettings-rconnect-player2/Local Store/#SharedObjects/pfe.swf/PFEgame0.sol` | 211040 | `8e70021accf93b8b920935666f85e6dc06f863ce5b242d04d6c7e2f38ef1bc3d` |
| 普通窗口，最新槽 0 | `C:/Users/hello/AppData/Roaming/pfe/Local Store/#SharedObjects/pfe.swf/PFEgame0.sol` | 210816 | `2c0fe1d16138797b5914a7e1a0adb12e7438c0b0fba88e594490bba30f42c9f4` |
| 两窗口均保留的旧槽 5 | 对应上述目录中的 `PFEgame5.sol`，两份字节一致 | 209365 | `aab0b90d39b894eb3e1af901131b0a9daada4f4960a02182f28d9a056b53c7ec` |

第二窗口槽 0 内保存时间为 `1791997491028` 毫秒（2026-10-15 01:04:51，北京时间）。旧槽 5 为 `1782147624942` 毫秒（2026-06-23）。所有槽位目录、存档内时间、哈希留在 `build/m52/littlepip-save-catalog-01.json`，未改原始记录。

## 第二窗口槽 0 的已保存字段

- 版本 `1.0.2`，存档内 `n=0`，地图 `random_mane`。
- `persName=Littlepip`，`level=29`。
- 技能原始点数：`tele=16`、`magic=17`。这不是念力技能等级 16。
- 专长：`telethrow=1`、`telemaster=1`、`selflevit=1`。
- 魔力健康字段 `manaHP=0.8731638643359567`；**它不是当前可用魔力池，也不是 `manaSt`**。
- 装备：武器 `quick`、护甲 `assault`、护符 `amul_energ`、魔法 `sp_mshit`。
- 普通窗口槽 0 的技能/上述专长相同；当前武器 `lmg`，`manaHP=0.9124299999999955`。

当前 `mana/maxmana`、`throwForce`、`throwDmagic`、`spellsPoss`、`manaSt` 等最终派生字段没有直接保存在这些角色字段中。不能把技能基础数据当成实际运行值；需要由主会话在唯一隔离 profile 读入精确副本后记录，保留装备、创伤和模组影响。

第二窗口 `config.sol` 确认 `keyTele=Q/右键`、`keyAction=E`，未见这两个操作被改成其他键。配置 SHA256 为 `350285d2d64ca86d98ed9ac57773bee4467ebdbf379b1adc41135f68f190a958`。

## 工具、证据和未完成项

- 只读工具：`tools/validation/inspect_native_sol.py`。只接受显式文件；报告输出必须在 RConnect 内，拒绝覆盖已有分析；校验 SOL 签名/声明长度/AMF3 编码与完整消费，检查读取前后文件时间和长度。
- 最小解析检查通过：有符号整数、浮点数、字符串引用、动态对象自引用、关联数组和 externalizable 拒绝。实际 22 个角色档及第二窗口配置均解析到文件结尾，无截断或未知标记；这不是游戏行为验证。
- 两个槽 0 的字段证据：`build/m52/littlepip-save-audit-01.json`。
- 两个 profile 的完整窄范围槽位目录：`build/m52/littlepip-save-catalog-01.json`。
- 第二窗口配置：`build/m52/littlepip-save-config-01.json`。
- 首次在原版参考目录搜索 SharedObject/getLocal 的只读组合命令被本地护栏以 `protected target/read-only-reference` 拒绝。没有换工具或包装重试。定位依靠已知启动器、明确 AppID 目录及独立 SOL 数据解析完成；未声称这次已重新核对原版的保存/菜单显示源码。
- 正常属性的原生 E 测试此前为 40/0，不等于用户存档异常已修复；本次也未启动存档实测。独立复制、读档后连接和实机采样由主会话继续。

## 后续复制档实测

上述“未复制、未启动”仅指最初的只读定位步骤。随后主会话将双方最新槽0只读复制到 `build/m52/littlepip-save-replay-01`，在新AppID的槽9加载；原存档未写入。`24010bb6f4` 与补充显示取证的 `99a41f3b8e` 各31/0，实际投掷力25、魔力池1000、最大抓取质量12，保留存档技能与装备。

这些测试仍直接选中碰撞代理、短时抓取，不能替代自然准星下长抓后按E的复现。补充取证确认一次主侧抛掷的短轨迹端点被200ms采样遗漏，加入侧两次抛掷仍实际飞出，不能宣称用户故障已修。下一步使用独立自然准星Q/E夹具，记录抓中本体或代理，以及持有抵抗与释放的顺序。完整运行/结果和限制见 [任务接续](a22-followup-2026-10-15.md)。

## 自然准星长抓与方向偏差

`004a273059` 的三轮自然准星 Q/E（42/0）确认实际抓中 UnitRaider 本体，非强制碰撞代理。长抓抬高/横移、接近挣脱阈值按 E 均有主侧真实飞行；第三轮不按 E，按原生抵抗耗尽自然松手。不能把自然挣脱当成需要强制投掷的故障。

第一轮 E 前 5ms 已收到敌人 X=125.5605，而用于原生投掷计算的延迟显示 X=77.075，玩家 X=120。目标实际已在玩家右侧，原生计算仍把它当作在左侧，得到水平推力 -7.7548。这是已确认的错时方向问题；该轮仍实际飞行并撞击扣血，不能称为用户“完全不飞”的完整复现。

新增断言直接从已接收同步包独立计算方向，不使用生产辅助接口作为答案。相同旧候选12的负对照 `bda94050a7`：47通过、2失败，失败恰为两次投掷方向不符，原生力度和自然耗尽检查通过。候选14只将真实原生冲量按最新已收到位置旋转，保留其长度、魔力消耗、许可、抵抗和伤害规则；当前正在做正对照，尚不写修复通过。

正对照已完成：14旧冻结组合 `f6e1f65e11` 49/0；合入最新本体后的当前组合 `a301071a62` 也49/0，魔力/力度/自然耗尽检查保持。普通角色一次低空投掷第二帧速度下降仍为未定样本a903，补采碰撞邻域a894为40/0而未复现。详见任务接续，不将这两类证据混成“所有投掷问题已修”。测试只写独立AppID，未写回原档；结束时加入侧原档哈希仍相同，主侧原档已由外部写入改变，保留其新内容，未覆盖。
