# 真实加入侧时序日志分析

2026-10-25。`analyze_trace.py`只读BClockTrace输出，不启动游戏、不修改产品、不调整时钟。兼容外置helper的JSONL及根驱动直接写出的`{header,rows,footer}`单个JSON。

状态：14项内存正反例通过。已核验真实`b-field21-final-02/rockets/join-clock-trace.json`，但该日志在首次载入后失去回调所有权，只含1个tick0确认、0弹丸事件，不能据此分析火箭延迟。新诊断保存为`field21-rockets-prefix-diagnostic-02.json`，原trace与旧报告保留。测试新增异常停止、单次初始载入、没有事件、未知停止原因及footer在停止后才读取live状态等反例。

## 命令

```powershell
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' `
  'mods/RConnect/experimental/b-field-clock-replay/analyze_trace.py' `
  --input 'build/ab/<真实运行目录>/join-clock-trace.json' `
  --receipt 'build/ab/<真实运行目录>/result.json' `
  --out 'experimental/b-field-clock-replay/<新的诊断文件名>.json'
```

相对参数以`mods/RConnect`为根，输出文件必须不存在、父目录已存在。输入限64MiB与最多20,000行记录；不复制原始大trace。可省略`--receipt`；提供时仅记其hash、candidate/native/scenario背景，不冒充已经重新核验整个实机回执。

退出码0：记录结构、配对和所检查的采样/事件条件没有已知缺口；1：可生成部分诊断，但有提前停止、事件样本不足、截断、未从起点采样、未配对状态或采样故障等限制；2：结构、时序或路径不合法，不能正常分析。它们都不代表性能、玩法或部署门禁通过。

## 配对、停止和场景覆盖是三件事

输出升级为`rconnect-b-clock-diagnostic-2`。`pairing_valid`与保留的`clean_pairing`只回答已经记录的到包/确认是否正确配对；即使只采到一对，也可能为true。`pairing_quality_notes`仅列配对问题。`quality_notes`另包含采样与覆盖缺口，不能再只看`clean_pairing`就称为完整测试。

`termination`原样保留footer.reason并识别场景正常结束、调用方主动停止、回调被替换、会话身份改变、容量上限与未知原因。只有明确`scenario completed`才说明采集器报告场景完成；它仍不能单独证明采样覆盖了每种武器。

`scene_coverage`统计tick0载入、后续状态、配对弹丸事件和地形修订变化。没有活动帧序列、只录到tick0、没有任一事件样本或未正常结束，均明确标不足。即使观测到了汇总弹丸/地形事件，当前格式没有逐武器名称、逐弹丸生命周期及完整场景起止契约，所以`full_scene_coverage_established`和`supports_weapon_specific_latency`仍不成立；已观测事件的等待值可以单独研究，不等于整个火箭场景。

真实旧trace的`reason`是`another owner replaced a diagnostic callback`。1个已配对样本收到→确认10242ms，原回调耗时10243ms，发生在tick0初次加载；本机确认比原回调返回早1ms，符合加载边界flush。它不是10秒网络或火箭延迟。新报告把它保存在`waits.initial_tick_zero`，`post_initial`与弹丸事件样本数均为0，不删除有效原始数据，也不虚构网络失败。

## 输出的含义

- `waits.*.entry_to_confirm_ms`：**同一加入进程**中的`confirmed.at-arrival.at`。起点是Link已经WireCodec.decode之后交给原处理器，终点是这一离散状态render完成进入confirmed回调。包含差量解码、排队、复制呈现及观察扰动，不能称为纯缓冲或网络耗时。
- `return_to_confirm_signed_ms`：确认完成减原收到回调返回。普通屏幕中常为正；到包触发暂停/换房flush时会为负，这是确认发生在回调返回之前，正常保留，不能把负值裁成“异常低延迟”。
- `push_to_confirm_lower/upper_ms`：因为内部push时间只知在forwardAt至returnAt内，给出其到确认完成的上下界。仍包含render，不是精确队列等待。
- `cadence.source_gap_*`：主侧连续源时间戳之间的间隔；`callback_entry_gap_*`是加入侧连续应用回调入口间隔。这是两条各自内部的时间差，**没有拿加入绝对时间减主侧绝对时间**。
- `active_same_epoch_*`：排除暂停、房间、角色代次和时停阶段/周期边界，并按现有估计器排除≤0或>1000ms源间隔。全部间隔及排除数量同时保留，不隐去长停顿。
- `application_callback_ms`：原收到处理器的外层耗时，包含FrameDelta、prediction及可能的flush。`screen_bracket_ms`包围整个RConnect.before，不能说是纯present独占CPU。
- `clock`：实际读出的delay/queued分布、原underflows计数变化和屏幕段内计数。underflow只是take后没有下一帧的计数，包含flush情形，不代表网络丢包或肉眼卡顿次数。
- `windows`：按采样开始后的10秒窗口汇总同进程等待；`slowest_matched`最多12条最慢样本，便于对照原记录。
- `waits.initial_tick_zero`与`post_initial`分开初次加载和后续状态；所有原始汇总仍只代表已捕获配对，不能直接套上某种武器名称。

原helper的footer会在导出`data()`时读取live frame/clock，可能晚于真正stop。本次trace停止时最后捕获tick0/time91830，但导出footer已是tick749/time157121。分析器标`footer_state_within_captured_history=false`，将累计underflow差37放到`footer_underflow_counter_delta_unscoped`，区间内的`underflow_counter_delta`置null。屏幕段里真实观测的增量仍保留。此处是观察器边界缺口，不是已证明丢失网络帧。

确认按顺序FIFO配对，不以tick为唯一键。暂停时同tick甚至同time可以有多次发布，不能用字典覆盖。若发现前面的到包没确认、后面的已确认，会保留跳过记录并标低资格，不静默跳过。采样结束时仍留在队列的尾部单独计数，不能直接算作事件丢失。

`with_projectile_events`只表示该确认含弹丸事件；`terrain_revision_changed`只表示同房间身份下地形修订号变化。当前采样没有逐弹丸ID/武器名或具体tile变化，因此不能据此单独指认某次导弹、野火核弹或破墙延迟。

`completeHistory=false`不阻止计算已配对包的收到→确认等待，但禁止据此声称完整复现私有时钟历史。`observerMs`是毫秒粒度记录开销，可能量化为0，并不证明零扰动。根驱动的clocktrace轮应保持诊断身份，不混进四轮净性能对照。

## 边界

本脚本只整理真实观测，不运行前面的保守时钟候选，也不把外层时间范围强行当作内部精确时刻。将来若做真实输入回放，需要另处理每个屏幕和到包的时间上下界，并先证明原field9模型能覆盖真实clock读数；当前没有宣称任何真实网络延迟改善或端到端攻击改善。
