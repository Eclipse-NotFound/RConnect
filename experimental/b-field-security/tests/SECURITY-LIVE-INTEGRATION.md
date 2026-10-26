# 安保终端实弹测试接线

`BSecurityLiveCases.as` 是外置动态驱动，不引用任何产品类的编译类型，不应放入正式模组包。未编译、未启动 AIR。只接受现有隔离 `pfe-modsettings-rconnect-b-startup-*` 应用 ID。

根驱动的 security 分支先在 host 同步执行 `BSecurityChecks.run`，再通知 join 同步检查结束；随后两侧各构造 `new BSecurityLiveCases(mod,root,domain,cfg,role,api)`。api 与 BUiCases 一样：check/write/read/finish/log、host 的 home/nextRoom/floorY。每帧继续把 input 与 step 转交；这里不依赖原 `security-done.json` 结束协议。整体超时建议至少 240 秒。

独立通信文件是 `security-live-control.json` 与 `join-security-live-<phase>.json`。正常结束时 join 先 ack、leaveSession、finish；host 收到 end ack 且自身 role 清空后 finish。外层应与 UI 场景一样允许该正常先后顺序，避免误判 join 提前退出。

四例顺序为 skill1/host、skill1/join、skill2/host、skill2/join。每例创建原生高置安保终端和普通机枪炮塔，E 实际开始计时破解，放开 E，再按 E 实际激活。只提高角色原生破解能力以保证成功，不写 actionObj、is_act、unlock 成功结果或直接调用终端。

取得个人权限后，将获权角色放在炮塔和未获权角色之间；仅补足双方生命、移除防护和闪避、提高可见度。炮塔没有关闭 AI，没有写 celUnit/aiState，没有调用 attack/findCel 或直接扣血。它通过正常房间调度自行发现、警戒、开火和结算。

之后观察 240 个 native tick，要求至少采到 180 个不同 tick，原生 spawnsFor 与武器 kol_shoot 都增加、未授权角色生命确实下降、有权角色在真实枪口瞄准线穿过身体时出现实际开火、有权角色生命不下降且双方全程 invulner=false；同时检查炮塔没有重新选中有权角色。加入侧还需收到并呈现两人的最终生命值。

“处于射线中”由枪口位置、真实武器角度、双方身体位置计算，并不声称逐颗随机散布子弹都撞上有权角色。实际命中不通过单独调用 hitPolicy 或手工构造 Bullet 冒充。

每个阶段超过 45 秒视为失败，不强制目标、不补发炮弹、不降低门槛。详细失败日志包含阶段、两人身份、安保技能、原生炮塔状态、当前目标、世界敌人开关、双方生命、实际交互状态和个人锁态。

结束每例后只移除本例终端、炮塔及其仍在场子弹；原生构建和产品覆盖未改动。helper 最终恢复测试前的相关玩家字段和共享策略，不保存用户存档。

2026-10-25 v8 实机夹具修订：准备期原本开放伤害，host 在真实解锁成功后约 1.55 秒死亡，随后多次复活，导致第二次 E 激活超时。证据为 `b-field2-fixed14-03/security/host.BStartupDriver.log`（71,194ms 解锁）和同目录 `host.RConnect-B.log`（72,747ms 首次死亡）。这轮不能归因终端产品激活丢失。准备期改为两人无敌，完成两次实际 E 后、正式窗口前明确取消，持续记录无敌计数为零。

直接写最大生命为 10000 不稳定：原生受击的器官/失血变化会调用 Pers.setParameters，将最大生命按真实等级恢复。夹具改用原生 setForcLevel(60)、setParameters、healAll 在准备与正式窗口开始前建立完整生命/器官容量；240 tick 样本期间不回血，不削弱炮塔伤害。增加全程无死亡断言及最大生命范围记录；位置、鼠标、终端边界、锁态、交互剩余时间和角色控制状态随失败诊断保存。修改后的 helper 尚待统一编译实测。

prepared-v9 / `b-field2-fixed20-01/security`：主侧 skill1 的两种操作者均完成真实破解、激活及 240 tick 战斗；case1 记录 33 次原生开火、未授权玩家从 1280 降至约 1046.42，获权玩家保持 1280，双方 invulner 始终 false、死亡样本为零。加入侧在 settle-1 的 helper 第 252 行访问缺失的 control.health 产生 1010；原因是先发布阶段，再补字段二次发布，另一进程读到了中间完整 JSON。已改为所有附加字段组装完毕后一次发布，并给不完整 settle 参考明确错误。该轮后两例未执行，不能记录整体通过；此修订等待下轮实机。

`b-field20-security-02` 的 unlock-0 失败发生在更早的准备阶段：62,694ms 首条 security-live-start 已记录宿主 sost=2、ggControl=false、work=die；peer-view-ready 要到 66,994ms。先补血和摆位置不能取消原版死亡流程，稍后复活将其移到 X1661 并取消 invulner，导致距离异常；因此不能将这轮归为终端权限或角色 profile 产品缺陷。helper 现先等首次画面就绪及双方原生存活可控，若期间房间/地面基准改变则明确失败，不强制恢复或逐帧拉回。root 另在专用驱动 external 场景 beginMission 前设置开场免伤，正式 240tick 窗口仍明确取消并持续断言双方 invulner=false。
