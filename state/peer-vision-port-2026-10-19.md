被测技能：diagnosing-bugs 2026-10-08.1（C:/Users/hello/.agents/skills/diagnosing-bugs/SKILL.md）；remains-mod-build / remains-auto-testing / remains-release-gate / remains-mod-memory
技能归属：用户级；Remains 工作区级
测试工作区：D:/Program Files/Steam/steamapps/common/Remains

# Q 队友视野开关接续

当前会话 RConnect (4)，`01a151b6-05e9-7902-acf5-a243f21a71e5`。用户要求先部署新版，再增加 Q 传送可使用队友视野的开关。

fix39 安装已完成，见 [安装记录](fix39-user-deployment-2026-10-19.md)，提交 `9177685`。安装仍是 fix39，不含本功能。

本功能源在 `experimental/peer-vision-port/src`，接点由 `tools/validation/prepare_peer_vision_port.py` 从冻结 fix39 机械合并。独立功能说明见该目录 README；不会消费 `experimental/a22-fixes` 当前并行修改，也不改根游戏 SWF。

已经完成四个类及 HUD/Config/入口接点，当前生产源包含非零蓄力判断、默认关时跳过逐帧工作，以及换房/连接/权限版本隔离。`build/m52/peer-vision-port-06` 编译成功，生产 SHA `85cd121f9f19c0381f54f85194a4b823435f7b2561cee95fc0665091bd52ae03`；**原生首轮失败，不能部署**。

首轮 `6907e02804`：主28通过/5失败、加22通过/1失败；原版自身视野Q双向及关闭时拒绝队友区域通过，宿主浮窗开关/独立配置保存通过。开启后的主侧收到了13个肯定视野答复，但扩展传送与预览未执行；随后加入侧该轮出现原生背包开启、超时，26场景只完成前5场景。不把 finish 标记当全部完成。无原生异常，132份安装输入未变，owned AIR 66012/60604 已由 runner 退出，执行会话2788 exit1，完整失败证据保留。

待验证假设：驱动把鼠标放在 `(800,280)` 的精确瓦片边界，Camera整数像素舍入可能让原生落到相邻瓦片，导致仅一个点的视野权限不匹配；驱动还未逐帧清 keyPip。`peer-vision-port-07` 保持生产源码不变，仅改驱动为格内瞄准 `(790,270)`（原生落点仍为800,319）、清无关控制并记录原生施法门槛。未将假设写为已证实原因，待下一窗口复测。

真实 Q 测试在 `experimental/peer-vision-port/tests/PeerPortTestDoc.as`，13类各主/加双向：关/开、自身/队友当前视野、双方不可见、历史标记、障碍、缺蓝、短按、冷却、无技能、中途失去视野、中途关闭政策。驱动不调用传送方法，也不伪造生产答复；使用隔离游戏的实际 Q 控制链和 TCP。

测试工具：`check_peer_vision_port.py build <新冻结目录>`；`run` 启动独立 AppID、当前全部模组、350秒上限，保留日志/安装输入/真实退出，清理自有资产副本。AIR 用已有授权的非沙箱执行，否则本机隔离存储会报 #3003。测试驱动和生产外部链接分离。

已将 AIR 窗口交回原主会话安保，之后 RC2 长房间、RC5 短probe、Q复测按主会话统一安排；不自行抢占。`tools/validation/install_peer_vision_port.py` 已准备但未执行：验证13场景×双向完整原始日志、生产输入和当前安装，备份fix39、定向替换唯一RConnect SWF、正式加载器双侧冒烟，失败自动回退。主会话要求新增Q部署在RC2之后看准确结果再统一安排，本次已有部署交接仅涵盖fix39。所有密集性能旧红仍保留。

技能使用边界：首次失败发生在本轮读取 diagnosing-bugs 之前；之后按该版本的证据/假设分离流程列出鼠标格子取整、原生施法状态、答复时效三项可区分假设，并将记录限制在第25帧与实际松键帧。尚无可归因于该流程的成功修复结论。技能SHA为 `755c267af6dcb82d4749429476ed8b56cafc5f2e92d58f168e57b340f18c5a1d`，与入口一致；同任务后续更新本文件，不逐次新建报告。

11:06 接续：07生产/外部驱动已编译成功，生产SHA `bf6ab8946a09357788e00d9ffff5b336e61370d970d3fc2cce2619350c8d25f7`，执行会话29890退出0。07尚未跑AIR；06失败不是07结果。校验/部署工具另增加运行前132份安装快照指纹、原生加载及驱动/依赖字节核对；尚无安装调用。11:05:41自测可提交余量4,841,209,856字节（约4.51GiB），低于6GiB，故不启动AIR。当前无本会话AIR/编译进程；等待主会话在内存恢复且前序测试结束后明确交回。准确下一命令：`python -B -X utf8 tools/validation/check_peer_vision_port.py run build/m52/peer-vision-port-07`，AIR需走已有授权的非沙箱执行。所有原始失败不改判，复测成功后再提交给主会话核对安排部署。报告已查重登记全局台账。
