# B field UI / camera repairs

统一集成进展（2026-10-26）：本覆盖已合入field22并部署，六次换房、两类计时交互以及最终文字画面检查通过；实际安装字节UI主77/加36通过。准确证据和遗留见[统一验证记录](../../state/b-field22-validation-2026-10-26.md)。下文保留首次交接时的分析与验证计划。

2026-10-25。只相对准确 `build/ab/b190-field9-build/src` 的六文件覆盖；当前只是待合并候选，未编译、未运行AIR、未部署。根会话统一合并验证，不能把静态定位说成用户场景已修复。

## 根因与修改

1. `OccupiedRooms.ensure` 为每个房间新建 `Camera`，其原生 `isZoom=0`；`showHost`直接换用新/旧房相机。原版同一玩家跨房保留同一Camera的isZoom，B却意外把缩放变成每房设置。现在只在真实host视图变更时取旧host相机isZoom，绑定新视图后写入并调用原生setLoc，重算当前窗口与该房尺寸。新房、重访都保留玩家选择，不复制旧房边界或坐标，不修改background模拟相机的平时状态。
2. 原生 `GUI.setCelObj` 的进度条分支读取 `gg.actionObj.owner` 和 `gg.mt_action/t_action`。B标量传输已有后两项，却不可能保留actionObj引用。`PlayerActor.snapshot`新增只含owner X/Y/nazv与actionText的action记录；`ClientReplica`建立不入链、不step的原生Obj+Interact供GUI只读，取消/断线清理。操作和成功/失败仍由host原生UnitPlayer/Interact结算。
3. `VisualPose.apply`以前先导入矩阵，再写htmlText/replaceText/textColor。居中/右对齐自动尺寸文本可在导入中再次移动，其后motion帧又回到源矩阵。现在文本导入后再恢复准确源矩阵，避免两种绘制路径坐标不一致。该机制风险明确，但NPC/伤害数字的完整用户抖动仍须实机确认；不改插值时钟、数字数值/颜色或动画节拍。
4. 应root的投掷物接线要求，`ReplicaScene.pointer(extra:Array=null)`接受额外只读候选。现有无参数调用语义不变；root负责投掷物proxy及传入。

## 合并注意

- `ClientReplica`、`PlayerActor`可能与root Q/投掷物工作相交；按本目录相对field9的差异合并，不整文件覆盖root新改动。
- `ReplicaScene`仅pointer参数与extra遍历两处，与同步性能组地形修正应可机械合并。
- `VisualPose.capture`协议未改变，已有独立参考pose捕获不需修改。
- `NativeTextChecks`是已有探针调用的检查类，本次增加5个检查：24次文本变化的CENTER/RIGHT确认与motion坐标，以及真实visualNumb/visReplic/visReplic2重复绘制像素一致。产品常规流程不调用测试方法。

## 根会话需要的实机验证

- 旧/新host在isZoom=0/1/2时真实过门，普通左右门/背景门、重访与在第二房改变缩放再回第一房；各次isZoom维持用户最新值，scaleV由原生房尺寸重新计算。join单独换房不能改host当前zoom，窗口resize仍正常。
- join真实按住E开锁和破译：从0到完成的原生pr_bar比例和目标/操作文本；松手、失败、成功、换房、断线后正确消失。两人同时操作不同目标不得互换条；同一对象按既有host仲裁。
- 调用`NativeTextChecks.stability(access,check)`对准确旧/新VisualPose路径取证。候选同时跑原有数字像素、原生NPC气泡与dialogue场景；捕获连续最终绘制帧，分开评价内容一致与抖动，不只比较一个确认时点。
- 本次新增文字测试是候选检查，可在外置同一驱动内拷贝该方法并通过目标domain.VisualPose调用，以取得真正旧/新同场景对照。

原生证据：`fe/inter/Camera.as` setLoc/setZoom，`fe/inter/GUI.as` setCelObj（约1280行），`fe/unit/UnitPlayer.as` actionObj/t_action/mt_action；均来自只读1.02参考。
