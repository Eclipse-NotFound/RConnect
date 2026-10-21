# recovery08 有界帧时序诊断

目的：定位真实高速轮 `105bfac8ad` 的加入侧106ms输出空档、首发354ms延迟；也适用于主会话新发现的特殊爆炸数百毫秒显示延迟。只做归因，不通过改播放缓冲或延长动画掩盖问题。本包**准确基于08**，不包含09酸液增量。01编译失败的证据保留；当前修正版尚未编译、未运行AIR，未修改installed/integrated或旧实测记录。

## 精确祖先与原行为

- 冻结 `build/m52/recovery-08`，SWF `74d2ab0f6c1d174153af56e9c3a8e3750fa429de066f0dfe90226d48db906f02`。
- 冻结 drivers14 `NativeFlightContinuityTestDoc.as` SHA `3fd803a59bfa84fd9aa5e82c3d6df83934d5041ac399b0b335ef57468f0da23a`。原8场景、真实背包装备、第一发、准备流程、时间限制、像素读取、所有断言不改。
- 同时从该冻结包按原字节复制 `tests/NativeFlightBounds.as` 到新输出tests，登记到driver_support和全部输入指纹。它是原driver的实际依赖，空帧与屏外证据规则完全不变。
- 复用此前 `recovery-flight-diagnostics/make_overlay.py` 中已经用过的motion/stream/projectile插点及driver生命周期插点，固定其SHA `6b6dcb0c53d51e614ab9c8c6dc536d5affe18b1c136c347a30f6ce1904a57f98`。新的Session/GameBridge范围插桩采用词法跳过字符串/注释后的花括号配对。
- 五份原类全部只插入有界只读诊断：RemoteMotion、ProjectileFrameStream、ProjectileVisuals、Session、GameBridge。剥掉 `FLIGHT_DIAGNOSTIC_BEGIN/END` 块后必须逐字恢复原输入（统一换行后），driver也相同。prepare冻结原输入hash并在编译前后重验，不从根src取代码。
- **RoomCodec、WallImpactVisuals没有覆盖**；08的默认无逐格日志保持原字节。没有payload/每tile采集，没有24MiB记录器，没有额外bitmap/getPixels，也不强制GC。

## 采集范围

1. Stage 最早/最晚ENTER_FRAME、最早/最晚RENDER，使用int最大/最小优先级。原driver最终RENDER采样优先级−2147483647不改；诊断最后边界−2147483648在其之后，因而包含原像素探针成本。首显/接触阶段同时保留原driver的采样前时间，不能把探针后的边界当成探针前停顿。
2. EXIT_FRAME最早/最晚监听只累积首时刻、末时刻、调用次数，下一次ENTER或换case/结束时写一个数字行。原生gotoAndStop可同步触发EXIT_FRAME，不能将这些回调等同于完整游戏帧结束；次数不平衡判诊断不完整。不会记录每个重入调用的独立行。
3. Session宿主/加入消息回调、发送定时回调，及GameBridge的四个原回调：onPerceptionFrame、onMirrorMaskFrame、onMirrorFrame、onVisForceFrame。每次仅一条起止时间行，try/finally保留原早退及异常传播。消息仅数值分类(worldstate/playerstate/unitsync/worldsync/ping/pong/其它)，无包体、字符串序列化或长度遍历。
4. 接收clock的offset/delay/clockAt、实际motion sourceTime/latestSampleTime；弹体更新前后的实际时间、首末样本时刻、最终显示坐标/帧和移除原因；motion的cursor/wanted/offset/实际速率。**不再次调用sample或推进时钟**。只记录本case已关联弹体的motion；其首次receive之前的历史不收集，第一条receive/clock包含当时实际游标。减少无关敌人记录，不影响原8轮所有弹体记录。
5. 每秒最多一次读System.totalMemoryNumber/freeMemory/privateMemory。内存下降不是GC事件证据，不能直接据它归因；没有System.gc/pause等操作。

所有hook默认sink=null，正常构造不启用；外部driver setup安装，finish清除。原8轮结束后一次性导出分块JSON到既有Log，运行途中不写新的诊断日志。原driver原本的COOP/FLIGHT日志不变。没有单独发送诊断网络消息。

## 开销和数据上限

