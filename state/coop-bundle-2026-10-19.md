# A 合并候选 — 2026-10-19

## 当前结论

用户已明确要求“请连同其他对话积累的修复一起部署”，包含此前具体预览中的安保配套本体。已有部署授权，不应再问。**尚未部署。当前候选改为不含Q的bundle2：安保、房间切换、投掷物抓取三项合并，生产和24类外置驱动均编译成功，functional-03正在实测。**

- 新生产`build/m52/coop-bundle-04`，`0.2.23-coop-bundle2`，186052字节，SHA `574d2b51490ae8b25a1396555600f56a301f8a20ae50104c0e35cf2796441afe`；prepared `4d0743b2fdd61586b22193c431e5d5fba534d77ca33e0bc5483b2f286ae112b1`。
- 新驱动`coop-bundle-drivers-03`，exec26664退出0，prepared `337d441b64021b2c0b4d233c749d8224eb9192e42a6ccd958f0b96298eaec092`。准确04安保`351dbd7262`主255/0、加177/0通过，严格异常0，安装未变；run SHA `c76571cd52582c24ee96ab51b143cdd3e5409943c07a4508debc8e71d81bc22c`。
- functional-03抓投`fcee59d6c2`失败：主50/8、加50/6，双方各9条场景结果、均无done，240秒外层限结束；不是完成10轮通过。所有抓取者minMana10000，host投酸弹round6加入侧仅抓到1帧，收到ineligible/retired，源端无持有/冲量。run SHA `d4530dcff80360271a9489ec6c488766f376e30595b2810e4bef11efc1ff4d71`。安装未变，内存未触发压力停止，95800/35680已退出，后续分房/换图未启动。
- RV主线程按用户新要求已合并并安装v0.32.3-stair-performance，准确 `76314b819151fba6f67f6d740b21030a9eec8359af4c9c9ddeb83d4caf5c46b7`，本会话核对安装文件与部署receipt一致。299项为RV所有者实测，正式冒烟通过；严格像素18/8、4/4残差仍保留。回执`mods/RealisticVision/build/stair-shadow-output/merged-v0323/deployment/receipt.json`，旧DECCA备份见该回执。当前RV已交回窗口，后续RConnect验证采用76314B，不把旧DECCA回执混作最终组合通过。
- 只增日志探针`coop-bundle-grip-probe-01` / `3f1edd34bf6b583f31f7785e15cd2993aab2be8952b57b5d1b6f4ba86d4495f1`，标记diagnostic_only禁止部署；`0d3d8971f3`已10回合done，但主55/9、加59/5失败，run SHA `96b4ecf78e88fd20f65d5f2f19eca4f7b87888c8f29a1362fddec3c9c549f608`。原生telePorog从夹具0恢复0.1，手雷mass=0.1，teleSqrtMassa=0/dmana=0、god=false，符合“轻物免费”；其他模组定期setParameters可覆盖派生字段。酸弹round6本次接受抓取，源端只1帧且minDx0、无光晕/抛出；该问题未结案，不能用别轮通过抹除。
- 探针02 `c67eaa0cc730fe20112d5aee8b76b71ee29b19679ae93650578860914072d3d7`及对应驱动已编译退出0；生产只新增接受/结束位置与生命周期日志，仍禁止部署。夹具只在原before步骤维持原本设定的telePorog=0，保留所有断言、Q/E输入、引信和物理规则。等待(2)完成已获准的Music去重后运行；共用runner未修改。
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

## 直接接续

内存稳定≥6GiB后核对测试争用，运行上述准确驱动。可先隔离测试A41密集/连续性决定是否纳入，最终组合仍须新增5类+既有20类、普通加载冒烟。原始内存采样为驱动目录memory-readiness-01.json。

安装前核对仍为A39/本体2A466/RV DECCA/WB DF9；如他人有更新先保留其改动。生成独立备份、定向安装，安装后普通加载冒烟失败则回滚本次改动。旧release_a22_motion.py源集合/单SWF部署不支持此合并版，不能直接调用。

当前没有创建重复游戏素材，无需删除唯一证据；安装授权已具备，当前待测试而非待授权。
