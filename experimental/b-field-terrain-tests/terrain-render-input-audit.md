# frontBmp 同瓦片不同底图：只读输入核对

范围：原生019中 Grafon/Location/Tile 的绘制路径（021保留这些方法原字节），以及 field21 SceneSnapshot/ReplicaScene/TerrainInk。此记录不是根因结论，没有修改产品或断言。

旧失败种子2780491448，房间0:4:0，四轮baseline均为主bc128cd5/加c1a70072；新通过种子1963887932，tWindows、transpFon=true、颜色矩阵单位值，两张相位图均零像素差。新轮裁图只有120×200测试墙有可见前景，墙下两行front/vid均空。这两个事实不能合并成“旧问题已解决”。

## 可验证差异清单

| 输入或条件 | 原生实际用途 | 当前B同步状态 | 固定种子轮如何验证 |
|---|---|---|---|
| 半高地形的物理边界 phY1/phY2 | Grafon.drawKusok 在 zForm≠0 时用真实边界计算材质与边框遮罩的高度、中心；不只读zForm | SceneSnapshot.TILE有zForm，但缺少phX1/phX2/phY1/phY2；Replica仅按字段赋值，不调用Tile.setZForm | 对照PNG差异是否集中在墙下原生地形；对照取证中的tiles[].bounds与zForm。测试墙强制全高，周边尤其是未改动的y=23仍需查。字段相同但bounds不同是直接可证的差异。 |
| 门引用对轮廓的影响 | Location.uslKontur 把 phis==1 **或 door!=null** 视作相连；开门phis=0仍影响邻格边角 | TILE传kont/pont数值，但Replica.drawLoc会再次tileKontur覆盖；door引用没有传递。plainFront只用于选择破墙路径，不提供门轮廓。Replica对象是只读Obj，不会调用Box.initDoor | 对比周边door布尔与kont/pont。若宿主邻格是开门而加入侧无door，重绘边角可能不同；当前夹具清掉y≤22门引用，所以必须实际见到剩余门才算适用。 |
| 房间颜色矩阵的后续变化 | Grafon.drawLoc最后用nloc.cTransform直接变换frontBmp；Location.allon/alloff会替换该矩阵并要求重画 | SceneSnapshot仅full时发送tint，Replica仅换房时应用；NativeFields不传ColorTransform引用。room.color/lightOn/darkness是标量，可变化但不会自动重建矩阵 | 两侧同刻tint数组直接比较；若最初相同、开关电后不同则需要补全对应生命周期。旧失败没有矩阵证据，不能仅凭新轮无色偏推断旧轮由此造成。 |
| 材质和homeStable替换纹理 | Material提供texture/border/floor/mask/filter；drawKusok在homeStable时用alttexture | 材质资源在各端从同一游戏/纹理文件加载，不逐帧回传；homeStable为public Boolean，会由NativeFields传递 | 先查homeStable与实际依赖文件哈希。图片若整片纹理不同，再取材质资源指纹；不因房间随机就假设同一个材质随机变化。 |
| 其他瓦片及相邻格 | front、vid/vid2、vRear/v2Rear决定前/后层；phis/back/shelf/door决定邻接轮廓；zForm还影响floorMask位置 | front/vid/rear/phis/back/shelf/kont/pont等均在TILE中。drawLoc仍按整房相邻格重新算轮廓 | 不能只看15块测试墙。现取证已含整个248×328区域周边字段；首先找PNG差异框，再比对应格和四周一圈。若差异触及裁图边缘，需下一次有界多取一格。 |
| 像素修改历史与重画代次 | drawLoc先清空并重建frontBmp，结束调用ink reset；弹孔/爆炸/魔法墙另外直接写位图 | TerrainInk以Grafon为键，reset清空旧块并增加epoch；后续修改只回传覆盖的64px最终像素块。它不回传整个基础底图 | 若baseline已不同，则先追基础绘制；局部破坏块可同步正确而区域其余底图仍不同。若只death后不同，再检查不同像素是否位于被回传区块之外或epoch变更之后。 |
| 生成随机与绘制随机 | Land仍有Math.random分支，固定layout seed未覆盖所有内容；普通drawLoc/drawKusok本体无Math.random。dyrka/孔洞绘制会选随机帧/旋转 | 不要求两侧各自重抽相同弹孔：由TerrainInk传宿主最终像素。基础瓦片的符号/材质选择来自host fields | 固定种子后先确认实际房间、baseline旧hash是否复现。不能把任意随机房间通过当关闭；也不能把存在Math.random泛化成普通材质绘制必然不确定。 |

## 已排除或需分清的条件

- `backwall`、`backform`、`transpFon`、`darkness`主要作用于backBmp/backBmp2、阴影和颜色覆盖层，不直接决定frontBmp的普通材质纹理。新轮tWindows是场景标识线索，不是独立解释。`backwall==sky`还会影响背景轮廓判定，所以仍记录。
- `black`、visi/t_visi影响lightBmp，视野遮罩不烘焙进frontBmp。不能将本机视野不同直接解释为本次原始位图不同。
- mirror在原生房间解码时影响瓦片/物件；前景重画使用已解码格子，不会因为mirror标量不同就自动镜像整张frontBmp。测试夹具已设mirror=false，两端仍需比较实际格子。
- isRebuild/isRecalc/isRelight等是本机调度标记，NativeFields有意排除。原生Location.rebuild只推进水体重新计算，并不等于Grafon.drawLoc。判断是否真重画应看TerrainInk epoch/terrainRedraws和像素，而非仅比较isRebuild。
- 这次完整取证已核对双方采样world.loc、room.grafon、grafon.loc身份一致，sourceTick/displayTick相同；新轮图片与区块均相同。旧轮只有房间/tick一致，没有旧图层身份采样，不把新证据倒推给旧轮。

## 源码锚点

- `build/ab/native-hooks-019/verified/scripts/fe/graph/Grafon.as`：drawLoc387；tileKontur477；front颜色633；ink reset701；setMCT782；drawKusok803；homeStable827；zForm真实边界868–884；随机孔洞1308/1317；gwall1349。
- `build/ab/native-hooks-019/verified/scripts/fe/loc/Location.as`：tileKontur2407；uslKontur2493；uslPontur2502；uslBontur2511；rebuild2620；allon2939/alloff2971。
- `game-reference/decompiled/1.02/src102/scripts/fe/loc/Box.as`：initDoor651、setDoor679；开门不清门引用。
- `build/ab/b190-field21-build/src/authority/SceneSnapshot.as`：TILE14；ink41；full tint58；plainFront74。
- `build/ab/b190-field21-build/src/authority/ReplicaScene.as`：换房颜色86；循环瓦片并重画103–137；applyObject238–256构造只读Obj。
- `build/ab/b190-field21-build/src/authority/NativeFields.as`：SCALARS12，ROOM14；ColorTransform不是标量。
- `build/ab/b190-field21-build/src/authority/TerrainInk.as`：reset25–27，snapshot42–58，apply89以后。

当前优先级按可观测性安排：固定失败seed → 对照PNG差异框 → 对照该框周边bounds/门/轮廓/颜色 → 再决定是否需要产品修复。静态缺口是可检验条件，不是对旧失败的归因。
