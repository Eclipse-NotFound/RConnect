# 玩家念力光晕移植到 offline1 的独立复核

2026-10-23。范围为只读检查历史原件、准确候选及最小移植；另按根任务指派提供外部驱动准备薄包装。此审查没有执行 Java、AIR、部署或修改其他模组。没有把祖先功能通过转成新候选的部署资格。

## 结论与准确输入

根已构建的 `build/m52/recovery-aura-offline-01` 符合本次最小移植：78 份生产源码中只改变四个光晕文件和版本，其余 73 份逐字相同，没有增加生产类。`PeerThrowDamage`、网络帧协议、加载、房间、弹体及离线采集开关均没有借机换成 recovery21。

| 输入 | SHA-256 |
|---|---|
| offline1 基底产品 | `eb3653533cfb305bcca0b0cfe5e81bc306ea28fa400aae751ab7b5ae1cfa5fee` |
| 574D 历史基底产品 | `574d2b51490ae8b25a1396555600f56a301f8a20ae50104c0e35cf2796441afe` |
| recovery21 实测供体产品 | `9ac7ede757c253bbf61e0c44334870b4a95112f976c1b40f2f390822a8b7e7ba` |
| 新 aura1 产品 | `df0fa0e2ca952e77e5132e75d71e73558dc919c7b8cdeba5da05fc9e94dc01e7` |
| 新候选 `compile.json` | `01e223598ab8b4c9ba9be0aebe9a9029bb685feadecda5532fd1b36858d679aa` |

已核对新候选四类与根的 `experimental/recovery-aura-offline/src` 逐字相同。完整来源分别在上述三个 `build/m52/<目录>/src`；574D 为 `coop-bundle-04`，offline1 为 `recovery-offline-production-01`。

## 四个生产文件的精确范围

1. `rconnect/core/PeerGrip.as`：offline1 与 574D 同为 `2d44e4b2dabec605ff512ebb3319708b5c76b6e62c489bcca9a95f2ee7d9651b`；新文件与 recovery21、`experimental/recovery-aura/src` 完全相同，为 `e85e81da3c318e9163592ffdaae84e067fda6f8d3af93cd66c7dc043905d8840`。新增独立 TelekinesisVisuals 实例；第一次原生 Q 后采集目标身上的真实 GlowFilter 和 ColorTransform，经原有 hold 包附带 aura 发送；接收校验通过后在 after 与最终 RENDER 重现，endIncoming 统一 reset。原 token、连接、房间 epoch/term、许可、抬升、抛出和伤害行为不变。
2. `rconnect/game/TelekinesisVisuals.as`：offline1 与 574D 同为 `e3abdaf0892aa284fc5d35fe2bf1f77d1fb2c068ba6f98828fb25b1f825fc169`；新文件与 recovery21、`experimental/recovery-aura-followup/src` 完全相同，为 `2a98e2d94bf6d0cfcf62f64e830845a3919a9cb461719b81ae5f152031be30b1`。包括有限原生参数验证、真实 `loc.gg === target && player === true` 身份准入，以及 release 的 RGB/alpha 两组所有权恢复。**不可换回 recovery-aura 初稿 539056…**，它缺少后继恢复修正。
3. `rconnect/game/PlayerBodyEffects.as`：offline1 与 574D 同为 `94aaa38d7dac7a8dbfa70d0aaf63002988b4cf26a4435ab9aad09c857339af42`；新文件与 recovery21、`experimental/recovery-aura/src` 完全相同，为 `11260028854167d8bd0c9f7e806e23081204dd0386902fdf746ba8e10485ccbd`。`apply` 新增默认 false 的第四参数 nativeGrip；只有真正被本机 Q 抓住的队友根显示对象让出染色和透明度，敌人路径与身体子效果不改。
4. `rconnect/game/GameBridge.as`：offline1 为 `c6b8aba21735ce4becb9c6ac398f4024b15bb02694386c51159bb667144cb4aa`。新文件为 `df23182fdd362fba529b962220329bd60499efca0ee7c8ea8f2033372e84e192`。独立按字节验证：只把三次 `_bodyEffects.apply` 增加 `peerGrip!=null && peerGrip.locallyHeld(...)` 第四参数，分别是最终 RENDER 的 rec.ghost，以及初次建图和 driveGhost 的 ghost。offline1 对应行 283、1012、1692。其所有离线采集优化字节保留；没有整类覆盖 recovery21。

