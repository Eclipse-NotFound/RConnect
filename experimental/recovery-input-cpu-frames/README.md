# 首轮加入侧独立帧 CPU 采样

针对825a566b2a长窗口采样在grant内丢失缓冲，只采目标grant处理返回后的**首6个ENTER_FRAME→最终RENDER窗口**。无满缓冲callback；每窗独立clear/start、pause/取样、stop。仅加入侧round0；原scene12派生驱动的三轮旅行、三帧输入基线、1000ms期限及原生KEY_DOWN/UP逻辑完整保留。移除带标记的插入可恢复冻结祖先全部源码。

本候选只用于归因。计时受采样和枚举影响，不能验收加载速度或帧率；不推算已失效的grant内部调用栈，不改原FAIL。

## 窗口与边界

- 目标grant的低优先级MESSAGE观察器只启用诊断。下一次Stage.ENTER_FRAME高优先级开始第一个窗口，不把grant尾部误当整帧。
- 最低优先级Stage.RENDER暂停并读取。一次gameFrame多次RENDER只关闭一次，额外事件记duplicateRenders，不重复枚举或重开采样。
- 下一ENTER_FRAME发现前窗尚未RENDER，前窗以missing-render关闭并丢弃其CPU数据；再开始新窗。原inputError/finish先发生则以stop-before-render关闭，不能补造RENDER。不调用stage.invalidate，不改变渲染调度。
- 首6帧后继续记录未取样帧和selection-cap原因，直到原round0输入成功/失败或finish。帧明细最多256，超出单列unrecordedFrames；标记64，超出单列markerDropped，不能称完整诊断。
- 零CPU、计数倒退、枚举不完整、采样异常、任一上限触顶均使该窗invalid，其cpuRows/stacks清空。其它独立有效窗可用于局部归因，但不能补齐失效窗口。原生序号每窗重置，禁止跨窗比较。
- 直接来源是采样器实际Sample.stack，不读取NewObjectSample/DeleteObjectSample的类型、对象或栈。Sample.time保留原微秒，不猜其与getTimer的偏移。

采样上限：最多6窗；全体保留CPU12000、栈512，每栈24层、函数名192个UTF-16单元；单窗原生条目先验上限和枚举上限均250000。每窗/全诊断15秒上限在返回AS事件时检查，不能打断阻塞中的原生调用。没有callback兜底，因此单个超长帧仍可能使VM停止；该窗必须invalid。AS数组与字符串有界，但VM自身原生采样缓冲容量由AIR实现决定，沿原生运行器的内存护栏，不宣称这些常量是整个VM的硬字节上限。

beginCostMs、scanCostMs、closeCostMs另记。枚举在RENDER暂停后执行，会影响后续真实测试时间；这些时间与原三轮失败均保留，不扣除开销来制造通过。最终测试结束才序列化CPU JSON；日志仅写文件名、窗口数和有效CPU数，不写栈文本。

## 复用入口

没有新runner。`generate.py`复用旧源生成器，只为helper构造传入真实Stage；`prepare.py`复用旧input-cpu prepare和原共享登记编译器，只改诊断元数据。源码manifest绑定全部祖先。`collect.py`沿旧输入/安装/描述符核验结构，增加逐窗schema和反例；失效原始JSON保留，不能从拒绝的数据生成栈摘要。

根会话从mods/RConnect使用当前Python运行时：

```powershell
python -B -X utf8 experimental/recovery-input-cpu-frames/prepare.py build/m52/recovery-input-cpu-frames-driver-01 --compile --candidate build/m52/recovery-13 --gate-expect on
```

执行构建产物中的`runtime-command.json`参数列表；仍为既有`recovery-seed-raster-control/native_runner.py`，保留全模组、独立桌面、defer-visible、wait-host-world、require-exclusive-air、共享登记和内存门槛。不要改用含旧first-frame解析逻辑的run_native.py。

结束后：

```powershell
python -B -X utf8 experimental/recovery-input-cpu-frames/collect.py --run build/cooperation/实际十位运行ID --drivers build/m52/recovery-input-cpu-frames-driver-01 --output build/m52/recovery-input-cpu-frames-review-01
```

每次新目录；collector不启动进程。原功能失败、三轮与ticket规则继续核验，summary始终不声称performance资格。`complete_selected_frame_capture`只指6个入选窗口全部有效，不代表grant、未取样帧或整个加载过程已获得CPU覆盖。

当前交付仅源码生成、Python静态/报告反例检查；没有编译或AIR实测。实际回调顺序、采样可用性与诊断开销待根会话验证。
