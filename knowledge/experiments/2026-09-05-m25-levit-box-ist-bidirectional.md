# 实验：M25 念力移动物品同步 + ist 双向——2026-09-05

- 用户报告（真实联机日志诊断）：①宿主侧敌人不在加入方渲染；②念力可移
  动物品不同步；③门状态两侧不同步。

## 诊断（读用户真实日志 %APPDATA%\pfe\pfe2 RConnect.log）

- ①**敌人**：加入方 `injectFail=4`——缺的 4 个 = alicorn1/alicorn2
  （boss 注入构造器 #1009，M17 已知限制）+ hmine/mine（无 AllData unit
  XML，跳过）；**其余敌人在 rbl 27/27、random_mane 2/2 正常渲染**。
  即"敌人不渲染"实际是 boss/地雷类未注入 + removed local extra（宿主
  权威清本地多余，正确行为）。修复：注入失败日志补 `getStackTrace()`
  （用户下次实测即可定位 alicorn 构造器空引用行）；boss 仍记已知限制。
- ②**念力物品**：M16 只同步 Box 的 dead/hp/ist，位置从不同步——念力
  （telekinesis，游戏内 levit/fracLevit/levitPoss 体系）移动的箱子在
  对端原地不动。
- ③**门**：M22 只有宿主→加入方单向；加入方自己开门/开锁/搜刮不上报。

## 实现（M25）

- **Box 位置镜像（宿主→joiner）**：objs 快照带 w（wall）与 q（托举态）；
  joiner 对 door<=0 且 wall<=0 的条目按 **id+就近匹配**（同 id 多箱）落位
  （X/Y/X1/X2/Y1/Y2 手写边界+清速度+runVis；q=true 时 stay=true 抗重力）。
- **joiner 上报（MSG_OBJS 新消息，1Hz 扫描）**：
  - moved：本地 Box 偏离宿主基线 >25px（念力/推挤）→ {id,x,y,q}，
    宿主 matchBoxById 就近强制落位（force，不走偏差保护）；
  - ist：本地 inter open/lock/loot 偏离期望态 → {id,o,l,t,x,y}，宿主
    setAct 官方路径应用 + ever-seen 标记 → 随快照重播全端收敛。
- **本地偏差保护**（镜像侧）：本地已偏离基线 >25px 时不覆写不刷基线
  （否则 5Hz 旧快照 200ms 内把本地移动拽回、上报通道永远发不出——M24
  的 loot 推动路径其实也有此洞，一并修复）；宿主快照与本地一致后自动
  刷新基线防无限重报。
- **稳定性门**（ist 上报侧）：连续 3 次扫描（≈3s）一致才上报——游戏
  自驱循环门（rbl door3 1.4s 周期）各相位撑不过窗口，被自然滤除
  （run2 实测 545 条上报风暴 → run3 起 0 条）。
- **同 id 多实例**：ist 扫描的期望/稳定性按**对象实例**（Dictionary）
  跟踪而非 id——'case' 类通用箱同房多只，id 级互殴使稳定性计数永远
  归零（run6/8 症状，run5 单实例 instr2 恰好通过）；上报附位置，宿主
  id+就近匹配（matchObjByIdPos，含门/墙对象）。

## 验证（双实例 random_mane，run9 终版）

- 宿主移箱 → joiner `box pos synced 'case' -> 1120,870` ✓
- joiner 移箱 → `objs report moved=1` → 宿主 `box move applied 'case'` ✓
- joiner 搜刮容器 → `ist local change 'case' t=2` → `objs report ist=1`
  → 宿主 `ist report applied 'case' o=0 l=0 t=2` ✓（双向 ist 闭环）
- 宿主→joiner lock 镜像（`ist apply lock=13 'wallcab'`）不回退 ✓
- 零错误对话框、零死亡；循环门上报风暴 0 条。

## 遗留与已知限制

- alicorn/mine 类注入仍受限（已加堆栈诊断，待用户实测定位）；念力托举
  的连续动画按 5Hz 落位近似（位置正确、过程不平滑）；joiner 念力持有
  期间宿主镜像自动让位（boxHeldLocally）；同 id 多门（罕见）的宿主→
  joiner ist 应用仍是 first-match（M16 语义）。
- 测试环境注意：新档直接 travelToLand 到基地型土地（rbl/stable_pi，
  tip='base'）会触发游戏侧 buildProb #1009（run3/4），random_mane 稳定。
  M22 时代"开局即 rbl"是 M23 前 newGame 早调失败落回存档的副作用。

## 教训

- **双向同步 = 镜像保护 + 上报通道 + 收敛检测三件套**：只做镜像会把
  本地发起的移动拽回（偏差被吞）；只做上报会来回打架；基线刷新时机
  （宿主快照与本地一致时）是止振关键。
- **按 id 的状态机在同 id 多实例房间必然互殴**——扫描/期望表一律按
  对象实例（Dictionary），上报附位置供对端就近匹配。
- 用户的真实日志（%APPDATA%\<appid>\Local Store\RConnect.log）是最快
  的诊断入口：injectFail/unitsync matched/ist apply 三类行直接定位。
