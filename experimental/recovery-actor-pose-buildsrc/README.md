# recovery15 完整隔离源码

准确从冻结 `build/m52/recovery-14` / `225a7940…efbe5f7` 复制全部88份AS源码，只叠已实跑54/0组件的 `UnitPresentation.tick` 单段覆盖，并将入口版本字符串改为 **0.2.24-recovery15**。其余86份文件逐字节不变；不更改活动13源码、安装文件或已有冻结目录。

[integration.json](integration.json) 可直接由正式 `prepare_recovery.py --source` 消费；记录准确14二进制、源码清单、原manifest、覆盖来源及实际组件的冻结源码、SWF与结果指纹。`ancestor-integration.json` 是14的原字节祖先记录。差分分为 [actor-pose.patch](actor-pose.patch) 与 [version.patch](version.patch)。

实际组件 `build/m52/recovery-actor-pose-fast-component-01` 已由主会话串行运行：54项通过，0失败，退出0，安装与源码未变，组件SWF `0316e8993b4c0b9ad0405bca542e5d36d48997a1b9bc33ee9663a60f0c753a2d`。结果与范围见 [component-review.json](component-review.json)：测试调用完整旧/新类，时间和原生依赖在边界受控；不包含原生枪口资源帧脚本、不提供整体性能资格。

本目录仅准备完整构建输入，未编译15、未启动AIR。生成器复用上一轮 `recovery-wall-encode-buildsrc/prepare_sources.py` 的指纹/清单工具和既有冻结结构；**没有新增编译或部署入口**。

主会话先验证，再通过现有入口编译（新输出目录必须不存在）：

```powershell
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/recovery-actor-pose-buildsrc/prepare_sources.py --verify
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 tools/validation/prepare_recovery.py build/m52/recovery-15 --source experimental/recovery-actor-pose-buildsrc --version 0.2.24-recovery15 --build
```

随后用相同固定密集 driver02 与原门槛对照。14普通密集仍失败的记录不变；54组件通过只证明这处等价范围，不保证密集场景更快，不能把gotoAndPlay采样归入本优化的节省量。
