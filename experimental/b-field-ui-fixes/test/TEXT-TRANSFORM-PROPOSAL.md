# 文字变换的局部性能核查

2026-10-25。以 field21 为参照；只有外置组件 helper，未改产品、未编译或运行。不能将单轮加入侧密集性能退步归因于这里。

## 已确认的调用范围

新增 `VisualPose.apply` 末尾 `transform(display,s)` 只在 `display is TextField && s.text!=null` 时执行，增加一次 Matrix 分配/赋值和 alpha、visible 写入。函数前面已经执行过同样的变换，后面还会重新写 alpha。

敌人身体、敌人武器、血条、场景物品及特效：完整确认调用 apply，中间插值调用 motion，motion 没有新增末尾变换。玩家身体/武器和投射物在 ClientReplica 中即使显示插值仍调用 apply，因此其素材若含 TextField，也会经过该分支。自己的移动预测还可能再次 applyPlayer，不能笼统说它只在所有“确认帧”发生。

`hpBar` 的原生脚本仅声明 armor/bar/goldstar 三个 MovieClip，`hpBarBoss` 声明 bar/goldstar；这不能证明嵌套匿名素材没有文字。尝试只读解析 SWF 资产被本地保护以 binary-swf-use-release-pipeline 拒绝，未重试或绕过。helper 的 assets 输出会直接列出五种真实素材当前帧内的 TextField 路径。`coverage(frame)` 统计实际离散确认内各类文字配方数量，不将敌人数当成文字调用数，也不是完整运行次数计数。

## 最小待测方案

对有文字配方的 TextField 跳过 apply 前面的 transform，保留文字导入、去除解析器附加换行、恢复滚动位置之后的现有 transform。所有其他显示对象及 motion 路径保持原样。这样仍使用源矩阵进行最后恢复，不依据“文字没变”的缓存而跳过更新，也不撤销 PoseTween 的真实抖动修正。

这只是待测的顺序调整：原生布局是否依赖首次变换，必须用真实文字资产和多种布局条件核对后才能采纳。

## 外置 helper

`BTextTransformChecks.run(mod,domain,check,log,iterations=0)`：

- 建立真实 visualNumb、visReplic、visReplic2 的文本对象，以及 CENTER/RIGHT/LEFT/NONE 四类自动尺寸文本。
- 24 轮改变文字、换行、折行、颜色、滤镜、透明度、可见性、缓存、反射/倾斜矩阵；每轮主动扰动目标位置，避免只凭缓存自证。
- 当前产品 `VisualPose.apply` 是参考；同时核对复写的当前文本分支与只延后首个 transform 的分支。比较完整文本/格式、布局尺寸、滚动、最终矩阵、颜色及父容器绘制图像。只有两份组件都与实际产品一致，才有资格比较它们的成本。
- `iterations=0` 不跑计时。显式传入如 4000 后，预热再交替顺序跑四轮组件计时；计时内无 bitmap、捕获、断言和 JSON 序列化工作。此数值只说明局部变换顺序的成本，不能宣称整帧改善，也不在最终四轮性能对照期间插入运行。
- `coverage(frame)` 可从实际确认帧统计文本分布；短命投射物事件和移动预测的额外应用次数不在这个静态数量中。运行中若要精确算调用次数，须另做诊断插桩，不能乘猜测的渲染频率。

没有修改安装版本。若组件等价失败，保留当前防御性恢复，先解释真实差异；不能删除测试或放宽一致性要求来换性能数字。
