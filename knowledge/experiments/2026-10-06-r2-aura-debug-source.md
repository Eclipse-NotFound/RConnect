---
domain: rendering
type: experiments
game-version:
  - "1.02"
confidence: medium
verified: false
discovered-by: RConnect
evidence:
  - kind: runtime-experiment
    summary: "相同2c83生产字节，仅隔离Aura驱动增加调试名，原测试源/时间/阈值不变。"
date-updated: 2026-10-06
---

# Aura漏帧与测试异常收尾取证

原正式`e329299888`两端各53 PASS，宿主0 FAIL，加入19 FAIL：round0颜色30/40、round2为45/46，其余17次Timer #1009；两端DONE。root出处`final-r2-pause-02/aura-failure-provenance.json`。该失败禁止部署，不能借Motion198绿与Restore326绿替代。

只给驱动增加debug=true，生产仍`2c83df6b…`的`2d946fac2a`退出1。原驱动源码、检查时长、阈值和断言均未改；对应`build/m46/aura-debug-driver-01`保存构建、输入、runner与源指纹。结果有额外启动前提失效：宿主begin→random_mane途中就setup，加入侧还在begin；round2首先明确出现missing grab fixture（grab/startRound/receive行号）。这一轮不能用大量颜色0/n判生产显示。

本轮后续#1009精确栈为TelekinesisTestDoc.as:53的UncaughtError回调→Timer_dispatch/tick。该行调用finish()，不是send(done)；此前R2发给root的空socket推断已立即纠正。finish原先先取retirementSnapshot才写cleanup状态，取证异常可再次触发同一收尾。这次精确驱动栈不反向证明旧e329的每次Timer来源。

测试侧另一个独立危险点：AuraMaskProbe.references直接读node.mask，并递归getChildAt结果。原生空子节点已在MirrorMasks调查中实测；该测试遍历原先仍缺同一空节点守卫。现在只改两份测试：空节点跳过；无世界返回空snapshot（原pairs>0断言仍会失败）；finish先进入cleanup并finally注销监听；异常收尾的次生错误单独记FAIL；通知只在连接有效时发出。nativeReady新增配置目标curLandId和已加载land.act.id双身份门控，避免启动地图的夹具被异步换图清除。

没有改1500/3000ms、good==samples、samples>=5、pairs>0和原断言，没有改变核心生产代码，也没有声称新测试修改已经运行通过。旧错误输出不重写、不删除。

继续只读核对发现，run_coop_regression.py 仅给宿主设置 autoTravelLand，加入端为空。因此上述配置目标守卫只直接约束宿主，不能认定已保证双方完成目标房间加载；加入端收到 setup 的分支仍未检查实际房间。下一轮在 UI 窗口交回后核对双方房间就绪握手，再复测原始呈现断言。当前未追加测试修改。

R3只读补证：旧e329 round0是实际光晕null，round2唯一miss为上一轮颜色7405360，而wire已经新16752672。wireReady观察最新收到信息，呈现却依赖driveGhost中的rec.motion.sample同一缓冲样本。下一次应读取已呈现样本的wi/aura/source time与实际root/kor光晕，区别仍在旧样本和新样本被本机覆盖；不延长等待追绿。

窗口已交root做已获用户授权的UI实装/串行编译/AIR；R2测试修改已明确完成且停止写测试/源码/构建和启动AIR，等待rootUI验证后交回新的冻结诊断。NetHud、HudLayout、VERSION/release/MEMORY与统一部署在root；R2不改Config/RCLocale。当前M45安装不动，2d自身PID8788/45256已退出。

## root接续：UI独立发行后的接点

0.2.17-dev UI /a5698f9f…已从M45冻结源独立派生并部署，681/0与正常加载4a3257643f绿。本文上方“安装M45未动”仅指取证当时；未发布M46核心与原错误没有混入UI，也没有由UI通过倒推修复。共享工作树核心标记0.2.18-dev，新安装基线integration-baseline-after-ui-20261006；旧M45基线、2c83核心及红证据保持。

较晚独立诊断5640e056b6实际宿主53/0、加入52/3，两端DONE，本轮零#1009但错色仍红；不能证明旧e329匿名Timer均修复。root已独立核对49640/38776退出。当前两份测试的防空/退出保护仍纳入仓库，原1500/3000ms和断言不放宽；下一次如增加呈现样本查询须用新冻结、保留旧红，先说明源码/AIR窗口。
