# 补充：累计墙痕轮转与缓存工作集

仅核对准确 recovery20（0674019C…CCE9F5）的既有机制；本补充不建立候选、不改频率或协议。源码仍为本目录原报告绑定的冻结文件。

**直接结论：快速 worldstate 只发送改变过的 cell；200ms unitsync 刻意循环发送累计 cell，即使内容未变。现有 128 项缓存不能保证覆盖代码允许的正常工作集，但本轮没有逐包 d/v 或缓存记录，不能认定它实际发生了大量缓存未命中。**

## 怎样轮转

- `GameBridge.readWallPaintUpdates → WallImpactVisuals.updates`（3506；472–488）：枚举当前房间的累计 cells，清除已非实体墙的项；只选 `sent[k]不存在 || cell.v>sent[k]`，按 cell 键的字符串顺序排序，限制64项和48,000个payload字符。未变化且已交给发送器的 cell 不再进快速包。
- Session:1219–1231 在当前房间可同步、为权威且非过渡时把这些变化附到 worldstate；broadcast 后且存在客户端才调用 sentUpdates，记录**已交给发送器**的版本。读取本身不消费游标；没有peer时不记已发送。它不是收件方应用成功的ACK。
- `readWallPaint(false) → snapshot(false)`（GameBridge:3505；WallImpactVisuals:505–520）不参考 sent/incoming，也不按“本轮修改”筛选：每次从 `s.cursor % keys.length` 出发，按已排序键循环装入累计cell，同样64项/48k，然后保存下次起点。房间只有少量cell且总长不超48k时，每份累计快照都会包含全部cell。较多时分批轮转；键集合变化时是新排序表上的位置游标，不是永久cell编号。
- Session:1063 先发快速包，随后到达200ms期限时在 :1088/:1111 发累计包；两类包能包含同一未变化版本。200ms按墙钟到期触发、不追发漏掉的周期，实际负载下不保证精确200ms。
- `packed` :281–285 缓存 cell.wire；只有真实像素变化后清空该缓存、增加版本。因此“再次发未变内容”不等于“发送端再次压缩”。后者能复用字符串；接收端仍进入 decode，命中纯payload缓存则复用已验证值的独立数组。
- 累计重发有既有用途：接收端若仍保护本地预测像素，不推进该cell incoming（:428–430）；其ACK到达后，需要相同权威版本再来完成修复。不能把快包已发送当作累计修复已完成。

## 单房可保留多少；128项意味着什么

cell 是40×40像素的稀疏最新颜色表，并非每个击中事件。一个cell最多1600个像素对，颜色覆盖同offset；停止开火、敌人全灭或ACK均不会删除它。没有按年龄/累计大小淘汰历史cell的规则；每房理论上可到所有被实际改色的实体墙格数，受房间格尺寸与实际画痕范围约束。decode的“单列表不超过1200”是输入/恢复校验，不是运行中 cells 字典的全房容量上限（普通网络批另限64）。

本轮 b3d7b8558b 的已冻结夹具两侧都是48×25＝1200格，其中 **142格为 phis≥1 的实体墙**（独立计数 fixture-audit 的完整 corridor.cells）。故这张固定图允许多于128个墙格被留痕；但142只是可留痕上限，**不是本轮已存142个cell，也不是142种不同payload**。本轮枪口/射线集中，实际 cells 数、各cell像素数和不同 d 的数量尚无日志。

wordCache 是整个 WallImpactVisuals 的纯内容缓存，不按房间/坐标/版本分项；不同cell相同 d 可以共用，相同cell不同 d 则占不同项。它同时受以下三限约束（:31–37、363–373）：

- 最多128个不同payload；
- 最多131,072个数字词，含索引和颜色。若每项填满1600对，则仅能同时保留40项；
- 最多524,288个payload字符。

这是按插入顺序淘汰，缓存命中不刷新顺序；持续新版本、其他房间或本地待确认内容也会占预算。即使当前墙格少于128，也不能仅据数量判断覆盖。可验证的覆盖条件是：再次使用的每种 d 仍驻留，期间新插入项没有触发任何一个预算将其淘汰。举例，142个不同且不变的payload按轮转顺序循环、每个只访问一次、没有其他命中路径时，128项FIFO不足以保住整轮；这是可构造条件，**不是本轮cache miss的测量结论**。

## ACK、房间完成与清理

| 事件 | 既有行为 |
|---|---|
| 普通ACK | 核pending seq，observe最新本地命中；整包解码后清pending并合并，继续保护更新的queued像素；累计cells保留（460–466）。 |
| 房间交接前flush | finishReports排空queued并清pending；原pending已经在有序TCP上发出（309–315）。GameBridge.checkpoint带全房wallPaint；RoomSync保存原房记录（GameBridge:6185–6189；RoomSync:720–756）。 |
| 权威/房间角色交接 | roleChanged清queued/pending/receipts/incoming/sent，轮转cursor归0；保留cells。不会清纯payload缓存（573–576）。 |
| 恢复房间 | restore验证完整列表后替换该房间cells及传输游标，再put/redraw；保留的同房恢复分支可跳过重新导入（532–538；GameBridge:6319）。 |
| 毁墙 | discard清该cell及queued/incoming/sent，避免旧弹痕把墙填回；现有pending后续仍按solid检验（277–279、403）。 |
| 地图对象更换 | GameBridge.onPerceptionFrame检测world.land身份改变即_wall.reset，清所有房间及payload缓存（374–376）。 |
| 断开会话/重连前停止 | Session.stop调用endSession；GameBridge:186–194与WallImpactVisuals:578–583清房间、影像与缓存。不能据此宣称稳定重连功能已验证。 |

rooms使用弱键，但当前地图持有的Location仍可能存活；不能把弱键当作离房即清理。active影像/阴影可换掉，累计cells与房间checkpoint仍保存。payload缓存跨普通房间保留，因仅解码纯数值，房间身份仍由外层检查。

## 若后续记录证实重复很多，哪些现有游标可利用

已有 `sent[k]`（本端交给发送器的版本）、`incoming[k]`（本端无预测跳过而接受的远端版本）、`cursor`（累计轮转位置）、`pending.seq / receipts[peer].seq`（非权威侧改色请求及回执），以及按 d 的已验证字典。**没有“对端已完整接受某个累计cell版本”的现成游标**；sent不能替代它，incoming也只在接收端，且角色切换会清空。

因此后续应先用同房/同term的 `x,y,v,d` 及缓存驻留/淘汰、预测保护和ACK前后记录区分：真新增色值、相同版本重复、相同色值的新版本、累计修复。现有游标足够帮助辨别这些类别，不需要先增加协议；但单靠现有sent/cursor删掉累计重发，或提前忽略incoming旧版本，都不能直接证明保持既有整包校验和ACK后修复语义。此处不新增候选，沿用原报告唯一的二次标量验证冗余建议。
