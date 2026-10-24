# 当前 A796 宿主：首次栅格等待桥

2026-10-24。这里只准备隔离源码、窄方法保留器与构建入口；本目录作者未启动 JVM/AIR，未替换正式 SWF。构建通过也只代表字节码/成员/资源核对，不能给加载时间、当前 RC/Sand 拼接或玩法资格。

准确基底是正式 A7968271…238B7。根已登记导出 `build/m52/recovery-room-first-raster-current-source-02` 的 World/Game/Grafon 三类 AS 与 pcode，回执 FD125E64…57A66、两条 JVM exit 0、输入/22 安装不变。source01 因本地日志解码失败保留失败，不改判。完整当前 XML 来自 CS 的 A796 tint 构建，1D2642C7…338DA；不是拿 BEFC/ACC/2D 的类假冒当前宿主。

旧 2D415D…3DD29 仅提供经过旧 early2 验证的桥合同：

- World：`step`、`exitStep` 及两个私有 helper。hold 时原生 exit/camera/GUI 继续，exitStep 后再查 hold，阻止同帧 Land/脚本推进，exit16 延后控制恢复，换档/新开流程取消旧票据。具体死亡取消仍由 RC 的真实身份/死亡检查负责。
- Game：新增 `rconnectTravelBridge:Function` 和版本常量 1；只在 `enterToCurLand` 最后的进入副作用完成后通知 `constructed`。不导入旧 adopt/announce、XML helper 或旧地图接管逻辑。
- Grafon：`sceneOpen` 在 clear 前取得同一 waiting/unpainted 票据；仍保留 prepare、对象、光照、相机相关准备。sceneEnsure/sceneTick 在 waiting 时返回；完成必须 resident>0、真实 sceneViewReady；普通 drawLoc 清旧票据。三个新 helper/getter 与旧合同逐词相同。

总计 8 个现有方法、5 个新方法和 4 个新字段。其他当前 AS 方法逐词不变，包括 CS 颜色、相机和大场景逻辑；源码证明在 `source-manifest.json`。`patched-readback/` 是相对准确导出的逻辑补丁；`source.diff` 可直接审查。`import/` 额外恢复两处 FFDec 不可编译伪指令方法：sceneDrawSteps 的 i/j 自增，以及 A796 sceneEntitySameColor 的既有可编译等价源。`donor-only.diff` 单列它们；这两个方法的供体字节码绝不进入最终产物，最终保留 A796 原始方法。

## 保留方式

不采用整 Game/Grafon 导入结果作为候选。FFDec 仅产生方法供体，随后从 A796 完整 XML 原骨架出发：

1. 常量池旧前缀逐项保留，只接纳供体追加项；新私有命名空间以当前真实旧声明及同类实际使用的唯一词法作用域对应，不按全池同名猜测。
2. 八个目标方法回填原 index，五个 helper 追加。拒绝目标中未支持的方法/类/slot 索引指令；原方法签名不变，只有明确的 NEED_ACTIVATION 位可随实际 body 变化，捕获 scope depth 必须相同。
3. 四字段和五方法的 traits 追加到原列表末尾；旧 trait 顺序/属性和类/script index 原样保留。新 slot/disp_id 设 0，交 VM 在旧成员之后分配；目标 body 不允许硬编码 slot 指令。原三类实例构造器全字节保留，未初始化 Object ticket 沿原生引用类型默认 null。
4. 不复制供体 cinit：Game/Grafon 原 cinit 必须无分支/catch/activation、只有末尾 returnvoid。保留原全部指令，仅在 return 前对 class local0 写新 bridge=null，Game 另 `initproperty version=1`；max_stack 至少 2。原静态字段初始化顺序不变，新字段无回调/外部副作用。这个明确增量另入回执。
5. 序列化后复用旧 `method_transplant.py` 的原始 tag 拼接，只替换 ABC0。最终 SWF 再导出 XML，要求与 retained XML 完整一致；全部旧非目标 body/metadata、原构造器、旧 traits、脚本、常量前缀和其他 ABC 原样。当前相机与颜色方法因此保留原字节，不依赖供体反编译语义。

`retain.py` 是本次三类/成员白名单接线，复用既有 ABC decoder、prefix 和 raw-tag splice，不是通用新补丁框架。其新成员形状尚须实际供体导出验证；任何匹配/作用域/初始化形状不符都停止，不静默扩大许可。

## 入口

从 `mods/RConnect`：

```text
python -B -X utf8 experimental/recovery-room-first-raster-host-current/prepare.py --prepare
python -B -X utf8 experimental/recovery-room-first-raster-host-current/prepare.py --check
python -B -X utf8 experimental/recovery-room-first-raster-host-current/build.py --check
```

仅根后续执行：

```text
python -B -X utf8 experimental/recovery-room-first-raster-host-current/build.py --build --output build/m52/recovery-room-first-raster-host-current-01 --registry-wait 900
```

六条 Java 串行，原共享登记、512 MiB JVM、1 GiB 启动/512 MiB 运行保护、300 秒单命令、自有 PID 回收和 22 安装前后一致保留。用实际当前安装记录，不把旧编译环境改标。`build.verify(output)` 只读回传完整回执，校验冻结来源/工具、imports、所有产物哈希和方法/资源审计。`validated=true` 的含义限于该静态宿主验收；`air_started/installed/gameplay_qualified/performance_qualified` 均仍 false。首绘 RC 六类和 Sand003 由根另行绑定验证：其中 WIV.front 在票据待绘时不读取 A796 保留的旧 frontBmp，不额外引入 surface 桥。缺桥不能冒充此路径有效。
