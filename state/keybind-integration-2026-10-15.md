# RConnect 菜单改键

当前：最终候选组合验证通过，未部署。用户在快捷键统筹会话要求给对应模组菜单加入改键，并授权联系各模组。RConnect 原会话继续独立战斗/动画任务，本会话接手 NetHud 与新按键适配器。

- 新增 `rconnect-hotkeys`：浮窗显隐默认 F10、聊天默认 Ctrl+Enter。精确匹配修饰键，保存至本机 `RConnect.hotkeys.json`；清除、恢复默认、冲突检查和捕获由 ModLoader 提供。原输入框 Enter/Esc 保留，浮窗底栏和帮助跟随新绑定。面板动作防止按住连发，失焦清理。
- 正式安装仍为 A22 fix15，SHA256 `07b76ed8082462c43eae7048af041370fe315a5b6b23ccdf4e600e02ecd443a4`。候选冻结自 `build/m52/a22-fixes-15/prepared.json` 逐源核对；只叠加 UI 改键，不带当前 experimental/a22-fixes 或 B 代码。
- 构建：`tools/validation/build_keybinds.py`。候选 `build/keybind-output/candidate/RConnectMod.swf`，版本 `0.2.22-fix15-keybinds`，168064 B，SHA256 `b2ed7f3a9b1d176dffb2b912d69da8084982906ff71d6fba8367bd36514e84f8`。完整输入与产物指纹 `build/keybind-output/candidate.json`。
- 最终七模组346项组合通过（首进程175、重启171），含本模组两按钮录入、精确匹配、显示宽高、重启保存及默认恢复；实际舞台事件验证旧F10失效、新面板键、防按住连发、松开重按及新聊天键打开真实聊天页。最终公共服务BD71B6F3…F4908B1的独立39项也通过。完整输入和结果在ModLoader/build/out/menus/keybind-all-fit-20261015及keybind-core-fit-20261015；不能扩称真实双人战斗/IME/DLC验收。
- 正式 release、网络/会话实现、用户游戏和真实存档未改。原A22与B任务的工作目录和提交保持原有所有权。
