# 2026-10-13 测试副本精简

用户要求：D 盘容量紧张，精简无用测试文件。操作仅限 RConnect 已结束的隔离测试运行副本。

- 初始 RConnect build 约 69.94 GiB，其中 build/ab 约 60.96 GiB；D 盘空闲约 2.38 GiB。
- 61 组旧双实例运行已校验并去重归档，共 38,138,612,640 字节重复实物（35.52 GiB）。计入新增归档/诊断，磁盘空闲净增加约35.44 GiB，结束时约37.82 GiB可用。
- 每份原文件删除前均与按 SHA256 校验的解压内容逐字节比较。原回执不改写，每组保留 runtime-archive.json，可恢复到新的独立目录。
- 原源码、构建、安装版A22、基线、存档、原有玩法日志/截图/失败记录均保留。113份玩法日志仍在；9个早期角色在启动/监听失败前未产生日志，原回执仍保留这些失败，不是清理删除了日志。
- 缺少退出/输入完整性记录的早期副本暂不处理。

清单：[扫描](../build/ab/test-space-inventory-20261013.json)、[清理回执](../build/ab/test-space-cleanup-20261013.json)、[完整性复核](../build/ab/test-space-cleanup-20261013-verification.json)。清理回执SHA256：56db40e853d700f0de873d7b3a0dbc9808061efb7cb8d996c7d5e2c345c1e1e2；复核SHA256：0ed2bc7316168d526779d353e6f2c9e7d75262f929381f21442f4721d1a21e6c。

后续单项也优先用run_suite.py --scenarios <单项> --archive --stop-on-failure；抖动等专用参数单独运行后立即归档。不能删除evidence-store-001或唯一证据。运行器字节保持，本次未放宽任何测试验收规则。
