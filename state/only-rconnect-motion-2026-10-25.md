# 仅 RConnect 原生运动核验 — 2026-10-25

## 本次核验范围与判断

本文件记录两轮原生念力抓取实测的独立复算，不改变原测试标准、不重跑游戏。正式 78C 与跳跃姿态候选 52D 均通过原主侧 43 / 加入侧 42 项检查、四个完整测量窗口及实际模组选择检查。52D 在这组箱子／掉落物抓取流程中没有出现原检查所能识别的功能回退；两者本机均接近 30 fps，不能据此宣称全部远端动画已经流畅，或认定 52D 带来了整体性能收益。

- 78C：`build/m52/goal-rconnect-only-motion-held-baseline-01`，运行 `2673bc6f78`。
- 52D：`build/m52/goal-rconnect-only-motion-held-pose-01`，运行 `3fb602435d`。
- 两轮均真实只启用 `RConnectMod`。每端 MainFE 状态的 `requested == ok == [RConnectMod]`、`err == []`；ModLoader 的选择器工具不等于启用其运行模组。
- 物理副本中的 14 个模组 SWF 清单完全相同，但只加载 RConnect；另记录的正式安装 22 项在各轮前后不变。两轮原运行输入只差生产 RConnect 产物；配置只差临时端口。宿主仍为 A796，停用模组不会撤销已嵌入宿主的补丁。
- 沿用已编译 FEF 原生驱动和 D52 Harness，未新增动作、截图或检查阈值。正常 Q 抓取、两次往返移动、松手、重力下落、原生地板落地；固定玩家位置并冻结环境 AI。这不是敌人抛掷或密集战斗测试。

## 本机帧与长帧

每格格式为“ENTER_FRAME fps；实际 RENDER 间隔 p95 / 最大值（毫秒）”。fps 按实际帧间隔计算，未用驱动计划帧数代替。

| 抓取轮次 | 78C 主侧 | 78C 加入侧 | 52D 主侧 | 52D 加入侧 |
|---|---:|---:|---:|---:|
| 主侧抓箱子 | 30.024；45 / 73 | 30.004；40 / 86 | 29.994；43 / 69 | 29.986；41 / 67 |
| 加入侧抓箱子 | 30.144；47 / 68 | 30.041；47 / 76 | 29.998；46 / 81 | 30.000；41 / 78 |
| 主侧抓掉落物 | 29.429；51 / 67 | 28.916；54 / 94 | 29.994；45 / 65 | 30.227；38 / 59 |
| 加入侧抓掉落物 | 30.008；48 / 70 | 29.836；48 / 62 | 29.926；45 / 65 | 29.994；42 / 60 |

四窗加权 ENTER fps：78C 主 **29.900**、加 **29.696**；52D 主 **29.978**、加 **30.052**。四窗测量总时长分别为 20.805 / 20.742 秒和 20.654 / 20.659 秒。所有窗口均为后台焦点，无前后台切换，不能外推前台表现。

两轮主／加均无超过 100 毫秒的 ENTER 或 RENDER 间隔。RENDER 超过 50 毫秒的间隔：78C 主 **20 / 618**、加 **25 / 612**；52D 主 **14 / 615**、加 **11 / 617**。52D 这一次的长帧较少，但仅一对先后运行不足以证明收益由候选造成。

## 远端连续移动与松手

下表仅取各轮接收端的实际绘制轨迹。原拟合算法原样复算，延迟、样本数、均方根误差均与原日志一致。延迟是源轨迹与接收端画面的相对拟合结果，**不是校准过的单程网络延迟**。原上限仍为 160 毫秒。

| 抓取者 → 观察端 | 拟合延迟 78C → 52D（毫秒） | 移动段重复位置 78C → 52D | 最大单帧位移 78C → 52D（像素） |
|---|---:|---:|---:|
| 主侧箱子 → 加入侧 | 80 → 90 | 0 / 79 → 0 / 79 | 5.326 → 5.320 |
| 加入侧箱子 → 主侧 | 100 → 90 | 0 / 79 → 1 / 79 | 6.964 → 9.278 |
| 主侧掉落物 → 加入侧 | 80 → 90 | 0 / 79 → 0 / 79 | 10.781 → 6.737 |
| 加入侧掉落物 → 主侧 | 90 → 90 | 0 / 79 → 0 / 79 | 6.719 → 5.705 |

