# B 独立包的精确部署工具

统一集成最终状态（2026-10-26）：`field22-input.json`指定的八项功能和四轮独立持续射击性能全部合格，实际执行install与finalize。回执`build/ab/b-field-deploy-20261026-01/deployment.json`为verified，安装字节UI主77/加36通过。原B包现field4，五文件备份可回滚，根游戏/A不改。下文保留原工具交接说明，当前准确结果见[统一验证记录](../../state/b-field22-validation-2026-10-26.md)。

2026-10-26统一审阅补充：支持准确区分原AB007与独立持续射击报告，只从固定的两份只读资格工具重算。60秒/45样本、8或80敌人、平均与P95最多退步5%、重复比1.2、六个开火窗口及每窗8秒覆盖门槛均固定不变；未知报告类型、阈值变化和旧失败仍拒绝。12项离线故障检查通过。当前仍未安装；不能将新负载结果描述为原90发弹匣资格。

仅准备了工具；本子任务没有执行安装、finalize、回滚或游戏测试。没有启动 JVM/AIR，没有改现有 B 包、A 的 release、根游戏、启动器、玩家配置和存档。

`deploy.py` 有四个命令：`check` 只读验收，`install` 安装后等待冒烟，`finalize` 验收实际部署字节的独立冒烟并完成，`rollback` 恢复本次备份。脚本不会启动游戏、编译、停止进程或要求玩家预先退出；已有窗口需由玩家保存并重启才会加载新字节。

## 必须显式提交的证据

- `--candidate`：准确的 `build/ab/b190-fieldNN-build` 冻结构建（NN≥20）。没有“选最新”或退回旧候选；读取并验证全体源文件、SWF、source ID、源码版本、BuildInfo 和 b3-v12。部署基线固定为已安装的 field9 / B3-0.1-field3，原生019。
- `--test NAME=.../result.json` 和 `--preparation NAME=.../prepared-vNN.json` 各八个，NAME 必须完整为 `ui,darkteleport,controls,security,terrainlive,rockets,enemies,textmotion`。每项校验实际 candidate/native 路径与指纹、两角色 installed/boot、完整 DONE/PASS 计数、无 fatal/error、隔离应用ID、冻结 runner/driver/helpers、存档种子、配置/端口/场景输入、全部运行依赖和运行期间没有改文件。旧候选通过的记录不能替代最终候选。
- `--performance`：准确候选的新性能资格 JSON。只读调用当前 `experimental/b-field-perf-qualification/qualify.py` 重算四轮原始证据，必须逐字段等于提交报告且 qualified=true；校验器自身指纹、冻结计划和所有输入也进入部署回执。性能重算不会再跑游戏，不放宽门槛。
- 原生候选严格为021：SWF、构建回执、字节保留报告、三个导入/反读源、原021冻结输入清单都有固定指纹；现行 native 源也必须等于冻结项。完整原生审计已由021构建完成，这里不重新运行反编译工具，也不要求永久保留数百MB中间 XML。不能使用从原版重新编译的宿主替换019已验证接口。
- `--notes`：本轮已经审阅的 UTF-8 更新说明。脚本将其附到现有玩家 README；没有内置“所有功能已通过”等超范围描述。

示例（路径由统一集成人填写准确结果，不可照抄占位项执行）：

```text
python experimental/b-field-deployment/deploy.py check
  --candidate build/ab/b190-field21-build
  --test ui=.../result.json --preparation ui=.../prepared-vNN.json
  ...其余七项...
  --performance .../qualification.json --notes .../release-notes.txt
```

`install` 使用同一组参数，额外要求 `--transaction build/ab/b-field-deploy-唯一名称`。该目录必须尚未存在。脚本只允许修改固定 B 包中的以下五个文件：

1. `game/pfe.swf`
2. `game/mods/RConnect/release/RConnectMod.swf`
3. `README.txt`
4. `manual-input.json`
5. `playable-validation.json`

清单同步更新 module/native 指纹、native_files、父清单和回滚位置；最初 local_field_gate_complete=false、candidate_ready_for_manual_testing=false。保留两个原启动器、AIR ID、角色存储、原配置、其他包文件。根游戏/A 文件有只读前后指纹核对；若同时被别的工作改动，脚本停止并报告，不改那些文件。

## 实际部署后的验证

安装成功状态仅为 `installed_pending_smoke`。由统一测试驱动登记并运行新的隔离 `ui` 场景：`--candidate` 必须指向现有包的 `game/mods/RConnect/release/RConnectMod.swf`，`--native` 必须指向同包 `game/pfe.swf`，不是原构建副本。可复用已冻结的安装前 preparation；run.py 会以实际安装文件替换隔离运行副本的 module/native/config。新结果的两应用ID不得与核心测试重复，文件时间必须晚于安装，所有实际运行指纹须相同。

```text
python experimental/b-field-deployment/deploy.py finalize
  --transaction build/ab/b-field-deploy-准确名称
  --smoke .../installed-ui/result.json
  --smoke-preparation .../prepared-vNN.json
```

通过才写 `verified` 和本轮局部验收完成；完整 B 所有玩法资格及 formal_release_gate_complete 不会因此宣称通过。核心、性能、冒烟证据均保留路径和指纹。记忆、日志、版本记录及 git 提交仍由统一集成人完成。

## 回滚和并发约束

五文件都有独立备份及摘要，全部预期新摘要在第一次替换前写入回执。每文件用同目录唯一临时文件、flush/fsync、替换前两次原摘要核对、原子替换及回读。这里承诺逐文件原子性，不把多文件事务说成操作系统级整体原子。

安装或冒烟失败自动尝试回滚；恢复前先核对所有目标都处于本事务记录的旧/新状态、备份准确，再逐个比较并替换。遇到第三方改动会明确记 `rollback_blocked`，不覆盖不属于本事务的字节。中断后可用原工具或事务目录的 `deploy-executed.py rollback --transaction ...` 恢复，工具指纹必须仍等于回执。进程锁异常遗留时先核实该 PID 已结束、回执和目标状态，再移除该准确锁文件；没有盲目清锁/强制覆盖选项。

## 已完成的工具检查

- 9 个离线故障测试通过：首次/二次比较保护、部分写入恢复、第三方编辑整体拒绝、备份破坏拒绝、回滚过程中并发修改拒绝、finalize 中断状态可恢复、八场景含 textmotion、路径穿越/大小写冲突拒绝。全部使用本目录内唯一临时小文件，结束后清理。
- 只读检查 native021 冻结证据通过；用 field20 的 `b-field20-controls-02` 对照解析器确认 65 条实际断言及精确输入检查通过。这只是校验器自检，不能代替 field21 的回归资格。
- 尚未执行完整 check，因为最终候选的八项核心和性能资格尚在统一验证。未执行任何正式包写操作。

运行离线工具测试：`python experimental/b-field-deployment/test_deploy.py`。