现有 `RConnectMod` 已创建并注入 `game.peerGrip`；`PeerGrip.locallyHeld`、原生 Q、现有 JSON/二进制消息值支持、RENDER 失效请求都已存在。因此这四类不需要修改宿主、Sandevistan、RV 或增加加载接口。新 presentAura 的 RENDER 优先级 -11000 位于 GameBridge 的 -10000 之后，避免后者同帧重画身体覆盖被抓者光晕。外部测试探针 -30000 在它们之后读最终画面。

## 历史 591 项的实际证据

实际回执为 `build/m52/recovery21-peer-grip-01/result.json`，SHA `41e6a5108afe45ccbe6ade8c68ab7e112f3569a745964d64254905d390e449e3`。原生运行目录为 `build/cooperation/d460ff8f14`，`run.json` SHA `56ec56a96cc15931aa7495c783a8d6d8fae5429199c5879c094480e663f0e644`。

此次独立审查重新读取两侧原始日志计数，主侧 296/0、加入侧 295/0，各 0—15 共 16 轮，双方 DONE；与回执逐项相同。逐一核对回执列出的所有日志哈希、run/input 收据链、保留 candidate 产品、冻结驱动的全部 inputs/files，全部一致。历史运行只清理自身 host/join/frozen 副本，原日志、图片、收据仍在。

覆盖八种情况且交换施法侧：禁抓、不挣扎、WASD 挣扎、撤销许可、E 抛出、共享暂停、reset、原生换房后返回。检查原生操作、最终 GlowFilter、RGB/alpha、舞台真实像素贡献及清理。`functional_only=true`、`performance_qualified=false`，不证明密集场景或加载性能。

历史宿主是当前相同的 BEFC；但历史 RV 是 **7852F61E**，当前是 **83D8**。不能以历史实机通过代替 aura1 + 当前全模组组合复验。旧 `recovery-aura/README` 和 `recovery-aura-followup/README` 的“未运行”是各自交付时状态，不是最终证据。

## 图片与组件

原生目录保留 16 张 PNG。既有根报告明确只目检了其中八张：host/join 各 round 1、9 的四张 `raster-with`，以及受抓方 join round 1、host round 9 各自的 `raster-without` 和 `released`。本次确认图片存在并读回全部 16 个哈希；没有谎称本审查重新目检八张。

| 原生目录内图片 | SHA-256 |
|---|---|
| host-presentation-peer-aura-1-raster-with.png | `b32c45214c56a339ef883ef99c4dcfe8cb51a5da17c4e9d436c06c9a61949a1a` |
| host-presentation-peer-aura-9-raster-with.png | `c42cb3e421f30949fcd6cc3ed3f026417ce606a242d3af18471a7b9c1cf098c1` |
| join-presentation-peer-aura-1-raster-with.png | `5cbe73d8555e46710b110e2b40a51b6f39550bcb84da58c7ceaf458f1140d146` |
| join-presentation-peer-aura-9-raster-with.png | `5310d4d98b955013494e026403215426cdaf95b5d47fbbdaac42a491de16e479` |
| join-presentation-peer-aura-1-raster-without.png | `20c159ea2a28b72e6cab8f610ffa9eca6839309cf08bcf65ca10c7a7775c7223` |
| host-presentation-peer-aura-9-raster-without.png | `3a1fe3d4c60449bad49905c54c87245813f8d47406386c8ed57c75e938a97b32` |
| join-presentation-peer-aura-1-released.png | `1561c56c6f51a92d0163d15d3e5c017c27f66a4002b9cb0118a2826aeb647230` |
| host-presentation-peer-aura-9-released.png | `8a2813fed35489cb862b879068762524676ca88a9b55ede0ded541e978926c19` |

