# 同一原生房间的灯具首绘图像诊断

仅准备源码，没有编译或启动。基底是已实际编译的 877B 驱动 `goal-native-loading-probe-driver-01/tests`，不是重建旅行流程：原三程动作、固定布局种子 1380142925、35 项旅行检查、双方各 11 项原生 UI 检查保留。原 `NativeLoadingProbe.as` 和 `A22RoomMetrics.as` 逐字不变；`RoomTravelTimingTestDoc.as` 只加新观察器成员、构造、begin、finish 四个接点。共 **4 个 AS**，入口仍 `RoomTravelTimingTestDoc.as`。沿原两份 external SWC 编译，不包含同名游戏类或访问内部字段的伪存根。

`prepare.py --prepare` 仅生成本目录另外三个文本源码、精确差分和清单；无参数或 `verify()` 只读核验全部文本。返回清单含 `sources`（四文件 SHA）、`original_sources`、`original_prepared_sha256`、`prepare_sha256`、`readme_sha256`、`diff_sha256`、四接点数、原检查数及新结果路径。仅这些文本资格不能作为实际编译或运行证明。

## 一次首绘对照

首程随机普通房的 `ENTER_FRAME -81` 在 LAD 的 -80 回调之后、WallBlend -100 之前观察。必须是 `t_exit=19`、当前 World/Game/Location/Grafon/玩家一致、48×25 普通房，且真实 LAD Carrier 已附着、灯数大于零、原灯三个绘制引用已移走、灯图层真实挂载、每盏代理恰在原生 units 中一次。空房或错过该帧不会取得覆盖。

按实际 `LadSceneBake.surfaces` 的筛选取得前景、背景、第二背景、水面四个原生 BitmapData，再加 public `satsBmp`。克隆按 BitmapData 身份去重，最多 2400 万独立像素；只释放自己创建的克隆/差异图/舞台截图，绝不释放游戏持有的图。随后同一次回调只调用一次真实 `g.drawLoc(loc)`，在 finally 用原生 `cam.setZoom()` 恢复当前缩放；不推进世界、不调用 LAD render、不碰随机源、不清痕迹。检查 `sceneRedraws` 恰增加一次、相机值和世界/房间/玩家/灯/代理/物理字段及对象成员不变，并逐像素比较五张图。真实前后 PNG 全保存；任何合理动态差异仍记录失败，不擦除差异或改容差。

`colorBmp` 是 internal，未直接读取；准确现有 SWC 没有 Grafon 声明，不猜 QName、不添加签名桥。只比较 hardlight 合成后的真实背景结果，输出明确 `color_buffer_directly_observed=false`。这能验证最终可见输出，不能单独证明内部颜色缓冲相同。

## 原生开关灯

原三程全部完成、旧观察器写出 `native-loading-observer.json` 后，才对当前实际房间分别调用 `Location.alloff()` / `allon()`，等待下一次 LAD 正常回调观察 powered/nativeFrame、同一灯和代理身份/数量、生命值，并在最终 RENDER 保存两个舞台 PNG。没有直接改 lamp 状态或手动触发 LAD 同步。开关灯会调用原生重绘和对象逻辑，本轮只有隔离实例，完成后由原运行器回收。

新输出在独有 Local Store：`ordinary-lamp/result.json`、十张 `first-<surface>-before/after.png`、`native-alloff.png`、`native-allon.png`。终态有八项附加检查，以及原始首绘/开关灯状态和错误。最后日志标记完整前缀为 **`LAMP RASTER PROBE DONE <host|join>`**；原 `COOP EFFECTS DONE travel-timing`、`NATIVE LOADING PROBE DONE` 都保留。

后续运行接线必须在原 600 秒内同时等这三个终态标记，并在清理前收齐实际 JSON/12 张 PNG，不能只等待旧 DONE 后提前终止。必须独立核原 35+11 和新八项；缺数据或诊断错误不能由原检查通过代替。当前上一层薄入口仍绑定旧 877B，**不能直接运行这份新源**；根需实际单驱动编译及准确绑定后才能运行。

## 证据边界

首绘额外原生重画、状态采集和 PNG 编码都发生于该测试旅行中，随后又主动开关灯；因此此轮固定 `diagnosticOnly=true`、`performanceQualified=false`，所有旅行时间只保留功能证据，不用于净加载速度。观察的是首程 LAD 成功附着后的实际栅格，旧版先做两次 BAKE 也可以通过同一像素比较；此观察器未读取或操纵私有票据，故固定 `optimizationPathProven=false`，不能单凭通过宣称新省绘路径确实执行。灯具图层和代理数据来自真实公开对象，截图来自真实显示；舞台截图并非只含灯，外观仍由根回看。仅覆盖普通房、成功附着及开关灯，不冒称覆盖 store/discover 异常、已有破坏像素、跨地图全部灯型或全套回滚链。
