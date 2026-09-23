被测技能：remains-runtime-debug、remains-auto-testing、remains-mod-build、remains-release-gate、remains-swf-patching、remains-mod-memory、remains-knowledge-contribution；diagnosing-bugs、test-report
技能归属：Remains 工作区级及 C:/Users/hello/.agents/skills 用户级
测试工作区：D:/Program Files/Steam/steamapps/common/Remains/mods/RConnect

# M34：敌人开火、机械死亡和加入侧枪械破墙

2026-09-23。用户报告敌人没有开火动画、旋翼机没有死亡动画、加入侧破墙未传到宿主且看不到墙后敌人；补充破墙方式为枪械射击。沿用既有合作功能修复及候选部署授权，仅修改 RConnect；两端测试均为独立副本、新角色和随机 AIR 应用标识，只结束本轮创建的进程。

## 原因与修改

1. 冻结 Unit.step 同时阻断了子武器的 step，旧单位快照没有开火事件。新增 UnitPresentation，宿主逐帧观察成功射击，形成独立递增计数；加入侧播放原生武器 shoot 帧、更新位置和朝向，不调用 attack/actions/step。原生 kol_shoot 在 t_prep 归零后清零，不能直接当持久事件号；结合子弹引用及弹匣变化捕获短促射击。武器随机选择不同则换成宿主对应原生显示，退出时恢复借用状态。
2. 单写 sost 不触发 Unit.die 的显示过程。旋翼机是 `UnitVortex`（中文 text_zh.xml 的 vortex），先前用于复现的 UnitDron 是无马机，两者最终都实测。sost4 死亡转变播放金属碎片及小爆炸并摘除机体、武器和血条；重复快照不重播。没有调用会产生掉落、XP、脚本和伤害的完整 die/expl。其他机械使用同类纯显示效果，特殊 Boss/焚毁效果未穷举。
3. 旧瓦片同步只有宿主下发；加入侧破坏被旧状态覆盖。网格实际为 `space[x][y]`，旧遍历和落点转置；旧状态遗漏 opac，固定前 60 块还会饿死后续变化。新增 TerrainSync：上报原生已接受的耐久损失，宿主通过 hitTile/dieTile 结算并回执；在途预测免受旧包覆盖，回执期间新增伤害保留，重复批次只结算一次，换房丢弃旧批次。碰撞、形状、遮光、贴图和水相关状态一起落位，持续状态分批轮转；HP 单独变化不重绘相机。
4. **墙后无画面还有独立显示原因**：World.redrawLoc / Grafon.drawLoc 换掉图层，被冻结单位的 addVisual 早退，vis.parent 仍指向旧的离树 Sprite。旧检查 parent!=null 会误判已挂接。现在核对 vis.stage 是否仍属于主游戏舞台，失联时重新挂接原生单位和子武器。原生 invis/isVis/alpha 与 M33 共享探索语义保留。

## 验证与失败记录

原始日志、场景 PNG、输入指纹、正式候选副本均保存在 `build/cooperation/<编号>/`；结构化摘要为相邻 `m34-validation-evidence.json`。

