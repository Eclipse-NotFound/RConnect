# 独立离线采集候选：构建与验证状态

2026-10-23。仅隔离候选，正式安装仍574D。此处记录后续结果，不修改已冻结README、prepared或compile回执。

## 构建完成

- 版本 `0.2.24-offline1`，目录 `build/m52/recovery-offline-production-01`。
- SWF `eb3653533cfb305bcca0b0cfe5e81bc306ea28fa400aae751ab7b5ae1cfa5fee`，186232字节。
- prepared `c15ee493fdfeb804a2dd39c9710b3127c7ba7f458efd238f6fab8443eea6d5e7`。
- compile `da37c6c00d922df3b900b9b3e4ac4e086a4dd3309989b49d28eaaf8772ae671d`。
- CS提案proof `ec95927aa31e0517b17850eaed2150b93530c1c59ec4da420b3c445f572dd045`。原78源中75份未变、71构建输入来自准确574D；提案之外只改版本号。
- 原compc/mxmlc均成功退出，两个自有Java进程已回收；22项安装前后一致。未启动游戏、未部署的字段指这次编译阶段。

源码审查及诊断r1/r2证据见 `../recovery-cs-offline-review/`。内部ABBA与本构建不是同一产物，不能直接继承性能或功能资格。

已将准确候选与清单交给CS进行无诊断API的原574D/新候选独立进程性能对照。根承担原生会话生命周期与后续整合审查；常规测试只走共享登记，不要求其他会话暂停。

## 第一次生命周期准备未完成

外部驱动01 `a511292c484aca0d8c43cb90be0a0bdbd2fa0df0b480f248ca5bb724d0c065fc` 编译成功。实际单实例 `153f25bc95` 停在begin地图，1200次模组tick中无原生错误；没有执行到网络断言。原因是夹具等待rbl，而此纯离线Session不会执行原有自动旅行分支。

根写本轮自有cancel-request，运行器以130退出并按原流程清理；`build/m52/recovery-offline-lifecycle-native-01/result.json` 为passed=false、done=false、安装不变。保留驱动、日志和取消证据，不把准备失败算成产品失败或已通过。

新v2夹具仅补一次公开原生gotoLand到rbl，待稳定后再固定对象身份。另收紧预期错误分类：每条允许网络日志只能有一个Error #2031，成功结果JSON只能有对应两个，abortReason须空；混入其他错误或额外重复均拒绝。八项纯Python边界检查通过。不会修改原共享runner文件；严格固定原字节，仅在本测试副本错误条件添加上述证据检查，内存、独占、超时和其他异常判定不变。

本轮尚不具备两游戏合作、自动重连、第一次尝试就是失败、实际采集调用观察或完整视觉等价资格。正式候选未合入活动恢复分支或安装版。

## 原生生命周期：第二轮失败，第三轮通过

第二轮 `9f6a0461c6` / driver02 `19f67acd6624108468844db433eb4920468a2c7a08178234a6e4456743545ea9` 完成56项检查和全部12阶段，但清理产生6条 #2002，`passed=false`。旧夹具无条件再次关闭曾记录的Socket；原日志没标资源身份，不能仅凭错误数精确分配来源，也不改判旧轮。

v3仅修测试清理：对尚连接的Socket执行close，随后确认断开，所有端点记录清理前后状态；服务器维持bound条件，补bound/listening关闭后核验。去掉按errorID忽略#2002，不扩大错误白名单。产品SWF未变化。

第三轮 `7a10b4a47f`，driver03 `ad26d81691d5aa527dd2ca633a7ced39f3feb86acffb2c7ec75bfe5000af6e0f`：**56项通过、0失败、12阶段完整**。驱动总23465ms、374次ENTER；两次真实回环接入，读取101字节原生消息但从不回应合作握手。两次拒连的原始#2031完整保留，并仅按完整成功证据识别为预期负例。

- 六个Socket清理前后均connected=false；四个ServerSocket清理前后均bound/listening=false。没有错误，原Session传输释放、私有port/hostIp恢复。
- wrapper退出0、原生runner RESULT PASS、DONE完整；22项安装不变，测试登记结束，自有实例及可重建游戏副本清理。
- 准确结果 `build/m52/recovery-offline-lifecycle-native-03/result.json` SHA256 `f97729db4fab9a37406887847691374351597e359f149665d9fbc5356997d4f1`。
- driver03 prepared `ab5220e9cee933f986528660d2a038c77a9d3150ac9cecfb78de500442f5ab6a`；原始host.log `20bcbec6afe9ed40839fba7fb65e0b39aec66ff2f003ff4c55c7b57981231e68`；run.json `76cc8caea257da381d30d6a7a69fe5fa674e5502aca2b13fc9510b094353d3fc`。

这证明实际Session资格与hook在这些阶段没有错误恢复。它**不证明采集方法实际执行、合作协议、双人效果或双人性能已通过**；连接尚未完成时异常退出的完整取消能力也未单独测试。测试运行器最终回收自有进程。

## 性能及下一步边界

CS已完成准确原574D与本EB365候选的独立进程、同探针/配置对照，各1200帧和90项检查。报告平均连续帧间隔69.615→58.8658ms、中位64→54ms、P95 96→80ms，最长帧306→473ms。自然人口和显示节点数不同，不能称完全同世界的净收益；详细原始数据独立核验见 `../recovery-cs-offline-review/NATIVE-PRODUCTION-REVIEW.md`。

离线改善不用于关闭双人卡顿或加载问题。最近可提交余量约4.9GiB，尚未达到原双实例6GiB启动门槛。保持安装574D，待资源满足后补真正双人和视觉行为验证，再决定是否合入恢复候选；不再重复离线跑分来替代这些缺口。
