# B 安保终端：独立覆盖与原生接口

2026-10-25。仅从 `build/ab/b190-field9-build/src` 与 `build/ab/native-hooks-019` 生成；不涉及 A 版、release 或安装文件。这里没有运行 AIR/JVM，尚不代表玩法已通过。

## 行为

- 宿主设置，默认共享破解。切换只影响之后的新授权；已取得的权限保留。
- 同一个终端保留两人的锁、失败次数、成功结果、待完成操作；仍调用原生 `Interact.act` 计算。两人同一步完成时各结算一次，但物件及其计时只 `step` 一次。
- 个人 `pers.security` 继续决定原生结果：0 为安全权限（两人都取得时才全局休眠），1 为原生重编程和经验，2 为原生无经验重编程。
- 未获权限的玩家仍可被重编程炮塔发现、攻击，并能反击；宠物及玩家地雷的归属沿玩家权限识别。
- 原存档/脚本已全局休眠或重编程的炮塔不被缩窄为个人权限。无人房由既有 B 房间实例保留；整图离开才清理本次世界的权限表。

## 源码合并

`src/` 只含相对 field9 的 10 个变动文件，`patches/` 给出逐文件差异，`source-manifest.json` 给出基线和覆盖指纹。请与相机/UI、同步性能覆盖三方合并，不能直接拿本目录覆盖它们的同名文件。

新增控制器是 `authority/SecurityTerminals.as`，其余为生命周期、逐玩家执行、逐物件执行、现有命中回调、加入侧场景数据和 UI 接线。**PlayerActor 的新增进度文案**若由另一覆盖加入，应取 `security.capture(interaction,id).actionText`；直接读真实 Interact 会读到外层恢复的宿主个人状态。动作时间仍取本人的原生 `t_action/mt_action`。

## 原生构建

```powershell
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' 'mods/RConnect/experimental/b-field-security/native_build.py' --check
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' 'mods/RConnect/experimental/b-field-security/native_build.py' --build --output build/ab/native-hooks-020
```

若 020 已存在，改用新的唯一 `native-hooks-*` 目录。`--prepare` 仅冻结小体积 donor 与命令；`--build` 自动使用共享登记、逐个启动 FFDec、检查内存、保留失败证据。`--verify --output ...` 只读复验结果。

原生输入必须是 SHA-256 `1028a49a4af4d8e1b4bd215a44d38a742723438e24056e2336ea875d82efdba9` 的 native019。不要从 baseline001 重跑旧 patch_native.py。

`native_retain.py` 只移植 5 个短 helper；对原 `Interact.allAct`、`UnitTurret.findCel/control` 插入准确入口字节，原方法尾部、相对跳转及元数据保留，异常区偏移统一增加。Unit 新增两个静态 trait：String const 能力标记和默认 null Function 回调。**不替换任何构造器或 static initializer**。旧 `b3-v12` 标记不变，独立能力标记为 `b-security-v1`。

构建必须通过原常量池前缀、所有旧方法索引和元数据、非目标方法字节、原 class/script traits、其他 ABC、SWF 原始资源标签和 XML 序列化往返断言。产物只从完整原019 SWF取原始资源标签并换入经审计的 ABC0。编译成功和字节保留不等于 AIR verifier、玩法或性能通过。

## 验证入口与剩余实测

`tests/authority/SecurityChecks.as` 为可接入现有隔离 Probe 的同步检查；双方真实原生玩家组装完毕且同房后调用 `SecurityChecks.run(session,check)`。它要求 `config.probe=true`，会清理隔离房间并建立测试场，绝不能用于用户游玩实例。测试源码目录不必进入正式发布包。

覆盖个人失败次数、同 tick 双人完成、共享和分别破解、切换后保权、skill0/1/2、命中许可、真实 `findCel`、原先全局安全状态。此入口尚未运行。它不能替代以下验收：真实鼠标与按键启动/中断破解、双方进度条和提示文案、炮塔实际开火/命中、分房往返、背景房、死亡复活、断开后继续单人、时停和 SATS，以及普通密集战斗的开销对照。

本分支执行了 `native_build.py --check`：22 个构建输入校验通过，未启动 Java；3 个 Python 文件语法检查通过。根会话已报告 native021 隔离构建成功；native020 因 FFDec 日志锁权限失败的证据保留。native021 的运行与字节证明由根会话保存。

产品编译修订 1：field13 编译发现 Flex 不接受 `capture()` 在 `try` 内返回且存在 `finally` 的写法。改为 `try` 赋值、`finally` 恢复原状态、最后 `return result`，不改变捕获和恢复的顺序。只修改 `SecurityTerminals.as` 及其 product 指纹；native donor、native 项和构建脚本均不变。完整 manifest 被原生构建脚本记录为输入，故此产品修订会改变当前 manifest 指纹；native021 证据应与其原始冻结 manifest 核对，不能把本次产品变化当作原生变化。修订后的产品尚待根会话重新编译及实机验证。
