# A 合并候选 — 2026-10-19

被测技能：remains-auto-testing / remains-runtime-debug / remains-release-gate 2026-10-19.1；test-report 2026-09-16.1
技能归属：Remains/.agents/skills；C:/Users/hello/.agents/skills/test-report
测试工作区：D:/Program Files/Steam/steamapps/common/Remains/mods/RConnect

## 当前结论

**最新：用户在获知密集性能失败后明确要求“直接部署”，已安装0.2.23-coop-bundle2与保留CS0.8更新的安保本体03。新组合安保432项及安装后普通双侧启动通过。密集性能仍未合格，普通发布审核的旧失败保留；本次是用户明确要求的候选安装。**

本次安装包含安保共享/分别破解、房间切换和投掷物抓取合并修正，保留既有改键/UI。Q因许可过期失败继续暂缓；旧A41不安装，B不变。下方按发生顺序保留早期准备与失败。

## 直接部署回执（17:29开始，安装后检查完成）

- 用户原话“直接部署”，覆盖本次已说明的密集性能发布阻塞；没有修改原性能门槛或将失败改判。新增`deploy_coop_user_candidate.py`限定准确候选、当前CS回执和新安保验证，复用备份、原子替换与失败回滚流程。正常release audit保持原要求，另存`user-deployment-audit.json`。
- 部署时CS刚更新为0.8：根本体A61E、CS B5E8、TDFC0324、WB0BD2。重新基于A61E制备安保03，只定向改Interact、UnitTurret、Bullet；回读确认Interact.move的CS场景偏移保留，MainFE及非代码标签一致。未覆盖CS/TDFC/WB/RV或配置。
- 安保03 SHA `02bfabe6a3b4881dfa1227515e71f2a8ea863d4b1b468fbe1d8008aeba7d9240`，prepared `04f8fc1d6b040c67316f9c24ec3d20018afce25806ed8ff9f2aee50963663060`。RConnect为下方准确04的574D原字节。
- 新组合安保`0067bdfd6f`主255/0、加177/0；双方完成、异常0、退出0、安装未变。run SHA `e86f205b3ba7a8df0a30a2e5543b6dcc99d5f398cc62aed0beb7aff7fcaed308`，结果`build/m52/coop-bundle-rebase-security-01/result.json`。
- 已备份并安装两份文件；回执`build/m52/coop-bundle-04/deployment.json`状态`deployed-smoke-passed`。从实际安装文件普通加载双侧`6e43008d5b`通过，新版标记、连接、单位同步、tick200、严格无异常及输入指纹核对通过，无外部测试驱动。run SHA `98adc4fd26a29d8785c077460da07458be75345b64800a6e164ba48752a50647`。
- 备份位于`build/backup/coop-bundle-20261019-172958-fae2b2`：`pfe.before.swf`为A61E，`RConnectMod.before.swf`为A02E。回退须先核对目标仍是本次02BF/574D，再恢复这两份并重启；若后续会话又改过，先合并而非盲目覆盖。此次未触发实际回滚。
- 旧23类2498项属于旧CS/WB组合，新组合额外验证范围为安保与正式启动，不能称全24类重新通过。密集卡顿仍待优化。技能报告复用本文件，保持既有台账条目；用户指令覆盖这次性能阻塞，不改技能或授权表。

