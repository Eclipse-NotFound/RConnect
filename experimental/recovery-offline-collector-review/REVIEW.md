# 原生玩家弹丸采集实测独立复核

日期：2026-10-23。对象：`f6eece7606`，仅事后读取、复算及文件散列核验；本审查未启动游戏、编译、修改冻结输入或部署。

结论：认可本次“玩家弹丸历史采集”专项通过，未发现应推翻结果的证据。原始日志有 86 条通过、0 条失败；唯一结果 JSON 与包装器保存的结果逐字段一致。不能据此认定身体特效、双人连接、对侧最终画面或性能通过。

## 输入与运行边界

- 候选为 `0.2.24-offline1`，SHA-256 `EB3653533CFB305BCCA0B0CFE5E81BC306EA28FA400AAE751AB7B5AE1CFA5FEE`；实际运行副本与运行输入记录一致。
- 驱动 SHA-256 `3DF94BEB6052D944070C5B140778741545FBECAE1E46DE9022504DF91B6CF2D4`；驱动清单 `529D2285FC24AC92E8D57025CA484BACDD7DB2C860A3CC3AAF06363C64A793B3`。9 个冻结文件、8 个工具及当前 AS/包装器与清单逐项相符。
- 共享运行器仍是 `7ECA453B13480140DA5F36BB33D2319739A927562CCAFDBB61A8B20CDB5AE4D3`。没有错误豁免；独立扫描主日志、标准输出和模组日志，未命中共享错误模式或 `COOP FAIL`。
- 实际只有一个隔离实例，应用 ID `pfe-modsettings-rconnect-coop-host-f6eece7606`；无用户存档模板。第六段实际开无人宿主，端口 60054，没有第二个游戏或合作握手。

## 原始位置复算

从 `host.log` 的六条 `collector-proof` 重新计算；每段均有三个不同 ENTER 帧、三个不同原生显示位置，且弹丸仍在原生链中。以下五个正例均为三帧与三个原生位置完全匹配，帧时间互异，从而组成三组“不同时间、不同位置”配对；每段驱动只读取一次公开快照。

| 阶段 | 产品帧时间（毫秒） | 对应的原生显示位置（x, y） | 匹配帧／有效配对 |
|---|---|---|---|
| virgin | 空 | (693.65,576.70) → (729.90,567.40) → (766.10,557.30) | 0／0，符合负对照 |
| null | 31700, 31742, 31776 | (696.60,578.45) → (735.80,570.75) → (774.95,562.20) | 3／3 |
| throws | 33134, 33177, 33216 | (689.65,575.50) → (721.85,564.75) → (754.10,553.05) | 3／3 |
| falseValue | 34500, 34548, 34601 | (699.15,578.95) → (740.85,571.70) → (782.55,563.45) | 3／3 |
| truthyString | 35828, 35884, 35924 | (702.40,576.40) → (747.40,566.70) → (792.40,556.10) | 3／3 |
| afterHost | 37172, 37239, 37288 | (691.65,576.60) → (725.85,567.15) → (760.05,556.80) | 3／3 |

原生类型为 `fe.weapon::Bullet` / `visbulflame`；六段武器 speed=40、flame=1。公开快照中的 capture 以 stamp=0 观察，不能补造这些正时间历史。无人宿主本身可能定时 capture，所以第六段不声称整个系统只 capture 一次。抛出哨兵阶段在取证时实际调用并抛出 23 次，阶段结束前累计 93 次；没有未捕获错误。这些时戳来自采集和 RENDER 的不同时间点，不是网络延迟或帧率测量。

## 清理与恢复边界

- 原始 `prepared.originalWeapon` 为 **null**。`equipmentRestored=true` 结合准确 AS 的断言，证明恢复了空手状态、原 weapons 数组及 childObjs 条目身份，也核对 magic/throw/fav/favIds/items 的原身份；本轮**没有实测恢复一把非空原装备**，也没有证明所有背包内部数值或武器瞬时计时器的完整回滚。
- hook 恢复原函数身份；真实 leave 后 mode=offline、server/link=null；资格仍保持首次 host 后的 false；内存配置 port 恢复。四项 cleanup 确认均 true，errors 为空。没有调用 Config.save。
- 已独立重算安装前记录的 22 项文件，全部相同；安装版 RConnect 仍为 `574D2B51490AE8B25A1396555600F56A301F8A20AE50104C0E35CF2796441AFE`。
- 自有 PID 50656 已不存在；run 目录内 host/join/frozen 三个可重建副本均不存在。独立应用的 Local Store 日志与回执仍保留，不应写成“所有测试目录已删除”。登记回执 passed=true、cancelled=false。
- 30 条内存记录：启动可提交余量 5,256,077,312 字节，最低 3,335,639,040 字节；未触发内存停止或外部 AIR 重叠停止。此次属于功能测试，没有性能资格。

## 可追溯证据

- [原始日志](<D:/Program Files/Steam/steamapps/common/Remains/mods/RConnect/build/cooperation/f6eece7606/host.log>)：`352B4940306076F0FC124B935986786EC90694EE68210D11C853DB83A21DE946`。
- [汇总结果](<D:/Program Files/Steam/steamapps/common/Remains/mods/RConnect/build/m52/recovery-offline-collector-native-01/result.json>)：`FAD44385D4CB3F4F309582F85FB613227FBC179C4D51923DE981B909113270A9`。
- [实际输入记录](<D:/Program Files/Steam/steamapps/common/Remains/mods/RConnect/build/cooperation/f6eece7606/run.json>)：`70E107172F76092EB01868C4E081A5C6D8A5E5810933BA157FD053723EE185E9`。
- [测试登记回执](<D:/Program Files/Steam/steamapps/common/Remains/mods/RConnect/build/cooperation/f6eece7606/registry-result.json>)：`4A6D3B2F363CC075D52DF8FB6D7DFD227A3213E2FA84B107F21545CC8E6A8919`。

审查期间一条综合只读核验命令被本地护栏误判为二进制操作，未执行。随后将日志复算与明确的只读 Get-FileHash 核验分开完成；没有调整护栏或新增授权。
