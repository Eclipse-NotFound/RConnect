# Actual particle text / camera observer

2026-10-25。`BTextMotionCases.as` 未编译、未运行。与UI/DarkQ相同constructor、input、step、finish接口。建议独立scenario `textmotion`，host选limX>=1600的普通探索房，根setup清走道、两人同home、传floorY后创建helper；不startExit。120秒以上总体timeout，独立end协议同前两个helper。

## 要回答什么

静止符号的8项文本检查在field9基线全通过，因此VisualPose文本导入后重设矩阵尚不能解释用户抖动。这份驱动观察真实Emitter创建的原生Part，而非仅在离线MovieClip上反复赋文字：

- numb沿原生定义dy=-1、brake=.98上浮，寿命60tick。
- replic/replic2使用原生NPC对白资产、100tick寿命和原生淡出。
- 不修改发射器的速度/寿命/透明度/镜头缩放规则；用cast指定正常文字和位置。
- 五段各90主侧tick：静止、加入玩家持续向右走、持续向左走，以及向右/向左移动同时轻机枪点射。除构建隔离夹具外，移动、点射由真实方向键/开火键执行，镜头仍用原生Camera.calc。

helper在每次ENTER_FRAME末端（priority -200000）只调用stage.invalidate；在Event.RENDER采样，每个ENTER_FRAME序号最多采一次。不能用EXIT_FRAME作为“最终画面”，因为gotoAndStop会同步重入EXIT_FRAME并暴露尚未transform的构造半成品。不包装产品方法、不推进第二次Part。

## 分开记录的证据

1. 最终Part的根位置与实际displayFrame已经提交的pose矩阵平移比较。如果被本机另一路重新定位，会出现rootError。
2. 将实际displayFrame的文字树各层矩阵独立相乘，得到文字叶子在世界层的坐标，再与最终显示树对比。用于寻找提交后发生的时间轴或文本布局改写，textError阈值0.16像素（容纳Flash固定点量化）。这只验证最终显示是否忠实于已经提交的配方，不验证PoseTween插值算法本身；不能先合成源A/B文字矩阵再线性混合，因为父子逐层缩放后的合成与之不等价。
3. 同时记录世界坐标、最终屏幕坐标、公共相机位移、加入玩家位置、预测领先量、播放时钟fraction/delay和断粮次数。固定世界物体在单方向走路中出现反向屏幕跳动时，分别统计worldReversals和cameraReversals。反向次数目前只作为诊断，不假定主观问题已经找到了。
4. baseline与candidate运行同一外置代码。源确认坐标和实际显示坐标在同一采样时间比对，不拿“现在主侧”与“延迟中的加入侧”直接比位移。

阶段末写小统计JSON；结束写每侧一份有限采样记录，没有每帧磁盘写入。保留原生移动/动画频率。

## 当前源码结论与边界

- `SceneEffects`加入侧只有DisplayObject，无原生Part参与物理step；`GUI.setCelObj`另写悬停文字celObj/进度条，没有直接改这些Part。
- Camera.calc只移动World.visual母层；如果屏幕文字跳而世界位置稳定，必须先判断共用镜头/自身预测位移，而不是继续给文字加平滑层。
- 三种Part均camscale=1，创建时使用主侧摄像机倒数缩放；双方缩放不同时可有尺寸差异，尚未证明是抖动根因。
- 该驱动覆盖头顶NPC气泡；正式剧情对话面板属于AuthorityGUI.applyModal的另一条路径，没有在本驱动中伪装成已覆盖。

2026-10-26补充静态核对：原生Emitter.arr/cast、Part继承的Pt字段/生命周期、Location链与数组、Camera采样字段均为public，未发现internal跨包访问；未自行调用JVM编译。追踪数据补充latestX/displayX/playerX、最新/当前确认time、clockPosition、Camera目标X/偏移/缩放/quake，可明确区分字自身偏移和相机在“最新预测位置”与“延迟播放位置”之间切换。MovementPrediction.sample对非纯移动输入、地形版本变化或超过150ms未到新帧返回null；ClientReplica.predict会立即回到displayFrame，而PlaybackClock可延迟65–250ms，这是尚待实测的强嫌疑路径。

