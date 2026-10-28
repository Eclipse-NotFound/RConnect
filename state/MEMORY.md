# RConnect A — 发布源码状态

当前发布候选：**0.2.24-animfix3-l10n**（九语言预发布），A 架构。源码正本为本分支 `src/`，构建 `tools/build_a.py`，译文 `locales/messages.json`，安装包由 `tools/package_a.py` 白名单生成。`release-manifest.json` 记录全部源文件和产物 SHA256。不要使用旧实验目录构建本版本。

117×9 译文已补齐，主侧／加入侧各1,181项检查通过，固定控件0溢出，昵称与聊天保留。85类成品不含原生存根；80个玩法类与此前已部署 animfix3 相同。源码与安装包的详细边界见 `docs/release-0.2.24.md`，机器结果摘要见 `docs/localization-validation.json`。

本次未纳入 B 架构。密集场景整帧卡顿、普通子弹、加载速度及历史房间边界不据语言测试宣布解决；部分安保／房间功能依赖游戏宿主接口，ZIP不分发本机完整宿主组合。历史日志保留当时证据，不代表现版已做全矩阵重测。

SWF SHA256：`239252df5ea24ec6da5005bd80bfeb31a91e393d6b2bfe7b1fd7b371cd4e618c`。
