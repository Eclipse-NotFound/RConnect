# 原生加载画面观察器（仅普通三程）

本目录只准备诊断驱动，不改游戏、RConnect 产品、共享运行器或旧冻结输入；目前没有编译或实测结论。

刺激来自准确 `build/m52/recovery-room-current-driver-01/tests/RoomTravelTimingTestDoc.as`：普通房三程、固定种子、原生旅行/控制恢复、两侧房间和入口距离等 35 项断言全部保留。只加入五处观察通知（字段、初始化、开始、原结果之后、原 DONE 之前）；删除这些插入即可逐字还原原类。`A22RoomMetrics.as` 字节不变。

## 实际观察

`NativeLoadingProbe` 在 Stage 的最终 RENDER 阶段观察，优先级 -2147483000，晚于当前 RoomSync 的 -2000000000。它不调用 `rconnectLoadingView`，不创建遮挡层、不改显示字段、不调用 invalidate，不切换加载画面的所有者。

逐次记录真实 World/vwait 对象身份、原父层、可见/alpha/祖先可见性、vblack（原生黑幕和淡出）、entryPending/busy/ready、t_exit/loadScreen、场景 visual、背景 vfon、HUD vgui，以及宿主公开的 rconnectLoadingUiFaults。按三个原旅行阶段分别计数，最多保存 20,000 条；超过上限、观察异常或宿主显示故障均不能取得观察资格。

旧自定义层检查在每次 RENDER 只查看原实现的确切附着容器（stage/main/visual.parent/vsats），搜寻 `rconnect-room-entry`、`rconnect-room-entry-sats`、`rconnect-native-loading`。最后一次原旅行测量已结束后再遍历完整显示树，禁止把其它位置的同名副本当作不存在。逐帧检查不额外扫描整棵树。

独立的 11 项观察断言检查三程覆盖、零异常/零丢行、真实等待覆盖、桥故障、vwait/父层身份、无旧副本、允许显示的本地 pending 期间原生等待可见且场景/背景/HUD 隐藏，以及终态恢复与真实 PNG。这些断言写在 JSON，**不增加或替代原 COOP PASS / FAIL 计数**。正常原生剧情/淡出等阻挡状态另记原因，不强行要求其符合联机等待显示规则。

等待/黑幕/交接的总时长和最大连续时长按相邻实际 RENDER 采样估算；同一 ENTER 间多次 RENDER 全部保留，不能据此宣称多次 GPU 绘制。观察本身会分配少量对象，保存自身总耗时/最长耗时；不据此授予原产品的性能资格。终态全树扫描及 PNG 编码位于原三程全部计时之后，PNG 是对真实 Stage 的绘制，不是人工构造图片。

## 完成合同（新薄运行入口必须使用）

原标记完全保留：`COOP EFFECTS DONE travel-timing host` / `COOP EFFECTS DONE travel-timing join`。

附加标记完整文本：`NATIVE LOADING PROBE DONE host` / `NATIVE LOADING PROBE DONE join`。它仅在 finish 请求之后的真实最终 RENDER、终态 JSON 已写完后输出。各端文件均位于该次隔离应用的 **Local Store/native-loading-observer.json**，真实终态图为 **Local Store/native-loading-terminal.png**。

根后续薄入口须在原 600 秒上限内同时等原 DONE 与本附加 DONE；可通过原运行器已有 `--done` 设置等待新标记，但仍独立核原 DONE 与原 35 项。不能在原 DONE 出现时立即回收，也不能因缺 JSON / 终态无限续时。若 `NATIVE LOADING PROBE OUTPUT FAILED` 出现、缺任一端终态或超时，一律失败。附加 DONE 只说明输出完成，不代表通过：最终还须各端 JSON 的 kind/appId/role、complete=true、passed=true、11 项全真、faultCount/dropped=0、三程计数、PNG 实际文件和原功能结果一致。

JSON `durationMeaning` 明示采样估算边界，`diagnosticOnly=true`、`performanceQualified=false`、`loadingViewCalled=false` 固定。此轮只验证普通共同旅行；不把它当作分房、背景门、剧情或死亡场景资格。

## 源码及构建入口

`prepare.py --check` 核原文件 SHA、五处精确插入、完整差分与本目录 manifest。首次源准备使用无参数入口，只写本目录新文本。

`build.py` 通过明确计数的文本替换复用冻结 `goal-three-issues-native/build.py`：只更换单一 timing 入口、产物 kind、命令数以及描述文字；展开版本保存于 `adapted-build.py.txt`。真实旧运动入口、78C 产品、当前安装环境、原普通 35 项驱动及 ABI 的资格检查先独立执行，不把新驱动冒充原产物。原登记、1 GiB 编译启动余量、运行中 512 MiB 保护、300 秒单编译命令上限、子进程回收及 22 项安装检查保留。

根可执行（本代理没有执行编译）：

```text
python -B experimental/goal-native-loading-probe/build.py --check
python -B experimental/goal-native-loading-probe/build.py --output build/m52/goal-native-loading-probe-driver-01 --build
```

只读 `build.verify(output)` 要求真实 `compile.json`，返回原有 verified/artifacts/prepared_sha256/compile_sha256/inputs。其 candidate_sha256=78C 表示编译所用的现有外部 ABI 基底，**不证明新的 UI 产品或修改后的宿主已运行合格**；实际新产品/宿主及 Sandevistan 组合仍须由根的运行入口各自验证。该配方不提供 AIR 启动器。
