# RConnect 测试音乐去重（2026-10-19）

用户发现音乐在测试时重复复制，要求精简。本轮只处理RConnect自有build目录中的 `Music/*.mp3`，不改游戏音乐、其他模组、SWF、配置、存档、原日志或测试结果。

## 已完成

- 74套音乐、2590条文件路径，逻辑总量13,488,605,744字节。原有硬链接已排除重复计数，去重前共有2275个MP3文件实体，占11,848,099,640字节。
- 内容哈希确认只有35种音乐，总计182,278,456字节。建立本模组独立缓存 `build/shared-assets/music-v1`，再逐个用同内容硬链接原子替换测试副本。
- 全部2590条替换成功，失败0；逐份重新读取验证，原路径与SHA256全相同，现为35个文件实体。扣除新缓存实际新增的数据，净减少 **11,665,821,184字节，约10.86GiB / 11.67GB**。
- 53份相关原始run/input/inputs/prepared回执的哈希未变；安装35首音乐的哈希及文件身份未变，缓存与安装目录没有共用文件实体。两份共用测试脚本也未修改。
- D盘结束时可用65,327,951,872字节（约60.84GiB）。同期有其他会话活动，磁盘总空闲增量不全部归为本轮收益。

资源管理器仍会显示原来的多套文件列表；硬链接在这些路径下共享实际存储。音乐仍可按原路径读取，没有删曲、静音或改变测试场景。

## 过程与边界

主会话明确交回磁盘窗口后执行，期间它只准备/编译夹具，不启动AIR。本会话没有启动游戏；完成后已立即交回窗口。

排除规则：`build/m52/coop-bundle*`、`build/m52/security-native-02`、`build/cooperation/351dbd7262`、`fcee59d6c2`、`0d3d8971f3`。其他模组不纳入。原始扫描中名为music的测试日志目录不是音频，88份这类小文件未纳入操作。

工具先记录每个MP3的绝对目录约束、文件身份/长度/修改时间和SHA256，再复制一份到独立缓存；缓存核验通过后，在目标同目录创建临时硬链接，最后原子替换。源文件相对计划变化、目标越界、符号链接/目录联接、错误缓存均拒绝；创建硬链接失败时保留原副本。没有递归删除目录，没有改写唯一材料。已有多条硬链接只有移除最后一条旧数据引用才计入回收量，没有把2590个目录项都算作独立释放。

新工具：`tools/validation/shared_music.py`、`deduplicate_test_music.py`、`test_shared_music.py`。微型独立文件验证共12项：11通过；符号链接创建因Windows权限不可用而跳过1，未绕过权限。覆盖安装与测试隔离、相同文件名不同内容不混用、缓存损坏、过期计划、失败时原件保留、配置仍独立、删一个实例后另一实例仍可读。没有用这些小文件检查代替游戏运行证据；本轮同字节去重通过实际2590文件复核。

注意：共享测试音乐应作为不可变资产使用。需要改某份音乐时，应写新文件后替换该路径，不能打开现有硬链接就地改写，否则会连带其他测试副本。安装音乐始终独立，不受这一约束影响。

## 原始清单

全部在 `build/music-cleanup-20261019/`：

- `plan.json`：2590文件原身份/哈希、排除规则、53份回执；SHA256 `efdc2952713f1a4259bccc8fb4aa577ea891e06135b929977424e76b58fe1793`。
- `applied.jsonl`：每次替换的即时记录；`applied.json`：实际释放量及新增缓存量。
- `verified.json`：逐文件原路径/内容和原回执复核结果。
- `protected-before.json`、`protected-after.json`：安装35首音乐与2份共用脚本的原值/复核，缓存不与安装共用文件身份。

命令已执行成功，以下输出名不可重用：

```text
python -B -X utf8 tools/validation/deduplicate_test_music.py plan --output build/music-cleanup-20261019/plan.json
python -B -X utf8 tools/validation/deduplicate_test_music.py apply --plan build/music-cleanup-20261019/plan.json --output build/music-cleanup-20261019/applied.json
python -B -X utf8 tools/validation/deduplicate_test_music.py verify --plan build/music-cleanup-20261019/plan.json --output build/music-cleanup-20261019/verified.json
```

## 避免再次积累

当前共用 `run_coop_regression.py` 会先复制frozen，再复制host/join，通常在finally清理副本，但保留副本或历史冻结环境会积累音乐。为保持主会话当前验收依赖的脚本指纹，本轮没有修改它或 `native_runtime_assets.py`。

已准备4处最小集成补丁 `tools/validation/patches/shared-music-runner.patch`，构建副本也保存于上述清单目录。补丁将初始资产复制及host/join的copytree接入MusicCache；只有MP3共用缓存，其他文件继续独立复制，原有磁盘门槛、输入哈希、音乐播放与清理逻辑不减。正常硬链接不可用时新建测试副本退回完整复制，不允许丢失音乐。

补丁依据runner SHA `c10351ad489581ff0a84b23530ab84f93eebcad9c537fffe1d67db0bb610a2f3`；候选脚本SHA `b28d5bed75f5c6b93e43dc3671560b92cc88bf3091123cb05649be21c9021b09`，语法检查通过。**尚未应用、尚未原生运行**；由主会话在确定新冻结版本时接入，并把新增helper计入输入指纹。历史冻结脚本不回写。现有新冻结环境也可继续使用 `--reuse-runtime` 复用自有旧冻结文件。

共享MEMORY/journal由主会话统一更新。本会话只提交独立清理工具、待合入补丁与本记录。
