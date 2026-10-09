---
domain: knowledge-validation
type: experiments
game-version: ["1.02"]
confidence: medium
verified: false
discovered-by: RConnect
evidence:
  - kind: source-code
    symbol: "FollowNetworkTestDoc.tick/receive；TcpLink.onData 的即时消息事件分发"
  - kind: runtime-experiment
    summary: "正式29准备超时；同一生产字节下人为延迟测试监听，旧夹具复现，新夹具完成原业务断言"
date-updated: 2026-10-09
---

# 跟随测试的准备确认不能依赖一次消息

## 已确认

正式29 / 1e5867c1c7两端只完成默认关闭检查，均停在wait；加入侧30秒后超时。没有开始select、align或任何跟房场景。生产心跳、房间提交和单位同步继续，未把这次测试记为业务通过。

旧FollowNetworkTestDoc在房间ready且非busy后才安装独立测试监听。加入侧仅发一次ready；TcpLink当时已经收到的消息不会在新监听安装后重放。另一个风险是ready直接切换宿主phase，早于本地boot时会跳过初始化。类似问题曾记录在[Gameplay测试](2026-10-03-m41-animation-gaps.md)，本次只修正跟随夹具，不改生产网络或跟随实现。

## 观察到

build/m50/follow-startup-probe的两次独立双实例诊断均使用正式候选32602e77。只把宿主的测试监听延迟到首个真实ready到达900ms后；额外只读监听记录该消息，生产TCP、房间逻辑及原全部断言/30秒超时不变。

- 旧夹具836f19eb50：ready在t=42347到达，测试监听false、phase=boot；之后只进入wait，加入侧超时。两端DONE，2 PASS / 1 FAIL，与正式29的未开始业务形态相同。
- 新夹具ec722761a6：首包t=39902、第二包40605时测试监听false，第三包41341时true。随后原分房、异房XP奖励、双向自动跟随及同时开启跟随均通过，10 PASS / 0 FAIL、两端DONE。

修正为尽早监听并记下peerReady，在本地boot完成后才开始选房；加入侧每600ms重发准备消息，收到align后停止。重复ready不会重置已经开始的场景，超时时间仍按原phase计算。正式源与诊断中未加延迟探针的修正文本逐字一致。

## 推测

正式29没有逐包到达与监听时间，不能证明其首包的确切丢失瞬间。源码中的启动竞争和受控复现共同支持这一解释；不据此宣称全部跨房失败或公网丢包均已解决。

## 尚未验证

正式30重新冻结同一生产字节与新夹具，严格保留其它37组的完整相同输入证据，跟随及原21负控重新执行。诊断结果不替代正式发行检查；当前尚未部署。


## 最终发行补记

正式30 / 4ce63cbedf无迟监听探针，原10项跟随业务断言全绿、两端DONE；38组全部4760/0后已部署22。诊断只作原因依据，正式30才作发行证据。原29首包确切丢失时刻仍未直接记录。
