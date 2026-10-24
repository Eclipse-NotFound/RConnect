# 采样保留与回调机制小组件

只验证本机 AIR 采样器的机制，不加载游戏。现有双人零样本结果保持失败。本目录准备阶段未编译、未运行 AIR。

三个阶段依次执行，均在 RENDER 开始采样、下一 ENTER 做工作、随后的 RENDER 暂停并立即取数量，再在下一 ENTER 读取和枚举，最后 stop、clear、解除 callback：

1. 150ms 有结果校验和的算术正对照。
2. 无 callback 的有界分配压力。
3. 设置 callback 后，完全相同的分配算法、批数上限和时间上限。

压力每阶段最多 2 秒工作、1,048,576 个对象，只保留 64 个活对象。每阶段含事件等待、采集和清理必须不超过 3 秒，否则该阶段断言失败；操作系统调度和 GC 不能被 AS 强行抢占，因此这是会拒绝超限结果的门槛，不是绝对墙钟保证。每段最多枚举 8,192 个样本，全阶段最多 32,768 个、最多保存 8 次 callback；callback 最多使用其中 24,576 个，给下一 ENTER 预留 8,192 个。原生采样缓冲的内存上限没有由本组件证明。

回调中先 pause、枚举有界前缀，再 clear，返回 true 观察运行时是否自动继续。前缀之外的未读量和截断明确保留，不能当完整性能分布。达到总枚举/回调/时间边界则返回 false 并记录主动停止。callbackSupported 只有真实 callback、真实清空以及清空后的新 CPU 样本均出现时才为 true；callback 不发生就是覆盖不足。未触发缓冲耗尽也不能证明不会耗尽。positiveThenZero 只在没有主动 callback 清空的阶段记录。

component-result.json 的 PASS 代表三阶段有效、有界、清理成功，共 9 项断言；第一阶段还必须实际取得 CPU 样本。它不代表压力下“不会清空”或“callback 一定支持”。判断具体机制须看 phases：pauseCount、nextEnterCount、positiveThenZero、callbackRecords、postCallbackCpu、callbackCoverage、truncated。暂停后删除记录可能继续增加，所以不强制两个总计数相等。当前实现仅记录样本类别数量，不格式化调用栈。

运行入口复用原 run_recovery_component.py，只做已经用于成功正对照的单处参数替换：debug=false、optimize=true。原共享登记、独立 AppID、隐藏桌面、1 GiB 启动门槛、512 MiB 运行保护、60 秒进程时限、源码与安装复验、进程回收保持不变。AIR 使用游戏目录的 adl64.exe 和 runtimes/air/win64；本次额外冻结 adl 和 Adobe AIR.dll 的真实哈希，两者版本均为 51.1.3.3。原组件框架保留自己的小型私有存储/结果清理行为，本薄入口不添加系统文件删除。

从 mods/RConnect 目录调用：

    python -B -X utf8 experimental/goal-sampler-retention-component/check.py
    python -B -X utf8 experimental/goal-sampler-retention-component/run.py --check
    python -B -X utf8 experimental/goal-sampler-retention-component/run.py --output build/m52/goal-sampler-retention-component-01

前两条只读静态核验，不启动编译或 AIR。最后一条由根会话执行。Python AST 与 AS 括号检查不替代实际 AS 编译。输入清单在 source-manifest.json，实际运行额外保存 retention-adaptation.json；旧 runner 和失败数据不会修改。
