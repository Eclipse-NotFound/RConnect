# A Sandevistan travel-hold 独立组件

2026-10-22。只准备源码与离线静态检查；尚未编译、尚未运行 AIR，也没有改安装版或 Sandevistan 原项目。根会话负责串行构建和实测。

## 根会话入口

在 `mods/RConnect` 下：

```powershell
python -B -X utf8 experimental/recovery-sandy-hold-components/prepare.py --verify
python -B -X utf8 experimental/recovery-sandy-hold-components/run_component.py --output build/m52/recovery-sandy-hold-component-01
```

第二条复用 `tools/validation/run_recovery_component.py`，保留共享 game 登记、1 GiB 组件内存门槛、60 秒运行期限、原始失败、源码与安装前后指纹、非空逐项结果和固定断言数量校验。它不加载完整游戏。运行目录必须全新，不能覆盖旧失败。`inputs.json` 与 `handoff.json` 给出准确冻结输入。

## 实际测试对象与 76 条检查

组件直接使用提案 `SandyTravelHoldBridge.as`，原 SHA `5b195a60fedcd94b416a7f0f3fa82db5cc5423a843ec3d90ef6bcc78037a2890`。按根会话指令，仅给 `query`、`acquire` 的 try/catch 之后补不可达的 `return null` / `return false`，解决当前 ASC 对明确返回的识别问题；不修改原提案。新类 SHA 见 `static-checks.json` 的 `component_bridge_sha256`，可与正式 builder 逐字对照。

`SandyTravelHoldChecks.as` 调用这份真实类的公开方法；只用外部 reader 与带异常 getter 的轻量 World 身份对象提供输入，不复制 bridge 算法，不冒充完整 Sandy 游戏逻辑。

| 断言 | 覆盖 |
|---|---|
| 01–09 | 发现契约、隐藏载体、无 owner 快路径、query 只读值与新返回对象、身份拒绝 |
| 10–28 | 空参数、读失败、active/replay/未知阶段/debug 拒绝、idle 正常准入、无游戏字段写入 |
| 29–46 | 同 owner/id/身份幂等、不同 owner/id 竞争、精确 release、异常中取消、后继票据不被旧 release 清除 |
| 47–67 | World/Game 替换与缺失、错误 query 参数、异常时持票保守保留、异常恢复、空状态与取消 |
| 68–76 | 完整生命周期无状态改写、不同载体实例相互独立、reader 缺失、release 后重新执行资格判断 |

两点是明确边界而非漏洞修正：同一已持有票据重入不重新读 phase（35）；两个同名载体有各自 owner（70）。调用方必须保存实际取得许可的那个对象，不能凭同名新对象取消旧票据。组件会保持这些原类语义。

## 准确 CEC6 入口补丁的静态检查

基线是 `mods/Sandevistan/build/out/keybind-20261015-006/frozen/src/SandevistanMod.as`，SHA `ad931f4f0cc374f9f084f61227d6b1fd1bf61e7a156cd69e2b0c79141584492d`；同目录产物和 build-input 绑定 CEC6。只在 Python 内存中应用准确 7 个 hunk、22 行新增，CRLF 结果 SHA 必须为 `577679b9da303a2959e50512a51c5cd0e39f37dfc46416615f8fb15ecf0cd352`，不写出修改后的完整 Sand 源码。

共核对 94 个原方法：88 个逐字不变；6 个变动只允许明确的 init 载体初始化或 hold 分支。去掉这些精确新增后，每个方法及整个文件都逐字回到基线。按这个准确基线的六空格方法格式提取，不声称是通用 AS3 解析器。

| 入口 | 静态控制流约束 |
|---|---|
| `onFrame` / `startSandy` / `onMouseDown` / `onKey` | hold 判断必须是首条语句；false 分支直接进入原首条语句，原文本与顺序不动 |
| `onKeyUp` | 先调用原 `releaseKey`，再判断 hold；true 分支清两个按键记录并返回，false 分支进入原 IME/释放代码 |
| `onMouseUp` / `onDeactivateClear` | 整个方法保持逐字不变 |
| `init` | 只在原 cfgHotkey 赋值后新增准确载体构造和 `main.addChild`，其余注册与初始化原样保留 |

静态自检还拒绝 6 种故意破坏：缺 gate、反转 gate、把 onFrame gate 放到 keybinds.step 后、KEY_UP 在释放前返回、修改 mouse-up、修改 replay 方法。断言清单编号必须连续 01–76。实际静态结果保存为 `static-checks.json`。

## 不能由组件或文本检查证明的部分

这证明的是原方法文本及明确 false 分支的顺序保持，不是完整 SWF 运行等价或“零新增指令”。init 新建显示对象并依赖真实 `main.addChild`；它不再支持“没有 addChild 的任意假 main”。本组件不执行 init，也不测试 ApplicationDomain 的真实 World 发现。实际加载入口、子项遍历和跨域发现仍须原生验证。

尤其尚未验证完整 Sandy 的玩家/敌人补步、冷却、回放、异步音乐回调、实际输入事件顺序、无 hold 时的单人行为，以及双方共同旅行的取得/取消/激活。原生须检查这些状态在 hold 期间不推进、释放后继续，KEY_UP/MOUSE_UP 不留下按键状态，活动/回放准入拒绝能正确退回旧旅行路径。76 条通过也不能替代这些验证或性能门槛。
