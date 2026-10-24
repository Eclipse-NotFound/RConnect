被测技能：remains-release-gate 2026-10-19.1；remains-auto-testing / runtime-debug / mod-build；test-report 2026-09-16.1
技能归属：Remains 工作区 .agents/skills；用户级 C:/Users/hello/.agents/skills/test-report
测试工作区：D:/Program Files/Steam/steamapps/common/Remains/mods/RConnect

# 2026-10-25 B190 启动、旧旅程备份与接口释放修复

## 当前交付

用户反馈双侧 `TDFC authority already attached`。本次修复已经更新到 **原有 `build/ab/b3-playable-190` 入口**，版本 `B3-0.1-startup2`。用户已保存并退出原两窗口；验证没有操作原存档或替用户关闭窗口。仍通过 `Player-1.cmd` / `Player-2.cmd` 启动，App ID 和角色存档目录保持原值。

- 实际部署 SWF：`2c536b5d2204b0acb0d69b025beff4cca7036c08260fda6a205ecb2190eb259b`，226240 字节。
- 冻结源码 ID：`a8d1148646d86a2088d0ce1ea1672bce9e588b6221e2230c0429e1360b07aa3f`。
- 构建：`build/ab/b190-startup2-build/build-input.json`；来源为冻结 B190，只改两个产品源文件及生成的版本指纹。
- 部署回执：`build/ab/b190-startup2-deploy-20261025-01/deployment.json`，状态 `verified`。该目录 `before/` 保存原 SWF、README、manual-input、playable-validation 四文件，`deploy-executed.py` 冻结实际执行脚本。
- B190 原 Native019 / TDFC004 / RV003 / MSW011 / Sandevistan001 与其余游戏资源逐项核对保留。普通 A 的安装入口未写入。本次没有引入 B195 性能候选。

## 根因与改动

实际玩家日志先出现 `Profile exceeds data budget`，之后重试才出现 TDFC 占用错误。隔离复制用户 B 槽 0 后，原 B190 实际重现了这条错误链。

1. 加入前需备份整个本地旅程，旧代码却把网络角色资料的 24000 节点上限也用于此备份。本次存档为 34362 节点，其中旅程 32735、角色资料 1622。`PlainData.nativeCopy` 现在仅对**游戏自身产生的本地保存数据**取消节点总量限制；深度、类型、键与数值校验以及原数组结构保留。联网用的 `PlainData.copy` 仍有原上限。实际所有 nativeCopy 调用均来自 `saveToObj` 或角色、背包、外观的 `save()`。
2. TDFC 接口在完整会话构造前已经取得。等待加入的宿主还没有 RoomRuntime，或加入侧构造中抛错没有产生 replica 时，原清理分支会遗漏释放。`RConnectMod.leaveSession` 现在在两种对象清理之后统一释放已取得的 TDFC 接口。已有运行中的 runtime 释放仍可重复调用，桥接对象自行归零；没有删除 TDFC 的重复接入保护，也没有改 TDFC 源码。

## 原生验证与失败保留

外部驱动加载实际候选，派发真实 HUD Host / Join / Leave 按钮事件；配置 `probe=false / autoGame=false`，通过原生菜单逻辑载入独立复制的存档。测试走共享登记、独立 AIR ID 和私有桌面；仅管理自己的进程。每轮保存实际组合指纹与原始日志。

| 记录目录（均在 build/ab） | 实际结果 |
| --- | --- |
| startup-red-host-20261025-01 | 原 B190：6 通过、3 失败；第二、三轮建房重现 already attached |
| startup-red-join-20261025-01 | 原 B190：2 通过、7 失败；先预算错误，再接口占用错误 |
| startup-green-host-20261025-01 | 第一修法：8 通过、1 失败；原目录名保留，不能当绿色结果 |
| startup-v2-host-cancel-20261025-01 | 当前修法：9/0；三轮取消建房后重试 |
| startup-v2-host-bind-failure-20261025-01 | 当前修法：9/0；三轮端口占用后释放，保留原 socket #2002 错误 |
| startup-v2-join-refused-20261025-01 | 当前修法：9/0；三轮连接拒绝后释放，保留原 socket #2031 错误 |
| startup-v2-pair-20261025-01 | 启动余量 5.520 GiB < 6 GiB，未启动 AIR，不算代码失败或通过 |
| startup-v2-pair-20261025-02 | 6/1（主）与 13/0（加）；驱动采样时序失败，原记录保留 |
| startup-v2-pair-20261025-03 | 9/0（主）与 13/0（加）；同进程内两轮连接/正常退出通过 |
| startup-installed-pair-20261025-01 | 从部署文件重新启动：9/0（主）与 13/0（加）；两轮通过 |