固定 `Vector.<Number>(32768*24)`，数字槽6MiB；不覆盖旧行，超限计dropped并判诊断不完整。弱身份表最多4096对象；没有payload、动态文本表或对象轨迹副本。首个setup分配、弱表和导出临时数组仍有额外占用，6MiB不是进程总开销。

hook/事件观察自身累计耗时、最大耗时和调用次数单列；getTimer仅毫秒精度，0ms不代表免费。数据包含额外getTimer、弱身份查找、少量delay只读计算和try/finally成本，累计值也不完全覆盖所有插点外围参数读取及初始分配。原生原日志和像素探针成本继续存在。Session与RC回调可能嵌套，**耗时和不能直接相加当CPU总占用**；analyzer另给输出空档中已观测span的时间并集。诊断包始终performance_qualified=false，不能拿本轮帧率直接和无诊断08判优劣。

## 数字行格式与分析

每行24项：`kind,at,globalFrame,phase,case,globalRender`，后18项为数据，缺失或非有限数导出null。frame/render是诊断全局计数；原driver每case计数保持不变，按同一getTimer与case标记关联。

|kind|数据依次为|
|---|---|
|1 motion|id,op,now,cursor,offset,stamp,sampledAt,arrivedAt,count,delay,interval,flags,wanted,rate,x,y,latest|
|2 clock|stateId,motionId,op,now,offset,delay,clockAt,detached,cursor,latest,incomingOffset|
|3 receive|stateId,ownerId,motionId,isPlayer,sourceStamp,seq,sampleCount,first,last,end|
|4 display|stateId,now,actualTime,reason,first,last,count,end,x,y,clipFrame,hasVisual,motionId,cursor|
|5 tick|effectiveNow,activeCount,pauseAt（连续零active不重复记录）|
|6 span|method,messageType,start,end,duration；method=1加入消息/2宿主消息/3发送timer/10感知/11mask/12mirror/13最终显示|
|7 exit aggregate|firstEarly,lastLate,earlyCount,lateCount,firstPhase,lastPhase|
|8 memory|totalMemoryNumber,freeMemory,privateMemory|
|9 boundary|1最早ENTER/2最晚ENTER/3最早RENDER/4最晚RENDER|
|10 lifecycle|op=0启动+墙钟；1新case+case编号；2阶段+固定阶段码（见recorder.switch）|

display reason沿原插点：0样本尚不可播，1可播更新前，2达到原生end，3原有15秒过期，4已写显示位置，5原有remove。不引入新的结束策略。

新analyzer保存边界、消息/RC成本、>50ms输出窗口的span并集、首receive/write及内存趋势；50ms只是选出诊断窗口，不改变原85ms等验收门槛。完整性单列；原frozen native_flight.py与bounds_evidence.py原样执行，原COOP/轨迹失败不会被诊断完整覆盖成通过。

## 使用与当前验证

首次 `recovery-flight-timing08-01/compile.log` 显示生产诊断SWF和声明SWC已编译成功，外部driver第184、377行因未复制 `NativeFlightBounds` 而失败；01不修改。修正仅在prepare补齐原drivers14的这个依赖并验证指纹，未改任何AS或断言。后续必须使用新输出02。

纯Python静态自检已过：五个覆盖及原driver去插桩恢复一致，Python语法和prepare/run只读导入成功，4个导出破坏反例及3个完整性反例均拒绝；不是AS编译或实机通过。

纯Python生成和静态检查，无子进程：

```powershell
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/recovery-flight-timing08/make_overlay.py
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/recovery-flight-timing08/test_static.py
```

主会话之后可调用（本会话不执行）：

```powershell
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/recovery-flight-timing08/prepare.py --output build/m52/recovery-flight-timing08-02 --build --registry-wait 900
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/recovery-flight-timing08/run.py --build build/m52/recovery-flight-timing08-02 --output build/m52/recovery-flight-timing08-run-01 --registry-wait 900
```

prepare/run是既有独立诊断框架的局部适配，原文件未改；build_mod.py及声明生成接口沿用冻结08。只有--build启动JVM，共享game登记、hidden编译进程、1GiB启动/512MiB终止、有限等待与自有子进程清理；run复用既有run_coop_regression的隐藏双实例、全模组、独占AIR、defer-visible/wait-host-world、内存门槛及登记。输入和22安装指纹前后检查；全部模组日志、两侧PASS/FAIL/DONE/version、原与新analyzer都必须审核。输出只能用新的build/m52直接子目录，失败证据不覆盖。
