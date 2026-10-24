# 原生跳跃：被动补帧观察

只以正式78C/A796和当前RV638E组合为基线，对照已编52D472/0.2.24-jumppose1；两臂都保留完整14模组。本目录不改产品、安装配置或旧冻结驱动。

## 最小变更

- NativeJumpNetworkTestDoc.as 与实际 drivers-02 的69C45E逐字相同：原键盘输入、8秒后跑跳、15秒停止输入、18秒窗口、双方6项原检查及原DONE全部保留。
- 只给 NativeMotionProbe 增加只读标量：实际收到的nativeJumpRun、姿态/帧/停止播放/房间身份；最终RENDER的真实MovieClip帧与原生演员字段。共享一个本地顺序号解决同毫秒收包和RENDER顺序，不校准两进程时钟。没有额外readSnapshot、输入、setPos、采样器或逐帧日志。
- 原4096记录上限和掉记录失败保持。记录随原完整窗口在finish后输出，原收包和帧率分析不改。

## 能证明与不能证明

实际RemoteMotion.sourceTime是public，但对象仅存于GameBridge的private _remotes，getRemoteGhost不返回它。因此cursorAvailable始终false，不通过私有QName探测，也不运行旁路插值器冒充产品。

候选必须每个观察方向均实际收到两个同nativeJumpRun、同房/epoch、同姿态且符合原生dy公式的端点，并看见最终停止的jump身体帧。进一步只在公开ghost.dx/dy/stay和姿态唯一匹配某个已收端点、坐标位于它与下一合格端点的范围内时，将严格处于两端身体帧之间的实际帧记作直接新帧证据。匹配多义不强选；不会由显示帧倒算cursor。证据不等于逐帧游标正确、像素级/GPU截图证明、零卡顿或性能收益。

基线缺nativeJumpRun是预期。基线只要求真实正常jump包和最终停止帧观察，并确认没有新标记；不会因没有候选标记失败。两臂保留旧摘要统计。新诊断资格写pose-observation-result.json，原result.json不覆盖：原功能通过但未观察到明确补帧时，诊断不授资格、退出非零，不改称原游戏失败。

额外标量读取和数组字段分配存在诊断开销，当前没有独立量化；两臂使用同一新驱动。不得直接将本轮帧率与旧9EE驱动数字相减宣称产品收益。

## 编译与运行（仅根执行）

先执行prepare.py --prepare生成准确两AS、展开文本和清单。prepare.py --check、build.py --check、run.py --source-check都不会启动Java/AIR。

单驱动编译：

    python experimental/goal-jump-pose-native-observation/build.py --output build/m52/goal-jump-pose-observation-driver-01 --build

基线：

    python experimental/goal-jump-pose-native-observation/run.py --drivers build/m52/goal-jump-pose-observation-driver-01 --product build/m52/recovery-room-production-05 --case native-jump --output build/m52/goal-jump-pose-native-baseline-01

候选：

    python experimental/goal-jump-pose-native-observation/run.py --drivers build/m52/goal-jump-pose-observation-driver-01 --product build/m52/goal-jump-pose-product-01 --case native-jump --output build/m52/goal-jump-pose-native-candidate-01

运行前可带--check而不带--output。缺真实新驱动compile.json明确not-ready；候选也必须经过实际产品build.verify及52D472指纹，不依赖UI准入。

## 复用边界

旧goal-self-echo-native只复用已经审过的历史BF4A驱动/当前638E分离证明；实际installed函数仍读取当前22文件，旧历史回执不变。本次新驱动编译前后必须是当前环境，不能把BF4A冒称本次编译环境。

单编译直接使用旧goal-three-issues-native的command/main/登记/1GiB启动、512MiB持续门槛和finally回收，仅CASES缩为native-jump、verify命令数2改1及输入指向本目录。保存adapted-build.py.txt。运行器保存adapted-run.py.txt，仅改导入绑定、产品选择、CASES缩为native-jump和新输出前缀；原共享runner、300秒、6GiB/512MiB、独占私有桌面、真实加载/存储/telemetry、错误扫描及清理不改。不编译fast-held，不创建新通用框架。
