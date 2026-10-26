# B 第二轮玩家反馈修复（进行中）

本轮只负责B。安装版仍B3-0.1-field3；准确基线field9。用户明确Q问题为原版瞬移绿框但失败。本轮新增功能已授权：安保终端共享/分别破解、抓回队友投掷物。

## 已定位及候选

- 每房Camera默认isZoom=0导致主侧换房/重访使用房间自己的缩放；OccupiedRooms改为继承玩家当前模式后原生重算。
- ClientReplica缺原生actionObj.owner，虽已有t_action/mt_action仍无法显示原生进度；增加只读显示引用，执行仍只在主侧。
- 原生checkPort读取目标tile.visi；主侧执行加入者时看主侧的光照。ActorSight对原生控制暂借加入者自己的目标格光照，finally恢复，不更换物理格。暗室Q真实测试验证中。
- 原生PhisBullet中心锚点、hover优先级3和临近爆炸不可新抓的规则此前未在指向代理中保持。新增只读加入侧提示，真实弹丸仍由主侧执行；到原生expiry时清除另一玩家的持有引用，不改归属/保险/爆炸。审查纠正：已有持有不能在liv5时提前释放，保留到原生liv3。
- 普通墙破坏已运输精确局部像素，但加入侧仍整房drawLoc。仅普通墙、同绘制代次、碰撞变化严格匹配且每个覆盖块均新确认时省去全房重画；任何门/水/斜坡/后景/混合几何保留旧路径。
- 文字根因后续确认是PoseTween用TextField.x/y覆盖matrix.tx/ty，两者原生并不总相同；field20改为矩阵平移分量独立插值。早期同pose组件测试未覆盖插值，不能据其通过排除该问题。
- PlaybackClock源时间延迟65–250ms可解释一部分已到包等待；五次弹丸姿态采样各承担生命周期不同观察点，不能按tick直接去重。仅生成诊断覆盖，未改时钟或删采集。见experimental/b-field-projectile-analysis。
- 安保SecurityTerminals默认共享、宿主设置，按玩家保留锁与失败次数，权限切换不撤回旧授予。原生新增细接口，炮塔索敌/伤害仍原生，未获权限玩家须可被攻击并反击。须实机验收。

## 构建与证据

- 源合并器tools/host_authority/field2_driver/assemble.py核对field9源manifest，再按三方差异合并；PlayerActor嵌套light/pointer/security顺序显式解决，个人操作文案从security.capture读取。
- field10不含安保，编译通过；field11/12是合并冲突中间证据；field13因SecurityTerminals.capture的try/finally返回形式编译失败；改为显式结果再return，field14通过。最终尚未合格。
- native020日志锁权限拒绝而按门槛失败；native021提升工具权限后完成。021 SHA eced04ad8dae6b74444ee6e5f5ec5ddf2e83528a9eecfef66f58985cb0c83063。base为native019，新增5个helper及3个精确原方法前缀；原方法尾部/异常区/traits/其他ABC/资源tags核对通过。旧冻结manifest在experimental/b-field-security/evidence/native021-source-manifest.json，与prepared指纹匹配。
- rockets-baseline-01未启动游戏：测试存储目录写入权限失败；-02正常独立双实例完成，内置主78/加82及外置双10项通过，无FATAL。
- ui-baseline-01双侧正常完成：主65/12错、加32/4错。错误均为已报告缩放/进度条，非夹具卡死。旧版文本8项双侧全过。v3外置helper增加actionTick，避免重试开始前的旧t_action被误判为活动进度。
- 其它结果与准确输入见build/ab/b-field2-*。所有失败保留，运行副本重复使用不复制多套AIR。

## 第二批实测接续