52D 的一次重复确实存在：主侧观察加入侧抓箱子，轨迹相对时间 2368 → 2406 毫秒，显示位置仍为 `(377.4, 212)`，持续 **38 毫秒**；没有连续多帧冻结。原条件仍为 `frames > 12`、`stalls / frames < 0.5`、`maxJump < 25`，并未因结果调整。整窗还包含主动保持不动，不能把整窗所有重复位置算成运动卡顿。

箱子松手的 `releaseWireAt`：主侧 → 加入侧 **242 → 112 毫秒**，加入侧 → 主侧 **79 → 47 毫秒**，均符合原 `< 350` 检查。这是接收端先收到测试用 `native-release` 通知、后收到实际生产 `q:false` 的到达间隔，不能直接解释成玩家按 Q 到对侧松手画面的延迟。原 `releaseFramesMs` 约 2.4 秒包含驱动松手后的观察和落地等待，也不能当通信延迟。两轮四程均验证解除悬浮、施法者目标指针清空、恢复重力并落在原生地板上；掉落物没有同一条 `q:false` 到达间隔测量。

## 完整性、指纹与限制

从两轮主／加原日志抽取全部 16 份 `NATIVE MOTION MEASURE`，重新调用冻结分析器所得 summary 与保存结果完全一致；四次拟合／每轮亦按原算法复算一致。测量均完整结束、无丢样，计时开关均恢复。每窗最后一个 ENTER 没有对应 RENDER 是驱动在该 ENTER 内结束测量造成；**中间缺失 RENDER 为零**。没有同步截图污染。内存最低可提交余量分别 **22.65 / 22.34 GiB**，无压力停止或外来 AIR 重叠；登记结果均 PASS。根会话已确认两轮测试实例退出。

原始证据：

- [78C 结果与逐端 summary 所在目录](<D:/Program Files/Steam/steamapps/common/Remains/mods/RConnect/build/m52/goal-rconnect-only-motion-held-baseline-01/result.json>)；[78C 实际选择结果](<D:/Program Files/Steam/steamapps/common/Remains/mods/RConnect/build/m52/goal-rconnect-only-motion-held-baseline-01/only-rc-result.json>)；原日志位于 `build/cooperation/2673bc6f78/{host,join}.log`。
- [52D 结果与逐端 summary 所在目录](<D:/Program Files/Steam/steamapps/common/Remains/mods/RConnect/build/m52/goal-rconnect-only-motion-held-pose-01/result.json>)；[52D 实际选择结果](<D:/Program Files/Steam/steamapps/common/Remains/mods/RConnect/build/m52/goal-rconnect-only-motion-held-pose-01/only-rc-result.json>)；原日志位于 `build/cooperation/3fb602435d/{host,join}.log`。

SHA-256：

| 项目 | 指纹 |
|---|---|
| 78C 生产产物 | `78c052aea963f1689b705ae1e14d274916ae1a1f7e81933390caf8d1a88f4699` |
| 52D 生产产物 | `52d4723c1cf43e9ed2949c2e20debf7beda0b6068767c0bbaf83e83eb6a56e88` |
| 共用原生驱动 | `fef72ab405e5df894b1e683e40d6171fa9cbd1d543aac6d2a75f5f51402317cb` |
| 共用 Harness | `d52ef4300c7d472ee05884d7b4709f4abf80b3e6ff935b695a9ed986db021086` |
| 78C result.json | `7e1bc183061d208bff849d64d19e7a9e3fa504c184b4e66388e373360ea6d5f3` |
| 52D result.json | `73cb60ae069a5fb81ee7961f381a735ebcdb595c7f074e4c51b00dc58bd3bc31` |

两轮均保留 `performanceQualified=false`、`smoothnessQualified=false`、`installed=false`。当前证据只支持这四种原生箱子／掉落物抓取操作；不覆盖 E 键敌人抛掷伤害、密集战斗、子弹、武器动画、SATS、真实网络或长时间游玩。52D 的跳跃身体姿态由独立跳跃实测负责，本表不借用念力结果替它授资格。与此前多模组约 15 fps 的结果相比，只能说当前仅 RConnect 组合未复现该幅度的低帧率，不能据此归因到某一个已停用模组。
