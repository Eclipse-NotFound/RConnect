# 外部密集夹具：武器准备一致性修正

2026-10-22，仅源码；不修改RConnect、原driver02、原失败结果或安装文件。父会话授权后在此准备，尚未编译或运行AIR。

准确祖先为 `build/m52/recovery-density-corridor-drivers-02`，manifest SHA256 `d014852ab877dcb750c9bfcf4fe03d2b78080f23c5af639eb5db0933c690bcb3`。问题证据见 `../recovery-wall-base64-runtime-review/fixture-hold-review.md`；两轮18/19的整体失败已另存，不能反改为通过。

只改主驱动的准备段，新增一个小型外部helper：

- 宿主原有七个fixture赋值移入 `DensityWeaponPreparation.configure`，数值不变。宿主准备结束记住39把真实枪对象与80身体的对应关系。
- 加入侧先等待正确原生武器class/id/variant及owner、childObjs关系，保留只读 `DENSITY WEAPON PREP.before`，再在既有对象上一次设置同七项数值。没有建枪、调用生产receive、装填、攻击或步进。不会以参数“自动同步成功”作为测试结论。
- `arenaIdentity.weapon` 从名称扩为原DensityFixture已有的完整武器字段行（10项，包括hold），加实际原生class。ready的600ms稳定期和commit都比较它。进程内还核对gun仍为准备时同一对象、owner/childObjs仍正确；同字段换对象也不接受。准备后漂移只拒绝，不再补值。
- 与driver02相比，`tick`、`nextPhase`、`frame`、RENDER探测和所有原断言原文保持。80身体、12把发枪、7段、原频率/8000ms/帧数/p95/快照/瞄准/轨迹门槛均保持；CorridorFixture和严格audit原样。没有在计时段增加helper扫描或参数维护。

静态核对和Python反例仅证明所写分支/字段关系，不等于AS编译或真实native准备已通过。反例覆盖同id异hold拒绝、只读检查不修值、一次补正通过、准备后漂移拒绝、同值换对象拒绝、外来owner/脱链/错误class拒绝。测试不替代产品弹匣/伤害同步的独立功能验证。

以下从RConnect根目录由根会话串行执行；原runner负责登记、独占、22输入和日志验收。不增加新的二进制复制流程。

```powershell
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/recovery-density-corridor-readyfix/check.py
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/recovery-density-corridor-readyfix/prepare.py --output build/m52/recovery-density-corridor-drivers-03 --build
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/recovery-density-corridor-readyfix/run.py --candidate build/m52/recovery-18 --drivers build/m52/recovery-density-corridor-drivers-03 --output build/m52/recovery18-density-ready-control-01
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/recovery-density-corridor-readyfix/run.py --candidate build/m52/recovery-19 --drivers build/m52/recovery-density-corridor-drivers-03 --output build/m52/recovery19-density-ready-native-01 --reference build/m52/recovery18-density-ready-control-01
```

普通BEFC宿主/走廊的相同新driver两包对照才可谈可比性；不能将新准备与旧driver02对比得出收益。原14项失败和原 `input_comparable=false` 永久保留。即使准备通过，七段原性能检查仍必须逐项通过；本夹具不提供大场景、加载或墙面桥资格。

未扩大旧夹具其它边界：ready锁存、开场诊断累计netAt、terrain轮转和最终场景复验均未在本次调整。不提供新的profile入口；本次仅普通性能夹具准备修正。
