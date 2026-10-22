# A 接口：真实非零冷却补充

只补冷却覆盖，不扩敌人场景。原 `recovery-sandy-hold-native-lifecycle` 和实际 `9180342e9d` 的 41/0 结果保持不变。本变体不是原 41 项逐字复跑：一项“零冷却”判据改为“自然回放结束后冷却大于零”，释放后的再激活改为等待自然归零；增加释放后下降、自然归零两项判据，预期 43 项。

保留原真实 Stage 按下/松开、时停/回放拒绝取许可、12 次持有回调、错误票据拒绝释放、同票据幂等、角色身份与控制连续性、二次时停/回放及最终清理。只在运行器创建的私有副本中，把准确原配置 `cooldown=0` 改为 `cooldown=120`；不改安装配置、存档、计数器或生产接口。持有时正冷却必须逐帧相同，释放后第 8 个实际 ENTER 回调必须仍为正且已经下降，随后自然到零，才发出下一次真实按键。

使用冻结 Sand003、early2 D356、host03 29D36。安装准入复用 `recovery-paint-native-cpu-rv83-v2` 的准确 RV83D8；私有运行仍注入 RV7852。host03 直接核准确独立复核回执、构建清单和所有读回字节，本驱动不注册绘制观察器。复用原生命周期编译器、原私有 native runner；排队取得登记后再次核 22 项安装与准确输入。单实例原 3 GiB 启动门槛、独占 AIR、取消、只清理自有实例均不变。新输出发生准入或结果拒绝也保留失败回执。

根会话审核后串行执行（此目录只准备与离线检查，未编译或运行）：

```
python -B -X utf8 experimental/recovery-sandy-hold-native-cooldown/check.py
python -B -X utf8 experimental/recovery-sandy-hold-native-cooldown/prepare.py --output build/m52/recovery-sandy-hold-native-cooldown-driver-01 --build
python -B -X utf8 experimental/recovery-sandy-hold-native-cooldown/run.py --drivers build/m52/recovery-sandy-hold-native-cooldown-driver-01 --output build/m52/recovery-sandy-hold-native-cooldown-01
```

未覆盖：`esandyenabled=1` 时的敌方手动补步、完整双人旅行的活动期回退、加载性能。仅看到 enemyEnabled 为 true 无法证明实际敌人补步，所以保持 `enemyManualStepQualified=false`，不制造通过。离线解析器中的合成记录仅用于拒绝错误证据，绝不计为原生功能通过。
