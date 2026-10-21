# 酸性炸弹地面粒子原生验证

状态：第三版已编译并完成 `recovery-acid-native-03 / a5dc1bb2ee`：主48/0、加44/0，四轮完整、独立验证8结果和24 PNG/JSON通过，全模组无报错、22项输入不变，自有副本清理。双向干地和水中代表Part小幅截图已目检，仅功能资格，不是帧率或全特殊武器资格。第一版 `recovery-acid-native-01 / 3cecbcf64b` 在 `boot round=-1` 超时；第二版 `recovery-acid-native-02 / dcf973ba67` 四轮酸液判据通过（host 46/0、join 42/0），但两侧 FA 报 Error #1009，整体失败保留。目标候选为 `build/m52/recovery-09`（`0.2.24-recovery9`，SWF SHA-256 `1507686cd0811f6e6697a663ceed08ed7f85c8562399d50ccc79a891f8503acf`）。安装仍574D，不修改通用驱动、生产源码或已冻结结果。

纯离线验证器及源码约束：第三版 32 项检查通过（粒子观察和验收与冻结第一版不变；开场函数与冻结第二版不变）。最初运行有 4 项因沙箱临时目录不可写而未完成；夹具改用内存日志后，原反例与断言不变。该结果不表示当前 AS3 已编译或新一轮全模组通过。

第三版仅修装备准备。第二版 FA 堆栈均为 `fa::Runtime/after()`；只读源码中 `owned()` 仅从 `w.invent.weapons` 建立 snapshots，而 `after()` 对持有枪直接读 `snapshots[held].shots`。旧夹具的 standby LMG 用 `Weapon.create` 手工挂在 currentWeapon，未进入背包，形成明确的不完整装备状态。现临时复制并保存 weapons/fav/favIds：LMG 与 acidgr 都由 `Invent.addWeapon` 创建，LMG 用 `changeWeapon` 装备，酸性炸弹用 `favItem(...,29)` 设置快捷投掷；结束恢复原数组和原装备。未改 FA，不关闭任何模组、不放宽日志门禁。错误归因仍需第三轮无错实测确认。

第二版仅修开场：boot 上限由 70s 对齐成功 flight14/MSW04 的 180s；轮内仍为 **26s**。移除任意的 `Timer.currentCount>130`，改为房间 ready、非 busy／过渡／暂停、原生加载遮罩结束、角色存活，然后调用原生 `anim()`／`controlOn()`。不得改 hp／sost／t_die 或对真死者复活；再等至少两个完整 ENTER_FRAME 末尾观察到可操作、非 die 动画，双方均满足才握手。记录解除前及就绪／超时的原始字段，避免再次仅凭 die 标签推断。第一轮日志没有 animOff、hp、t_die、vblack 等字段，无法确定最后被哪项条件阻塞，只能确认尚未进入任何测试轮。

`AcidGroundNativeTestDoc` 从既有 `tests/ExplosiveVisualTestDoc.as` 的真实输入和双侧握手流程生成。差异在 `driver.patch`，源指纹在 `native-plan.json`。四轮依次为主侧干地、加入侧干地、主侧水中、加入侧水中。使用 G 输入触发真实 `PhisBullet`，没有直接调用接收器、生产视觉方法、Emitter、Bullet.step 或爆炸方法。场景固定为双方相同的平直碰撞走廊，冻结其他单位并临时停用近炸技能；不更改炸弹速度、重力、碰撞、引信及粒子寿命。

核对的不是 `acidexpl` 闪光，而是原生 `fe.graph::Part`、其资源 `visualAcid` 及最终舞台像素：

- 每侧实际出现地面 Part；接收侧不得多出本地伤害弹体。
- 原生 `inWater` 必须符合本轮 dry/water 条件。1.02 酸液在水中仍生成；只火焰排除水中路径，不能把该规则套到酸液。
- 源实际 Part 落在原生暴露地面：横向格中心随机偏移 ±2 像素，纵向等于 `phY1`。接收侧与源实际 Part 数量相同、一一配对，每轴误差不超过 **4 像素**（双方各自原生随机偏移）。没有放宽到相邻格，也不接受火焰的 `-33` 偏移。
- 实际动画帧与透明度改变；原生初始寿命为 100–129 帧；释放输入后自然倒数至零、移出对象链，显示对象离开舞台。
- 每轮每侧仅对一个实际可见 Part 取一对有/无该 Part 的小幅舞台位图（最大 150,000 像素），立刻恢复显示。`getVector`、PNG 编码及文件保存延至已观察粒子全部自然结束后。输出隔离应用存储中的两 PNG 和 JSON，适配器在游戏退出后复制并记录 SHA。绝不写角色存档。

本套不是弹道连续性或 FPS 基准，取图仍有运行成本，不用于声明性能达标。最多 256 个地面 Part 和 20,000 节对象链；越界明确失败。当前仅平地 dry/water，不覆盖坡面、分房或暂停。原先飞行套件阈值不受影响。

## 源码检查与执行入口

以下相对路径均从 `mods/RConnect` 执行。使用现有 Python，避免生成 pycache：

```powershell
& $python -B -X utf8 experimental/recovery-acid-native-tests/generate.py
& $python -B -X utf8 experimental/recovery-acid-native-tests/test_offline.py
& $python -B -X utf8 experimental/recovery-acid-native-tests/native_tool.py prepare --source build/m52/recovery-09/src --output build/m52/recovery-acid-drivers-03 --build
& $python -B -X utf8 experimental/recovery-acid-native-tests/native_tool.py run --drivers build/m52/recovery-acid-drivers-03 --output build/m52/recovery-acid-native-03
```

对照版本用相同冻结驱动，另选新输出目录并添加 `--control`。适配器保留通用 runner 的测试登记、隐藏独立桌面、内存资格、22 项安装输入不变检查、工具指纹、双侧四轮完成和日志失败判定；只增加一个入口，不构建旧通用组件。每次编译失败或测试失败保留原目录，使用新编号，不覆盖旧失败。

`result.json` 仍由原 runner 生成，不重写；`acid-verification.json` 为冻结独立验证器的逐轮 Part 配对及原始 PNG/JSON 证据，二者均通过才算本套通过。原版 574D 若只显示爆炸闪光而无远端地面酸液，必须保持失败，不能把缺失粒子、缺失轮次或未退出粒子忽略。

机制来源：1.02 `Bullet.explosion/explLiquid`、`Part.initVis/step/setNull`、`Emitter.cast`、`AllData.xml` 的 `acid` 参数；原生文件只读。
