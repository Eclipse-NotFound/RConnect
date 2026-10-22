# FD92 大图墙痕宿主：隔离构建适配

只交付 Python 配方；未编译、未运行 AIR、未部署。准确基线是 `recovery-first-raster-host-03/pfe.swf`，SHA `fd92fbd5ae92b5c8d4cbf8151d11796a140810f34988b7031e258c747d86734e`。导入源已按墙面桥 handoff `74fb4fa581be26f7f56710ab692c2158a1d65016c7cae6d16fa97356ff6fe0f1` 冻结，只导入 `fe.graph.Grafon`，不从 BEFC 或 E159 重新拼装。

`prepare_host.py` 复用准确 `recovery-first-raster/prepare_host.py` 的 main，通过十个严格唯一文本锚点适配源位置、元数据、验证器和宿主。原有共享 `game` 登记、每次启动前的源/工具/安装核验、5 次 FFDec 导出/导入、240 秒子进程等待和 finally 清理保留；没有复制一个新的进程框架。额外拒绝 FFDec 的 SEVERE/预处理错误/未处理异常日志。参数与原入口一致，新目录不可覆盖旧结果。

根会话串行执行：

```powershell
$py = 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
& $py -B -X utf8 experimental/recovery-wall-surfaces-host/check_offline.py
& $py -B -X utf8 experimental/recovery-wall-surfaces-host/prepare_host.py build/m52/recovery-wall-surfaces-host-01 --build
& $py -B -X utf8 experimental/recovery-wall-surfaces-host/prepare_host.py verify build/m52/recovery-wall-surfaces-host-01
```

不带 `--build` 只冻结输入、记录命令，`compiled/validated=false`；这不能用于游戏测试，也不能在同一输出目录后补编译。构建和验证失败同样保留现有输出，下一次用新目录。

## 校验内容

- 基线调用现有 `reverify_host.verify()`，与 `recovery-first-raster-host-recheck-03/receipt.json` 完全相等。保留 host03 原先 `sceneEnsure` 误拒回执及后来独立核验；不重写原 `validated:false`。
- FFDec 导入前的实际 Grafon 导出必须与准确 host03 的 `after/scripts/fe/graph/Grafon.as` 标准化后相同。不是拿未经回读的提案当基线。
- 输入 Grafon 与导入后的实际回读，均同时经过已修正的首绘 `readback.verify_grafon` 和墙面桥 `verify_readback.verify`。覆盖原来的等待/完成/重置分支以及新局部 before/after、revision、场景回放和错误隔离锚点。
- 全部类名列表、电影头及所有非代码 tags 不变；7 个代表类 `MainFE/World/Game/Land/Location/Camera/GUI` 前后标准化源码完全相同。MainFE 也用于确认 loader 未被改变。
- 完整 22 项安装输入在开始、每次 FFDec 启动前、编译后和末尾均核对；末尾同时保存实际 `installation_after`，不能只相信布尔值。
- 源、全部冻结提案清单、实际导入文件、构建工具、校验器及基线证据均绑定 SHA。排队期间或构建中改变输入会失败。

成功输出 `prepared.json` 的 kind 为 `isolated-wall-surfaces-host`，包含 `compiled/validated`、实际候选 SHA、FD92 基线 SHA、当前安装宿主 `original_sha256`、`native_input_sha256`、前后安装清单、回读文件清单及两项行为检查标记。`native-input.json` 保存导入前冻结输入。`verify_prepared()` 是供后续原生测试薄适配调用的只读入口，明确拒绝源码提案、编译失败或回读失败；本轮没有去改原生驱动的宿主准入。

这些检查不是对所有 ABC 方法进行完全语义审计，也不是原生墙痕或性能测试。只有根会话实际构建/回读完成后，才能把准确新宿主交给同字节四例驱动；旧 14+FD92 结果继续保留。
