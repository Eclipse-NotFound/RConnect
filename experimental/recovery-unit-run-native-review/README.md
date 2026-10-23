# 用户地图首错的最小原生取证

仅准备源码与薄入口，尚未编译或实测。产品仍为准确正式 aura1，宿主和其他模组使用当前 22 项安装基线。外部驱动以 `recovery-room-repair-review` 已有 RoomTravelTimingTestDoc 为基底，保留三段原生旅程、房间/尺寸/种子/出生/操作恢复断言及原 95 秒分段超时。

差异仅为：固定测试 seed 为 `4095208676`；宿主/离线侧首个 beginMission 前设置 random_mane 的 landStage=4 一次；用既有 Littlepip 29 隔离模板正常读档后先回 rbl；增加外部只读单位取证。原 runner 未复制、未修改，仍使用登记、独占、双实例 6 GiB/单实例 3 GiB 和运行中 512 MiB 门槛。原三段不完整或原生报错仍为失败，部分记录仅用于首因分析。

## 存档与前置

直接读已有隔离副本，不读取或修改玩家真存档：

- `build/m52/littlepip-save-replay-01/host/PFEgame0.sol`：`2c0fe1d16138797b5914a7e1a0adb12e7438c0b0fba88e594490bba30f42c9f4`
- `build/m52/littlepip-save-replay-01/join/PFEgame0.sol`：`8e70021accf93b8b920935666f85e6dc06f863ce5b242d04d6c7e2f38ef1bc3d`

该目录 source-audit 已记录双方 Littlepip、level 29、random_mane stage 4。原 runner 将副本改名为隔离 slot 9，并令生产 autoLoadSave 正常载入。它在提供存档模板时不会设置 autoTravelLand，所以驱动在原生稳定、确认为 Littlepip level 29 后，由宿主/离线侧正常 gotoLand('rbl') 一次；加入侧继续走生产跟随。没有自行布置出生位置或强制替换单位。

种子钩子仍沿原驱动规则：宿主/离线固定，加入侧调用生产原有种子函数。没有绕过真实加入侧采纳。此固定种子不保证 Math.random 产生的所有内容与用户现场相同。

## 观察与失败边界

`UnitRunGenerationProbe` 不调用单位 step、setPos、snapshot、restore，也不改错误框、碰撞或世界状态。首个新目标 Land 返回后，以及第一次可见 verror 时，各最多保存一份 JSON 到实例自己的 `Local Store/unit-run-generation/`。错误文件保留完整 verror 文本，不沿用生产日志的 400 字截断。

扫描当前 Land 的各层 loc.units，最多 512 个房间、8192 个单位、100 条异常详情；超界显式 complete=false，异常超出 100 条标 anomaliesTruncated。记录房间尺寸和身份、非有限坐标/尺寸、X1/X2 对应首尾列缺失、单位 loc 身份，附 disabled/sost/in_chain 等解释字段。protected diagon 不越权读取，明确记 protected-not-read。不会将异常单位数量直接等同于首错单位：扫描发生在原生生成返回/后续 ENTER_FRAME，已丢失的瞬间坐标可能无法追回；死单位或特殊非碰撞单位也可能合法位于边界外。

首个错误记录后，驱动原样记 COOP FAIL，停止本测试流程并保留原生错误状态；不会为继续三段而自动关框。若初次读档本身就报错，phase=boot 会明确保留，不能宣称已经复现后续新探索。取证自身异常保存 faults/complete=false，输出失败会记 COOP FAIL。

薄运行入口另外复制并核对观察 JSON、模板源指纹和实际 runner slot 9 记录。`functional_pass` 仍要求三段全成、无原错误；`passed` 还要求实际生成观察存在且无原生首错。所有输出 `diagnostic_only=true`、`performance_qualified=false`。一次扫描及写文件会扰动该帧，计时不得拿来证明性能改善。

## 由根会话串行执行

以下以 `mods/RConnect` 为当前目录，先由根审核源码并运行构建；此交付没有执行这些命令：

```powershell
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/recovery-unit-run-native-review/prepare.py --output build/m52/recovery-unit-run-driver-01 --build
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/recovery-unit-run-native-review/run_native.py --drivers build/m52/recovery-unit-run-driver-01 --product aura1 --mode dual --scenario timing --output build/m52/recovery-unit-run-dual-01
```

`timing` 为普通房原生模式；若需要与大场景对照，使用新的输出目录并显式选择 `scene`。同源单人用 `--mode solo`，只传 host 模板；不将单人取证视为联机资格。
