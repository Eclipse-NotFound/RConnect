# 宿主原生单位采集：有界只读判定

2026-10-22。来源为准确18的GameBridge、MirrorHitUnit、编译声明，以及原生14采样a6a7e27789。仅新增本文，没有生产修改、组件、编译或AIR。没有把旧样本冒充18新采样：18与14的probe、probeOptional、unitFields、readEnemyMotion、readUnitsSnapshot五个方法逐字相同；完整GameBridge因墙面接口变更而不同。

**结论：有一处真实可达、尚未做过的限定优化方向，但还不是可直接合入的修改：为已确认原生Unit的固定字段组提供专用读取，保留非Unit的原unitFields路径。优先只考虑22字段的defense组；不建议一次改写完整单位快照或合并两个采集周期。** 它省的是每字段重复类型/名称检查和已知公共变量的保护读，不省动画、网络采样次数或输出对象。现有采样足以支持一次小范围等价/成本证伪，尚不足以证明整帧收益；准确宿主字段核验未完成，当前停在提案边界。

## 实际成本与可达路径

宿主原采样共2318 CPU样本，重新从完整PROFILE行计算：

|包含式项目|全路径|在readUnitsSnapshot内|在readEnemyMotion内|
|---|---:|---:|---:|
|readUnitsSnapshot|216|216|0|
|readEnemyMotion|128|0|128|
|probe（精确方法名，不包含probeOptional名字匹配）|228|121|36|
|probeOptional|141|66|22|
|unitFields|113|90|22|

unitFields自身叶样本30，其中快照23、高频运动7；全路径GC叶15。快照内有26个`probe←unitFields`叶样本、12个`activation-object←probeOptional←probe←unitFields`叶样本，另12个GC样本停在同样的activation栈下。不是只有源码推测，但这些行嵌套，不相加，也不能把113或216当作全部可节省时间。GC没有分配归属，不能断言全由字段读取造成。

`GameBridge:5581–5591`每个完整快照分别采motion8、grip7、targeting2、defense22，共39次unitFields字段读取。`5513–5514`高频运动分别采motion6和grip7，共13次。每次都会新建本组输出Object；motion/targeting还在调用点新建小字段名Array。

`probe:620–628`已有原生Unit快捷表，不能把它描述成所有字段都走try/catch：

- motion8、grip7、targeting2全部已入表，但每字段仍重复`o is Unit`、表查询、动态名称读取和undefined转换。
- defense22只有maxhp、armor_hp、shithp、invulner这4项入表。
- 另外18项是skin、armor、marmor、armor_maxhp、armor_qual、shitArmor、allVulnerMult、vulner、dexter、dexterPlus、dodge、transp、opt、mech、blood、mat、maxShok、showNumbs。它们在已知原生Unit上仍会经过类型/表判断、一次`name in o`，再进入probeOptional第二次`name in o`及受保护读取。公共1.02 Unit.as将这18项都声明为public var。

本轮仅证明调用和代码分支，不知道113个样本逐字段分配，不能声称18项占了固定比例。高频readEnemyMotion只有22个unitFields样本，且13项已走已有快捷表，不值得优先扩改它。

## 尚缺的编译与宿主依据

准确18 `tools/stubs/fe/unit/Unit.as`只有internal显示/反馈字段和少数方法，没有上述public变量，也未声明原生Obj/Pt继承。它是供当前内部访问桥使用的局部外部声明，不是完整准确Unit ABI。build_mod.py:77–87把这批声明编成GameCombatStubs并以external-library-path链接。因此不能直接写`var native:Unit; native.skin`便声称编译层已支持，也不能把Obj/Pt的字段随意塞成Unit自有变量而称为原样继承。

公共1.02参考链为Unit→Obj→Pt：dx/dy/stay在Pt，scX/scY/massa/levit/levitPoss/fracLevit在Obj，其余本组字段在Unit。该参考支持方向，但实施前仍需将准确目标宿主的公共slot种类、类型和继承与外部声明绑定，并保持外部声明不嵌入生产。`levit_max:*`尤其不能误写Number，opt为Object、vulner为Array。

这不是此前recovery-probe-fast-runtime那27项Weapon/Bullet字段快捷表；旧提案只添加武器/弹体字段，没有解决此处Unit防御组，也没有把一次组采集中的类型判断提到外层。不能沿用它的组件结果证明本方案。

## 最窄安全差异面

允许的形状：每个源单位只取得一次`u as Unit`；在原defense调用位置，原生分支按现有22项顺序读确定公共变量，逐项执行原null判断和数组处理；非原生仍完整调用原unitFields。若只从defense开始，motion/grip/targeting、全局probe、玩家readSnapshot、接收applyUnitFields都保持不变。新helper应产生新Object，与旧结果保持相同属性存在性、数值、浅引用和数组副本。

