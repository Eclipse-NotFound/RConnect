# 开阔走廊夹具：独立静态审核

2026-10-22。仅阅读准确冻结 `recovery-density-corridor-drivers-01` 及其源码、固定夹具03、BEFC导出的 Bullet/World/Grafon 和原版 Weapon/Unit/Tile。没有运行 JVM/AIR，没有修改作者目录或生产；本报告不是性能通过。

## 应先修：宿主80本体会留在旧显示层

`CorridorFixture.apply:75` 在80个演员与本机玩家均 `disabled=true` 时调用 `world.redrawLoc()`。准确BEFC `World:1102–1108 → Grafon.drawLoc:3887 → drawAllObjs:3920–3934` 替换所有 `visObjs` 层，然后逐对象 `addVisual()`。原生 `Unit.addVisual:2873–2875` 遇 disabled 直接返回，连 childObjs 枪械也不会重新挂回。`DensityFixture.place` 只定位，不重新挂载。

RConnect recovery12 `GameBridge:287–314` 的脱离stage补挂位于 `if(!_mirroring)return` 之后，宿主不走该路径。夹具 readiness 只查 in_chain、身份、位置和地形，没有检查当前显示父层、stage或实际可见性，所以少绘制80本体/枪仍可进入计时。新增独立 `recovery-density-corridor-visualfix` 将只修计时前原生重新挂载及准备断言；冻结01原编译证据保留，不应拿01运行作为密集绘制基线。

## 确认保留的门槛与几何范围

- 独立比对确认主驱动相对固定03**恰好**只有 edits.json 六处插入。frame、RENDER判断及原断言未变；80唯一敌人（1尸鬼/40血翼/39掠夺者）、12 LMG+27只瞄准枪、七个 `>8000ms` 窗口、`frames>=80 && p95<200`、`packets>=20 && maxPacket<900`、`count>packets`、可见移动弹道非零、结束后不追加隐形帧均保留。新增场景不是原随机房性能的等价替代。
- 原生 Weapon:1459、1495–1505 支持角度/速度公式；recoilUp 为 int，NPC LMG recoil5 得到0。Bullet.step:170–205 的分段移动不增加总距离，run:513先排除disabled单位。BEFC Bullet与公共参考确有安保命中补丁差异，但分段/速度/墙体碰撞及disabled过滤相同，不破坏这项几何推导。
- `findCel=false` 确实是让原 forceRot 刺激生效的必要准备差别（Weapon.actions:1067–1092），必须新旧同字节重跑。三步无边界碰撞只在列出的枪口/速度/散布前提内成立。当前只在初始准备检查枪口，不能称已逐发证实整个56秒均在包络内；完整枪口/弹体实测仍待运行。源gun.b总量不是逐弹对应，也不能从三步几何推出对侧会显示三帧。

## 旧快照与其它限定

1. **正常旧宿主快照有顺序屏障。** 宿主先清理实际列表/链和地形，再 send density-prepare；同一TCP链上旧unitsync先于prepare交付。加入侧等到80个真实key后才清理一次。后续 readObjsSnapshot 遍历已清空loc.objs，readNewObjs/readLootSync读实际对象链；progress.capture读已清空bonuses/acts，不会仅因旧身份表存在而自行继续发送被移除物。准备中的status会阻止当前静态物件重新出现。此结论不覆盖独立断线、换房或新的脚本生成。
2. **600ms稳定声明不完全成立（继承问题）。** `prepareDensityTick:410` 不稳时重置时间/签名，但未清除已置true的arenaLocalReady；host随后只要当前ready与缓存remoteReady相同就commit。第一次稳定后发生失效、又恢复同值，可以不等待新的600ms。join收到commit也只查当前ok。当前TCP顺序降低旧包风险，不等于这项计时证明成立。不要声称任意恢复后都已连续稳定600ms。
3. **清空房间产生额外持久terrain流量。** TerrainSync.hostPatch:119–135保留入房base，每包最多128个“相对原房改变”的格子并轮转重复；外部清空地形没有重置这个生产基线。加入侧capture还可能把本次外部清空视为破坏报告。不能为了通过改生产/私有基线；真实准备与测量需记录tilePatch数量/字节，把它当新场景负载，不能把这种额外工作错误归因于弹道本身。600ms并不证明所有轮转格子和报告已发完。
4. **可选profile的诊断标识有遗漏。** `--profile` 的manifest为diagnostic_only=true，但 DENSITY FIXTURE 的diagnostic仅取trajectoryDiag!=null，profile为false。复用audit只看日志该字段，因此两轮同profile驱动可能被标为attribution_allowed=true（performance_qualified仍固定false）。普通入口不受此问题影响；profile只能诊断，不得用于普通性能资格。应以后显式合并manifest诊断标识，不能沿用此误分类。
5. 准备后的status不会继续运行到七个测量窗口；新脚本重建/地形变化没有终场审计。当前场景未找到正常路径会在通过握手后无故重建旧对象，不把这一缺口写成已经发生。已有netAt首样本误计、异步host窗口、Part时变快照的保守比较限制继续保留，不推翻原帧数失败。
