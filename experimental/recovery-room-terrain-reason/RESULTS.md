# 地形复用诊断：实际构建记录

2026-10-24，根会话编译 `build/m52/recovery-room-terrain-reason-product-01`，版本 `0.2.24-roomreason1`，197497 字节。SWF SHA256：`9a128737ce470127db16ff903fe0bcbdd8280daead0f714c983515c52a14b1ef`。

- prepared.json：`9650b504612a8a279d477f06a6ceceb5ebfc9896d58cdf168f0c2268aeadfb21`
- compile.json：`2402bbca756801456adf4431661a60cdb80bca6e812055d2f3260cf9676a856c`
- 两个编译进程均 exit 0 并已回收；源码与正式安装输入未变。构建后 `run.py --product … --check` 实际通过，确认 candidate_compiled=true。

产品准确继承 roomfix5，仅两类诊断和版本改动。独立审查确认四个原短路条件保持值、顺序、调用次数；reuseGuardDirty 在原复用判断之前采集；beforeRole 将前置工作从原累计 role 数值中分开。原三程驱动没有改动或重编。

**尚未启动本诊断的游戏测试，没有取得首拒绝原因。** 同轮遮罩双实例尝试在可提交余量约 4.29 GiB 时被 6 GiB 启动门槛拦下；本构建完成后的采样又约 3.62 GiB。因此没有继续创建重复失败的双实例目录，没有降低门槛。本诊断本来就不授性能资格，也不可部署。恢复条件满足后按 ENTRY.md 的既有命令运行，结果须另存新目录。
