---
domain: rendering
type: experiments
game-version: ["1.02"]
confidence: high
verified: true
discovered-by: RConnect
date-updated: 2026-10-04
evidence:
  - kind: runtime-experiment
    summary: "原版生产字节双端红验；仅补武器路径变绿、箱子仍红；补物品显示后双向原生抓取变绿。最终候选八阶段真TCP验证通过。"
  - kind: decompiled-game-code
    symbol: "fe.unit.UnitPon.weaponLevit; UnitPlayer.actTele/dropTeleObj; UnitAlicorn.upTeleObj/dropTeleObj"
---

# M44 念力光晕

用户反馈双方看不到彼此和敌人施加于武器、物品的念力光晕。问题是显示信息漏传：原生角色已经把GlowFilter设在武器根显示对象或kor子对象；旧weapon快照只有型号/姿态/开火。场景快照传位置与悬浮标记，也没有光晕或染色。不是单纯颜色配置错误或收包后被绘制清除。

## 复现与逐项验证

循环入口：`tools/build_effects_driver.py --candidate <生产文件> --entry TelekinesisTestDoc --java <java> --output <build驱动目录>`；随后`tools/run_coop_regression.py --candidate <同一文件> --effects-driver <驱动目录> --effects --all-mods --responsive --seconds 110 --expected-version <版本>`。驱动单独加载原封不动的生产字节；游戏启动需要约20秒，核心初验约4秒，完整八阶段约24秒，不能将测试驱动代码混入候选。

- 旧版基线M43，SHA `ed240f09883b091fef5474ff6ef5219bdeae669948ca1331c76007faeef24b20`。`0796e56a83`及`61258bd43b`双向武器、敌人武器均缺光晕；后者截获的真实网络包也没有发光字段。本机青/紫颜色正确，远端GlowFilter为null。
- 前两轮箱子夹具没有成功进入原生抓持，不能作为物品红例；显式给隔离角色合法重量/距离参数，并经同包访问器调用原生actTele后，`348205cd2f`成功抓起箱子，加入端仍0/21帧有光晕。这才是有效物品红例。未改用户角色或重新实现原生发光。
- `176b5f1cc8`只增加武器参数的候选：双向武器20/20、21/21帧正确，画面分别新增1490、1014发光像素；敌人武器21/21帧正确，箱子仍0/21帧。证明两条路径独立遗漏。
- `cf62312507`物品显示候选初验全部通过，箱子22/22帧显示。
- 扩大测试的`083975c52b`在测试日志读取Loot不存在的id时#1069，修正测试读取为item.id，生产文件未变。`f55d530bf6`八阶段行为全部通过，但测试在结束消息确认前关闭宿主socket，加入侧缺DONE导致整体FAIL；测试补了结束回执后再关闭，没有为此修改生产连接逻辑。
- 最终0.2.15-dev候选：102735字节，SHA `8b6fb844bb5295448d3a29e763378a6f3d63f111eb83dc0a5a381da49ff569ae`。`c59e4214a4`完整八阶段通过；双方LMG根图层、assr的kor图层、同武器改色、双方轮流抓箱/掉落、天角兽抓箱、释放、重绘和退出清理均有明确断言。实际最终场景按“保留光晕/临时去掉光晕”差分计数，不以filters字段存在代替可见画面。

## 实现边界

TelekinesisVisuals只收发原生GlowFilter参数和被抓物品的ColorTransform，保留非发光滤镜。GameBridge使用已有房间内稳定键定位目标；加入侧抓物从玩家快照反向送达。武器继续由原有逐帧动画更新；敌人与物品沿现有房间权属发送，不新增物理、伤害或背包结算。

原生fracLevit在松手后可能保留，不能据此持续画光。以真实levit和现存发光为准；收到明确空状态则清理。自己当前抓持及房间所有者原生抓持优先，不回写levit。换房、权属切换、离线、武器替换清理显示引用；接收物品消失或死亡时同样移除覆盖。测试验证远端光晕不会在宿主开启念力物理，且退出会恢复原色及无关滤镜。

本轮不修复加入侧抓敌后的托举/投掷权属；RConnect (2)收到的“有光晕但敌人继续运动”为后续M45独立调查。背景房失控/死敌重现和密集战斗性能边界沿M43，不据本轮通过宣称解决。正式部署与最终相关回归见M44部署记录及证据JSON。
