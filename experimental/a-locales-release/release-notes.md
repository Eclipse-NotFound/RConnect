当前 A 版九语言更新，基于已部署 **animfix3**，保留 **Pre-release** 身份，不含 B 架构。

- 补齐简中、繁中、英文、俄文、乌克兰文、波兰文、德文、西班牙文、日文，共 117 条界面文本／1,053 项译文。
- 浮窗、设置、快捷键和连接／房间提示跟随游戏语言；昵称、聊天、地址和存档原样保留。长标签适配紧凑浮窗。
- 纳入当前 A 版武器翻转／近战姿态、敌人话语、念力撞击数字、快速开关门错误碎屑及特殊弹道插值修正。

**验证：** 正式 SWF 在独立静音双实例中各通过 1,181 项多语言与排版检查。80 个玩法类与 animfix3 一致，沿用相应的定向实测证据。普通子弹仍可能受整帧停顿影响；本版不承诺消除密集场景卡顿或全部房间加载问题。

**安装：** 双方保存退出，备份旧模组；先安装 ModLoader，再将 ZIP 内 `mods` 合并到游戏目录，运行扫描器并重启。两边必须同版。F10 显隐，Ctrl+Enter 聊天；本机双开使用 `mods/RConnect/Start-Coop.bat`。本包不覆盖个人配置、存档、游戏本体或其他模组。

部分安保／房间能力依赖配套的游戏宿主接口；本包不提供本机完整宿主组合，不替换 `pfe.swf`。缺少安保接口时浮窗会提示。公网、稳定重连、三人以上及其它游戏版本未保证。详细边界与回退方法见包内说明。

---

Current **A** build with all nine native game UI languages. This remains a **prerelease**, and includes no B architecture. The release tag contains the matching complete A source, editable language catalog and reproducible build/package tools.

The exact SWF passed 1,181 localization and UI checks on each side in isolated host/join instances. Names and chat stay untouched; 80 gameplay files are unchanged from the deployed animfix3 baseline. Targeted visual fixes are included, but whole-frame stalls and dense-scene projectile stutter remain known limitations. Some features require compatible patched host hooks; the game host itself is not distributed in this ZIP.

Install ModLoader first, merge `mods` into your game directory, run the scanner and restart both games with this same version. Keep your settings/saves. Download the attached **RConnect_v0.2.24-animfix3-l10n.zip**, not GitHub's automatic source archives. Checksums are included.

SWF SHA256: `239252df5ea24ec6da5005bd80bfeb31a91e393d6b2bfe7b1fd7b371cd4e618c`.
