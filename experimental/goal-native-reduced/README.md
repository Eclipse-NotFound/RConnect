# 同一原生跳跃的显示模组排除对照

仅准备隔离运行入口，不编译驱动、不运行游戏、不改正式选择。准确正式组合为 RConnect 78C052 / roomfix5、宿主 A796；直接复用 `goal-three-issues-native-drivers-02` 的原始跳跃驱动与 18 秒动作、6/6 原断言、完整运动观测。不是 CPU 采样驱动，不引入样本枚举开销。

官方选择器在测试副本内取消 LightAndDarkness、RealisticVision、ContinuousScene，保留其物理 SWF 和其它 11 个模组。实际每端必须在本轮唯一 AppID 的 ModLoader.sol 中证明同一新 session 的 requested/ok 均恰为这 11 项，err 为空；配置报告或“未扫描到类”本身不授运行资格。原始 SOL、解码状态、选择器日志和完整物理清单均由原 selector 留在本轮 cooperation/selection。

薄适配只展开两份已冻结 Python：原运动外壳 5 处替换（新增输入指纹、独立确认原 shared runner、跳过官方选择器的非 AIR 通知、允许已结束且准确记账的选择器进程、仅实际启用 11 项进入 inputs.modules）；旧 selector 2 处替换（公开已有登记回调、600 秒专用场景限制改为原跳跃的 300 秒）。原 shared runner 内仍仅既有的选择副本/按启用项列清单两处适配。展开全文、精确差分、旧新指纹保存在新输出中。未改任何旧文件。

共享登记、双人 6 GiB 启动与 512 MiB 运行保护、300 秒原超时、后台私有桌面、独占、真实 Littlepip29 只读复制、普通房偏好、原遥测配置忠实复制、错误扫描、22 项安装前后核验和自有副本/PID 清理均保留。CS 的偏好文件仍按原刺激设置为 false，但独立 loader 证据才用于确认 CS 未加载。不同随机人口/出生与后台调度仍须在解读中保留，关闭三者后的差异不能直接归因于其中一个模组。

根执行入口（本目录只做静态预检）：

```text
python -B -X utf8 experimental/goal-native-reduced/run.py --drivers build/m52/goal-three-issues-native-drivers-02 --product build/m52/recovery-room-production-05 --case native-jump --check
python -B -X utf8 experimental/goal-native-reduced/run.py --drivers build/m52/goal-three-issues-native-drivers-02 --product build/m52/recovery-room-production-05 --case native-jump --output build/m52/goal-native-reduced-jump-01
```

最终须同时核 `result.json` 原功能/观测检查及 `reduced-result.json` 的实际 11 项加载资格。后者也绑定 cooperation 中 `reduced-selection-result.json`、原始 SOL 与日志。通过仍不自动代表性能或视觉流畅度达标，需与全组合原刺激数据比较。