合计当前修法部署前 **49 项专项断言通过**，部署后 **22 项复验通过**，后者包含重复验证，不能称 71 个独立功能。双方版本和来源指纹正确，角色会话和原生帧继续推进；加入侧离开后自己的保存旅程 `game.lands` 逐项一致，`ggControl` 恢复、`onPause=false`。每轮实际运行组合指纹未变，无 RConnect FATAL，原生错误面板未出现。

第一修法曾尝试用 ByteArray 克隆备份，虽然真实存档复制通过，但稀疏、带名称属性的 Array 结构验证失败，已放弃，未交付。最终沿用原克隆逻辑，仅区分本地与网络预算。

pair-02 的加入侧在第二轮已完成自己的 25 帧检查并退出，而宿主独立计数尚未达到 25 个 tick，导致宿主停在 phase 2 等待到超时。pair-03 仅改外部驱动：宿主完成原断言后写本轮标记，加入侧再正常退出；产品 SWF、原断言与阈值不变。新驱动 SHA `c1446ec050b05f84dc816f3d7f33abee14e1105c89ea4739cc1c2355c66d754d`；第一驱动及准备清单另存。

## 发布范围、回滚与保留

本地窄修门禁已完成：隔离构建、版本、专项实测、原包指纹核对、备份、同字节更新与部署后双侧复验。B 仍是独立实验版，元数据的 `formal_release_gate_complete=false` 保留；新的 `local_startup_repair_gate_complete=true` 和 `candidate_ready_for_manual_testing=true` 只指本次修复。原 B190 的完整玩法、600 秒密集测试记录保存在备份验证文件中，**没有重新标为本次新字节的实测**。本轮不证明全部武器/战斗/视觉、真人输入、长期稳定性或性能改善。

需要回滚时先保存退出 B，再运行 `tools/host_authority/startup_driver/deploy_fix.py rollback`。它仅恢复上面四个备份文件；如目标有新的并发修改会拒绝覆盖。回滚路径已备份并审查，本次没有实际执行回滚，因为部署后复验通过。

`startup-repair-20261025-01/game` 已在验证结束、核对自有进程退出后删除。`cleanup.json` 留下每个文件的 SHA 和可恢复来源，独有驱动/配置/描述文件在 `retained-runtime/`，脚本在 `retained-tools/`；原始日志、冻结的两份存档、两代驱动、源码和候选都保留。净回收 **312747634 字节（约 313 MB）**。重新测试需按清理回执恢复副本，不能直接运行指向已删除 game 的命令。

## 技能实战回流

本次自然采用调试、构建、自动测试和发布门禁方法，test-report 用于同一任务合并登记。新证据是：较大真实旧档的初始化异常、等待/失败阶段接口清理、测试双方检查结束顺序以及窄修更新既有实验入口。知识属本模组实现与测试夹具，未推广成游戏本体规则；本次产物为源码、驱动、配方、上述回执和本报告。

技能指纹（SHA-256）：release-gate `2d6030bc3311400fdb4301e7708e45357ff7dd66f1c86c9298c3914100c6db02`；auto-testing `d6c2efbb03c2d5431c438b4626b83ae00c36e2904b91dba10c4d4a2b06a4dc89`；runtime-debug `6017fbd0d89c8aa08f31c3b8474f7feca6f901c483f0fe08f10178e1246f6eb7`；mod-build `1907a013dc94d0848d88b1ccd163cf0045d65edebd49b33af8575bcb5ac6f88a`；test-report `cde4695f98417768f2c11ea42f6ea1f4400ddecc5d00f5a224fcc988646febf5`。

处置：待维护侧核对；没有修改技能文件，也没有把驱动时序问题归咎于技能。尚无用户对修复后的试玩反馈。全局测试报告台账已查重追加并回读确认（2026-10-25，状态待吸收）。
