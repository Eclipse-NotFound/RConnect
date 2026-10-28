# RConnect — 双人合作联机

[English](README.md) · **简体中文**

和一位朋友一起探索废土：互相看见、聊天、战斗，也能在同一地图的普通房间分头行动。

**[下载 v0.2.24-animfix3-l10n — RConnect_v0.2.24-animfix3-l10n.zip](https://github.com/Eclipse-NotFound/RConnect/releases/download/v0.2.24-animfix3-l10n/RConnect_v0.2.24-animfix3-l10n.zip)** · [发布说明 / 其他版本](https://github.com/Eclipse-NotFound/RConnect/releases)

点击上方链接下载成品。也可以打开发布页，展开 **Assets（下载文件）**，选择同名文件；**Source code** 和绿色 **Code → Download ZIP** 是源码，不能直接安装。


> **当前 A 架构九语言预发布版。** 包含已部署 animfix3 修复与本轮翻译更新，不含 B 实验架构。密集场景仍可能停顿，不宣称解决全部动画和性能问题。

## 语言与本次更新

浮窗、设置、快捷键及连接／房间提示跟随游戏语言，支持 **简体中文、繁體中文、English、Русский、Українська、Polski、Deutsch、Español、日本語**。切换无需重启模组，昵称和聊天原文保持不变，长说明仍在浮窗内部滚动。

本包也纳入 A 版敌人武器翻转与近战姿态、敌人话语、念力撞击伤害数字、快速开关门错误碎屑等修复。特殊弹道在已确认的位置之间平滑显示，但整体帧停顿仍可能使普通子弹卡顿。详见[验证与已知限制](docs/release-0.2.24.md)。

## 开始前

- 两个人都需要自己的 **Windows / Remains 1.02** 安装，并使用**同一版 RConnect**。
- 先按两台电脑在同一局域网的方式连接；公网、稳定断线重连和三人以上不作可用承诺。
- 一人当房主（Host），一人加入（Join）。角色存档各自保存，不需要复制成同一份存档。

## 安装

适用于 **Windows / Remains 1.02**。

1. 保存并退出游戏。Steam 库中右键 Remains → **管理 → 浏览本地文件**，打开含 `pfe.swf` 和 `application.xml` 的游戏文件夹。
2. 第一次装本系列模组，先完成 [ModLoader 首次安装](https://github.com/Eclipse-NotFound/ModLoader/blob/master/docs/INSTALL.zh-CN.md#first-install)；它包含一次性游戏补丁和模组扫描器。已装好的玩家可跳过。
3. 解压下载的 ZIP，把里面的 **`mods` 文件夹合并到游戏文件夹**，不要套成 `mods/mods`。
4. 双击游戏目录下的 **`mods/ModLoader/RemainsModScanner.exe`**，等待完成后关闭提示，再按平常方式启动游戏。

放对后应能找到：`mods/RConnect/release/RConnectMod.swf`。读入角色后应出现带 Host / Join 按钮的联机面板；F10 可显示/隐藏。

[图示文件结构、更新与恢复方法](https://github.com/Eclipse-NotFound/ModLoader/blob/master/docs/INSTALL.zh-CN.md)

**以上安装步骤，两边都要完成。**

## 第一次连接

1. 两边启动游戏，各自读入角色。面板不见时按 **F10**。
2. 房主在面板填写昵称，地址保留 **127.0.0.1**，端口保留 **23456**，点击 **Host**。
3. 房主在 Windows“设置 → 网络和 Internet → 当前网络属性”查看自己的 **IPv4 地址**（例如 192.168.1.10），发给朋友。
4. 加入方填写自己的昵称，把地址改为**房主的 IPv4 地址**，端口同为 **23456**，点击 **Join**。127.0.0.1 指自己这台电脑，不能用它连接另一台电脑。
5. 点击 **▼** 展开浮窗，在“连接”页操作；连接成功后应能看见对方角色和名字。按 **Ctrl+Enter** 打开聊天，**Enter** 发送，**Esc** 收起。

如果 Windows 防火墙询问，允许游戏在当前使用的可信局域网通信；房主需放行所用端口。无需关闭整个防火墙。

## 一起游玩时

- 普通房间可以分头探索；跨地图旅行由房主带队，剧情与挑战区一起进出。
- 地面物品只有一份，先捡到的人获得；经验点奖励与存档点解锁可以共享。
- 无人房间在本次联机中暂停并保留进度。这不等于退出游戏后保存完整随机房战斗现场；退出时仍按原版方式保存角色。
- 可选共享探索；安装 RealisticVision 时，也可配合本地视野使用。

## 紧凑浮窗与本机双开

浮窗默认只有短状态条，展开后分为连接、聊天、队友和设置四页。拖动标题移动位置；设置页可调 30–100% 不透明度。F10 显隐。宿主可开启菜单/SATS 共同暂停和队友伤害；双方各自设置能否被队友念力抓起、WASD 是否挣脱。

本机双开可运行 `mods/RConnect/Start-Coop.bat`，两个窗口分别保存自己的角色，详见[本机合作说明](docs/local-coop.md)。启动器会让它启动的游戏进程在后台保持运行速度，可能增加耗电。

## 验证与限制

本轮用独立、静音的主侧／加入侧检查九种语言、AIR 字体排版以及玩家文字保留。80 个玩法类与已部署 animfix3 源码逐字节相同，沿用其对应的门、武器、话语、抛掷反馈和弹道检查证据。本次不构成新的性能保证或全部第三方模组组合验证，详见[验证与限制](docs/release-0.2.24.md)。

## 连接不上 / 更新 / 停用

依次确认：两边版本相同且已重启 → 房主先点 Host → 加入方填的是房主局域网地址 → 端口一致 → 房主防火墙允许通信。先在同一局域网测试，不把一次连接失败当作需要重装游戏。

更新时两边保存退出、备份 `mods/RConnect`，再同时更换同版文件、运行扫描器并重启。保留各自原有配置。本包不附带 `config.txt`，避免覆盖个人设置；首次安装使用程序内置默认值。停用可将 RConnect 文件夹移到 `mods` 外备份，再扫描、重启。

## 遇到问题

先检查：文件夹是否放对、是否运行过扫描器、是否完全退出并重启。通用问题见[安装与排错指南](https://github.com/Eclipse-NotFound/ModLoader/blob/master/docs/INSTALL.zh-CN.md#troubleshooting)。

仍有问题，请到[问题反馈](https://github.com/Eclipse-NotFound/RConnect/issues)说明：游戏版本、本模组版本、其他已装模组、操作步骤、预期结果与实际结果；能附截图或报错原文更好。不要上传个人存档，除非排查时确有需要。

<details>
<summary>开发资料与版本差异</summary>

此 Release 标签内的 [src/](src/) 是对应 A 版完整源码；译文在 [locales/messages.json](locales/messages.json)，编译入口见[构建说明](docs/BUILD-A.md)。不包含 B 实验架构。

</details>

[查看全部模组及玩法介绍](https://github.com/Eclipse-NotFound/ModLoader/blob/master/README.zh-CN.md#choose-mods) · [首次安装指南](https://github.com/Eclipse-NotFound/ModLoader/blob/master/docs/INSTALL.zh-CN.md)

这是玩家制作的非官方模组项目，需要自行拥有游戏。