- 新生产`build/m52/coop-bundle-04`，`0.2.23-coop-bundle2`，186052字节，SHA `574d2b51490ae8b25a1396555600f56a301f8a20ae50104c0e35cf2796441afe`；prepared `4d0743b2fdd61586b22193c431e5d5fba534d77ca33e0bc5483b2f286ae112b1`。
- 新驱动`coop-bundle-drivers-03`，exec26664退出0，prepared `337d441b64021b2c0b4d233c749d8224eb9192e42a6ccd958f0b96298eaec092`。准确04安保`351dbd7262`主255/0、加177/0通过，严格异常0，安装未变；run SHA `c76571cd52582c24ee96ab51b143cdd3e5409943c07a4508debc8e71d81bc22c`。
- functional-03抓投`fcee59d6c2`失败：主50/8、加50/6，双方各9条场景结果、均无done，240秒外层限结束；不是完成10轮通过。所有抓取者minMana10000，host投酸弹round6加入侧仅抓到1帧，收到ineligible/retired，源端无持有/冲量。run SHA `d4530dcff80360271a9489ec6c488766f376e30595b2810e4bef11efc1ff4d71`。安装未变，内存未触发压力停止，95800/35680已退出，后续分房/换图未启动。
- RV主线程按用户新要求已合并并安装v0.32.3-stair-performance，准确 `76314b819151fba6f67f6d740b21030a9eec8359af4c9c9ddeb83d4caf5c46b7`，本会话核对安装文件与部署receipt一致。299项为RV所有者实测，正式冒烟通过；严格像素18/8、4/4残差仍保留。回执`mods/RealisticVision/build/stair-shadow-output/merged-v0323/deployment/receipt.json`，旧DECCA备份见该回执。当前RV已交回窗口，后续RConnect验证采用76314B，不把旧DECCA回执混作最终组合通过。
- 只增日志探针`coop-bundle-grip-probe-01` / `3f1edd34bf6b583f31f7785e15cd2993aab2be8952b57b5d1b6f4ba86d4495f1`，标记diagnostic_only禁止部署；`0d3d8971f3`已10回合done，但主55/9、加59/5失败，run SHA `96b4ecf78e88fd20f65d5f2f19eca4f7b87888c8f29a1362fddec3c9c549f608`。原生telePorog从夹具0恢复0.1，手雷mass=0.1，teleSqrtMassa=0/dmana=0、god=false，符合“轻物免费”；其他模组定期setParameters可覆盖派生字段。酸弹round6本次接受抓取，源端只1帧且minDx0、无光晕/抛出；该问题未结案，不能用别轮通过抹除。
- 探针02 `c67eaa0cc730fe20112d5aee8b76b71ee29b19679ae93650578860914072d3d7`及对应驱动已编译退出0；生产只新增接受/结束位置与生命周期日志，仍禁止部署。夹具只在原before步骤维持原本设定的telePorog=0，保留所有断言、Q/E输入、引信和物理规则。等待(2)完成已获准的Music去重后运行；共用runner未修改。
- 探针02随后`daff027fef`十回合完成、主64/0加64/0，严格异常0；run SHA `ef22331bc09e5f3a6996950aa4623e9464b1cb0f0362a35e3a47bb1e07858bcd`。耗蓝实测每帧0.695701085237、20帧后9986.085978；酸弹接受时源X534.219/Y236.010/liv54/dx15.439，随后反向拉回并抛出。旧酸弹失败仍保留，没有据此宣称稳定或改判。
- `bind_coop_grip_fixture.py`将仅夹具修正绑定回准确生产04，生成`coop-bundle-drivers-04`；逐行确认所有原check断言相同、其余23驱动未变。`functional-04`正在RV76314B基线上顺序重测四核心，安保`e9984441d9`432/0、exit0、异常0、安装未变，run SHA `fc305ec4ff389d5ef0b4f5f93f5459c169de48c10c8edb327a2a415769508ebd`；抓投随后开始。
- (2)重复Music清理已完成并交回窗口，提交ec95039；其verified.json记录2590路径与内容不变、53原回执不变，净释放10.86GiB。详见`state/music-storage-cleanup-2026-10-19.md`。新runner补丁仅候选、未应用，不改变本轮运行器指纹。
- `functional-04`四项全部完成：security `e9984441d9`432/0，projectile-grip `803ae287c4`128/0，entry-room `db28b8f327`69/0，entry-map `e43bbae44b`36/0，共665项；exit0、done、严格异常0、安装未变。分房join等待/就绪PNG已目检；原生travel352–759ms仍有加载成本，不称性能消失。驱动04 prepared `4fca8838c40d7e406956b9d350896a7c9e2f7523b7a9a37f1a247f5e934002eb`。
- `performance-01`：continuity `1d84ef56c9`51/0；density `bf9b92cd9d`主25/0、加48/2，七窗帧65/55/87/143/117/106/125，P95ms170/226/169/105/123/131/123，前两窗红。原80帧/8s、P95<200ms未改。
- A41组件audit再次通过4859比较和38像素对后，仅隔离覆盖WB的`performance-wb-01`：continuity `08f4832d83`51/0；density `f621c119ba`主25/0、加48/2，帧110/124/124/74/82/108/116、P95ms139/114/128/221/189/148/151。第4窗maxFrame1502ms/maxPacket1579ms，帧门槛与收包各1红。均done/安装不变；不归因给某一模组、不把单轮均值或组件通过称为密集合格。A41不安装，已通知(3)。
- `regression-01`采用准确04/driver04/实际安装WB DF9/RV76314B，继续terrain、throw、saved-grip、timeline、late-pause、pause-timing、pause-repaint、targets、animation、behavior、room、respawn、pause、vision-api、hud、navigation、codec、weapon-batch共18类，失败即停。普通加载冒烟与发布审核仍未完成。
- 前12类实测均退出0、双侧done、严格异常0、安装不变：terrain198、throw97、saved-grip49、timeline50、late-pause98、pause-timing155、pause-repaint103、targets10、animation27、behavior43、room64、respawn27，共921项。准确运行编号/原始指纹由`regression-01/result.json`逐项保存。
- `targets`运行`2a9fa15acc`实际标记1856像素与暂停图不符0；三张PNG及源指纹已复制到该运行的evidence目录，暂停图/参考图已目检。仅证明目标区域最终落位，不把截图当帧率证据。
- 原完整MEMORY压缩写入因正文路径被本地护栏判为二进制部署而拒绝，未执行、未改护栏、未换工具重试。随后只更正入口首段过时状态，详细当前证据保留本记录。
- `regression-01`最终18类共1782项全部通过、exec32261退出0：后六类pause438、vision-api82、hud176、navigation55、codec50、weapon-batch60。加四核心665及连续性51，共23类2498项；不包含密集的失败断言，也不把组件A41对照重复计入。
- `prepare_coop_density_profile.py`仅编译原有ProjectileProfileTestDoc，正式候选和所有门槛未变。独立诊断驱动标记diagnostic_only，入口与正式density不同，不能用于发布审核；该运行是定位新证据，不是重跑筛绿灯。
- 正常权限诊断`fdc875f726`双侧done，生产字节/安装不变；主2023、加1367个CPU样本。主Session/onTick含子调用1009、编码pack409；加onMirrorFrame368、WB301、RV189、Weapon.animate152。采样仅部分帧/阶段，包含子调用不可相加，不能当总CPU或FPS收益。完整栈与计数保留，摘要`coop-bundle-density-profile-02/profile-summary.json`。
- 诊断包装器把JSON分配统计中的24个ReferenceError类名也匹配成错误；这是分配元数据，并非24次游戏弹窗。原回执不修改，诊断本身仍有8项真实性能断言失败，不能改判通过。
- 普通加载`d08438551d`双侧版本/连接/世界同步/200tick、严格异常0、安装不变，exec85044退出0，run SHA `c23c3783685f00cbae8453aaa88ad139f9d0597097009d440bde14f1810454b9`。无外置功能驱动。
- 汇总`coop-bundle-04/regression-summary-01.json`、最终选择`evidence-01.json`；实际执行发布audit在第58行失败断言拒绝（退出1），日志/回执`release-audit-attempt-01.*`。没有生成通过的release-audit，没有执行deploy/备份替换。阻塞是密集性能，不是授权或未跑普通加载。
- bundle1 Q重测`0e8b793543`26场景完成：主91/1、加84/3，加入侧on-peer round5未施法。只增加日志的探针`1f9f874816`主88/4、加83/4，准确探针SHA `2f93b408…6340f0`；松键前有效许可age主768ms/加597ms，均超过原350ms而拒绝。另有非成功场景before341/after373ms的边界记录，不能混称on-peer失败原因。
- 因此Q暂缓安装，没有放宽TTL或取消拒绝条件。探针禁止部署，旧红完整保留。已成功向(4)发送证据交接，明确无需新AIR或新工作。用户又回复释放内存后继续实测；本会话会按实际余量继续，无需重复问授权。

