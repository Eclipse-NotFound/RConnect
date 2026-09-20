被测技能：remains-runtime-debug、remains-auto-testing、remains-mod-build、remains-release-gate、remains-swf-patching、remains-mod-memory、remains-knowledge-contribution；diagnosing-bugs、resolving-merge-conflicts、test-report
技能归属：Remains 工作区级及 C:/Users/hello/.agents/skills 用户级
测试工作区：D:/Program Files/Steam/steamapps/common/Remains/mods/RConnect

# M32：轻机枪命中反馈与远端护甲

2026-09-20。用户反馈加入方攻击没有伤害数字，双方看到的对方护甲都与本机相同；补充武器为轻机枪、目标为天角兽。沿用候选修复/部署授权，仅修改 RConnect；不操作用户游戏进程和真实存档。M31 共享探索并行完成后，将本轮隔离工作树上的改动合入 e127ab7；部署记录 ed0e38d 保留。

## 复现与修复

- 原生轻机枪 `Weapon.shoot → Bullet.run` 命中镜像天角兽，不指定强制命中对象。红测 9989486af1：子弹伤害 12，护盾 24→12、HP 2000 不变，画面无数字；去除护盾后正常扣血。第一组数字过期后再次射击仍扣血，但不出现数字。
- 原因：原生合并数字的 `hitPart/hitSumm/t_hitPart` 由 `Unit.actions` 清空；M30 的受击器为了不运行 AI，只存在于碰撞表，不执行 actions，缓存指向已离开画面的粒子。现在只关闭受击器的原生数字，保留原生损伤计算，由 `HitFeedback` 管理数字及过期重建；尊重 showHit/showNumbs。独立显示蓝色 `S -数字` 表示护盾消耗，宿主也显示远端造成的护盾消耗；HP 数字不会用护盾量冒充。伤害日志分别写 hp/armor/shield。
- 红测另复现：本机 pip、远端 power，跑动/跳跃后的服装子部件都变回 pip。`Obj.setArmor` 在新动画部件构造时重新读取本机全局状态，构造 visualPlayer 时暂换 Appear 不够。`RemoteArmor` 仅修正远端显示树里带护甲标签的剪辑，在动画构帧后重施远端护甲，并防 EXIT_FRAME 同步重入；宿主和加入方均执行，不依赖敌人镜像模式。本机外观、装备属性不随之改变。
- 颜色、特殊 Boss 伤害、持续效果等不借本次反馈修复扩成全规则重做；原生伤害与 M30 按键回传机制保留。

## 验证与失败记录

| 隔离轮 | 结果与含义 |
|---|---|
| 8dc07990d3 | 32 秒观察窗下仅初始化，尚无测试断言；不能判通过，不据此归因代码故障 |
| 9989486af1 | 68 PASS、3 FAIL：护盾反馈、远端护甲、第二轮数字均为用户问题的红测；短轮未跑完整网络场景 |
| 3df1568fbb | 同场景 71 PASS、0 条失败，三处恢复；短轮缺网络完成标记，整体脚本仍 FAIL，不能写完整回归通过 |
| b6e31786ce | 117 PASS、3 FAIL。新增长射击场景在宿主固定计时检查过早，加入方尚未开始射击；后续日志已显示命中到达。改成等待实际伤害收敛且静置 6 秒，再断言，不把两端 Timer 次数当共同时间 |
| d995672ebb | **122 PASS / 0 FAIL，完整回归 PASS**，实际加载 RV v0.30 配套候选 |
| 6ccefa9187 | 普通 0.2.4 SWF 双实例启动检查 PASS，双方版本、tick 200、连接和单位同步通过 |
| c7ae0ed25a | 从已部署 release 取文件，双实例重启检查 PASS；双方 0.2.4、tick 200、连接和单位同步通过 |

完整回归包括：9 项外观/数字专项，真实双端不同护甲，65 发轻机枪击破 500 护盾再伤害生命，宿主与加入方最终同为 HP 1695.2 / shield 0，收到的宿主最终生命值等于加入方逐次原生命中损伤之和；双方能见护盾数字。同时通过 35 项既有合作、16 项敌人、12 项战斗/动画、22 项共享探索及既有 TCP 门箱/死亡等检查。

正式包 51393 字节，SHA256 `4e65327f3014211b3811e3917d4ff4dd984e9d6d2964c38f0ee21d51996c5262`。FFDec 列出 17 个模组类；无 fe.* 存根、NativeTestGun 或测试文档类。测试类里的 Weapon 子类仅调用原生轻机枪发射并控制测试瞄准、散布和弹量，未给敌人手工扣血替代联机验证。

结构化记录及每轮日志指纹：`m32-validation-evidence.json`。原始日志保存在其中列出的 build 路径；应用 ID 均为本轮随机 `pfe-rconnect-coop-host/join-*`。脚本只结束自己创建的 PID。0.2.4 基于共享探索功能及同期 ModSettings 部署后的根游戏，不覆盖 RV 文件。

## 部署与边界

**0.2.4-dev 已部署并通过重启检查**。正式文件与上述候选完全同哈希。回执及保护文件指纹见 `build/m32/deployment.json`（内容也收入 m32-validation-evidence.json）。上一版备份为 `build/backup/m32-release-20260920-153135-660744/RConnectMod.before.swf`，SHA256 `0e00e4f8f1ba74842b6227b7311ccfd47c4ff3e212afc4132e051e39c3277157`。复制回 release/RConnectMod.swf 并正常重启双方可回到 M31，只恢复 RConnect，保留同期 RV / ModSettings 与共享探索部署。没有独立 changelog，以 README、MEMORY 和 journal 留版本记录。

- 测试覆盖游戏 1.02、同机真实 TCP、普通轻机枪与 alicorn3；为使结算确定，测试敌人 AI 冻结，设置 world.testDam，单独注入完整护盾。未冒充完整野外 AI 或用户具体存档的验收。
- 镜像接收器仍是基础 Unit 普通损伤规则，未复刻所有敌人特殊 damage override、持续伤害/附加状态与特殊击杀效果。HP 数字以实际净损伤显示，未穷举原生暴击文字样式。
- 本轮不验稳定重连、3 人以上、公网、其他游戏版本；未把 RConnect+RV 验收写成全部模组联合作战通过。

## 知识归档与回流

[本次产物] 游戏机制两条分别写入 `shared-knowledge/rendering/discoveries/player-armor-frame-global-state.md` 和 `damage-number-unit-actions-lifetime.md`，带 1.02 适用范围和实测摘要；不把模组状态写入公共库。

[已落盘] `synchronous-exit-frame-during-hit.md` 的重入保护结论本轮继续适用。并行任务的共享脚本版本断言竞争由 M31 部署记录保存；本轮保留其新增的加入侧心跳检查。技能未改。报告台账已追加并回读确认，经验待维护核对；测试初期短观察窗不足不能变成“构建成功即业务通过”。
