# 旧 574D 密集场景采样复核

2026-10-21。只读分析 `build/m52/recovery-density-profile-02`，未编辑生产、未启动测试。它是**旧版热点调查，不是 recovery-01 的性能结果**。

## 来源和统计口径

- 候选：`0.2.23-coop-bundle2`，`574d2b51490ae8b25a1396555600f56a301f8a20ae50104c0e35cf2796441afe`。隔离运行 `build/cooperation/c39f372c37` 的 candidate.swf 和两侧版本日志吻合。运行签名中的 `d52e…1086` 是测试加载器，不是生产候选指纹。
- [摘要](../../build/m52/recovery-density-profile-02/result.json)、[运行日志](../../build/m52/recovery-density-profile-02/runner.log)。原始 host.log / join.log 的 SHA 与摘要吻合；安装、运行脚本、AIR 占用检查均未变化，未因内存或其他 AIR 实例停止。采样期间可提交余量约 5.26–9.69 GiB。
- 冻结驱动：`build/m52/coop-bundle-density-profile-drivers-01`，prepared.json SHA `571be8d5…9454c`；其 `SustainedDensityTestDoc.as` 和 `ProjectileProfileTestDoc.as` 与清单吻合。`diagnostic_only=true`，仅阶段 0、1、5、6 的每第五帧取样，每阶段六帧。两侧各 **24 个 CPU 采样窗口**；其余 419/326 条帧记录没有 CPU 堆栈，不能混入分母。
- 主侧 2,045、加入侧 1,373 个 CPU 栈样本。下文百分比是“含该调用链的样本数 / 该侧样本总数”，**包含子调用且可以重叠，不能相加或当独占 CPU 百分比**。CPU 样本与分配/释放样本已分开。采样器本身及统计输出会干扰时序；这些 FPS、p95 不能用于发布验收或与未采样轮直接比较。

## 真实失败与误收日志

`result.json` 主侧 errors 的唯一一项、加入侧 errors 的最后一项都是巨型 `PROJECTILE PROFILE` JSON，分别约 525 KB、323 KB。冻结运行器 `run_coop_regression.py:385` 在整行搜索 `ReferenceError` 等词，将 JSON 分配表中的类名当成报错；两侧各采到 24 次该类型分配。**分配类型不是未捕获异常；也不能据此断言异常开销不存在。** 本复核未打印或复制巨型行。

剔除这两条结构化采样数据后，主侧没有错误行；加入侧有 **7 次真实 `COOP FAIL network-state 80 enemies keep stage frames progressing`**，对应七个阶段。冻结驱动判据是每约 8 秒 `frames >= 80 && p95 < 200 ms`；本轮为 40–53 帧、p95 232–336 ms。它们是真实断言失败，但受诊断采样影响，不能当正常游玩帧率。快照继续到达、武器瞄准推进、后六阶段可用轨迹/移动弹体等断言通过；没有其他独立的 Error #、TypeError、ReferenceError 或 uncaught 行。结果仍为 FAIL，不能因为误收已解释就改判 PASS。

后续解析应先识别并解析 `PROJECTILE PROFILE` 的独立记录，再扫描真正错误记录；不能全局忽略 `ReferenceError`。本次未改运行器。

## 实际热点

| 调用链 | 主侧样本 | 加入侧样本 | 含义 |
|---|---:|---:|---|
| RConnect 任意调用 | 1,197 / 58.5% | 682 / 49.7% | 包括 RConnect 调用 RV 探索接口的开销 |
| BinaryMessageCodec | 378 / 18.5% | 6 / 0.4% | 主侧 copy 243，pack/writeObject 路径 135 |
| WallImpactVisuals | 191 / 9.3% | 5 / 0.4% | 主侧 packed 路径 160，含 RoomCodec JSON/压缩 |
| UnitPresentation | 177 / 8.7% | 142 / 10.3% | 主侧采集；加入侧播放，包含下行重叠 |
| tickFrozenAnims | 0 | 287 / 20.9% | 加入侧每帧镜像、原生动画、命中接收体更新 |
| WallBlend | 283 / 13.8% | 299 / 21.8% | BackgroundBlendLayer 为主，含 join/gridKey/syncDamage |
| RealisticVision | 280 / 13.7% | 195 / 14.2% | 含 RC 发起的 captureExploration：103 / 5.0%、87 / 6.3% |
| TDFC | 51 / 2.5% | 98 / 7.1% | GameBridge.snapshot / TdfcRuntime，不是 RC 同名类 |

