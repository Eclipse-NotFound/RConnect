# RConnect A 0.2.24-tcp1

## 中文

本版增加普通 TCP 内网穿透的地址输入支持：可直接粘贴 `域名:端口`、`tcp://域名:端口`，自动分开并回填地址和端口。也可继续分别输入地址、端口。宿主的本地监听端口与加入方的外部端口可以不同。修正连接立即失败后仍显示“连接中”的情况，九语言增加穿透说明和错误提示。

保留此前九语言界面及 animfix3 修正。本轮没有改动战斗、房间同步协议或发送频率；不包含 B 架构。完整 A 源码在本标签的 `src/`，可重建说明见 [BUILD-A.md](BUILD-A.md)。

### 安装

下载发布页的 **RConnect_v0.2.24-tcp1.zip**，解压后把 **mods 文件夹**合并进游戏目录，运行 ModLoader 扫描器，双方安装同版并完全重启。首次装模组须先完成 [ModLoader 加载入口与扫描器安装](https://github.com/Eclipse-NotFound/ModLoader/blob/master/docs/INSTALL.zh-CN.md#first-install)。不要下载 Source code 当安装包。

ZIP 最外层有“先读我-安装说明.txt”。不含个人配置、存档、游戏 SWF、其他模组或测试驱动。更新不会覆盖个人 `config.txt`。本机双开入口仍保留；远程连接按 [TCP 穿透指南](tcp-tunnel.zh-CN.md)设置。账号、节点由宿主自行准备。

### 验证依据

发布 SWF SHA256：`690604878bd8707007a99e3ad14f8f5f3f55cdd4948c8debe6cc87363afd38c9`。

该文件已在独立、静音的 Windows / Remains 1.02 双实例中通过以下检查，只有 RConnect 启用：

| 条件 | 主侧 / 加入侧检查 | 持续玩家 / 世界状态包 |
|---|---|---|
| 本机真实 TCP 转发，内外端口不同 | 33 / 37，全部通过 | 212 / 424 |
| 每方向增加 40ms 延迟，按 1/3/17/65536 字节交替拆分写入 | 33 / 37，全部通过 | 211 / 426 |

共 **140 项检查**，包括实际界面粘贴与端口回填、域名解析、非法输入拒绝、握手、房间初始化、双方 Unicode 聊天和持续状态包。延迟为人工添加的每方向数值，不是实测公网往返延迟。两轮中转无错误，未改变正常游戏的安装和配置。

语言目录 **119 条 × 9 种 = 1,071 项**覆盖与占位符检查通过。相对上一公开版，81 个已有源码文件和 71 个外部声明文件逐字节相同，仅更改版本、界面接入、Session 接入与语言文件，新增地址解析器。之前的翻译布局/玩法测试仅对未变路径复用，不声称本次重新跑完了全部玩法。`BUILD.json` 记录构建指纹，ZIP 的 `SHA256.json` 可核对文件完整性。

### 已知边界

- 尚未用真实公网节点、第二条宽带完成异地长局验证。IPv6 仅检查地址输入格式，未测试 IPv6 隧道。
- 仅普通 TCP；不支持 HTTP/HTTPS/UDP 转发或 Proxy Protocol 头。没有房间口令或应用层端到端加密，仅向可信队友分享地址。
- 既有普通弹道、密集场景、房间加载等卡顿仍可能存在，本版不承诺性能提升；稳定重连、三人以上和其他游戏版本也未保证。
- 部分安保和房间能力依赖兼容的游戏宿主接口，缺失时可能不可用；本包不分发完整本机宿主组合，也不替换游戏文件。未重新验证全部第三方模组组合。
- 回退时双方保存退出，恢复旧 RConnect 目录、扫描并重启。

## English

This A prerelease accepts pasted `hostname:port` and `tcp://hostname:port` endpoints, separates the fields, and supports different local/external ports for ordinary TCP tunnels. Separate hostname and port input still works. Immediate connection failures no longer leave the UI incorrectly in the joining state. Tunnel help and error text cover all nine game languages. Gameplay, room protocol and send cadence are unchanged; B architecture is excluded.

Download **RConnect_v0.2.24-tcp1.zip**, extract and merge its **mods** folder into the game folder, run the ModLoader scanner, and restart both games with matching versions. First-time users need [ModLoader's game patch and scanner](https://github.com/Eclipse-NotFound/ModLoader/blob/master/docs/INSTALL.md#first-install). Personal config, saves, game SWFs, other mods and test drivers are excluded. See [the TCP guide](tcp-tunnel.md).

The exact SWF identified above passed **140 checks** across two isolated host/join runs: real local TCP forwarding, then an added 40 ms delay in each direction with fragmented writes. Checks covered pasted endpoints, distinct ports, DNS, invalid input rejection, handshake, room initialization, Unicode chat and sustained state traffic. The catalog has **119 messages × 9 languages**. Earlier evidence is reused only for unchanged paths, not presented as a fresh full gameplay or performance qualification.

Real public-node and long-distance sessions remain untested. IPv6 parsing does not imply IPv6 tunnel qualification. Only plain TCP is supported: no HTTP/HTTPS/UDP proxy or Proxy Protocol header. There is no room password or application-level end-to-end encryption. Existing dense-scene, projectile and room-load stalls remain open. Reconnection, 3+ players, other game versions and every mod combination are not guaranteed. Some features require compatible patched-game hooks, which are not bundled. Preserve your settings; restore your mod backup, scan and restart to roll back.
