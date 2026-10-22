# 早期交付：原生冻结接点与状态转移

2026-10-22，只读接口草案；未修改任何生产类。接[方案](early-delivery.md)。源码依据仍为准确E159的World/Game及FD92 Grafon；控制函数另核对公共1.02参考，不冒称已导出准确宿主UnitPlayer/Ctr。

## A. 原生接口只承担三个窄职责

**1. Game完成通知。** 在 `Game.enterToCurLand` 最后一条原生状态工作之后、返回调用者之前，调用已存在 `Game.rconnectTravelBridge` 的新phase `constructed`。参数仅为本机Game和当前World/Land/Location/玩家引用及实际id/seed/sceneMerged；引用不走网络。回调只能在已协商、已开始的共同整图旅行中认领。无RC、未知phase、普通进房，返回null保持原行为。回调不在new Land或sceneOpen入口发出，因为那些位置出生尚未完成。

**2. World受限推进。** 用同一桥增加本机查询 `loadingHold`，只返回仍匹配全部对象身份/代际的已冻结票据，不创建票据。以下是边界示意，不是可直接粘贴实现：

```text
正常原生入口检查和 ctr.step / Snd.step 保留
如果 allStat==1 且（未onPause，或本次有效loadingHold）：
    按原条件推进exitStep（仍尊重17+clickReq==1）
    重新查询loadingHold/onPause  // exitStep可能刚刚constructed并冻结
    只有现在确实允许模拟：执行原Emitter、piEvent、Land.step、死亡、
        SATS.step2、质量重算、自动保存计时等原块
原comLoad/newGame路径保留，但在换档动作之前先取消旧loadingHold
原 allStat>=1 的 cam.calc / gui.step / pip.step / sats.step 保留
有效loadingHold期间不执行打开Pip/背包/技能/地图/SATS的热键分支
```

查询必须仅允许同次构造后的 `0<=t_exit<=19`；`t_die>0`、comLoad开始、ng_wait开始、World/Game/新Land/Location/玩家不符即失效。它不是“onPause也可以正常模拟”。同一帧重新判断不可省：当前原生外层if是在exitStep前选中的，新置onPause不会自动跳过其余语句；否则源checkpoint后还会多跑一次Land.step。

`World.step` 的相机/GUI部分本来就在onPause之外，准确Camera.calc会调用sceneTick，因此保持onPause不会阻止恢复后首屏。反之 `catPause` 不够：准确Land.step即使catPause也会步进scripts，不能用它代替冻结。

**3. 控制放行仍由事务完成决定。** 原生exit16会调用gg.controlOn并把pip.noAct设false。此处仅在有效loadingHold时把这两步记作待放行，不能先controlOn再每帧controlOff：公共原生controlOff会clearAll、dropTeleObj、改invulner和武器visible，多次调用不是纯输入开关。constructed时只执行一次既有handoff释放/控制关闭；结束时按原生controlOn语义恢复一次，且再次检查玩家存活和身份。必要热键按既有清理接口清掉，原生加载点击仍保留，不能吞掉clickReq所需点击。

不应重调setLoadScreen“续时”：它会重置故事/随机图/显示和输入状态。继续使用已有RoomEntryView镜像原生资产；它自身mouseEnabled=false且位于GUI下方，**不能把遮罩当作输入锁**。真正输入锁是上面的控制/热键约束。GUI其他鼠标操作是否能越过pip.noAct/ggControl仍需准确原生组合验证。

## B. RC状态只保留一份当前加载事务

| 状态 | 可做 | 禁止 |
|---|---|---|
| prepared | 原生按既有参数生成；打开当前整图绘制ticket | 不发完整grant，不解除旧房间事务 |
| constructed+frozen | 已完成原生逻辑/出生；结算旧房间末消息；锁定anchor；原生计时继续 | 不执行世界模拟，不对普通worldstate宣称ready |
| grant-fixed | 宿主捕获一次完整状态并固定字节；发原grant；宿主开始首屏 | 不在后续ready重复capture；不因发grant就release |
| restored | 加入侧在精确目标完整restore并定位；开始首屏 | 不借旧Location/同名不同seed；不跳死亡、破墙或掉落 |
| local-native-ready | t_exit真实0、首屏真实ready；加方发原ACK | 不只看t_exit/遮罩，也不跳过用户加载点击 |
| activate | 宿主自身ready且收到本次ACK，发小型activate；各端检查后恢复控制/暂停 | 不允许旧/重复activate触发第二次restore或误解锁新世界 |

