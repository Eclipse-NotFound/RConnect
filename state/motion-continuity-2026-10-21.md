# A 版高速运动连续性修正（候选，未部署）

## 用户报告与本轮边界

2026-10-21 用户报告高速子弹/天角兽闪电、对侧念力物品、加入侧掉落物卡顿；随后补充角色高速移动与跳跃也卡顿。本轮沿安装 A 版处理，不恢复 B，不混入尚未合格的房间19或 motion1。

用户最终选择“暂不退出，先保留候选和测试记录”。停止本轮双人性能实测，不部署；不关闭普通游戏，不改真实存档。

## 准确基线与候选

- 基线：`build/m52/coop-bundle-04` / `0.2.23-coop-bundle2`，SWF SHA256 `574d2b51490ae8b25a1396555600f56a301f8a20ae50104c0e35cf2796441afe`，仍是安装版。
- 宿主：根 `pfe.swf` SHA256 `befcf0509e11fac9fef7afb834708b8b93752a14ae3d5cd72b42aa6d42f9b82a`。本轮不修改。
- 稀疏源码：`experimental/motion-continuity/src`；仅 `RemoteMotion.as`、`ProjectileVisuals.as`。
- 冻结候选：`build/m52/motion-continuity-02` / `0.2.24-motion2`，SWF SHA256 **`6e03c9a719bcd23c029ee61bef6a8dc334abd44d28e6e4885578b00b00f98cef`**。
- `prepared.json` 保存基线、源码、工具、编译器输出和覆盖层指纹。正式优化编译成功，未安装、未声称原生验收通过。02仅修正构建清单路径，使其可被现有原生对照工具读取；与01的所有生产源码和构建工具逐文件SHA相同，未将二进制哈希不同称为同字节复测。组件测的是该相同源码，不是完整SWF原生执行。01与其原清单保留。

## 已定位并修正

1. **普通时钟校准直接跳位。** `RemoteMotion.pushTimed` 在测得更低的传输延迟时立即增加显示进度，即使两个 `sample(now)` 时间完全相同也改变位置。800px/s 固定输入中，仅25ms校准就让玩家/念力物品跳20px。候选让普通小校准由已有平滑变速逻辑消化；保留原来大积压快速恢复分支。不增加固定播放延迟，不外推。
2. **新点重写已播放的曲线。** 三次曲线每次采样重新计算末端斜率。低延迟念力或首批掉落已经播到段中间时，后续点会让同一时刻的显示位置改变。固定回放分别产生10px、8.91px跳动。候选在一段开始播放时固定该段斜率；新点只参与后续段，保持接收端点范围。
3. **移动闪电被排除在位置插值之外。** 原生 `Bullet.step` 对天角兽闪电使用与普通弹体相同的世界坐标更新；它是移动的 spring=1 弹体。旧 `tickBeam` 按图像类名额外排除两种闪电。候选允许几何尺度一致的移动闪电在已收到点之间补位置，仍保留 spring>=2 光束、火焰及尺度变化的离散规则、原生结束时刻和禁止外推。

未改碰撞、伤害、AI、发包频率、实体归属、房间交接或其它模组。本轮没有证明这三处是所有实际卡顿的唯一原因。

## 验证证据

全部组件使用实际 AS3 生产类、固定时间输入、自有隐藏 AIR 桌面与独立 AppID，登记到共享测试表。没有加载游戏本体；原生武器/传送边界在夹具中明确抛错，不能用这些结果替代原生效果检查。

| 输出目录（build/m52 下） | 结果 | 含义 |
|---|---|---|
| motion2-clock-baseline-01 | 31通过 / 6失败 | 精确旧版复现玩家/物品20px校准跳动与念力/掉落9–10px曲线跳动；失败保留 |
| motion2-clock-candidate-01 | 37 / 0 | 相同新增用例通过；旧念力断流恢复、两组实际掉落流量回放、有限特效播放速度、敌人动画时钟检查均通过 |
| motion2-clock-legacy-01 | 18 / 0 | 原有2–16帧积压、抖动、暂停/迟到末点、旧无时间戳调用和大位移阈值检查通过 |
| motion2-projectile-baseline-01 | 13 / 2 | 两种闪电在15个显示间隔只移动3次；普通子弹、光束/火焰与结束边界通过 |
| motion2-projectile-candidate-01 | 15 / 0 | 两种闪电均15次连续移动，仍不超出最后点、按原结束时刻消失；光束/火焰边界保持 |

组件结果中的 `installation_unchanged`、`source_unchanged` 均为true。合计不是新功能数量，不代表游戏FPS或整合发布资格。

`motion2-baseline-fast-01` 尝试准确旧版实机对照时，运行器检测到已有AIR PID86656/89852并在启动前拒绝；无run ID、无新增游戏进程，不能计作运行失败或性能样本。之后只读核对剩余86656命令为根 `application.xml -nodebug`，确认为用户游戏。内存当时约7–8GiB可提交余量；实际原因是测试独占条件不满足，不能写成内存不足。用户明确暂不退出后停止该实测安排。

## 尚未完成与接续

- 候选未跑真实双人高速角色/跳跃、真实念力物品、容器掉落与闪电连射；密集场景CPU/帧率未对比。
- 微小收包校准修正不涵盖大积压寻址、源端帧本来缺失、网络批量迟到或原生整帧变慢。曲线缓存有少量额外对象，应在原生密集测试核对开销。
- 接续时重读安装22项、确认用户已退出和6GiB门槛，按共享登记串行跑相同驱动旧/新对照；使用新输出目录，禁止覆盖本轮红结果。检查渲染最后阶段的实际位置、移动样本/静止间隔和CPU，不只看收包数。
- `tools/validation/prepare_motion_continuity.py` 冻结/编译候选；`run_motion_continuity_checks.py` 执行组件；原生运动对照可复用 `run_motion_comparison.py` 的 fast-motion、continuity、pause-timing、density。角色跳跃、原生闪电和抓取应补对应实景，不把受控直线夹具当完整覆盖。
- 其它会话独立处理：`native-loading-ui`（基于房间19）、`peer-player-aura`（玩家被抓光晕）、`wall-impact-effects`（击墙火星/命中特效）。均已协调，本会话统一集成，禁止互相覆盖。ProjectileVisuals最终合并时将本轮tickBeam变更与命中特效receive/tick/reset增量分别核对。

## 可复现入口

```text
tools/validation/prepare_motion_continuity.py build/m52/<新候选目录> --version <新版本> --build --registry-wait 300
tools/validation/run_motion_continuity_checks.py --source build/m52/motion-continuity-02/src --output build/m52/<新组件目录> [--entry RemoteMotionClockTestDoc|ProjectileContinuityChecks]
```

独立桌面运行需按当前工具权限执行；不因默认沙箱拒绝而退回前台。编译/组件会登记game占用以免干扰其他性能测试。组件的替代边界与实际复制源码清单均保存在每轮inputs.json。
