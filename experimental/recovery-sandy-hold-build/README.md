# A 版 Sandevistan 加载兼容候选

2026-10-22，用户已明确同意原提案的 A 独立接口及隔离验证合格后部署。本目录只管理构建与证据；当前安装不变。

准确基础是 Sandevistan 的 `build/out/keybind-20261015-006/frozen`（正式 CEC6），不使用含 B 接口的开发源。保留原提案文件，入口逐段加入原定 22 行；helper 只补两个编译器要求的函数末返回值，不改变 try/catch 内的执行结果。

构建结果在 `mods/Sandevistan/build/out/a-travel-hold-20261022-003`：

- SWF：`3e220b595f54249c82fcad36e1b13364c0456c4e8b5f4e20f876c3964c7d331c`，57,920 字节。
- 入口：`577679b9da303a2959e50512a51c5cd0e39f37dfc46416615f8fb15ecf0cd352`。
- `intent.json` 固定全部原源、工具、配置及安装指纹；`receipt.json` 确认编译通过、输入未变。
- 未运行真实游戏，未取得加载耗时、完整时停行为或部署资格。

失败记录保留：001 在准备阶段因 helper 为 LF、脚本误按 CRLF 匹配而停止，无编译；002 因实际可提交余量约 791 MiB 未启动编译。003 在满足 1 GiB 小型构建门槛后编译完成，运行期保持 512 MiB 保护。

重建使用新目录名：

```text
python -B -X utf8 experimental/recovery-sandy-hold-build/build_candidate.py --output a-travel-hold-20261022-004
```

默认共用 ModLoader 的 `game` 登记。只写 Sandevistan 的独立 `build/out`，不改其工作源、正式 SWF、用户配置或宿主。正常无票据路径、活动/回放拒绝、取消/换档、并行首绘及单人对照仍须分别核验；组件绿灯不能代替双人实测。