- field14/native021 UI候选主77/加36全部通过；真实原生进度条显示与比例、取消完成清理、六次走门缩放保持均已验。旧版文字组件本身仍全过，矩阵修正未算已解决玩家抖动。
- 暗室Q旧版存在两个方向错误：加入者看得见主侧看不见时失败；只有主侧看得见时错误放行。夹具落地原生Y比请求Y多1已用实际稳定坐标修正，候选三例主39/加8全过。
- `b-field2-fixed14-01` rockets通过；controls因测试错误访问private teleReady失败；terrain因测试把弹孔枪械替换为导弹失败。保留原日志，分别修复驱动后重跑，不降产品断言。
- prepared-v5实际编译发现AS3对动态索引前置递增不接受，改显式数值赋值，prepared-v6编译过。该驱动新增实际E破解/激活后240tick原生炮塔战斗，以及纯移动/点射时最终文字位置和镜头回退采样。当前运行`b-field2-fixed14-02`。
- 单独motion实验不进入field14：新增当前离散状态逐项护卫的运动导入，必须先测试可能反而更慢。motion15合并冲突、motion16测试类布局编译失败均保留；motion17只链测试入口，不更改ClientReplica调用。
- 共享测试队列不保证先进先出，一次等待300秒超时后重排；已按现有RConnect跨会话授权协调短编译空档，没有停止别人的测试或改登记规则。

## 精确授权处理

用户已授权本次测试源码准备的一条10分钟精确护栏授权。实际成功调用仅创建/修改field2_driver/run.py及BStartupDriverMod.as；未改安装文件。因hook标准化格式核对经历3次未匹配，均在finally撤销各自条目。最后核实exec_command在hook侧是Bash及仅command输入，cwd为普通Windows显示路径；成功后立即撤销。没有禁用hook。后续新增授权不能从这次扩展。

## field20实测接续

- field20 SWF `663005a8e7c5cf30692da78b8f19f11a214b78b36ab15e57b6ba93ac7787fb5e`，source `c49104e12703d719ba26df76f2a4ba022397c1d158f8fa065ed8270c4fd9300a`。在field14上增加有界的已发布投掷物画面记录，Q使用玩家按键时实际看到的目标，再验证当前原生距离/视线/质量/生命；不倒退物理模拟。
- `b-text-native-baseline-01` 旧版在真实numb/replic/replic2和CENTER/RIGHT文字插值复现5项误差，最大3.9/3/6px；完成的运动阶段无RENDER半成品错误，整轮被外置moveTo3012中断，未当作完整通过。
- `b-field2-fixed20-01/textmotion` 主20/加34全过。5项文字插值误差均0；五个静止/左右走/点射阶段共446有效最终绘制样本，屏幕反跳0、位置误差<0.05px。位置检查和同pose像素检查分别记录，未称逐像素验证所有插值画面。
- 同套controls主36/1错、加25/2错。加入侧酸弹成功真实抓取；首次普通手雷未等加入侧准备，主已投完而加只采到2帧。hover读取时序在新present后，和上一屏鼠标不配套。需修夹具重测，未把推断当产品通过。
- security前两组（不同操作者）真实解锁/激活、240tick炮塔索敌/开火/安全者不扣血、未授权者扣血通过；随后夹具先发布settle再补health字段，加入侧读到缺字段记录1010。改为完整对象一次发布，产品没改。
- terrainlive组件双侧通过，真正开火前外置moveTo3012失败，未获实战资格。原field14的terrain弹孔/烧痕/耐久原探针主93/加105全过。工具3012/3013均保留队列重试，超5秒明确失败。
- 最后已失败的terrainlive按本轮PID与唯一描述符核对后停止自有实例，运行器保存失败并正常释放登记；随后留给已排队A测试空档。后续避免连续套件反复抢先。
- motion18单独测得body full995ms/guard1062ms、weapon60/93且等价失败；真实visualBullet27/32且等价通过。已放弃，不进产品。时钟离线恢复候选有负例，未改产品；下一次导弹测试增加有界只读时序记录，先测已收到→呈现等待。

## 遗留验收

完成暗室Q旧新对照、候选UI、真实投掷物双向抓取/扔回/到期、安保实际终端和炮塔、导弹核弹与破墙像素/耗时、实际文字抖动及密集性能；只有通过后按门禁更新B独立玩家包并复验，A不变。
