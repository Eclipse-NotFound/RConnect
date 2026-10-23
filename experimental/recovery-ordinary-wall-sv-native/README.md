# 普通墙面 SV：复用原生驱动

仅准备隔离运行入口，不编译、不部署。固定产品为 `recovery-ordinary-wall-sv-production-01` 的 C6A3…3496D；直接复用 `recovery-ordinary-wall-driver-01` 已编译的 AS 驱动和 harness，没有新的 AS 副本或编译。

保留旧四轮普通房测试（双方轻机枪、速射等离子）、真实原生开火与最终画面、原始 uint 像素完全相等分析器、全部错误/完成/22 文件核验、6 GiB 启动门槛、512 MiB 运行保护、共享登记和自有副本清理。唯一代码绑定复用旧 `recovery-wall-surfaces-native.adapted_native` 的既有五处替换，没有新增 inspect/文本替换层。没有性能通过资格，也不据此声称破墙结构版本、重访及 mat7/gwall 全部已验证。

历史产品验证明确分开两件事：用原 `reviewed_inputs/source_bytes/inventory/proposal_patch` 核对历史源码、工具、补丁、构建回执及产物；旧 prepared/compile 的安装清单仍为 574D，不把它冒充当前清单。实际运行只接受这 22 项中 RConnect 从 574D 精确变为 EB365，其余 21 项不变。不会替换原构建器 installation 回调，也不改旧源码和失败回执。

新宿主尚无运行资格时不能冻结入口。根审查实际编译后，独立 `receipt.json` 须含 `candidate_sha256`、`build_manifest_sha256`（build.json）、`readback_audit_sha256`，以及全部为 true 的 `compiled/source_readback_passed/pcode_bindings_passed/exception_cfg_passed/validated`；`inputs/readback_files` 是绝对路径到 SHA256 的映射，须包括真实 SWF、两类实际 AS 回读与 P-code。入口显式调用 `recovery-ordinary-method-transplant/build_final.py` 的 `verify_result`（它仍保持 validated=false），再核独立语义证明，不能只凭成功编译放行。host01/02/03 失败保留；host03 的无关 E4X 变更拒绝准入，host04 仅为中间产物。最终候选只从准确 Grafon-only 基底保留两个 Location 目标方法，且另核其余方法、常量前缀及最终序列化结果。

命令从 RConnect 目录运行（Python 必须不带 `-O`）：

```text
python -B -X utf8 experimental/recovery-ordinary-wall-sv-native/native_tool.py --freeze --host build/m52/recovery-ordinary-wall-sv-host-05 --host-receipt build/m52/<独立审查目录>/receipt.json
python -B -X utf8 experimental/recovery-ordinary-wall-sv-native/native_tool.py --check
python -B -X utf8 experimental/recovery-ordinary-wall-sv-native/native_tool.py --run --output build/m52/recovery-ordinary-wall-sv-native-01 --registry-wait 900
```

`--freeze` 只新增本目录 binding.json；已有绑定不可覆盖。`--check` 只读。`--run` 交回原通用 runner，由它登记并启动游戏；本次准备不执行该命令。原 result.json 不重写；独立 wall-surface-result.json 保留逐 uint 结果，准入/后验异常另写 binding-failure.json。任何失败都不能获得功能或性能资格。