| 轮次 | 结果和解释 |
|---|---|
| b50326103c | 旧代码红测 4 PASS / 8 FAIL，复现没有开火帧、机械爆裂/机体移除、转置坐标、加入侧墙体被盖回和墙后像素缺失 |
| e214e890ec | 特效已通过；测试临时造墙后立即开火，观察器尚未取得造墙后的初始状态。给场景准备增加握手等待和开枪前完整墙断言，不把此轮当正式通过 |
| c4bc07160a | 12 PASS / 1 FAIL，两端墙体及 opac 收敛；墙后像素仍为 0 |
| c3dc4c09a2 | 新增回执/批量/房间边界断言全过；21 PASS / 1 FAIL。截图发现敌人位置附近还有原生厚墙，修正为两边通畅走廊 |
| 2eac12cd93 | 发布优化、全模组；23 PASS / 1 FAIL。走廊验证通过但像素仍为 0，定位到 parent 非空而舞台失联；此前厚墙并非全部原因 |
| 285c37d9e8 | 发布优化、全模组专项 **27 PASS / 0 FAIL**。含真正 UnitVortex 与 UnitDron、无本地子弹、重复死亡无新碎片、加入射击破墙；墙后敌人最终场景贡献 2154 像素 |
| b63258d97b | 发布优化、RC+RV 既有合作完整回归 **131 PASS / 0 FAIL**：原生轻机枪/天角兽护盾与 HP、不同护甲、门箱、探索、死亡与退出清理 |
| ded0968377 | **直接加载正式 57505 字节 SWF**，独立驱动、全模组专项 **27 PASS / 0 FAIL**。SHA256 cab160ba…5f549b86，两端 production 输入相同；墙后像素 2154，194 次绘制采样中的峰值，不冒充 194 帧逐帧不缺失 |
| 74fbb372df | 发布优化、全模组 M33 画面回归 **26 PASS / 0 FAIL**。三个敌人实际视口有像素；连续 15 个最终绘制帧缺失 0；两端两包间均 7 个不同位置及动画帧；停止帧与探索差分通过 |

回执/320 块轮转等边界采用独立小型网格测试；真实枪械场景调用原生 Bullet.run，经真实 Session/TCP 到宿主原生 Location.hitTile。两类证据分开，未把模拟网格称为原生联测。没有修改用户存档或操作用户正在玩的实例。

## 正式文件的直接验证方法

新增 `tools/build_effects_driver.py` 与 `tests/harness/`，仅用于隔离副本。测试加载器在主游戏域下创建正式候选的独立域，再让外部驱动继承候选域。驱动用外部 SWC 获取编译声明，运行时调用的 GameBridge/TerrainSync/Session 均来自原封不动的正式候选。

FFDec 检查：正式包 20 个类，不含测试或 fe.* 存根；驱动只有 EffectsTerrainTestDoc、TerrainRegression 两类，不含第二份 RConnect 实现。两端日志、production/hash、driver/hash、harness/hash 一起存证。临时手写 SWC catalog 曾令编译器报 null；改为正常 compc 生成外部声明，声明包不进入运行副本。首次遗漏 AIR_HOME 的构建失败也已修正。正式启动检查仍另走普通加载路径，测试包装器不部署。

## 部署与边界

正式候选 **0.2.6-dev / M34**，57505 字节，SHA256 `cab160ba34ce7c2bedc84c68b9f85a2900811c426b4aeb523a0aa3cf5f549b86`。仅替换 `release/RConnectMod.swf`。

旧 0.2.5 备份：`build/backup/m34-release-20260923-183657-115022/RConnectMod.before.swf`，SHA256 `683f8573e45cfa8b709d683cd5f558eec6f0b82f0c020380e59b7eb352fff2e6`。回滚只复制这一文件回 RConnect release，再正常重启双方；不能恢复旧根游戏而覆盖同期其他模组加载器。完整部署指纹在 `build/m34/deployment.json`。

双方必须完全退出并重新启动，确认 0.2.6-dev。未穷举特殊武器/敌人/Boss、焚毁、长时间全组合战斗；不是稳定重连、公网、三人以上、版本兼容验证。任务/背包/交易未扩展。普通正式路径重启结果在部署回执和本报告末尾登记。

## 技能实战反馈

- 原生动作、网络因果握手、最终场景像素和发布优化设置各自提供不同证据；测试程序认为 visible/parent 正常不能代替实际画面。
- 两端输入继续先冻结再启动。精确正式字节行为验证通过外部驱动完成，避免仅有 debug 行为与 release 启动证据。
- 发布前均完成本轮专项及相关既有回归，再备份单独目标文件。未对共享技能本体作修改。

## 正式路径重启回执

07638f0926：从已部署 release 文件建立独立双实例，双方 0.2.6-dev 初始化、连接、tick200 与单位同步通过，无 COOP FAIL。部署回执状态 deployed-smoke-passed；本轮前后根游戏、loader 清单、其他模组与配置指纹一致。仅用户自己的游戏实例仍需自行正常重启。
