---
domain: knowledge-validation
type: experiments
game-version: ["1.02"]
confidence: high
verified: true
discovered-by: RConnect
date-updated: 2026-10-13
evidence:
  - kind: runtime-experiment
    summary: "原600秒夹具约4.7分钟后停止射击；外置002在相同B190产物上连续600秒，每分钟双方新射击，2658/2610真实子弹与扣弹相等，168项通过"
  - kind: runtime-experiment
    summary: "外置001经HUD寻找B域失败；002显式加载原始B到已知域，双侧安装标记和完整输入字节审计通过"
---

# B190 的持续开火压力夹具

本记录限 RConnect 的公共 Probe 测试缝和冻结 B190，不改变一般玩家的输入语义。共享库已正确记录兄弟模组应用域不可互见；这里记录模组专属外置夹具接入方式，不重复保存为公共事实。

原 StressProbe 的 input 只返回持续 FIRE。源码确认：原生玩家开火在 Weapon.attack 失败时会消费按钮，PlayerActor.consumedButtons 保留这种输入行为；没有松开重按便可能不再开火。旧夹具检查累计射击大于零，因此十分钟后仍通过，但约后五分钟没有新子弹。旧运行没有逐次按键消费／失败原因日志，不能直接锁定是哪次換弹、低耐久或卡壳触发了停火；消费按键路径和耐久下降是解释线索。累计量不能证明持续负载，旧证据不能改写为新断言通过。

外置 ContinuousStressProbe 继承运行中的 authority.Probe，编译时用 extern SWC，仅嵌入夹具类。每30个本机输入帧松开再按；按一分钟窗口检查每人新子弹，在主侧检查真实库存扣弹精确等于原生 projectile 创建数。耐久恢复、随机卡壳抑制和双方／敌人无敌均为明确夹具条件；原生换弹和弹药库存继续执行。

首次从舞台 HUD 的 loaderInfo.applicationDomain 查找 RConnectMod 失败：被插入游戏显示树的 HUD 没有暴露 B 类定义所在域。原游戏以 LoaderContext(false) 将模块加载到各自子域，不能从 HUD 域猜出兄弟模块域。

修正仅发生在隔离测试副本：关闭清单中的直接 RConnectMod 1.02 载入项，启用测试 bootstrap。bootstrap 将相同原始 B SWF 显式加载到自己的 ApplicationDomain.currentDomain，调用 init 一次，再把 typed payload 装进同一域。payload 使用实际 B 的 Probe 类型；通过公共 mod.probe 替换夹具，通过公共 mod.link 发送就绪消息。原 B、原生补丁和四接口 SWF 都由原回执冻结哈希核验。

接入必须在联网实例构建前完成，显式配置 stressExternal=true、scenario=stress、probe=true，并限独立测试 AppID。驱动、源码、extern、运行器与加载清单分别记录；双侧 installed 标记包含 B 源码标记、原生能力和夹具标记。最终 audit 必须显式 --stress-driver 选择冻结清单，不能根据运行回执自行接受未知驱动。

证据：驱动 build/ab/stress-driver-002，源 ae969f31b7e878ba6df5390f2871d8961697e5741138fb67df7537b993cd8f32；20秒150项及600秒168项均过。十分钟回执 c0be15aac1f9c866724ed8b000d480f6c53ffdc56bb1bf7f24d8004182fb7900；最终审计 b3-suite-audit-190-final。001失败、旧混合负载及002原日志／截图全部保留，运行副本无损去重。

15项证据负控拒绝未知驱动、错B域、重复／错误安装、清单变动、缺分钟、提前结束和单人停火。此类工具检查不能替代实机结果。十分钟不证明无限期稳定；受控夹具不证明正常武器损耗；分时后台负载变化不能算严格A/B性能收益。