加入侧 `RemoteMotion` 84 样本（6.1%）；`UnitPresentation.play` 69（5.0%），其中存在 `gotoAndPlay → constructChildren`。主侧 `readEnemyMotion` 109（5.3%）、`observeWeapon` 59（2.9%）、`GameBridge.probeOptional` 139（6.8%）。加入侧 `captureUnitDamage` 48（3.5%）、TerrainSync 30（2.2%）。这些子项与上表重叠。

分配记录也显示频繁临时对象：24 个窗口中，主侧 String 577,962、Object 171,344、Array 62,349；加入侧分别为 408,407、57,450、48,689。Function 分配分别 8,445 / 13,591。它们是被采样的分配计数，**不是存活对象数或泄漏证据**。`[reap]` 出现在两侧约 20% 的栈中，提示应关注分配/回收压力，不能直接写成“GC 占 20%”。

## RConnect 内优先检查的改进

1. **消息构造和编码。** [BinaryMessageCodec.as:17](../../build/m52/coop-bundle-04/src/rconnect/net/BinaryMessageCodec.as:17) 每包先递归复制，再 writeObject；[Session.as:1062](../../build/m52/coop-bundle-04/src/rconnect/core/Session.as:1062) 每约 200 ms 重建全量修复。先测每消息类型的字段数、字节数、重复历史和构造次数，优先避免重复生成/复制未变字段。整数快路已经存在；不可为提速去掉类、循环、大小检查或改变浮点兼容语义。只有一位加入者，本轮没有证据表明“多接收者重复编码”是热点。
2. **墙痕打包。** [WallImpactVisuals.as:231](../../build/m52/coop-bundle-04/src/rconnect/game/WallImpactVisuals.as:231) 已按 revision 缓存 c.wire；不能再次泛称“加缓存”。量每个 cell revision 的 packed 次数、像素词数和压缩时间，确认是在重复工作，还是高射速持续造成真实新变化。可考虑同一原生帧合并重复脏标记/复用有序索引，但保留每个最终变化、快速下发和补发规则。
3. **采集与动态字段读取。** [UnitPresentation.as:49](../../build/m52/coop-bundle-04/src/rconnect/game/UnitPresentation.as:49) 已有按 owner 的批量历史武器索引及每帧一次弹链索引。尚有 weaponList 复制、重复字段探测及最终 RENDER 再观察。适合在同一次采集中复用列表/已知字段值；已知原生字段可局部走安全直接读，未知模组属性继续保留探测。不能跳过 RENDER 最终点、换枪残留弹体或死亡终态。
4. **加入侧镜像显示。** [GameBridge.as:6319](../../build/m52/coop-bundle-04/src/rconnect/game/GameBridge.as:6319) 与 [UnitPresentation.as:305](../../build/m52/coop-bundle-04/src/rconnect/game/UnitPresentation.as:305) 是首要显示热点。按实体记录每帧采样、重设姿势及实际 clip 启播次数；缓存同一 clip 的标签和已确认姿势，检查伤害采集与上报扫描能否共享同帧结果。现有代码已有闪光重启冷却，采样看到 gotoAndPlay 并不证明它错误地每帧重启；须保留原生射击节奏及有效命中。

## 外模组边界与下一轮判据

WallBlend 的 Array.join/gridKey、RV 的墙轮廓位图更新和 TDFC snapshot 是外模组内部路径；本次没有读取或修改其源码，也未向其他会话发消息。RC 可以先减少自身对外接口的重复调用，但 [ExplorationSync.as:194](../../build/m52/coop-bundle-04/src/rconnect/game/ExplorationSync.as:194) 已有 100 ms 节流、行差分和合并缓存，不能把它描述成“每帧无条件全量发送”。RV 的 `captureExploration` 同时落在 RC 栈中，归因需单独列出，避免重复计数。native `Bullet.run → hitTile → Grafon.decal` 也有 62 个主侧样本（3.0%），不属于 RC 留痕网络打包。

建议先验证 recovery-01 的功能和无采样对照，再以相同输入做少量诊断采样。新候选把普通弹也纳入真实显示帧，可能增加采集、AMF 和分配成本；本轮旧版数据不能证明它更快。验收保留画面连续性、真实命中/墙痕、终态、同 stamp 修正、死亡与暂停，不能通过降频、少绘制或抹去特效换取分数。
