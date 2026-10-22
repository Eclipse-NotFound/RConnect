# recovery21 定向原生复验

准确候选为 `build/m52/recovery-21`，SHA `9ac7ede757c253bbf61e0c44334870b4a95112f976c1b40f2f390822a8b7e7ba`。安装仍是回退后的574D；本报告不授予整包发布资格。

## 驱动来源与原失败

`recovery21-targeted-drivers-01` 的两原生入口及aura组件编译成功，但旧impact组件裁剪闭包缺少 `ProjectileExplosionVisuals`，整次构建失败。记录保留，没有用已生成的部分SWF直接开测。

`recovery-native-only-drivers/native_only.py` 只把原准备模块的可选 `COMPONENTS` 置空，其他源码冻结、生产声明、选定入口及原生运行器均不变。新02构建成功，绑定准确21；不产生impact组件通过结论。

## 双向玩家念力光晕：通过

- 原入口 `PeerGripTestDoc`，驱动 `build/m52/recovery21-targeted-drivers-02`；结果 `build/m52/recovery21-peer-grip-01/result.json`，原生运行 `d460ff8f14`。
- 主侧296/0、加入侧295/0，双方16个round完整、DONE/version/连接成立，无运行错误。原八类情形各交换施法侧一次：拒绝抓取、不挣扎、挣扎、收回许可、抛掷、共享暂停、重置、换房。
- 检查包含原生Q/E动作、双侧身体最终颜色/GlowFilter、真实舞台像素贡献、释放及换房后的清理。安装22项无变化，完整冻结输入未变，自有host/join/frozen副本已由原运行器清理。
- 原始16张PNG保留于 `build/cooperation/d460ff8f14`。根实际查看了双方round1/9的4张raster-with、受抓方的2张raster-without及2张released：四个抓取视角均有绿色身体轮廓光晕；只移除GlowFilter的对照无该轮廓，释放画面无残留。此目检覆盖8张，不将其写成全部16张逐一目检。
- 这是准确21的本项实际功能通过，不能代替密集场景或加载耗时验证，也不赋予全部武器/掉落动画资格。

## 单发原生高速弹体：本轮通过

同一准确21及同一02驱动，`NativeFlightContinuityTestDoc` 结果在 `build/m52/recovery21-native-flight-01`，原生运行 `cc7e8dfe50`。主侧63/0、加入侧77/0，8组完整；独立 `flight-summary.json` 检查也全部通过，无缺组/重复组/运行错误。

最终RENDER中的实际本体、像素贡献、轨迹误差、方向、唯一映射、相对源端的显示间隔、原生接触尾段位置/帧/寿命及自然移除均参与断言；尾段短暂停留按原生行为分开，不冒充飞行停顿。八组对侧最大可见帧间隔为52/57/71/64/67/65/65/60ms；门槛保留原来相对源端的规则，没有改为固定宽松值。所有安装项和冻结输入未变，自有副本已清理。

本测试是单发轨迹的功能连续性验证，原结果明确 `dense_fire_qualified=false`、`performance_qualified=false`。不能用它覆盖密集前两段失败，也不能推及尚未在21重跑的玩家跳跃、念力物品、容器掉落及完整武器矩阵。此前其它候选的高速失败保留，不把单次通过归因于两处解码优化。
