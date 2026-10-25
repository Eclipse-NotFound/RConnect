# 仅 RConnect 的普通三程对照

只改变隔离副本的官方加载名单：运行时仅 `RConnectMod`，包括 `ModLoaderMod` 在内的其余 13 项不加载。官方选择器是外部准备工具；实际加载状态由宿主 MainFE 的 SOL 验证。物理模组文件保留，正式配置不改；实际启用 inputs 与完整物理清单分别保存。

两臂共用一个外部驱动：正式 78C / A796 与原生加载 UI 9C85 / 2DB0。不纳入 LAD 首绘候选。原 877B 的三程动作、种子、旅行检查和计时保持；只把 CS 已加载前提替换为缺席检查，并增加结果时的入口/视口记录。双人仍主侧 23 + 加入侧 12 项，单人 11 项。原真实 RENDER 观察保持；9C 双人强制原 11 项 UI 资格，正式版或单人只要求 8 项通用观察，全部 11 个原始布尔仍记录，`uiContractQualified=false`，不伪称不存在的桥已通过。

布局种子 1380142925 不固定原生出生抽签和人口。比较必须同时看每程 x/y、camera、viewport、房间和单位列表长度；后者不等于活敌人数。入口不同不能直接归因候选提速。观测区间仍是采样间隔而非 GPU 完成时间；PNG 在旅行计时结束后生成。

## 根会话执行

1. `python -B experimental/goal-rconnect-only-loading/prepare.py --check`
2. `python -B experimental/goal-rconnect-only-loading/build.py --check`
3. `python -B experimental/goal-rconnect-only-loading/build.py --build --output build/m52/goal-rconnect-only-loading-driver-01`
4. `python -B experimental/goal-rconnect-only-loading/run.py --arm baseline --mode solo --output build/m52/goal-rconnect-only-loading-baseline-solo-01`
5. 同入口以 `--arm baseline|ui --mode solo|dual` 选择其他组。运行前 `--check` 必须核到真实成功编译，缺产物返回 not-ready。

所有相对路径以 mods/RConnect 为运行目录。单 mxmlc 使用既有有界编译器，1 GiB 起步、512 MiB 运行、登记与自有 PID 回收保持。AIR 沿原共享运行器，单人 3 GiB / 双人 6 GiB、600 秒、私有桌面、独占、错误扫描与回收保持。源码预处理不启动编译/游戏。

历史 BF4A 编译与当前 RV638E 的 22 项环境分别校验；不会替换 installed() 或改写旧结果。候选另核原 2DB0 实际语义准入。运行时关闭 RV 不等于可跳过实际安装指纹。

`result.json` 保存原旅行结果、实际 observer 文件、严格 onlyRC SOL 证据及事实/资格区分。额外 `NATIVE LOADING PROBE DONE` 与原 DONE 同时满足才结束，不延长原超时。通用结果不会授予性能资格。