以下为bundle1准备与失败经过，最终安装目标以上述bundle2为准。

历史启动阻塞：编译完成后40秒六次采样，可提交余量约2.65–3.31GiB，均低于6GiB启动门槛；此前一次1.54GiB。没有为本候选启动AIR，未关闭或调整其他程序。非本会话的AIR 9108于13:46出现，随后自行退出。已异步请用户释放内存后回复继续实测。

最新：内存恢复6.71GiB后，functional-01安保cbc9d5de79通过主255/0、加177/0共432项，安装无变化。Q轮2b0cb7e2c9主7/1、加8/1，准备首场景超时。日志证明host准备发生于seal2之前，join在begin房布置后才travel，夹具抢在共同换图完成前执行；die动画标签也出现在旧成功轮，不能据此断言实际死亡。旧失败保留。prepare_coop_port_fixture.py在drivers02只改Q的就绪条件与带room/epoch/term的握手，所有玩法断言保留，新增场景就绪断言；其余24驱动及生产字节不变。functional-02正在重测Q及未跑三类，结果待回。用户已获告知无需继续释放内存。

## 冻结产物

- 生产 `build/m52/coop-bundle-03`，版本 `0.2.23-coop-bundle1`。
- SWF `267994640b29041296ea1606b249ba5f9ae80136a52fe450ca77cbad8e043307`，190119字节。
- prepared `15c757a1f7a3ab58f4a1d6510d6b1cbd5894bd1667e0cc9b6b3df5495a7703c9`。
- 驱动 `build/m52/coop-bundle-drivers-01`，prepared `e459a183fbda6daedf5638e664e1da0299089729ab91126173bd56c77f82f31c`。25类全部编译退出0，保留compile.log、源和产物清单。
- 配套本体 `build/m52/security-native-02/pfe.swf`，`a8403f65d20b11daae3b9a8bc08951ea53b7c7d6c9d6f7b4fa941372094a4ca1`，仅三类定向补丁，原加载器与非代码资源保持。

