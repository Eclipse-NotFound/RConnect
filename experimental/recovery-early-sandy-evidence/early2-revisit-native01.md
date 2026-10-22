# early-travel2：原生重访卡死修正复核

2026-10-22。根会话运行，独立只读审查。准确候选 `d356483f927c608b5973982558127ce4feb0873a36676909ed3b3d6ac8b7acb3`，输出 `build/m52/recovery-early-exit-native-01`，raw run **`f95499e5a7`**。

**已确认本次重访卡死消失，并且实际重新经过了旧版会失败的“grant到达时exit仍为10”路径。** 三段全部完成，主47／0、加36／0；不是把负例绕到较慢的晚交付路径，也没有放宽原超时／按键断言。

## 实际组合

双侧 `inputs.production` 都是D356。相对原诊断失败轮 `5b404cdea1`，game/assets/harness/modules/mod_assets相同；真正生产候选是唯一改变。外部诊断驱动也相同，RV实际仍为旧7852。非RC配置一致，安装前后未改变。来源审核对应 `early2-revisit-probe01-audit.json`；全部原始TRAVEL RESULT经逐字解析与wrapper rows对等核验，见 `early2-revisit-travel01-audit.json`。

## 旧错误条件的正面对照

加入侧原生重访 grant handler 为本地t47355→49124，结束时 **exit10**。随后观察到原生倒数 **9 → 3 → 0**，当前目的地始终random_mane，与当前Land.act.id一致；不再被回写为rbl。

同一票据完成绘制、Grafon视口完整、创建时世界／Game／玩家／Land／Location／Grafon身份均保持一致。加入侧t52649发出early ready，t52769激活；主侧收到ACK后t89461激活。两进程getTimer原点不同，不直接相减这些数值。

三段的TRAVEL RESULT最终permit均 `held=false, phase=idle`；加入侧重访最后诊断样本也直接显示 `earlyPending=false, busy=false, entryPending=false`。主侧最后一个周期诊断样本早于激活，仍held=true；其随后的TRAVEL RESULT明确已释放，不能只取该周期尾样本误判泄漏。

六次方向键响应与释放的独立检查全部通过。双方最终就绪位置距离依次 **1 / 0 / 1 px**，同房、同种子、同尺寸；原80px门槛保留。

## 时长只作诊断记录

下表各格为本端就绪／统一起点到原生输入响应，单位毫秒：

| 流程 | 主侧 | 加入侧 |
|---|---:|---:|
| 首进 | 10674 / 11762 | 10924 / 11827 |
| 基地 | 2696 / 2879 | 2778 / 3446 |
| 缓存重访 | 6672 / 7593 | 6671 / 7414 |

这是有界诊断轮，没有同候选无诊断单人对照，因此不赋予性能资格。它确认修正了错误的旅行授权清理顺序；仍不能宣称达到单人相应耗时、实际绘制重叠已量化，或此前四项体验问题全部修好。
