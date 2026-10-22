# 保持旧 RV 的重访诊断准入

RV 所属会话已将安装包从准确 `7852F61E…BE86764` 升至 `AB461FF3…2F23871`。旧实验清单不改。本新入口只允许这一项明确变化；其余 21 项必须与旧清单逐项相同。当前安装仍保留 AB46，隔离测试通过原有 `--vision-candidate` 入口载入备份中的旧 7852（41,630 字节），继续重现 `3b3c31c5f5` 的运行组合。

- 准备直接复用已编译 `recovery-early-sandy-scene-driver-01` 的原源、两个声明库和 harness；原生产、测试来源和完整旧清单仍核验。不调用已按旧安装锁定的旧 prepare。
- 仅替换此前冻结的 `recovery-early-revisit-probe/tests/FirstRasterSceneProbe.as`，一字不改；其余 AS 字节不变。原旅行与按键断言仍有效。
- Sand003 所有源码、工具、intent、receipt 和原 22 项安装来源仍按原指纹检查。当前安装另用精确转换检查，不接受其它新包、缺项、多项或任意 RV。
- host 独立回读原有完整检查仍执行，仅其安装比较应用同一个精确转换；原回执与失败不改。新派生脚本指纹单列，其余回读结果必须完全一致。
- runner 仅增加必须使用准确旧 RV 的入口断言；原隐桌面、登记、内存、独占、清理保持。运行回执必须证明双侧实际 RV 都为 7852，安装前后都为 AB46。诊断不给性能资格。

根会话（mods/RConnect，Python 带 `-B -X utf8`）：

```text
experimental/recovery-early-revisit-frozen-rv/check.py
experimental/recovery-early-revisit-frozen-rv/prepare.py --output build/m52/recovery-early-revisit-frozen-rv-driver-01 --build --registry-wait 900
experimental/recovery-early-revisit-frozen-rv/run_native.py --candidate build/m52/recovery-early-compile-01 --game-candidate build/m52/recovery-early-host-01 --drivers build/m52/recovery-early-revisit-frozen-rv-driver-01 --output build/m52/recovery-early-revisit-frozen-rv-native-01 --sand-mode bridge --registry-wait 900
```

尚未编译/AIR。各 `.patch` 显示与冻结旧入口的实际差异；新 `inputs.json` 同时绑定旧实验、新适配、旧 RV 和本次 RV 部署回执。未修改任何安装或旧实验文件。
