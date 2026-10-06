# 0.2.17-dev 紧凑浮窗部署记录

2026-10-06，本机候选已部署，正常无驱动加载双端检查通过。双方保存后完全退出并重启游戏。不是GitHub发布或分发包。

## 改动与来源

- 默认280×36状态条，通常展开280×240；连接、队友、聊天、设置四页。保持12单位主字号，长名字、错误、说明通过当前页内部滚动查看。
- 默认顶部位置读取具体可见原生信息控件边界；可拖动标题、四角停靠，玩家分别记忆位置与开合；窗口/倍率变化限制在舞台可见范围。
- F10隐藏/恢复原状态；Ctrl+Enter普通游玩时打开聊天，输入框Enter发送、Esc收起。原版菜单优先，保留原版Enter全屏。修正先按住Shift再进聊天后松键仍奔跑的问题，仅调用原版释放接口，不修改游戏本体。
- 暂停原因独立显示，不随F10隐藏；连接成功收起；未读消息不抢焦点。跟随、探索、传送、宿主暂停设置接回已有规则。
- 冻结来源 `build/ui-20261006/stable-ui-07`：以M45冻结源派生，仅NetHud、新HudLayout与版本变化。47份其他M45源文件逐字节相同；**未发布M46核心没有混入**。当前工作树后续会准备0.2.18-dev，不能用默认工作树构建冒充本UI发行。

## 验证

| 入口 | 双端run | 宿主PASS | 加入PASS | FAIL |
|---|---|---:|---:|---:|
| HudTestDoc | 013025159e | 57 | 57 | 0 |
| CoopPauseTestDoc | 6ebbe208b6 | 217 | 221 | 0 |
| TeammateNavigationTestDoc | 52d472ef50 | 30 | 25 | 0 |
| RoomCooperationTestDoc | e9e7402c87 | 22 | 52 | 0 |

合计681/0，四组两端均DONE；全部输入在启动前冻结，源50项、验证131项、生产49类，不含原生声明/测试类。UI专项保留22张RENDER即时完整游戏PNG；目视常驻、队友页、小窗/200%和隐藏时的暂停提示。其他56项安装文件保护指纹不变，只有本模组release更换。

正常无驱动加载 `4a3257643f`：150秒、当前所有模组、双方新版本/网络心跳和世界匹配通过，未发现门禁失败词。十个专项/冒烟PID逐一独立确认已退出，不操作用户游戏进程。

负对照7d947ade07保持旧90731e82生产字节，新增持键检查两端各56绿1红；新候选相同测试源码各57绿。A恢复本来已绿，仅Shift的keyRun残留实证修复。其他早期红输出全部保留。首次冒烟预检用GBK读取UTF-8记录失败于AIR启动前；已立即回滚M45，再审计/唯一备份，用python -X utf8重试同候选成功。首失败receipt和错误没有覆盖。

边界：合成鼠标/IME/键盘事件不能代替真人实体鼠标与中文输入法；未穷举所有原版/第三方菜单组合。HTML本地file:浏览器限制未绕过，真实AIR截图不等于HTML浏览器通过。密集战斗卡顿、背景房失控/重刷原反馈与M46红仍未解决；不新增稳定重连/三人以上/真实公网/版本兼容保证。

## 安装字节与回滚

- 目标 `release/RConnectMod.swf`：117821字节，SHA256 `a5698f9f5941b27c2fd47de56366c4d867bf256b2dcb7d484596844dea093971`。
- 上一版M45/0.2.16-dev：SHA256 `59a03d1eb3ca7d8467015c709301bc1fbe6d585342de5857e984344a33572790`。
- 备份 `build/backup/ui-release-retry-20261006-232432-d168f9/RConnectMod.before.swf`；不覆盖现有备份，不改根/DLC游戏SWF、描述符、其他模组或玩家存档。
- 回滚：保存退出两端后，把该备份复制回本模组release，再完全重启；只回退SWF，不回退角色保存。

```powershell
Copy-Item -LiteralPath 'D:\Program Files\Steam\steamapps\common\Remains\mods\RConnect\build\backup\ui-release-retry-20261006-232432-d168f9\RConnectMod.before.swf' -Destination 'D:\Program Files\Steam\steamapps\common\Remains\mods\RConnect\release\RConnectMod.swf'
```

原始证据入口：[验证闭包](../knowledge/experiments/ui-20261006-validation-evidence.json)，[真实常驻截图](../design/ui-preview/native-compact.png)，[中文设置截图](../design/ui-preview/native-settings-zh.png)。

新核心安装基线 `build/m46/integration-baseline-after-ui-20261006` 保存当前UI、57项保护和源出处；旧 `integration-baseline` 与M46原失败均保留。后续核心使用0.2.18-dev，重新冻结并走原13组＋HudTestDoc、当前驱动旧905负控及正常加载门禁；本次UI的681项不能替代后续核心总验证。

## 发布门禁

构建/类清单 → 新版本标记 → 681项自动验证 → 已有用户授权 → 游戏SWF未修改（loader核对不适用） → 唯一备份 → 仅本模组部署 → 正常加载通过 → 上述回滚位置 → MEMORY/journal更新 → 本记录（无已有changelog） → 本地Git提交。没有外部推送。
