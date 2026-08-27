# RConnect —— Agent 工作范围

> 完整治理规则见工作区根目录 `GOVERNANCE.md`（权限模型、知识库、参考区、游戏文件修改、外置记忆协议、同步与镜像）。
> 本文件只记录本模组的参数与特例。开始开发：读本文件 → 读 `state\MEMORY.md`（记忆入口）。

## 项目参数

| 项 | 值 |
|---|---|
| project | RConnect |
| workspace | mods/RConnect/ |
| repository | 本目录为独立 git 仓库 |
| 运行时入口 | release/RConnectMod.swf（入口类 `RConnectMod`，`public static init(main)`） |
| 记忆入口 | state/MEMORY.md |

## 本模组特例（相对 GOVERNANCE 的偏离/补充）

- loader 硬编码路径为 `app:/mods/Rconnect/release/RConnectMod.swf`（小写 c），实际目录名是 `RConnect`——靠 Windows 大小写不敏感成立，**不要"顺手统一"**。
- `tools\` 是构建/补丁/测试编排层（build_mod.py、patch_game_swfs.py、run_m2_dualtest.py 等），相当于其他模组的 build 脚本目录。
- `README.md` 与 `INSTALL.txt` 是面向玩家的文档（安装教程），不是 agent 内部文档。
- `release\config.txt` 是运行时配置（路径硬编码于模组源码，勿移动）。
- 模组使用 AIR 专属 API（ServerSocket 等），**必须用 amxmlc 编译**，不能用纯 FP 的 mxmlc 配置。
