# 2026-10-11 eli5 实战：专用远端玩家实体规划

被测技能：eli5｜2026-10-02.1｜C:/Users/hello/.agents/skills/eli5/SKILL.md｜SHA-256 `ee4eeea81babed33f4f08fc1c1df94d74d2bd17e17254f99d2f3a729227ea47c`
技能归属：用户级；维护驻地 D:/活/总控
测试工作区：D:/Program Files/Steam/steamapps/common/Remains/mods/RConnect

- 场景与实际采用：用户明确要求详细规划、通俗讲解并点名eli5。先确定对象/关系/变化，再制作原生玩家与远端演员、共享背包副作用、一枪四步、共同播放进度、特殊效果寿命和旧身份拒绝等图；以短标签为主，技术约束和证据展开，并另附完整实施文档。
- 本次产物：[HTML图解](../design/remote-player-entity-preview/index.html)、[详细方案](../design/remote-player-entity-plan-2026-10-11.md)、[静态检查](../design/remote-player-entity-preview/qa/static-check.json)。新旧机制明确区分；不把源码事实、设计建议与实机证明混为一谈。运行代码、构建、游戏测试和部署保持暂停。
- 实际结果：HTML/方案文件存在；16处SVG、21个按钮；本地引用无缺失、无重复ID、标签闭合、静态脚本ID存在，Node `--check` 退出0。这些仅证明源码检查，不能证明图多字少、无溢出或实际点击成功。
- 环境限制：CUA `createBrowserTab` 打开本地 `file:///.../remote-player-entity-preview/index.html` 被浏览器URL策略拒绝，只允许http/https，并明确禁止换工具/路径绕过；未重试替代浏览器、HTTP服务或原始浏览器命令。错误见本对话工具返回，其文字摘要写入静态检查JSON；没有另造浏览器日志或截图。
- 未验：桌面和窄屏实际呈现、所有点击、读者理解与满意度均未观察。不因另一会话的 `implementation-explainer` 有浏览器证据而替本页面宣称通过。首屏/主线图意仅完成作者源码自查。
- 新增证据：本版本在“复杂软件重构方案”的一次自然使用；同日另一会话报告讲现有机制，本报告讲拟议重构，是不同产物。环境限制不归为技能缺陷。
- 经验状态：[未落盘] 若维护侧需要，可核对“本地文件协议受CUA URL策略限制”的客户端条件；本轮只记录具体工具结果，不推广为所有Codex预览都不可用，不修改正式技能。
- 处置：待维护核对。已按既有约定向全局台账精确追加并回读唯一记录，状态“待吸收”。未修改正式技能。
