# 2026-10-11 技能实战：RConnect 零基础专业图解

被测技能：eli5｜2026-10-02.1｜C:/Users/hello/.agents/skills/eli5/SKILL.md｜SHA-256 ee4eeea81babed33f4f08fc1c1df94d74d2bd17e17254f99d2f3a729227ea47c；test-report｜2026-09-16.1｜SHA-256 cde4695f98417768f2c11ea42f6ea1f4400ddecc5d00f5a224fcc988646febf5
技能归属：用户级；eli5 维护驻地 D:/活/总控，test-report 维护驻地 D:/活/笔记/写作
测试工作区：D:/Program Files/Steam/steamapps/common/Remains/mods/RConnect

- 场景：用户明确表示完全不懂编程，点名 eli5，要求多图讲解模组技术实现，随后要求同时保证专业性。这是自然讲解任务，没有启动 test-mode、委托、编译游戏或运行游戏测试。
- 实际采用：先核对 eli5 当前验证入口及最近同版本报告 SRC-23f68c52557a，采用“首屏直接解释机制、图承担关系、细节展开”的方式。主线 8 节：双端状态、原版接入、房间归属、双向伤害、武器表现、显示缓冲与暂停、架构职责、开发与验证。
- 专业依据：核心实现固定于 f81c4d9，避免把并行修改中的源码当成已完成结果；另从 0927470 补录 10 月 11 日暂停登记与远端实体评估。22 份来源条目及安装 SWF 指纹保存在 evidence.json。明确区分敌人净损失上报与受害玩家端原生减伤、状态与事件、源时间与收包时间、已部署 22 与未部署 23。
- 结果：完成独立、自包含的 HTML。内置脚本只驱动合成教学场景；不连接游戏、修改配置或存档。教学数值明确标示意，原有实机结果仅引用既有记录；没有据此宣称性能改善。
- 呈现检查：Codex 内置浏览器 1280×720、390×844；实际观察首屏、分房、伤害、武器表格、移动对比等。首屏是两个游戏实例与状态资料传递，手机改为上下排列；图内标签放大、敌人标签移位，表格取消第二列强制不换行，防止展开长文本外溢。最后 390px 展开术语表后，没有可见元素超出视口。
- 交互检查：三步位置演示先使加入侧变为 x=253、主侧保持 x=191，传递后均为 x=253；分头、空房、重访改变负责人且保留 A 房已消灭/已破墙；伤害方向切换时计算端与资料类型同时改变。650ms 合成演示为源位置 65、最新收到 40、缓冲显示 35，关闭缓冲后显示 40；手机滑杆起点均为 0，终点均为 100，播放能自然结束。专业折叠与术语表实际打开。
- 静态检查：无重复 ID、无断开的本地链接、无替换字符、无外部资源依赖；Node 脚本语法检查成功。页面控制台未观察到 error/warn。图解能力验证不等于读者理解验证。
- 环境与限制：首次受限执行环境的本机 HTTP 不可访问；使用批准的仅 127.0.0.1 预览后 HTTP 200、浏览器正常加载。旧错误页为 data URL，绑定受浏览器策略限制；按文档创建新的预览页，没有绕过策略。没有测试 file 协议、其他浏览器、打印或读者复述能力。
- 新增证据：eli5 同版本在复杂联机架构解释中的自然使用；图与专业层分开，保留代码、权限模型、候选状态和失败边界。没有独立新手评价，用户理解效果未验。此报告与 test-report 流程合并记录，不另造报告递归。
- 处置：待维护核对。已向全局台账追加一行，并回读确认本报告路径仅有一条登记；本报告不修改技能正式状态或行为。

## 本次产物

- [讲解页面](../../design/implementation-explainer/index.html)
- [依据清单](../../design/implementation-explainer/evidence.json)、[静态检查](../../design/implementation-explainer/qa/static-check.json)、[浏览器检查](../../design/implementation-explainer/qa/browser-check.json)
- [桌面首屏](../../design/implementation-explainer/qa/desktop-first.jpg)、[分房演示](../../design/implementation-explainer/qa/desktop-rooms.jpg)
- [手机首屏](../../design/implementation-explainer/qa/mobile-first.jpg)、[手机缓冲演示](../../design/implementation-explainer/qa/mobile-motion.jpg)、[展开术语表](../../design/implementation-explainer/qa/mobile-glossary.jpg)

页面检查包含 agent 视觉判断；浏览器 JSON 保存部分实际操作回读。报告中的其他操作描述来自本轮工具可见结果，不声称 JSON 覆盖每一步。

预览服务：仅本机 127.0.0.1:8770，服务目录为本模组；自有 Python PID 69092 留作页面阅读，未启动 AIR。端口和 PID 是本次会话环境记录，不是以后启动脚本的固定依赖。
