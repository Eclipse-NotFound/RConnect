# 原生加载界面：仅背景门原夹具复测

复用准确 `recovery-room-repair-review/run_hidden_v3.py`（7CF2FCBC）的历史驱动资格段、review_role 和完整主运行/结果逻辑。原12轮驱动仍来自 `a22-testpack-15-04/build/driver-qualified-hidden`：A2A5C325 / CFE342DC。历史73d75eff59的原输入、日志、driver-input及成功回执继续逐项核验；不声称80CF/roomfix3旧preflight在当前环境原样通过。

新绑定真实读取 UIv2 已冻结 bundle：9C8536A7 产品、2DB0B4EB 私有宿主、BF4A历史编译/638E当前22项，以及已存在的4FDA39F7根语义准入。原正式安装仍A796/78C。通过共享runner官方 `--game-candidate` 指定私有宿主，不改正式文件、名单或Sandevistan。旧历史驱动保持原字节，不加载877B观察器；UI bundle对877B的校验只保留其原组合输入证明，不把它说成本次运行驱动。

展开差分仅七个明确接点：替换过期导入、绑定目标常量、preflight前半段改为真实UI资格、限制新输出、官方game override、准确intent说明、增加私有配置回读。历史资格尾段与全部业务断言保留。launcher只在原run_registered的before_launch/child_stopped写入并回读本次私有CS `nativeEnabled=false` 和真实telemetry，仍调用原登记回调；两个角色的独有AppID、descriptor、文件此前不存在均先检查，回读在原副本清理前完成。

原600秒、6GiB/512MiB、独占、私有桌面、错误扫描、角色身份/控制/身体像素、敌人死亡/血量、返回伤害只结算一次及全部12轮coverage不改。结果继续不授性能或部署资格。此驱动开启宿主跟随；不覆盖宿主留守加载画面、逐帧真实vwait可见性或交接取消，不冒称35+11探针也在运行。

在 `mods/RConnect` 执行，root统一安排实际运行：

```text
python -B experimental/goal-native-loading-hidden-only/run.py --source-check
python -B experimental/goal-native-loading-hidden-only/run.py --check
python -B experimental/goal-native-loading-hidden-only/run.py --output build/m52/goal-native-loading-hidden-01
```

所有输出须全新。实际宿主准入缺失仍not-ready，不能由此入口创建或假造。仅源码/静态核验，不编译或启动游戏。
