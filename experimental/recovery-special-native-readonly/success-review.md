# MSW 独立爆炸：常规原生02复核

2026-10-22。只读分析，未追加测试、编译或生产修改。准确运行 `build/cooperation/b99cbe382d` / `build/m52/recovery-special-native-02`：08候选 `74d2ab0f6c1d174153af56e9c3a8e3750fa429de066f0dfe90226d48db906f02`，driver04 `3b029fa3a7a7fa3a418f8bb544a252e16c64dc158e01ac23122882ac159a1303`。

**这轮功能成立：主16/0、加14/0，两轮DONE，双方各一发真实控制输入→独立无图像dummy→唯一TCP事件→对侧一个原生爆炸Part且有舞台像素。** 双方反向观察均未生成伤害Bullet；22项安装、冻结输入未变。两侧diagnosticVariant=false、queue=null，属于常规候选，不是队列诊断副本。主108、加89条只读观察均无丢弃。

## 准备修正实际覆盖

主侧round0：新枪在帧1/at84934仍为explRadius=150、destroy=600、tipDecal=9、noTrass=false；原生MSW正常处理后帧2/85010变为0/0/0/true；帧3/85583才首次按攻击。加入侧round1同样经历帧105/48699的150/600/9/false，帧106/48732变为0/0/0/true，帧107/48780首次按攻击。两侧当时枪都确实持有且在背包中，speed=35、grav=1、damageExpl=120、wallHits=1。

首次真实Bullet的explRadius=0、damageExpl=120、vis存在、isExpl=false、in_chain=true；随后原生MSW确实产生不同对象、vis=null、isExpl=true、liv=1的dummy。这直接证实“新装备后必须等原生MSW真实参数就绪”并非多余等待，夹具未强写这些派生字段。旧失败反向首发未进入该支路，修正覆盖了这个准备竞态；但旧日志没有当时参数，不能声称已还原旧轮每个失败字段。

## 真实显示与时间

四个目标Part（两侧各两轮）均为新对象，bitmapMatch=true、3360×240、liv=15、locSame/locActive/stage/visible均true、alpha=1。位置与对应dummy精确一致；classMatch=false符合原生blit特效，不是资源识别失败。收包时locActive也均true。本轮证明原先的getSpriteList身份判据能识别真实源端和远端爆炸，未放宽为任意Part。

| 方向 | 源事件at→源dummy观察→源Part观察（源进程ms） | 收包→远端Part（接收进程ms） | 该进程等待 | 源/远端Part墙钟差 |
|---|---|---|---:|---:|
| 主→加 | 85856→85886→85888 | 45199→45560 | 361 ms | 522 ms |
| 加→主 | 49113→49750→49755 | 90642→91252 | 610 ms | 647 ms |

源事件at、武器sampleTime与角色ownerStamp两轮各自相同，未见单位/epoch混用。不同进程的getTimer不直接相减；最后列仅用同机Date墙钟观察差。**这些是观察时刻，不是Emitter调用或队列cursor采样**。尤其反向接收记录在帧126，Part在帧127，相隔610 ms；源at与源dummy观察也差637 ms。仍有明显长间隔，不能把这轮功能通过当成动画/延迟/性能通过，不能单凭这些数将延迟全部归于队列。结果本身performance_qualified=false。

## 与原失败的关系

旧 `e82a41c002` / special-native-01：07+driver02，主8通过/2失败、加6通过/3失败。round0源确有dummy和Part，加入也确实收到事件，但Part=0；round1加入首发支路失败并超时；DONE另有格式错误。旧结果保持失败。

07→08的UnitPresentation、ProjectileVisuals、ProjectileExplosionVisuals、ImpactEventQueue、ProjectileFrameStream、RemoteMotion六个文件逐字节相同；两轮22项安装清单也相同，但候选其它代码、测试准备/观测及随机场地与执行时序不同。因此**旧round0缺失未复现，尚不能归因于准备修正、位图判据、loc.active或特定时钟修正**。旧轮没有这些现场字段，不能补造结论，也不能倒推旧轮其实成功。

现有常规原生证据已足够关闭“该准确候选能否双向同步这条MSW独立无图像爆炸”功能验证，不为得到更多绿色结果重复跑诊断。原首轮原因记作未确定；gas重复脉冲、acid地面附效及整体流畅度不在此两轮证明范围。