从安装A39 A02E基线合并：security-terminals-10 CB94（共享/分别破解、切换保留权限、Area/Trap修复）；a22-room-entry-04 1C451（加载层与场景就绪、保留最终伤害回执）；peer-vision-port-07 BF6A（队友视野Q传送，默认关）；peer-projectile-grip-04 CCF8（双向抓投投掷物）。

`prepare_coop_bundle.py`核对四份冻结源，三方合并共用文件。Config保留两个开关；ProjectileGrip初始化沿原精确变换；Q带入两份编译声明与构建入口。保留A39改键/UI/用户设置。01/02为静态冲突失败，只有03无冲突并编译成功。

`check_coop_bundle.py`复用冻结夹具：新增5类（安保、Q、投掷物、分房、整图）+既有20类回归，不修改断言。驱动与正式SWF分开，检查实际版本、输入、退出、完成标记、错误和安装变化，失败即停。各来源以前单独通过不代替新组合通过。

## 护栏与编译记录

第一条隔离编译被本地护栏拒绝。用户明确批准此会话、最长10分钟、此条调用的授权表维护。登记正文因引用SWF路径也被拒，后从原会话记录只读核对摘要，仅登记摘要，未修改或关闭护栏。

精确摘要 `f3c05c9553db2acf1b7ee40ea7026df8a94ceb3cf99acaf69d2ef0319c33bc1c`，8分钟有效。原命令通过护栏但SDK相对路径导致编译失败；立即撤销本条授权，保留其他条目。失败日志保留在生产候选compile.log。改用绝对SDK路径的正常构建退出0（exec49663）；源未改变，未扩大或复用授权。

