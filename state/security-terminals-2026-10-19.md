# A 版安保终端权限开关 — 2026-10-19

## 用户决定与边界

设置加入「安保终端：共享破解 / 分别破解」，由宿主管理，默认共享。用户明确选择：切换时保留已经取得的安全权限，只影响后续破解。分别破解允许双方各自尝试同一终端，不能由普通门箱同步把另一人的锁定状态覆盖。

当前只在 RConnect 自有隔离树实现。当前正式安装为 fix39-keybinds（由 (4) 按用户另一次要求安装）；此功能尚未安装。原生接口先仅修改自己的 pfe 副本，不写安装本体。真实存档不写。

## 实现与准确输入

- 基线：`build/m52/a22-fixes-39/src`，禁止从根 src 重建；正式字节 `a02e5aafc2ba529d37a78c83ac92a055121b72d347d56ab8ca720802cc9ddf60`。
- 功能源：`experimental/security-terminals/src`。`tools/validation/prepare_security_terminals.py` 机械合并 Config、紧凑 HUD 和 GameBridge，不覆盖其它功能覆盖树。
- 当前候选：`build/m52/security-terminals-06`，版本 `0.2.22-fix39-security1`，SWF `498fe827fd39386d0efa76e41ee8b95165f90d85233c3dcf7c9a84afbc013782`。编译通过。
- 原生副本：`build/m52/security-native-02/pfe.swf`，SHA `a8403f65d20b11daae3b9a8bc08951ea53b7c7d6c9d6f7b4fa941372094a4ca1`。固定安装基线 `2a4662488ba3b690eb23acfe4b79aca3f0d9ae114e5e2dee7595af3cabffb3ea`，只改 Interact、UnitTurret、Bullet。MainFE 加载器与非代码标签读回不变。
- 外部驱动：`tests/security-terminals/SecurityTerminalTestDoc.as`，由 `tools/validation/build_security_driver.py` 与准确候选绑定；03 已编译，后续若修夹具另建目录，不能覆盖原回执。

## 机制

原生破解直接对所在房间的炮塔调用 hack；高级破解会把阵营改为玩家阵营100。不能只过滤找目标：原版子弹也会跳过同阵营玩家。隔离接口因此覆盖终端成功事件、炮塔寻敌、实际子弹/气体/爆炸命中，依目标玩家权限判断，离线时回到原生行为。

宿主只统一权限记录与设置；当前房间的原有权威端继续执行炮塔 AI 和伤害。每份记录锁定当时的共享范围，切换设置不会改写旧记录。原先已被原生剧情/存档关闭或改写的炮塔不会因个人破解重新变成敌对。高级破解炮塔继续进入快照、身体/武器显示与房间交接；个人终端锁/失败次数不进入对方通用交互状态。

权限范围为本次联机和地图轮次，普通房/背景隐藏房分别按房间标识记录。本轮不新增跨重启随机探索战斗存档或稳定重连协议；不能把内存记录说成永久存档。

## 已有证据与待验

- `build/m52/security-access-04/result.json`：纯 AS3 独立 AIR **34 项通过、0 失败、退出0**。包括两人的个人权限、共享旧权限不撤销、重复和乱序消息、后生炮塔、不同房间、空房终端、外部对象改写隔离与新探索清空。
- 原生接口及准确候选编译成功；并不代表原生游玩通过。
- 双侧首轮已运行但未通过，详情见下。必须补齐的有效检查为子弹/气体/爆炸扣血、第二人独立破解和外来房间状态恢复；原生寻敌/锁状态等通过不能替代整体结论。
- 原有密集帧数、首次掉落等红项仍在 `a22-motion-2026-10-15.md`，fix39 的候选安装不等于完整性能验收。

## 首轮原生实测与修正

`security-run-01` / `cooperation/bac9fc89a4` 使用06候选、native02、driver04，双方完整结束，执行退出1，安装前后无变化。主侧103通过14失败、加入侧50通过14失败。共享/个人锁状态、寻敌排除破解者、设置保存和切换保留均有通过记录；伤害和第二人破解存在失败，**整体未通过，不部署**。

已定位测试准备的明确错误：只写角色派生 maxhp=5000，原生 Pers.setParameters 又按 begHP 恢复100，产生4900的假伤害；测试还在双侧加载完成前暴露给原生敌人，角色进入死亡流程。修正驱动：加载时保护测试角色，使用原生 Pers.begHP/inMaxHP/healAll/setParameters 准备血量，每次断言活着且血量稳定，不手工伪造复活。生产字节06不变；第二人请求是否另有问题需正确角色下复核，不提前归因全部为夹具。

最终待运行驱动为 **security-driver-08**，SHA `46db9fabb39db16ba2b5e641dcf23b9b900482db661b87d016ec651958eccab4`，源码 `119867caa0c127c6c7db58bbe42571499d2102b6f1c57a3941e4e558c1349e66`。已编译；增加了滚动后实际控件可见性与截图、外来房间状态恢复，以及未破解玩家对改写阵营炮塔的普通子弹命中。生产仍06，原生仍02。原失败日志、准确输入、内存采样保留，重复游戏素材已由本次runner清理。

11:09 的 `security-run-02` 在实际提权运行器启动检查中因可提交余量低于6 GiB退出，**没有启动AIR**；`run=null`，安装前后无变化。这与首轮行为失败分别记录，不混称为测试通过或游戏崩溃。前序检查同样经历5.04/5.93 GiB波动；没有关闭用户或其它任务的进程，没有降低门槛。

## 测试协调与接续

第一轮已完成RC5、A41、Q、安保与RC2分房。RC5普通手雷短probe已通过；其完整回归仍待。A41组件1281项/38对图像已由(3)读回复核，非联合性能门禁。RC2的04新发送门控、Q07均仅编译及组件或旧字节通过，尚未部署。

当前没有本会话自有AIR。RV阶梯会话连续服务容量错误，未能启动；RV主会话也在真实6 GiB门槛前退出。资源稳定后明确交接，功能接续为安保→Q→房间04→RC5完整；RV约1分钟原生像素及90秒阶梯另与其就绪状态对齐，性能采样需要稳定窗口。不要依据旧消息自动同时启动。

本会话下一步精确命令（RConnect目录，既有隔离测试权限，必须使用全新输出目录）：

```powershell
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 tools/validation/run_security_terminals.py --output build/m52/security-run-03 --candidate build/m52/security-terminals-06 --native build/m52/security-native-02 --driver build/m52/security-driver-08 --seconds 240
```

先读回源/产物指纹、当前安装及实际同权限内存；旧失败不覆盖。通过后目检`cooperation/<run>/host-presentation-security-*.png`及加入侧对应图。若伤害或第二人权限仍失败，按新增的SECURITY HACK真实状态和原生条件定位，不预设都是夹具错误。

开跑前核对准确二进制/驱动指纹、当前安装和至少6 GiB可提交余量；只管理自己的隔离 AppID，保留其它游戏/后台实例，记录背景负载。第一轮安保结束后先交 RC2，若失败先离线修复再安排后续窗口。发布前另走发布门禁，配套本体修改按已有授权边界处理。