每个票据绑定World、Game、gg、旧Land、新Land、Location、目标id+seed+sceneMerged、epoch/barrier及协商能力。沿现有SeedRasterEntry/nativeTravel区分随机/非随机，不另造长期房间表。已有RoomSync.records/owner/term及普通房路径不改；离开旧房间时的最后伤害/开箱/掉落/地形报告须在新checkpoint定稿前照原序结算。只有同一共同目的地允许early-ready，不把它扩到普通分房所有权交接。

`checkpoint()`目前会绑定身份键、观察基线和presentation游标；“只读”只表示接收方暂不激活它，不能在native通知中试采一份又让commit再采一份。应把原本commit的唯一采集移到该票据的冻结点并复用精确字节，不保留第二个过期完整世界。

## C. 取消与失败的明确边界

- **尚未constructed：** 目标/seed/支持能力变化可撤销优化ticket，原生继续走旧完整加载/交接；不能更改原种子选择。
- **已冻结、尚未restore：** 取消先使本次grant/ACK/activate失效；仅对仍由此票据拥有的同World/Game/玩家恢复保存的pause/控制，释放自己的绘图等待，然后进入旧交接或退出联机路径。用户原本暂停不能被强行解除。
- **restore中/失败：** 不能把半恢复世界放行。沿现有同步失败状态保留原生加载提示，停止优化；由现有断开/重新载入流程恢复，不构造另一份世界强盖。
- **换档/死亡/断开：** 在可观察的原生换档动作前取消旧票据。若同World的Game已被外部替换，撤销旧票据且不向新玩家调用旧controlOn；恢复权归新原生流程，不能把旧savedPause盲写到新Game。未知直接替换无法归属时失败关闭优化，需测试明确没有遗留pause锁。
- **普通分房/单边支持/旧协议：** 根本不进入这张票据，保持原commit后本地release、不等对方ACK的行为。新能力必须显式协商；不能给旧端发它不识别的activate后等它解锁。

## D. 当前能拍板与仍未拍板

已能确定：原生UI/相机可在onPause时推进；只允许exitStep的窄分支可避免卡死原生倒计时；Game返回后才有完整出生；同帧Land.step及exit16控制恢复必须另挡。

尚不能仅靠源码保证：所有模组都尊重onPause；GUI鼠标绝无越权；预绘前checkpoint包含的派生Tile字段在双方最终绘制后等价。尤其NativeTileState包含所有可传public标量，不能忽略shelf或随意删kont/pont字段。独立审查/组件及同组合原生反例若证明这些条件不能成立，应停止这条方案，而非继续扩大到通用世界调度框架。

目前足以进入一次**隔离实现的设计审查**，尚不足以承诺收益或部署。最有价值的证伪仍是同一大图三段里：在冻结后故意让peer晚到，原生t_exit和相机继续而对象/脚本状态不动；grant在宿主首chunk前定稿、双侧首绘实际重叠，激活后同出生/完整持久状态和真实输入时限均成立。

## E. 独立只读审查补充

peer_aura_fix于本轮回执确认：FD92 `sceneDrawSteps:2743` / `drawLoc:3691` 会调用 `Location.tileKontur:2399`，该函数只改 `kont1..4/pont1..4`；其原生全fe引用扫描仅见Location写、Grafon读，未发现碰撞消费。region绘图会临时切换backwall等环境字段并finally恢复，但Tile上这8个轮廓值不会回滚，且pont计算受backwall==sky影响。因此早快照的稳定性判据须区分这8个已确认原生派生量与实际世界量，不能要求绘图前后全public字节不变；此结论仍不涵盖其他模组消费者。

同一回执确认：Checkpoint构造的82–83行会写两格shelf，不是addVisual时才写。正常应在Game完整返回前已发生；**shelf不属于上述8字段豁免**。这补充了可验证边界，没有证明本次组合预绘checkpoint已经安全。控制方面，peer同样指出exit16 controlOn和World尾部onPause之外的SATS/菜单键必须约束；本草案已将其作为必要接口，而非可选优化。
