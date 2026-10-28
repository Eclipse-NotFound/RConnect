# A 九语言更新与 GitHub 发布

用户要求补齐各语言并将当前 A 更新到 GitHub、创建 Release；已完成，不涉及 B。

- 版本：`0.2.24-animfix3-l10n`，预发布。GitHub master 与标签均指向 `303631c142a4b09049786491e5a4cc70b3f0724d`。
- [Release](https://github.com/Eclipse-NotFound/RConnect/releases/tag/v0.2.24-animfix3-l10n)，资产 `RConnect_v0.2.24-animfix3-l10n.zip`，241341 B。
- SWF SHA256：`239252df5ea24ec6da5005bd80bfeb31a91e393d6b2bfe7b1fd7b371cd4e618c`。
- ZIP SHA256：`44934877df3779a229994c01d31d5ea22b4df5865697ba3092b29d142314bd50`。GitHub digest 与下载回读相同，非 draft。

## 源码与范围

本机正式安装原为 EB6D animfix3，85类全源在 `experimental/a-visual-round2/validated-src`。本轮只改 RCLocale、RCLocaleMessages、NetHud、NetKeybinds 和版本标识，共5文件；其余80类逐字节相同。公开完整源位于 `build/github-a-release/src`，已在公共提交303631c内跟踪，可由 Git 恢复；当前本地主开发分支的旧顶层 src 仍不是安装源，不得从它重建覆盖本版。

公共发布沿远端1a4b683新建 `codex/a-locales-release` 分支／独立工作树，正常快进推送 master。没有把本地249个开发提交及 B 实验整体推上去，保留远端贡献者说明。公开 `tools/build_a.py`、`generate_locales.py`、`package_a.py` 为当前编译、翻译和白名单打包入口；旧入口改为转发。编译存根外部链接，不进SWF和安装包。完整源与声明共156个Git暂存字节指纹匹配构建清单。

原生语言菜单有 zh/tw/en/ru/ua/pl/de/es/jp 九种；原先只有zh/en/ru且tw回退简中。现117条、1053项译文集中到JSON，别名uk/ja/zh-TW/zh-Hant正确映射，未知语言英文回退。昵称、聊天、地址、协议和存档不参与翻译。固定按钮长文本只在变化时计算字号并缓存，说明继续在原浮窗内滚动。

## 验证

- 编译：`build/a-locales-04`，最终指纹239252…E618C；85类审计通过，不含原生声明和测试驱动。
- 实机：`build/cooperation/8a120eb346`，仅RConnect、独立AppID/端口/存储、静音；主／加各1181项、0失败、0固定控件溢出、各369次页面/滚动观察。正式配置、名单、宿主、存档不改。运行副本已由自有运行器清理。
- 早期 `ca24a50707` 暴露德/日停靠标签过长及检测误将scrollRect显示范围当原始文本框；`5ad8ae41c2` 保留同类裁切误报，不冒称通过。最终改用固定控件设计高度测量，并覆盖滚动后的设置。实际按钮文字变短、字号缓存避免反复计算。03产品只编译，最终实测为04。
- 80玩法类沿用上一轮对应门、武器、话语/伤害反馈与弹道定向证据，不重标为本轮全玩法/性能验证。普通枪弹整帧停顿、密集场景及房间加载目标仍未完成；各语言未全部经独立母语审校。
- 安装包仅本模组、原已有同机启动器、说明、源/产物摘要与SHA清单；无配置、存档、游戏SWF、其他模组、B或测试驱动。部分安保/房间能力依赖配套宿主接口，当前本机完整宿主组合不随ZIP分发，已在首页/安装/Release声明。

## 本机部署与接续

回执 `build/a-locales-deploy-20261029/deployment.json` verified；旧EB6D备份 `RConnectMod.before.swf` 同目录。只替换 `release/RConnectMod.swf`，部署回读239252…E618C与公开安装包相同，双方需重启。以后修复以本版本完整A源码为起点，避免丢失九语言。

ContinuousScene另送来单人尾段栈出现RoomSync.present/RoomEntryView.clear/NetHud.refresh等的观察，原始依据为其 `knowledge/experiments/evidence/camera-nearplayer-tail-20261028-r3/camera-tail-review.json`。只是栈计数，未核实可节省耗时；留后续性能排查，不在本轮翻译发布中混改。
