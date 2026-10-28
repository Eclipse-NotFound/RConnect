# animfix3：A六项视觉反馈修复

正式产物为 `build/m52/visual2-combined-04/RConnectMod.swf`，EB6D11…ABC127，已部署。完整报告见 `state/a-visual-feedback-repair-2026-10-28.md`。

- `src/` 为相对F14A/animfix2的窄覆盖；`prepare.py`整合独立审查结果，明确不纳入迟到补播。
- `validated-src/` 是最终85类完整源码快照，`validated-manifest.json`核对源、外置声明和已部署SWF。不要从陈旧的模组顶层src构建。
- `stubs/`只用于编译外置声明，绝不能内嵌到产品。`build.py`在隔离输出创建SWC并以external-library-path编译主产品，沿实际F14A基线重建；最终完整快照可直接使用相同编译参数。`compile.json`保存精确命令与输入清单。
- `build_probe.py` / `run.py`为外部驱动和隔离测试，不修改产品类、安装版或玩家存档。`check_component.py`运行实际产品插值helper的AIR检查。
- `audit.py`核对实际SWF类清单；`qualify.py`固定匹配证据及限制；`deploy.py`只部署已验证的EB6D字节，旧版必须是F14A，否则停止以防覆盖并发变化。

只承诺报告中的已验行为，不承诺整体FPS或所有弹道卡顿已解决。旧迟到补播实验仍在独立projectiles目录用于审查溯源，未纳入产品。
