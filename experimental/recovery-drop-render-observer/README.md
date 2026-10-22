# 掉落物两秒绘制回调观察

仅外部诊断驱动；尚未编译或运行 AIR。基于已冻结、已修正实际背包武器的 `build/m52/motion2-continuity-drivers-01/tests/PresentationContinuityTestDoc.as`，SHA-256 `2e998334580505028b9fa58d3daa6067e3eaa92d3df313db4ecfeeba26a8e6f9`。生产源码、原两次容器操作、SATS、敌人行走、原断言、原截图、阶段期限及原去重轨迹完全保留。

此目录实现 `recovery-motion-cost-crosscheck` 提出的唯一试验。它不更改位置、游标、寿命、同步频率或生产回调，不新增截图、CPU 采样和运行器，不给性能资格。

## 记录边界

- 只观察 round0 的 kofe×37。第一条记录采用原轨迹的“掉落存在、vis 存在且已挂到 stage”判据。这个“初显”只是显示对象资格，不是截图像素或祖先可见性证明。
- 在原 `render` 的 `lastRender==renderFrame` 去重之前记录，每个 RENDER 都保留；原 `trace.push` 和去重逻辑原文不变。
- 从首次符合条件的 RENDER 起 `[start,start+2000)` 内，共享上限 **256 条**：RENDER、原高优先级 ENTER、原 lootMotion 监听器的匹配条目合计。不是每类 256 条。溢出计数、异常、显示对象替换和网络键变化明确使诊断不完整，不丢掉旧原生失败。
- RENDER 记录真实 `getTimer`、已有游戏帧号、是否会被原去重过滤、同一个掉落对象的逻辑 X/Y、当前 vis.x/y、stage/visible/alpha、stay 和显示对象身份是否仍相同。首次匹配后保留对象引用，不因位置相似而暗中认领另一个对象。
- ENTER 只记录已有回调的帧号和到达时刻。lootMotion 直接沿用原 `lootArrivals` 那次 `getTimer`，记录 sampleTime、x/y/stay/k；不复制整包。网络键最多 64 字符。源宿主本来没有这条接收监听分支，宿主零条 loot 行不代表丢包。
- 只读现有公开字段；不读私有 motion 游标，不新增生产钩子。加入端网络键与显示对象通过唯一测试物品身份关联，没有读取生产私有键表，故不冒充独立完成的任意场景逐物品身份审计。
- 到截止后的首个现有回调只关闭窗口，不补造记录。测试原 `finish` 最后一次输出 `DROP RENDER OBSERVER {…}`，在原 DONE 前；记录期间没有逐条日志/文件写入。失败提前收尾也导出并标不完整。若运行器杀死进程、未到 finish，则缺失导出本身就是不完整。

内存只保留最多 256 个固定字段小记录和一个对象引用；无 payload、位图或栈。热路径多了函数调用、标量读取和有界对象分配；首次寻找目标使用原 `drop()` 查询，开始后复用引用。收尾 JSON/日志在原采样流程结束后，不能拿此诊断的帧率授予性能资格。原测试自己的 SATS 截图仍原样保留，发生在该掉落两秒窗口之后。

## 可区分与不能区分

1. 若空档内 ENTER 与所有该优先级的 RENDER 均缺席，可排除“这些回调持续调用但该物品一直没更新”；不能据此指定网络、GC、渲染或某个模组为根因。
2. 若同一游戏帧内额外 RENDER 存在，可直接看到原去重曾漏掉的回调与坐标；不能将旧轨迹的采样空档自动等同真实屏幕停顿。
3. 若新 ENTER／RENDER 持续出现、位置包已经经过现有监听器而 vis 保持不变，才支持进一步核查显示时钟或放置次序。稳态落地时坐标相同本来合法，需看 stay 与实际飞行段。

接收时间是已有监听器执行时刻，不是操作系统收包时刻；两进程 getTimer 不是同一时钟，不直接相减作纯网络延迟。记录的是该既有 RENDER 监听器处的显示属性，不能证明其后没有其它监听器再改变显示。没有 CPU 栈或新增像素证据。

## 最小复用入口

`materialize.py` 只生成 AS 和文本清单，并反向精确移除五组插入，要求恢复冻结父驱动的全部字节（含 CRLF）。两个已有回归 helper 直接逐字复用。没有改父驱动的任何原断言。`prepare.py` 是已有 pause-native-driver 构建适配的同样薄流程：独立输入、登记、编译前后指纹、1 GiB 启动条件、512 MiB 终止检查、仅终止自有编译器；不调用 AIR。二进制指纹取自已有回执，实际 freeze/build 前重新核对字节。`--check` 仅核对文本，明确不声称已读回二进制。

主会话可调用（以下路径相对 `mods/RConnect`；输出都必须新建）：

```powershell
python -B -X utf8 experimental/recovery-drop-render-observer/prepare.py --check
python -B -X utf8 experimental/recovery-drop-render-observer/prepare.py --output build/m52/recovery-drop-observer-drivers-01 --build --registry-wait 900
python -B -X utf8 experimental/recovery-formal-policy-control/run_motion_comparison.py --candidate build/m52/recovery-23 --drivers build/m52/recovery-drop-observer-drivers-01 --case continuity --output build/m52/recovery-drop-observer-native-01 --host-vision-config-template experimental/recovery-formal-policy-control/configs/host-RealisticVision_config.txt --join-vision-config-template experimental/recovery-formal-policy-control/configs/join-RealisticVision_config.txt --registry-wait 900
```

候选由主会话决定；示例 23 不是已经编译／实测的声称。正式 wrapper 原有独占、隐藏桌面、HighQoS 读回、实际 RV 模板、22 安装输入与错误日志核对保持原样，没有复制或放宽 wrapper。不要把原没有 observer 的运行作为严格 `--reference`，因为驱动字节不同。

运行结束后，用具体已结束 cooperation 目录读取两侧日志，不打印原长数组：

```powershell
python -B -X utf8 experimental/recovery-drop-render-observer/read_observation.py --run build/cooperation/实际运行ID --output build/m52/recovery-drop-observer-native-01/observer-summary.json
```

汇总单列完整性、同帧额外 RENDER 数、真实回调间隔与窗口边缘缺样；不改原 wrapper PASS/FAIL，也不新增“性能通过”阈值。原 `COOP` 断言结果与该诊断完整性必须分别呈现。
