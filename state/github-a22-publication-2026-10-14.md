# A22 GitHub 同步：已发布

用户要求把 A 最新稳定版同步 GitHub。本轮选择已部署 0.2.22-dev 原字节，不提升稳定性声明，不包含 M51/B。

- origin：https://github.com/Eclipse-NotFound/RConnect（PUBLIC）。远端当前 master d5260e9；已 fetch，其贡献者说明在发布树中合并保留。
- 独立发布 worktree：build/github-a22-20261014，HEAD 1a4b683a0be646fc8e53aa4496e016fb6f1be0f8；本地标签 v0.2.22-dev 已指向该提交。无 B/M51，生产源对应 dcef118。
- 核对原 source-input 69 条：冻结字节哈希正确，与发布源码除 Git 换行外全部一致。原 SWF 与本机 release 完全一致，SHA256 32602e77a21b206d1f7ff0e927b953878c28254e7201529455818923a3539732。
- 原部署证据38组4760/0及正常加载通过；本轮未重新实机测试、未重编或修改游戏安装。
- 包：build/github-a22-package-20261014/RConnect_v0.2.22-dev.zip，180910字节，SHA256 53823865250d981e1fefbddb656199062082ba812e8a150d00f9e995f26a05ad。ZIP逐项回读一致、CRC通过；SHA256.json包含文件校验。只含模组SWF、合作启动依赖和说明，不含配置、存档、游戏本体、其他模组。
- 中英文首页及 INSTALL 已更新。release-notes.md、verification.json 和准备脚本均在 build 对应目录保留。独立发布树干净，原开发 master 保持 B195。
- 原子推送 master/tag 与 gh release create 的命令被自动审批在执行前拒绝：虽用户要求同步 GitHub，审批认为未明确授权公开目标仓库及本次完整 payload。因此没有推送或创建 Release；禁止改工具绕过。
- 待用户明确允许公开向 Eclipse-NotFound/RConnect 更新 A22 源码、发布上述安装包并创建预发布后，再查远端是否变化，执行普通非强制推送并核对远端提交/资产摘要。不要推送原开发 master（含 B）。

## 用户明确确认后完成

2026-10-14 用户回复“允许”，明确批准前述公开目标与完整内容。重新核对远端仍为 d5260e9、ZIP 哈希未变，随后非强制原子推送独立发布树 master/tag 成功，创建预发布成功。

- GitHub master 和 v0.2.22-dev 解引用均为 1a4b683a0be646fc8e53aa4496e016fb6f1be0f8。
- 发布页：https://github.com/Eclipse-NotFound/RConnect/releases/tag/v0.2.22-dev
- isDraft=false，isPrerelease=true；资产 ID 640612238，180910 字节，state=uploaded。
- GitHub 返回资产 digest 与本地一致：sha256:53823865250d981e1fefbddb656199062082ba812e8a150d00f9e995f26a05ad。
- A22 源码、标签、安装包和中英文首页已公开；B/M51 未上传。本机安装、存档未改。开发 master 不直接 push，避免把 B 混入公开 A。