v6备用（不改root已复制的v5）：增加walk-right-attack与walk-left-attack两段，所有阶段前统一准备原生轻机枪；点射为6个主侧tick按住、6tick松开，仍通过真实输入传输。最多1200条采样；记录注入键/最终键、latest/display/实际玩家位置、时钟位置、地形确认版本、原生work、quake与不含震屏的cam.vx。arrival字段是private，因此不跨包读取；observedFrameAgeMS仅表示本观察器上次看见replica.frames变化后的时长，不冒充精确网络到达年龄。屏幕反向最大幅度、去掉震屏后的相机反向最大幅度分别记录，仍不把正常枪械震屏当错误断言。

v7修正（root实测发现夹具问题后）：删除flatten(source)/flatten(next)后直接线性混合的错误期望，改用实际displayFrame.effect.pose逐层合成。firstError同时保存完整source/future/display pose和实际根→文字的矩阵链、根/文字/屏幕坐标，可据此区分错误来源。v5首段3.913px textError不能算产品错误；file-open #3013及主侧退出后的巨大rootError也不算有效产品证据。计数语句改用metrics[kind]=Number(metrics[kind])+1，避免Flex将String下标错误处理为自增操作数。此目录没有启动编译或游戏。

v9待统一编译：Event.RENDER替代EXIT_FRAME，每次真实ENTER_FRAME最多一次采样，末尾文件新增renderSampling，阶段与trace记录开始/结束ENTER_FRAME、RENDER序号。SDK本机airglobal.swc catalog确认有flash.display:Stage、flash.events:Event，library.swf包含invalidate/RENDER/render API符号。首次绑定当前房间调用原生cam.setZoom(0)、cam.setLoc，不直接写cam.vx；整轮应看到非零镜头范围。此前field14-03的相机scale=.5125、vx恒0，是全地图缩放，未覆盖跟随镜头的预测回摆；新构造粒子根矩阵identity的10项失败均疑似EXIT_FRAME重入，不能算产品缺陷。

独立`BTextInterpolationChecks.run(mod,domain,check)`应先在field9 baseline跑，然后跑修复候选。用真实visualNumb/visReplic/visReplic2和CENTER/RIGHT TextField，仅改变alpha产生A/B两个确认，通过真实PoseTween.pose(A,B,t)及VisualPose.apply测最终叶子位置；原生几何固定时不得漂移。必须至少一个夹具实际出现TextField x/y getter与matrix.tx/ty差异，否则没有复现目标条件。候选PoseTween只把m[4]/m[5]改为对应原始矩阵平移插值。field14-03虽有采样时机瑕疵，但源数据已直接给出x=-54.5/m.tx=-23.5以及x=-25.5/m.tx=-23.5的真实差异；trace在root/camera固定时出现±31px和±2px屏幕位移，对应当前错误矩阵重建。

## 统一实机结果复核

根会话运行、子任务只读分析：`build/ab/b-text-native-baseline-01`的五个插值检查双侧均失败，三种原生文字最大位移3.9px、CENTER 3px、RIGHT 6px，所有夹具真实存在getter/matrix差异。前四运动阶段的RENDER采样不再出现构造半成品，root/text误差最大约0.049px；末阶段host外置File.moveTo报3012、join随后超时，不计产品失败，也不能称基线整套完成。

`build/ab/b-field2-fixed20-01/textmotion`候选主20/0、加34/0完整结束；五种插值检查7个比例的最大位移均0。join记录446次ENTER_FRAME与446次有效RENDER，过滤448次重复RENDER。五段运动root/text最大误差小于0.05px，屏幕与去震镜头反跳最大幅度均0，镜头实际随人物移动（例如向右cam.vx从-313到-936）。这支持矩阵平移修复生效；位置检查不是逐像素截图比较，正式剧情对话面板仍不属于本粒子测试覆盖范围。
