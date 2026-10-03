# 游戏内语言适配 · 2026-10-03

状态：已获用户明确授权，正式安装完成；安装后隔离复验通过。

菜单、联机按钮/状态和系统提示接入；俄文输入不再漏到游戏控制；保留刚部署的 M41 / 9583c9d。

- 消息数：38，提供英文/俄文，使用游戏的语言开关。
- 当前正式 SWF：93060 字节，SHA256 `2B25A7D2301D1BAAC40E04E70BA48E9BC40B5C292C0B3938A69BF6B151B41186`。
- 构建输出：`D:\Program Files\Steam\steamapps\common\Remains\mods\RConnect\build\localization\RConnectMod.swf`。另有固定副本 `D:\Program Files\Steam\steamapps\common\Remains\mods\ModLoader\build\localization\verified\RConnectMod.swf`。
- 八模组联合隔离验证：安装前 4431 项、安装后 4432 项通过，0 溢出；113 个设置值与玩家文字保留。测试宿主1.02；并非所有玩法的完整回归。
- [联合记录与证据](../../ModLoader/state/localization-2026-10-03.md)，包括原生中→英→俄→中切换、九个设置页所有分页、分组及各模组面板。
- 当前无待部署步骤。正式配置、存档和主游戏 SWF 未改；用户保存重启生效。独立编辑器没有纳入游戏语言入口。
- 本模块回滚备份：`D:\Program Files\Steam\steamapps\common\Remains\mods\ModLoader\build\localization\backups\before-languages-20261003-160623-9ebd8cd6\Rconnect\RConnectMod.swf`；共同回滚步骤见联合记录。
