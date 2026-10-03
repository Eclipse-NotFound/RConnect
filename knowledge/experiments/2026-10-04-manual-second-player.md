---
domain: knowledge-validation
type: experiments
game-version: ["1.02"]
confidence: high
verified: true
discovered-by: RConnect
date-updated: 2026-10-04
evidence:
  - kind: runtime-experiment
    summary: "同一冻结游戏/模组输入，旧身份自动新档；手动身份停在菜单。独立原生选档实测11项通过。"
---

# 手动第二窗口误开新档

用户反馈 second_player.bat 像加载旧模组、默认新档；确认偏好为“保留第二角色，启动时选择已有存档”。RConnect (2)负责启动工具；原RConnect负责后续M44统一SWF部署。没有改其他模组、游戏SWF或真实角色配置。

## 已确认的原因

真实第二窗口命令行使用当前游戏根与 `second_player_descriptor.xml → pfe.swf`。RConnect.log 最新一次初始化为0.2.14-dev，文件头的0.1.0是追加历史；TDFC最新启动为0.6.4。旧pfe2有槽0–10，RConnect配置autoGame/autoLoadSave/autoRole为空，不能将此问题归因为RConnect配置强开档或实际加载旧SWF。

当前技能武器模组自动驱动以 `appid != pfe && !appid.startsWith("pfe-modsettings-")` 启用，pfe2误中此条件。其驱动关闭主菜单、`newGame(-1,"LP",null)`、打开Pip设置页，与本次用户日志begin/pipA=true一致。原生newGame负槽位会清空当前自动存档对象，因此不能用测试用autoLoadSave“先新建再读档”修手动入口。

## 修复与边界

- 工具改用固定 `pfe-modsettings-rconnect-player2`，使用现有自动驱动排除范围，无需修改其他模组。保留正确live游戏根、pfe.swf和进程局部后台性能设置。
- 首次启动前识别仍运行的旧/新第二窗口并停止；复制pfe2的全部SharedObjects和个人配置到新身份，逐文件核对SHA，再同卷提交整个目录。旧资料保留。新目录有迁移回执则不再复制，避免覆盖继续游玩的角色；未知已有目录拒绝合并。
- 新身份关闭RConnect自动开档/操作测试键及已复制的Sandevistan debugtest，保留昵称、连接、跟随等玩法设置。读取/写入UTF-8以保留中文昵称。历史大日志不继承。
- `ManualStartup`仅该固定手动身份生效。等原生菜单ready调用`mm.funLoadGame(null)`打开列表，用户自选槽位；已进入游戏不打断，超时/错误退回手动Load Game。未改世界建档或读档机制。
- 启动器脚本已在原入口生效；自动打开列表的AS3改动需原RConnect纳入M44统一验证部署。部署前0.2.14仍正常停主菜单，点“载入游戏”即可选档。
- 真实pfe/pfe2仍在运行，本轮没有执行真实迁移、没有关闭它们；第一次迁移在用户保存关闭后下次使用入口时发生。

## 验证

命令均从本模组目录执行；Python使用本机Codex runtime。

1. `python tests/windows/check_manual_startup.py --legacy`：`build/launcher/3133830000`，旧身份**FAIL（预期红）**，无人输入时两次心跳world=begin、mm.active=false、pipA=true。
2. `python tests/windows/check_manual_startup.py`：`build/launcher/914e285432`，相同冻结输入、只换身份，**PASS**；两次心跳world=null、mm.active=true、verror=false。无外部驱动。
3. `powershell -NoProfile -File tests/windows/VerifySecondProfile.ps1`：最终`build/launcher/profile-5d71cb9ca8/result.json`。11槽字节不变、原资料不变、重复启动不覆盖新进度、中文昵称及玩法设置保留、测试驱动关闭、活动窗口及未知存储冲突保护、空角色不伪造存档全部通过。该存储测试使用自建夹具，真实SOL读取另见下一项。
4. `python tests/windows/build_manual_startup_test.py`：冻结M43源+仅ManualStartup改动，候选100530B，SHA256 `ea30f1b144244c1c856e8b3c5210a2a580fd201a832e847556d3fbd41d86c8a8`；全部源码/产物哈希`build/launcher/manual-candidate/inputs.json`。
5. `python tests/windows/check_manual_startup.py --chooser-driver build/launcher/manual-candidate --save-template <只读pfe2槽1>`：`build/launcher/6ea9737c45`，**11 PASS/0 FAIL**。原生列表显示复制角色、等待操作、触发原生槽位点击后实际载入同名/同等级/同地图、无错误、不重开菜单，真实模板前后哈希一致。测试只调用同一openSaveChooser方法；固定生产身份的选择条件由源码核对，未创建真实新身份做测试。
6. 完整`tools/start_coop.ps1 -Mode Second`实测当前用户第二窗口仍开着时返回1，提示先保存关闭；新正式角色目录仍不存在。脚本解析0错误、git diff --check通过。

三次AIR测试只结束自己PID48108、48740、56308。已释放编译/AIR窗口给原RConnect继续M44。正式release仍是M43的99900B、SHA `ed240f09883b091fef5474ff6ef5219bdeae669948ca1331c76007faeef24b20`，本轮未独立部署或改版本号。诊断证据是模组集成条件，不作为所有AIR应用的一般规则。