## 其他会话交接

- RV已由所有者独立安装v0.32.2，`decca3e0e1142eb8faf7e0e776f2b94fc67dce1c5503de7fba7b810c4a0b10ca`。交接b9a4f8a，`mods/RealisticVision/state/deployment-v0322-2026-10-19.md`。新组合以此为基线，不回退旧D29。
- RV阶梯交接902282d：唯一生产变化RVWallSurface.contourRole剩余高度判断。299功能通过、8组黑条消除；严格参考像素18/8、隔离4/4及其合成取整解释仍完整记录。当前组合先用DECCA；后续必须将窄修复合入新生产源并验证新字节，不能安装旧325A整包。对方已确认此安排、无后续AIR。报告在该模组knowledge/experiments/2026-10-19-stair-shadow.md。
- WB A41 `27144730…e04a8`组件通过，联合密集80帧/8秒、P95<200ms及首次掉落≤85ms未在本组合通过，暂不部署。保留“原门槛合格后部署”条件。
- B190/B195不变。旧密集性能/掉落红项不因新功能编译通过而消除。

## 历史接续说明（当前以顶部结论为准）

内存稳定≥6GiB后核对测试争用，运行上述准确驱动。可先隔离测试A41密集/连续性决定是否纳入，最终组合仍须新增5类+既有20类、普通加载冒烟。原始内存采样为驱动目录memory-readiness-01.json。

安装前核对仍为A39/本体2A466/RV DECCA/WB DF9；如他人有更新先保留其改动。生成独立备份、定向安装，安装后普通加载冒烟失败则回滚本次改动。旧release_a22_motion.py源集合/单SWF部署不支持此合并版，不能直接调用。

当前没有创建重复游戏素材，无需删除唯一证据；安装授权已具备，当前待测试而非待授权。

## 本轮技能实战回流

- 自然采用2026-10-19.1测试/调试/发布技能：独立应用身份和存储、冻结输入、双侧日志及退出状态、严格异常扫描、失败即停、发布前重新核对安装。专用双人驱动延续既有流程，没有把单实例调试器替代双侧场景。
- 技能指纹：auto-testing `2b4c0eb3a1c6ea4b79764592a1e51484fab61cfe52ad38bb9ad82cb51656a5c2`；runtime-debug `5ff26d51c00a14fc4331f6a04a5c1ee2b03ccbd8bd37dd8124c145ad8e8a95b0`；release-gate `2d6030bc3311400fdb4301e7708e45357ff7dd66f1c86c9298c3914100c6db02`。
- 功能结果和性能资格分开；发布授权已具备，但密集红项阻止安装。没有执行本次备份替换或安装后回滚，不能声称验证了完整发布/回滚流程。测试输入、计数和原始指纹见上方运行记录及`regression-summary-01.json`。
- 受限运行`6a2bdedfb9`创建两份自有AIR，却无业务日志；退出后的原生输出多处#3003，初始化未完成。MEMORY第7节已有正常桌面权限要求，本次初次诊断调用未遵循，属于执行偏差，不是新算法故障或技能缺口。只结束已核对PID及唯一运行目录的自有进程；安装未变。正常权限`fdc875f726`完整结束并写出日志，旧失败保留。
- 已有方法参考[KB-000071](D:/活/总控/知识库/条目/KB-000071.md)、[KB-000056](D:/活/总控/知识库/条目/KB-000056.md)，本轮未改变任何进程QoS/优先级；不能凭窗口可见或单次长帧归因。当前环境结论待正常权限对照完成。
- 报告复用本文件，不逐调用建档；技能验证状态由维护侧核对，尚未宣称技能全面通过。已查重追加全局台账并回读确认，状态待吸收。