这不需要跨帧缓存，没有“上次值未变就跳过”逻辑，也不持有上轮输出。若将来扩到motion/grip，只能使用同一原则，不能借此复用旧快照值或缩减字段。

必须保留的反例与边界：

1. **动态对象/Proxy/不属于当前Unit定义的对象**：不得按类名字符串判原生；保留旧逐字段probe。getter抛错后旧逻辑将该项当null并继续，不能改成整个组一次try/catch、提前终止。Proxy的has/get副作用及次数不能变化。
2. **第三方Unit子类**：只有经准确宿主核实的继承public var才可走原生路径。它们不能被普通AS继承getter覆写；其他扩展字段仍需通用读取。不能因构造器名称不是原版就改变输出，也不能把width、tr等可选字段扩大进来。本轮没有新增编译反例或实际第三方子类验证。
3. **采集时间顺序**：只提前判断类型，不能提前把值都装进临时struct。原对象字面量中death、view、body、weapons、aura等捕获方法穿插在字段组之间；它们可能触发状态更新。defense必须仍在weapons/aura之后读取，cx/cy也保持之后。
4. **字段转换也有顺序**：vulner数组元素的Number转换可以执行自定义valueOf并改变后续dexter等字段。必须读完当前字段、完成原numbers/concat操作，再读下一字段，不能先读完全部22个槽。若扩到grip，levit_max的Number转换同理。
5. **缺省与值语义**：null/undefined省略属性；false/0保留；NaN、Infinity不能偷偷改为0。vulner用原numbers逐项数值化，其他Array仍concat，Object仍保持浅引用。稀疏数组/特殊元素、opt为Array、数组被后续修改均需原语义。
6. **两个周期不可共用结果**：Session:1063先broadcastWorldState，之后200ms到期才readUnitsSnapshot；前者的采集/发送与其它方法可能改变状态。合并同一Timer回调的两份motion/grip会改变读取时点；跨Timer复用更会损失实际动作变化。消息频率、包内容和数组快照生命周期必须保留。

## 是否值得实施

**值得的上限是一次defense专用读取的隔离等价与成本证伪，前提是先完成准确宿主声明核验；不建议现在扩成全量强类型采集层。** 快照内unitFields90样本的确比上一轮单个literal有更明确依据，但可省部分只是其中的分派/探测；输出对象、vulner转换、字段采集本身仍需保留。它不直接解释加入侧长帧，宿主更快也不自动等于两侧流畅。

可沿现有组件入口比较完整旧新采集调用而不是只测单个slot读取：稳定原生及子类、动态getter/Proxy、可选字段异常、null/NaN、XMLList levit_max、稀疏vulner、valueOf改后续字段、两次采集间突变、输出数组不别名。若局部收益不明确即停止；有收益后才有同输入原生对照理由。此处没有编写该组件或新框架。

## 输入与执行边界

- 原host.log SHA256：`35d83e706a362c9d81eef9cbfc675276a215ac0cacc85fe6a480be2ab94fb3e7`。
- 准确18 GameBridge：`3fe9bb83a16a57300e733806cddbe74ce55bcaf323bec15554814f4714eba967`；MirrorHitUnit：`e5339ba7481c4e14d90171939e4a8729a4b8812dddf27bce1a006dd65de79147`。
- 与14相同的方法正文SHA（从function起到闭合花括号，UTF-8文本）：probe `ae878103598cf240c51375aebd01501b4af3e3537012d7b1d4da4b0841f0a613`；unitFields `bdcbca8187160f468eeacc4acd438c256b76eb4d1996746b0838912fd75d0d2e`；readEnemyMotion `67e53a5542e10627d2d5dd61c192ae59119a86cc33c4952e0315cd42c80f4d89`；readUnitsSnapshot `9c9b13d90eee2fe575b58105570303c6782294c6f15f0018b2ef1d94c2f7eee9`。
- 公共参考Unit/Obj/Pt SHA分别为`3a6c2db7cca18045c6c6d753f15e2ae96fea6da1c97223ecd8f7f35b9756d66c`、`e835c6b3a2dce6568f24e4c365c36dbee9cda808131a0761bf6542a06edb9bb3`、`98f5fcf9a42a84e8d1374f73dfaed830c39a53d0b70ad5cba26e438922a799c2`。

一次尝试复用既有audit_native_slots.inspect_swf读取游戏、读取SWC内library并保存JSON的组合命令，被本机PreToolUse以`Protected target (binary-swf-use-release-pipeline)`拒绝，未执行。已取消该二进制核验，没有换工具重试、维护授权或修改二进制；后续只读文本源码与日志完成本文。故本文不声称已新核验准确宿主slot、SWC编译产物或获得运行收益。