后继颜色恢复组件曾真实运行：`build/m52/recovery-aura-component-03/result.json` SHA `376008f95df0dc3343234a0fa9e249646f3c96b949666fff729147ab92bfd363`，59/0；原 `component-result.json` SHA `3696995c32c0e2ebbb0bdeeaf3c8f03072bce9070892e56304af9c46e671e8d7`。本次读回两份并核对真实行数，不采用 README 的声明数量当证据。

## 可复用测试与薄包装

历史冻结驱动目录：`build/m52/recovery21-targeted-drivers-02`，prepared SHA `46f805ebc8fdb5d9657727acb40d5994e4dcfd7f2dd71a7080e9f8ed44eecc01`。其 PeerGrip EffectsDriver 为 `a13ff1ba58580784ec5fd77edc69fb6aaf8b1fd1fe321bb7fe9e9386ea2cbef6`，但它绑定 recovery21，**不能直接改绑定当 aura1 复验**。

当前模板与历史冻结源码逐字一致：PeerGripTestDoc `9cf5f556…da598`、PeerAuraFixture `39f0fec0…fda4c`、EnemyGrabProbe `c80bacf3…c2f46`、PeerThrowDamageTestDoc `950fce4a…a52e9e`。新驱动应重新对准确 aura1 生产声明编译。

本目录 `prepare_drivers.py` SHA `e3a1a284e14945b20f405cec82bf901be9300753f73452eee6c40083e4a9d8bd`：

- 原样导入 `experimental/recovery-tests/prepare.py`（固定 SHA `57adca102…39ac3`），只保留 aura 组件与 PeerGripTestDoc、PeerThrowDamageTestDoc 两原生入口；不改 AS 测试、任何断言或原始 recipe 文件。
- 默认绑定 `build/m52/recovery-aura-offline-01/src`，输出全新 `build/m52/recovery-aura-offline-drivers-01`；原准备器仍负责源码冻结、完整生产声明、框架、原始 manifest、共享测试登记。
- 原五个 compc/mxmlc 调用在同一登记中加自有子进程记录、1 GiB 启动余量、既有 `runtime_memory.wait_owned` 的 512 MiB/300 秒保护、隐藏窗口及 finally 回收。其它命令拒绝，不通过一般 shell 扩展权限。
- 本次仅 AST 检查及 `--check` 准入完成，返回准确 DF0FA0E2；根可加 `--build --registry-wait 900` 执行。没有实际编译或 AIR 结论。

运行可继续使用未经修改的 `experimental/recovery-tests/run.py`：先 `component --component aura`，再分别 `native --entry PeerGripTestDoc` 与 `native --entry PeerThrowDamageTestDoc`，各选独立输出目录。它会重新冻结当前 22 项安装清单并审计实际副本，不把安装值硬锁为 574D。**其 `--control` 参数仍只指向 574D**，不得称为 offline1 同版本对照；如要专门跑 offline1 负例，应另冻结 offline1 驱动绑定，不能改历史回执。

## 风险和剩余门槛

- PeerGrip 16 轮中的 E 是释放/姿态覆盖；仍复用单独 20 情景 PeerThrowDamageTestDoc 检查友方碰撞伤害和关断，不能用光晕通过替代伤害回归。
- TelekinesisVisuals.release 是玩家、敌人、物品共用的颜色恢复逻辑；59 项需在新候选真实组件中复验，尤其原生隐身改变 alpha、新染色覆盖 RGB、替换显示对象和原有滤镜保留。
- 同帧最终像素截图本身有成本，此功能驱动不给性能资格。恢复中的加载、击墙、高速、念力物体及掉落卡顿仍独立开放。
- 纯抓取画面增加每条 hold 包的少量原生滤镜参数及一个 RENDER 回调；未抓取时回调立即返回。不能仅据静态小改认定没有运行代价，也不因此捆绑失败的 receive-pump 或 recovery21 其余改动。
- 新 aura1 仍须根执行新候选同一组合的组件、双向原生、伤害和实际安装复验；本报告仅给最小源码移植及历史证据的独立确认。

记录：尝试在同一 shell 指令中读 SWF 哈希并写一份 JSON 审查回执，被本机 `binary-swf-use-release-pipeline` 护栏拒绝，整条未执行。没有修改护栏或重放该写入；随后完成纯只读核验，并以此纯文字报告保存结果。未产生 `review-evidence.json`。
