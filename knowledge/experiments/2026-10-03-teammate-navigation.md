---
domain: ui-systems
type: experiments
game-version: ["1.02"]
confidence: medium
verified: true
discovered-by: RConnect
date-updated: 2026-10-04
evidence:
  - kind: decompiled-game-code
    symbol: "fe.inter.PipPageInfo.setSubPages/setMapSize; fe.loc.Land.drawMap; fe.unit.Unit.collisionAll"
  - kind: runtime-experiment
    summary: "v4精确候选b2f24d6f83：真实TCP双端55项断言通过，导航/地图错误0，3次正常到达；原生地图最终像素与F10面板截图已核看。"
---

# 队友地图标记与主动传送

当前：实现、独立专项和统一final2候选的专项复验均已完成，交原会话继续整体验证部署；本记录不是已安装声明。基线为语言版ce56ecc，交付时正式SWF仍93060字节，SHA256 `2b25a7d2301d1baac40e04e70ba48e9bc40b5c292c0b3938a69bf6b151b41186`。本轮同时有其他会话修复光束/破墙和调查隐藏房间；各自冻结因果候选，AIR测试按窗口串行，最终统一合并。

发布分工已按用户后续明确回复调整：原`RConnect`会话统一最终验证、版本、部署、MEMORY/journal与提交；本`RConnect (3)`交付地图/传送源码、专项和本记录，`RConnect (2)`交付光束/墙体。已直接互相确认，其他两会话不独立覆盖正式SWF。

用户先要求在游戏地图显示联机玩家，随后追加“传送到队友身边”。沿用已经确认的同地图普通房分头行动、剧情挑战共同进入、宿主共同换图规则，不新增跨地图独立旅行或保存协议。

## 实现

- `TeammateMap`在原生PipBuck的本地地图位图所在容器上挂青色菱形和玩家名，沿用该容器的遮罩和拖动；缩放位置而不缩放标记/文字，不接管鼠标。地图外、断开、陈旧地图世代、无地图房间均不保留错误标记。标记不会修改探索位或房间visited。
- 原生地图按`(landX-minLocX)*cellsX+x/tileX`定位，Y方向减半个角色高度；`Land.drawMap`只绘制基础房间平面，标记使用和原生本地玩家相同的投影。
- `TeammateNavigation`直接使用已有双方快照，三秒没有新的位置包即不再采用。每次旅行重新核对地图/房间世代、角色存活和原有区域限制；F10新增按钮及中英俄文本。
- 跨房使用`RoomSync.travelToTeammate`走原有交接；完成后在队友附近查原生碰撞，要求身体空间可用且脚下有支撑。没有落点就提示失败，不盲目落入墙内；不修改生命、背包或开关“跟随队友”。

## 验证计划与证据

专项`TeammateNavigationTestDoc`使用独立新角色、真实TCP、原生地图缩放/拖动/切页和最终画面像素；覆盖双方同房/分房定位、两向跨房传送、原生落点、失效请求和断开清理。失败和修正按实测补充，不以仅编译成功宣称功能完成。

- 首次定位构建v1因新地图类遗漏Log导入而停止；已补齐。未启动游戏，正式安装未变。
- v2生产SWF构建成功，外部驱动的截图调用缺少`DisplayObject`类型转换；修正驱动后冻结v3。
- v3双端`0ae98027e9`完成55项行为断言，包括原生地图像素、缩放拖动、两向跨房和断线清理；但导航路径错误写入原生角色不存在的`osnova`字段，三次`#1056`出现在移动之后，因此**本轮验收不通过**。删除该多余赋值，仅保留原生`setPos/setVisPos`与公开速度/攀爬状态字段。旧runner只过滤既有功能错误而输出PASS，已补导航/地图失败日志过滤，不以旧PASS掩盖错误。
- 已核看`build/teammate-navigation/navigation-map-v3.png`实际画面：青色标记和姓名位于原生地图遮罩内，字号固定；同位置断言与原生玩家十字标一致。该截图来自隔离新角色，地形探索很少，不代表正式存档的探索被清空。
- v4候选`build/teammate-navigation/v4/RConnectMod.swf`：97547字节，SHA256 `62870ce133c56692123e1d834aef8760fc95e47d8c4e13b53389790f68c42f89`，冻结源码及逐文件指纹在同目录`src/`与`source-input.json`。双端`b2f24d6f83`：宿主30、加入25，共55 PASS／0 FAIL；新增导航/地图错误过滤为0，成功落地日志3次，完整双方DONE。`navigation-audit.json`重新核对两端输入相等，受保护文件无变化；测试进程已按runner结束清理。
- v4最终地图和F10面板截图分别为`build/cooperation/b2f24d6f83/join-navigation-map.png`与`join-navigation-panel.png`，均已人工核看；标记/名字在地图区域内，传送按钮位于原有跟随开关下方，文字未截断。中英俄按钮宽度在实际TextField中验证。
- 可入库验收摘要为同目录`teammate-navigation-validation-evidence.json`；原生本地地图挂载/投影机制已提炼到公共`shared-knowledge/ui-systems/facts/pipbuck-local-map-overlays.md`，没有改动原有旅行页知识。
- 统一final2候选（0.2.14-dev）`build/m43/final2/RConnectMod.swf`，99900字节、SHA256 `ed240f09883b091fef5474ff6ef5219bdeae669948ca1331c76007faeef24b20`。基于其冻结源码重新编译`build/teammate-navigation/final2-driver`，双端运行`8c657607a8`再次55 PASS／0 FAIL，宿主30、加入25，两端DONE；3次传送成功，导航/地图及游戏异常日志0。两端输入相等，保护指纹未变。宿主54864、加入3056退出后额外按PID回查，均不再运行；窗口已交回原会话。
- final2的地图与F10面板PNG在该run目录，已核看标记、名字、按钮及0.2.14-dev版本文字。入库摘要`teammate-navigation-final2-validation-evidence.json`保留对应SHA、断言和落地记录。final1因待修诊断误报没有启动地图测试；未把旧候选结果算作final2验证。

## 交付与剩余验证

生产改动：`RConnectMod.as`、`RoomSync.as`新增主动旅行方法、`NetHud.as`、`TeammateNavigation.as`、`TeammateMap.as`、两份本地化词表。测试改动：`TeammateNavigationTestDoc.as`、builder新增入口、runner新增导航/地图失败日志过滤。README中英两份与INSTALL补入口用法，不改统一版本和安装状态。

统一final2同字节地图专项已完成，入口为`run_coop_regression.py --candidate <SWF> --effects-driver <driver> --effects --all-mods --responsive --land random_mane --seconds 180`，实际流程约60秒。本侧不再修改生产或重复运行；原会话负责剩余最终门禁、现有分房回归、正常无驱动冒烟、安装与回滚、MEMORY/journal和统一提交。

未覆盖范围：跨地图和剧情/挑战传送主动拒绝；三人以上、断线稳定重连仍不在目标内。落点只检查空间与支撑，不承诺避开一切火焰、辐射或敌人；跨房先完成原生进入与交接，若此时队友移动/失效或附近没有落点，会留在原生入房位置并提示取消或失败。本专项不评估密集战斗性能，也不证明隐藏房原有问题已修复。

统一部署补记（2026-10-04）：原RConnect已完成final2共9组470项及正常加载冒烟，部署0.2.14-dev、99900字节、ed240f。本专项55项属于其中，未重复计数。完整部署与回滚见[统一回执](../../state/deployment-m43-2026-10-04.md)；背景房问题仍未确认修复。
