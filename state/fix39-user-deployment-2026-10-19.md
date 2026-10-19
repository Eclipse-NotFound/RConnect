# fix39 用户要求的测试候选安装

- 用户本轮明确要求“先部署新版”；原主会话已将此次准确冻结 fix39 的安装和回退移交 RConnect (4)，不包含其他会话的新功能。
- 已安装 `0.2.22-fix39-keybinds`，SHA256 `a02e5aafc2ba529d37a78c83ac92a055121b72d347d56ab8ca720802cc9ddf60`。重启普通游戏/双开入口后加载。
- 回执：`build/m52/fix39-user-install-20261019-02/deployment.json`；同目录 `RConnectMod.before.swf` 是原 fix15 `b2ed7f3a9b1d176dffb2b912d69da8084982906ff71d6fba8367bd36514e84f8`，回退时只恢复 `release/RConnectMod.swf`。
- 校验冻结生产源/构建输入/10份原始回执与日志。九类739项历史通过，依赖组合较旧，不能代替当前组合完整验收；第十类密集测试仍失败。
- 正式路径普通加载器双侧冒烟 `d67361aaea` 通过：双方版本正确、持续200次心跳、加入侧完成连接及单位同步、无原生异常。读取安装版后在独立 AppID 副本中启动，无测试替代生产类；仅管理自有进程，未写真实存档。
- 132项安装输入只变 RConnect SWF。根游戏保持 `2a4662488ba3b690eb23acfe4b79aca3f0d9ae114e5e2dee7595af3cabffb3ea`；其它模组/配置/清单及 ModSettings 禁用设置保留。
- 首次普通沙箱启动 `6fce4ab35d` 出现隔离存储 Error #3003，未形成有效测试，已自动回退；证据在 `build/m52/fix39-user-install-20261019`。第二次按既有隔离实测授权使用非沙箱 AIR，通过后才保留安装。
- **这是用户明确要求的测试候选，`full_release_qualified=false`。** 密集帧数低于80帧/8秒、历史部分P95超200ms、首次掉落86ms超85ms，以及当前组合20类完整验证尚未完成。旧失败未改判，不宣称性能稳定。
- Q 使用队友实时视野的新功能仍在 `experimental/peer-vision-port` 独立开发，未随本次安装；也未带入安保终端、手雷抓取、房间加载及 A41 WallBlend 候选。
