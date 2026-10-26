# 原AB007的只读进程采样包装器

`profile_cpu.py`用于诊断一次原bench.py的`--profile`运行，不取得性能资格。准备状态：17项纯假API/临时描述符离线检查通过；没有启动AIR或查询真实进程。Win32调用签名已声明，实际系统兼容性仍须第一次隔离诊断核验。

## 运行边界

- 导入原`tools/host_authority/field2_driver/bench.py`并只调用一次`main()`，固定加入`--profile`。启动、测试登记、等待、内存保护、进程关闭及档案复制仍全部由原runner完成；不启动额外游戏。
- 运行前核验冻结计划中的runner、源码、SWF及native，候选只接受计划中准确field9/native019或field21/native021组合。原bench.py文件不改，结束再次检查字节指纹。
- 原runner先save回执，再给内存中的角色记录补PID；host PID到准备join时才再次落盘，join PID要到finally才落盘。因此只轮询磁盘会错过整个join运行期。本wrapper链原save：原参数、对象和返回值原样转发**一次**，成功后仅保留本次result.json的receipt只读引用。采样器不改receipt，不额外save原档案，结束恢复函数。
- 从此引用读取**本轮明确登记的两个PID**。先核对角色appid、同一session、隔离存储、ab-test.xml内容/文件hash，再打开查询handle，核对实际exe为该角色目录的adl64.exe及进程创建时间。PID/appid变化时拒绝替换。没有进程枚举、按名字搜索、猜PID或关闭用户程序。
- 只申请`PROCESS_QUERY_LIMITED_INFORMATION (0x1000)`。用GetProcessTimes读user/kernel/创建/退出时间，QueryFullProcessImageNameW核对路径，K32GetProcessMemoryInfo读取工作集与private commit。若只读权限下内存不可得，记录错误码，不追加VM_READ、写入或终止权限。
- 一个后台线程每秒采样，最多1800行；两个进程和整机信息在同一行中。只用有界内存数组，结束一次写独立JSON。查询handle不会因PID后来被复用而指向另一进程。自然退出正常记录，采样错误只记录缺失并关闭自身查询handle，不干预原测试。

## 根会话示例命令

下面由根会话在合适的测试占用时执行；本子任务未运行。输出路径必须全新，不重用既有失败轮次。`--profile`由wrapper自动加，不另传。

```powershell
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B `
  'mods/RConnect/experimental/b-field-perf-qualification/profile_cpu.py' `
  --workspace 'build/ab/b-field2-bench-20261025-01' `
  --candidate 'build/ab/b190-field9-build' `
  --native 'build/ab/native-hooks-019/pfe.swf' `
  --result 'build/ab/b-field9-profile-cpu-01' `
  --out 'experimental/b-field-perf-qualification/field9-profile-cpu-01.json' `
  --seconds 60
```

运行期不启动第二条bench命令。正式回执、截图与machine.json由原runner照常保存在`--result`；wrapper单独输出到`--out`，且拒绝把其输出放入原测试档案目录。候选诊断改为field21/native021及新结果名即可。原净性能资格工具会拒绝profile运行，不能把这些数据混入四轮资格。

## 字段和解释

- 每进程保留raw user/kernel FILETIME（100ns单位）、创建/退出时间及本机wall/monotonic时间。差分使用实际monotonic间隔，不假定恰好1000ms。
- `cpu_core_percent`以一个逻辑CPU满载为100%，AIR多线程时可以超过100%；`cpu_machine_percent`再除以记录的logical_cpus。
- `memory.working_set_bytes`为工作集，`private_commit_bytes`为进程私有提交量，另保留峰值工作集、pagefile及缺页计数。不可得时`available=false`，不把缺失冒充零。
- 独立`machine`样本沿用原runner的GetSystemTimes/free_gib口径；原runner自己的machine.json照常保留。
- 输出登记原runner与wrapper hash、计划hash、准确调用参数、最终原回执hash、身份、错误、截断状态与每角色样本数。`two_roles_sampled`只表示两侧各≥2个样本，不表示覆盖整个运行期或性能合格。

CPU时间包含整个AIR进程的所有线程，不能直接认定全来自AS3。Timing是墙钟耗时，包含线程被暂停的时间；不要将有包含关系的计时项直接相加。该包装器没有记录GPU、网络端到端延迟，也未额外加入游戏内camera/hostTick采样；它们仍按原AB007现有日志和截图解释，需要新信息时另行明确外置探针。

## 离线检查

```powershell
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B `
  'mods/RConnect/experimental/b-field-perf-qualification/test_profile_cpu.py'
```

覆盖身份/描述符/hash/存储、原save参数/返回值/异常及单次调用、迟到PID、拒绝猜测或替换、错误exe与旧进程、退出、内存缺失、查询失败、有界线程收尾、CPU单位、只读OpenProcess权限。测试所有进程API均为假对象；不会用当前Python或用户程序来冒充本轮游戏测试进程。
